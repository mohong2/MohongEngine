package mohong;

#if sys
import sys.io.File;
#end
#if cpp
import sys.thread.Mutex;
#end
import haxe.PosInfos;
import Language;

import mohong.TraceLevel;
import mohong.TraceEntry;

/**
 * Trace 监听器回调类型。
 */
typedef TraceListener = TraceEntry -> Void;

/**
 * FNF-SeiunEngine 统一日志中枢（mohong 重写版）。
 *
 * 解决什么问题：
 *   全项目 300+ 处调用点的日志系统。旧实现每条日志（含所有裸 `trace()`）
 *   都无差别做一次 Language 翻译；HTML5 等非 sys 平台完全没有任何输出；
 *   环形缓冲/控制台写的路径也不够省。
 *
 * 挂在哪个真实调用点：
 *   - `init()` 由 Main.new 调用，并拦截 `haxe.Log.trace`（所有裸 trace 汇入）；
 *   - 300+ 处 `TraceManager.info/warn/error/debug` 静态调用；
 *   - `TraceConsole`（监听器）、`OptionsState`（开关/级别）直接依赖本类。
 *
 * 怎么验证它真的在工作：
 *   - Windows 实机：控制台能看到带时间/级别/模块的日志；开关 Trace Console 生效；
 *   - HTML5：编译后浏览器 console 出现引擎日志（js console）；
 *   - 环形缓冲满后内存不再增长（MAX_ENTRIES 上限，切歌 20 次后条目数恒定）。
 *
 * 输出目标按平台分支：
 *   - `#if (cpp && windows)` → WriteConsoleW（Windows.hx）；
 *   - `#elseif sys`        → Sys.println；
 *   - `#elseif js`         → 浏览器 console（html5）。
 */
class TraceManager
{
	/** 环形缓冲最大容量；达到上限后覆盖最旧条目，内存占用恒定。 */
	public static var MAX_ENTRIES:Int = 5000;

	/** 是否拦截并记录 trace（关闭时裸 trace 直接转发给原始 haxe.Log.trace）。 */
	public static var enabled:Bool = true;

	/** 是否同时输出到控制台（按平台走上面的分支）。 */
	public static var consoleOutput:Bool = true;

	/** 最低输出级别：级别 >= consoleLevel 才写控制台。 */
	public static var consoleLevel:TraceLevel = DEBUG;

	/** 原始 haxe.Log.trace 引用（init 时保存）。 */
	private static var originalTrace:Dynamic = null;

	/** 环形缓冲底层数组（容量封顶 MAX_ENTRIES）。 */
	private static var entries:Array<TraceEntry> = [];

	/** 环形缓冲写入位置（满后从此处覆盖最旧条目）。 */
	private static var bufferHead:Int = 0;

	/** 当前有效条目数（0..MAX_ENTRIES）。 */
	private static var bufferCount:Int = 0;

	/** 监听器列表（TraceConsole 等）。 */
	private static var listeners:Array<TraceListener> = [];

	/** 自增条目 ID。 */
	private static var entryId:Int = 0;

	/** 保护环形缓冲（cpp 多线程目标：HTTP/视频线程也会 trace）。 */
	#if cpp
	private static var bufferMutex:Mutex = new Mutex();
	#end

	/** 已初始化标志。 */
	private static var initialized:Bool = false;

	/** 写控制台防重入标志（WriteConsoleW 是同步调用，防止重入导致卡死）。 */
	private static var consoleBusy:Bool = false;

	/** 级别 → 名称。 */
	private static var levelNames:Map<TraceLevel, String> = [
		DEBUG => "DEBUG",
		INFO  => "INFO",
		WARN  => "WARN",
		ERROR => "ERROR"
	];

	/** 级别 → ANSI 颜色（原生终端）。 */
	private static var levelColors:Map<TraceLevel, String> = [
		DEBUG => "\x1b[90m",
		INFO  => "\x1b[37m",
		WARN  => "\x1b[33m",
		ERROR => "\x1b[31m"
	];

	private static var RESET_COLOR:String = "\x1b[0m";

	/**
	 * 初始化：拦截 haxe.Log.trace；Windows 桌面启用控制台 ANSI 颜色。
	 * 不主动打开控制台（Options 里的 Trace Console 开关负责）。
	 */
	public static function init():Void
	{
		if (initialized) return;
		initialized = true;

		#if (windows && cpp && !android)
		try {
			Windows.enableAnsiColors();
		} catch (e:Dynamic) {
			// 颜色不是关键功能，忽略
		}
		#end

		originalTrace = haxe.Log.trace;
		haxe.Log.trace = captureTrace;
	}

	/**
	 * 从 ClientPrefs 同步设置（桌面端：根据存档决定是否输出+启动 TraceConsole）。
	 */
	public static function syncWithPrefs():Void
	{
		#if desktop
		var wantConsole:Bool = (ClientPrefs.data.traceConsoleEnabled == true);
		consoleOutput = wantConsole;
		if (wantConsole)
		{
			var level:String = ClientPrefs.data.traceConsoleLevel;
			if (level != null) applyConsoleLevel(level);
			TraceConsole.start();
		}
		else
		{
			TraceConsole.stop();
		}
		#end
	}

	/**
	 * 启用/禁用控制台输出。
	 */
	public static function enableConsoleOutput(on:Bool):Void
	{
		consoleOutput = on;
		if (on)
			info('trace.consoleEnabled', 'Trace console output enabled.');
		else
			info('trace.consoleDisabled', 'Trace console output disabled.');
	}

	/**
	 * 应用控制台过滤级别（按名字，大小写不敏感）。
	 */
	public static function applyConsoleLevel(levelName:String):Void
	{
		if (levelName == null || levelName.length == 0) return;
		consoleLevel = switch (levelName.toUpperCase())
		{
			case 'DEBUG': DEBUG;
			case 'INFO':  INFO;
			case 'WARN', 'WARNING': WARN;
			case 'ERROR': ERROR;
			default: DEBUG;
		}
	}

	/**
	 * 拦截裸 trace() 的处理器。
	 * 只有消息本身像语言键（无空格、含点、Language.has 命中）时才做翻译——
	 * 自由文本日志（如 'hello world'）不再浪费一次字典查找。
	 */
	private static function captureTrace(v:Dynamic, ?infos:haxe.PosInfos):Void
	{
		if (!enabled)
		{
			if (originalTrace != null) originalTrace(v, infos);
			return;
		}

		var rawMsg:String = Std.string(v);
		var fileName:String = (infos != null && infos.fileName != null) ? infos.fileName : 'unknown';
		var lineNumber:Int = (infos != null) ? infos.lineNumber : 0;

		var displayMsg:String = rawMsg;
		if (!isLanguageSelfTrace(fileName) && isLangKeyLike(rawMsg) && Language.has(rawMsg))
			displayMsg = Language.get(rawMsg, rawMsg);

		addEntry({
			timestamp: haxe.Timer.stamp(),
			level: INFO,
			message: displayMsg,
			rawMessage: rawMsg,
			fileName: fileName,
			lineNumber: lineNumber,
			moduleName: extractModuleName(fileName)
		});
	}

	/** 消息是否"像语言键"：含点、无空白、无异常字符。 */
	private static function isLangKeyLike(msg:String):Bool
	{
		if (msg == null || msg.length == 0 || msg.indexOf('.') < 0) return false;
		for (i in 0...msg.length)
		{
			var c:Int = msg.charCodeAt(i);
			var ok:Bool = (c >= 97 && c <= 122)   // a-z
				|| (c >= 65 && c <= 90)           // A-Z
				|| (c >= 48 && c <= 57)           // 0-9
				|| c == 46 || c == 95 || c == 45; // . _ -
			if (!ok) return false;
		}
		return true;
	}

	/** 判断是否来自 Language.hx 自身，避免递归翻译。 */
	private static function isLanguageSelfTrace(fileName:String):Bool
	{
		if (fileName == null) return false;
		var lower:String = fileName.toLowerCase();
		return lower.indexOf("language") >= 0
			&& (lower.endsWith(".hx") || lower.indexOf("language.hx") >= 0);
	}

	// -------- 四级静态 API（签名与旧版完全兼容） --------

	public static function info(key:String, defaultText:String, ?args:Array<Dynamic>, ?pos:haxe.PosInfos):TraceEntry
	{
		return log(INFO, key, defaultText, args, pos);
	}

	public static function warn(key:String, defaultText:String, ?args:Array<Dynamic>, ?pos:haxe.PosInfos):TraceEntry
	{
		return log(WARN, key, defaultText, args, pos);
	}

	public static function error(key:String, defaultText:String, ?args:Array<Dynamic>, ?pos:haxe.PosInfos):TraceEntry
	{
		return log(ERROR, key, defaultText, args, pos);
	}

	public static function debug(key:String, defaultText:String, ?args:Array<Dynamic>, ?pos:haxe.PosInfos):TraceEntry
	{
		return log(DEBUG, key, defaultText, args, pos);
	}

	/**
	 * 核心日志方法：翻译 → 插值（逐个替换 {}）→ 入环形缓冲 → 控制台 → 监听器。
	 */
	private static function log(level:TraceLevel, key:String, defaultText:String, ?args:Array<Dynamic>, ?pos:haxe.PosInfos):TraceEntry
	{
		var translated:String = Language.get(key, defaultText);

		if (args != null && args.length > 0)
		{
			for (i in 0...args.length)
			{
				var idx:Int = translated.indexOf('{}');
				if (idx < 0) break;
				translated = translated.substr(0, idx) + Std.string(args[i]) + translated.substr(idx + 2);
			}
		}

		var fileName:String = (pos != null && pos.fileName != null) ? pos.fileName : 'unknown';
		var lineNumber:Int = (pos != null) ? pos.lineNumber : 0;

		var entry:TraceEntry = {
			timestamp: haxe.Timer.stamp(),
			level: level,
			message: translated,
			rawMessage: defaultText,
			fileName: fileName,
			lineNumber: lineNumber,
			moduleName: extractModuleName(fileName)
		};

		addEntry(entry);
		return entry;
	}

	/**
	 * 环形缓冲写入（O(1)，临界区只在 cpp 加锁）。
	 * 控制台输出与监听器通知都在锁外执行。
	 */
	private static function addEntry(entry:TraceEntry):Void
	{
		#if cpp
		bufferMutex.acquire();
		#end

		entryId++;
		if (bufferCount < MAX_ENTRIES)
		{
			entries.push(entry);
			bufferCount++;
		}
		else
		{
			entries[bufferHead] = entry;
			bufferHead = (bufferHead + 1) % MAX_ENTRIES;
		}

		#if cpp
		bufferMutex.release();
		#end

		if (consoleOutput && shouldOutput(entry.level) && !consoleBusy)
		{
			consoleBusy = true;
			writeToConsole(entry);
			consoleBusy = false;
		}

		if (listeners.length > 0)
			notifyListeners(entry);
	}

	private static function shouldOutput(level:TraceLevel):Bool
	{
		return getLevelOrder(level) >= getLevelOrder(consoleLevel);
	}

	private static function getLevelOrder(level:TraceLevel):Int
	{
		return switch (level) {
			case DEBUG: 0;
			case INFO:  1;
			case WARN:  2;
			case ERROR: 3;
		}
	}

	/**
	 * 格式化并输出到控制台 —— 按平台分支。
	 * 格式: [HH:MM:SS.ms][LEVEL] module:line ▸ message
	 */
	private static function writeToConsole(entry:TraceEntry):Void
	{
		var timeStr:String = formatTimestamp(entry.timestamp);
		var levelStr:String = levelNames[entry.level];
		var moduleInfo:String = (entry.moduleName != 'unknown')
			? '${entry.moduleName}:${entry.lineNumber}'
			: '';

		#if (cpp && windows && !android)
		// Windows：WriteConsoleW（UTF-8 安全，避免 stdout 重定向死锁）
		var levelColor:String = levelColors[entry.level];
		var line:String = '\x1b[90m$timeStr$RESET_COLOR $levelColor[$levelStr]$RESET_COLOR '
			+ (moduleInfo != '' ? '\x1b[36m$moduleInfo$RESET_COLOR ' : '')
			+ '\x1b[90m\u25B8$RESET_COLOR ${entry.message}';
		try {
			Windows.writeConsole(line + '\n');
		} catch (e:Dynamic) {}
		#elseif sys
		var levelColor:String = levelColors[entry.level];
		var line:String = '\x1b[90m$timeStr$RESET_COLOR $levelColor[$levelStr]$RESET_COLOR '
			+ (moduleInfo != '' ? '\x1b[36m$moduleInfo$RESET_COLOR ' : '')
			+ '\x1b[90m\u25B8$RESET_COLOR ${entry.message}';
		try {
			Sys.println(line);
		} catch (e:Dynamic) {}
		#elseif js
		// HTML5：浏览器 console，级别映射到对应方法
		var line:String = '$timeStr [$levelStr]'
			+ (moduleInfo != '' ? ' $moduleInfo' : '')
			+ ' ${entry.message}';
		try {
			switch (entry.level) {
				case DEBUG: js.Browser.console.debug(line);
				case INFO:  js.Browser.console.info(line);
				case WARN:  js.Browser.console.warn(line);
				case ERROR: js.Browser.console.error(line);
			}
		} catch (e:Dynamic) {}
		#end
	}

	private static function formatTimestamp(timestamp:Float):String
	{
		var date:Date = Date.fromTime(timestamp * 1000);
		var hours:String = zeroPad(date.getHours(), 2);
		var minutes:String = zeroPad(date.getMinutes(), 2);
		var seconds:String = zeroPad(date.getSeconds(), 2);
		var ms:String = zeroPad(Math.floor((timestamp - Math.floor(timestamp)) * 1000), 3);
		return '$hours:$minutes:$seconds.$ms';
	}

	private static function zeroPad(num:Int, digits:Int):String
	{
		var str:String = Std.string(num);
		while (str.length < digits) str = '0$str';
		return str;
	}

	private static function extractModuleName(fileName:String):String
	{
		if (fileName == null || fileName == 'unknown') return 'unknown';
		var parts:Array<String> = fileName.split('/');
		var last:String = parts[parts.length - 1];
		if (last.endsWith('.hx')) last = last.substr(0, last.length - 3);
		return last;
	}

	// -------- 监听器管理 --------

	public static function addListener(listener:TraceListener):Void
	{
		if (!listeners.contains(listener))
			listeners.push(listener);
	}

	public static function removeListener(listener:TraceListener):Void
	{
		listeners.remove(listener);
	}

	private static function notifyListeners(entry:TraceEntry):Void
	{
		for (listener in listeners)
		{
			try {
				listener(entry);
			} catch (e:Dynamic) {
				// 监听器崩溃不影响日志系统本身
			}
		}
	}

	// -------- 查询 / 导出 API --------

	/** 获取所有 Trace 条目（按时间顺序，快照拷贝）。 */
	public static function getAll():Array<TraceEntry>
	{
		#if cpp
		bufferMutex.acquire();
		#end

		var result:Array<TraceEntry> = [];
		for (i in 0...bufferCount)
		{
			var idx:Int = (bufferCount < MAX_ENTRIES) ? i : (bufferHead + i) % MAX_ENTRIES;
			result.push(entries[idx]);
		}

		#if cpp
		bufferMutex.release();
		#end
		return result;
	}

	/** 当前有效条目数。 */
	public static function getCount():Int
	{
		return bufferCount;
	}

	/**
	 * 按级别/模块/关键词过滤（null/空 = 不过滤），limit 0 = 全部。
	 */
	public static function getFiltered(?levels:Array<TraceLevel>, ?moduleName:String, ?search:String, ?limit:Int = 0):Array<TraceEntry>
	{
		#if cpp
		bufferMutex.acquire();
		#end

		var result:Array<TraceEntry> = [];
		for (j in 0...bufferCount)
		{
			var idx:Int = (bufferCount < MAX_ENTRIES) ? j : (bufferHead + j) % MAX_ENTRIES;
			var e:TraceEntry = entries[idx];

			if (levels != null && levels.length > 0 && !levels.contains(e.level))
				continue;

			if (moduleName != null && moduleName != '' && e.moduleName != moduleName)
				continue;

			if (search != null && search != '')
			{
				var lowerSearch:String = search.toLowerCase();
				if (e.message.toLowerCase().indexOf(lowerSearch) < 0
					&& e.rawMessage.toLowerCase().indexOf(lowerSearch) < 0
					&& e.moduleName.toLowerCase().indexOf(lowerSearch) < 0)
					continue;
			}

			result.push(e);

			if (limit > 0 && result.length >= limit)
				break;
		}

		#if cpp
		bufferMutex.release();
		#end
		return result;
	}

	/** 按级别统计条目数。 */
	public static function getStats():Map<TraceLevel, Int>
	{
		#if cpp
		bufferMutex.acquire();
		#end

		var stats:Map<TraceLevel, Int> = [
			DEBUG => 0,
			INFO  => 0,
			WARN  => 0,
			ERROR => 0
		];

		for (j in 0...bufferCount)
		{
			var idx:Int = (bufferCount < MAX_ENTRIES) ? j : (bufferHead + j) % MAX_ENTRIES;
			var e:TraceEntry = entries[idx];
			stats[e.level] = stats[e.level] + 1;
		}

		#if cpp
		bufferMutex.release();
		#end
		return stats;
	}

	/** 清空缓冲。 */
	public static function clear():Void
	{
		#if cpp
		bufferMutex.acquire();
		#end

		entries = [];
		bufferHead = 0;
		bufferCount = 0;
		entryId = 0;

		#if cpp
		bufferMutex.release();
		#end
	}

	/** 导出为 JSON 字符串。 */
	public static function exportToJson(?levels:Array<TraceLevel>, ?limit:Int = 100):String
	{
		var data:Array<Dynamic> = [];
		var filtered:Array<TraceEntry> = getFiltered(levels, null, null, limit);

		for (entry in filtered)
		{
			data.push({
				timestamp: entry.timestamp,
				level: levelNames[entry.level],
				message: entry.message,
				file: entry.fileName,
				line: entry.lineNumber,
				module: entry.moduleName
			});
		}

		return haxe.Json.stringify(data, '  ');
	}

	/** 将 Trace 数据保存到文件（仅 sys 平台）。 */
	public static function saveToFile(path:String, ?levels:Array<TraceLevel>):Void
	{
		#if sys
		var json:String = exportToJson(levels, 0);
		File.saveContent(path, json);
		info('trace.exportSaved', 'Trace data saved to: {}', [path]);
		#end
	}
}
