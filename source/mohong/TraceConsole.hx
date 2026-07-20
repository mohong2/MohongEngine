package mohong;

#if sys
import sys.FileSystem;
#end

import mohong.TraceLevel;
import mohong.TraceEntry;

/**
 * 
 * 
 * 纯粹的 Trace 实时监控面板，无交互命令。
 * - 实时显示 Trace 数据流（颜色区分级别）
 * - 由 TraceManager 驱动，watch 模式下自动输出
 */
class TraceConsole
{
    /** 是否已启动 */
    private static var running:Bool = false;

    /** 当前监控模式（由 TraceManager 控制） */
    private static var watchMode:Bool = false;

    /** ANSI 颜色代码 */
    private static var RESET:String = "\x1b[0m";
    private static var GRAY:String = "\x1b[90m";
    private static var BLUE:String = "\x1b[34m";

    /**
     * 启动实时监控
     */
    public static function start():Void
    {
        if (running) return;
        running = true;
        watchMode = true;
        TraceManager.addListener(onTrace);

        // 简单启动提示
        printLine(GRAY + "[TraceConsole] Monitoring started." + RESET);
    }

    /**
     * 停止监控
     */
    public static function stop():Void
    {
        if (!running) return;
        running = false;
        watchMode = false;
        TraceManager.removeListener(onTrace);
    }

    /**
     * Trace 回调 — 实时输出带颜色的 Trace
     */
    private static function onTrace(entry:TraceEntry):Void
    {
        if (!watchMode) return;

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
     * 打印一行到控制台
     */
    private static function printLine(text:String):Void
    {
        #if (windows && cpp && !android)
        try {
            Windows.writeConsole(text + '\n');
        } catch (e:Dynamic) {
            try { Sys.println(text); } catch (e2:Dynamic) {}
        }
        #elseif sys
        try { Sys.println(text); } catch (e:Dynamic) {}
        #end
    }

    /**
     * 格式化时间 HH:MM:SS
     */
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
