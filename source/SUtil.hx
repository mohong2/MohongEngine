package;

import lime.system.System as LimeSystem;
#if android
import android.content.Context as AndroidContext;
import android.os.Environment as AndroidEnvironment;
import android.os.Build;
import android.Permissions as AndroidPermissions;
import android.Settings as AndroidSettings;
import android.Tools as AndroidTools;
#end
#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

/**
 * A storage class for mobile.
 * @author Mihai Alexandru (M.A. Jigsaw)
 */
class SUtil
{
	#if android
	static var cachedStorageType:String = null;
	static var cachedStoragePath:String = '';

	/**
	 * Version-aware default storage type:
	 * - Android 11+ (API 30+) without "All files access" cannot write to public
	 *   external storage, so we default to the app-specific directory which
	 *   never requires permissions.
	 * - Older Android (or when All-files access is granted) keeps the classic
	 *   public `.funkin` folder.
	 */
	public static function getDefaultStorageType():String
	{
		if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R && !AndroidEnvironment.isExternalStorageManager())
			return "EXTERNAL_DATA";
		return "EXTERNAL";
	}
	#end

	#if sys
	public static function getStorageDirectory(?force:Bool = false):String
	{
		var daPath:String = '';
		#if android
		// Priority: 1) ClientPrefs.storageType (user choice)  2) version-aware default  3) fallback chain
		var preferredType:String = ClientPrefs.data.storageType;
		if (preferredType == null || preferredType.length == 0)
			preferredType = getDefaultStorageType();

		// Cache the resolved path so Main.new() and TitleState agree on the same
		// location even before ClientPrefs is fully loaded.
		if (!force && cachedStorageType != null && cachedStorageType == preferredType && cachedStoragePath.length > 0)
			return cachedStoragePath;

		// Try preferred type first, then fallback chain
		var fallbackOrder:Array<String> = [preferredType, "EXTERNAL_DATA", "EXTERNAL", "INTERNAL", "EXTERNAL_OBB", "EXTERNAL_MEDIA"];
		// Deduplicate while preserving order
		var seen:Map<String, Bool> = [];
		var uniqueFallback:Array<String> = [];
		for (t in fallbackOrder) {
			if (!seen.exists(t)) { seen.set(t, true); uniqueFallback.push(t); }
		}

		var lastError:String = '';
		for (stType in uniqueFallback)
		{
			try {
				daPath = force ? StorageType.fromStrForce(stType) : StorageType.fromStr(stType);
				daPath = haxe.io.Path.addTrailingSlash(daPath);
				if (!FileSystem.exists(daPath))
					FileSystem.createDirectory(daPath);
				// Verify the directory is actually writable before committing to
				// it — public external storage silently fails on many Android
				// 11+ devices when "All files access" is missing, which used to
				// make asset extraction fail on some versions and work on others.
				if (!AndroidTools.isDirectoryWritable(daPath))
					throw 'Storage directory is not writable: $daPath';

				cachedStorageType = stType;
				cachedStoragePath = daPath;
				// Path works — save to ClientPrefs so next boot uses it
				if (ClientPrefs.data.storageType != stType)
				{
					ClientPrefs.data.storageType = stType;
					ClientPrefs.saveSettings();
				}
				lastError = '';
				break;
			} catch (e:Dynamic) {
				lastError = Std.string(e);
				continue;
			}
		}

		// All fallbacks failed — last resort
		if (lastError.length > 0)
		{
			daPath = LimeSystem.applicationStorageDirectory;
			try {
				if (!FileSystem.exists(daPath))
					FileSystem.createDirectory(daPath);
			} catch (_:Dynamic) {}
		}
		#elseif mac
		// macOS: .app 的资源全部位于 bundle 的 Contents/Resources 里
		// （assets/、mods/、lang/ 等），而代码里大量磁盘读取是相对路径。
		// 因此把工作/存储目录直接指向 Resources，行为与 Windows 一致。
		// 注意：应用若被放到系统保护目录（如 /Applications），bundle 内
		// 可能不可写；届时再改回 LimeSystem.applicationStorageDirectory。
		daPath = haxe.io.Path.directory(Sys.programPath()) + "/../Resources/";
		try {
			if (daPath == null || daPath.length == 0)
				daPath = LimeSystem.applicationDirectory;
			if (!FileSystem.exists(daPath))
				FileSystem.createDirectory(daPath);
		} catch (e:Dynamic) {}
		#elseif ios
		daPath = LimeSystem.documentsDirectory;
		#end

		return daPath;
	}

	public static function mkDirs(directory:String):Void
	{
		try {
			if (FileSystem.exists(directory) && FileSystem.isDirectory(directory))
				return;
		} catch (e:haxe.Exception) {
			CoolUtil.traceMsg('trace.folderError', 'Something went wrong while looking at folder. ({})', [e.message]);
		}

		var total:String = '';
		if (directory.substr(0, 1) == '/')
			total = '/';

		var parts:Array<String> = directory.split('/');
		if (parts.length > 0 && parts[0].indexOf(':') > -1)
			parts.shift();

		for (part in parts)
		{
			if (part != '.' && part != '')
			{
				if (total != '' && total != '/')
					total += '/';

				total += part;

				try
				{
					if (!FileSystem.exists(total))
						FileSystem.createDirectory(total);
				}
				catch (e:haxe.Exception)
					CoolUtil.traceMsg('trace.folderCreateError', 'Error while creating folder. ({})', [e.message]);
			}
		}
	}

	public static function saveContent(fileName:String = 'file', fileExtension:String = '.json',
			fileData:String = 'You forgor to add somethin\' in yo code :3'):Void
	{
		try
		{
			if (!FileSystem.exists('saves'))
				FileSystem.createDirectory('saves');

			File.saveContent('saves/' + fileName + fileExtension, fileData);
			showPopUp(fileName + " file has been saved.", "Success!");
		}
		catch (e:haxe.Exception)
			CoolUtil.traceMsg('trace.fileSaveError', 'File couldn\'t be saved. ({})', [e.message]);
	}

	#if android
	public static function doPermissionsShit():Void
	{
		try {
			var sdkInt = android.os.Build.VERSION.SDK_INT;

			var granted = AndroidPermissions.getGrantedPermissions();

			// Android 10 (API 29) and below: with requestLegacyExternalStorage
			// in the manifest, READ/WRITE_EXTERNAL_STORAGE grant full access to
			// the public /storage/emulated/0 root (no root needed).
			if (sdkInt <= android.os.Build.VERSION_CODES.Q)
			{
				if (!granted.contains('android.permission.WRITE_EXTERNAL_STORAGE'))
					AndroidPermissions.requestPermission('WRITE_EXTERNAL_STORAGE');
				if (!granted.contains('android.permission.READ_EXTERNAL_STORAGE'))
					AndroidPermissions.requestPermission('READ_EXTERNAL_STORAGE');
			}
			// Android 11+ (API 30+): MANAGE_EXTERNAL_STORAGE (All files access)
			// is a special permission - the normal request dialog cannot grant
			// it, so explain first, then open the system settings page. This
			// also runs on API 33+ so every user can keep the public root
			// (/storage/emulated/0/.SeiunEngine) without root. If the user
			// declines, storage falls back to the app-specific directory
			// automatically (game still works, mods just need another path).
			else if (sdkInt >= android.os.Build.VERSION_CODES.R)
			{
				if (!AndroidEnvironment.isExternalStorageManager())
				{
					try
					{
						backend.Dialog.showYesNo(
							'需要"所有文件访问"权限',
							'为了让所有安卓用户都能把模组/存档放进公开目录'
							+ '（无需 root，文件管理器可直接访问），'
							+ '请授予"所有文件访问"权限。\n\n'
							+ '如果拒绝，游戏会改用应用专属目录，'
							+ '模组安装会变得麻烦。',
							function() AndroidSettings.requestSetting('MANAGE_APP_ALL_FILES_ACCESS_PERMISSION'),
							function() {}
						);
					}
					catch (e:Dynamic)
					{
						AndroidSettings.requestSetting('MANAGE_APP_ALL_FILES_ACCESS_PERMISSION');
					}
				}
			}

			// Android 13+ notification permission
			if (sdkInt >= android.os.Build.VERSION_CODES.TIRAMISU && !granted.contains('android.permission.POST_NOTIFICATIONS'))
				AndroidPermissions.requestPermission('POST_NOTIFICATIONS');

			try {
				var finalPath = SUtil.getStorageDirectory();
				if (!FileSystem.exists(finalPath))
					FileSystem.createDirectory(finalPath);
			} catch (e:Dynamic) {
				try {
					var fallbackPath = StorageType.fromStr("EXTERNAL_DATA");
					if (!FileSystem.exists(fallbackPath))
						FileSystem.createDirectory(fallbackPath);
				} catch (e2:Dynamic) {
					showPopUp('Please create folder to\n' + SUtil.getStorageDirectory(true) + '\nPress OK to close the game', 'Error!');
					LimeSystem.exit(1);
				}
			}
		} catch (e:Dynamic) {
			// 捕获所有异常，避免崩溃
			CoolUtil.traceMsg('trace.permissionsError', 'Permissions error: {}', [Std.string(e)]);
			showPopUp('Permission error occurred. Please grant storage permissions manually.', 'Error');
		}
	}

	public static function checkExternalPaths(?splitStorage = false):Array<String> {
		var paths:Array<String> = [];
		#if android
		try {
			// Read /proc/mounts directly instead of shelling out to `grep`/`paste`
			// — those binaries are missing or sandboxed on several devices/ROMs.
			var mounts:String = File.getContent('/proc/mounts');
			for (line in mounts.split('\n'))
			{
				var idx = line.indexOf('/storage/');
				if (idx < 0) continue;
				var after = line.substr(idx);
				var end = after.indexOf(' ');
				var path:String = (end > 0) ? after.substr(0, end) : after;
				path = path.trim();
				if (path.length > 0 && !paths.contains(path))
					paths.push(path);
			}
		} catch (e:Dynamic) {}

		if (paths.length == 0)
		{
			var primary = AndroidEnvironment.getExternalStorageDirectory();
			if (primary != null && primary.length > 0)
				paths.push(primary);
		}
		#end

		if (splitStorage)
			for (i in 0...paths.length)
				paths[i] = paths[i].replace('/storage/', '');

		return paths;
	}

	public static function getExternalDirectory(external:String):String {
		var daPath:String = '';
		for (path in checkExternalPaths())
			if (path.contains(external)) daPath = path;

		daPath = haxe.io.Path.addTrailingSlash(daPath.endsWith("\n") ? daPath.substr(0, daPath.length - 1) : daPath);
		return daPath;
	}
	#end
	#end
	public static function showPopUp(message:String, title:String):Void
	{
		backend.Dialog.show(title, message);
	}
}

#if android
enum abstract StorageType(String) from String to String
{
	final forcedPath = '/storage/emulated/0/';

	public static function fromStr(str:String):StorageType
	{
		final packageName = lime.app.Application.current.meta.get('packageName');
		final file = lime.app.Application.current.meta.get('file');
		
		final EXTERNAL_DATA = AndroidContext.getExternalFilesDir();
		final EXTERNAL_OBB = AndroidContext.getObbDir();
		final EXTERNAL_MEDIA = AndroidEnvironment.getExternalStorageDirectory() + '/Android/media/' + packageName;
		final EXTERNAL = AndroidEnvironment.getExternalStorageDirectory() + '/.' + file;
		final INTERNAL = AndroidContext.getFilesDir();

		return switch (str)
		{
			case "EXTERNAL_DATA": EXTERNAL_DATA;
			case "EXTERNAL_OBB": EXTERNAL_OBB;
			case "EXTERNAL_MEDIA": EXTERNAL_MEDIA;
			case "EXTERNAL": EXTERNAL;
			case "INTERNAL": INTERNAL;
			default: SUtil.getExternalDirectory(str) + '.' + file;
		}
	}

	public static function fromStrForce(str:String):StorageType
	{
		final packageName = lime.app.Application.current.meta.get('packageName');
		final file = lime.app.Application.current.meta.get('file');
		
		final EXTERNAL_DATA = forcedPath + 'Android/data/' + packageName + '/files';
		final EXTERNAL_OBB = forcedPath + 'Android/obb/' + packageName;
		final EXTERNAL_MEDIA = forcedPath + 'Android/media/' + packageName;
		final EXTERNAL = forcedPath + '.' + file;
		final INTERNAL = AndroidContext.getFilesDir();

		return switch (str)
		{
			case "EXTERNAL_DATA": EXTERNAL_DATA;
			case "EXTERNAL_OBB": EXTERNAL_OBB;
			case "EXTERNAL_MEDIA": EXTERNAL_MEDIA;
			case "EXTERNAL": EXTERNAL;
			case "INTERNAL": INTERNAL;
			default: SUtil.getExternalDirectory(str) + '.' + file;
		}
	}
}
#end
