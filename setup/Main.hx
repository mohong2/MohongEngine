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
		// 本地创建项目内 .haxelib；CI 不创建（避免劫持 ~/haxelib 仓库）
		if (!FileSystem.exists(".haxelib") && Sys.getEnv("GITHUB_ACTIONS") == null)
			FileSystem.createDirectory(".haxelib");

		// brief explanation: first we parse a json containing the library names, data, and such
		final libs:Array<Library> = Json.parse(File.getContent('./hmm.json')).dependencies;

		// now we loop through the data we currently have
		for (data in libs) {
			// and install the libraries, based on their type
			switch (data.type) {
				case "install", "haxelib": // for libraries only available in the haxe package manager
					var version:String = data.version == null ? "" : data.version;
					// CI 下 --never：已装版本保持不变，避免交互询问卡住
					var extraArgs:String = Sys.getEnv("GITHUB_ACTIONS") == null ? "" : " --never";
					Sys.command('haxelib --quiet install ${data.name} ${version}${extraArgs}');
				case "git": // for libraries that contain git repositories
					var ref:String = data.ref == null ? "" : data.ref;
					Sys.command('haxelib --quiet git ${data.name} ${data.url} ${data.ref}');
				default: // and finally, throw an error if the library has no type
					Sys.println('[SEIUN ENGINE SETUP]: Unable to resolve library of type "${data.type}" for library "${data.name}"');
			}
		}

		// 兜底：git 库的空版本依赖会把 hxcpp/lime 拉成最新版，这里重新钉回 hmm.json 声明的版本
		for (data in libs) {
			if ((data.type == "install" || data.type == "haxelib") && data.version != null && data.version != "") {
				Sys.command('haxelib --quiet set ${data.name} ${data.version}');
			}
		}

		// after the loop, we can leave
		Sys.exit(0);
	}
}
