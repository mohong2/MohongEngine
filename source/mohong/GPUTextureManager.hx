package mohong;

import flixel.graphics.FlxGraphic;
import openfl.display.BitmapData;

/**
 * Texture memory bookkeeping. Paths.cacheBitmap / purgeGraphicFromCaches
 * drive track/untrack. Never disposes anything itself.
 */
class GPUTextureManager
{
	/** On/off (ClientPrefs.texturePooling). */
	public static var managementEnabled:Bool = true;

	/** Log track/untrack events. */
	public static var logTextureEvents:Bool = false;

	/** Estimated bytes used. */
	public static var estimatedVRAMUsage(get, never):Float;

	/** Peak estimate. */
	public static var peakVRAMUsage:Float = 0;

	/** Bytes per pixel (RGBA). */
	static final BYTES_PER_PIXEL:Float = 4.0;

	/** key -> bytes. */
	static var _trackedMemory:Map<String, Float> = new Map<String, Float>();

	static var _vramEstimate:Float = 0;
	static var _texturesCreated:Int = 0;
	static var _texturesDisposed:Int = 0;

	static function get_estimatedVRAMUsage():Float
	{
		return _vramEstimate;
	}

	/**
	 * Track a graphic (called by Paths.cacheBitmap).
	 * Re-registering a key nets out the old value.
	 */
	public static function trackGraphic(key:String, graphic:FlxGraphic):Void
	{
		if (!managementEnabled || key == null || graphic == null)
			return;

		var bitmap:BitmapData = graphic.bitmap;
		var memory:Float = (bitmap != null) ? bitmap.width * bitmap.height * BYTES_PER_PIXEL : 0;

		if (_trackedMemory.exists(key))
		{
			_vramEstimate -= _trackedMemory.get(key);
			_trackedMemory.remove(key);
		}

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

	/**
	 * Untrack (called by Paths.purgeGraphicFromCaches).
	 */
	public static function untrackGraphic(key:String):Void
	{
		if (key == null || !_trackedMemory.exists(key))
			return;

		_vramEstimate -= _trackedMemory.get(key);
		_trackedMemory.remove(key);
		if (_vramEstimate < 0)
			_vramEstimate = 0;
		_texturesDisposed++;
	}

	/** One-line summary. */
	public static function getDiagnostics():String
	{
		return 'GPU Textures: ${_trackedMemory.keys().hasNext() ? "tracked" : "none"} | '
			+ '${_texturesCreated} created, ${_texturesDisposed} disposed | '
			+ 'VRAM: ~${Std.int(_vramEstimate / 1024 / 1024)}MB / ${Std.int(peakVRAMUsage / 1024 / 1024)}MB peak';
	}

	/** Reset counters, no disposal. */
	public static function resetTracking():Void
	{
		_trackedMemory = new Map<String, Float>();
		_texturesCreated = 0;
		_texturesDisposed = 0;
		_vramEstimate = 0;
		peakVRAMUsage = 0;
	}
}
