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
		// 本地开发：创建项目内 .haxelib，让依赖落在项目目录（已被 .gitignore 排除）。
		// CI（GitHub Actions）：不要创建——haxelib 4.x 会把“当前目录里的 .haxelib 文件夹”
		// 当作仓库（优先级高于 HAXELIB_PATH 和 haxelib setup），
		// 而 CI 里依赖必须统一装到 haxelib setup 指定的 ~/haxelib（缓存、后续步骤都依赖它）。
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
					// CI 下加 --never：版本已装就保持不变，避免“Set hxcpp to version ...”交互询问卡住流水线
					var extraArgs:String = Sys.getEnv("GITHUB_ACTIONS") == null ? "" : " --never";
					Sys.command('haxelib --quiet install ${data.name} ${version}${extraArgs}');
				case "git": // for libraries that contain git repositories
					var ref:String = data.ref == null ? "" : data.ref;
					Sys.command('haxelib --quiet git ${data.name} ${data.url} ${data.ref}');
				default: // and finally, throw an error if the library has no type
					Sys.println('[SEIUN ENGINE SETUP]: Unable to resolve library of type "${data.type}" for library "${data.name}"');
			}
		}

		// after the loop, we can leave
		Sys.exit(0);
	}
}
