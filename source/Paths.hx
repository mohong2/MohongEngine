package;

import openfl.display3D.textures.RectangleTexture;
import animateatlas.AtlasFrameMaker;
 
import flixel.graphics.frames.FlxFrame.FlxFrameAngle;
import openfl.geom.Rectangle;
import flixel.math.FlxRect;
import haxe.xml.Access;
import openfl.system.System;
 
import flixel.graphics.frames.FlxAtlasFrames;
import openfl.utils.AssetType;
import openfl.utils.Assets as OpenFlAssets;
import lime.utils.Assets;
 
#if sys
import sys.io.File;
import sys.FileSystem;
#end
import flixel.graphics.FlxGraphic;
import openfl.display.BitmapData;
import haxe.Json;

import flash.media.Sound;

using StringTools;
import mohong.TraceManager;
import mohong.MemoryMonitor;
import mohong.GPUTextureManager;

class Paths
{
	inline public static var SOUND_EXT = #if web "mp3" #else "ogg" #end;
	inline public static var VIDEO_EXT = "mp4";

	#if MODS_ALLOWED
	public static var ignoreModFolders:Array<String> = [
		'characters',
		'custom_events',
		'custom_notetypes',
		'data',
		'songs',
		'music',
		'sounds',
		'shaders',
		'videos',
		'images',
		'stages',
		'weeks',
		'fonts',
		'scripts',
		'hscripts',
		'options',
		'achievements'
	];
	#end

	public static function excludeAsset(key:String) {
		if (!dumpExclusions.contains(key))
			dumpExclusions.push(key);
	}

	public static var dumpExclusions:Array<String> =
	[
		'assets/music/freakyMenu.$SOUND_EXT',
		'assets/shared/music/breakfast.$SOUND_EXT',
		'assets/shared/music/tea-time.$SOUND_EXT',
	];
	/** Whether to track graphic loads via MemoryMonitor for leak detection. */
	public static var enableMemoryTracking:Bool = true;

	/** Whether to force GPU texture upload on image load (improves runtime perf, costs load time). */
	public static var forceGPUUploadOnLoad:Bool = true;

	/** Maximum number of cached assets before triggering cleanup. 0 = unlimited. */
	public static var maxCachedAssets:Int = #if mobile 200 #else 300 #end;

	/** Whether loaded FlxGraphic objects auto-free when no sprite references them.
	 *  false = persist forever (desktop); true = auto-collect when unused (mobile aggressive). */
	public static var allowGraphicAutoFree:Bool = false;

	/// haya I love you for the base cache dump I took to the max
	public static function clearUnusedMemory() {
		// clear non local assets in the tracked assets list
		var keysToRemove:Array<String> = [];
		for (key in currentTrackedAssets.keys()) {
			// if it is not currently contained within the used local assets
			if (!localTrackedAssets.contains(key)
				&& !dumpExclusions.contains(key)) {
				keysToRemove.push(key);
			}
		}
		// Batch remove to avoid map modification during iteration
		for (key in keysToRemove) {
			var obj = currentTrackedAssets.get(key);
			@:privateAccess
			if (obj != null) {
				openfl.Assets.cache.removeBitmapData(key);
				FlxG.bitmap._cache.remove(key);
				MemoryMonitor.untrackGraphic(key);
				obj.destroy();
				currentTrackedAssets.remove(key);
			}
		}
		// run the garbage collector for good measure lmfao
		System.gc();
	}

	// define the locally tracked assets
	public static var localTrackedAssets:Array<String> = [];
	public static function clearStoredMemory(?cleanUnused:Bool = false) {
		// clear anything not in the tracked assets list
		@:privateAccess
		for (key in FlxG.bitmap._cache.keys())
		{
			var obj = FlxG.bitmap._cache.get(key);
			if (obj != null && !currentTrackedAssets.exists(key)) {
				openfl.Assets.cache.removeBitmapData(key);
				FlxG.bitmap._cache.remove(key);
				obj.destroy();
			}
		}

		// clear all sounds that are cached
		for (key in currentTrackedSounds.keys()) {
			if (!localTrackedAssets.contains(key)
			&& !dumpExclusions.contains(key) && key != null) {
				//trace('test: ' + dumpExclusions, key);
				Assets.cache.clear(key);
				currentTrackedSounds.remove(key);
			}
		}
		// flags everything to be cleared out next unused memory clear
		localTrackedAssets = [];
		openfl.Assets.cache.clear("songs");
	}

	static public var currentModDirectory(get, set):String;
	static var _currentModDirectory:String = '';

	static function get_currentModDirectory():String return _currentModDirectory;
	static function set_currentModDirectory(v:String):String {
		if (_currentModDirectory == v) return v;
		var oldMod = _currentModDirectory;
		_currentModDirectory = v;
		for (cb in onModDirectoryChanged) cb(oldMod, v);
		return v;
	}

	/** 模组目录变更回调（供 HScript 等监听） **/
	public static var onModDirectoryChanged:Array<String->String->Void> = [];

	static public var currentLevel:String;
	static public function setCurrentLevel(name:String)
	{
		currentLevel = name.toLowerCase();
	}

	public static function getPath(file:String, ?type:AssetType = TEXT, ?library:Null<String> = null)
	{
		if (library != null)
			return getLibraryPath(file, library);

		if (currentLevel != null)
		{
			var levelPath:String = '';
			if(currentLevel != 'shared') {
				levelPath = getLibraryPathForce(file, currentLevel);
				if (OpenFlAssets.exists(levelPath, type))
					return levelPath;
			}

			levelPath = getLibraryPathForce(file, "shared");
			if (OpenFlAssets.exists(levelPath, type))
				return levelPath;
		}

		return getPreloadPath(file);
	}

	static public function getLibraryPath(file:String, library = "preload")
	{
		return if (library == "preload" || library == "default") getPreloadPath(file); else getLibraryPathForce(file, library);
	}

	inline static function getLibraryPathForce(file:String, library:String)
	{
		var returnPath = '$library:assets/$library/$file';
		return returnPath;
	}

	inline public static function getPreloadPath(file:String = '')
	{
		return 'assets/$file';
	}

	inline static public function file(file:String, type:AssetType = TEXT, ?library:String)
	{
		return getPath(file, type, library);
	}

	inline static public function txt(key:String, ?library:String)
	{
		return getPath('data/$key.txt', TEXT, library);
	}

	inline static public function xml(key:String, ?library:String)
	{
		return getPath('data/$key.xml', TEXT, library);
	}

	inline static public function json(key:String, ?library:String)
	{
		return getPath('data/$key.json', TEXT, library);
	}

	inline static public function shaderFragment(key:String, ?library:String)
	{
		return getPath('shaders/$key.frag', TEXT, library);
	}
	inline static public function shaderVertex(key:String, ?library:String)
	{
		return getPath('shaders/$key.vert', TEXT, library);
	}
	inline static public function lua(key:String, ?library:String)
	{
		return getPath('$key.lua', TEXT, library);
	}

	static public function video(key:String)
	{
		#if MODS_ALLOWED
		// 1. Check active mod's folder
		if (currentModDirectory != null && currentModDirectory.length > 0)
		{
			var file:String = mods(currentModDirectory + '/videos/' + key + '.' + VIDEO_EXT);
			if(FileSystem.exists(file)) {
				#if windows
				return file.split('\\').join('/');
				#else
				return file;
				#end
			}
		}
		// 2. Check global mods
		for (mod in getGlobalMods())
		{
			var file:String = mods(mod + '/videos/' + key + '.' + VIDEO_EXT);
			if(FileSystem.exists(file)) {
				#if windows
				return file.split('\\').join('/');
				#else
				return file;
				#end
			}
		}
		// 3. Check root mods/
		var file:String = mods('videos/' + key + '.' + VIDEO_EXT);
		if(FileSystem.exists(file)) {
			#if windows
			return file.split('\\').join('/');
			#else
			return file;
			#end
		}
		#end
		return 'assets/videos/$key.$VIDEO_EXT';

	}

	static public function sound(key:String, ?library:String):Sound
	{
		var sound:Sound = returnSound('sounds', key, library);
		return sound;
	}

	inline static public function soundRandom(key:String, min:Int, max:Int, ?library:String)
	{
		return sound(key + FlxG.random.int(min, max), library);
	}

	inline static public function music(key:String, ?library:String):Sound
	{
		var file:Sound = returnSound('music', key, library);
		return file;
	}

	inline static public function voices(song:String):Any
	{
		var songKey:String = '${formatToSongPath(song)}/Voices';
		var voices = returnSound('songs', songKey);
		return voices;
	}

		inline static public function opponentvoices(song:String):Any
	{
		var songKey:String = '${formatToSongPath(song)}/Voices-Opponent';
		var voices = returnSound('songs', songKey);
		return voices;
	}
		inline static public function playervoices(song:String):Any
	{
		var songKey:String = '${formatToSongPath(song)}/Voices-Player';
		var voices = returnSound('songs', songKey);
		return voices;
	}

	inline static public function inst(song:String):Any
	{
		var songKey:String = '${formatToSongPath(song)}/Inst';
		var inst = returnSound('songs', songKey);
		return inst;
	}
	/*
	inline static public function image(key:String, ?library:String):FlxGraphic
	{
		// streamlined the assets process more
		var returnAsset:FlxGraphic = returnGraphic(key, library);
		return returnAsset;
	}*/
	inline public static function getSharedPath(file:String = '')
	{
		return 'assets/shared/$file';
	}

	inline public static function mergeAllTextsNamed(path:String, defaultDirectory:String = null, allowDuplicates:Bool = false)
	{
		if(defaultDirectory == null) defaultDirectory =	getSharedPath();
		defaultDirectory = defaultDirectory.trim();
		if(!defaultDirectory.endsWith('/')) defaultDirectory += '/';
		if(!defaultDirectory.startsWith('assets/')) defaultDirectory = 'assets/$defaultDirectory';

		var mergedList:Array<String> = [];
		var paths:Array<String> = directoriesWithFile(defaultDirectory, path);

		// directoriesWithFile already returns paths in correct priority:
		// active mod → global mods → mods/ root → default (lowest)
		// No need to reorder; the natural order is authoritative.

		for (file in paths)
		{
			var list:Array<String> = CoolUtil.coolTextFile(file);
			for (value in list)
				if((allowDuplicates || !mergedList.contains(value)) && value.length > 0)
					mergedList.push(value);
		}
		return mergedList;
	}
	inline public static function directoriesWithFile(path:String, fileToFind:String, mods:Bool = true)
	{
		var foldersToCheck:Array<String> = [];

		#if MODS_ALLOWED
		if(mods)
		{
			// 1. Active mod's folder (highest priority)
			if(currentModDirectory != null && currentModDirectory.length > 0)
			{
				var folder:String = Paths.mods(currentModDirectory + '/' + fileToFind);
				if(FileSystem.exists(folder) && !foldersToCheck.contains(folder)) foldersToCheck.push(folder);
			}

			// 2. Global mods
			for(mod in getGlobalMods())
			{
				var folder:String = Paths.mods(mod + '/' + fileToFind);
				if(FileSystem.exists(folder) && !foldersToCheck.contains(folder)) foldersToCheck.push(folder);
			}

			// 3. Root "mods/" folder
			var folder:String = Paths.mods(fileToFind);
			if(FileSystem.exists(folder) && !foldersToCheck.contains(folder)) foldersToCheck.push(folder);
		}
		#end

		// 4. Default path (lowest priority)
		#if sys
		if(FileSystem.exists(path + fileToFind))
		#end
			foldersToCheck.push(path + fileToFind);

		return foldersToCheck;
	}


	static public function image(key:String, ?library:String = null, ?allowGPU:Bool = true):FlxGraphic
	{
		var bitmap:BitmapData = null;
		var file:String = null;

		#if MODS_ALLOWED
		file = modsImages(key);
		if (currentTrackedAssets.exists(file))
		{
			localTrackedAssets.push(file);
			return currentTrackedAssets.get(file);
		}
		else if (FileSystem.exists(file))
			bitmap = BitmapData.fromFile(file);
		else
		#end
		{
			file = getPath('images/$key.png', IMAGE, library);
			if (currentTrackedAssets.exists(file))
			{
				localTrackedAssets.push(file);
				return currentTrackedAssets.get(file);
			}
			else if (OpenFlAssets.exists(file, IMAGE))
				bitmap = OpenFlAssets.getBitmapData(file);
		}

		if (bitmap != null)
		{
			var retVal = cacheBitmap(file, bitmap, allowGPU);
			if(retVal != null) return retVal;
		}

		TraceManager.warn('trace.paths.nullReturn', 'oh no its returning null NOOOO ($file)');
		return null;
	}
	static public function languageImage(key:String, ?library:String = null, ?allowGPU:Bool = true):FlxGraphic
	{
		var currentLang:String = ClientPrefs.data.language;
		
		if (currentLang != null && currentLang.length > 0)
		{
			var langKey:String = '';
			
			if (key.indexOf('/') != -1)
			{
				var lastSlash:Int = key.lastIndexOf('/');
				langKey = key.substring(0, lastSlash) + '/' + currentLang + '/' + key.substring(lastSlash + 1);
			}
			else
			{
				langKey = currentLang + '/' + key;
			}
			#if MODS_ALLOWED
			var modPath:String = modsImages(langKey);
			if (FileSystem.exists(modPath))
			{
				return image(langKey, library, allowGPU);
			}
			#end
			
			var mainPath:String = getPath('images/$langKey.png', IMAGE, library);
			if (OpenFlAssets.exists(mainPath, IMAGE))
			{
				return image(langKey, library, allowGPU);
			}
		}
		
		return image(key, library, allowGPU);
	}

	static public function cacheBitmap(file: String, ?bitmap: BitmapData = null, ?allowGPU: Bool = true): FlxGraphic {
			if (currentTrackedAssets.exists(file)) {
				localTrackedAssets.push(file);
				return currentTrackedAssets.get(file);
			}

			// Enforce cache size limit to prevent memory bloat
			if (maxCachedAssets > 0) {
				var currentCount:Int = 0;
				for (_ in currentTrackedAssets) currentCount++;
				if (currentCount >= maxCachedAssets) {
					clearUnusedMemory();
				}
			}

			if (bitmap == null) {
				#if MODS_ALLOWED
				if (FileSystem.exists(file)) bitmap = BitmapData.fromFile(file);
				else
				#end {
					if (OpenFlAssets.exists(file, IMAGE)) bitmap = OpenFlAssets.getBitmapData(file);
				}
				if (bitmap == null) return null;
			}

			localTrackedAssets.push(file);

			if (allowGPU && ClientPrefs.data.cacheOnGPU && forceGPUUploadOnLoad) {
				var texture: RectangleTexture = FlxG.stage.context3D.createRectangleTexture(bitmap.width, bitmap.height, BGRA, true);
				texture.uploadFromBitmapData(bitmap);
				// Track GPU texture allocation for VRAM monitoring
				GPUTextureManager.trackTextureAllocation(texture, bitmap.width, bitmap.height);
				bitmap.image.data = null;
				bitmap.dispose();
				bitmap.disposeImage();
				bitmap = BitmapData.fromTexture(texture);
			}
			var newGraphic: FlxGraphic = FlxGraphic.fromBitmapData(bitmap, false, file);
		newGraphic.persist = !allowGraphicAutoFree;
		newGraphic.destroyOnNoUse = allowGraphicAutoFree;
			currentTrackedAssets.set(file, newGraphic);
			// Track graphic lifecycle for leak detection
			if (enableMemoryTracking) {
				MemoryMonitor.trackGraphic(file, newGraphic);
			}
			return newGraphic;
		}
	static public function getTextFromFile(key:String, ?ignoreMods:Bool = false):String
	{
		#if sys
		#if MODS_ALLOWED
		if (!ignoreMods)
		{
			var foundPath:String = modFolders(key); // Now searches active mod → global mods → root mods/
			if (FileSystem.exists(foundPath))
				return File.getContent(foundPath);
		}
		#end

		if (FileSystem.exists(getPreloadPath(key)))
			return File.getContent(getPreloadPath(key));

		if (currentLevel != null)
		{
			var levelPath:String = '';
			if(currentLevel != 'shared') {
				levelPath = getLibraryPathForce(key, currentLevel);
				if (FileSystem.exists(levelPath))
					return File.getContent(levelPath);
			}

			levelPath = getLibraryPathForce(key, 'shared');
			if (FileSystem.exists(levelPath))
				return File.getContent(levelPath);
		}
		#end
		return Assets.getText(getPath(key, TEXT));
	}
	inline static public function getSparrowAtlas(key:String, ?library:String = null, ?allowGPU:Bool = true):FlxAtlasFrames
	{
		var imageLoaded:FlxGraphic = image(key, library, allowGPU);
		#if MODS_ALLOWED
		var xmlExists:Bool = false;

		var xml:String = modsXml(key);
		if(FileSystem.exists(xml)) xmlExists = true;

		return FlxAtlasFrames.fromSparrow(imageLoaded, (xmlExists ? File.getContent(xml) : getPath('images/$key.xml', library)));
		#else
		return FlxAtlasFrames.fromSparrow(imageLoaded, getPath('images/$key.xml', library));
		#end
	}


	inline static public function languageFont()
	{
		var language_ttf:String = Language.get("ttf", "vcr");
		return 'assets/fonts/$language_ttf.ttf';
	}

	static public function font(key:String)
	{
		#if MODS_ALLOWED
		// 1. Check active mod
		if (currentModDirectory != null && currentModDirectory.length > 0)
		{
			var file:String = mods(currentModDirectory + '/fonts/' + key);
			if(FileSystem.exists(file)) return file;
		}
		// 2. Check global mods
		for (mod in getGlobalMods())
		{
			var file:String = mods(mod + '/fonts/' + key);
			if(FileSystem.exists(file)) return file;
		}
		// 3. Check root mods/
		var file:String = mods('fonts/' + key);
		if(FileSystem.exists(file)) return file;
		#end
		return 'assets/fonts/$key';
	}

	inline static public function optionsfont()
	{
		var options_ttf:String = Language.get("option.ttf", "vcr");
		return 'assets/fonts/$options_ttf.ttf';
	}
	inline static public function locale(key:String, ?library:String)
	{
		return getPath('lang/$key', TEXT, library);
	}
	inline static public function localeMod(key:String)
	{
		return modFolders('lang/$key');
	}

	static public function fileExists(key:String, type:AssetType, ?ignoreMods:Bool = false, ?library:String)
	{
		#if MODS_ALLOWED
		// 1. Check active mod's folder
		if (Paths.currentModDirectory != null && Paths.currentModDirectory.length > 0)
		{
			if(FileSystem.exists(mods(currentModDirectory + '/' + key))) return true;
		}
		// 2. Check global mods
		for (mod in getGlobalMods())
		{
			if(FileSystem.exists(mods(mod + '/' + key))) return true;
		}
		// 3. Check root mods/
		if(FileSystem.exists(mods(key))) return true;
		#end

		if(OpenFlAssets.exists(getPath(key, type))) {
			return true;
		}
		return false;
	}

	inline static public function getPackerAtlas(key:String, ?library:String)
	{
		#if MODS_ALLOWED
		var imageLoaded:FlxGraphic = returnGraphic(key);
		var txtExists:Bool = false;
		if(FileSystem.exists(modsTxt(key))) {
			txtExists = true;
		}

		return FlxAtlasFrames.fromSpriteSheetPacker((imageLoaded != null ? imageLoaded : image(key, library)), (txtExists ? File.getContent(modsTxt(key)) : file('images/$key.txt', library)));
		#else
		return FlxAtlasFrames.fromSpriteSheetPacker(image(key, library), file('images/$key.txt', library));
		#end
	}

	inline static public function formatToSongPath(path:String) {
		var invalidChars = ~/[~&\\;:<>#]/;
		var hideChars = ~/[.,'"%?]/;

		var path = invalidChars.split(path.replace(' ', '-')).join("-");
		return hideChars.split(path).join("").toLowerCase();
	}

	// completely rewritten asset loading? fuck!
	public static var currentTrackedAssets:Map<String, FlxGraphic> = [];
	public static function returnGraphic(key:String, ?library:String) {
		#if MODS_ALLOWED
		var modKey:String = modsImages(key);
		if(FileSystem.exists(modKey)) {
			if(!currentTrackedAssets.exists(modKey)) {
				var newBitmap:BitmapData = BitmapData.fromFile(modKey);
				var newGraphic:FlxGraphic = FlxGraphic.fromBitmapData(newBitmap, false, modKey);
				newGraphic.persist = true;
				currentTrackedAssets.set(modKey, newGraphic);
			}
			localTrackedAssets.push(modKey);
			return currentTrackedAssets.get(modKey);
		}
		#end

		var path = getPath('images/$key.png', IMAGE, library);
		//trace(path);
		if (OpenFlAssets.exists(path, IMAGE)) {
			if(!currentTrackedAssets.exists(path)) {
				var newGraphic:FlxGraphic = FlxG.bitmap.add(path, false, path);
				newGraphic.persist = true;
				currentTrackedAssets.set(path, newGraphic);
			}
			localTrackedAssets.push(path);
			return currentTrackedAssets.get(path);
		}
		TraceManager.warn('trace.paths.nullReturn', 'oh no its returning null NOOOO');
		return null;
	}

	public static var currentTrackedSounds:Map<String, Sound> = [];
	public static function returnSound(path:String, key:String, ?library:String) {
		#if MODS_ALLOWED
		var file:String = modsSounds(path, key);
		if(FileSystem.exists(file)) {
			if(!currentTrackedSounds.exists(file)) {
				currentTrackedSounds.set(file, Sound.fromFile(file));
			}
			localTrackedAssets.push(key);
			return currentTrackedSounds.get(file);
		}
		#end
		// I hate this so god damn much
		var gottenPath:String = getPath('$path/$key.$SOUND_EXT', SOUND, library);
		gottenPath = gottenPath.substring(gottenPath.indexOf(':') + 1, gottenPath.length);
		// trace(gottenPath);
		if(!currentTrackedSounds.exists(gottenPath))
		#if MODS_ALLOWED
			currentTrackedSounds.set(gottenPath, Sound.fromFile(gottenPath));
		#else
		{
			var folder:String = '';
			if(path == 'songs') folder = 'songs:';

			currentTrackedSounds.set(gottenPath, OpenFlAssets.getSound(folder + getPath('$path/$key.$SOUND_EXT', SOUND, library)));
		}
		#end
		localTrackedAssets.push(gottenPath);
		return currentTrackedSounds.get(gottenPath);
	}

	#if MODS_ALLOWED
	inline static public function mods(key:String = '') {
		return Sys.getCwd() + 'mods/' + key;
	}

	inline static public function modsFont(key:String) {
		return modFolders('fonts/' + key);
	}

	inline static public function modsJson(key:String) {
		return modFolders('data/' + key + '.json');
	}

	inline static public function modsVideo(key:String) {
		return modFolders('videos/' + key + '.' + VIDEO_EXT);
	}

	inline static public function modsSounds(path:String, key:String) {
		return modFolders(path + '/' + key + '.' + SOUND_EXT);
	}

	inline static public function modsImages(key:String) {
		return modFolders('images/' + key + '.png');
	}

	inline static public function modsXml(key:String) {
		return modFolders('images/' + key + '.xml');
	}

	inline static public function modsTxt(key:String) {
		return modFolders('images/' + key + '.txt');
	}


	/* Goes unused for now

	inline static public function modsShaderFragment(key:String, ?library:String)
	{
		return modFolders('shaders/'+key+'.frag');
	}
	inline static public function modsShaderVertex(key:String, ?library:String)
	{
		return modFolders('shaders/'+key+'.vert');
	}
	inline static public function modsAchievements(key:String) {
		return modFolders('achievements/' + key + '.json');
	}*/

	static public function modFolders(key:String) {
		// 1. Check active mod's folder (highest priority)
		if(currentModDirectory != null && currentModDirectory.length > 0) {
			var fileToCheck:String = mods(currentModDirectory + '/' + key);
			if(FileSystem.exists(fileToCheck)) {
				return fileToCheck;
			}
		}

		// 2. Check global mods (runsGlobally) — they should always be available
		for (mod in getGlobalMods()) {
			var fileToCheck:String = mods(mod + '/' + key);
			if(FileSystem.exists(fileToCheck)) {
				return fileToCheck;
			}
		}

		// 3. Fall back to root mods/ (lowest priority)
		return Sys.getCwd() + 'mods/' + key;
	}

	public static var globalMods:Array<String> = [];

	/** Add a single mod to the global mods list (used for dependency loading). */
	public static function addGlobalMod(mod:String):Void
	{
		if (mod == null || mod.length == 0) return;
		if (globalMods == null) globalMods = [];
		if (!globalMods.contains(mod)) globalMods.push(mod);
	}

	static public function getGlobalMods()
		return globalMods;

	static public function clearGlobalMods() {
		globalMods = [];
	}

	static public function pushGlobalMods() // prob a better way to do this but idc
	{
		globalMods = [];
		var path:String = 'modsList.txt';
		if(FileSystem.exists(path))
		{
			var list:Array<String> = CoolUtil.coolTextFile(path);
			for (i in list)
			{
				var dat = i.split("|");
				if (dat[1] == "1")
				{
					var folder = dat[0];
					var path = Paths.mods(folder + '/pack.json');
					if(FileSystem.exists(path)) {
						try{
							var rawJson:String = File.getContent(path);
							if(rawJson != null && rawJson.length > 0) {
								var stuff:Dynamic = Json.parse(rawJson);
								var global:Bool = Reflect.getProperty(stuff, "runsGlobally");
								if(global)globalMods.push(dat[0]);
							}
						} catch(e:Dynamic){
							TraceManager.error('trace.error', 'Exception: {}', [e]);
						}
					}
				}
			}
		}
		return globalMods;
	}

	static public function getModDirectories():Array<String> {
		var list:Array<String> = [];
		var modsFolder:String = mods();
		if(FileSystem.exists(modsFolder)) {
			for (folder in FileSystem.readDirectory(modsFolder)) {
				var path = haxe.io.Path.join([modsFolder, folder]);
				if (sys.FileSystem.isDirectory(path) && !ignoreModFolders.contains(folder) && !list.contains(folder)) {
					list.push(folder);
				}
			}
		}
		return list;
	}
	#end
}
