package mohong;

import flixel.graphics.FlxGraphic;
import openfl.display.BitmapData;

/**
 * Texture / bitmap memory manager (rewritten).
 *
 * The previous version uploaded every bitmap to a Stage3D RectangleTexture and
 * wrapped it back with BitmapData.fromTexture(), which broke image rendering
 * with the standard OpenFL/Flixel renderer (blank images until the asset was
 * loaded a few times). This engine does not use Stage3D rendering, so that
 * path was both useless and harmful.
 *
 * This rewrite is a lightweight, safe bookkeeper: it estimates the memory used
 * by FlxGraphic bitmaps and exposes diagnostics. It never disposes textures on
 * its own — all disposal is left to Flixel's own refcounted FlxGraphic cache,
 * which only frees bitmaps that no sprite references anymore.
 */
class GPUTextureManager
{
	// ═══════════════════════════════════════
	//  Configurable settings (soft-coded)
	// ═══════════════════════════════════════

	/** Whether texture memory management is enabled. */
	public static var managementEnabled:Bool = true;

	/** Maximum number of pooled textures per size category (kept for compat). */
	public static var maxPooledTexturesPerSize:Int = 8;

	/** Whether to log texture allocation/deallocation events. */
	public static var logTextureEvents:Bool = false;

	/** Estimated memory usage in bytes (tracked). */
	public static var estimatedVRAMUsage(get, never):Float;

	/** Peak memory usage observed. */
	public static var peakVRAMUsage:Float = 0;

	// ═══════════════════════════════════════
	//  Internal state
	// ═══════════════════════════════════════

	/** Tracked bitmap memory per asset key. */
	static var _trackedMemory:Map<String, Float> = new Map<String, Float>();

	/** Count of tracked allocations. */
	static var _texturesCreated:Int = 0;

	/** Count of tracked disposals. */
	static var _texturesDisposed:Int = 0;

	/** Cached estimate of bytes per pixel (RGBA = 4 bytes). */
	static final BYTES_PER_PIXEL:Float = 4.0;

	/** Current VRAM/bitmap estimate. */
	static var _vramEstimate:Float = 0;

	// ═══════════════════════════════════════
	//  Property accessors
	// ═══════════════════════════════════════

	static function get_estimatedVRAMUsage():Float
	{
		return _vramEstimate;
	}

	// ═══════════════════════════════════════
	//  Public API
	// ═══════════════════════════════════════

	/** Register a FlxGraphic's bitmap memory for tracking. */
	public static function trackGraphic(key:String, graphic:FlxGraphic):Void
	{
		if (!managementEnabled || key == null || graphic == null)
			return;
		if (_trackedMemory.exists(key))
			untrackGraphic(key);

		var bitmap:BitmapData = graphic.bitmap;
		var memory:Float = (bitmap != null) ? bitmap.width * bitmap.height * BYTES_PER_PIXEL : 0;
		_trackedMemory.set(key, memory);
		_vramEstimate += memory;
		_texturesCreated++;

		if (_vramEstimate > peakVRAMUsage)
			peakVRAMUsage = _vramEstimate;

		if (logTextureEvents)
		{
			TraceManager.debug('gpuTextureManager.alloc',
				'Texture tracked: {key} ({mem}KB) | Total: {vram}MB',
				[key, Std.int(memory / 1024), Std.int(_vramEstimate / 1024 / 1024)]);
		}
	}

	/** Unregister an asset key. */
	public static function untrackGraphic(key:String):Void
	{
		if (!_trackedMemory.exists(key))
			return;
		var memory:Float = _trackedMemory.get(key);
		_trackedMemory.remove(key);
		_vramEstimate -= memory;
		if (_vramEstimate < 0)
			_vramEstimate = 0;
		_texturesDisposed++;
	}

	// ── Backwards-compatible aliases (old Stage3D API) ──

	/** Compat alias: register allocation. Kept for old callers. */
	public static function trackTextureAllocation(texture:Dynamic, width:Int, height:Int):Void
	{
		if (!managementEnabled || texture == null) return;
		var memory:Float = width * height * BYTES_PER_PIXEL;
		_vramEstimate += memory;
		_texturesCreated++;
		if (_vramEstimate > peakVRAMUsage)
			peakVRAMUsage = _vramEstimate;
	}

	/** Compat alias: register disposal. Kept for old callers. */
	public static function trackTextureDisposal(texture:Dynamic, width:Int = 0, height:Int = 0):Void
	{
		if (texture == null) return;
		_vramEstimate -= width * height * BYTES_PER_PIXEL;
		if (_vramEstimate < 0)
			_vramEstimate = 0;
		_texturesDisposed++;
	}

	/** Safe no-op: disposal is handled by Flixel's refcounted graphic cache. */
	public static function safeDisposeTexture(texture:Dynamic, width:Int = 0, height:Int = 0):Void
	{
		// Intentionally a no-op — see class docs.
	}

	/** Safe no-op: never force-dispose tracked resources. */
	public static function disposeAllTrackedTextures():Void
	{
		// Intentionally a no-op — see class docs.
	}

	/** Check for stale tracking entries (null/key mismatches). */
	public static function detectOrphanedTextures():Int
	{
		var orphanCount:Int = 0;
		for (key in _trackedMemory.keys())
		{
			if (key == null)
				orphanCount++;
		}
		for (key in _trackedMemory.keys())
		{
			if (key == null)
				_trackedMemory.remove(key);
		}
		return orphanCount;
	}

	/** Get a diagnostic summary of texture memory state. */
	public static function getDiagnostics():String
	{
		return 'GPU Textures: ${_trackedMemory.keys().hasNext() ? "tracked" : "none"} | '
			+ '${_texturesCreated} created, ${_texturesDisposed} disposed | '
			+ 'VRAM: ~${Std.int(_vramEstimate / 1024 / 1024)}MB / ${Std.int(peakVRAMUsage / 1024 / 1024)}MB peak';
	}

	/** Reset all tracking counters. Does not dispose any resources. */
	public static function resetTracking():Void
	{
		_trackedMemory = new Map<String, Float>();
		_texturesCreated = 0;
		_texturesDisposed = 0;
		_vramEstimate = 0;
		peakVRAMUsage = 0;
	}
}
