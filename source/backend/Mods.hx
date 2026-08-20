package backend;

import haxe.Json;
import Paths;
import CoolUtil;

/**
 * Psych Engine 0.7.3 兼容层：`backend.Mods`。
 *
 * SeiunEngine 原本没有这个类，但大量 0.7.3 模组脚本（尤其是 HScript）会
 * `import backend.Mods` 并访问 `Mods.currentModDirectory` / `Mods.getGlobalMods()`。
 * 这里把所有实现委托给 Seiun 已有的 `Paths` 静态 API，避免重复维护一套 mod 逻辑。
 */
typedef ModsList = {
	enabled:Array<String>,
	disabled:Array<String>,
	all:Array<String>
};

class Mods
{
	public static var currentModDirectory(get, set):String;
	static function get_currentModDirectory():String return Paths.currentModDirectory;
	static function set_currentModDirectory(v:String):String return Paths.currentModDirectory = v;

	#if MODS_ALLOWED
	public static var ignoreModFolders:Array<String> = Paths.ignoreModFolders;
	#else
	public static var ignoreModFolders:Array<String> = [];
	#end

	private static var globalMods:Array<String> = [];

	inline public static function getGlobalMods()
		return Paths.getGlobalMods();

	inline public static function pushGlobalMods()
		return Paths.pushGlobalMods();

	inline public static function getModDirectories():Array<String>
		return Paths.getModDirectories();

	inline public static function mergeAllTextsNamed(path:String, defaultDirectory:String = null, allowDuplicates:Bool = false)
		return Paths.mergeAllTextsNamed(path, defaultDirectory, allowDuplicates);

	inline public static function directoriesWithFile(path:String, fileToFind:String, mods:Bool = true)
		return Paths.directoriesWithFile(path, fileToFind, mods);

	public static function getPack(?folder:String = null):Dynamic
	{
		#if MODS_ALLOWED
		if(folder == null) folder = Mods.currentModDirectory;

		var path = Paths.mods(folder + '/pack.json');
		if(FileSystem.exists(path)) {
			try {
				#if sys
				var rawJson:String = File.getContent(path);
				#else
				var rawJson:String = Assets.getText(path);
				#end
				if(rawJson != null && rawJson.length > 0) return tjson.TJSON.parse(rawJson);
			} catch(e:Dynamic) {
				trace(e);
			}
		}
		#end
		return null;
	}

	public static var updatedOnState:Bool = false;

	inline public static function parseList():ModsList {
		if(!updatedOnState) updateModList();
		var list:ModsList = {enabled: [], disabled: [], all: []};

		#if MODS_ALLOWED
		try {
			for (mod in CoolUtil.coolTextFile('modsList.txt'))
			{
				if(mod.trim().length < 1) continue;

				var dat = mod.split("|");
				list.all.push(dat[0]);
				if (dat[1] == "1")
					list.enabled.push(dat[0]);
				else
					list.disabled.push(dat[0]);
			}
		} catch(e) {
			trace(e);
		}
		#end
		return list;
	}

	private static function updateModList()
	{
		#if MODS_ALLOWED
		// Find all that are already ordered
		var list:Array<Array<Dynamic>> = [];
		var added:Array<String> = [];
		try {
			for (mod in CoolUtil.coolTextFile('modsList.txt'))
			{
				var dat:Array<String> = mod.split("|");
				var folder:String = dat[0];
				if(folder.trim().length > 0 && FileSystem.exists(Paths.mods(folder)) && FileSystem.isDirectory(Paths.mods(folder)) && !added.contains(folder))
				{
					added.push(folder);
					list.push([folder, (dat[1] == "1")]);
				}
			}
		} catch(e) {
			trace(e);
		}

		// Scan for folders that aren't on modsList.txt yet
		for (folder in getModDirectories())
		{
			if(folder.trim().length > 0 && FileSystem.exists(Paths.mods(folder)) && FileSystem.isDirectory(Paths.mods(folder)) &&
			!ignoreModFolders.contains(folder.toLowerCase()) && !added.contains(folder))
			{
				added.push(folder);
				list.push([folder, true]);
			}
		}

		// Now save file
		var fileStr:String = '';
		for (values in list)
		{
			if(fileStr.length > 0) fileStr += '\n';
			fileStr += values[0] + '|' + (values[1] ? '1' : '0');
		}

		File.saveContent('modsList.txt', fileStr);
		updatedOnState = true;
		#end
	}

	public static function loadTopMod()
	{
		Mods.currentModDirectory = '';

		#if MODS_ALLOWED
		var list:Array<String> = Mods.parseList().enabled;
		if(list != null && list[0] != null)
			Mods.currentModDirectory = list[0];
		#end
	}
}
