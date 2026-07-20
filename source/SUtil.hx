package;

import lime.system.System as LimeSystem;
#if android
import android.content.Context as AndroidContext;
import android.os.Environment as AndroidEnvironment;
import android.os.Build;
import android.Permissions as AndroidPermissions;
import android.Settings as AndroidSettings;
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
	#if sys
	public static function getStorageDirectory(?force:Bool = false):String
	{
		var daPath:String = '';
		#if android
		// Priority: 1) ClientPrefs.storageType (user choice)  2) EXTERNAL  3) fallback chain
		var preferredType:String = ClientPrefs.data.storageType;
		if (preferredType == null || preferredType.length == 0)
			preferredType = "EXTERNAL";

		// Try preferred type first, then fallback chain
		var fallbackOrder:Array<String> = [preferredType, "EXTERNAL_DATA", "EXTERNAL", "EXTERNAL_OBB", "EXTERNAL_MEDIA"];
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
			var hasReadStorage = granted.contains('android.permission.READ_EXTERNAL_STORAGE');
			var hasWriteStorage = granted.contains('android.permission.WRITE_EXTERNAL_STORAGE');

			var needLegacyStorage = !hasReadStorage || !hasWriteStorage;
			if (needLegacyStorage) {
				AndroidPermissions.requestPermission('READ_EXTERNAL_STORAGE');
				AndroidPermissions.requestPermission('WRITE_EXTERNAL_STORAGE');
			}

			if (sdkInt >= 30) {
				var hasManageStorage = granted.contains('android.permission.MANAGE_EXTERNAL_STORAGE');
				if (!hasManageStorage) {
					AndroidPermissions.requestPermission('MANAGE_EXTERNAL_STORAGE');
					if (!AndroidEnvironment.isExternalStorageManager()) {
						AndroidSettings.requestSetting('MANAGE_APP_ALL_FILES_ACCESS_PERMISSION');
					}
				}
			}

			if (sdkInt >= 33) {
				AndroidPermissions.requestPermission('READ_MEDIA_IMAGES');
				AndroidPermissions.requestPermission('READ_MEDIA_VIDEO');
				AndroidPermissions.requestPermission('READ_MEDIA_AUDIO');
				AndroidPermissions.requestPermission('POST_NOTIFICATIONS');
			}

			if (needLegacyStorage || sdkInt >= 30) {
				showPopUp('If you accepted the permissions you are all good!' + '\nIf you didn\'t then expect a crash' + '\nPress Ok to see what happens',
					'Notice!');
			}

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
		var process = new sys.io.Process('grep -o "/storage/....-...." /proc/mounts | paste -sd \',\'');
		var paths:String = process.stdout.readAll().toString();
		if (splitStorage) paths = paths.replace('/storage/', '');
		return paths.split(',');
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
		#if android
		backend.Dialog.show(title, message);
		#elseif !ios
		try
		{
			flixel.FlxG.stage.window.alert(message, title);
		}
		catch (e:Dynamic)
			CoolUtil.traceMsg('trace.showPopUp', '$title - $message');
		#else
		CoolUtil.traceMsg('trace.showPopUp', '$title - $message');
		#end
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

		return switch (str)
		{
			case "EXTERNAL_DATA": EXTERNAL_DATA;
			case "EXTERNAL_OBB": EXTERNAL_OBB;
			case "EXTERNAL_MEDIA": EXTERNAL_MEDIA;
			case "EXTERNAL": EXTERNAL;
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

		return switch (str)
		{
			case "EXTERNAL_DATA": EXTERNAL_DATA;
			case "EXTERNAL_OBB": EXTERNAL_OBB;
			case "EXTERNAL_MEDIA": EXTERNAL_MEDIA;
			case "EXTERNAL": EXTERNAL;
			default: SUtil.getExternalDirectory(str) + '.' + file;
		}
	}
}
#end