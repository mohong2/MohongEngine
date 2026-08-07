package hxcodec.flixel;

#if hxvlc
import flixel.FlxG;
import hxvlc.flixel.FlxInternalVideo;
import openfl.events.Event;
import sys.FileSystem;

/**
 * hxCodec 3.x `hxcodec.flixel.FlxVideo` compatibility layer, backed by hxvlc.
 *
 * Emulates the hxCodec 3.x API (`play`, `autoResize`, `onEndReached`, ...).
 */
class FlxVideo extends FlxInternalVideo
{
	public var autoResize:Bool = true;

	var _shouldLoop:Bool = false;
	var _location:String = null;

	public var onTextureSetup(get, never):Dynamic;
	public var location(get, never):String;

	public function new():Void
	{
		super();

		// CPU rendering + keep updating frames while invisible
		// (see vlc.MP4Handler for details)
		hxvlc.openfl.Video.useTexture = false;
		forceRendering = true;

		// `play` collides with hxvlc's own `play():Bool`, so expose the
		// hxCodec 3.x signature at runtime (same trick as FNF-PlusEngine).
		Reflect.setField(this, "play", function(location:String, shouldLoop:Bool = false):Bool
		{
			return playMP4(location, shouldLoop);
		});

		FlxG.addChildBelowMouse(this);

		FlxG.stage.addEventListener(Event.ENTER_FRAME, onEnterFrame);
	}

	@:noCompletion
	function onEnterFrame(e:Event):Void
	{
		if (autoResize)
		{
			var aspectRatio:Float = FlxG.width / FlxG.height;

			if (FlxG.stage.stageWidth / FlxG.stage.stageHeight > aspectRatio)
			{
				// stage is wider than the video
				width = FlxG.stage.stageHeight * aspectRatio;
				height = FlxG.stage.stageHeight;
			}
			else
			{
				// stage is taller than the video
				width = FlxG.stage.stageWidth;
				height = FlxG.stage.stageWidth * (1 / aspectRatio);
			}
		}
	}

	public function playMP4(location:String, shouldLoop:Bool = false):Bool
	{
		_shouldLoop = shouldLoop;

		if (_shouldLoop)
		{
			onEndReached.add(function()
			{
				stop();
				haxe.Timer.delay(function()
				{
					if (_location != null && load(_location))
						play();
				}, 50);
			});
		}

		var videoPath = location;
		if (FileSystem.exists(Sys.getCwd() + location))
			videoPath = Sys.getCwd() + location;

		_location = videoPath;

		var success = load(videoPath);
		if (success)
		{
			play();
			return true;
		}

		return false;
	}

	override public function dispose():Void
	{
		FlxG.stage.removeEventListener(Event.ENTER_FRAME, onEnterFrame);

		stop();

		if (FlxG.game.contains(this))
			FlxG.game.removeChild(this);

		super.dispose();
	}

	@:noCompletion
	private function get_onTextureSetup():Dynamic
	{
		return onFormatSetup;
	}

	@:noCompletion
	private function get_location():String
	{
		return _location;
	}
}
#else
// Dummy fallback so `hxcodec.flixel.FlxVideo` always exists (e.g. HTML5 builds).
class FlxVideo
{
	public var autoResize:Bool = true;
	public var location:String = null;

	public function new():Void
	{
		trace("FlxVideo: hxvlc is not available on this target!");
	}

	public function play(location:String, shouldLoop:Bool = false):Bool
	{
		trace("FlxVideo.play: hxvlc is not available on this target!");
		return false;
	}

	public function dispose():Void {}
	public function pause():Void {}
	public function resume():Void {}
	public function stop():Void {}
}
#end
