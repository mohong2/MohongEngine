package mohong;

#if cpp
import cpp.vm.Gc;
#end
import openfl.system.System;
import openfl.Lib;
import flixel.graphics.FlxGraphic;
import flixel.FlxG;
import haxe.Timer;

/**
 * Memory monitoring and optimization utility.
 * 
 * Features:
 * - Track current / peak memory usage
 * - Periodic automatic garbage collection
 * - Memory pressure detection with auto-release
 * - Frame time tracking for jank detection
 * - FlxGraphic lifecycle tracking for leak detection
 * 
 * Design: soft-coded — all thresholds and intervals are configurable.
 */
class MemoryMonitor
{
	// ═══════════════════════════════════════
	//  Configurable constants (soft-coded)
	// ═══════════════════════════════════════

	/** Memory pressure threshold in bytes (3 GB). Triggers cache cleanup when exceeded. */
	public static var memoryPressureThreshold:Float = 3.0 * 1024 * 1024 * 1024;

	/** Critical memory pressure threshold in bytes (3.5 GB). Triggers emergency cleanup when exceeded. */
	public static var criticalMemoryThreshold:Float = 3.5 * 1024 * 1024 * 1024;

	/** Auto-GC interval in seconds. */
	public static var garbageCollectionInterval:Float = 30.0;

	/** Frame time warning threshold in milliseconds (~30 FPS). */
	public static var frameTimeWarningThreshold:Float = 33.0;

	/** Frame time critical threshold in milliseconds (~20 FPS). */
	public static var frameTimeCriticalThreshold:Float = 50.0;

	/** Whether memory monitoring is enabled. */
	public static var monitoringEnabled:Bool = true;

	/** Whether frame time tracking is enabled. */
	public static var frameTimeTrackingEnabled:Bool = false;

	/** Whether to auto-release unused assets under memory pressure.
	 *  WARNING: Enabling this may destroy GPU textures still in use, causing rendering errors.
	 *  Only enable if you fully understand the risks. */
	public static var autoReleaseOnPressure:Bool = false;

	/** Whether to trigger GC on state switch. */
	public static var garbageCollectOnStateSwitch:Bool = true;

	/** Whether to log memory warnings to TraceManager. */
	public static var logWarnings:Bool = true;

	// ═══════════════════════════════════════
	//  Runtime state
	// ═══════════════════════════════════════

	/** Current memory usage in bytes. */
	public static var currentMemoryUsage(get, never):Float;

	/** Peak memory usage in bytes since tracking started. */
	public static var peakMemoryUsage:Float = 0;

	/** Timestamp of last GC trigger in milliseconds. */
	static var _lastGarbageCollectionTime:Float = 0;

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

	/** Whether the system is under memory pressure. */
	public static var isUnderMemoryPressure(get, never):Bool;

	/** Whether the system is under critical memory pressure. */
	public static var isUnderCriticalPressure(get, never):Bool;

	/** Cumulative GC trigger count. */
	public static var garbageCollectionCount:Int = 0;

	/** Internal frame counter for throttling expensive checks. */
	static var _frameCounter:Int = 0;

	/** Cumulative count of disposed BitmapData objects (for leak detection). */
	public static var disposedBitmapCount:Int = 0;

	/** Tracked FlxGraphic keys for lifecycle monitoring. */
	static var _trackedGraphics:Map<String, FlxGraphic> = new Map<String, FlxGraphic>();

	/** Count of graphics currently alive. */
	public static var livingGraphicCount(get, never):Int;

	/** Whether tracking has been initialized. */
	static var _initialized:Bool = false;

	// ═══════════════════════════════════════
	//  Property accessors
	// ═══════════════════════════════════════

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
			// FlxGraphic extends FlxBasic which has exists/alive properties
			if (graphic != null)
				count++;
		}
		return count;
	}

	static function get_isUnderMemoryPressure():Bool
	{
		return currentMemoryUsage > memoryPressureThreshold;
	}

	static function get_isUnderCriticalPressure():Bool
	{
		return currentMemoryUsage > criticalMemoryThreshold;
	}

	// ═══════════════════════════════════════
	//  Initialization
	// ═══════════════════════════════════════

	/**
	 * Initialize the memory monitor. Call once at application startup.
	 */
	public static function initialize():Void
	{
		if (_initialized)
			return;
		_initialized = true;
		_lastGarbageCollectionTime = Timer.stamp() * 1000;
		_lastFrameTimestamp = _lastGarbageCollectionTime;
		peakMemoryUsage = currentMemoryUsage;
	}

	// ═══════════════════════════════════════
	//  Per-frame update
	// ═══════════════════════════════════════

	/**
	 * Call once per frame to track frame times only (cheap — no syscall).
	 * Heavy operations (GC, memory pressure) run on a separate low-frequency timer.
	 */
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

		// Only run expensive checks once every ~120 frames (~2 seconds at 60 FPS)
		_frameCounter++;
		if (_frameCounter % 120 != 0)
			return;

		// Update peak memory (single syscall every ~2s, not every frame)
		var mem:Float = currentMemoryUsage;
		if (mem > peakMemoryUsage)
			peakMemoryUsage = mem;

		// Periodic GC
		if (now - _lastGarbageCollectionTime > garbageCollectionInterval * 1000)
		{
			triggerGarbageCollection('periodic');
		}
	}

	// ═══════════════════════════════════════
	//  GC management
	// ═══════════════════════════════════════

	/**
	 * Trigger garbage collection with a reason tag for diagnostics.
	 * @param reason Descriptor for why GC was triggered (e.g. 'stateSwitch', 'periodic', 'manual').
	 */
	public static function triggerGarbageCollection(reason:String = 'manual'):Void
	{
		#if cpp
		var before:Float = currentMemoryUsage;
		Gc.run(true); // major collection
		Gc.compact(); // compact heap to reduce fragmentation
		var after:Float = currentMemoryUsage;
		#end

		_lastGarbageCollectionTime = Timer.stamp() * 1000;
		garbageCollectionCount++;

		#if cpp
		if (logWarnings && before - after > 5 * 1024 * 1024) // Only log if >5MB freed
		{
			TraceManager.debug('memoryMonitor.gcComplete',
				'GC #{count} ({reason}): {before}MB -> {after}MB freed {freed}MB',
				[garbageCollectionCount, reason, Std.int(before / 1024 / 1024),
				 Std.int(after / 1024 / 1024), Std.int((before - after) / 1024 / 1024)]);
		}
		#end
	}

	// ═══════════════════════════════════════
	//  Pressure handling
	// ═══════════════════════════════════════

	static function handleMemoryPressure():Void
	{
		if (logWarnings)
		{
			TraceManager.warn('memoryMonitor.pressure',
				'Memory pressure: {mem}MB / {threshold}MB',
				[Std.int(currentMemoryUsage / 1024 / 1024),
				 Std.int(memoryPressureThreshold / 1024 / 1024)]);
		}

		// Clear unused cached assets
		Paths.clearUnusedMemory();
	}

	static function handleCriticalPressure():Void
	{
		if (logWarnings)
		{
			TraceManager.error('memoryMonitor.criticalPressure',
				'CRITICAL memory pressure: {mem}MB / {threshold}MB — emergency cleanup',
				[Std.int(currentMemoryUsage / 1024 / 1024),
				 Std.int(criticalMemoryThreshold / 1024 / 1024)]);
		}

		// Force-clear all non-essential caches
		Paths.clearStoredMemory(true);
		triggerGarbageCollection('criticalPressure');

		#if cpp
		// On critical pressure, also clear OpenFL internal caches
		@:privateAccess
		{
			openfl.Assets.cache.clear();
		}
		#end
	}

	// ═══════════════════════════════════════
	//  FlxGraphic lifecycle tracking (leak detection)
	// ═══════════════════════════════════════

	/**
	 * Register a FlxGraphic for lifecycle tracking.
	 * Call when loading/creating a new graphic asset.
	 */
	public static function trackGraphic(key:String, graphic:FlxGraphic):Void
	{
		if (graphic == null)
			return;
		_trackedGraphics.set(key, graphic);
	}

	/**
	 * Unregister a FlxGraphic when it is destroyed.
	 * Call when explicitly destroying a graphic.
	 */
	public static function untrackGraphic(key:String):Void
	{
		_trackedGraphics.remove(key);
	}

	/**
	 * Check for potential memory leaks by comparing tracked graphics
	 * against FlxG.bitmap cache. Returns keys that exist in the cache
	 * but were not explicitly tracked.
	 */
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

	/**
	 * Get a summary of current memory state as a formatted string.
	 */
	public static function getMemoryReport():String
	{
		var memMB:Int = Std.int(currentMemoryUsage / 1024 / 1024);
		var peakMB:Int = Std.int(peakMemoryUsage / 1024 / 1024);
		var avgFPS:Float = averageFrameTime > 0 ? 1000.0 / averageFrameTime : 0;
		return 'Memory: ${memMB}MB / ${peakMB}MB peak | '
			+ 'Graphics cached: ${cachedGraphicCount} | '
			+ 'GC count: ${garbageCollectionCount} | '
			+ 'Avg FPS: ${Std.int(avgFPS)}';
	}

	/**
	 * Called on state switch to clean up and optionally trigger GC.
	 */
	public static function onStateSwitch():Void
	{
		if (!monitoringEnabled)
			return;

		// Clear per-state caches
		Paths.clearUnusedMemory();

		if (garbageCollectOnStateSwitch)
		{
			triggerGarbageCollection('stateSwitch');
		}
	}
}
