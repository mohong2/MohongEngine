package;

import haxe.Json;
import sys.FileSystem;
import sys.io.File;

typedef Library = {
	name:String, type:String,
	version:String, dir:String,
	ref:String, url:String
}

class Main {
	public static function main():Void {
		if (!FileSystem.exists(".haxelib") && Sys.getEnv("GITHUB_ACTIONS") == null)
			FileSystem.createDirectory(".haxelib");

		final libs:Array<Library> = Json.parse(File.getContent('./hmm.json')).dependencies;

		for (data in libs) {
			switch (data.type) {
				case "install", "haxelib":
					var version:String = data.version == null ? "" : data.version;
					var extraArgs:String = Sys.getEnv("GITHUB_ACTIONS") == null ? "" : " --never";
					if (Sys.command('haxelib --quiet install ${data.name} ${version}${extraArgs}') != 0) {
						Sys.println('[SEIUN ENGINE SETUP]: Failed to install ${data.name}');
						Sys.exit(1);
					}
				case "git":
					var ref:String = data.ref == null ? "" : data.ref;
					if (Sys.command('haxelib --quiet git ${data.name} ${data.url} ${data.ref}') != 0) {
						Sys.println('[SEIUN ENGINE SETUP]: Failed to install ${data.name} from ${data.url}');
						Sys.exit(1);
					}
				case "dev":
					if (Sys.command('haxelib --quiet dev ${data.name} ${data.url}') != 0) {
						Sys.println('[SEIUN ENGINE SETUP]: Failed to link ${data.name} to ${data.url}');
						Sys.exit(1);
					}
				default:
					Sys.println('[SEIUN ENGINE SETUP]: Unable to resolve library of type "${data.type}" for library "${data.name}"');
			}
		}

		for (data in libs) {
			if ((data.type == "install" || data.type == "haxelib") && data.version != null && data.version != "") {
				Sys.command('haxelib --quiet set ${data.name} ${data.version}');
			}
		}

		applyFlxanimatePatch();

		Sys.exit(0);
	}

	static function applyFlxanimatePatch():Void
	{
		var patchDir:String = './setup/flxanimate_haxe425_patch';
		if (!FileSystem.exists(patchDir)) return;

		var libPath:String = '';
		try
		{
			var proc = new sys.io.Process('haxelib', ['path', 'flxanimate']);
			libPath = StringTools.trim(proc.stdout.readLine());
			proc.close();
		}
		catch (e:Dynamic)
		{
			Sys.println('[SEIUN ENGINE SETUP]: Cannot resolve flxanimate path, skip patch.');
			return;
		}

		if (libPath.length < 1 || StringTools.startsWith(libPath, '-D')) return;
		libPath = StringTools.replace(libPath, '\\', '/');
		while (StringTools.endsWith(libPath, '/')) libPath = libPath.substr(0, libPath.length - 1);

		var files:Array<Array<String>> = [
			['FlxElement.hx', 'flxanimate/animate/FlxElement.hx'],
			['MacroAnimationData.hx', 'flxanimate/data/MacroAnimationData.hx'],
			['FlxAnimateFrames.hx', 'flxanimate/frames/FlxAnimateFrames.hx']
		];
		for (pair in files)
		{
			var src:String = '$patchDir/${pair[0]}';
			var dst:String = '$libPath/${pair[1]}';
			if (FileSystem.exists(src))
			{
				File.saveContent(dst, File.getContent(src));
				Sys.println('[SEIUN ENGINE SETUP]: Patched $dst');
			}
		}
	}
}
