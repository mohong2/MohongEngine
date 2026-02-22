package options;

#if cpp
import Discord.DiscordClient;
#end
import flixel.input.keyboard.FlxKey;
import flixel.graphics.FlxGraphic;
import Controls;
#if android
import android.Tools;
#end
using StringTools;

class GameplaySettingsSubState extends BaseOptionsMenu
{
	public function new()
	{
		 
		
		title = 'Gameplay Settings';
		rpcTitle = 'Gameplay Settings Menu';
		
		var option:Option = new Option('Controller Mode',
			Language.get("option.controllerMode.desc", "Check this if you want to play with\na controller instead of using your Keyboard."),
			'controllerMode',
			'bool',
			#if android true #else false #end);
		addOption(option);
		/*
		var option:Option = new Option('0.7.3 Compatibility mode',
			Language.get("option.compatibility_mode.desc", "If checked, lua will use the Psych Engine 0.7.3 method\n to be compatible with Psych Engine 0.7.3 mods"),
			'compatibility_mode',
			'bool',
			false
			);
		addOption(option);
	*/	
		var option:Option = new Option('Downscroll',
			Language.get("option.downScroll.desc", "If checked, notes go Down instead of Up, simple enough."),
			'downScroll',
			'bool',
			false);
		addOption(option);

		var option:Option = new Option('Middlescroll',
			Language.get("option.middleScroll.desc", "If checked, your notes get centered."),
			'middleScroll',
			'bool',
			false);
		addOption(option);
		/*
		var option:Option = new Option('KeyboardDisplay',
			Language.get("option.keyboardDisplay.desc", "If checked, Feedback the key you pressed"),
			'keyboardDisplay',
			'bool',
			false);
		addOption(option);
		*/

		var option:Option = new Option('Opponent Notes',
			Language.get("option.opponentStrums.desc", "If unchecked, opponent notes get hidden."),
			'opponentStrums',
			'bool',
			true);
		addOption(option);

		var option:Option = new Option('Ghost Tapping',
			Language.get("option.ghostTapping.desc", "If checked, you won't get misses from pressing keys\nwhile there are no notes able to be hit."),
			'ghostTapping',
			'bool',
			true);
		addOption(option);

		var option:Option = new Option('Disable Reset Button',
			Language.get("option.noReset.desc", "If checked, pressing Reset won't do anything."),
			'noReset',
			'bool',
			false);
		addOption(option);

		var option:Option = new Option('Smooth HP Bar',
			Language.get("option.smoothhpbar.desc", "If checked, the HP bar and icon movements will become smoother\nFor some levels, there may be unspeakable bugs and performance penalty"),
			'smoothhpbar',
			'bool',
			false);
		addOption(option);

		var option:Option = new Option('Note Underlay Opacity',
			Language.get("option.trackAlpha.desc", 'Funny notes does \"Tick!\" when you hit them."'),
			'trackAlpha',
			'percent',
			0);
		addOption(option);
		option.scrollSpeed = 2.0;
		option.minValue = 0.0;
		option.maxValue = 1;
		option.changeValue = 0.1;
		option.decimals = 1;

		var option:Option = new Option('Hitsound Volume',
			Language.get("option.hitsoundVolume.desc", 'Funny notes does \"Tick!\" when you hit them."'),
			'hitsoundVolume',
			'percent',
			0);
		addOption(option);
		option.scrollSpeed = 1.6;
		option.minValue = 0.0;
		option.maxValue = 1;
		option.changeValue = 0.1;
		option.decimals = 1;
		option.onChange = onChangeHitsoundVolume;

		var option:Option = new Option('Rating Offset',
			Language.get("option.ratingOffset.desc", 'Changes how late/early you have to hit for a "Sick!"\nHigher values mean you have to hit later.'),
			'ratingOffset',
			'int',
			0);
		option.displayFormat = '%vms';
		option.scrollSpeed = 20;
		option.minValue = -30;
		option.maxValue = 30;
		addOption(option);

		var option:Option = new Option('Sick! Hit Window',
			Language.get("option.sickWindow.desc", 'Changes the amount of time you have\nfor hitting a "Sick!" in milliseconds.'),
			'sickWindow',
			'int',
			45);
		option.displayFormat = '%vms';
		option.scrollSpeed = 15;
		option.minValue = 15;
		option.maxValue = 80;
		addOption(option);

		var option:Option = new Option('Good Hit Window',
			Language.get("option.goodWindow.desc", 'Changes the amount of time you have\nfor hitting a "Good" in milliseconds.'),
			'goodWindow',
			'int',
			90);
		option.displayFormat = '%vms';
		option.scrollSpeed = 30;
		option.minValue = 15;
		option.maxValue = 100;
		addOption(option);

		var option:Option = new Option('Bad Hit Window',
			Language.get("option.badWindow.desc", 'Changes the amount of time you have\nfor hitting a "Bad" in milliseconds.'),
			'badWindow',
			'int',
			130);
		option.displayFormat = '%vms';
		option.scrollSpeed = 60;
		option.minValue = 15;
		option.maxValue = 135;
		addOption(option);

		var option:Option = new Option('Safe Frames',
			Language.get("option.safeFrames.desc", 'Changes how many frames you have for\nhitting a note earlier or late.'),
			'safeFrames',
			'float',
			10);
		option.scrollSpeed = 5;
		option.minValue = 2;
		option.maxValue = 10;
		option.changeValue = 0.1;
		addOption(option);
	
		super();
	}
	

	function onChangeHitsoundVolume()
	{
		FlxG.sound.play(Paths.sound('hitsound'), ClientPrefs.data.hitsoundVolume);
	}
}

