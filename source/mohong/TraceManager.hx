package mohong;

#if sys
import sys.io.File;
import sys.FileSystem;
#end
#if cpp
import sys.thread.Mutex;
#end
import haxe.PosInfos;
import Language;

import mohong.TraceLevel;
import mohong.TraceEntry;

/**
 * Trace 监听器回调类型
 */
typedef TraceListener = TraceEntry -> Void;

/**
 * FNF-SeiunEngine Trace Manager
 * 
 * 统一的 Trace 管理系统：
 * - 拦截所有 haxe.Log.trace 调用
 * - 提供多语言支持的静态 API（info/warn/error/debug）
 * - 维护环形缓冲区存储历史 Trace
 * - 支持实时监听回调
 * - 支持按级别过滤
 * 
 * 用法:
 *   TraceManager.info('trace.fileSaved', 'File saved!');
 *   TraceManager.warn('trace.warning', 'Something suspicious: {}', [detail]);
 *   TraceManager.error('trace.error', 'Failed: {}', [err]);
 *   TraceManager.debug('trace.debug', 'Entering function foo');
 *   
 *   // 注册监听器
 *   TraceManager.addListener(myCallback);
 *   
 *   // 获取所有 Trace
 *   var all = TraceManager.getAll();
 *   
 *   // 获取过滤后的 Trace
 *   var warns = TraceManager.getFiltered([TraceLevel.WARN, TraceLevel.ERROR]);
 */
class TraceManager
{
    /** 环形缓冲区最大容量 */
    public static var MAX_ENTRIES:Int = 5000;

    /** 是否启用 Trace 拦截（默认启用） */
    public static var enabled:Bool = true;

    /** 是否将 Trace 同时输出到控制台 */
    public static var consoleOutput:Bool = true;

    /** 最低输出级别（低于此级别的不输出到控制台） */
    public static var consoleLevel:TraceLevel = DEBUG;

    /** 原始 haxe.Log.trace 引用 */
    private static var originalTrace:Dynamic = null;

    /** 环形缓冲区 - 固定大小数组（避免 O(n) shift） */
    private static var entries:Array<TraceEntry> = [];

    /** 环形缓冲区 - 头指针（下一个要读取的位置） */
    private static var bufferHead:Int = 0;

    /** 环形缓冲区 - 尾指针（下一个要写入的位置） */
    private static var bufferTail:Int = 0;

    /** 环形缓冲区 - 当前有效条目数 */
    private static var bufferCount:Int = 0;

    /** 监听器列表 */
    private static var listeners:Array<TraceListener> = [];

    /** 自增条目 ID */
    private static var entryId:Int = 0;

    /** 保护环形缓冲区数据的互斥锁（仅 cpp 多线程目标需要） */
    #if cpp
    private static var bufferMutex:Mutex = new Mutex();
    #end

    /** 已初始化标志 */
    private static var initialized:Bool = false;

    // -------- 级别名称映射 --------
    private static var levelNames:Map<TraceLevel, String> = [
        DEBUG => "DEBUG",
        INFO  => "INFO",
        WARN  => "WARN",
        ERROR => "ERROR"
    ];

    // -------- 级别颜色（控制台 ANSI） --------
    private static var levelColors:Map<TraceLevel, String> = [
        DEBUG => "\x1b[90m",    // 灰色
        INFO  => "\x1b[37m",    // 白色
        WARN  => "\x1b[33m",    // 黄色
        ERROR => "\x1b[31m"     // 红色
    ];

    /** 重置颜色 */
    private static var RESET_COLOR:String = "\x1b[0m";

    // Language 自身 trace 的识别通过 isLanguageSelfTrace() 完成

    /**
     * 初始化 TraceManager
     * 拦截 haxe.Log.trace，启用 Windows 控制台颜色
     */
    public static function init():Void
    {
        if (initialized) return;
        initialized = true;

        // 启用 Windows 控制台 ANSI 颜色支持
        #if (windows && cpp && !android)
        enableWindowsAnsiColors();
        #end

        // 保存原始 trace 函数并替换
        originalTrace = haxe.Log.trace;
        haxe.Log.trace = captureTrace;

        // 注意：控制台不会在启动时自动打开。
        // 请到 额外设置 → Trace Console 按 Enter 手动打开。
        // 这样避免了 Lime 环境未就绪时写入 stdout 导致的错误。
    }

    /**
     * 从 ClientPrefs 同步设置
     */
    public static function syncWithPrefs():Void
    {
        #if desktop
        // 安全读取设置，处理尚未保存的情况
        var enabled:Bool = (ClientPrefs.data.traceConsoleEnabled == true);
        if (enabled)
        {
            consoleOutput = true;
            var level:String = ClientPrefs.data.traceConsoleLevel;
            if (level != null) applyConsoleLevel(level);
            TraceConsole.start();
        }
        else
        {
            consoleOutput = false;
            TraceConsole.stop();
        }
        #end
    }

    /**
     * 启用或禁用控制台输出
     */
    public static function enableConsoleOutput(enabled:Bool):Void
    {
        consoleOutput = enabled;
        if (enabled)
            info('trace.consoleEnabled', 'Trace console output enabled.');
        else
            info('trace.consoleDisabled', 'Trace console output disabled.');
    }

    /**
     * 应用控制台过滤级别
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
     * 启用 Windows 控制台 ANSI 颜色支持
     * 委托给 Windows.hx（已包含正确的 windows.h 头文件处理）
     */
    #if (windows && cpp && !android)
    private static function enableWindowsAnsiColors():Void
    {
        try {
            Windows.enableAnsiColors();
        } catch (e:Dynamic) {
            // 忽略 — 颜色支持不是关键功能
        }
    }
    #end

    /**
     * 拦截 trace() 的处理器 — 自动支持多语言
     * 
     * 对于拦截到的 trace 消息，如果内容匹配语言键格式（如 "trace.xxx"），
     * 会自动通过 Language 系统查找翻译并替换为本地化文本。
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

        // ── 多语言自动翻译 ──
        // 对所有 trace 消息尝试 Language 翻译。
        // 如果 Language 系统中有对应的键（如 "trace.fileSaved"），
        // 则使用翻译文本；否则保持原文。
        // 注意：跳过 Language 自身输出的消息以避免递归。
        var displayMsg:String = rawMsg;
        if (!isLanguageSelfTrace(fileName))
        {
            var translated:String = Language.get(rawMsg, rawMsg);
            if (translated != rawMsg)
                displayMsg = translated;
        }

        // 创建条目（默认级别为 INFO）
        var entry:TraceEntry = {
            timestamp: haxe.Timer.stamp(),
            level: INFO,
            message: displayMsg,
            rawMessage: rawMsg,
            fileName: fileName,
            lineNumber: lineNumber,
            moduleName: extractModuleName(fileName)
        };

        addEntry(entry);
    }

    /** 判断是否来自 Language.hx 自身，避免递归翻译 */
    private static function isLanguageSelfTrace(fileName:String):Bool
    {
        if (fileName == null) return false;
        // 只匹配 Language.hx 自身文件的 trace
        var lower:String = fileName.toLowerCase();
        // 匹配各种路径形式：Language.hx、/Language.hx、source\Language.hx 等
        return lower.indexOf("language") >= 0
            && (lower.endsWith(".hx") || lower.indexOf("language.hx") >= 0);
    }

    /**
     * 输出 Info 级别 Trace（带多语言支持）
     * @param key 语言键
     * @param defaultText 默认文本（未找到翻译时使用）
     * @param args 插值参数（可选）
     * @param pos 调用位置（自动填充）
     */
    public static function info(key:String, defaultText:String, ?args:Array<Dynamic>, ?pos:haxe.PosInfos):TraceEntry
    {
        return log(INFO, key, defaultText, args, pos);
    }

    /**
     * 输出 Warn 级别 Trace（带多语言支持）
     */
    public static function warn(key:String, defaultText:String, ?args:Array<Dynamic>, ?pos:haxe.PosInfos):TraceEntry
    {
        return log(WARN, key, defaultText, args, pos);
    }

    /**
     * 输出 Error 级别 Trace（带多语言支持）
     */
    public static function error(key:String, defaultText:String, ?args:Array<Dynamic>, ?pos:haxe.PosInfos):TraceEntry
    {
        return log(ERROR, key, defaultText, args, pos);
    }

    /**
     * 输出 Debug 级别 Trace（带多语言支持）
     */
    public static function debug(key:String, defaultText:String, ?args:Array<Dynamic>, ?pos:haxe.PosInfos):TraceEntry
    {
        return log(DEBUG, key, defaultText, args, pos);
    }

    /**
     * 核心日志方法
     */
    private static function log(level:TraceLevel, key:String, defaultText:String, ?args:Array<Dynamic>, ?pos:haxe.PosInfos):TraceEntry
    {
        // 获取翻译文本
        var translated:String = Language.get(key, defaultText);

        // 插值：逐个替换 {}，防止 StringTools.replace 一次替换全部
        if (args != null && args.length > 0)
        {
            for (i in 0...args.length)
            {
                var pos:Int = translated.indexOf('{}');
                if (pos < 0) break;
                translated = translated.substr(0, pos) + Std.string(args[i]) + translated.substr(pos + 2);
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

        // 如果通过 trace() 调用（如 CoolUtil 转发），也调用原始 trace
        // 但我们的方法已经处理了输出，所以不需要

        return entry;
    }

    /**
     * 添加条目到环形缓冲区（O(1) 操作，使用固定大小数组）
     */
    /** 写入锁 — 防止多帧并发写出导致卡死 */
    private static var consoleBusy:Bool = false;

    private static function addEntry(entry:TraceEntry):Void
    {
        // ── 环形缓冲区写入（临界区） ──
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

        bufferTail = (bufferHead + bufferCount) % MAX_ENTRIES;

        #if cpp
        bufferMutex.release();
        #end
        // ── 临界区结束 ──

        // 控制台输出 — 在 Mutex 外执行，避免 WriteConsoleW 阻塞影响其他操作
        // 用标志位防重入（非线程安全但可接受：最多丢一条输出）
        if (consoleOutput && shouldOutput(entry.level) && !consoleBusy)
        {
            consoleBusy = true;
            writeToConsole(entry);
            consoleBusy = false;
        }

        // 通知监听器（也在 Mutex 外，防止监听器死锁）
        notifyListeners(entry);
    }

    /**
     * 判断是否应输出到控制台
     */
    private static function shouldOutput(level:TraceLevel):Bool
    {
        return getLevelOrder(level) >= getLevelOrder(consoleLevel);
    }

    /**
     * 获取级别顺序值
     */
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
     * 格式化并输出到控制台 — 彩色优化版本
     * 
     * 输出格式: [HH:MM:SS.ms][LEVEL] module:line ▸ message
     * 颜色方案:
     *   DEBUG → 灰色
     *   INFO  → 白色/青色
     *   WARN  → 黄色/金色
     *   ERROR → 亮红色
     */
    private static function writeToConsole(entry:TraceEntry):Void
    {
        #if sys
        var timeColor:String = "\x1b[90m";    // 灰色时间
        var moduleColor:String = "\x1b[36m";  // 青色模块名
        var arrowColor:String = "\x1b[90m";   // 灰色箭头
        var levelColor:String = levelColors[entry.level];
        var levelStr:String = levelNames[entry.level];
        var resetColor:String = RESET_COLOR;

        var timeStr:String = formatTimestamp(entry.timestamp);
        var moduleInfo:String = (entry.moduleName != 'unknown')
            ? '$moduleColor${entry.moduleName}:${entry.lineNumber}$resetColor'
            : '';

        // 不同级别输出不同格式
        var output:String = switch (entry.level)
        {
            case DEBUG:
                '$timeColor$timeStr$resetColor '
                + '$levelColor[$levelStr]$resetColor '
                + '$moduleInfo $arrowColor▸$resetColor ${entry.message}';

            case INFO:
                '$timeColor$timeStr$resetColor '
                + '$levelColor[$levelStr]$resetColor '
                + '$moduleInfo $arrowColor▸$resetColor ${entry.message}';

            case WARN:
                '$timeColor$timeStr$resetColor '
                + '$levelColor[$levelStr]$resetColor '
                + '$moduleInfo $arrowColor▸$resetColor '
                + '\x1b[33m${entry.message}$resetColor';

            case ERROR:
                '$timeColor$timeStr$resetColor '
                + '$levelColor[$levelStr]$resetColor '
                + '$moduleInfo $arrowColor▸$resetColor '
                + '\x1b[91m${entry.message}$resetColor';
        }

        // Windows 下用 WriteConsoleW 直接输出（避免 stdout 死锁）
        try {
            #if (windows && cpp && !android)
            Windows.writeConsole(output + '\n');
            #else
            Sys.println(output);
            #end
        } catch (e:Dynamic) {}
        #end
    }

    /**
     * 格式化时间戳
     */
    private static function formatTimestamp(timestamp:Float):String
    {
        var date:Date = Date.fromTime(timestamp * 1000);
        var hours:String = zeroPad(date.getHours(), 2);
        var minutes:String = zeroPad(date.getMinutes(), 2);
        var seconds:String = zeroPad(date.getSeconds(), 2);
        var ms:String = zeroPad(Math.floor((timestamp - Math.floor(timestamp)) * 1000), 3);
        return '$hours:$minutes:$seconds.$ms';
    }

    /**
     * 数字补零
     */
    private static function zeroPad(num:Int, digits:Int):String
    {
        var str:String = Std.string(num);
        while (str.length < digits) str = '0$str';
        return str;
    }

    /**
     * 从文件名提取模块名
     */
    private static function extractModuleName(fileName:String):String
    {
        if (fileName == null || fileName == 'unknown') return 'unknown';
        var parts:Array<String> = fileName.split('/');
        var last:String = parts[parts.length - 1];
        if (last.endsWith('.hx')) last = last.substr(0, last.length - 3);
        return last;
    }

    // -------- 监听器管理 --------

    /**
     * 注册 Trace 监听器
     */
    public static function addListener(listener:TraceListener):Void
    {
        if (!listeners.contains(listener))
            listeners.push(listener);
    }

    /**
     * 移除 Trace 监听器
     */
    public static function removeListener(listener:TraceListener):Void
    {
        listeners.remove(listener);
    }

    /**
     * 通知所有监听器
     */
    private static function notifyListeners(entry:TraceEntry):Void
    {
        for (listener in listeners)
        {
            try {
                listener(entry);
            } catch (e:Dynamic) {
                // 防止监听器崩溃影响系统
                if (consoleOutput)
                    Sys.println('[$RESET_COLOR\x1b[31mERROR\x1b[0m] TraceManager: Listener error: $e');
            }
        }
    }

    /**
     * 获取所有 Trace 条目（按时间顺序）
     */
    public static function getAll():Array<TraceEntry>
    {
        #if cpp
        bufferMutex.acquire();
        #end

        if (bufferCount == 0)
        {
            #if cpp
            bufferMutex.release();
            #end
            return [];
        }

        var result:Array<TraceEntry> = [];
        if (bufferCount < MAX_ENTRIES)
        {
            for (i in 0...bufferCount)
                result.push(entries[i]);
        }
        else
        {
            for (i in 0...bufferCount)
                result.push(entries[(bufferHead + i) % MAX_ENTRIES]);
        }

        #if cpp
        bufferMutex.release();
        #end
        return result;
    }

    /**
     * 获取 Trace 条目数量
     */
    public static function getCount():Int
    {
        return bufferCount;
    }

    /**
     * 获取过滤后的 Trace 条目
     * @param levels 要包含的级别数组（null 表示全部）
     * @param moduleName 按模块名过滤（null 表示全部）
     * @param search 搜索关键词（null 表示全部）
     * @param limit 最大返回数量（0 表示全部）
     */
    public static function getFiltered(?levels:Array<TraceLevel>, ?moduleName:String, ?search:String, ?limit:Int = 0):Array<TraceEntry>
    {
        #if cpp
        bufferMutex.acquire();
        #end

        var result:Array<TraceEntry> = [];

        // 按时间顺序遍历环形缓冲区
        var total:Int = bufferCount;
        for (j in 0...total)
        {
            var idx:Int = (bufferCount < MAX_ENTRIES) ? j : (bufferHead + j) % MAX_ENTRIES;
            var e:TraceEntry = entries[idx];

            // 级别过滤
            if (levels != null && levels.length > 0 && !levels.contains(e.level))
                continue;

            // 模块过滤
            if (moduleName != null && moduleName != '' && e.moduleName != moduleName)
                continue;

            // 关键词搜索
            if (search != null && search != '')
            {
                var lowerSearch:String = search.toLowerCase();
                var lowerMsg:String = e.message.toLowerCase();
                var lowerRaw:String = e.rawMessage.toLowerCase();
                var lowerModule:String = e.moduleName.toLowerCase();
                if (lowerMsg.indexOf(lowerSearch) < 0
                    && lowerRaw.indexOf(lowerSearch) < 0
                    && lowerModule.indexOf(lowerSearch) < 0)
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

    /**
     * 按级别统计 Trace 数量
     */
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

        var total:Int = bufferCount;
        for (j in 0...total)
        {
            var idx:Int = (bufferCount < MAX_ENTRIES) ? j : (bufferHead + j) % MAX_ENTRIES;
            var e:TraceEntry = entries[idx];
            var count:Int = stats[e.level];
            stats[e.level] = count + 1;
        }

        #if cpp
        bufferMutex.release();
        #end
        return stats;
    }

    /**
     * 清空 Trace 缓冲区
     */
    public static function clear():Void
    {
        #if cpp
        bufferMutex.acquire();
        #end

        entries = [];
        bufferHead = 0;
        bufferTail = 0;
        bufferCount = 0;
        entryId = 0;

        #if cpp
        bufferMutex.release();
        #end
    }

    /**
     * 将 Trace 数据导出为 JSON 字符串
     */
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

    /**
     * 将 Trace 数据保存到文件
     */
    public static function saveToFile(path:String, ?levels:Array<TraceLevel>):Void
    {
        #if sys
        var json:String = exportToJson(levels, 0);
        File.saveContent(path, json);
        info('trace.exportSaved', 'Trace data saved to: {}', [path]);
        #end
    }
}
