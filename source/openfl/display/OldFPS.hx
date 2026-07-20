package openfl.display;

import flixel.math.FlxMath;
import openfl.events.Event;
import openfl.system.System;
import openfl.text.TextField;
import openfl.text.TextFormat;
#if gl_stats
import openfl.display._internal.stats.Context3DStats;
import openfl.display._internal.stats.DrawCallContext;
#end
#if flash
import openfl.Lib;
#end

/**
	OldFPS — 移植自 PsychEngine 0.6.3 原版简约 FPS 样式。
	基于 TextField，所有属性均可直接修改，供 hscript 随时读写。
**/
#if !openfl_debug
@:fileXml('tags="haxe,release"')
@:noDebug
#end
class OldFPS extends TextField
{
	/** 当前帧率 (FPS) — 可在 hscript 中直接读取 **/
	public var currentFPS(default, null):Int;

	/** 是否显示内存占用 **/
	public var showMemory:Bool = true;
	/** 是否显示 DrawCalls **/
	public var showDrawCalls:Bool = true;
	/** 内存警告阈值 (MB)，超过时变色 **/
	public var warningMemory:Float = 3000;
	/** 正常文字颜色 **/
	public var colorNormal:Int = 0xFFFFFFFF;
	/** 警告文字颜色 **/
	public var colorWarning:Int = 0xFFFF0000;
	/** 字体大小 **/
	public var fontSize:Int = 14;
	/** 字体名称 **/
	public var fontName:String = "_sans";
	/** 显示位置 X **/
	public var displayX:Float;
	/** 显示位置 Y **/
	public var displayY:Float;

	/** 是否使用平滑帧率（与旧版一致） **/
	public var smoothFPS:Bool = true;
	/** 文字透明度 **/
	public var textAlpha:Float = 1.0;

	/** 强制显示的文字（不为 null 时替代正常 FPS 显示，供 hscript 操控） **/
	public var forceText:Null<String> = null;
	/** 强制文字颜色（不为 null 时替代正常颜色） **/
	public var forceColor:Null<Int> = null;

	@:noCompletion private var cacheCount:Int;
	@:noCompletion private var currentTime:Float;
	@:noCompletion private var times:Array<Float>;

	public function new(x:Float = 10, y:Float = 10, color:Int = 0xFFFFFF)
	{
		super();

		this.x = x;
		this.y = y;
		displayX = x;
		displayY = y;

		currentFPS = 0;
		selectable = false;
		mouseEnabled = false;
		defaultTextFormat = new TextFormat(fontName, fontSize, color);
		autoSize = LEFT;
		multiline = true;
		text = "FPS: ";

		cacheCount = 0;
		currentTime = 0;
		times = [];

		#if flash
		addEventListener(Event.ENTER_FRAME, function(e)
		{
			var time = Lib.getTimer();
			__enterFrame(time - currentTime);
		});
		#end
	}

	/** 强制刷新显示下一帧 **/
	public function forceRefresh():Void
	{
		cacheCount = -1;
	}

	/** 更新位置到 displayX/displayY **/
	public function syncPosition():Void
	{
		x = displayX;
		y = displayY;
	}

	@:noCompletion
	private #if !flash override #end function __enterFrame(deltaTime:Float):Void
	{
		currentTime += deltaTime;
		times.push(currentTime);

		while (times[0] < currentTime - 1000)
		{
			times.shift();
		}

		var currentCount = times.length;
		if (smoothFPS)
			currentFPS = Math.round((currentCount + cacheCount) / 2);
		else
			currentFPS = currentCount;

		if (currentFPS > ClientPrefs.data.framerate) currentFPS = ClientPrefs.data.framerate;

		if (currentCount != cacheCount)
		{
			// 如果 hscript 设了 forceText，显示强制文字而不是真实 FPS
			if (forceText != null)
			{
				text = forceText;
				textColor = (forceColor != null) ? forceColor : colorNormal;
			}
			else
			{
				text = "FPS: " + currentFPS;

				#if openfl
				var memoryMegas:Float = Math.abs(FlxMath.roundDecimal(System.totalMemory / 1000000, 1));
				if (showMemory)
				{
					text += "\nMemory: " + memoryMegas + " MB";
				}
				#end

				textColor = (forceColor != null) ? forceColor : colorNormal;
				#if openfl
				if (forceColor == null && (memoryMegas > warningMemory || currentFPS <= ClientPrefs.data.framerate / 2))
				{
					textColor = colorWarning;
				}
				#end

				#if (gl_stats && !disable_cffi && (!html5 || !canvas))
				if (showDrawCalls)
				{
					text += "\ntotalDC: " + Context3DStats.totalDrawCalls();
					text += "\nstageDC: " + Context3DStats.contextDrawCalls(DrawCallContext.STAGE);
					text += "\nstage3DDC: " + Context3DStats.contextDrawCalls(DrawCallContext.STAGE3D);
				}
				#end

				text += "\n";
			}
		}

		cacheCount = currentCount;
	}
}
