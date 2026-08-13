package mohong;

import flixel.graphics.FlxGraphic;
import openfl.display.BitmapData;

/**
 * 贴图内存记账器（mohong 重写版）。
 *
 * 解决什么问题：
 *   旧实现保留了一堆 Stage3D 时代的"兼容别名"（trackTextureAllocation 等），
 *   全部零调用；真正的 trackGraphic 也从没被任何加载路径调用，
 *   estimatedVRAMUsage 恒为 0——又是一个假接口。重写为纯记账：
 *   按 FlxGraphic 位图尺寸估算显存占用，与 Paths 的加载/销毁生命周期真实联动。
 *
 * 挂在哪个真实调用点：
 *   - Paths.cacheBitmap：新 FlxGraphic 入缓存时调用 trackGraphic（真实加载点）；
 *   - Paths.purgeGraphicFromCaches：贴图被清理/销毁前调用 untrackGraphic
 *     （真实销毁点，与 FlxG.bitmap 的 useCount/zombie 守卫走同一条路径）。
 *
 * 怎么验证它真的在工作：
 *   - 加载一张大图后 estimatedVRAMUsage 增加对应字节数；
 *   - 切歌/清缓存后回落，且峰值峰值 peakVRAMUsage 保留；
 *   - getDiagnostics() 的计数与 MemoryMonitor.cachedGraphicCount 趋势一致。
 *
 * 明确不做：不 dispose 任何贴图（销毁全部交给 Flixel 引用计数与 Paths 的
 * zombie 守卫），不做 Stage3D 纹理上传（引擎不用 Stage3D）。
 */
class GPUTextureManager
{
	/** 是否启用记账（ClientPrefs.texturePooling 接线）。 */
	public static var managementEnabled:Bool = true;

	/** 是否输出纹理跟踪日志（诊断用）。 */
	public static var logTextureEvents:Bool = false;

	/** 当前估算的贴图内存占用（字节）。 */
	public static var estimatedVRAMUsage(get, never):Float;

	/** 观测到的估算峰值（字节）。 */
	public static var peakVRAMUsage:Float = 0;

	/** 每像素字节数（RGBA 位图）。 */
	static final BYTES_PER_PIXEL:Float = 4.0;

	/** key → 估算字节数。 */
	static var _trackedMemory:Map<String, Float> = new Map<String, Float>();

	static var _vramEstimate:Float = 0;
	static var _texturesCreated:Int = 0;
	static var _texturesDisposed:Int = 0;

	static function get_estimatedVRAMUsage():Float
	{
		return _vramEstimate;
	}

	/**
	 * 登记一张贴图的内存估算（加载时由 Paths.cacheBitmap 调用）。
	 * 同 key 重复登记会先冲销旧值。
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
	 * 冲销一张贴图的内存估算（销毁时由 Paths.purgeGraphicFromCaches 调用）。
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

	/** 诊断摘要（一行文本）。 */
	public static function getDiagnostics():String
	{
		return 'GPU Textures: ${_trackedMemory.keys().hasNext() ? "tracked" : "none"} | '
			+ '${_texturesCreated} created, ${_texturesDisposed} disposed | '
			+ 'VRAM: ~${Std.int(_vramEstimate / 1024 / 1024)}MB / ${Std.int(peakVRAMUsage / 1024 / 1024)}MB peak';
	}

	/** 重置全部记账（不销毁任何资源）。 */
	public static function resetTracking():Void
	{
		_trackedMemory = new Map<String, Float>();
		_texturesCreated = 0;
		_texturesDisposed = 0;
		_vramEstimate = 0;
		peakVRAMUsage = 0;
	}
}
