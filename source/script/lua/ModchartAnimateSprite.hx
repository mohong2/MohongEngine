package script.lua;

#if flxanimate
import flxanimate.PsychFlxAnimate;
import ClientPrefs;

/**
 * 0.7.3/1.0.4 兼容的 FlxAnimate modchart 精灵（带动画偏移表）。
 * English: 0.7.3/1.0.4-compatible FlxAnimate modchart sprite (with anim offsets).
 */
class ModchartAnimateSprite extends PsychFlxAnimate
{
	public var animOffsets:Map<String, Array<Float>> = new Map<String, Array<Float>>();
	public function new(?x:Float = 0, ?y:Float = 0)
	{
		super(x, y);
		antialiasing = ClientPrefs.data.globalAntialiasing;
	}

	public function playAnim(name:String, forced:Bool = false, ?reverse:Bool = false, ?startFrame:Int = 0)
	{
		anim.play(name, forced, reverse, startFrame);

		var daOffset = animOffsets.get(name);
		if (animOffsets.exists(name)) offset.set(daOffset[0], daOffset[1]);
	}

	public function addOffset(name:String, x:Float, y:Float)
	{
		animOffsets.set(name, [x, y]);
	}
}
#end
