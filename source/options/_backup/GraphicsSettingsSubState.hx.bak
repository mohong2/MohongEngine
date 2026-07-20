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
		title = Language.get("option.graphics", "Graphics");
		rpcTitle = Language.get("option.graphicsSettingsMenu", "Graphics Settings Menu");
		
		var option:Option = new Option(Language.get("option.lowQuality", "Low Quality"),
			Language.get("option.lowQuality.desc", "If checked, disables some background details,\ndecreases loading times and improves performance."),
			'lowQuality',
			'bool',
			false);
		addOption(option);

		var option:Option = new Option(Language.get("option.globalAntialiasing", "Anti-Aliasing"),
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

		var option:Option = new Option(Language.get("option.cacheOnGPU", "GPU Caching"),
			Language.get("option.cacheOnGPU.desc", "If checked, allows the GPU to be used for caching textures, decreasing RAM usage.\nDon't turn this on if you have a shitty Graphics Card."),
			'cacheOnGPU',
			'bool');
		addOption(option);
		/*
		var option:Option = new Option(Language.get("option.preloadAssets", "Preload Assets"),
			Language.get("option.preloadAssets.desc", "If checked, preloads script images before gameplay with a loading screen.\nReduces lag during songs at the cost of initial load time."),
			'preloadAssets',
			'bool',
			false);
		addOption(option);
		*/

		#if !html5
		var option:Option = new Option(Language.get("option.framerate", "Framerate"),
			Language.get("option.framerate.desc", "Pretty self explanatory, isn't it?"),
			'framerate',
			'int',
			60);
		addOption(option);

		option.minValue = 60;
		option.maxValue = 360;
		option.displayFormat = '%v FPS';
		option.onChange = onChangeFramerate;
		
		#if desktop
		var option:Option = new Option(Language.get("option.windowedmode", "Windowed mode"),
			Language.get("option.windowedmode.desc", "Choose your window mode (Press ACCEPT to apply changes)."),
			'windowedmode',
			'string',
			'windowed',
			['windowed', 'fullscreen'/*, 'borderless'*/]);
		option.onChange = onChangeWindowMode;
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
	
	#if desktop
	function onChangeWindowMode()
	{
		var mode:String = ClientPrefs.data.windowedmode;
		
		try {
			var window = Lib.application.window;
			switch(mode)
			{
				case 'windowed':
					FlxG.fullscreen = false;
					Lib.application.window.fullscreen = false;
					Lib.application.window.borderless = false;
				case 'fullscreen':
					FlxG.fullscreen = true;
					Lib.application.window.fullscreen = true;
					Lib.application.window.borderless = false;
					
				case 'borderless':
					FlxG.fullscreen = false;
					window.fullscreen = false;
					window.borderless = true;
					
					var screenWidth:Int = Lib.current.stage.stageWidth;
					var screenHeight:Int = Lib.current.stage.stageHeight;
					
					window.width = screenWidth;
					window.height = screenHeight;
					window.x = 0;
					window.y = 0;
				
			}
		} catch(e:Dynamic) {
			trace('Failed to change window mode: $e');
		}
	}
	#end
}