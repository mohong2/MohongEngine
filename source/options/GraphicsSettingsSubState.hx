package options;

#if cpp
import Discord.DiscordClient;
#end
import flash.text.TextField;
 
 
 
import flixel.addons.display.FlxGridOverlay;
 
 
 
 
import lime.utils.Assets;
import flixel.FlxSubState;
import flash.text.TextField;
 
 
import flixel.util.FlxSave;
import haxe.Json;
 
 
 
import flixel.input.keyboard.FlxKey;
import flixel.graphics.FlxGraphic;
import Controls;
import openfl.Lib;

using StringTools;

class GraphicsSettingsSubState extends BaseOptionsMenu
{
public function new()
	{
		 
		
		title = 'Graphics';
		rpcTitle = 'Graphics Settings Menu';
		
		var option:Option = new Option('Low Quality',
			Language.get("option.lowQuality.desc", "If checked, disables some background details,\ndecreases loading times and improves performance."),
			'lowQuality',
			'bool',
			false);
		addOption(option);

		var option:Option = new Option('Anti-Aliasing',
			Language.get("option.globalAntialiasing.desc", "If unchecked, disables anti-aliasing, increases performance\nat the cost of sharper visuals."),
			'globalAntialiasing',
			'bool',
			true);
		option.showBoyfriend = true;
		option.onChange = onChangeAntiAliasing;
		addOption(option);

		var option:Option = new Option('Shaders',
			Language.get("option.shaders.desc", "If unchecked, disables shaders.\nIt's used for some visual effects, and also CPU intensive for weaker PCs."),
			'shaders',
			'bool',
			true);
		addOption(option);

		var option:Option = new Option('GPU Caching',
			Language.get("option.cacheOnGPU.desc", "If checked, allows the GPU to be used for caching textures, decreasing RAM usage.\nDon't turn this on if you have a shitty Graphics Card."),
			'cacheOnGPU',
			'bool');
		addOption(option);

		#if !html5
		var option:Option = new Option('Framerate',
			Language.get("option.framerate.desc", "Pretty self explanatory, isn't it?"),
			'framerate',
			'int',
			60);
		addOption(option);

		option.minValue = 60;
		option.maxValue = 360;
		option.displayFormat = '%v FPS';
		option.onChange = onChangeFramerate;
		#if !android
		var option:Option = new Option('Windowed mode',
			Language.get("option.windowedmode.desc", "Choose your window mod(The game needs to be restarted)(Has bugs)"),
			'windowedmode',
			'string',
			'windowed',
			['windowed', 'fullscreen', 'borderless']);
		addOption(option);
		#end
		#end

		super();
	}
	
	function onChangeAntiAliasing()
	{
		for (sprite in members)
		{
			var sprite:Dynamic = sprite; //Make it check for FlxSprite instead of FlxBasic
			var sprite:FlxSprite = sprite; //Don't judge me ok
			if(sprite != null && (sprite is FlxSprite) && !(sprite is FlxText)) {
				sprite.antialiasing = ClientPrefs.data.globalAntialiasing;
			}
		}
	}

	function onChangeFramerate()
	{
		if(ClientPrefs.data.framerate > FlxG.drawFramerate)
		{
			FlxG.updateFramerate = ClientPrefs.data.framerate;
			FlxG.drawFramerate = ClientPrefs.data.framerate;
		}
		else
		{
			FlxG.drawFramerate = ClientPrefs.data.framerate;
			FlxG.updateFramerate = ClientPrefs.data.framerate;
		}
	}
}