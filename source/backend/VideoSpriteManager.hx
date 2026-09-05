package backend;

#if VIDEOS_ALLOWED 
// hxvlc-backed hxCodec compatibility layer (see source/objects/hxcodec)
import vlc.MP4Sprite as VideoSprite;
#end
import states.PlayState;
import haxe.extern.EitherType;
import flixel.util.FlxSignal;
import flixel.util.FlxTimer;
import mohong.TraceManager;

#if VIDEOS_ALLOWED
class VideoSpriteManager extends VideoSprite {
    
    var onPlayState(get, never):Bool;
    public var playbackRate(get, set):EitherType<Single, Float>;
    public var paused(default, set):Bool = false;
    public var onVideoEnd:FlxSignal;
    public var onVideoStart:FlxSignal;

    
    public function new(x:Float = 0, y:Float = 0, width:Float = 1280, height:Float = 720, autoScale:Bool = true){

        super(x, y, width, height, autoScale);
        
        onVideoEnd = new FlxSignal();
        onVideoEnd.add(function(){
            destroy();
        });
        onVideoStart = new FlxSignal();
        readyCallback = function(){
            onVideoStart.dispatch();
        };
        finishCallback = function(){
            onVideoEnd.dispatch();
        };
    }
    
    public function startVideo(path:String, loop:Bool = false) {
        // Wait for LibVLC init before calling playVideo; otherwise playVideo is
        // deferred and the immediate playbackRate assignment below would be lost.
        VideoPreloader.whenReady(function() {
            if (video == null)
                return;

            try
            {
                playVideo(path, loop, false);
                if(onPlayState && video != null && PlayState.instance != null)
                    playbackRate = PlayState.instance.playbackRate;
            }
            catch (e:Dynamic)
            {
                // Log failures instead of failing silently, then run the end callback.
                TraceManager.error('trace.video.startFailed', 'VideoSpriteManager failed to start video: {} - {}', [path, e]);
                finishCallback();
            }
        });
    }

    @:noCompletion
    private function set_paused(shouldPause:Bool){
        if(shouldPause){
            video.pause();
        } else {
            video.resume();
        }
        return shouldPause;
    }

    @:noCompletion
    private function set_playbackRate(multi:EitherType<Single, Float>){
        video.rate = multi;
        return multi;
    }

    @:noCompletion
    private function get_playbackRate():Float {
        return video.rate;
    }

    @:noCompletion
    private function get_onPlayState():Bool {
        return Std.isOfType(MusicBeatState.getState(), PlayState);
    }

    public function altDestroy() {
        super.destroy();
        finishCallback = null;
    }
}
#end
