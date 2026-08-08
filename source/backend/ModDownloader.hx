package backend;

import haxe.io.Bytes;
import lime.app.Future;
import lime.net.HTTPRequest;
import lime.net.HTTPRequestHeader;
import lime.net.HTTPRequestMethod;
import sys.FileSystem;
import sys.io.File;

/**
 * Multi-connection chunked downloader built on top of lime.net.HTTPRequest
 * (libcurl, bundled with lime). All callbacks are dispatched on the main
 * thread by lime's ThreadPool, so file IO and UI updates are safe there.
 *
 * Strategy:
 *  1. Probe with HEAD to learn Content-Length / Accept-Ranges / filename.
 *  2. If the server supports byte ranges and the file is big enough, split it
 *     into fixed-size chunks and download up to MAX_CONNECTIONS chunks in
 *     parallel (real multi-threaded download), writing each chunk at its
 *     offset. Memory stays bounded (CHUNK_SIZE x MAX_CONNECTIONS).
 *  3. Otherwise fall back to a single full download.
 */
class ModDownloader
{
	public static inline var CHUNK_SIZE:Int = 4 * 1024 * 1024; // 4 MB
	public static inline var MAX_CONNECTIONS:Int = 4;
	public static inline var MIN_CHUNKED_SIZE:Int = 2 * 1024 * 1024; // 2 MB

	public var url(default, null):String;
	public var destPath(default, null):String;
	public var totalSize:Int = -1;
	public var downloaded:Int = 0;
	public var supportsRanges:Bool = false;
	public var finished(default, null):Bool = false;
	public var canceled(default, null):Bool = false;
	public var error(default, null):String = null;

	/** Filename hint from Content-Disposition, if any. */
	public var remoteFileName(default, null):String = null;
	/** Number of chunks used for the current download (diagnostics). */
	public var lastChunkCount(default, null):Int = 0;

	var chunks:Array<Chunk>;
	var nextChunkIndex:Int = 0;
	var activeRequests:Array<HTTPRequest<Bytes>> = [];
	var chunkedAborted:Bool = false;
	var probeDone:Bool = false;
	var probeFailed:Bool = false;
	var onProgressCb:Int->Int->Void;
	var onDoneCb:Void->Void;
	var onErrorCb:String->Void;

	public function new(url:String, destPath:String)
	{
		this.url = url;
		this.destPath = destPath;
	}

	public function start(?onProgress:Int->Int->Void, ?onDone:Void->Void, ?onError:String->Void):Void
	{
		if (probeDone || finished || canceled) return;
		onProgressCb = onProgress;
		onDoneCb = onDone;
		onErrorCb = onError;

		// Make sure the destination directory exists.
		var dir = haxe.io.Path.directory(destPath);
		if (dir.length > 0 && !FileSystem.exists(dir)) FileSystem.createDirectory(dir);

		probeWithHead();
	}

	/** Best-effort cancellation; in-flight curl transfers may take a moment. */
	public function cancel():Void
	{
		if (canceled || finished) return;
		canceled = true;
		for (req in activeRequests)
			req.cancel();
		activeRequests = [];
	}

	// ------------------------------------------------------------------
	// Probe
	// ------------------------------------------------------------------

	function probeWithHead():Void
	{
		var req = new HTTPRequest<Bytes>(url);
		req.method = HEAD;
		req.followRedirects = true;
		req.enableResponseHeaders = true;
		req.timeout = 15000;
		req.userAgent = "SeiunEngine-ModInstaller/0.1";

		activeRequests.push(req);
		req.load().onComplete(function(_) {
			activeRequests.remove(req);
			probeDone = true;
			parseProbeHeaders(req);
			if (req.responseStatus == 200 || req.responseStatus == 206)
			{
				if (!supportsRanges)
				{
					// Server did not advertise range support (no Accept-Ranges).
					// Probe with a GET + Range to find out for real.
					probeWithGet();
				}
				else
				{
					decideDownloadMode();
				}
			}
			else
			{
				probeWithGet();
			}
		}).onError(function(e) {
			activeRequests.remove(req);
			probeDone = true;
			probeFailed = true;
			probeWithGet();
		});
	}

	function probeWithGet():Void
	{
		// GET with Range: bytes=0-0 — either the server answers 206 (ranges OK)
		// or it ignores the range and returns the whole body, which we can save
		// directly as a complete single-shot download.
		var req = new HTTPRequest<Bytes>(url);
		req.method = GET;
		req.followRedirects = true;
		req.enableResponseHeaders = true;
		req.timeout = 15000;
		req.userAgent = "SeiunEngine-ModInstaller/0.1";
		req.headers.push(new HTTPRequestHeader("Range", "bytes=0-0"));
		req.headers.push(new HTTPRequestHeader("Accept-Encoding", "identity"));

		activeRequests.push(req);
		req.load().onComplete(function(body:Bytes) {
			activeRequests.remove(req);
			probeDone = true;
			parseProbeHeaders(req);

			if (req.responseStatus == 206 && supportsRanges && totalSize > 0)
			{
				decideDownloadMode();
				return;
			}

			// Server ignored the range: the body IS the whole file.
			totalSize = body.length;
			supportsRanges = false;
			try
			{
				File.saveBytes(destPath, body);
				downloaded = body.length;
				notifyProgress();
				finishOk();
			}
			catch (e:Dynamic)
			{
				fail('Failed to write downloaded file: ' + Std.string(e));
			}
		}).onError(function(e) {
			activeRequests.remove(req);
			probeDone = true;
			fail('Download failed: ' + Std.string(e));
		});
	}

	function parseProbeHeaders(req:HTTPRequest<Bytes>):Void
	{
		for (h in req.responseHeaders)
		{
			var name:String = h.name.toLowerCase();
			var value:String = h.value;
			switch (name)
			{
				case "content-length":
					if (totalSize < 0)
						totalSize = Std.parseInt(value);

				case "accept-ranges":
					supportsRanges = (value.toLowerCase() == "bytes");

				case "content-range":
					// bytes 0-0/TOTAL
					var m = ~/bytes\s+\d+-\d+\/(\d+|\*)/i;
					if (m.match(value) && m.matched(1) != "*")
						totalSize = Std.parseInt(m.matched(1));

				case "content-disposition":
					var fm = ~/filename\*?=(?:UTF-8''|")?([^";]+)/i;
					if (fm.match(value))
						remoteFileName = StringTools.replace(fm.matched(1), '"', '');
			}
		}
	}

	// ------------------------------------------------------------------
	// Download modes
	// ------------------------------------------------------------------

	function decideDownloadMode():Void
	{
		if (canceled) return;

		if (supportsRanges && totalSize >= MIN_CHUNKED_SIZE)
		{
			// If the probe got a 206 for bytes 0-0, the first chunk of the
			// real download is already paid for — reuse it as chunk 0.
			var chunkCount:Int = Std.int(Math.ceil(totalSize / CHUNK_SIZE));
			lastChunkCount = chunkCount;
			chunks = [];
			chunkedAborted = false;
			for (i in 0...chunkCount)
			{
				var start:Int = i * CHUNK_SIZE;
				var end:Int = Std.int(Math.min(totalSize - 1, start + CHUNK_SIZE - 1));
				chunks.push({start: start, end: end});
			}
			nextChunkIndex = 0;
			for (i in 0...MAX_CONNECTIONS)
				launchNextChunk();
		}
		else
		{
			downloadWhole();
		}
	}

	function launchNextChunk():Void
	{
		if (canceled || finished || chunkedAborted || nextChunkIndex >= chunks.length) return;
		var chunk = chunks[nextChunkIndex++];

		var req = new HTTPRequest<Bytes>(url);
		req.method = GET;
		req.followRedirects = true;
		req.timeout = 30000;
		req.userAgent = "SeiunEngine-ModInstaller/0.1";
		req.headers.push(new HTTPRequestHeader("Range", 'bytes=${chunk.start}-${chunk.end}'));
		req.headers.push(new HTTPRequestHeader("Accept-Encoding", "identity"));

		activeRequests.push(req);
		req.load().onComplete(function(body:Bytes) {
			activeRequests.remove(req);
			if (canceled || finished || chunkedAborted) return;

			if (req.responseStatus != 206)
			{
				// Range support vanished mid-download — restart with a single stream.
				cancelChunked();
				supportsRanges = false;
				downloadWhole();
				return;
			}

			try
			{
				writeAt(destPath, body, chunk.start);
				downloaded += body.length;
				notifyProgress();
				launchNextChunk();
				checkFinished();
			}
			catch (e:Dynamic)
			{
				fail('Failed to write chunk: ' + Std.string(e));
			}
		}).onError(function(e) {
			activeRequests.remove(req);
			if (canceled || finished || chunkedAborted) return;
			fail('Download failed: ' + Std.string(e));
		});
	}

	function downloadWhole():Void
	{
		var req = new HTTPRequest<Bytes>(url);
		req.method = GET;
		req.followRedirects = true;
		req.timeout = 30000;
		req.userAgent = "SeiunEngine-ModInstaller/0.1";
		req.headers.push(new HTTPRequestHeader("Accept-Encoding", "identity"));

		activeRequests.push(req);
		req.load().onComplete(function(body:Bytes) {
			activeRequests.remove(req);
			if (canceled) return;
			try
			{
				File.saveBytes(destPath, body);
				downloaded = body.length;
				if (totalSize <= 0) totalSize = body.length;
				notifyProgress();
				finishOk();
			}
			catch (e:Dynamic)
			{
				fail('Failed to write downloaded file: ' + Std.string(e));
			}
		}).onError(function(e) {
			activeRequests.remove(req);
			if (canceled) return;
			fail('Download failed: ' + Std.string(e));
		});
	}

	function cancelChunked():Void
	{
		chunkedAborted = true;
		for (req in activeRequests)
			req.cancel();
		activeRequests = [];
		chunks = null;
		nextChunkIndex = 0;
	}

	function checkFinished():Void
	{
		if (canceled || finished) return;
		if (activeRequests.length == 0 && nextChunkIndex >= chunks.length)
			finishOk();
	}

	// ------------------------------------------------------------------
	// Helpers
	// ------------------------------------------------------------------

	static function writeAt(path:String, bytes:Bytes, offset:Int):Void
	{
		// File.update: read-write mode WITHOUT truncation (File.write would
		// wipe the file on every chunk, breaking the multi-chunk reassembly).
		var out = File.update(path, true);
		try
		{
			out.seek(offset, sys.io.FileSeek.SeekBegin);
			out.writeFullBytes(bytes, 0, bytes.length);
		}
		catch (e:Dynamic)
		{
			out.close();
			throw e;
		}
		out.close();
	}

	function notifyProgress():Void
	{
		if (onProgressCb != null) onProgressCb(downloaded, totalSize);
	}

	function finishOk():Void
	{
		finished = true;
		if (onDoneCb != null) onDoneCb();
	}

	function fail(msg:String):Void
	{
		if (finished || canceled) return;
		error = msg;
		if (onErrorCb != null) onErrorCb(msg);
	}
}

typedef Chunk =
{
	var start:Int;
	var end:Int;
}
