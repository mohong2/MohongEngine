package backend;

import backend.ZipReader;

using StringTools;

/**
 * Pure decision logic for turning a ZIP's entry list into an install plan.
 * No flixel / engine dependencies, so it can be unit-tested standalone.
 */
class ModZipPlanner
{
	static var MOD_MARKERS:Array<String> = [
		'data', 'songs', 'music', 'sounds', 'images', 'shaders', 'videos',
		'stages', 'weeks', 'characters', 'custom_events', 'custom_notetypes',
		'hscripts', 'scripts', 'lang', 'achievements', 'fonts', 'options'
	];

	static var MOD_MARKER_FILES:Array<String> = ['pack.json', 'icon.png', 'icon.xml'];

	public static function isModMarker(name:String):Bool
	{
		var n:String = name.toLowerCase();
		if (MOD_MARKERS.contains(n)) return true;
		return MOD_MARKER_FILES.contains(n.toLowerCase());
	}

	/**
	 * Turn the central-directory entry list into an install plan.
	 * job.src paths are relative to the extraction temp root ('' = root).
	 * A job with an empty name means "ask the player for a name".
	 */
	public static function analyze(entries:Array<ZipEntry>):ZipPlan
	{
		var topDirs:Array<String> = [];
		var topFiles:Array<String> = [];
		var topMap:Map<String, Bool> = new Map();
		var dirSet:Map<String, Bool> = new Map();

		for (entry in entries)
		{
			if (entry.name == null || entry.name.length == 0) continue;
			if (entry.name == '__MACOSX' || entry.name.indexOf('__MACOSX/') == 0) continue;

			// Track every directory, including implied parents (many zips omit
			// explicit directory entries, e.g. .NET's ZipFile).
			if (entry.isDirectory) dirSet.set(stripTrailingSlash(entry.name), true);
			var slashIdx:Int = entry.name.indexOf('/');
			while (slashIdx >= 0)
			{
				dirSet.set(entry.name.substr(0, slashIdx), true);
				slashIdx = entry.name.indexOf('/', slashIdx + 1);
			}

			var slash:Int = entry.name.indexOf('/');
			var top:String = slash < 0 ? entry.name : entry.name.substr(0, slash);
			if (top.length == 0) continue;
			if (topMap.exists(top)) continue;
			topMap.set(top, true);
			if (slash < 0 && !entry.isDirectory)
				topFiles.push(top);
			else
				topDirs.push(top);
		}

		// Loose mod content at the zip root (data/, songs/, ... + pack.json).
		var looseMod:Bool = false;
		for (t in topDirs)
			if (isModMarker(t)) { looseMod = true; break; }
		for (t in topFiles)
			if (isModMarker(t)) { looseMod = true; break; }

		if (looseMod)
		{
			var jobs:Array<InstallJob> = [{src: '', name: ''}]; // name filled by caller (zip base name)
			return {jobs: jobs, promptForName: false, promptIndex: -1, promptDefault: ''};
		}

		// "mods" folder handling
		var modsIdx:Int = -1;
		for (i in 0...topDirs.length)
			if (topDirs[i].toLowerCase() == 'mods') { modsIdx = i; break; }

		if (modsIdx >= 0)
		{
			var modsFolder:String = topDirs[modsIdx];
			var modsPrefix:String = modsFolder + '/';
			// Does mods/ contain mod folders?
			var childMods:Array<String> = [];
			var modsIsModRoot:Bool = false;
			for (entry in entries)
			{
				if (entry.name.indexOf(modsPrefix) == 0)
				{
					var rest:String = entry.name.substr(modsFolder.length + 1);
					var firstSlash:Int = rest.indexOf('/');
					var direct:String = firstSlash < 0 ? rest : rest.substr(0, firstSlash);
					direct = stripTrailingSlash(direct);
					if (direct.length == 0) continue;
					if (dirSet.exists(modsPrefix + direct) && !childMods.contains(direct))
						childMods.push(direct);
					if (isModMarker(direct)) modsIsModRoot = true;
				}
			}

			var jobs:Array<InstallJob> = [];
			var promptIndex:Int = -1;
			var promptDefault:String = '';

			if (modsIsModRoot)
			{
				// The "mods" folder IS the mod: ask the player for a name.
				jobs.push({src: modsFolder, name: ''});
				promptIndex = jobs.length - 1;
				promptDefault = modsFolder;
			}
			else if (childMods.length > 0)
			{
				// The "mods" folder is a pack: install its children as mods.
				for (child in childMods)
					jobs.push({src: modsFolder + '/' + child, name: child});
			}

			// Other top-level mod folders next to "mods".
			for (dir in topDirs)
			{
				if (dir == modsFolder) continue;
				if (dir.toLowerCase() == 'mods') continue;
				jobs.push({src: dir, name: dir});
			}

			if (jobs.length > 0)
				return {jobs: jobs, promptForName: promptIndex >= 0, promptIndex: promptIndex, promptDefault: promptDefault};
		}

		// Multiple top-level folders -> pack.
		if (topDirs.length > 1)
		{
			var jobs:Array<InstallJob> = [];
			for (dir in topDirs)
			{
				if (dir.toLowerCase() == 'mods') continue; // handled above
				jobs.push({src: dir, name: dir});
			}
			if (jobs.length > 0)
				return {jobs: jobs, promptForName: false, promptIndex: -1, promptDefault: ''};
		}

		// Exactly one top-level folder -> that folder is the mod.
		if (topDirs.length == 1 && topFiles.length == 0)
		{
			var name:String = sanitizeName(topDirs[0]);
			if (name.length == 0 || name.toLowerCase() == 'mods')
				return null;
			return {
				jobs: [{src: topDirs[0], name: name}],
				promptForName: false,
				promptIndex: -1,
				promptDefault: ''
			};
		}

		// One folder + loose files (readme etc.) -> that folder is the mod.
		if (topDirs.length == 1)
		{
			var name:String = sanitizeName(topDirs[0]);
			if (name.length == 0 || name.toLowerCase() == 'mods')
				return null;
			return {
				jobs: [{src: topDirs[0], name: name}],
				promptForName: false,
				promptIndex: -1,
				promptDefault: ''
			};
		}

		return null;
	}

	static function stripTrailingSlash(name:String):String
	{
		while (name.endsWith("/"))
			name = name.substr(0, name.length - 1);
		return name;
	}

	public static function sanitizeName(name:String):String
	{
		if (name == null) return '';
		name = StringTools.replace(name, "\\", "_");
		name = ~/[<>:"\/\\|?*\x00-\x1F]/g.replace(name, "");
		name = StringTools.trim(name);
		while (name.startsWith(".")) name = name.substr(1);
		while (name.endsWith(".") || name.endsWith(" ")) name = name.substr(0, name.length - 1);
		if (name.length > 80) name = name.substr(0, 80);
		if (name.toLowerCase() == 'mods') name = name + '_mod';
		return name;
	}
}

typedef InstallJob =
{
	var src:String;  // path relative to tempRoot ('' = tempRoot itself)
	var name:String; // target mod folder name; '' = ask player
}

typedef ZipPlan =
{
	var jobs:Array<InstallJob>;
	var promptForName:Bool;
	var promptIndex:Int;
	var promptDefault:String;
}
