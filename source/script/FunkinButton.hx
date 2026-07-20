package script;

import flixel.ui.FlxButton;
import flixel.util.FlxColor;

/**
 * A convenience button wrapper exposed to HScript / Lua.
 */
class FunkinButton extends FlxButton
{
	public function new(X:Float = 0, Y:Float = 0, ?text:String = "Button", ?onClick:Void->Void)
	{
		super(X, Y, text, onClick);
		label.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER);
	}
}
