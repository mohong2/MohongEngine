package script.hscript;

import haxe.io.Path;
import flixel.addons.display.FlxRuntimeShader;
import crowplexus.hscript.*;
import crowplexus.hscript.Expr.Error;
import crowplexus.hscript.Parser;
import flixel.FlxG;
import flixel.util.FlxColor;
import Paths;
import Conductor;
import ClientPrefs;
import Character;
import Alphabet;
import script.lua.FunkinLua;
import states.*;
import script.tools.*;
#if HSCRIPT_ALLOWED

enum HScriptType {
    STATE;   
    GLOBAL;     
    PLAYSTATE;  
    MODULE;     
}

class HScript
{
    public static var globalScripts:Array<HScript> = [];
    private static var initialized:Bool = false;
    
    public static function initialize() {
        if (initialized) return;
        initialized = true;
        loadGlobalScripts();
        trace('HScript initialized with ${globalScripts.length} global scripts');
    }
    
    private static function loadGlobalScripts() {
        var filesPushed:Array<String> = [];
        var foldersToCheck:Array<String> = [Paths.getPreloadPath('hscript/global/')];

        #if MODS_ALLOWED
        foldersToCheck.insert(0, Paths.mods('hscript/global/'));
        if(Paths.currentModDirectory != null && Paths.currentModDirectory.length > 0)
            foldersToCheck.insert(0, Paths.mods(Paths.currentModDirectory + '/hscript/global/'));

        for(mod in Paths.getGlobalMods())
            foldersToCheck.insert(0, Paths.mods(mod + '/hscript/global/'));
        #end

        for (folder in foldersToCheck) {
            if(FileSystem.exists(folder)) {
                for (file in FileSystem.readDirectory(folder)) {
                    if(isHscriptFile(file) && !filesPushed.contains(file)) {
                        try {
                            var script = new HScript(folder + file);
                            script.scriptType = GLOBAL;
                            globalScripts.push(script);
                            filesPushed.push(file);
                        } catch (e:Dynamic) {
                            trace('Failed to load global hscript: $file - $e');
                        }
                    }
                }
            }
        }
    }
    
    public static function callOnGlobalScript(event:String, args:Array<Dynamic> = null):Dynamic {
        if (args == null) args = [];
        var returnVal:Dynamic = FunkinLua.Function_Continue;
        
        for (script in globalScripts) {
            if (script.closed) continue;
            
            var ret:Dynamic = script.call(event, args);
            if(ret == FunkinLua.Function_StopHScript) {
                returnVal = ret;
                break;
            }
            
            if(ret != FunkinLua.Function_Continue) {
                returnVal = ret;
            }
        }
        
        return returnVal;
    }
    
    public static function setOnGlobalScript(variable:String, arg:Dynamic) {
        for (script in globalScripts) {
            if (!script.closed) {
                script.set(variable, arg);
            }
        }
    }
    
    public static function cleanup() {
        for (script in globalScripts) {
            script.stop();
        }
        globalScripts = [];
        initialized = false;
    }
    
    public static function isHscriptFile(file:String):Bool {
        return file.endsWith('.hx') || file.endsWith('.hscript') || 
               file.endsWith('.hsc') || file.endsWith('.hxs');
    }

	public static var hscriptVersion:String = "0.1.2";
	public var __importedPaths:Array<String> = [];
    public var parser:Parser;
    public var scriptDir:String = '';
	public var modchartTexts:Map<String, FlxText> = new Map();
    public var modchartSprites:Map<String, FlxSprite> = new Map();
    public var modchartSounds:Map<String, FlxSound> = new Map();
	public var interp:Interp;
	public var scriptName:String = '';
	public var closed:Bool = false;
	public var scriptType:HScriptType = STATE;

	public var variables(get, never):Map<String, Dynamic>;

	public function get_variables()
	{
		return interp.variables;
	}
	public function set(variable:String, data:Dynamic):Void {
        if (closed) return;
        interp.variables.set(variable, data);
    }
	function handleError(e:Dynamic) {
        trace('HScript error: ' + e);
        #if windows
        if (!closed) lime.app.Application.current.window.alert(e, 'Error on hscript!');
		return;
        #end
    }

	public function new(?scriptPath:String = null)
	{
		interp = new Interp();
		parser = new Parser();
        parser.allowTypes = true;
        parser.allowJSON = true;
        
        if (scriptPath != null) {
            scriptDir = Path.directory(scriptPath);
            __importedPaths.push(scriptPath);
        }
        setupBasicVariables();

        if (scriptPath != null) {
            loadScriptFromPath(scriptPath);
        }
        call('onCreate', []);
	}	
	private function loadScriptFromPath(scriptPath:String) {
        try {
            var scriptContent:String = File.getContent(scriptPath);
            execute(scriptContent);
            trace('hscript file loaded successfully: $scriptPath');
            
            
        } catch (e:Dynamic) {
            handleError('Failed to load script: $e');
			#if windows
            lime.app.Application.current.window.alert('Failed to load script: $e', 'Error on hscript!');
            #end
			return;
        }
    }

	public function setupBasicVariables()
	{
		if (PlayState.instance != null){
		set('game', PlayState.instance);
        set('curBpm', Conductor.bpm);
        set('bpm', PlayState.SONG.bpm);
        set('scrollSpeed', PlayState.SONG.speed);
        set('crochet', Conductor.crochet);
        set('stepCrochet', Conductor.stepCrochet);
        set('songLength', FlxG.sound.music.length);
        set('songName', PlayState.SONG.song);
        set('songPath', Paths.formatToSongPath(PlayState.SONG.song));
        set('startedCountdown', false);
        set('curStage', PlayState.SONG.stage);
        set('compatibility_mode', ClientPrefs.data.compatibility_mode);
        set('isStoryMode', PlayState.isStoryMode);
        set('difficulty', PlayState.storyDifficulty);

        var difficultyName:String = CoolUtil.difficulties[PlayState.storyDifficulty];
        set('difficultyName', difficultyName);
        set('difficultyPath', Paths.formatToSongPath(difficultyName));
        set('weekRaw', PlayState.storyWeek);
        set('week', WeekData.weeksList[PlayState.storyWeek]);
        set('seenCutscene', PlayState.seenCutscene);
        
        set('boyfriend', PlayState.instance.boyfriend);
        set('dad', PlayState.instance.dad);
        set('gf', PlayState.instance.gf);
        set('camGame', PlayState.instance.camGame);
        set('camHUD', PlayState.instance.camHUD);
        set('camOther', PlayState.instance.camOther);

		// Gameplay settings
		set('healthGainMult', PlayState.instance.healthGain);
		set('healthLossMult', PlayState.instance.healthLoss);
		set('playbackRate', PlayState.instance.playbackRate);
		set('instakillOnMiss', PlayState.instance.instakillOnMiss);
		set('botPlay', PlayState.instance.cpuControlled);
		set('practice', PlayState.instance.practiceMode);
		set('luattf', ClientPrefs.data.luattf);
        set('addBehindGF', PlayState.instance.addBehindGF);
		set('addBehindDad', PlayState.instance.addBehindDad);
		set('addBehindBF', PlayState.instance.addBehindBF);

		set('setVar', function(name:String, value:Dynamic)
		{
			PlayState.instance.variables.set(name, value);
		});
		set('getVar', function(name:String)
		{
			var result:Dynamic = null;
			if(PlayState.instance.variables.exists(name)) result = PlayState.instance.variables.get(name);
			return result;
		});
		set('removeVar', function(name:String)
		{
			if(PlayState.instance.variables.exists(name))
			{
				PlayState.instance.variables.remove(name);
				return true;
			}
			return false;
		});
		}


		set('MusicBeatState', MusicBeatState);
		set('MusicBeatSubstate', MusicBeatSubstate);
		set('FreeplayState', FreeplayState);
		set('StoryMenuState', StoryMenuState);
		set('TitleState', TitleState);
		set('CreditsState', CreditsState);
		set('MainMenuState', MainMenuState);

        set('PlayState', PlayState);
        set('HScript', HScript);
		set('hsciptVersion', hscriptVersion);
		set('FlxG', flixel.FlxG);
		set('FlxMath', flixel.math.FlxMath);

		set("Math",	Math);
		set("Std", Std);
		set("StringTools", StringTools);
		set("Sys", Sys);
		set("Type", Type);
		set("Reflect", Reflect);
		set("Date", Date);
		set("DateTools", DateTools);
		set("Lambda", Lambda);
		set("EReg", EReg);
		set("Xml", Xml);
		set("Json", haxe.Json);

		set('FlxSprite', flixel.FlxSprite);
		set('FlxSpriteUtil', flixel.util.FlxSpriteUtil);
		set('FlxCamera', flixel.FlxCamera);
		set('FlxTimer', flixel.util.FlxTimer);
		set('FlxTween', flixel.tweens.FlxTween);
		set('FlxEase', flixel.tweens.FlxEase);
		set('FlxText', flixel.text.FlxText);
		set('FlxSound', flixel.sound.FlxSound);
		set('FlxGroup', flixel.group.FlxGroup);
		set('FlxTypedGroup', flixel.group.FlxTypedGroup);
		set('FlxSpriteGroup', flixel.group.FlxSpriteGroup);
		set('FlxStringUtil', flixel.util.FlxStringUtil);
		set('FlxAtlasFrames', flixel.graphics.frames.FlxAtlasFrames);	
        set('FlxColor', CustomFlxColor);

		set('Paths', Paths);
		set('Conductor', Conductor);
		set('ClientPrefs', ClientPrefs);
		set('Character', Character);
		set('Alphabet', Alphabet);
		set('CustomSubstate', CustomSubstate);
		#if (!flash && sys)
		set('FlxRuntimeShader', FlxRuntimeShader);
		#end
		set('ShaderFilter', openfl.filters.ShaderFilter);
        set('ColorMatrixFilter', openfl.filters.ColorMatrixFilter);
		set('StringTools', StringTools);

		set('this', this);

        set('FunkinText', FunkinText);
		
		set('importScript', function(path:String):Dynamic {
        if (closed) return null;
        
        try {

            var fullPath:String = path;
            if (!Path.isAbsolute(path)) {
                fullPath = Path.join([scriptDir, path]);
            }

            var foundPath:String = null;
            for (ext in ["hx", "hscript", "hsc", "hxs"]) {
                var testPath = '$fullPath.$ext';
                if (FileSystem.exists(testPath)) {
                    foundPath = testPath;
                    break;
                }
                
                var assetsPath = 'assets/$path.$ext';
                if (FileSystem.exists(assetsPath)) {
                    foundPath = assetsPath;
                    break;
                }
            }
            
            if (foundPath == null) {
                trace('HScript error: Could not find script file: $path');
                return null;
            }
            
            if (__importedPaths.contains(foundPath)) {
                trace('HScript: Script already imported: $foundPath');
                return null;
            }
            
            var scriptContent:String = File.getContent(foundPath);
            __importedPaths.push(foundPath);
            
            var oldScriptDir = scriptDir;
            scriptDir = Path.directory(foundPath);

            var result = execute(scriptContent);

            scriptDir = oldScriptDir;
            
            return result;
        } catch (e:Dynamic) {
            trace('HScript error importing script $path: ' + e);
            return null;
        }		
   	 });

		#if windows
		set('buildTarget', 'windows');
		#elseif linux
		set('buildTarget', 'linux');
		#elseif mac
		set('buildTarget', 'mac');
		#elseif html5
		set('buildTarget', 'browser');
		#elseif android
		set('buildTarget', 'android');
		#else
		set('buildTarget', 'unknown');
		#end
		set('customSubstate', CustomSubstate.instance);
		set('customSubstateName', CustomSubstate.name);

		set('Function_Stop', FunkinLua.Function_Stop);
		set('Function_Continue', FunkinLua.Function_Continue);
		set('Function_StopLua', FunkinLua.Function_StopLua);
		set('Function_StopHScript', FunkinLua.Function_StopHScript);
		set('Function_StopAll', FunkinLua.Function_StopAll);
		
		set('add', FlxG.state.add);
		set('insert', FlxG.state.insert);
		set('remove', FlxG.state.remove);

		set('luaDebugMode', false);
		set('luaDeprecatedWarnings', true);
		set('inChartEditor', false);

		set('language', ClientPrefs.data.language);
		set('screenWidth', FlxG.width);
		set('screenHeight', FlxG.height);
		set('version', MainMenuState.psychEngineVersion.trim());
        set('keyboardJustPressed', function(name:String) return Reflect.getProperty(FlxG.keys.justPressed, name));
        set('keyboardPressed', function(name:String) return Reflect.getProperty(FlxG.keys.pressed, name));
        set('keyboardReleased', function(name:String) return Reflect.getProperty(FlxG.keys.justReleased, name));

        set('anyGamepadJustPressed', function(name:String) return FlxG.gamepads.anyJustPressed(name));
        set('anyGamepadPressed', function(name:String) return FlxG.gamepads.anyPressed(name));
        set('anyGamepadReleased', function(name:String) return FlxG.gamepads.anyJustReleased(name));

        set('gamepadAnalogX', function(id:Int, ?leftStick:Bool = true)
        {
            var controller = FlxG.gamepads.getByID(id);
            if (controller == null) return 0.0;
            return controller.getXAxis(leftStick ? LEFT_ANALOG_STICK : RIGHT_ANALOG_STICK);
        });
        set('gamepadAnalogY', function(id:Int, ?leftStick:Bool = true)
        {
            var controller = FlxG.gamepads.getByID(id);
            if (controller == null) return 0.0;
            return controller.getYAxis(leftStick ? LEFT_ANALOG_STICK : RIGHT_ANALOG_STICK);
        });
        set('gamepadJustPressed', function(id:Int, name:String)
        {
            var controller = FlxG.gamepads.getByID(id);
            if (controller == null) return false;
            return Reflect.getProperty(controller.justPressed, name) == true;
        });
        set('gamepadPressed', function(id:Int, name:String)
        {
            var controller = FlxG.gamepads.getByID(id);
            if (controller == null) return false;
            return Reflect.getProperty(controller.pressed, name) == true;
        });
        set('gamepadReleased', function(id:Int, name:String)
        {
            var controller = FlxG.gamepads.getByID(id);
            if (controller == null) return false;
            return Reflect.getProperty(controller.justReleased, name) == true;
        });

        set('keyJustPressed', function(name:String) {
			var key:Bool = false;
			switch(name) {
				case 'left': key = PlayState.instance.getControl('NOTE_LEFT_P');
				case 'down': key = PlayState.instance.getControl('NOTE_DOWN_P');
				case 'up': key = PlayState.instance.getControl('NOTE_UP_P');
				case 'right': key = PlayState.instance.getControl('NOTE_RIGHT_P');
				case 'accept': key = PlayState.instance.getControl('ACCEPT');
				case 'back': key = PlayState.instance.getControl('BACK');
				case 'pause': key = PlayState.instance.getControl('PAUSE');
				case 'reset': key = PlayState.instance.getControl('RESET');
				case 'space': key = FlxG.keys.justPressed.SPACE;//an extra key for convinience
			}
			return key;
		});
        set('keyPressed', function(name:String) {
			var key:Bool = false;
			switch(name) {
				case 'left': key = PlayState.instance.getControl('NOTE_LEFT');
				case 'down': key = PlayState.instance.getControl('NOTE_DOWN');
				case 'up': key = PlayState.instance.getControl('NOTE_UP');
				case 'right': key = PlayState.instance.getControl('NOTE_RIGHT');
				case 'space': key = FlxG.keys.pressed.SPACE;//an extra key for convinience
			}
			return key;
		});
        set('keyReleased',  function(name:String) {
			var key:Bool = false;
			switch(name) {
				case 'left': key = PlayState.instance.getControl('NOTE_LEFT_R');
				case 'down': key = PlayState.instance.getControl('NOTE_DOWN_R');
				case 'up': key = PlayState.instance.getControl('NOTE_UP_R');
				case 'right': key = PlayState.instance.getControl('NOTE_RIGHT_R');
				case 'space': key = FlxG.keys.justReleased.SPACE;//an extra key for convinience
			}
			return key;
		});
    }

		public function execute(codeToRun:String):Dynamic
	{
		if (closed) return FunkinLua.Function_StopHScript;
		
		try {
			@:privateAccess
			parser.line = 1;
			parser.allowTypes = true;
			return interp.execute(parser.parseString(codeToRun));
		} catch (e:Dynamic) {
			trace('HScript error: ' + e);
			return FunkinLua.Function_StopHScript;
		}
	}

		public function call(func:String, args:Array<Dynamic>):Dynamic
	{
		if (closed) return FunkinLua.Function_StopHScript;
		
		try {
			if (interp.variables.exists(func))
			{
				var f:Dynamic = interp.variables.get(func);
				if (Reflect.isFunction(f))
				{
					return Reflect.callMethod(null, f, args);
				}
			}
		} catch (e:Dynamic) {
			trace('HScript error calling $func: ' + e);
		}
		return FunkinLua.Function_Continue;
	}

    
    public function get(variable:String):Dynamic {
        if (closed) return null;
        return interp.variables.get(variable);
    }
    
    public function exists(variable:String):Bool {
        if (closed) return false;
        return interp.variables.exists(variable);
    }
    
    public function stop():Void {
        if (closed) return;
        
        closed = true;

        cleanupModchartObjects();
        
        interp = null;
        parser = null;
    }
    
    private function cleanupModchartObjects() {
        for (tag in modchartTexts.keys()) {
            var text:FlxText = modchartTexts.get(tag);
            if (text != null) {
                if (PlayState.instance != null) PlayState.instance.remove(text, true);
                text.destroy();
            }
        }
        modchartTexts.clear();

        for (tag in modchartSprites.keys()) {
            var sprite:FlxSprite = modchartSprites.get(tag);
            if (sprite != null) {
                if (PlayState.instance != null) PlayState.instance.remove(sprite, true);
                sprite.destroy();
            }
        }
        modchartSprites.clear();

        for (tag in modchartSounds.keys()) {
            var sound:FlxSound = modchartSounds.get(tag);
            if (sound != null) {
                sound.stop();
                sound.destroy();
            }
        }
        modchartSounds.clear();
    }

    
}

class CustomFlxColor {
	public static var TRANSPARENT(default, null):Int = FlxColor.TRANSPARENT;
	public static var BLACK(default, null):Int = FlxColor.BLACK;
	public static var WHITE(default, null):Int = FlxColor.WHITE;
	public static var GRAY(default, null):Int = FlxColor.GRAY;

	public static var GREEN(default, null):Int = FlxColor.GREEN;
	public static var LIME(default, null):Int = FlxColor.LIME;
	public static var YELLOW(default, null):Int = FlxColor.YELLOW;
	public static var ORANGE(default, null):Int = FlxColor.ORANGE;
	public static var RED(default, null):Int = FlxColor.RED;
	public static var PURPLE(default, null):Int = FlxColor.PURPLE;
	public static var BLUE(default, null):Int = FlxColor.BLUE;
	public static var BROWN(default, null):Int = FlxColor.BROWN;
	public static var PINK(default, null):Int = FlxColor.PINK;
	public static var MAGENTA(default, null):Int = FlxColor.MAGENTA;
	public static var CYAN(default, null):Int = FlxColor.CYAN;

	public static function fromInt(Value:Int):Int 
	{
		return cast FlxColor.fromInt(Value);
	}

	public static function fromRGB(Red:Int, Green:Int, Blue:Int, Alpha:Int = 255):Int
	{
		return cast FlxColor.fromRGB(Red, Green, Blue, Alpha);
	}
	public static function fromRGBFloat(Red:Float, Green:Float, Blue:Float, Alpha:Float = 1):Int
	{	
		return cast FlxColor.fromRGBFloat(Red, Green, Blue, Alpha);
	}

	public static inline function fromCMYK(Cyan:Float, Magenta:Float, Yellow:Float, Black:Float, Alpha:Float = 1):Int
	{
		return cast FlxColor.fromCMYK(Cyan, Magenta, Yellow, Black, Alpha);
	}

	public static function fromHSB(Hue:Float, Sat:Float, Brt:Float, Alpha:Float = 1):Int
	{	
		return cast FlxColor.fromHSB(Hue, Sat, Brt, Alpha);
	}
	public static function fromHSL(Hue:Float, Sat:Float, Light:Float, Alpha:Float = 1):Int
	{	
		return cast FlxColor.fromHSL(Hue, Sat, Light, Alpha);
	}
	public static function fromString(str:String):Int
	{
		return cast FlxColor.fromString(str);
	}
}
#end