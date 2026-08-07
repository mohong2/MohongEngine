package hxcodec.flixel;

#if hxvlc
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.util.FlxColor;
import hxvlc.flixel.FlxInternalVideo;
import sys.FileSystem;

/**
 * hxCodec 3.x `hxcodec.flixel.FlxVideoSprite` compatibility layer, backed by hxvlc.
 *
 * Emulates the hxCodec 3.x sprite API (`bitmap`, `play`, `togglePaused`, ...).
 */
class FlxVideoSprite extends FlxSprite
{
	public var bitmap(default, null):FlxInternalVideo;

	var _shouldLoop:Bool = false;
	var _location:String = null;

	public function new(x:Float = 0, y:Float = 0):Void
	{
		super(x, y);

		makeGraphic(1, 1, FlxColor.TRANSPARENT);

		bitmap = new FlxInternalVideo();
		hxvlc.openfl.Video.useTexture = false;
		bitmap.forceRendering = true;
		bitmap.alpha = 0;

		bitmap.onFormatSetup.add(function()
		{
			if (bitmap != null && bitmap.bitmapData != null)
				loadGraphic(bitmap.bitmapData);
		});

		FlxG.game.addChild(bitmap);
	}

	public function play(location:String, shouldLoop:Bool = false):Bool
	{
		_shouldLoop = shouldLoop;

		if (_shouldLoop)
		{
			bitmap.onEndReached.add(function()
			{
				bitmap.stop();
				haxe.Timer.delay(function()
				{
					if (bitmap != null && _location != null && bitmap.load(_location))
						bitmap.play();
				}, 50);
			});
		}

		var videoPath = location;
		if (FileSystem.exists(Sys.getCwd() + location))
			videoPath = Sys.getCwd() + location;

		_location = videoPath;

		var success = bitmap.load(videoPath);
		if (success)
		{
			bitmap.play();
			return true;
		}

		return false;
	}

	public function stop():Void
	{
		if (bitmap != null)
			bitmap.stop();
	}

	public function pause():Void
	{
		if (bitmap != null)
			bitmap.pause();
	}

	public function resume():Void
	{
		if (bitmap != null)
			bitmap.resume();
	}

	public function togglePaused():Void
	{
		if (bitmap != null)
		{
			if (bitmap.isPlaying)
				bitmap.pause();
			else
				bitmap.resume();
		}
	}

	override public function destroy():Void
	{
		if (bitmap != null)
		{
			if (FlxG.game.contains(bitmap))
				FlxG.game.removeChild(bitmap);

			bitmap.dispose();
			bitmap = null;
		}

		super.destroy();
	}
}
#else
// Dummy fallback so `hxcodec.flixel.FlxVideoSprite` always exists (e.g. HTML5 builds).
class FlxVideoSprite extends flixel.FlxSprite
{
	public var bitmap(default, null):Dynamic = null;

	public function new(x:Float = 0, y:Float = 0):Void
	{
		super(x, y);
		trace("FlxVideoSprite: hxvlc is not available on this target!");
	}

	public function play(location:String, shouldLoop:Bool = false):Bool
	{
		trace("FlxVideoSprite.play: hxvlc is not available on this target!");
		return false;
	}

	public function stop():Void {}
	public function pause():Void {}
	public function resume():Void {}
	public function togglePaused():Void {}
}
#end
