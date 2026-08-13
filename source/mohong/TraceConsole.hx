package mohong;

import mohong.TraceLevel;
import mohong.TraceEntry;

/**
 * Trace 实时监控面板（重写版）。
 *
 * 解决什么问题：
 *   为 TraceManager 提供实时输出通道（监听器）。旧实现的输出路径与
 *   TraceManager 各写一套、非 Windows 平台不完整。
 *
 * 挂在哪个真实调用点：
 *   - Main.new 在桌面端调用 `start()`；
 *   - OptionsState 的 Trace Console 开关调用 `start()/stop()`；
 *   - 监听 TraceManager.addListener 的数据流。
 *
 * 怎么验证它真的在工作：
 *   Windows 实机打开 Trace Console 后，控制台持续刷出带颜色分级的日志；
 *   关闭后日志不再输出（TraceManager 自身仍记录进环形缓冲）。
 */
class TraceConsole
{
	private static var running:Bool = false;
	private static var watchMode:Bool = false;

	/** 是否存在真实输出目标：没有控制台时跳过逐条格式化（避免纯浪费）。 */
	private static var consoleAvailable:Bool = false;

	private static var RESET:String = "\x1b[0m";
	private static var GRAY:String = "\x1b[90m";
	private static var BLUE:String = "\x1b[34m";

	/**
	 * 启动实时监控（幂等）。启动时探测输出目标是否真的存在。
	 */
	public static function start():Void
	{
		if (running) return;
		running = true;
		watchMode = true;
		consoleAvailable = detectConsole();
		TraceManager.addListener(onTrace);
		if (consoleAvailable)
			printLine(GRAY + "[TraceConsole] Monitoring started." + RESET);
	}

	/**
	 * 停止监控（幂等）。
	 */
	public static function stop():Void
	{
		if (!running) return;
		running = false;
		watchMode = false;
		TraceManager.removeListener(onTrace);
	}

	/** 输出目标探测：Windows 看是否有控制台窗口；sys/js 平台恒有 stdout/js console。 */
	private static function detectConsole():Bool
	{
		#if (cpp && windows && !android)
		try {
			return Windows.hasConsole();
		} catch (e:Dynamic) {
			return false;
		}
		#elseif (sys || js)
		return true;
		#else
		return false;
		#end
	}

	/**
	 * Trace 回调 — 带颜色输出一条日志。无输出目标时直接返回（零格式化开销）。
	 */
	private static function onTrace(entry:TraceEntry):Void
	{
		if (!watchMode || !consoleAvailable) return;

		var lvlColor:String = switch (entry.level) {
			case DEBUG: "\x1b[90m";
			case INFO:  "\x1b[37m";
			case WARN:  "\x1b[33m";
			case ERROR: "\x1b[31m";
		}
		var lvlName:String = switch (entry.level) {
			case DEBUG: "DEBUG";  case INFO:  "INFO";
			case WARN:  "WARN";   case ERROR: "ERROR";
		}

		var timeStr:String = GRAY + "[" + formatTime(entry.timestamp) + "]" + RESET;
		var modStr:String = BLUE + entry.moduleName + ":" + entry.lineNumber + RESET;

		printLine('$timeStr $lvlColor[$lvlName]$RESET $modStr ${entry.message}');
	}

	/**
	 * 打印一行到控制台 —— 平台分支与 TraceManager 一致。
	 */
	private static function printLine(text:String):Void
	{
		#if (cpp && windows && !android)
		try {
			Windows.writeConsole(text + '\n');
		} catch (e:Dynamic) {
			try { Sys.println(text); } catch (e2:Dynamic) {}
		}
		#elseif sys
		try { Sys.println(text); } catch (e:Dynamic) {}
		#elseif js
		try { js.Browser.console.log(text); } catch (e:Dynamic) {}
		#end
	}

	private static function formatTime(timestamp:Float):String
	{
		var date:Date = Date.fromTime(Std.int(timestamp * 1000));
		return  zeroPad(date.getHours(), 2) + ":"
		      + zeroPad(date.getMinutes(), 2) + ":"
		      + zeroPad(date.getSeconds(), 2);
	}

	private static function zeroPad(num:Int, digits:Int):String
	{
		var str:String = Std.string(num);
		while (str.length < digits) str = '0$str';
		return str;
	}
}
