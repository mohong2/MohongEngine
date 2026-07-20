package script;

import flixel.ui.FlxBar;
import flixel.util.FlxColor;
import flixel.math.FlxRect;

/**
 * A convenience fill‑bar wrapper exposed to HScript / Lua.
 */
class FunkinBar extends FlxBar
{
	/**
	 * @param x        X position
	 * @param y        Y position
	 * @param w        Width  (px)
	 * @param h        Height (px)
	 * @param min      Minimum value
	 * @param max      Maximum value
	 * @param bgColor  Background colour
	 * @param fillColor Fill colour
	 */
	public function new(X:Float = 0, Y:Float = 0, w:Int = 200, h:Int = 20,
			min:Float = 0, max:Float = 100,
			?bgColor:FlxColor = 0xFF000000, ?fillColor:FlxColor = 0xFFFFFFFF)
	{
		super(X, Y, LEFT_TO_RIGHT, w, h, null, null, min, max);
		createFilledBar(bgColor, fillColor);
		numDivisions = 2000;
	}
}
