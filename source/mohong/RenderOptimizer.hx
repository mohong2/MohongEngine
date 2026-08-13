package mohong;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;

/**
 * Render observer. Hooks FlxG.signals.preDraw/postDraw and samples
 * visible sprites + render time. Observation only - no rendering changes.
 */
class RenderOptimizer
{
	/** On/off (ClientPrefs.memoryOptimization). */
	public static var optimizationEnabled:Bool = true;

	/**
	 * Quality 0=low 1=med 2=high (ClientPrefs.renderQualityLevel).
	 * Drives sampling rate and budget threshold.
	 * Visual quality stays with lowQuality/globalAntialiasing.
	 */
	public static var renderQualityLevel:Int = 2;

	/** Last sampled visible sprite count. */
	public static var visibleSprites:Int = 0;

	/** Last render span ms (preDraw->postDraw). */
	public static var lastRenderTime:Float = 0;

	// ring buffer of render times (1024 slots)
	static final RENDER_WINDOW:Int = 1024;
	static var _renderTimes:Array<Float> = [for (_ in 0...RENDER_WINDOW) 0.0];
	static var _renderCount:Int = 0;

	static var _renderStart:Float = 0;
	static var _frameCounter:Int = 0;
	static var _lastWarningAt:Float = 0;

	/** Sampling interval in frames; lower quality = sparser. */
	static function get_sampleInterval():Int
	{
		return switch (renderQualityLevel) {
			case 0: 120;
			case 1: 60;
			default: 30;
		}
	}

	/** Budget warning threshold, ms. */
	static function get_budgetThreshold():Float
	{
		return switch (renderQualityLevel) {
			case 0: 50.0;
			case 1: 40.0;
			default: 33.0;
		}
	}

	/** preDraw hook. */
	public static function onRenderStart():Void
	{
		if (!optimizationEnabled)
			return;
		_renderStart = haxe.Timer.stamp() * 1000;
	}

	/** postDraw hook. */
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

		// warn when over budget, at most once per second
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
	 * Count visible sprites in the current state.
	 * Sampled only, no substates.
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
	 * Render-time percentiles (sort on demand).
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

	/** One-line summary. */
	public static function getRenderStats():String
	{
		var s:RenderStats = getStats();
		return 'Render: ${Math.round(s.avgMs)}ms avg (p95 ${Math.round(s.p95Ms)}ms, max ${Math.round(s.maxMs)}ms) | '
			+ 'Visible sprites: ${s.visibleSprites}';
	}
}

/** Render stats result. */
typedef RenderStats = {
	samples:Int,
	avgMs:Float,
	p50Ms:Float,
	p95Ms:Float,
	maxMs:Float,
	visibleSprites:Int
}
