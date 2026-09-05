package script.lua;

import flixel.FlxG;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxStringUtil;
import Paths;
import ClientPrefs;
import states.PlayState;

class ModchartText extends FlxText
{
	public var wasAdded:Bool = false;
	public function new(x:Float, y:Float, text:String, width:Float)
	{
		super(x, y, width, text, 16);
		if (ClientPrefs.data.luattf == 'Default TTF') {
		setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		}else
		{ 
		setFormat(Paths.languageFont(), 16, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		}

		cameras = (PlayState.instance != null && PlayState.instance.camHUD != null) ? [PlayState.instance.camHUD] : [FlxG.camera];
		scrollFactor.set();
		borderSize = 2;
	}
}
