package openfl.display;

import openfl.text.Font;
import haxe.Timer;
import openfl.events.Event;
import openfl.text.TextField;
import openfl.text.TextFormat;
import states.MainMenuState;
#if gl_stats
import openfl.display._internal.stats.Context3DStats;
import openfl.display._internal.stats.DrawCallContext;
#end
#if flash
import openfl.Lib;
#end

import openfl.system.System;

/**
	The FPS class provides an easy-to-use monitor to display
	the current frame rate of an OpenFL project
**/
#if !openfl_debug
@:fileXml('tags="haxe,release"')
@:noDebug
#end
class FPS extends TextField
{
	/**
		The current frame rate, expressed using frames-per-second
	**/
	public var currentFPS(default, null):Int;

	@:noCompletion private var cacheCount:Int;
	@:noCompletion private var currentTime:Float;
	@:noCompletion private var times:Array<Float>;
	@:noCompletion private var maxMemory:Float = 0;

	@:noCompletion private var dataFont:Font;

	public function new(x:Float = 10, y:Float = 10, color:Int = 0x000000)
	{
		super();

		this.x = x;
		this.y = y;

		dataFont = new Font("assets/fonts/vcrcn.ttf");
		
		currentFPS = 0;
		selectable = false;
		mouseEnabled = false;
		
		var labelFormat = new TextFormat("_sans", 14, color); 
		
		defaultTextFormat = labelFormat;
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

	// Event Handlers
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
		currentFPS = Math.round((currentCount + cacheCount) / 2);
		if (currentFPS > ClientPrefs.data.framerate) currentFPS = ClientPrefs.data.framerate;

		if (currentCount != cacheCount /*&& visible*/)
		{
			var memoryMegas:Float = 0;
			memoryMegas = Math.abs(FlxMath.roundDecimal(System.totalMemory / 1000000, 1));
			
			if (memoryMegas > maxMemory) {
				maxMemory = memoryMegas;
			}
			
			var currentMemoryText:String;
			var maxMemoryText:String;
			
			if (memoryMegas >= 1024) {
				currentMemoryText = FlxMath.roundDecimal(memoryMegas / 1024, 2) + " GB"; 
			} else {
				currentMemoryText = memoryMegas + " MB"; 
			}
			
			if (maxMemory >= 1024) {
				maxMemoryText = FlxMath.roundDecimal(maxMemory / 1024, 2) + " GB"; 
			} else {
				maxMemoryText = maxMemory + " MB"; 
			}

			// 修改这里：将内存显示格式改为 "xxx GB/MB / xxx MB/GB"
			var currentMemParts = currentMemoryText.split(" ");
			var maxMemParts = maxMemoryText.split(" ");
			
			htmlText = "<font face='" + dataFont.fontName + "' size='24'>" + currentFPS + "</font>" +
					   "<font face='_sans' size='14'> FPS</font><br/>" +
					   "<font face='" + dataFont.fontName + "' size='24'>" + currentMemParts[0] + "</font>" +
					   "<font face='_sans' size='14'> " + currentMemParts[1] + " / " + maxMemParts[0] + " " + maxMemParts[1] + "</font><br/>" +
					   "<font face='_sans' size='14' color='#A9A9A9'>MohongEngine v" + MainMenuState.mohongEngineVersion + "</font>";

			textColor = 0xFFFFFFFF;
			if (memoryMegas > 3000 || currentFPS <= ClientPrefs.data.framerate / 2)
			{
				textColor = 0xFFFF0000;
			}else if(memoryMegas > 2000 || currentFPS <= ClientPrefs.data.framerate / 1.5)
			{
				textColor = 0xFFFFA500;
			}
			#if (gl_stats && !disable_cffi && (!html5 || !canvas))
			htmlText += "<br/><font face='_sans' size='14'>totalDC: </font>" + 
						"<font face='" + dataFont.fontName + "' size='20'>" + Context3DStats.totalDrawCalls() + "</font>";
			htmlText += "<br/><font face='_sans' size='14'>stageDC: </font>" + 
						"<font face='" + dataFont.fontName + "' size='20'>" + Context3DStats.contextDrawCalls(DrawCallContext.STAGE) + "</font>";
			htmlText += "<br/><font face='_sans' size='14'>stage3DDC: </font>" + 
						"<font face='" + dataFont.fontName + "' size='20'>" + Context3DStats.contextDrawCalls(DrawCallContext.STAGE3D) + "</font>";
			#end
		}

		cacheCount = currentCount;
	}
}