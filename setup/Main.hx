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
		applyLimeSdlConfigPatch();

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

	/**
	 * 修复在 Linux 主机上交叉编译 Android 时，Lime 的 SDL/SDL3 构建配置
	 * 误用 Linux 的 SDL_config（定义 SDL_VIDEO_DRIVER_X11）导致
	 * X11/Xlib.h 缺失的问题。Android 目标应使用 Android 专用配置。
	 */
	static function applyLimeSdlConfigPatch():Void
	{
		var libPath:String = '';
		try
		{
			var proc = new sys.io.Process('haxelib', ['path', 'lime']);
			var output:String = proc.stdout.readAll().toString();
			proc.close();
			for (line in output.split('\n'))
			{
				var l:String = StringTools.trim(line);
				if (l.length > 0 && !StringTools.startsWith(l, '-'))
				{
					libPath = l;
					break;
				}
			}
		}
		catch (e:Dynamic)
		{
			Sys.println('[SEIUN ENGINE SETUP]: Cannot resolve lime path, skip SDL config patch.');
			return;
		}

		if (libPath.length < 1) return;
		libPath = StringTools.replace(libPath, '\\', '/');
		while (StringTools.endsWith(libPath, '/')) libPath = libPath.substr(0, libPath.length - 1);

		var files:Array<String> = [
			'$libPath/project/lib/sdl3-files.xml',
			'$libPath/project/lib/sdl/files.xml',
			'$libPath/project/Build.xml'
		];

		var anyPatched:Bool = false;
		for (file in files)
		{
			if (!FileSystem.exists(file)) continue;
			var content:String = File.getContent(file);
			var original:String = content;

			// SDL3: Android 使用通用 build_config（内部按 SDL_PLATFORM_ANDROID 选 android 配置），
			// Linux 配置仅用于真正的 Linux 目标。
			content = StringTools.replace(content,
				'value="${"$"}{NATIVE_TOOLKIT_PATH}/custom/sdl3/linux" if="linux" unless="rpi"/>',
				'value="${"$"}{NATIVE_TOOLKIT_PATH}/sdl3/include/build_config" if="android" />\n       <set name="SDL_CONFIG_PATH" value="${"$"}{NATIVE_TOOLKIT_PATH}/custom/sdl3/linux" if="linux" unless="rpi || android"/>');

			// SDL2: Android 使用 default 配置（内部按 __ANDROID__ 选 android 配置）。
			content = StringTools.replace(content,
				'value="${"$"}{NATIVE_TOOLKIT_PATH}/sdl/include/configs/linux/" if="linux" unless="rpi"/>',
				'value="${"$"}{NATIVE_TOOLKIT_PATH}/sdl/include/configs/default/" if="android" />\n       <set name="SDL_CONFIG_PATH" value="${"$"}{NATIVE_TOOLKIT_PATH}/sdl/include/configs/linux/" if="linux" unless="rpi || android"/>');

			// Build.xml 中 SDL2 的 include 路径同样要避免在 Android 交叉编译时使用 Linux config。
			content = StringTools.replace(content,
				'<compilerflag value="-I${"$"}{NATIVE_TOOLKIT_PATH}/sdl/include/configs/linux/" if="linux" unless="rpi" />',
				'<compilerflag value="-I${"$"}{NATIVE_TOOLKIT_PATH}/sdl/include/configs/default/" if="android" />\n\t\t\t\t<compilerflag value="-I${"$"}{NATIVE_TOOLKIT_PATH}/sdl/include/configs/linux/" if="linux" unless="rpi || android" />');

			if (content != original)
			{
				File.saveContent(file, content);
				Sys.println('[SEIUN ENGINE SETUP]: Patched $file');
				anyPatched = true;
			}
		}

		if (!anyPatched)
			Sys.println('[SEIUN ENGINE SETUP]: Lime SDL config already patched or not needed.');
	}
}
