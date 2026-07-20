package script;

import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import openfl.display.BitmapData;

/**
 * A convenience FlxSprite wrapper exposed to HScript and Lua scripts,
 * providing quick-construction helpers common in Psych Engine mods.
 */
class FunkinSprite extends FlxSprite
{
	/**
	 * Create a sprite from a graphic asset path.
	 * @param graphic Path to the image (passed through Paths.image).
	 * @param x X position.
	 * @param y Y position.
	 */
	public function new(?graphic:String = null, X:Float = 0, Y:Float = 0)
	{
		super(X, Y);
		if (graphic != null && graphic.length > 0)
			loadGraphic(Paths.image(graphic));
		antialiasing = ClientPrefs.data.globalAntialiasing;
	}

	/** Load a sparrow (generic) atlas and add an animation. */
	public function loadSparrowAtlas(key:String):Void
	{
		frames = Paths.getSparrowAtlas(key);
	}

	/** Add an animation by prefix (sparrow atlas). */
	public function addAnimByPrefix(name:String, prefix:String, fps:Int = 24, loop:Bool = true):Void
	{
		animation.addByPrefix(name, prefix, fps, loop);
	}

	/** Add an animation by indices (sparrow atlas). */
	public function addAnimByIndices(name:String, prefix:String, indices:Array<Int>, ?postfix:String = "", fps:Int = 24, loop:Bool = true):Void
	{
		animation.addByIndices(name, prefix, indices, postfix, fps, loop);
	}

	/** Play an animation by name. */
	public function playAnim(name:String, force:Bool = true, ?reverse:Bool = false, ?frame:Int = 0):Void
	{
		animation.play(name, force, reverse, frame);
	}

	/** Make the sprite a solid coloured rectangle. */
	public function makeSolid(width:Int, height:Int, color:Int = 0xFFFFFFFF):Void
	{
		makeGraphic(width, height, color);
	}
}
