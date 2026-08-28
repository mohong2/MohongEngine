package backend;

#if cpp
import sys.FileSystem;
#end

/**
 * NativeCrash - C++-level crash hooks (implementation in native_crash.inc).
 *
 * Haxe's try/catch and UncaughtErrorEvent only see Haxe exceptions; driver
 * faults, access violations and LuaJIT aborts kill the process silently.
 * These hooks only observe and log, then let the process crash as before:
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
}
