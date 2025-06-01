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

		var option:Option = new Option('Lua TTF',
		'Change the font of lua (if lua is not set)',
        'luattf', 
        'string',
        'English',
         ['English TTF', 'Chinese TTF']);
		addOption(option);

		var option:Option = new Option('Opponent flickering effect',
		'If unchecked, the flickering effect will be canceled after the opponent hits.',
		'opponentfe',
		'bool',
		true);
		addOption(option);

		var option:Option = new Option('Side HUD',
		'If this is not checked, values such as sick and good on the left side of the game will not be displayed',
		'sidehud',
		'bool',
		true);

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

		var option:Option = new Option('Lua TTF',
		'改变lua的字体（如果lua没有设置）',
        'luattf', 
        'string',
        'English',
         ['English TTF', 'Chinese TTF']);
		addOption(option);

		var option:Option = new Option('Opponent flickering effect',
		'如果未选中将会取消对手击中后的闪烁效果。',
		'opponentfe',
		'bool',
		true);
		addOption(option);
		
		var option:Option = new Option('Side HUD',
		'如果未选中将会不显示游戏左侧的sick，Good等之类的数值',
		'sidehud',
		'bool',
		true);
		addOption(option);

		super();
		}

	}

	function onChangeHitsoundVolume()
	{
		FlxG.sound.play(Paths.sound('hitsound'), ClientPrefs.hitsoundVolume);
	}
}