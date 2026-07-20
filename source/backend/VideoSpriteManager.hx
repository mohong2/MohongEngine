package backend;

#if VIDEOS_ALLOWED 
#if hxCodec
#if (hxCodec >= "3.0.0") import hxcodec.flixel.FlxVideoSprite as VideoSprite;
#elseif (hxCodec >= "2.6.1") import hxcodec.VideoSprite;
#elseif (hxCodec == "2.6.0") import VideoSprite;
#else import vlc.MP4Sprite as VideoSprite; #end
#elseif hxvlc
import hxvlc.flixel.FlxVideoSprite as VideoSprite;
#end
#end
import states.PlayState;
import haxe.extern.EitherType;
import flixel.util.FlxSignal;
import flixel.util.FlxTimer;
import haxe.io.Path;

#if VIDEOS_ALLOWED
class VideoSpriteManager extends VideoSprite {
    
    var onPlayState(get, never):Bool;
    public var playbackRate(get, set):EitherType<Single, Float>;
    public var paused(default, set):Bool = false;
    public var onVideoEnd:FlxSignal;
    public var onVideoStart:FlxSignal;

    var daX:Dynamic;
    var daY:Dynamic;
    
    public function new(x:Float = 0, y:Float = 0 #if (hxCodec < "2.6.0" && hxCodec), width:Float = 1280, height:Float = 720, autoScale:Bool = true #end){

        #if (hxCodec < "2.6.0" && hxCodec)
        daX = x;
        daY = y;
        #elseif hxvlc
        daX = Std.int(x);
        daY = Std.int(y);
        #else
        daX = x;
        daY = y;
        #end

        super(daX, daY #if (hxCodec < "2.6.0" && hxCodec), width, height, autoScale #end);
        
        onVideoEnd = new FlxSignal();
        onVideoEnd.add(function(){
            destroy();
        });
        onVideoStart = new FlxSignal();
        #if (hxCodec >= "3.0.0" || hxvlc)
        onVideoEnd.add(destroy);
        bitmap.onOpening.add(function(){
            onVideoStart.dispatch();
        });
        bitmap.onEndReached.add(function(){
            onVideoEnd.dispatch();
        });
        #elseif (hxCodec < "3.0.0" && hxCodec)
        readyCallback = function(){
            onVideoStart.dispatch();
        };
        finishCallback = function(){
            onVideoEnd.dispatch();
        };
        #end
    }
    
    public function startVideo(path:String, #if hxCodec loop:Bool = false #elseif hxvlc loops:Int = 0, ?options:Array<String> #end) {
        #if (hxCodec >= "3.0.0" && hxCodec)
        play(path, loop);
        #elseif (hxCodec < "3.0.0" && hxCodec)
        playVideo(path, loop, false);
        #elseif hxvlc
        load(path, loops, options);
        new FlxTimer().start(0.001, function(tmr:FlxTimer) {
            play();
        });
        #end
        if(onPlayState)
            playbackRate = PlayState.instance.playbackRate;
    }

    @:noCompletion
    private function set_paused(shouldPause:Bool){
        #if (hxCodec >= "3.0.0" || hxvlc)
        var parentResume = resume;
        var parentPause = pause;
        #elseif(hxCodec < "3.0.0" && hxCodec)
        var parentResume = video.resume;
        var parentPause = video.pause;
        #end

        if(shouldPause){
            #if (hxCodec >= "3.0.0" || hxvlc)
            pause();
            #elseif (hxCodec < "3.0.0" && hxCodec)
            video.pause();
            #end
    
            if(FlxG.autoPause) {
                if(FlxG.signals.focusGained.has(parentResume))
                    FlxG.signals.focusGained.remove(parentResume);
    
                if(FlxG.signals.focusLost.has(parentPause))
                    FlxG.signals.focusLost.remove(parentPause);
            }
        } else {
            #if (hxCodec >= "3.0.0" || hxvlc)
            resume();
            #elseif (hxCodec < "3.0.0" && hxCodec)
            video.resume();
            #end

            if(FlxG.autoPause) {
                FlxG.signals.focusGained.add(parentResume);
                FlxG.signals.focusLost.add(parentPause);
            }
        }
        return shouldPause;
    }

    @:noCompletion
    private function set_playbackRate(multi:EitherType<Single, Float>){
        #if (hxCodec >= "2.6.0")
        bitmap.rate = multi;
        #else
        return multi;
        #end
        return multi;
    }

    @:noCompletion
    private function get_playbackRate():Float {
        #if (hxCodec >= "2.6.0")
        return bitmap.rate;
        #else
        return 1.0;
        #end
    }

    @:noCompletion
    private function get_onPlayState():Bool {
        return Std.isOfType(MusicBeatState.getState(), PlayState);
    }

    public function altDestroy() {
        super.destroy();
        #if (hxCodec < "3.0.0" && hxCodec)
        finishCallback = null;
        #end
    }
}
#end