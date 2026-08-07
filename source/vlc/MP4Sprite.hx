package vlc;

#if hxvlc
import flixel.FlxSprite;

/**
 * hxCodec 2.5.x `vlc.MP4Sprite` compatibility layer, backed by hxvlc.
 *
 * Plays a video inside a FlxSprite. `video` stays public on purpose:
 * the engine's `VideoSpriteManager` (and old mods) access it directly.
 */
class MP4Sprite extends FlxSprite
{
	public var readyCallback:Void->Void;
	public var finishCallback:Void->Void;

	public var video:MP4Handler;

	public function new(x:Float = 0, y:Float = 0, width:Float = 320, height:Float = 240, autoScale:Bool = true)
	{
		super(x, y);

		video = new MP4Handler(width, height, autoScale);
		video.alpha = 0;

		video.readyCallback = function()
		{
			if (video.bitmapData != null)
				loadGraphic(video.bitmapData);

			if (readyCallback != null)
				readyCallback();
		};

		video.finishCallback = function()
		{
			if (finishCallback != null)
				finishCallback();

			kill();
		};
	}

	/**
	 * Native video support for Flixel & OpenFL
	 * @param path Example: `your/video/here.mp4`
	 * @param repeat Repeat the video.
	 * @param pauseMusic Pause music until done video.
	 */
	public function playVideo(path:String, ?repeat:Bool = false, pauseMusic:Bool = false):Void
	{
		video.playVideo(path, repeat, pauseMusic);
	}

	public function pause():Void
	{
		video.pause();
	}

	public function resume():Void
	{
		video.resume();
	}

	override public function destroy():Void
	{
		if (video != null)
		{
			video.dispose();
			video = null;
		}

		super.destroy();
	}
}
#else
// Dummy fallback so `vlc.MP4Sprite` always exists (e.g. HTML5 builds).
class MP4Sprite extends flixel.FlxSprite
{
	public var readyCallback:Void->Void;
	public var finishCallback:Void->Void;
	public var video:Dynamic = null;

	public function new(x:Float = 0, y:Float = 0, width:Float = 320, height:Float = 240, autoScale:Bool = true)
	{
		super(x, y);
		trace("MP4Sprite: hxvlc is not available on this target!");
	}

	public function playVideo(path:String, ?repeat:Bool = false, pauseMusic:Bool = false):Void
	{
		trace("MP4Sprite.playVideo: hxvlc is not available on this target!");

		if (finishCallback != null)
			finishCallback();
	}

	public function pause():Void {}
	public function resume():Void {}
}
#end
