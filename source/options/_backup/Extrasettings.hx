package options;

#if cpp
import Discord.DiscordClient;
#end
 
 
import flixel.addons.display.FlxGridOverlay;
 
 
 
 
import lime.utils.Assets;
import flixel.FlxSubState;
import flash.text.TextField;
 
 
import flixel.util.FlxSave;
import haxe.Json;
 
 
 
import flixel.input.keyboard.FlxKey;
import flixel.graphics.FlxGraphic;
import Controls;
import Language;
using StringTools;

class Extrasettings extends BaseOptionsMenu
{

	public function new()
	{
		 

        title = Language.get("option.extrasettings.title", "Extra settings");
        rpcTitle = Language.get("option.extrasettings.rctitle", "Extra settings Menu");

		var lang:Array<String> = Paths.mergeAllTextsNamed('lang/list.txt', "assets");
		var option:Option = new Option('Language',
			Language.get("option.language.desc", "Select the game display language."),
            'language', 
            'string',
            ClientPrefs.data.language,
            lang);
		option.onChange = function() {
			 
			#if android
			removeVirtualPad();
			#end
			Language.load();
			//FlxG.resetState();
			closeSubState();
			openSubState(new options.Extrasettings());
			
		};
		addOption(option);

		var option:Option = new Option(Language.get("option.luattf", "Lua TTF"),
		Language.get("option.luattf.desc", "Change the font of lua (if lua is not set)"),
        'luattf', 
        'string',
        'English',
         ['Default TTF', 'Language TTF']);
		addOption(option);

		var option:Option = new Option(Language.get("option.opponentfe", "Bot flickering effect"),
		Language.get("option.opponentfe.desc", "If unchecked, the flickering effect will be canceled after the Bot hits."),
		'opponentfe',
		'bool',
		true);
		addOption(option);

		var option:Option = new Option(Language.get("option.sidehud", "Side HUD"),
		Language.get("option.sidehud.desc","If this is not checked, values such as sick and good on the left side of the game will not be displayed"),
		'sidehud',
		'bool',
		true);
		addOption(option);

		var option:Option = new Option(Language.get("option.oldmodsmenu", "OLD Mods Menu"),
		Language.get("option.oldmodsmenu.desc" ,"If checked, the old mods menu will be used instead of the new one"),
		'oldmodsmenu',
		'bool',
		false);
		addOption(option);

		var option:Option = new Option(Language.get("option.newchartingstate", "New Charting State"),
		Language.get("option.newchartingstate.desc" ,"If checked, the new charting state will be used instead of the old one"),
		'newchartingstate',
		'bool',
		false);
		addOption(option);


		super();
	}

	function onChangeHitsoundVolume()
	{
		FlxG.sound.play(Paths.sound('hitsound'), ClientPrefs.data.hitsoundVolume);
	}
}