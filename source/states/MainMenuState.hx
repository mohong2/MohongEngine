package states;

import backend.seiun.ui.*;
import script.lua.FunkinLua;
import options.OptionsState;
import substates.ModSelectSubstate;
import states.ModState;
import backend.ModConfig;
#if cpp
import Discord.DiscordClient;
#end
import flixel.FlxObject;
import flixel.addons.transition.FlxTransitionableState;
import flixel.effects.FlxFlicker;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.tweens.FlxEase.EaseFunction;
import lime.app.Application;
import Achievements;
import editors.MasterEditorMenu;
import mohong.TraceManager;
import haxe.Json;
import flixel.input.keyboard.FlxKey;
#if MODS_ALLOWED
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

class MainMenuState extends MusicBeatState
{
	public static var seiunengineVersion:String = '0.2.1'; 
	public static var psychEngineVersion:String = '0.6.4';
	public static var curSelected:Int = 0;

	public var menuItems:FlxTypedGroup<FlxSprite>;
	public var camGame:FlxCamera;
	public var camAchievement:FlxCamera;

	public var optionShit:Array<String> = [
		'story_mode',
		'freeplay',
		#if MODS_ALLOWED 'mods', #end
		#if ACHIEVEMENTS_ALLOWED 'awards', #end
		'credits',
		#if !switch 'donate', #end
		'options'
	];

	public var bg:FlxSprite;
	public var magenta:FlxSprite;
	public var camFollow:FlxObject;
	public var camFollowPos:FlxObject;
	public var debugKeys:Array<FlxKey>;
	public var mouseOverlapIndex = -1;
	public static var instance:MainMenuState;

	// === Mod Selection (persists across state transitions) ===
	public static var selectedModFolder:String = '';

	var currentModText:FlxText;
	var pendingModIndex:Int = -1;
	var pendingModRestart:Bool = false;
	
	override function create()
	{
		instance = this;

		#if MODS_ALLOWED
		loadActiveMod();
		Paths.pushGlobalMods();
		// Use the user-selected mod folder (from ModSelectSubstate), default to vanilla
		Paths.currentModDirectory = selectedModFolder;
		// Apply mod pack.json config: window title, state/substate replacements
		ModState.applyModPackConfig(selectedModFolder);
		#end
		FlxG.mouse.visible = true;
		#if cpp
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Menus", null);
		#end
		debugKeys = ClientPrefs.copyKey(ClientPrefs.keyBinds.get('debug_1'));
		FlxG.keys.preventDefaultKeys.remove(TAB);

		camGame = new FlxCamera();
		camAchievement = new FlxCamera();
		camAchievement.bgColor.alpha = 0;

		FlxG.cameras.reset(camGame);
		FlxG.cameras.add(camAchievement, false);
		FlxG.cameras.setDefaultDrawTarget(camGame, true);

		transIn = FlxTransitionableState.defaultTransIn;
		transOut = FlxTransitionableState.defaultTransOut;

		persistentUpdate = persistentDraw = true;

		var yScroll:Float = Math.max(0.25 - (0.05 * (optionShit.length - 4)), 0.1);
		bg = new FlxSprite(-80).loadGraphic(Paths.image('menuBG'));
		bg.scrollFactor.set(0, yScroll);
		bg.setGraphicSize(Std.int(bg.width * 1.175));
		bg.updateHitbox();
		bg.screenCenter();
		bg.antialiasing = ClientPrefs.data.globalAntialiasing;
		add(bg);

		camFollow = new FlxObject(0, 0, 1, 1);
		camFollowPos = new FlxObject(0, 0, 1, 1);
		add(camFollow);
		add(camFollowPos);

		magenta = new FlxSprite(-80).loadGraphic(Paths.image('menuDesat'));
		magenta.scrollFactor.set(0, yScroll);
		magenta.setGraphicSize(Std.int(magenta.width * 1.175));
		magenta.updateHitbox();
		magenta.screenCenter();
		magenta.visible = false;
		magenta.antialiasing = ClientPrefs.data.globalAntialiasing;
		magenta.color = 0xFFfd719b;
		add(magenta);
		


		menuItems = new FlxTypedGroup<FlxSprite>();
		add(menuItems);

		var scale:Float = 1;
		/*if(optionShit.length > 6) {
			scale = 6 / optionShit.length;
		}*/

		for (i in 0...optionShit.length)
		{
			var offset:Float = 108 - (Math.max(optionShit.length, 4) - 4) * 80;
			var menuItem:FlxSprite = new FlxSprite(0, (i * 140)  + offset);
			menuItem.scale.x = scale;
			menuItem.scale.y = scale;
			menuItem.frames = Paths.getSparrowAtlas('mainmenu/menu_' + optionShit[i]);
			menuItem.animation.addByPrefix('idle', optionShit[i] + " basic", 24);
			menuItem.animation.addByPrefix('selected', optionShit[i] + " white", 24);
			menuItem.animation.play('idle');
			menuItem.ID = i;
			menuItems.add(menuItem);
			var scr:Float = (optionShit.length - 4) * 0.135;
			if(optionShit.length < 6) scr = 0;
			menuItem.scrollFactor.set(0, scr);
			menuItem.antialiasing = ClientPrefs.data.globalAntialiasing;
			menuItem.updateHitbox();
			
			var leftMargin = 100; 
			menuItem.x = leftMargin;
		}

		FlxG.camera.follow(camFollowPos, null, 1);
		var versionShitx = 1000;
		
		var versionShit:FlxText = new FlxText(versionShitx, FlxG.height - 64, 0, "Seiun Engine v" + seiunengineVersion, 12);
		versionShit.scrollFactor.set();
		versionShit.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(versionShit);
		var versionShit:FlxText = new FlxText(versionShitx, FlxG.height - 44, 0, "Psych Engine v" + psychEngineVersion, 12);
		versionShit.scrollFactor.set();
		versionShit.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(versionShit);
		var versionShit:FlxText = new FlxText(versionShitx, FlxG.height - 24, 0, "Friday Night Funkin' v" + Application.current.meta.get('version'), 12);
		versionShit.scrollFactor.set();
		versionShit.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(versionShit);

		var hscriptversionShit:FlxText = new FlxText(versionShitx + 20, FlxG.height - 704, 0, "Hscript version: " + HScript.hscriptVersion, 12);
		hscriptversionShit.scrollFactor.set();
		hscriptversionShit.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(hscriptversionShit);

		var luaversionShit:FlxText = new FlxText(versionShitx + 20, FlxG.height - 684, 0, "Lua version: " + FunkinLua.luaversion, 12);
		luaversionShit.scrollFactor.set();
		luaversionShit.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(luaversionShit);

		// === Active mod indicator ===
		currentModText = new FlxText(5, FlxG.height - 24, 0, "", 16);
		currentModText.scrollFactor.set();
		currentModText.setFormat(Paths.languageFont(), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		currentModText.borderSize = 1;
		add(currentModText);

		// Ensure menu music is playing (may not be if TitleState was replaced)
		if (FlxG.sound.music == null)
			FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);

		// NG.core.calls.event.logEvent('swag').send();

		changeItem();

		#if ACHIEVEMENTS_ALLOWED
		Achievements.loadAchievements();
		var leDate = Date.now();
		if (leDate.getDay() == 5 && leDate.getHours() >= 18) {
			var achieveID:Int = Achievements.getAchievementIndex('friday_night_play');
			if(!Achievements.isAchievementUnlocked(Achievements.achievementsStuff[achieveID][2])) { //It's a friday night. WEEEEEEEEEEEEEEEEEE
				Achievements.achievementsMap.set(Achievements.achievementsStuff[achieveID][2], true);
				giveAchievement();
				ClientPrefs.saveSettings();
			}
		}
		#end
		#if android
		addVirtualPad(UP_DOWN, A_B_C);
		#end
		super.create();

		// Language is now loaded (by MusicBeatState.create), safe to use translations
		// Re-set font because languageFont() now returns the correct language-specific font
		currentModText.setFormat(Paths.languageFont(), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		updateActiveModText();

		#if LUA_ALLOWED
		initLuaScripts();
		setOnLuas('controls', controls);
		setOnLuas('state', this);
		callOnLuas('onCreatePost', []);
		#end
	}

	#if ACHIEVEMENTS_ALLOWED
	// Unlocks "Freaky on a Friday Night" achievement
	function giveAchievement() {
		add(new AchievementObject('friday_night_play', camAchievement));
		FlxG.sound.play(Paths.sound('confirmMenu'), 0.7);
		TraceManager.info('trace.mainMenu.giveAchievement', 'Giving achievement "friday_night_play"');
	}
	#end

	var selectedSomethin:Bool = false;

	override function update(elapsed:Float)
	{
		#if LUA_ALLOWED
		callOnLuas('onUpdate', [elapsed]);
		#end
		#if HSCRIPT_ALLOWED
		callOnHscript('onUpdate', [elapsed]);
		#end
		// Handle deferred mod restart (from ModSelectSubstate selection)
		if (pendingModRestart)
		{
			pendingModRestart = false;
			FlxG.sound.music.fadeOut(0.3);
			TitleState.initialized = false;
			TitleState.closedState = false;
			FlxG.camera.fade(FlxColor.BLACK, 0.5, false, FlxG.resetGame, false);
			return;
		}

		if (FlxG.sound.music != null && FlxG.sound.music.volume < 0.8)
		{
			FlxG.sound.music.volume += 0.5 * FlxG.elapsed;
			if(FreeplayState.vocals != null) FreeplayState.vocals.volume += 0.5 * elapsed;
		}

		var lerpVal:Float = CoolUtil.boundTo(elapsed * 7.5, 0, 1);
		camFollowPos.setPosition(FlxMath.lerp(camFollowPos.x, camFollow.x, lerpVal), FlxMath.lerp(camFollowPos.y, camFollow.y, lerpVal));
		var newMouseOverlapIndex = -1;
		for (item in menuItems) {
			if (FlxG.mouse.overlaps(item)) {
				newMouseOverlapIndex = item.ID;
				break;
			}
		}
		if (FlxG.mouse.wheel != 0 && !selectedSomethin) {
        FlxG.sound.play(Paths.sound('scrollMenu'));
        changeItem(-FlxG.mouse.wheel);
    	}

		if (mouseOverlapIndex != newMouseOverlapIndex) {
			if (mouseOverlapIndex >= 0 && mouseOverlapIndex != curSelected) {
				menuItems.members[mouseOverlapIndex].animation.play('idle');
			}
			
			if (newMouseOverlapIndex >= 0 && newMouseOverlapIndex != curSelected) {
				menuItems.members[newMouseOverlapIndex].animation.play('selected');
			}
			
			mouseOverlapIndex = newMouseOverlapIndex;
		}
		if (FlxG.mouse.justPressed && mouseOverlapIndex >= 0 && mouseOverlapIndex != curSelected) {
			curSelected = mouseOverlapIndex;
			changeItem(0);
			FlxG.sound.play(Paths.sound('scrollMenu'));
		}
		if (!selectedSomethin)
		{
			if (controls.UI_UP_P)
			{
				FlxG.sound.play(Paths.sound('scrollMenu'));
				changeItem(-1);
			}

			if (controls.UI_DOWN_P)
			{
				FlxG.sound.play(Paths.sound('scrollMenu'));
				changeItem(1);
			}

			if (controls.BACK)
			{
				selectedSomethin = true;
				FlxG.sound.play(Paths.sound('cancelMenu'));
				MusicBeatState.switchState(new TitleState());
			}

			// TAB to open mod selection (when there are mods installed)
			#if MODS_ALLOWED
			if (FlxG.keys.justPressed.TAB && !selectedSomethin)
			{
				openModSelectSubstate();
			}
			#end

			if (FlxG.mouse.justPressed && mouseOverlapIndex == curSelected && !selectedSomethin || controls.ACCEPT) {
				if (optionShit[curSelected] == 'donate') {
					CoolUtil.browserLoad('https://ninja-muffin24.itch.io/funkin');
				} else {
					selectedSomethin = true;
					FlxG.sound.play(Paths.sound('confirmMenu'));
					
					if(ClientPrefs.data.flashing) FlxFlicker.flicker(magenta, 1.1, 0.15, false);
					
					menuItems.forEach(function(spr:FlxSprite) {
						if (curSelected != spr.ID) {
							FlxTween.tween(spr, {
								alpha: 0,
								x: spr.x - 500 
							}, 0.4, {
								ease: FlxEase.quadOut,
								onComplete: function(twn:FlxTween) { spr.kill(); }
							});
						} else {
							FlxFlicker.flicker(spr, 1, 0.06, false, false, function(flick:FlxFlicker) {
								var daChoice:String = optionShit[curSelected];
								
								switch (daChoice) {
									case 'story_mode':
										MusicBeatState.switchState(new StoryMenuState());
									case 'freeplay':
										MusicBeatState.switchState(new FreeplayState());
									#if MODS_ALLOWED
									case 'mods':
										if(!ClientPrefs.data.oldmodsmenu)
										MusicBeatState.switchState(new ModsMenuState());
										else
										MusicBeatState.switchState(new ModsMenuStateOld());
									#end
									case 'awards':
										MusicBeatState.switchState(new AchievementsMenuState());
									case 'credits':
										MusicBeatState.switchState(new CreditsState());
									case 'options':
										LoadingState.loadAndSwitchState(new options.OptionsState());
										OptionsState.onPlayState = false;
								}
							});
						}
					});
				}
			}
			else if (#if android virtualPad.buttonC.justPressed ||	#end FlxG.keys.anyJustPressed(debugKeys))
			{
				selectedSomethin = true;
				MusicBeatState.switchState(new MasterEditorMenu());
			}
		}

		super.update(elapsed);

		#if LUA_ALLOWED
		callOnLuas('onUpdatePost', [elapsed]);
		#end
		#if HSCRIPT_ALLOWED
		callOnHscript('onUpdatePost', [elapsed]);
		#end
	}

	function changeItem(huh:Int = 0)
	{
		curSelected += huh;

		if (curSelected >= menuItems.length)
			curSelected = 0;
		if (curSelected < 0)
			curSelected = menuItems.length - 1;

		menuItems.forEach(function(spr:FlxSprite)
		{
			spr.animation.play('idle');
			spr.updateHitbox();

			if (spr.ID == curSelected)
			{
				spr.animation.play('selected');
				var add:Float = 0;
				if(menuItems.length > 4) {
					add = menuItems.length * 8;
				}
				camFollow.setPosition(
					FlxG.width / 2, 
					spr.getGraphicMidpoint().y - add
				);
				spr.centerOffsets();
			}
		});
	}
	// =============== Mod Selection ===============

	override function closeSubState() {
		if (pendingModIndex >= 0)
		{
			applyModSelection(pendingModIndex);
			pendingModIndex = -1;
		}
		persistentUpdate = true;
		super.closeSubState();
		// Restore camera follow after substate closes so menu scrolling works again
		FlxG.camera.follow(camFollowPos, null, 1);
	}

	function openModSelectSubstate()
	{
		#if MODS_ALLOWED
		// Reset camera to center before opening substate to prevent offset issues
		camFollow.setPosition(FlxG.width / 2, FlxG.height / 2);
		camFollowPos.setPosition(FlxG.width / 2, FlxG.height / 2);
		FlxG.camera.scroll.set(0, 0);

		// Build the mod list from modsList.txt + mod folders
		var modFolders:Array<String> = []; // '' = vanilla
		var modsListPath:String = 'modsList.txt';
		if (FileSystem.exists(modsListPath))
		{
			var lines:Array<String> = CoolUtil.coolTextFile(modsListPath);
			for (line in lines)
			{
				var parts = line.split('|');
				if (parts.length >= 1 && parts[0].length > 0
					&& !Paths.ignoreModFolders.contains(parts[0].toLowerCase())
					&& !modFolders.contains(parts[0]))
				{
					modFolders.push(parts[0]);
				}
			}
		}
		// Also pick up any folders not yet in modsList.txt
		for (folder in Paths.getModDirectories())
		{
			if (!Paths.ignoreModFolders.contains(folder) && !modFolders.contains(folder))
				modFolders.push(folder);
		}
		modFolders.sort(function(a, b) return (a < b) ? -1 : ((a > b) ? 1 : 0));
		modFolders.insert(0, ''); // Vanilla first

		// Find current selection index
		var selIdx:Int = 0;
		for (i in 0...modFolders.length)
		{
			if (modFolders[i] == selectedModFolder) { selIdx = i; break; }
		}

		// Stop camera follow so the substate isn't affected by camera movement
		FlxG.camera.follow(null);

		pendingModIndex = -1;
		persistentUpdate = false;
		openSubState(new ModSelectSubstate(
			modFolders,
			selIdx,
			function(newIdx:Int) { pendingModIndex = newIdx; },
			function() { /* cancel */ }
		));
		#end
	}

	function applyModSelection(newIdx:Int)
	{
		#if MODS_ALLOWED
		applyModSelectionExternal(newIdx);
		#end
	}

	/** Public version that can be called from ModState (accepts pre-built modFolders). */
	public static function applyModSelectionExternal(newIdx:Int, ?modFolders:Array<String>):Void
	{
		#if MODS_ALLOWED
		if (modFolders == null) 
			modFolders = [''];
		var modsListPath:String = 'modsList.txt';
		if (FileSystem.exists(modsListPath))
		{
			var lines:Array<String> = CoolUtil.coolTextFile(modsListPath);
			for (line in lines)
			{
				var parts = line.split('|');
				if (parts.length >= 1 && parts[0].length > 0
					&& !Paths.ignoreModFolders.contains(parts[0].toLowerCase())
					&& !modFolders.contains(parts[0]))
				{
					modFolders.push(parts[0]);
				}
			}
		}
		for (folder in Paths.getModDirectories())
		{
			if (!Paths.ignoreModFolders.contains(folder) && !modFolders.contains(folder))
				modFolders.push(folder);
		}
		modFolders.sort(function(a, b) return (a < b) ? -1 : ((a > b) ? 1 : 0));
		// Insert vanilla at front after sort
		if (modFolders.indexOf('') < 0) modFolders.insert(0, '');

		if (newIdx < 0 || newIdx >= modFolders.length) return;

		var newFolder:String = modFolders[newIdx];
		if (newFolder == selectedModFolder) return;

		// Apply selection
		selectedModFolder = newFolder;
		Paths.currentModDirectory = newFolder;
		saveActiveMod();

		// Apply mod pack.json config: window title, state/substate replacements
		ModState.applyModPackConfig(newFolder);

		// Check mod config: API version + restart requirements
		var needsRestart:Bool = false;
		if (newFolder.length > 0)
		{
			var modCfg:ModConfig = ModConfig.load(newFolder);

			// ── API version compatibility check ──
			if (!ModConfig.isCompatible(modCfg))
			{
				var reason:String = ModConfig.incompatibilityReason(modCfg);
				TraceManager.warn('trace.mainMenu.incompatibleMod', 'Incompatible mod: {}', [reason]);
				// Still allow selection but show warning — the ModsMenu will display the reason.
			}

			needsRestart = modCfg.restartRequired;

			// If the mod defines any state/substate replacements,
			// force a restart regardless of the "restart" field.
			if (!needsRestart)
			{
				if (modCfg.stateReplacements.keys().hasNext())
					needsRestart = true;
				else if (modCfg.substateReplacements.keys().hasNext())
					needsRestart = true;
			}
		}
		

		// Always force a full game restart (through TitleState) when switching mods,
		// even when switching to "vanilla" (empty folder).  This ensures:
		//   - stateReplacements are properly cleared and TitleState is not replaced
		//   - global mods are re-evaluated
		//   - assets reload cleanly
		if (instance != null) {
			instance.pendingModRestart = true;
			instance.currentModText.text = Language.get("MainMenu.activeMod", "Active Mod: ")
				+ WeekData.getModFolderDisplayName(newFolder)
				+ "\n" + Language.get("Mod.restart", "(Restarting...)");
			instance.currentModText.color = 0xFFFF6666;
			instance.currentModText.setFormat(Paths.languageFont(), 16, 0xFFFF6666, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			return;
		}
		else
		{
			// Called from outside MainMenuState (e.g. ModState TAB) — force a
			// full game restart so state replacements, window title etc. apply.
			TitleState.initialized = false;
			TitleState.closedState = false;
			FlxG.resetGame();
			return;
		}
		#end
	}

	function updateActiveModText()
	{
		#if MODS_ALLOWED
		var displayName:String = WeekData.getModFolderDisplayName(selectedModFolder);
		currentModText.text = Language.get("MainMenu.activeMod", "Active Mod:") + displayName;
		#else
		currentModText.text = '';
		#end
	}

	// =============== Persist active mod selection ===============

	/** Read the previously-selected mod folder from `activeMod.txt` (game root). */
	public static function loadActiveMod():Void {
		#if MODS_ALLOWED
		var path:String = 'activeMod.txt';
		if (FileSystem.exists(path)) {
			try {
				var content:String = File.getContent(path).trim();
				if (content.length > 0) {
					selectedModFolder = content;
				}
			} catch (e:Dynamic) {
				TraceManager.error('trace.error', 'Failed to load activeMod.txt: {}', [e]);
			}
		}
		#end
	}

	/** Persist the current mod folder to `activeMod.txt` (game root). */
	static function saveActiveMod():Void {
		#if MODS_ALLOWED
		try {
			File.saveContent('activeMod.txt', selectedModFolder);
		} catch (e:Dynamic) {
			TraceManager.error('trace.error', 'Failed to save activeMod.txt: {}', [e]);
		}
		#end
	}

	override function destroy() {
		instance = null;
		super.destroy();
	}
	
}