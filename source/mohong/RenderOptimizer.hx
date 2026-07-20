package mohong;

import flixel.FlxG;
import flixel.FlxBasic;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.FlxSprite;

/**
 * Render optimization utilities for reducing draw calls and GPU state changes.
 * 
 * Features:
 * - Draw call counting for diagnostics
 * - Batch-friendly rendering hints
 * - Culling optimization helpers
 * - Frame timing analysis for render budget
 * 
 * Design: All settings are soft-coded as static configurable properties.
 */
class RenderOptimizer
{
	// ═══════════════════════════════════════
	//  Configurable settings (soft-coded)
	// ═══════════════════════════════════════

	/** Whether render optimization is enabled. */
	public static var optimizationEnabled:Bool = true;

	/** Whether to log draw call statistics. */
	public static var trackDrawCalls:Bool = false;

	/** Whether to enable automatic off-screen culling hints. */
	public static var autoCulling:Bool = true;

	/** Maximum number of visible sprites before batching warning. */
	public static var maxVisibleSpritesWarning:Int = 500;

	/** Whether to enable atlas texture batching (reduces state changes). */
	public static var enableAtlasBatching:Bool = true;

	/** Render quality level: 0=low, 1=medium, 2=high. */
	public static var renderQualityLevel:Int = 2;

	/** Whether to skip rendering invisible cameras entirely. */
	public static var skipInvisibleCameras:Bool = true;

	// ═══════════════════════════════════════
	//  Runtime state
	// ═══════════════════════════════════════

	/** Estimated draw calls for the current frame. */
	public static var estimatedDrawCalls:Int = 0;

	/** Count of sprites rendered this frame. */
	public static var spritesRenderedThisFrame:Int = 0;

	/** Timestamp of the current frame start for budget tracking. */
	static var _frameStartTime:Float = 0;

	/** Whether a render budget warning has been issued this frame. */
	static var _budgetWarningIssued:Bool = false;

	// ═══════════════════════════════════════
	//  Per-frame API
	// ═══════════════════════════════════════

	/**
	 * Call at the start of each render frame to reset counters.
	 */
	public static function onRenderStart():Void
	{
		estimatedDrawCalls = 0;
		spritesRenderedThisFrame = 0;
		_budgetWarningIssued = false;
		_frameStartTime = haxe.Timer.stamp() * 1000;
	}

	/**
	 * Call at the end of each render frame for diagnostics.
	 */
	public static function onRenderEnd():Void
	{
		if (!trackDrawCalls)
			return;

		var elapsed:Float = haxe.Timer.stamp() * 1000 - _frameStartTime;
		if (elapsed > MemoryMonitor.frameTimeWarningThreshold && !_budgetWarningIssued)
		{
			_budgetWarningIssued = true;
			TraceManager.debug('renderOptimizer.frameBudget',
				'Render frame took {elapsed}ms with ~{drawCalls} draw calls, {sprites} sprites',
				[Std.int(elapsed), estimatedDrawCalls, spritesRenderedThisFrame]);
		}
	}

	/**
	 * Increment the draw call counter. Call before each non-batched draw.
	 */
	public static inline function incrementDrawCall():Void
	{
		estimatedDrawCalls++;
	}

	/**
	 * Increment the sprite render counter.
	 */
	public static inline function incrementSpriteCount():Void
	{
		spritesRenderedThisFrame++;
	}

	// ═══════════════════════════════════════
	//  Camera optimization
	// ═══════════════════════════════════════

	/**
	 * Check if a camera should be rendered this frame.
	 * Skips invisible cameras and those with alpha=0.
	 */
	public static function shouldRenderCamera(camera:flixel.FlxCamera):Bool
	{
		if (!skipInvisibleCameras)
			return true;
		return camera != null && camera.visible && camera.alpha > 0;
	}

	// ═══════════════════════════════════════
	//  Sprite optimization helpers
	// ═══════════════════════════════════════

	/**
	 * Check if a sprite is likely visible on screen.
	 * Simple AABB check against the provided camera bounds.
	 */
	public static function isSpriteOnScreen(sprite:FlxSprite, camera:flixel.FlxCamera):Bool
	{
		if (sprite == null || !sprite.exists || !sprite.visible || sprite.alpha <= 0)
			return false;

		if (!autoCulling)
			return true;

		// Use camera viewport rect; FlxCamera does not expose a public 'bounds' getter.
		var camLeft:Float = camera.scroll.x;
		var camTop:Float = camera.scroll.y;
		var camRight:Float = camLeft + camera.width;
		var camBottom:Float = camTop + camera.height;

		var spriteBounds = sprite.getScreenBounds(null, camera);

		// Manual AABB overlap test (FlxRect.intersects is not a method on this Flixel version)
		return (spriteBounds.x < camRight && spriteBounds.right > camLeft
			&& spriteBounds.y < camBottom && spriteBounds.bottom > camTop);
	}

	// ═══════════════════════════════════════
	//  Quality level helpers
	// ═══════════════════════════════════════

	/**
	 * Get recommended antialiasing setting based on quality level.
	 */
	public static function shouldUseAntialiasing():Bool
	{
		return renderQualityLevel >= 1;
	}

	/**
	 * Get recommended particle count multiplier based on quality level.
	 */
	public static function getParticleMultiplier():Float
	{
		return switch (renderQualityLevel)
		{
			case 0: 0.5;  // Low quality — half particles
			case 1: 0.75; // Medium quality
			case 2: 1.0;  // High quality — full particles
			default: 1.0;
		}
	}

	// ═══════════════════════════════════════
	//  Batching hints
	// ═══════════════════════════════════════

	/**
	 * Sort a group of sprites by texture atlas to reduce GPU state changes.
	 * Sprites sharing the same atlas render without texture swaps.
	 * 
	 * @param group The sprite group to sort.
	 */
	public static function sortByTexture(group:FlxTypedGroup<FlxSprite>):Void
	{
		if (!enableAtlasBatching || group == null)
			return;

		// FlxTypedGroup.sort signature: (order:Int, a:T, b:T) -> Int
		group.sort(function(_:Int, a:FlxSprite, b:FlxSprite):Int
		{
			if (a.graphic == null || b.graphic == null)
				return 0;
			var keyA:String = a.graphic.key;
			var keyB:String = b.graphic.key;
			if (keyA == keyB)
				return 0;
			return (keyA < keyB) ? -1 : 1;
		});
	}

	// ═══════════════════════════════════════
	//  Diagnostics
	// ═══════════════════════════════════════

	/**
	 * Get a render statistics summary.
	 */
	public static function getRenderStats():String
	{
		return 'DrawCalls: ~${estimatedDrawCalls} | Sprites: ${spritesRenderedThisFrame}';
	}
}
