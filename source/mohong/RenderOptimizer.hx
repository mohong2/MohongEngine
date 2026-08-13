package mohong;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;

/**
 * 渲染路径观测器（mohong 重写版）。
 *
 * 解决什么问题：
 *   旧实现宣称 draw call 统计/atlas 批处理/自动剔除，但计数器没有任何调用点
 *   （PlayState 只 import 未使用，ClientPrefs 只设开关）——纯"配置开关+零调用点"
 *   的假优化。重写为诚实的渲染观测：真实渲染段耗时、可见精灵采样、帧预算告警。
 *
 * 挂在哪个真实调用点：
 *   - Main.setupGame 用 FlxG.signals.preDraw/postDraw 接入 Flixel 渲染循环
 *     （FlxGame.draw 在渲染前后派发这两个信号，flixel 公共 API，不改任何库文件）；
 *   - ClientPrefs.loadDefaultKeys 继续接线 optimizationEnabled / renderQualityLevel，
 *     且 renderQualityLevel 现在有真实效果：采样频率与帧预算阈值。
 *
 * 怎么验证它真的在工作：
 *   - perf 模式 CSV 里可见精灵数随场景变化（标题画面 vs 打歌中）；
 *   - getStats() 的渲染耗时 p50/p95 有数据；
 *   - 渲染超预算时 TraceConsole 出现 throttled 告警日志。
 *
 * 明确不做：Stage3D 贴图、跨线程渲染、关 GC——都不是本类的职责。
 */
class RenderOptimizer
{
	/** 是否启用观测（ClientPrefs.memoryOptimization 接线）。 */
	public static var optimizationEnabled:Bool = true;

	/**
	 * 渲染质量 0=low 1=medium 2=high（ClientPrefs.renderQualityLevel 接线）。
	 * 真实效果：可见精灵采样频率与帧预算告警阈值（观测强度）。
	 * 视觉质量由引擎既有的 lowQuality/globalAntialiasing 设置负责，本类不碰。
	 */
	public static var renderQualityLevel:Int = 2;

	/** 最近一次采样的可见精灵数（每 sampleInterval 帧刷新）。 */
	public static var visibleSprites:Int = 0;

	/** 上一帧渲染段耗时（ms，preDraw → postDraw）。 */
	public static var lastRenderTime:Float = 0;

	// ── 渲染耗时环形缓冲（固定 1024 槽） ──
	static final RENDER_WINDOW:Int = 1024;
	static var _renderTimes:Array<Float> = [for (_ in 0...RENDER_WINDOW) 0.0];
	static var _renderCount:Int = 0;

	static var _renderStart:Float = 0;
	static var _frameCounter:Int = 0;
	static var _lastWarningAt:Float = 0;

	/** 采样间隔（帧）：质量越低采样越稀（低端机少付遍历开销）。 */
	static function get_sampleInterval():Int
	{
		return switch (renderQualityLevel) {
			case 0: 120;
			case 1: 60;
			default: 30;
		}
	}

	/** 帧预算告警阈值（ms）。 */
	static function get_budgetThreshold():Float
	{
		return switch (renderQualityLevel) {
			case 0: 50.0;
			case 1: 40.0;
			default: 33.0;
		}
	}

	/** 渲染前钩子（FlxG.signals.preDraw）。 */
	public static function onRenderStart():Void
	{
		if (!optimizationEnabled)
			return;
		_renderStart = haxe.Timer.stamp() * 1000;
	}

	/** 渲染后钩子（FlxG.signals.postDraw）。 */
	public static function onRenderEnd():Void
	{
		if (!optimizationEnabled || _renderStart <= 0)
			return;

		lastRenderTime = haxe.Timer.stamp() * 1000 - _renderStart;
		_renderTimes[_renderCount % RENDER_WINDOW] = lastRenderTime;
		_renderCount++;

		_frameCounter++;
		if (_frameCounter % get_sampleInterval() != 0)
			return;

		visibleSprites = countVisibleSprites();

		// 帧预算告警：渲染段超阈值时输出，每秒最多一条
		var now:Float = haxe.Timer.stamp();
		if (lastRenderTime > get_budgetThreshold() && now - _lastWarningAt > 1.0)
		{
			_lastWarningAt = now;
			TraceManager.debug('renderOptimizer.frameBudget',
				'Render took {ms}ms with {sprites} visible sprites',
				[Math.round(lastRenderTime), visibleSprites]);
		}
	}

	/**
	 * 遍历当前状态的 members，统计可见精灵数。
	 * 只在采样帧调用（每 30/60/120 帧一次），不计子状态（文档化）。
	 */
	static function countVisibleSprites():Int
	{
		var state:FlxState = FlxG.state;
		if (state == null)
			return 0;

		var count:Int = 0;
		for (member in state.members)
		{
			var spr:FlxSprite = (Std.isOfType(member, FlxSprite) ? cast member : null);
			if (spr == null)
				continue;
			if (spr.exists && spr.visible && spr.alpha > 0)
				count++;
		}
		return count;
	}

	/**
	 * 渲染耗时统计（对窗口内样本排序；仅显式调用时开销）。
	 */
	public static function getStats():RenderStats
	{
		var n:Int = Std.int(Math.min(_renderCount, RENDER_WINDOW));
		if (n == 0)
			return {samples: 0, avgMs: 0, p50Ms: 0, p95Ms: 0, maxMs: 0, visibleSprites: visibleSprites};

		var sorted:Array<Float> = [];
		var sum:Float = 0;
		var max:Float = 0;
		for (i in 0...n)
		{
			var v:Float = _renderTimes[i];
			sorted.push(v);
			sum += v;
			if (v > max) max = v;
		}
		sorted.sort(Reflect.compare);

		return {
			samples: n,
			avgMs: sum / n,
			p50Ms: sorted[Std.int(n * 0.50)],
			p95Ms: sorted[Std.int(n * 0.95)],
			maxMs: max,
			visibleSprites: visibleSprites
		};
	}

	/** 一行可读的观测摘要。 */
	public static function getRenderStats():String
	{
		var s:RenderStats = getStats();
		return 'Render: ${Math.round(s.avgMs)}ms avg (p95 ${Math.round(s.p95Ms)}ms, max ${Math.round(s.maxMs)}ms) | '
			+ 'Visible sprites: ${s.visibleSprites}';
	}
}

/** 渲染观测统计结果。 */
typedef RenderStats = {
	samples:Int,
	avgMs:Float,
	p50Ms:Float,
	p95Ms:Float,
	maxMs:Float,
	visibleSprites:Int
}
