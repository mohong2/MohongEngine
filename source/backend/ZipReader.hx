package backend;

import haxe.io.Bytes;
import sys.FileSystem;
import sys.io.File;
import sys.io.FileInput;

using StringTools;

/**
 * Minimal ZIP reader/extractor (no external haxelib needed).
 *
 * Supports:
 *  - stored entries (method 0)
 *  - deflated entries (method 8, raw DEFLATE via lime's zlib binding)
 *  - nested directories (created on the fly)
 *  - UTF-8 / legacy (Latin-1 fallback) file names
 *
 * Not supported:
 *  - ZIP64 (entries larger than 4 GB) — detected and reported
 *  - encrypted / multi-disk archives
 *
 * All methods run on the calling thread; extraction reports per-file progress
 * through an optional callback.
 */
class ZipReader
{
	static inline var LOC_SIG:Int = 0x04034b50;
	static inline var CEN_SIG:Int = 0x02014b50;
	static inline var EOCD_SIG:Int = 0x06054b50;

	public static inline var METHOD_STORED:Int = 0;
	public static inline var METHOD_DEFLATED:Int = 8;

	/** Check the magic bytes of a file to decide if it is really a ZIP. */
	public static function isZipFile(path:String):Bool
	{
		try
		{
			if (!FileSystem.exists(path)) return false;
			var input = File.read(path, true);
			var head = input.read(4);
			input.close();
			// PK\x03\x04 little-endian: getUInt16(0)=0x4b50, getUInt16(2)=0x0403
			return head.length == 4 && head.getUInt16(0) == 0x4b50 && head.getUInt16(2) == 0x0403;
		}
		catch (e:Dynamic)
		{
			return false;
		}
	}

	/**
	 * Parse the central directory and return the list of entries.
	 * @throws String on malformed / unsupported archives.
	 */
	public static function readEntries(path:String):Array<ZipEntry>
	{
		var input = File.read(path, true);
		try
		{
			var fileSize:Int = Std.int(FileSystem.stat(path).size);
			if (fileSize < 22) throw "Not a valid ZIP archive (too small)";

			// Find EOCD: scan backwards through the last 64 KB + EOCD size.
			var searchLen:Int = Std.int(Math.min(fileSize, 22 + 65535));
			input.seek(fileSize - searchLen, sys.io.FileSeek.SeekBegin);
			var tail = input.read(searchLen);

			var eocdPos:Int = -1;
			var i:Int = searchLen - 22;
			while (i >= 0)
			{
				if (tail.getUInt16(i) == 0x4b50 && tail.getUInt16(i + 2) == 0x0605)
				{
					eocdPos = i;
					break;
				}
				i--;
			}
			if (eocdPos < 0) throw "Not a valid ZIP archive (no end-of-central-directory)";

			var diskNum:Int = tail.getUInt16(eocdPos + 4);
			var cdStartDisk:Int = tail.getUInt16(eocdPos + 6);
			var entriesOnDisk:Int = tail.getUInt16(eocdPos + 8);
			var totalEntries:Int = tail.getUInt16(eocdPos + 10);
			var cdSize:Int = tail.getInt32(eocdPos + 12);
			var cdOffset:Int = tail.getInt32(eocdPos + 16);

			if (diskNum != 0 || cdStartDisk != 0 || entriesOnDisk != totalEntries)
				throw "Multi-disk ZIP archives are not supported";
			if (cdOffset < 0 || cdSize < 0 || cdOffset + cdSize > fileSize)
				throw "Malformed ZIP central directory offset";

			// Some writers use ZIP64; the marker values are suspicious.
			if (totalEntries == 0xFFFF || cdSize == 0xFFFFFFFF || cdOffset == 0xFFFFFFFF)
				throw "ZIP64 archives are not supported yet";

			input.seek(cdOffset, sys.io.FileSeek.SeekBegin);
			var cdBytes = input.read(cdSize);

			var entries:Array<ZipEntry> = [];
			var pos:Int = 0;
			while (pos + 46 <= cdBytes.length)
			{
				if (cdBytes.getUInt16(pos) != 0x4b50 || cdBytes.getUInt16(pos + 2) != 0x0201)
					throw "Malformed ZIP central directory entry";

				var flags:Int = cdBytes.getUInt16(pos + 8);
				var method:Int = cdBytes.getUInt16(pos + 10);
				var compSize:Int = cdBytes.getInt32(pos + 20);
				var uncompSize:Int = cdBytes.getInt32(pos + 24);
				var nameLen:Int = cdBytes.getUInt16(pos + 28);
				var extraLen:Int = cdBytes.getUInt16(pos + 30);
				var commentLen:Int = cdBytes.getUInt16(pos + 32);
				var localOffset:Int = cdBytes.getInt32(pos + 42);

				if (compSize < 0 || uncompSize < 0 || localOffset < 0)
					throw "ZIP64 entry sizes are not supported yet";

				var nameBytes = cdBytes.sub(pos + 46, nameLen);
				var rawName:String = decodeName(nameBytes, (flags & 0x800) != 0);
				var entryName:String = rawName.replace("\\", "/");

				var isDirectory:Bool = entryName.endsWith("/");
				if (!isDirectory)
				{
					while (entryName.endsWith("/"))
						entryName = entryName.substr(0, entryName.length - 1);
				}

				entries.push({
					name: entryName,
					isDirectory: isDirectory,
					method: method,
					compSize: compSize,
					uncompSize: uncompSize,
					localOffset: localOffset,
					crc32: cdBytes.getInt32(pos + 16),
					flags: flags
				});

				pos += 46 + nameLen + extraLen + commentLen;
			}

			return entries;
		}
		catch (e:Dynamic)
		{
			input.close();
			throw e;
		}
	}

	/**
	 * Extract every entry of a ZIP file into destDir.
	 * Returns the list of (safe, relative) file paths that were written.
	 * @param onProgress optional (doneEntries, totalEntries) callback.
	 * @throws String on failure (caller is expected to wrap in try/catch).
	 */
	public static function extract(path:String, destDir:String, ?onProgress:Int->Int->Void):Array<String>
	{
		FileSystem.createDirectory(destDir);
		var extractor = new ZipExtractor(path);
		extractor.start(destDir);
		var waited:Int = 0;
		while (!extractor.finished && waited < 60000)
		{
			extractor.pumpMessages();
			if (onProgress != null && extractor.total > 0)
				onProgress(extractor.done, extractor.total);
			Sys.sleep(0.01);
			waited++;
		}
		extractor.pumpMessages();
		if (extractor.error != null) throw extractor.error;
		return extractor.writtenFiles;
	}

	/** macOS junk and common unwanted files. */
	public static function isJunkEntry(name:String):Bool
	{
		var lower:String = name.toLowerCase();
		if (lower == "__macosx" || lower.indexOf("__macosx/") == 0) return true;
		var base:String = haxe.io.Path.withoutDirectory(name);
		var baseLower:String = base.toLowerCase();
		if (baseLower == ".ds_store" || baseLower == "thumbs.db" || baseLower == "desktop.ini") return true;
		if (base.indexOf("._") == 0) return true;
		return false;
	}

	/** Turn a raw ZIP entry path into a safe relative path (no traversal, no bad chars). */
	public static function safeRelativePath(name:String):String
	{
		var parts = name.split("/");
		var clean:Array<String> = [];
		for (raw in parts)
		{
			var seg:String = sanitizeSegment(raw);
			if (seg.length == 0 || seg == "." || seg == "..") continue;
			clean.push(seg);
		}
		return clean.join("/");
	}

	static function sanitizeSegment(seg:String):String
	{
		seg = StringTools.replace(seg, "\\", "_");
		seg = ~/[<>:"\/\\|?*\x00-\x1F]/g.replace(seg, "");
		seg = StringTools.trim(seg);
		while (seg.startsWith(".")) seg = seg.substr(1);
		while (seg.endsWith(".") || seg.endsWith(" ")) seg = seg.substr(0, seg.length - 1);
		if (seg.length == 0) return "unnamed";
		return seg;
	}

	/** Decode a file name: UTF-8 when the UTF-8 flag is set, else Latin-1 fallback. */
	static function decodeName(bytes:Bytes, utf8Flag:Bool):String
	{
		if (utf8Flag)
		{
			try
			{
				return bytes.toString();
			}
			catch (e:Dynamic)
			{
				// fall through to Latin-1
			}
		}
		var buf = new StringBuf();
		for (i in 0...bytes.length)
			buf.add(String.fromCharCode(bytes.get(i)));
		return buf.toString();
	}
}

/**
 * Incremental ZIP extractor: processes a few entries per call so the game
 * keeps rendering/updating while a large archive is unpacked.
 *
 * On native targets (cpp/neko/hl) the extraction runs on a background thread;
 * progress/completion is delivered back through hxcpp thread messages which
 * the main thread drains with pumpMessages() once per frame. File IO happens
 * only on the worker, so the game never blocks on big entries.
 */
class ZipExtractor
{
	public var done(default, null):Int = 0;
	public var total(default, null):Int = 0;
	public var finished(default, null):Bool = false;
	public var writtenFiles(default, null):Array<String> = [];
	public var currentFile(default, null):String = '';
	public var error(default, null):String = null;

	/** Transient flag used by ModInstaller to remember the pending prompt. */
	public var pendingPrompt:Bool = false;

	var zipPath:String;
	var cancelRequested:Bool = false;
	var mainThread:sys.thread.Thread;

	public function new(zipPath:String)
	{
		this.zipPath = zipPath;
	}

	/**
	 * Kick off extraction into destDir. On native targets this spawns a worker
	 * thread; on other targets it runs synchronously (blocking).
	 */
	public function start(destDir:String):Void
	{
		#if (cpp || neko || hl)
		mainThread = sys.thread.Thread.current();
		sys.thread.Thread.create(function() run(destDir));
		#else
		run(destDir);
		finished = true;
		#end
	}

	/**
	 * Drain worker messages on the main thread (call once per frame).
	 * After this, read `finished` / `error` / `done` / `total`.
	 */
	public function pumpMessages():Void
	{
		#if (cpp || neko || hl)
		if (mainThread == null) return;
		var msg:Dynamic = sys.thread.Thread.readMessage(false);
		while (msg != null)
		{
			handleMessage(msg);
			msg = sys.thread.Thread.readMessage(false);
		}
		#end
	}

	/** Ask the worker to stop; waits (bounded) until it actually exits. */
	public function requestCancel():Void
	{
		cancelRequested = true;
		#if (cpp || neko || hl)
		var waited:Int = 0;
		while (!finished && waited < 300)
		{
			pumpMessages();
			Sys.sleep(0.01);
			waited++;
		}
		#end
	}

	// ------------------------------------------------------------------
	// Worker
	// ------------------------------------------------------------------

	function run(destDir:String):Void
	{
		var input:FileInput = null;
		try
		{
			FileSystem.createDirectory(destDir);
			input = File.read(zipPath, true);
			var entries:Array<ZipEntry> = ZipReader.readEntries(zipPath);
			var totalEntries:Int = entries.length;
			var index:Int = 0;
			while (index < totalEntries)
			{
				if (cancelRequested) break;
				var entry:ZipEntry = entries[index];
				currentFile = entry.name;
				processEntry(input, entry, destDir);
				index++;
				total = index;
				done = index;
				sendMessage({t: 'prog', done: done, total: total, cur: currentFile});
			}

			input.close();
			input = null;
			total = totalEntries;
			done = totalEntries;
			if (cancelRequested)
				sendMessage({t: 'canceled'});
			else
				sendMessage({t: 'done', files: writtenFiles});
		}
		catch (e:Dynamic)
		{
			if (input != null)
			{
				input.close();
				input = null;
			}
			sendMessage({t: 'err', msg: Std.string(e)});
		}
	}

	function processEntry(input:FileInput, entry:ZipEntry, destDir:String):Void
	{
		var name:String = entry.name.replace("\\", "/");
		if (name.length == 0 || ZipReader.isJunkEntry(name)) return;
		var safeRel:String = ZipReader.safeRelativePath(name);
		if (safeRel == null || safeRel.length == 0) return;

		var outPath:String = haxe.io.Path.join([destDir, safeRel]);
		var outDir:String = haxe.io.Path.directory(outPath);
		if (outDir.length > 0 && !FileSystem.exists(outDir))
			FileSystem.createDirectory(outDir);

		if (entry.isDirectory)
		{
			if (!FileSystem.exists(outPath)) FileSystem.createDirectory(outPath);
			return;
		}

		var data:haxe.io.Bytes = readEntryData(input, entry);
		var fileOut = File.write(outPath, true);
		try
		{
			fileOut.writeFullBytes(data, 0, data.length);
		}
		catch (e:Dynamic)
		{
			fileOut.close();
			throw e;
		}
		fileOut.close();
		writtenFiles.push(safeRel);
	}

	function readEntryData(input:FileInput, entry:ZipEntry):haxe.io.Bytes
	{
		// Local header: 30 bytes + name + extra; data starts right after.
		input.seek(entry.localOffset, sys.io.FileSeek.SeekBegin);
		var locHead = input.read(30);
		if (locHead.getUInt16(0) != 0x4b50 || locHead.getUInt16(2) != 0x0403)
			throw 'Corrupt local header for "' + entry.name + '"';
		var nameLen:Int = locHead.getUInt16(26);
		var extraLen:Int = locHead.getUInt16(28);
		input.seek(entry.localOffset + 30 + nameLen + extraLen, sys.io.FileSeek.SeekBegin);

		var raw:haxe.io.Bytes = entry.compSize > 0 ? input.read(entry.compSize) : haxe.io.Bytes.alloc(0);

		var out:haxe.io.Bytes;
		switch (entry.method)
		{
			case 0: // stored
				out = raw;

			case 8: // deflated — native zlib via lime
				out = if (raw.length == 0)
					haxe.io.Bytes.alloc(0)
				else
					lime.utils.Bytes.fromBytes(raw).decompress(lime.utils.CompressionAlgorithm.DEFLATE);
				if (out == null)
					throw 'Failed to decompress "' + entry.name + '"';

			default:
				throw 'Unsupported ZIP compression method ' + entry.method + ' for "' + entry.name + '"';
		}

		if (entry.uncompSize >= 0 && out.length != entry.uncompSize)
			throw 'Size mismatch for "' + entry.name + '" (expected ' + entry.uncompSize + ', got ' + out.length + ')';
		return out;
	}

	function sendMessage(msg:Dynamic):Void
	{
		#if (cpp || neko || hl)
		if (mainThread != null) mainThread.sendMessage(msg);
		#end
	}

	function handleMessage(msg:Dynamic):Void
	{
		switch (msg.t)
		{
			case 'prog':
				done = msg.done;
				total = msg.total;
				currentFile = msg.cur;

			case 'done':
				finished = true;
				writtenFiles = msg.files;

			case 'err':
				error = msg.err;
				finished = true;

			case 'canceled':
				finished = true;

			default:
		}
	}

}

typedef ZipEntry =
{
	var name:String;
	var isDirectory:Bool;
	var method:Int;
	var compSize:Int;
	var uncompSize:Int;
	var localOffset:Int;
	var crc32:Int;
	var flags:Int;
}
