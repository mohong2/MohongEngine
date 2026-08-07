package mohong;

import openfl.system.System;
import flixel.graphics.FlxGraphic;
import flixel.FlxG;
import haxe.Timer;

/**
 * Memory and frame-time monitoring utility.
 *
 * 仅保留监控功能（帧耗时 / 内存峰值 / 贴图生命周期跟踪），
 * 不含任何自动 GC 或内存清理逻辑 —— 内存回收完全交给 hxcpp 运行时默认行为。
 */
class MemoryMonitor
{
	/** Whether memory monitoring is enabled. */
	public static var monitoringEnabled:Bool = true;

	/** Frame time warning threshold in milliseconds (~30 FPS). */
	public static var frameTimeWarningThreshold:Float = 33.0;

	/** Frame time critical threshold in milliseconds (~20 FPS). */
	public static var frameTimeCriticalThreshold:Float = 50.0;

	/** Whether frame time tracking is enabled. */
	public static var frameTimeTrackingEnabled:Bool = false;

	/** Current memory usage in bytes. */
	public static var currentMemoryUsage(get, never):Float;

	/** Peak memory usage in bytes since tracking started. */
	public static var peakMemoryUsage:Float = 0;

	/** Timestamp of previous frame in milliseconds (for frame time calc). */
	static var _lastFrameTimestamp:Float = 0;

	/** Current frame duration in milliseconds. */
	public static var currentFrameTime:Float = 0;

	/** Smoothed average frame time using exponential moving average. */
	public static var averageFrameTime:Float = 0;

	/** Smoothing factor for frame time EMA (0-1, higher = more responsive). */
	public static var frameTimeSmoothingFactor:Float = 0.1;

	/** Count of cached FlxGraphic entries. */
	public static var cachedGraphicCount(get, never):Int;

	/** Cumulative count of disposed BitmapData objects (for leak detection). */
	public static var disposedBitmapCount:Int = 0;

	/** Tracked FlxGraphic keys for lifecycle monitoring. */
	static var _trackedGraphics:Map<String, FlxGraphic> = new Map<String, FlxGraphic>();

	/** Count of graphics currently alive. */
	public static var livingGraphicCount(get, never):Int;

	/** Whether tracking has been initialized. */
	static var _initialized:Bool = false;

	/** Internal frame counter for throttling expensive checks. */
	static var _frameCounter:Int = 0;

	static function get_currentMemoryUsage():Float
	{
		#if cpp
		return System.totalMemory;
		#else
		return 0;
		#end
	}

	static function get_cachedGraphicCount():Int
	{
		@:privateAccess
		var keys:Array<String> = [for (k in FlxG.bitmap._cache.keys()) k];
		return keys.length;
	}

	static function get_livingGraphicCount():Int
	{
		var count:Int = 0;
		for (key in _trackedGraphics.keys())
		{
			var graphic:FlxGraphic = _trackedGraphics.get(key);
			if (graphic != null)
				count++;
		}
		return count;
	}

	/** Initialize the monitor. Call once at application startup. */
	public static function initialize():Void
	{
		if (_initialized)
			return;
		_initialized = true;
		_lastFrameTimestamp = Timer.stamp() * 1000;
		peakMemoryUsage = currentMemoryUsage;
	}

	/** Call once per frame to track frame times and peak memory (cheap). */
	public static function onFrameStart():Void
	{
		if (!monitoringEnabled || !_initialized)
			return;

		var now:Float = Timer.stamp() * 1000;
		if (_lastFrameTimestamp > 0)
		{
			currentFrameTime = now - _lastFrameTimestamp;
			averageFrameTime = averageFrameTime * (1 - frameTimeSmoothingFactor)
				+ currentFrameTime * frameTimeSmoothingFactor;
		}
		_lastFrameTimestamp = now;

		// 低频更新峰值内存（每 ~120 帧一次 syscall）
		_frameCounter++;
		if (_frameCounter % 120 != 0)
			return;
		var mem:Float = currentMemoryUsage;
		if (mem > peakMemoryUsage)
			peakMemoryUsage = mem;
	}

	/** Get a summary of current memory state as a formatted string. */
	public static function getMemoryReport():String
	{
		var memMB:Int = Std.int(currentMemoryUsage / 1024 / 1024);
		var peakMB:Int = Std.int(peakMemoryUsage / 1024 / 1024);
		return 'Memory: ${memMB}MB / ${peakMB}MB peak | '
			+ 'Graphics cached: ${cachedGraphicCount}';
	}

	/** Register a FlxGraphic for lifecycle tracking. */
	public static function trackGraphic(key:String, graphic:FlxGraphic):Void
	{
		if (graphic == null)
			return;
		_trackedGraphics.set(key, graphic);
	}

	/** Unregister a FlxGraphic when it is destroyed. */
	public static function untrackGraphic(key:String):Void
	{
		_trackedGraphics.remove(key);
	}

	/** Check for potential memory leaks by comparing tracked graphics against FlxG.bitmap cache. */
	public static function detectUntrackedGraphics():Array<String>
	{
		var untracked:Array<String> = [];
		@:privateAccess
		for (key in FlxG.bitmap._cache.keys())
		{
			if (!_trackedGraphics.exists(key))
				untracked.push(key);
		}
		return untracked;
	}
}
