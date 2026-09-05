package backend;

import StringTools;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

/**
 * NativeCrash - C++-level crash hooks (implementation in native_crash.inc).
 *
 * Haxe's try/catch and UncaughtErrorEvent only see Haxe exceptions; driver
 * faults, access violations and LuaJIT aborts kill the process silently.
 * These hooks log, show a best-effort OS popup, and then let the process crash
 * as before; the marker left behind lets the next launch roll into the
 * existing crash-catcher recovery screen:
 *   - Windows SEH: exception code, faulting instruction pointer, access
 *     target pointer, faulting module, registers -> crash/native_crash_*.txt
 *   - POSIX (Linux/macOS): SIGSEGV/SIGABRT/SIGBUS/SIGFPE/SIGILL -> signal,
 *     si_addr memory pointer and backtrace, then re-raise
 */
#if cpp
@:cppInclude('./native_crash.inc')
#end
class NativeCrash
{
	static var installed:Bool = false;

	/** Install native crash hooks first thing in Main.main() so even early startup faults are captured. */
	public static function install():Void
	{
		#if cpp
		if (installed) return;
		installed = true;

		try
		{
			untyped __cpp__("::seiun_install_native_crash_hooks()");

			// pre-create the crash dir (the C++ handler also creates it as a fallback)
			if (!FileSystem.exists('./crash/'))
				FileSystem.createDirectory('./crash/');
		}
		catch (e:Dynamic) {}
		#end
	}

	/**
	 * Install a LuaJIT panic handler on a lua_State (llua.State).
	 *
	 * Unprotected errors inside the Lua VM (no pcall boundary) make LuaJIT print
	 * "PANIC: unprotected error..." and kill the process without leaving any
	 * engine-side log. With this hook the panic writes crash/native_crash_*.txt
	 * (Lua error message + backtrace) before the process aborts.
	 */
	public static function installLuaPanic(luaState:llua.State):Void
	{
		#if cpp
		if (luaState == null) return;
		try
		{
			// Haxe's generated C++ lives in `namespace backend`, so the call must
			// be explicitly global-qualified; otherwise the linker looks for
			// `backend::seiun_install_lua_panic` and fails on Linux/macOS/iOS.
			untyped __cpp__('::seiun_install_lua_panic((void*){0});', luaState);
		}
		catch (e:Dynamic) {}
		#end
	}

	/**
	 * Consume a native crash marker written by native_crash.inc.
	 *
	 * If the previous process ended via a native crash (SEH, fatal signal or
	 * LuaJIT panic), the C++ layer leaves crash/native_crash.pending next to
	 * the log file. This returns the latest log path/content and removes the
	 * marker, so the game can show the crash-catcher recovery screen exactly
	 * once. Native log files themselves are kept for future reports.
	 */
	public static function consumePendingNativeCrash():Null<{path:String, content:String}>
	{
		#if sys
		try
		{
			var markerPath:String = './crash/native_crash.pending';
			if (!FileSystem.exists(markerPath)) return null;

			var logPath:String = StringTools.trim(File.getContent(markerPath));
			if (logPath == '' || !FileSystem.exists(logPath))
			{
				try { FileSystem.deleteFile(markerPath); } catch (e:Dynamic) {}
				return null;
			}

			var content:String = File.getContent(logPath);
			try { FileSystem.deleteFile(markerPath); } catch (e:Dynamic) {}
			return {path: logPath, content: content};
		}
		catch (e:Dynamic)
		{
			return null;
		}
		#else
		return null;
		#end
	}
}
