package backend;

/**
 * RenderThread - 多线程渲染管理器（已禁用）
 * 
 * 多线程渲染已移除，因为 OpenFL 的 OpenGL 渲染器不支持跨线程调用。
 * 所有方法保留为单线程回退存根，保持 API 兼容性。
 */
class RenderThread
{
	/** 是否启用多线程渲染（始终为 false） */
	public static var enabled:Bool = false;
	
	/** 线程模式名称 */
	public static var threadMode(get, never):String;
	
	static inline function get_threadMode():String
	{
		return "Single-Thread";
	}

	/** @return 始终返回 false */
	public static function start():Bool { return false; }
	
	/** 直接在当前线程执行绘制函数 */
	public static function submitRender(drawFn:Void->Void):Void { drawFn(); }
	
	/** @return 始终返回 false */
	public static function submitRenderAsync(drawFn:Void->Void):Bool { return false; }
	
	/** 空操作 */
	public static function stop():Void {}
	
	/** 空操作 */
	public static function flushTraces():Void {}
	
	/** @return 始终返回 "RenderThread: disabled" */
	public static function getStats():String { return "RenderThread: disabled"; }
	
	/** @return 始终返回 false */
	public static function isHealthy():Bool { return false; }
}
