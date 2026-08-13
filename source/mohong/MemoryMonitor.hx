package mohong;

import flixel.graphics.FlxGraphic;
import flixel.FlxG;
import haxe.Timer;
#if cpp
import openfl.system.System;
import cpp.vm.Gc;
#end

/**
 * Memory + frame-time sampler. Read-only: no GC, no reclaim here.
 * Memory read is per-platform (cpp heap / js performance.memory / 0).
 */
class MemoryMonitor
{
	/** On/off (ClientPrefs.memoryOptimization). */
	public static var monitoringEnabled:Bool = true;

	/** Frame-time warn threshold, ms (~30fps). */
	public static var frameTimeWarningThreshold:Float = 33.0;

	/** Frame-time critical threshold, ms (~20fps). */
	public static var frameTimeCriticalThreshold:Float = 50.0;

	/** Record frame-time ring (for percentiles); off by default. */
	public static var frameTimeTrackingEnabled:Bool = false;

	/** Current memory bytes, per platform. */
	public static var currentMemoryUsage(get, never):Float;

	/** Peak memory since start. */
	public static var peakMemoryUsage:Float = 0;

	static var _lastFrameTimestamp:Float = 0;

	/** Last frame time, ms. */
	public static var currentFrameTime:Float = 0;

	/** EMA of frame time, ms. */
	public static var averageFrameTime:Float = 0;

	/** EMA smoothing factor. */
	public static var frameTimeSmoothingFactor:Float = 0.1;

	/** Cached graphic count (refreshed every 60 frames). */
	public static var cachedGraphicCount(get, never):Int;

	/** Untracked/destroyed count. */
	public static var disposedBitmapCount:Int = 0;

	/** Tracked graphics (key -> graphic). */
	static var _trackedGraphics:Map<String, FlxGraphic> = new Map<String, FlxGraphic>();

	/** Live tracked count, kept O(1). */
	static var _livingCount:Int = 0;

	public static var livingGraphicCount(get, never):Int;

	static var _initialized:Bool = false;
	static var _frameCounter:Int = 0;
	static var _cachedGraphicCountValue:Int = 0;

	// frame-time ring (~68s @60fps)
	static final FRAME_WINDOW:Int = 4096;
	static var _frameTimes:Array<Float> = [];
	static var _frameTimeCount:Int = 0;

	// memory sample history for the CSV curve
	static final MEM_SAMPLE_INTERVAL:Int = 120;
	static final MEM_HISTORY_CAP:Int = 10000;
	static var _memHistory:Array<MemSample> = [];

	#if cpp
	/** hxcpp GC heap now (sawtooth shows GC), cpp only. */
	public static var gcCurrentMemory(get, never):Float;
	static function get_gcCurrentMemory():Float
	{
		return Gc.memInfo64(Gc.MEM_INFO_CURRENT);
	}
	#end

	static function get_currentMemoryUsage():Float
	{
		#if cpp
		return System.totalMemory;
		#elseif js
		// browser GC: performance.memory is Chrome/Edge only;
		// elsewhere return 0.
		return untyped __js__('
			(window.performance && window.performance.memory)
				? window.performance.memory.usedJSHeapSize
				: 0
		');
		#else
		return 0;
		#end
	}

	static function get_cachedGraphicCount():Int
	{
		return _cachedGraphicCountValue;
	}

	static function get_livingGraphicCount():Int
	{
		return _livingCount;
	}

	/** Init once at startup. */
	public static function initialize():Void
	{
		if (_initialized)
			return;
		_initialized = true;
		_lastFrameTimestamp = Timer.stamp() * 1000;
		peakMemoryUsage = currentMemoryUsage;
		_frameTimes.resize(FRAME_WINDOW);
		_memHistory = [];
	}

	/**
	 * Per-frame (Main ENTER_FRAME): EMA + ring;
	 * memory + cache counts are throttled.
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

			if (frameTimeTrackingEnabled)
			{
				_frameTimes[_frameTimeCount % FRAME_WINDOW] = currentFrameTime;
				_frameTimeCount++;
			}
		}
		_lastFrameTimestamp = now;

		_frameCounter++;

		// low-freq memory sample (~every 120 frames)
		if (_frameCounter % MEM_SAMPLE_INTERVAL == 0)
		{
			var mem:Float = currentMemoryUsage;
			if (mem > peakMemoryUsage)
				peakMemoryUsage = mem;

			if (_memHistory.length < MEM_HISTORY_CAP)
			{
				_memHistory.push({
					t: Timer.stamp(),
					mem: mem,
					peak: peakMemoryUsage,
					cached: _cachedGraphicCountValue,
					living: _livingCount
				});
			}
		}

		// refresh cached-graphic count every 60 frames
		if (_frameCounter % 60 == 0)
		{
			var count:Int = 0;
			@:privateAccess
			for (key in FlxG.bitmap._cache.keys())
				count++;
			_cachedGraphicCountValue = count;
		}
	}

	/** One-line memory summary. */
	public static function getMemoryReport():String
	{
		var memMB:Int = Std.int(currentMemoryUsage / 1024 / 1024);
		var peakMB:Int = Std.int(peakMemoryUsage / 1024 / 1024);
		return 'Memory: ${memMB}MB / ${peakMB}MB peak | '
			+ 'Graphics cached: ${cachedGraphicCount} | living tracked: ${livingGraphicCount}';
	}

	/** Frame-time percentiles (sort on demand). */
	public static function getFrameStats():FrameStats
	{
		var n:Int = Std.int(Math.min(_frameTimeCount, FRAME_WINDOW));
		if (n == 0)
			return {frames: 0, avg: 0, p50: 0, p95: 0, p99: 0, max: 0};

		var sorted:Array<Float> = [];
		var sum:Float = 0;
		var max:Float = 0;
		for (i in 0...n)
		{
			var v:Float = _frameTimes[i];
			sorted.push(v);
			sum += v;
			if (v > max) max = v;
		}
		sorted.sort(Reflect.compare);

		return {
			frames: n,
			avg: sum / n,
			p50: percentile(sorted, 0.50),
			p95: percentile(sorted, 0.95),
			p99: percentile(sorted, 0.99),
			max: max
		};
	}

	static inline function percentile(sorted:Array<Float>, q:Float):Float
	{
		var idx:Int = Std.int(sorted.length * q);
		if (idx >= sorted.length) idx = sorted.length - 1;
		if (idx < 0) idx = 0;
		return sorted[idx];
	}

	/**
	 * Export memory history + frame stats to CSV (sys only, on demand).
	 * Returns the path or null.
	 */
	public static function exportStats(?path:String):String
	{
		#if sys
		if (path == null)
		{
			var dir:String = 'perf';
			if (!sys.FileSystem.exists(dir))
				sys.FileSystem.createDirectory(dir);
			path = dir + '/memorymonitor_' + Std.string(Math.floor(Timer.stamp())) + '.csv';
		}

		var fstats:FrameStats = getFrameStats();
		var lines:Array<String> = [];
		lines.push('t,memBytes,peakBytes,cachedGraphics,livingTracked');
		for (s in _memHistory)
			lines.push('${s.t},${s.mem},${s.peak},${s.cached},${s.living}');
		lines.push('');
		lines.push('# frames=${fstats.frames} avgMs=${fstats.avg} p50Ms=${fstats.p50} p95Ms=${fstats.p95} p99Ms=${fstats.p99} maxMs=${fstats.max}');
		lines.push('# disposedBitmaps=${disposedBitmapCount}');

		try {
			sys.io.File.saveContent(path, lines.join('\n'));
			return path;
		} catch (e:Dynamic) {
			return null;
		}
		#else
		return null;
		#end
	}

	/** Track a graphic. */
	public static function trackGraphic(key:String, graphic:FlxGraphic):Void
	{
		if (graphic == null)
			return;
		if (!_trackedGraphics.exists(key))
			_livingCount++;
		_trackedGraphics.set(key, graphic);
	}

	/** Untrack; bumps the destroy counter. */
	public static function untrackGraphic(key:String):Void
	{
		if (!_trackedGraphics.exists(key))
			return;
		_trackedGraphics.remove(key);
		_livingCount--;
		disposedBitmapCount++;
	}

	/**
	 * Diagnostic: cache keys we are not tracking (O(n), not hot path).
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
}

/** One memory sample. */
typedef MemSample = {
	t:Float,
	mem:Float,
	peak:Float,
	cached:Int,
	living:Int
}

/** Frame-time stats result. */
typedef FrameStats = {
	frames:Int,
	avg:Float,
	p50:Float,
	p95:Float,
	p99:Float,
	max:Float
}
