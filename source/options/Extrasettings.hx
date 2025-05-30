package options;

#if desktop
import Discord.DiscordClient;
#end
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.display.FlxGridOverlay;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import lime.utils.Assets;
import flixel.FlxSubState;
import flash.text.TextField;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.util.FlxSave;
import haxe.Json;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxTimer;
import flixel.input.keyboard.FlxKey;
import flixel.graphics.FlxGraphic;
import Controls;

using StringTools;

class Extrasettings extends BaseOptionsMenu
{
	public function new()
	{
		if (ClientPrefs.language == 'English') {
        title = 'Extra settings';
        rpcTitle = 'Extra settings Menu';

		var option:Option = new Option('Language',
			'Select the game display language.',
            'language', 
            'string',
            'English',
            ['English', 'Chinese']);
		addOption(option);
		super();
		}
		else{
        title = 'Extra settings';
        rpcTitle = 'Extra settings Menu';

		var option:Option = new Option('Language',
			'选择游戏显示语言。',
            'language', 
            'string',
            'English',
            ['English', 'Chinese']);
		addOption(option);
		super();
		}
	}

	function onChangeHitsoundVolume()
	{
		FlxG.sound.play(Paths.sound('hitsound'), ClientPrefs.hitsoundVolume);
	}
}