package backend;

import flixel.FlxG;
import haxe.io.Path;
import mohong.TraceManager;
import openfl.Lib;
import states.MainMenuState;
import states.ModState;
import states.ModsMenuState;
import states.ModsMenuStateOld;
import substates.ModSelectSubstate;
import sys.FileSystem;
import sys.io.File;
import backend.ZipReader;
import backend.ModZipPlanner;

using StringTools;

/**
 * Drop-to-install manager.
 *
 *  - listens to the lime window's onDropFile event (SDL drag & drop)
 *  - .zip       -> analyze -> extract -> install into mods/
 *  - folder     -> copy into mods/
 *  - http(s) URL or .url file / text file containing a URL -> download
 *    (multi-connection chunked downloader) -> auto-install if the result
 *    is a ZIP archive
 *
 * The matching UI is ModInstallUI (a FlxSubState). ModInstaller.update() is
 * pumped from MusicBeatState/MusicBeatSubstate so drops work in every state.
 */
class ModInstaller
{
	static var instance:ModInstaller;

	public static function get():ModInstaller
	{
		if (instance == null) instance = new ModInstaller();
		return instance;
	}

	/** Register the window drop listener (called once from Main). */
	public static function init():Void
	{
		#if desktop
		get().hookWindow();
		#end
	}

	/** Per-frame pump (called from MusicBeatState / MusicBeatSubstate). */
	public static function update(elapsed:Float):Void
	{
		#if desktop
		get().pump(elapsed);
		#end
	}

	// ------------------------------------------------------------------
	// Public UI state (read by ModInstallUI)
	// ------------------------------------------------------------------

	public var busy:Bool = false;
	public var showPrompt:Bool = false;
	public var promptMessage:String = '';
	public var promptDefault:String = '';
	public var title:String = '';
	public var status:String = '';
	public var detailText:String = '';
	public var progress:Float = 0; // 0..1
	public var indeterminate:Bool = false;
	public var showResult:Bool = false;
	public var resultMessage:String = '';
	public var canCancel:Bool = false;

	// ------------------------------------------------------------------
	// Internal
	// ------------------------------------------------------------------

	var hooked:Bool = false;
	var ui:ModInstallUI;
	var extractor:ZipExtractor;
	var tempRoot:String;
	var pendingJobs:Array<InstallJob>;
	var promptJobIndex:Int = -1;
	var installedNames:Array<String> = [];
	var downloader:ModDownloader;
	var zipBaseName:String;
	var pendingDrop:String = null;

	function new() {}

	function hookWindow():Void
	{
		if (hooked) return;
		hooked = true;
		try
		{
			var window = Lib.application.window;
			window.onDropFile.add(onDropFile);
			TraceManager.info('modInstaller.hook', 'Mod drop-to-install listening (window.onDropFile).');
		}
		catch (e:Dynamic)
		{
			TraceManager.error('modInstaller.hookError', 'Failed to hook drop events: {}', [Std.string(e)]);
		}
	}

	function pump(elapsed:Float):Void
	{
		if (pendingDrop != null && FlxG.state != null)
		{
			var p:String = pendingDrop;
			pendingDrop = null;
			onDropFile(p);
		}

		// Drain background-extraction progress/result messages.
		if (extractor != null)
		{
			extractor.pumpMessages();
			if (extractor.error != null)
			{
				var msg:String = extractor.error;
				extractor = null;
				abortTask('解压失败：' + msg);
			}
			else if (extractor.finished)
			{
				var willPrompt:Bool = extractor.pendingPrompt;
				extractor = null;
				onExtractionDone(willPrompt);
			}
			else if (extractor.total > 0)
			{
				progress = extractor.done / extractor.total;
				indeterminate = false;
				status = '正在解压… (' + extractor.done + '/' + extractor.total + ')';
				detailText = extractor.currentFile;
			}
		}
	}

	// ------------------------------------------------------------------
	// Drop handling
	// ------------------------------------------------------------------

	function onDropFile(path:String):Void
	{
		if (path == null || StringTools.trim(path).length == 0) return;
		path = StringTools.trim(path);
		TraceManager.info('modInstaller.drop', 'Dropped: {}', [path]);

		if (FlxG.state == null)
		{
			// Game not fully started yet — queue it and process next frame.
			pendingDrop = path;
			return;
		}

		if (!isAllowedContext())
		{
			showMessage('这里不能用', '拖放安装只在主菜单 / Mod 选择界面生效喵～\n（游戏中请先回主菜单）');
			return;
		}

		if (busy)
		{
			showMessage('任务进行中', '已经有任务在跑啦，等它完成再拖新的喵～');
			return;
		}

		// 1. The dropped string itself is a URL (SDL may deliver link text)
		if (looksLikeUrl(path))
		{
			startUrlDownload(path);
			return;
		}

		// 2. Directory -> copy as mod
		if (FileSystem.exists(path) && FileSystem.isDirectory(path))
		{
			installFolder(path);
			return;
		}

		// 3. ZIP archives (check before the existence fallback below)
		var lower:String = path.toLowerCase();
		if (FileSystem.exists(path) && (lower.endsWith('.zip') || ZipReader.isZipFile(path)))
		{
			startZip(path);
			return;
		}

		// 4. The OS handed us a path that does not exist — this is often a
		//    dragged browser link delivered as URL text or a virtual .url file.
		if (!FileSystem.exists(path))
		{
			if (looksLinky(path))
			{
				startUrlDownload(path);
				return;
			}
			showMessage('无法读取', '找不到这个文件喵：\n' + path + '\n\n如果是链接，试试直接复制 URL 再拖一次。');
			return;
		}

		// 5. Internet shortcut (.url) — parse even if the extension is unusual
		if (lower.endsWith('.url'))
		{
			startUrlFile(path);
			return;
		}

		// 6. Unsupported archive formats
		if (lower.endsWith('.rar') || lower.endsWith('.7z') || lower.endsWith('.tar')
			|| lower.endsWith('.gz') || lower.endsWith('.bz2') || lower.endsWith('.xz'))
		{
			showMessage('暂不支持', '这个格式还没法自动安装（只支持 .zip）喵：\n' + Path.withoutDirectory(path));
			return;
		}

		// 7. Small text files that contain a link (.txt / .html / unknown /
		//    virtual .url files with unexpected names)
		var urlFromText:String = readUrlFromTextFile(path);
		if (urlFromText != null)
		{
			startUrlDownload(urlFromText);
			return;
		}

		showMessage('不支持的文件', '把 .zip 压缩包或 http/https 链接拖进来才能自动安装喵～');
	}

	/** The drag&drop feature is only active on the main menu / mod select screens. */
	function isAllowedContext():Bool
	{
		var state:flixel.FlxState = FlxG.state;
		if (Std.isOfType(state, MainMenuState)) return true;
		if (Std.isOfType(state, ModsMenuState)) return true;
		if (Std.isOfType(state, ModsMenuStateOld)) return true;
		if (Std.isOfType(state, ModState)) return true;

		// Mod select popup may sit on top of any menu state.
		var sub:flixel.FlxSubState = state.subState;
		while (sub != null)
		{
			if (Std.isOfType(sub, ModSelectSubstate)) return true;
			sub = sub.subState;
		}
		return false;
	}

	// ------------------------------------------------------------------
	// ZIP install
	// ------------------------------------------------------------------

	function startZip(zipPath:String):Void
	{
		if (!ZipReader.isZipFile(zipPath))
		{
			showMessage('不是有效的压缩包', '这个文件看起来不是 ZIP 喵：\n' + Path.withoutDirectory(zipPath));
			return;
		}

		busy = true;
		zipBaseName = ModZipPlanner.sanitizeName(Path.withoutExtension(Path.withoutDirectory(zipPath)));

		var entries:Array<ZipEntry>;
		try
		{
			entries = ZipReader.readEntries(zipPath);
		}
		catch (e:Dynamic)
		{
			busy = false;
			showMessage('解析失败', '无法读取这个压缩包喵：\n' + Std.string(e));
			return;
		}

		if (entries.length == 0)
		{
			busy = false;
			showMessage('空压缩包', '这个压缩包里什么都没有喵。');
			return;
		}

		// Decide the install plan up-front (fast, metadata only).
		var plan = ModZipPlanner.analyze(entries);
		if (plan == null)
		{
			busy = false;
			showMessage('无法安装', '压缩包里没有看起来像 mod 的内容喵。');
			return;
		}

		tempRoot = Sys.getCwd() + 'temp/mods-install/' + Date.now().getTime() + '/';
		installedNames = [];

		// Fill empty names with the zip base name (loose mod content at zip root).
		for (job in plan.jobs)
		{
			if (job.name == null || job.name.length == 0)
				job.name = zipBaseName;
		}

		if (plan.promptForName)
		{
			// Extract first, ask for the name afterwards (so the temp tree exists).
			pendingJobs = plan.jobs;
			promptJobIndex = plan.promptIndex;
			promptDefault = plan.promptDefault;
			promptMessage = '压缩包里有一层叫 "mods" 的文件夹，请给它起个名字：';
			beginExtraction(zipPath, true);
		}
		else
		{
			pendingJobs = plan.jobs;
			promptJobIndex = -1;
			beginExtraction(zipPath, false);
		}
	}

	function beginExtraction(zipPath:String, willPrompt:Bool):Void
	{
		openUI();
		showPrompt = false;
		showResult = false;
		canCancel = true;
		title = '安装 Mod';
		status = '正在解压…';
		indeterminate = true;
		progress = 0;

		try
		{
			extractor = new ZipExtractor(zipPath);
			extractor.pendingPrompt = willPrompt;
			extractor.start(tempRoot);
			detailText = '';
		}
		catch (e:Dynamic)
		{
			abortTask('解压失败：' + Std.string(e));
		}
	}

	function onExtractionDone(willPrompt:Bool):Void
	{
		if (willPrompt)
		{
			// Show the naming prompt; install continues after confirmName().
			showPrompt = true;
			canCancel = true;
			title = '给 mod 起个名字';
			status = '';
			indeterminate = false;
			if (ui != null) ui.focusInput();
			return;
		}

		runInstallJobs();
	}

	/** Called by ModInstallUI when the player confirms a name. */
	public function confirmName(rawName:String):Void
	{
		if (!busy || pendingJobs == null) return;
		var name:String = ModZipPlanner.sanitizeName(rawName);
		if (name.length == 0)
		{
			if (ui != null) ui.showPromptError('名字不能为空或包含非法字符，再试一次喵～');
			return;
		}

		if (promptJobIndex >= 0 && promptJobIndex < pendingJobs.length)
			pendingJobs[promptJobIndex].name = name;
		showPrompt = false;
		runInstallJobs();
	}

	/** Called by ModInstallUI when the player cancels the naming prompt. */
	public function cancelPrompt():Void
	{
		abortTask('已取消安装。');
	}

	// ------------------------------------------------------------------
	// Install execution
	// ------------------------------------------------------------------

	function runInstallJobs():Void
	{
		if (pendingJobs == null || pendingJobs.length == 0)
		{
			abortTask('没有可安装的内容喵。');
			return;
		}

		var modsDir:String = Sys.getCwd() + 'mods';
		if (!FileSystem.exists(modsDir)) FileSystem.createDirectory(modsDir);

		title = '安装 Mod';
		status = '正在安装…';
		indeterminate = true;
		showPrompt = false;
		canCancel = false;

		installedNames = [];
		var failed:Array<String> = [];
		var total:Int = pendingJobs.length;
		var done:Int = 0;

		for (job in pendingJobs)
		{
			if (job.name == null || StringTools.trim(job.name).length == 0)
			{
				failed.push(job.src);
				done++;
				continue;
			}

			var srcPath:String = job.src.length == 0 ? tempRoot : tempRoot + job.src;
			if (!FileSystem.exists(srcPath))
			{
				failed.push(job.name);
				done++;
				continue;
			}

			var targetName:String = uniqueModName(modsDir, job.name);
			var targetPath:String = modsDir + '/' + targetName;
			try
			{
				moveInto(srcPath, targetPath);
				installedNames.push(targetName);
				addToModsList(targetName);
			}
			catch (e:Dynamic)
			{
				failed.push(job.name + ' (' + Std.string(e) + ')');
			}

			done++;
			progress = done / total;
			status = '正在安装… (' + done + '/' + total + ')';
		}

		cleanupTemp();
		pendingJobs = null;
		busy = false;

		var msg:String = '';
		if (installedNames.length > 0)
			msg += '已安装：' + installedNames.join('、') + '\n';
		if (failed.length > 0)
			msg += '以下内容安装失败：' + failed.join('、') + '\n';
		msg += '\n去 mod 菜单里选中就能用啦喵！';
		showMessage('安装完成', msg);
	}

	function uniqueModName(modsDir:String, base:String):String
	{
		var name:String = ModZipPlanner.sanitizeName(base);
		var candidate:String = name;
		var i:Int = 1;
		while (FileSystem.exists(modsDir + '/' + candidate))
		{
			candidate = name + ' (' + i + ')';
			i++;
		}
		return candidate;
	}

	/** Move a file/directory; falls back to recursive copy when rename is not possible. */
	static function moveInto(src:String, dst:String):Void
	{
		if (FileSystem.isDirectory(src))
		{
			try
			{
				FileSystem.rename(src, dst);
				return;
			}
			catch (e:Dynamic)
			{
				copyDir(src, dst);
				deleteDirRecursive(src);
			}
		}
		else
		{
			try
			{
				FileSystem.rename(src, dst);
			}
			catch (e:Dynamic)
			{
				File.copy(src, dst);
				FileSystem.deleteFile(src);
			}
		}
	}

	static function copyDir(src:String, dst:String):Void
	{
		if (!FileSystem.exists(dst)) FileSystem.createDirectory(dst);
		for (entry in FileSystem.readDirectory(src))
		{
			var s:String = src + '/' + entry;
			var d:String = dst + '/' + entry;
			if (FileSystem.isDirectory(s))
				copyDir(s, d);
			else
				File.copy(s, d);
		}
	}

	/** Delete a directory tree; only allowed under our own temp install root. */
	static function deleteDirRecursive(path:String):Void
	{
		if (!FileSystem.exists(path) || !FileSystem.isDirectory(path)) return;
		var cwd:String = Sys.getCwd();
		var tempBase:String = cwd + 'temp/mods-install';
		if (path != tempBase && path.indexOf(tempBase + '/') != 0)
		{
			TraceManager.warn('modInstaller.safeDelete', 'Refusing to delete outside temp: {}', [path]);
			return;
		}
		for (entry in FileSystem.readDirectory(path))
		{
			var full:String = path + '/' + entry;
			if (FileSystem.isDirectory(full))
				deleteDirRecursive(full);
			else
				FileSystem.deleteFile(full);
		}
		FileSystem.deleteDirectory(path);
	}

	function cleanupTemp():Void
	{
		if (tempRoot != null && tempRoot.length > 0)
		{
			deleteDirRecursive(tempRoot);
			tempRoot = null;
		}
	}

	function addToModsList(modName:String):Void
	{
		try
		{
			var listPath:String = Sys.getCwd() + 'modsList.txt';
			var existing:Array<String> = [];
			if (FileSystem.exists(listPath))
				existing = CoolUtil.coolTextFile(listPath);

			var found:Bool = false;
			for (line in existing)
			{
				var parts:Array<String> = line.split('|');
				if (parts.length >= 1 && parts[0] == modName) found = true;
			}
			if (found) return;

			var out = File.append(listPath, true);
			try
			{
				out.writeString(modName + '|' + modName + '\n');
			}
			catch (e:Dynamic)
			{
				out.close();
				throw e;
			}
			out.close();
		}
		catch (e:Dynamic)
		{
			TraceManager.warn('modInstaller.modsList', 'Could not update modsList.txt: {}', [Std.string(e)]);
		}
	}

	// ------------------------------------------------------------------
	// Folder drop
	// ------------------------------------------------------------------

	function installFolder(folderPath:String):Void
	{
		var modsDir:String = Sys.getCwd() + 'mods';
		if (!FileSystem.exists(modsDir)) FileSystem.createDirectory(modsDir);

		var absSrc:String = haxe.io.Path.normalize(folderPath);
		var absMods:String = haxe.io.Path.normalize(modsDir);
		if (absSrc == absMods || absSrc.indexOf(absMods + '/') == 0 || absSrc.indexOf(absMods + '\\') == 0)
		{
			showMessage('不需要', '这就是 mods 文件夹本身喵，拖别的来～');
			return;
		}

		busy = true;
		openUI();
		title = '安装 Mod';
		status = '正在复制文件夹…';
		indeterminate = true;
		canCancel = false;
		showPrompt = false;
		showResult = false;

		var baseName:String = ModZipPlanner.sanitizeName(Path.withoutDirectory(folderPath));
		var targetName:String = uniqueModName(modsDir, baseName);
		try
		{
			copyDir(folderPath, modsDir + '/' + targetName);
			addToModsList(targetName);
			busy = false;
			showMessage('安装完成', '已安装：' + targetName + '\n\n去 mod 菜单里选中就能用啦喵！');
		}
		catch (e:Dynamic)
		{
			busy = false;
			showMessage('复制失败', '复制文件夹时出错喵：\n' + Std.string(e));
		}
	}

	// ------------------------------------------------------------------
	// URL download
	// ------------------------------------------------------------------

	function startUrlFile(urlFilePath:String):Void
	{
		var url:String = extractUrlFromFile(urlFilePath);
		if (url != null)
		{
			startUrlDownload(url);
		}
		else
		{
			showMessage('无法识别', '这个 .url 文件里没有找到有效的链接喵。');
		}
	}

	function startUrlDownload(rawUrl:String):Void
	{
		var url:String = StringTools.trim(rawUrl);
		if (!looksLikeUrl(url))
		{
			showMessage('无效链接', '只支持 http:// 或 https:// 开头的链接喵。');
			return;
		}

		busy = true;
		var fileName:String = fileNameFromUrl(url);
		var destPath:String = Sys.getCwd() + 'downloads/' + fileName;
		if (FileSystem.exists(destPath)) destPath = uniqueFilePath(destPath);

		openUI();
		showPrompt = false;
		showResult = false;
		canCancel = true;
		title = '下载 Mod';
		status = '正在连接…';
		indeterminate = true;
		progress = 0;

		downloader = new ModDownloader(url, destPath);
		var lastBytes:Int = 0;
		var lastTime:Float = 0;
		var speed:Float = 0;
		downloader.start(
			function(loaded:Int, total:Int)
			{
				if (downloader == null) return;
				var now:Float = Sys.time();
				if (lastTime > 0)
				{
					var dt:Float = now - lastTime;
					if (dt >= 0.5)
					{
						speed = (loaded - lastBytes) / dt;
						lastBytes = loaded;
						lastTime = now;
					}
				}
				else
				{
					lastBytes = loaded;
					lastTime = now;
				}
				var speedText:String = speed > 0 ? ' (' + formatBytes(Std.int(speed)) + '/s)' : '';
				if (total > 0)
				{
					progress = loaded / total;
					indeterminate = false;
					status = '下载中… ' + formatBytes(loaded) + ' / ' + formatBytes(total) + speedText;
				}
				else
				{
					indeterminate = true;
					status = '下载中… ' + formatBytes(loaded) + speedText;
				}
			},
			function()
			{
				onDownloadDone();
			},
			function(err:String)
			{
				downloader = null;
				busy = false;
				showMessage('下载失败', err);
			}
		);
	}

	function onDownloadDone():Void
	{
		if (downloader == null) return; // task was canceled
		var zipPath:String = downloader.destPath;
		downloader = null;

		// Auto-install when the downloaded file is a ZIP.
		if (ZipReader.isZipFile(zipPath))
		{
			// Reuse the same UI (still open, busy state).
			startZip(zipPath);
		}
		else
		{
			busy = false;
			showMessage('下载完成', '已保存到 downloads/ 文件夹喵：\n' + Path.withoutDirectory(zipPath) + '\n\n（不是 zip，所以没有自动安装）');
		}
	}

	/** Called from ModInstallUI (cancel button / ESC during download). */
	public function cancelTask():Void
	{
		if (!busy) return;
		if (downloader != null)
		{
			downloader.cancel();
			downloader = null;
		}
		abortTask('已取消下载。');
	}

	// ------------------------------------------------------------------
	// Misc helpers
	// ------------------------------------------------------------------

	public function openUI():Void
	{
		if (ui != null && ui.exists) return;
		ui = new ModInstallUI();
		FlxG.state.openSubState(ui);
	}

	/** Called by ModInstallUI when it closes. */
	public function onUIClosed():Void
	{
		ui = null;
	}

	function showMessage(titleText:String, message:String):Void
	{
		openUI();
		this.title = titleText;
		this.resultMessage = message;
		this.showResult = true;
		this.showPrompt = false;
		this.canCancel = false;
		this.progress = 0;
		this.indeterminate = false;
		this.status = '';
	}

	function abortTask(message:String):Void
	{
		if (extractor != null)
		{
			extractor.requestCancel();
			extractor = null;
		}
		cleanupTemp();
		pendingJobs = null;
		busy = false;
		showPrompt = false;
		showMessage('已取消', message);
	}

	static function looksLikeUrl(text:String):Bool
	{
		return ~/^https?:\/\//i.match(StringTools.trim(text));
	}

	/** Paths that are not real files but still look like something link-ish. */
	static function looksLinky(text:String):Bool
	{
		var t:String = StringTools.trim(text);
		if (looksLikeUrl(t)) return true;
		if (~/^www\./i.match(t)) return true;
		if (t.indexOf("://") > 0) return true;
		return false;
	}

	static function readUrlFromTextFile(path:String):String
	{
		return extractUrlFromFile(path, 64 * 1024);
	}

	/** Extract an http(s) URL from a small text/shortcut file (UTF-8 or UTF-16). */
	static function extractUrlFromFile(path:String, maxSize:Int = 4096):String
	{
		if (!FileSystem.exists(path) || FileSystem.isDirectory(path)) return null;
		try
		{
			var size:Int = Std.int(FileSystem.stat(path).size);
			if (size <= 0 || size > maxSize) return null;
			var bytes = sys.io.File.getBytes(path);
			var content:String;
			if (bytes.length >= 2 && bytes.get(0) == 0xFF && bytes.get(1) == 0xFE)
				content = decodeUtf16(bytes, 2, false);
			else if (bytes.length >= 2 && bytes.get(0) == 0xFE && bytes.get(1) == 0xFF)
				content = decodeUtf16(bytes, 2, true);
			else
				content = bytes.getString(0, bytes.length);
			var m = ~/(https?:\/\/\S+)/i;
			if (m.match(content)) return m.matched(1);
		}
		catch (e:Dynamic) {}
		return null;
	}

	/** Minimal UTF-16 decode (URLs are ASCII, so char-code pairing is enough). */
	static function decodeUtf16(bytes:haxe.io.Bytes, start:Int, bigEndian:Bool):String
	{
		var buf = new StringBuf();
		var i:Int = start;
		while (i + 1 < bytes.length)
		{
			var code:Int = bigEndian
				? (bytes.get(i) << 8) | bytes.get(i + 1)
				: bytes.get(i) | (bytes.get(i + 1) << 8);
			buf.add(String.fromCharCode(code));
			i += 2;
		}
		return buf.toString();
	}

	static function fileNameFromUrl(url:String):String
	{
		var clean:String = url.split('?')[0].split('#')[0];
		var name:String = Path.withoutDirectory(clean);
		try
		{
			name = StringTools.urlDecode(name);
		}
		catch (e:Dynamic) {}
		name = ModZipPlanner.sanitizeName(name);
		if (name.length == 0 || name.indexOf('.') < 0)
			name = 'download.zip';
		return name;
	}

	static function uniqueFilePath(path:String):String
	{
		var dir:String = Path.directory(path);
		var name:String = Path.withoutExtension(Path.withoutDirectory(path));
		var ext:String = Path.extension(path);
		var i:Int = 1;
		var candidate:String = path;
		while (FileSystem.exists(candidate))
		{
			candidate = dir + '/' + name + ' (' + i + ').' + ext;
			i++;
		}
		return candidate;
	}

	static function formatBytes(bytes:Int):String
	{
		if (bytes < 1024) return bytes + ' B';
		if (bytes < 1024 * 1024) return Std.int(bytes / 1024) + ' KB';
		if (bytes < 1024 * 1024 * 1024)
		{
			var mb:Float = bytes / (1024 * 1024);
			return (Math.round(mb * 10) / 10) + ' MB';
		}
		var gb:Float = bytes / (1024 * 1024 * 1024);
		return (Math.round(gb * 100) / 100) + ' GB';
	}
}
