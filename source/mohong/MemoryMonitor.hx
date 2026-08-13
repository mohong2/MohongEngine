package mohong;

import flixel.graphics.FlxGraphic;
import flixel.FlxG;
import haxe.Timer;
#if cpp
import openfl.system.System;
import cpp.vm.Gc;
#end

/**
 * 内存与帧时间监控（mohong 重写版）。
 *
 * 解决什么问题：
 *   为"先测量后动手"提供测量基建：帧时间分位数、按平台分支的内存读数、
 *   贴图生命周期追踪、可导出的内存曲线。旧实现非 cpp 平台内存恒为 0，
 *   disposedBitmapCount 声明了却从不递增，且没有分位数统计。
 *
 * 挂在哪个真实调用点：
 *   - Main.hx ENTER_FRAME 每帧调用 onFrameStart()（已存在）；
 *   - Paths.hx cacheBitmap 调用 trackGraphic、purgeGraphicFromCaches 调用
 *     untrackGraphic（已存在），本类计数与贴图生命周期真实联动。
 *
 * 怎么验证它真的在工作：
 *   - Windows 实机：perf 测试模式导出的 CSV 里帧时间/内存/缓存数逐行变化；
 *   - 切歌 20 次后 cachedGraphicCount 回落到稳定值、disposedBitmapCount 持续增长；
 *   - HTML5（Chrome）：currentMemoryUsage 返回真实 JS heap 而非 0。
 *
 * 注意：本类只做"监控"，不做任何回收动作——回收交给运行时默认行为。
 */
class MemoryMonitor
{
	/** 是否启用监控（ClientPrefs.memoryOptimization 接线）。 */
	public static var monitoringEnabled:Bool = true;

	/** 帧时间告警阈值（ms，约 30 FPS）。 */
	public static var frameTimeWarningThreshold:Float = 33.0;

	/** 帧时间严重告警阈值（ms，约 20 FPS）。 */
	public static var frameTimeCriticalThreshold:Float = 50.0;

	/** 是否记录帧时间环形缓冲（分位数统计需要；默认关以省内存）。 */
	public static var frameTimeTrackingEnabled:Bool = false;

	/** 当前内存占用（字节）。平台分支见实现。 */
	public static var currentMemoryUsage(get, never):Float;

	/** 自启动以来观测到的内存峰值（字节）。 */
	public static var peakMemoryUsage:Float = 0;

	static var _lastFrameTimestamp:Float = 0;

	/** 当前帧耗时（ms）。 */
	public static var currentFrameTime:Float = 0;

	/** 帧时间指数滑动平均（ms）。 */
	public static var averageFrameTime:Float = 0;

	/** 帧时间 EMA 平滑系数（0-1，越大越灵敏）。 */
	public static var frameTimeSmoothingFactor:Float = 0.1;

	/** FlxG.bitmap 缓存中的图条目数（每 60 帧刷新一次的缓存值）。 */
	public static var cachedGraphicCount(get, never):Int;

	/** 累计被销毁/取消追踪的贴图数（untrackGraphic 时递增）。 */
	public static var disposedBitmapCount:Int = 0;

	/** 受追踪的 FlxGraphic（key → graphic），用于泄漏检测。 */
	static var _trackedGraphics:Map<String, FlxGraphic> = new Map<String, FlxGraphic>();

	/** 当前存活的受追踪贴图数（track/untrack 时直接维护，读取 O(1)）。 */
	static var _livingCount:Int = 0;

	public static var livingGraphicCount(get, never):Int;

	static var _initialized:Bool = false;
	static var _frameCounter:Int = 0;
	static var _cachedGraphicCountValue:Int = 0;

	// ── 帧时间环形缓冲（固定大小，约 68 秒 @60fps） ──
	static final FRAME_WINDOW:Int = 4096;
	static var _frameTimes:Array<Float> = [];
	static var _frameTimeCount:Int = 0;

	// ── 内存采样历史（每 MEM_SAMPLE_INTERVAL 帧一条，供导出曲线） ──
	static final MEM_SAMPLE_INTERVAL:Int = 120;
	static final MEM_HISTORY_CAP:Int = 10000;
	static var _memHistory:Array<MemSample> = [];

	#if cpp
	/** hxcpp GC 堆当前值（含未回收垃圾；锯齿曲线可观测 GC 活动，仅 cpp）。 */
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
		// 浏览器托管 GC：Chrome/Edge 提供 performance.memory（仅此二家）；
		// 其他浏览器返回 0，标注清楚，不依赖平台专属 API 实现核心逻辑。
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

	/** 初始化（应用启动时调用一次）。 */
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
	 * 每帧调用（Main ENTER_FRAME）：帧时间 EMA + 环形缓冲；
	 * 内存采样与缓存计数按帧节流，避免每帧 syscall/遍历。
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

		// 低频内存采样（每 ~120 帧一次）
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

		// 低频刷新缓存图计数（每 60 帧遍历一次 FlxG.bitmap._cache）
		if (_frameCounter % 60 == 0)
		{
			var count:Int = 0;
			@:privateAccess
			for (key in FlxG.bitmap._cache.keys())
				count++;
			_cachedGraphicCountValue = count;
		}
	}

	/** 当前内存状态摘要（一行文本）。 */
	public static function getMemoryReport():String
	{
		var memMB:Int = Std.int(currentMemoryUsage / 1024 / 1024);
		var peakMB:Int = Std.int(peakMemoryUsage / 1024 / 1024);
		return 'Memory: ${memMB}MB / ${peakMB}MB peak | '
			+ 'Graphics cached: ${cachedGraphicCount} | living tracked: ${livingGraphicCount}';
	}

	/** 帧时间分位数统计（对窗口内样本排序后计算；仅在显式调用时开销）。 */
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
	 * 导出内存历史 + 帧时间统计到 CSV（仅 sys 平台；显式调用才写文件，
	 * 平时零磁盘开销）。返回写出的完整路径，失败返回 null。
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

	/** 登记一个 FlxGraphic 的生命周期。 */
	public static function trackGraphic(key:String, graphic:FlxGraphic):Void
	{
		if (graphic == null)
			return;
		if (!_trackedGraphics.exists(key))
			_livingCount++;
		_trackedGraphics.set(key, graphic);
	}

	/** 取消登记；仅在确实移除了条目时递增销毁计数。 */
	public static function untrackGraphic(key:String):Void
	{
		if (!_trackedGraphics.exists(key))
			return;
		_trackedGraphics.remove(key);
		_livingCount--;
		disposedBitmapCount++;
	}

	/**
	 * 找出 FlxG.bitmap 缓存中未被追踪的键（诊断用，O(n)，别在热路径调）。
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

/** 一条内存采样记录。 */
typedef MemSample = {
	t:Float,
	mem:Float,
	peak:Float,
	cached:Int,
	living:Int
}

/** 帧时间统计结果。 */
typedef FrameStats = {
	frames:Int,
	avg:Float,
	p50:Float,
	p95:Float,
	p99:Float,
	max:Float
}
