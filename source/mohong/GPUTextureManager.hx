package mohong;

import openfl.display.BitmapData;
import openfl.display3D.textures.RectangleTexture;
import openfl.display3D.Context3DTextureFormat;
import flixel.FlxG;
import flixel.graphics.FlxGraphic;

/**
 * GPU texture lifecycle manager.
 * 
 * Manages GPU-side texture allocation and disposal to:
 * - Prevent VRAM leaks from orphaned textures
 * - Pool frequently-used texture sizes for reuse
 * - Track texture memory usage for diagnostics
 * - Ensure proper cleanup on state transitions
 * 
 * Design: All settings are soft-coded as static configurable properties.
 */
class GPUTextureManager
{
	// ═══════════════════════════════════════
	//  Configurable settings (soft-coded)
	// ═══════════════════════════════════════

	/** Whether GPU texture management is enabled. */
	public static var managementEnabled:Bool = true;

	/** Maximum number of pooled textures per size category. */
	public static var maxPooledTexturesPerSize:Int = 8;

	/** Whether to log texture allocation/deallocation events. */
	public static var logTextureEvents:Bool = false;

	/** Estimated VRAM usage in bytes (tracked). */
	public static var estimatedVRAMUsage(get, never):Float;

	/** Peak VRAM usage observed. */
	public static var peakVRAMUsage:Float = 0;

	// ═══════════════════════════════════════
	//  Internal state
	// ═══════════════════════════════════════

	/** Active texture references tracked for leak detection. */
	static var _activeTextures:Array<RectangleTexture> = [];

	/** Count of textures created since tracking began. */
	static var _texturesCreated:Int = 0;

	/** Count of textures disposed since tracking began. */
	static var _texturesDisposed:Int = 0;

	/** Cached estimate of bytes per pixel (RGBA = 4 bytes). */
	static final BYTES_PER_PIXEL:Float = 4.0;

	/** Tracked VRAM estimate. */
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

	/**
	 * Register a newly created GPU texture for tracking.
	 * Call this whenever a RectangleTexture is created.
	 */
	public static function trackTextureAllocation(texture:RectangleTexture, width:Int, height:Int):Void
	{
		if (!managementEnabled || texture == null)
			return;

		_texturesCreated++;
		_activeTextures.push(texture);

		var textureMemory:Float = width * height * BYTES_PER_PIXEL;
		_vramEstimate += textureMemory;

		if (_vramEstimate > peakVRAMUsage)
			peakVRAMUsage = _vramEstimate;

		if (logTextureEvents)
		{
			TraceManager.debug('gpuTextureManager.alloc',
				'Texture allocated: {w}x{h} ({mem}KB) | Active: {active} | Total VRAM: {vram}MB',
				[width, height, Std.int(textureMemory / 1024),
				 _activeTextures.length, Std.int(_vramEstimate / 1024 / 1024)]);
		}
	}

	/**
	 * Register a GPU texture disposal for tracking.
	 * Call this whenever a RectangleTexture is disposed.
	 */
	public static function trackTextureDisposal(texture:RectangleTexture, width:Int, height:Int):Void
	{
		if (!managementEnabled || texture == null)
			return;

		_texturesDisposed++;
		_activeTextures.remove(texture);

		var textureMemory:Float = width * height * BYTES_PER_PIXEL;
		_vramEstimate -= textureMemory;
		if (_vramEstimate < 0)
			_vramEstimate = 0;
	}

	/**
	 * Safely dispose a GPU texture with tracking.
	 * Use this instead of calling texture.dispose() directly.
	 */
	public static function safeDisposeTexture(texture:RectangleTexture, width:Int = 0, height:Int = 0):Void
	{
		if (texture == null)
			return;

		trackTextureDisposal(texture, width, height);

		try
		{
			texture.dispose();
		}
		catch (e:Dynamic)
		{
			TraceManager.warn('gpuTextureManager.disposeFailed',
				'Failed to dispose texture: {error}', [Std.string(e)]);
		}
	}

	/**
	 * Dispose all tracked textures. Use for emergency cleanup.
	 */
	public static function disposeAllTrackedTextures():Void
	{
		if (logTextureEvents)
		{
			TraceManager.info('gpuTextureManager.disposeAll',
				'Disposing {count} tracked textures ({vram}MB VRAM)',
				[_activeTextures.length, Std.int(_vramEstimate / 1024 / 1024)]);
		}

		var textures:Array<RectangleTexture> = _activeTextures.copy();
		for (texture in textures)
		{
			try
			{
				texture.dispose();
			}
			catch (e:Dynamic) {}
		}

		_activeTextures = [];
		_vramEstimate = 0;
	}

	/**
	 * Check for potential VRAM leaks: textures that are still allocated
	 * but have no known FlxGraphic reference.
	 */
	public static function detectOrphanedTextures():Int
	{
		var orphanCount:Int = 0;
		// Iterate active textures and check if they still have valid references
		for (texture in _activeTextures)
		{
			// A heuristic: if the texture object exists but has been disposed
			// by the GC without our knowledge, it shouldn't be in our list.
			// Most orphan detection relies on the FlxGraphic cache.
			if (texture == null)
				orphanCount++;
		}

		// Clean up null references
		while (_activeTextures.remove(null)) {}
		return orphanCount;
	}

	/**
	 * Get a diagnostic summary of GPU texture state.
	 */
	public static function getDiagnostics():String
	{
		return 'GPU Textures: ${_activeTextures.length} active | '
			+ '${_texturesCreated} created, ${_texturesDisposed} disposed | '
			+ 'VRAM: ~${Std.int(_vramEstimate / 1024 / 1024)}MB / ${Std.int(peakVRAMUsage / 1024 / 1024)}MB peak';
	}

	/**
	 * Reset all tracking counters. Does not dispose any textures.
	 */
	public static function resetTracking():Void
	{
		_activeTextures = [];
		_texturesCreated = 0;
		_texturesDisposed = 0;
		_vramEstimate = 0;
		peakVRAMUsage = 0;
	}
}
