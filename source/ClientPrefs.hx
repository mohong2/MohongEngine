package;


import flixel.util.FlxSave;
import flixel.input.keyboard.FlxKey;
import flixel.graphics.FlxGraphic;
import Controls;
import flixel.input.gamepad.FlxGamepadInputID;
#if sys
import sys.io.Process;
#end

@:structInit class SaveVariables{
	public var arrowRGB:Array<Array<FlxColor>> = [
		[0xFFC24B99, 0xFFFFFFFF, 0xFF3C1F56],
		[0xFF00FFFF, 0xFFFFFFFF, 0xFF1542B7],
		[0xFF12FA05, 0xFFFFFFFF, 0xFF0A4447],
		[0xFFF9393F, 0xFFFFFFFF, 0xFF651038]];
	public var arrowRGBPixel:Array<Array<FlxColor>> = [
		[0xFFE276FF, 0xFFFFF9FF, 0xFF60008D],
		[0xFF3DCAFF, 0xFFF4FFFF, 0xFF003060],
		[0xFF71E300, 0xFFF6FFE6, 0xFF003100],
		[0xFFFF884E, 0xFFFFFAF5, 0xFF6C0000]];
	public var noteSkin:String = 'Default';
	public var splashSkin:String = 'Psych';

	public var modSettings:Map<String, Map<String, Dynamic>> = new Map();

	public var keyboardAlpha:Float = 0.8;
	public var keyboardTimeDisplay:Bool = true;
	public var keyboardTime:Float = 500;
	public var keyboardBGColor:String = 'WHITE';
	public var keyboardTextColor:String = 'BLACK';
	public var keyboardDisplay:Bool = false;
	public var hitboxPos:Bool = true;
	public var hitboxType:String = "No Gradient";
	public var mobileCAlpha:Float = 0.6;
	public var mobileCEx:Bool = false;
	public var downScroll:Bool = false;
	public var middleScroll:Bool = false;
	public var opponentStrums:Bool = true;
	public var showFPS:Bool = true;
	public var flashing:Bool = true;
	public var globalAntialiasing:Bool = true;
	public var noteSplashes:Bool = true;
	public var lowQuality:Bool = false;
	public var shaders:Bool = true;
	public var framerate:Int = 60;
	public var cursing:Bool = true;
	public var violence:Bool = true;
	public var camZooms:Bool = true;
	public var hideHud:Bool = false;
	public var noteOffset:Int = 0;
	public var arrowHSV:Array<Array<Int>> = [[0, 0, 0], [0, 0, 0], [0, 0, 0], [0, 0, 0]];
	public var ghostTapping:Bool = true;
	public var timeBarType:String = 'Time Left';
	public var scoreZoom:Bool = true;
	public var noReset:Bool = false;
	public var healthBarAlpha:Float = 1;
	public var controllerMode:Bool = #if !android false #else true #end;
	public var hitsoundVolume:Float = 0;
	public var trackAlpha:Float = 0;
	public var pauseMusic:String = 'Tea Time';
	public var checkForUpdates:Bool = true;
	public var comboStacking = false;
	public var language:String = "English";
	public var oldmodsmenu:Bool = false;
	public var sidehud:Bool = true;
	public var luattf:String = "Default TTF";
	public var doublebetbf:Bool = true;
	public var doublebetdad:Bool = true;
	public var opponentfe:Bool = true;
	public var currentFont:String = "vcr.ttf"; 
	public var windowedmode:String = "windowed";
	public var compatibility_mode:Bool = false; 
	public var guitarHeroSustains:Bool = false; 
	public var smoothhpbar:Bool = false; 
	public var unnotec:Bool = false;
	public var cacheOnGPU:Bool = false; 
	public var splashAlpha:Float = 0.6;
	public var autoPause:Bool = true;
	public var gameplaySettings:Map<String, Dynamic> = [
		'scrollspeed' => 1.0,
		'scrolltype' => 'multiplicative', 
		'songspeed' => 1.0,
		'healthgain' => 1.0,
		'healthloss' => 1.0,
		'instakill' => false,
		'practice' => false,
		'botplay' => false,
		'opponentplay' => false
	];
	public var comboOffset:Array<Int> = [0, 0, 0, 0, 530, 470, 520, 350];
	public var ratingOffset:Int = 0;
	public var sickWindow:Int = 45;
	public var goodWindow:Int = 90;
	public var badWindow:Int = 130;
	public var safeFrames:Float = 10;
}

class ClientPrefs {
	public static var data:SaveVariables = {};
	public static var defaultData:SaveVariables = {};

	public static var arrowRGB(get, never):Array<Array<FlxColor>>;
	public static var arrowRGBPixel(get, never):Array<Array<FlxColor>>;
	public static var noteSkin(get, never):String;
	public static var splashSkin(get, never):String;
	public static var modSettings(get, never):Map<String, Map<String, Dynamic>>;
	public static var keyboardAlpha(get, never):Float;
	public static var keyboardTimeDisplay(get, never):Bool;
	public static var keyboardTime(get, never):Float;
	public static var keyboardBGColor(get, never):String;
	public static var keyboardTextColor(get, never):String;
	public static var keyboardDisplay(get, never):Bool;
	public static var hitboxPos(get, never):Bool;
	public static var hitboxType(get, never):String;
	public static var mobileCAlpha(get, never):Float;
	public static var mobileCEx(get, never):Bool;
	public static var downScroll(get, never):Bool;
	public static var middleScroll(get, never):Bool;
	public static var opponentStrums(get, never):Bool;
	public static var showFPS(get, never):Bool;
	public static var flashing(get, never):Bool;
	public static var globalAntialiasing(get, never):Bool;
	public static var noteSplashes(get, never):Bool;
	public static var lowQuality(get, never):Bool;
	public static var shaders(get, never):Bool;
	public static var framerate(get, never):Int;
	public static var cursing(get, never):Bool;
	public static var violence(get, never):Bool;
	public static var camZooms(get, never):Bool;
	public static var hideHud(get, never):Bool;
	public static var noteOffset(get, never):Int;
	public static var arrowHSV(get, never):Array<Array<Int>>;
	public static var ghostTapping(get, never):Bool;
	public static var timeBarType(get, never):String;
	public static var scoreZoom(get, never):Bool;
	public static var noReset(get, never):Bool;
	public static var healthBarAlpha(get, never):Float;
	public static var controllerMode(get, never):Bool;
	public static var hitsoundVolume(get, never):Float;
	public static var trackAlpha(get, never):Float;
	public static var pauseMusic(get, never):String;
	public static var checkForUpdates(get, never):Bool;
	public static var comboStacking(get, never):Bool;
	public static var language(get, never):String;
	public static var oldmodsmenu(get, never):Bool;
	public static var sidehud(get, never):Bool;
	public static var luattf(get, never):String;
	public static var doublebetbf(get, never):Bool;
	public static var doublebetdad(get, never):Bool;
	public static var opponentfe(get, never):Bool;
	public static var currentFont(get, never):String;
	public static var windowedmode(get, never):String;
	public static var compatibility_mode(get, never):Bool;
	public static var guitarHeroSustains(get, never):Bool;
	public static var smoothhpbar(get, never):Bool;
	public static var unnotec(get, never):Bool;
	public static var cacheOnGPU(get, never):Bool;
	public static var splashAlpha(get, never):Float;
	public static var autoPause(get, never):Bool;
	public static var gameplaySettings(get, never):Map<String, Dynamic>;
	public static var comboOffset(get, never):Array<Int>;
	public static var ratingOffset(get, never):Int;
	public static var sickWindow(get, never):Int;
	public static var goodWindow(get, never):Int;
	public static var badWindow(get, never):Int;
	public static var safeFrames(get, never):Float;
	
	static inline function get_arrowRGB() return data.arrowRGB;
	static inline function get_arrowRGBPixel() return data.arrowRGBPixel;
	static inline function get_noteSkin() return data.noteSkin;
	static inline function get_splashSkin() return data.splashSkin;
	static inline function get_modSettings() return data.modSettings;
	static inline function get_keyboardAlpha() return data.keyboardAlpha;
	static inline function get_keyboardTimeDisplay() return data.keyboardTimeDisplay;
	static inline function get_keyboardTime() return data.keyboardTime;
	static inline function get_keyboardBGColor() return data.keyboardBGColor;
	static inline function get_keyboardTextColor() return data.keyboardTextColor;
	static inline function get_keyboardDisplay() return data.keyboardDisplay;
	static inline function get_hitboxPos() return data.hitboxPos;
	static inline function get_hitboxType() return data.hitboxType;
	static inline function get_mobileCAlpha() return data.mobileCAlpha;
	static inline function get_mobileCEx() return data.mobileCEx;
	static inline function get_downScroll() return data.downScroll;
	static inline function get_middleScroll() return data.middleScroll;
	static inline function get_opponentStrums() return data.opponentStrums;
	static inline function get_showFPS() return data.showFPS;
	static inline function get_flashing() return data.flashing;
	static inline function get_globalAntialiasing() return data.globalAntialiasing;
	static inline function get_noteSplashes() return data.noteSplashes;
	static inline function get_lowQuality() return data.lowQuality;
	static inline function get_shaders() return data.shaders;
	static inline function get_framerate() return data.framerate;
	static inline function get_cursing() return data.cursing;
	static inline function get_violence() return data.violence;
	static inline function get_camZooms() return data.camZooms;
	static inline function get_hideHud() return data.hideHud;
	static inline function get_noteOffset() return data.noteOffset;
	static inline function get_arrowHSV() return data.arrowHSV;
	static inline function get_ghostTapping() return data.ghostTapping;
	static inline function get_timeBarType() return data.timeBarType;
	static inline function get_scoreZoom() return data.scoreZoom;
	static inline function get_noReset() return data.noReset;
	static inline function get_healthBarAlpha() return data.healthBarAlpha;
	static inline function get_controllerMode() return data.controllerMode;
	static inline function get_hitsoundVolume() return data.hitsoundVolume;
	static inline function get_trackAlpha() return data.trackAlpha;
	static inline function get_pauseMusic() return data.pauseMusic;
	static inline function get_checkForUpdates() return data.checkForUpdates;
	static inline function get_comboStacking() return data.comboStacking;
	static inline function get_language() return data.language;
	static inline function get_oldmodsmenu() return data.oldmodsmenu;
	static inline function get_sidehud() return data.sidehud;
	static inline function get_luattf() return data.luattf;
	static inline function get_doublebetbf() return data.doublebetbf;
	static inline function get_doublebetdad() return data.doublebetdad;
	static inline function get_opponentfe() return data.opponentfe;
	static inline function get_currentFont() return data.currentFont;
	static inline function get_windowedmode() return data.windowedmode;
	static inline function get_compatibility_mode() return data.compatibility_mode;
	static inline function get_guitarHeroSustains() return data.guitarHeroSustains;
	static inline function get_smoothhpbar() return data.smoothhpbar;
	static inline function get_unnotec() return data.unnotec;
	static inline function get_cacheOnGPU() return data.cacheOnGPU;
	static inline function get_splashAlpha() return data.splashAlpha;
	static inline function get_autoPause() return data.autoPause;
	static inline function get_gameplaySettings() return data.gameplaySettings;
	static inline function get_comboOffset() return data.comboOffset;
	static inline function get_ratingOffset() return data.ratingOffset;
	static inline function get_sickWindow() return data.sickWindow;
	static inline function get_goodWindow() return data.goodWindow;
	static inline function get_badWindow() return data.badWindow;
	static inline function get_safeFrames() return data.safeFrames;

	public static var keyBinds:Map<String, Array<FlxKey>> = [
		//Key Bind, Name for ControlsSubState
		'note_left'		=> [A, LEFT],
		'note_down'		=> [S, DOWN],
		'note_up'		=> [W, UP],
		'note_right'	=> [D, RIGHT],
		
		'ui_left'		=> [A, LEFT],
		'ui_down'		=> [S, DOWN],
		'ui_up'			=> [W, UP],
		'ui_right'		=> [D, RIGHT],
		
		'accept'		=> [SPACE, ENTER],
		'back'			=> [BACKSPACE, ESCAPE],
		'pause'			=> [ENTER, ESCAPE],
		'reset'			=> [R, NONE],
		
		'volume_mute'	=> [ZERO, NONE],
		'volume_up'		=> [NUMPADPLUS, PLUS],
		'volume_down'	=> [NUMPADMINUS, MINUS],
		
		'debug_1'		=> [SEVEN, NONE],
		'debug_2'		=> [EIGHT, NONE]
	];
	public static var defaultKeys:Map<String, Array<FlxKey>> = null;

	public static function loadDefaultKeys()
	{
		defaultKeys = keyBinds.copy();
	}

	public static function saveSettings()
	{
		for (key in Reflect.fields(data))
			Reflect.setField(FlxG.save.data, key, Reflect.field(data, key));

		FlxG.save.flush();

		// Placing this in a separate save so that it can be manually deleted without removing your Score and stuff
		var save:FlxSave = new FlxSave();
		save.bind('controls_v2', 'ninjamuffin99');
		save.data.keyboard = keyBinds;
		save.flush();
		FlxG.log.add("Settings saved!");
	}


	public static function loadPrefs() {
		for (key in Reflect.fields(data))
			if (key != 'gameplaySettings' && Reflect.hasField(FlxG.save.data, key))
				Reflect.setField(data, key, Reflect.field(FlxG.save.data, key));

		if (Main.fpsVar != null)
			Main.fpsVar.visible = data.showFPS;

		#if (!html5 && !switch)
		FlxG.autoPause = ClientPrefs.data.autoPause;

		if (FlxG.save.data.framerate == null) {
			final refreshRate:Int = FlxG.stage.application.window.displayMode.refreshRate;
			data.framerate = Std.int(FlxMath.bound(refreshRate, 60, 240));
		}
		#end

		if (data.framerate > FlxG.drawFramerate) {
			FlxG.updateFramerate = data.framerate;
			FlxG.drawFramerate = data.framerate;
		} else {
			FlxG.drawFramerate = data.framerate;
			FlxG.updateFramerate = data.framerate;
		}

		if (FlxG.save.data.gameplaySettings != null) {
			var savedMap:Map<String, Dynamic> = FlxG.save.data.gameplaySettings;
			for (name => value in savedMap)
				data.gameplaySettings.set(name, value);
		}

		// flixel automatically saves your volume!
		if (FlxG.save.data.volume != null)
			FlxG.sound.volume = FlxG.save.data.volume;
		if (FlxG.save.data.mute != null)
			FlxG.sound.muted = FlxG.save.data.mute;

		#if DISCORD_ALLOWED
		DiscordClient.check();
		#end
		var save:FlxSave = new FlxSave();
		save.bind('controls_v2', 'ninjamuffin99');
		if(save != null && save.data.customControls != null) {
			var loadedControls:Map<String, Array<FlxKey>> = save.data.customControls;
			for (control => keys in loadedControls) {
				keyBinds.set(control, keys);
			}
			reloadControls();
		}
	}

	inline public static function getGameplaySetting(name:String, defaultValue:Dynamic = null, ?customDefaultValue:Bool = false):Dynamic {
		if (!customDefaultValue)
			defaultValue = defaultData.gameplaySettings.get(name);
		return (data.gameplaySettings.exists(name) ? data.gameplaySettings.get(name) : defaultValue);
	}


	public static function reloadControls() {
		PlayerSettings.player1.controls.setKeyboardScheme(KeyboardScheme.Solo);

		TitleState.muteKeys = copyKey(keyBinds.get('volume_mute'));
		TitleState.volumeDownKeys = copyKey(keyBinds.get('volume_down'));
		TitleState.volumeUpKeys = copyKey(keyBinds.get('volume_up'));
		FlxG.sound.muteKeys = TitleState.muteKeys;
		FlxG.sound.volumeDownKeys = TitleState.volumeDownKeys;
		FlxG.sound.volumeUpKeys = TitleState.volumeUpKeys;
	}
	
	public static function copyKey(arrayToCopy:Array<FlxKey>):Array<FlxKey> {
		var copiedArray:Array<FlxKey> = arrayToCopy.copy();
		var i:Int = 0;
		var len:Int = copiedArray.length;

		while (i < len) {
			if(copiedArray[i] == NONE) {
				copiedArray.remove(NONE);
				--i;
			}
			i++;
			len = copiedArray.length;
		}
		return copiedArray;
	}
}