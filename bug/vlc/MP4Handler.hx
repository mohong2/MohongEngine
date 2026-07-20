package vlc;


#if (hxCodec >= "3.0.0")
import flixel.FlxG;
import hxcodec.flixel.FlxVideo;
import openfl.events.Event;

/**
 * Compatibility layer for the old MP4Handler API.
 * Internally uses the newer hxCodec FlxVideo system.
 * 
 * Stability improvements in this adapter:
 * - Prevents double-disposal of video resources.
 * - Manages ENTER_FRAME listener safely to avoid conflicts.
 * - Handles visibility correctly while keeping rendering active.
 * - Ensures music pause/resume happens exactly once.
 * - Uses a state flag to avoid callback re-entrancy.
 * - Properly removes onEndReached callback to prevent memory leaks.
 * - Cleans up FlxVideo sprite from display list on dispose.
 * - Added error handling for video playback failures.
 */
class MP4Handler extends FlxVideo
{
	public var readyCallback:Void->Void;
	public var finishCallback:Void->Void;

	var pauseMusic:Bool = false;
	var isFinished:Bool = false;      // Prevents multiple finishVideo calls
	var updateAdded:Bool = false;     // Tracks if we manually added an ENTER_FRAME listener
	var isDisposed:Bool = false;      // Prevents double-disposal

	public function new(width:Float = 320, height:Float = 240, autoScale:Bool = true)
	{
		super();

		// Match old constructor behavior
		this.width = width;
		this.height = height;
		this.autoResize = autoScale;

		// Map hxCodec callbacks
		onOpening.add(function() {
			if (readyCallback != null) readyCallback();
		});

		// Use a named function so we can remove it later
		onEndReached.add(onVideoEnd);

		// The base class already adds itself to FlxG via addChildBelowMouse
	}

	/**
	 * Named callback for onEndReached to allow proper removal.
	 */
	private function onVideoEnd():Void
	{
		if (!isFinished)
			finishVideo();
	}

	/**
	 * Override visible setter: setting visible=false keeps rendering active (alpha=0).
	 * This allows the internal frame loop to continue, so bitmapData stays updated.
	 */
	override private function set_visible(value:Bool):Bool
	{
		if (!value)
		{
			this.alpha = 0;
			return super.set_visible(true);
		}
		else
		{
			this.alpha = 1;
			return super.set_visible(true);
		}
	}

	/**
	 * Play a video file.
	 */
	public function playVideo(path:String, ?repeat:Bool = false, pauseMusic:Bool = false):Void
	{
		if (isFinished || isDisposed)
			return; // Already disposed, cannot reuse

		this.pauseMusic = pauseMusic;

		if (pauseMusic && FlxG.sound.music != null)
			FlxG.sound.music.pause();

		// Add a dummy ENTER_FRAME listener for compatibility if needed.
		// Some old scripts try to remove it. We add it only if not already present.
		if (!FlxG.stage.hasEventListener(Event.ENTER_FRAME))
		{
			FlxG.stage.addEventListener(Event.ENTER_FRAME, update);
			updateAdded = true;
		}

		var fullPath:String = checkFile(path);
		
		// Try to play the video, handle failure gracefully
		try
		{
			var result:Int = super.play(fullPath, repeat);
			#if debug
			if (result == -1)
			{
				trace('Failed to play video: ' + fullPath);
				finishVideo();
				return;
			}
			#end
		}
		catch (e:Dynamic)
		{
			#if debug
			trace('Error playing video: ' + e);
			#end
			finishVideo();
		}
	}

	/**
	 * Stop playback and clean up.
	 * Guaranteed to run only once.
	 */
	public function finishVideo():Void
	{
		if (isFinished)
			return;
		isFinished = true;

		// Resume music if we paused it
		if (pauseMusic && FlxG.sound.music != null)
			FlxG.sound.music.resume();

		// Remove our compatibility ENTER_FRAME listener
		if (updateAdded)
		{
			FlxG.stage.removeEventListener(Event.ENTER_FRAME, update);
			updateAdded = false;
		}

		// Remove the end reached callback to prevent memory leaks
		@:privateAccess
		{
			if (onEndReached != null)
				onEndReached.remove(onVideoEnd);
		}

		// Dispose native resources (FlxVideo.dispose does everything)
		dispose();

		if (finishCallback != null)
			finishCallback();
	}

	override public function pause():Void
	{
		if (!isFinished && !isDisposed)
			super.pause();
	}

	override public function resume():Void
	{
		if (!isFinished && !isDisposed)
			super.resume();
	}

	/**
	 * Legacy update function – does nothing, but kept for event listener compatibility.
	 */
	private function update(e:Event):Void
	{
		// No-op; rendering is handled internally by hxCodec.
	}

	/**
	 * Replicates the old path prefix logic.
	 */
	#if sys
	private function checkFile(fileName:String):String
	{
		#if !android
		var pDir = "";
		var appDir = "file:///" + Sys.getCwd() + "/";

		if (fileName.indexOf(":") == -1)
			pDir = appDir;
		else if (fileName.indexOf("file://") == -1 || fileName.indexOf("http") == -1)
			pDir = "file:///";

		return pDir + fileName;
		#else
		return "file://" + fileName;
		#end
	}
	#end

	/**
	 * Override dispose to avoid double-free and to clean up our own state.
	 */
	override public function dispose():Void
	{
		if (isDisposed)
			return; // Already disposed

		isDisposed = true;
		isFinished = true; // Also mark as finished to prevent further operations

		// Remove listener if still attached
		if (updateAdded)
		{
			FlxG.stage.removeEventListener(Event.ENTER_FRAME, update);
			updateAdded = false;
		}

		// Remove the end reached callback to prevent memory leaks
		@:privateAccess
		{
			if (onEndReached != null)
				onEndReached.remove(onVideoEnd);
		}

		// Clear callbacks to help GC
		readyCallback = null;
		finishCallback = null;

		Paths.clearUnusedMemory();

		// Let super handle the native cleanup
		super.dispose();
	}
}
#elseif (hxCodec == "2.5.1")
import openfl.events.Event;
import flixel.FlxG;
import vlc.bitmap.VlcBitmap;
/**
 * Play a video using cpp.
 * Use bitmap to connect to a graphic or use `MP4Sprite`.
 */
class MP4Handler extends VlcBitmap
{
	public var readyCallback:Void->Void;
	public var finishCallback:Void->Void;

	var pauseMusic:Bool;

	public function new(width:Float = 320, height:Float = 240, autoScale:Bool = true)
	{
		super(width, height, autoScale);

		onVideoReady = onVLCVideoReady;
		onComplete = finishVideo;
		onError = onVLCError;

		FlxG.addChildBelowMouse(this);

		FlxG.stage.addEventListener(Event.ENTER_FRAME, update);

		FlxG.signals.focusGained.add(function()
		{
			resume();
		});
		FlxG.signals.focusLost.add(function()
		{
			pause();
		});
	}

	function update(e:Event)
	{
		if ((FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.SPACE) && isPlaying)
			finishVideo();

		if (FlxG.sound.muted || FlxG.sound.volume <= 0)
			volume = 0;
		else
			volume = FlxG.sound.volume + 0.4;
	}

	#if sys
	function checkFile(fileName:String):String
	{
		#if !android
		var pDir = "";
		var appDir = "file:///" + Sys.getCwd() + "/";

		if (fileName.indexOf(":") == -1) // Not a path
			pDir = appDir;
		else if (fileName.indexOf("file://") == -1 || fileName.indexOf("http") == -1) // C:, D: etc? ..missing "file:///" ?
			pDir = "file:///";

		return pDir + fileName;
		#else
		return "file://" + fileName;
		#end
	}
	#end

	function onVLCVideoReady()
	{
		trace("Video loaded!");

		if (readyCallback != null)
			readyCallback();
	}

	function onVLCError()
	{
		// TODO: Catch the error
		throw "VLC caught an error!";
	}

	public function finishVideo()
	{
		if (FlxG.sound.music != null && pauseMusic)
			FlxG.sound.music.resume();

		FlxG.stage.removeEventListener(Event.ENTER_FRAME, update);

		dispose();

		if (FlxG.game.contains(this))
		{
			FlxG.game.removeChild(this);

			if (finishCallback != null)
				finishCallback();
		}
	}

	/**
	 * Native video support for Flixel & OpenFL
	 * @param path Example: `your/video/here.mp4`
	 * @param repeat Repeat the video.
	 * @param pauseMusic Pause music until done video.
	 */
	public function playVideo(path:String, ?repeat:Bool = false, pauseMusic:Bool = false)
	{
		this.pauseMusic = pauseMusic;

		if (FlxG.sound.music != null && pauseMusic)
			FlxG.sound.music.pause();

		#if sys
		play(checkFile(path));

		this.repeat = repeat ? -1 : 0;
		#else
		throw "Doesn't support sys";
		#end
	}
}
#elseif (hxCodec == "2.6.1")
import openfl.events.Event;
import flixel.FlxG;
import hxcodec.vlc.VLCBitmap;
import openfl.display.BitmapData;
import openfl.display.Sprite;
import openfl.Lib;

/**
 * Compatibility layer for the old `vlc.MP4Handler` API
 * using the new `hxcodec.vlc.VLCBitmap` backend.
 * 
 * Since VLCBitmap extends openfl.display.Bitmap, it can be added to
 * FlxG.game directly (which is a Sprite).
 */
class MP4Handler
{
	public var video:VLCBitmap;
	public var readyCallback:Void->Void;
	public var finishCallback:Void->Void;

	private var pauseMusic:Bool = false;
	private var _visible:Bool = true;
	private var _volume:Float = 1.0;
	private var started:Bool = false;
	private var finished:Bool = false;

	public function new(width:Float = 320, height:Float = 240, autoScale:Bool = true)
	{
		video = new VLCBitmap();
		
		// Set initial size
		video.width = width;
		video.height = height;
		video.visible = true;

		// We'll handle sizing in onOpening
		video.onPlaying = function()
		{
			if (!started)
			{
				started = true;
				
				// Auto-scale if needed
				if (autoScale && FlxG.stage != null)
				{
					video.width = getVideoWidth();
					video.height = getVideoHeight();
				}
				
				if (readyCallback != null)
					readyCallback();
			}
		};

		video.onEndReached = function()
		{
			if (!finished)
				finishVideo();
		};

		video.onEncounteredError = function()
		{
			if (!finished)
				finishVideo();
		};

		// Add to stage - FlxG.game is a Sprite, VLCBitmap is a Bitmap (DisplayObject)
		FlxG.game.addChild(video);

		// Our own frame update for skip/volume
		Lib.current.stage.addEventListener(Event.ENTER_FRAME, update);

		// Auto-pause/resume on focus change
		FlxG.signals.focusGained.add(function()
		{
			resume();
		});
		FlxG.signals.focusLost.add(function()
		{
			pause();
		});
	}

	public function playVideo(path:String, ?repeat:Bool = false, pauseMusic:Bool = false):Void
	{
		this.pauseMusic = pauseMusic;
		finished = false;
		started = false;

		if (FlxG.sound.music != null && pauseMusic)
			FlxG.sound.music.pause();

		video.play(path, repeat);
	}

	public function pause():Void
	{
		if (video != null)
			video.pause();
	}

	public function resume():Void
	{
		if (video != null)
			video.resume();
	}

	public function finishVideo():Void
	{
		if (finished)
			return;
		finished = true;

		// Resume music if we paused it
		if (FlxG.sound.music != null && pauseMusic)
			FlxG.sound.music.resume();

		// Remove our frame listener
		Lib.current.stage.removeEventListener(Event.ENTER_FRAME, update);

		// Stop and dispose the player
		if (video != null)
		{
			video.stop();
			video.dispose();
			
			// Remove from display list
			if (video.parent != null)
				video.parent.removeChild(video);
		}

		if (finishCallback != null)
			finishCallback();
	}

	private function update(e:Event):Void
	{
		if (video == null || finished)
			return;

		// Skip on ENTER / SPACE (old MP4Handler behaviour)
		if ((FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.SPACE) && video.isPlaying)
			finishVideo();

		// Volume syncing - VLCBitmap volume is 0-100, old MP4Handler used 0.0-1.0
		if (FlxG.sound.muted || FlxG.sound.volume <= 0)
			video.volume = 0;
		else
			video.volume = Std.int((FlxG.sound.volume + 0.4) * 100);
	}

	// ---- Property accessors (compatible with old Lua scripts) ----

	public var visible(get, set):Bool;
	private function get_visible():Bool { return _visible; }
	private function set_visible(value:Bool):Bool
	{
		_visible = value;
		if (video != null) video.visible = value;
		return _visible;
	}

	public var bitmapData(get, never):BitmapData;
	private function get_bitmapData():BitmapData
	{
		if (video != null) return video.bitmapData;
		return null;
	}

	public var volume(get, set):Float;
	private function get_volume():Float { return _volume; }
	private function set_volume(value:Float):Float
	{
		_volume = value;
		if (video != null) video.volume = Std.int(value * 100);
		return _volume;
	}

	public var isPlaying(get, never):Bool;
	private function get_isPlaying():Bool
	{
		if (video != null) return video.isPlaying;
		return false;
	}

	// ---- Helper: same sizing logic as old VlcBitmap ----

	private function getVideoWidth():Float
	{
		if (FlxG.stage == null) return 320;
		if (FlxG.stage.stageHeight / 9 < FlxG.stage.stageWidth / 16)
			return FlxG.stage.stageHeight * (16 / 9);
		else
			return FlxG.stage.stageWidth;
	}

	private function getVideoHeight():Float
	{
		if (FlxG.stage == null) return 240;
		if (FlxG.stage.stageHeight / 9 < FlxG.stage.stageWidth / 16)
			return FlxG.stage.stageHeight;
		else
			return FlxG.stage.stageWidth / (16 / 9);
	}
}
#end