package backend;

#if android
import openfl.events.KeyboardEvent;
import flixel.FlxG;
import flixel.input.FlxInput;
import flixel.input.android.FlxAndroidKey;

/**
 * SDL3 changed Android BACK's key code from the old SDL2 APP_CONTROL_BACK
 * (0x4000010E) to the new SDLK_AC_BACK (0x4000011A).  FlxG.android still
 * tracks only the old code, so translate the new key event into the existing
 * FlxAndroidKey.BACK input.  This keeps `FlxG.android.justPressed/justReleased.BACK`
 * working everywhere without touching every call site.
 */
class AndroidBackFix
{
	static var initialized:Bool = false;

	public static function init():Void
	{
		if (initialized) return;

		var stage = FlxG.stage;
		if (stage == null) return;
		initialized = true;

		stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
		stage.addEventListener(KeyboardEvent.KEY_UP, onKeyUp);
	}

	static function onKeyDown(event:KeyboardEvent):Void
	{
		if (event.keyCode != 0x4000011A) return;

		@:privateAccess
		var back:FlxInput<FlxAndroidKey> = FlxG.android._keyListMap.get(FlxAndroidKey.BACK);
		if (back != null) back.press();

		preventDefaultIfNeeded(event);
	}

	static function onKeyUp(event:KeyboardEvent):Void
	{
		if (event.keyCode != 0x4000011A) return;

		@:privateAccess
		var back:FlxInput<FlxAndroidKey> = FlxG.android._keyListMap.get(FlxAndroidKey.BACK);
		if (back != null) back.release();

		preventDefaultIfNeeded(event);
	}

	static function preventDefaultIfNeeded(event:KeyboardEvent):Void
	{
		if (FlxG.android.preventDefaultKeys == null) return;
		if (FlxG.android.preventDefaultKeys.indexOf(FlxAndroidKey.BACK) == -1) return;

		event.stopImmediatePropagation();
		event.stopPropagation();
		event.preventDefault();
	}
}
#end
