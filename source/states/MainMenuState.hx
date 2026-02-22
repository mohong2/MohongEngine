package states;

import script.lua.FunkinLua;
import options.OptionsState;
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
import flixel.input.keyboard.FlxKey;

using StringTools;

class MainMenuState extends ScriptState
{
	#if desktop
	public static var mohongEngineVersion:String = '1.0'; 
	#else
	public static var mohongEngineVersion:String = '0.0.1'; // Android version
	#end
	public static var psychEngineVersion:String = '0.6.3.1';
	public static var curSelected:Int = 0;

	var menuItems:FlxTypedGroup<FlxSprite>;
	private var camGame:FlxCamera;
	private var camAchievement:FlxCamera;
	
	var optionShit:Array<String> = [
		'story_mode',
		'freeplay',
		#if MODS_ALLOWED 'mods', #end
		#if ACHIEVEMENTS_ALLOWED 'awards', #end
		'credits',
		#if !switch 'donate', #end
		'options'
	];

	var magenta:FlxSprite;
	var camFollow:FlxObject;
	var camFollowPos:FlxObject;
	var debugKeys:Array<FlxKey>;
	var mouseOverlapIndex = -1;
	public static var instance:MainMenuState;
	
	override function create()
	{
		instance = this;
		#if MODS_ALLOWED
		Paths.pushGlobalMods();
		#end
		WeekData.loadTheFirstEnabledMod();
		FlxG.mouse.visible = true;
		#if cpp
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Menus", null);
		#end
		debugKeys = ClientPrefs.copyKey(ClientPrefs.keyBinds.get('debug_1'));

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
		var bg:FlxSprite = new FlxSprite(-80).loadGraphic(Paths.image('menuBG'));
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
		
		var versionShit:FlxText = new FlxText(versionShitx, FlxG.height - 64, 0, #if !android "Mohong Engine v" #else "Mohong Engine Android v" #end + mohongEngineVersion, 12);
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
	}

	#if ACHIEVEMENTS_ALLOWED
	// Unlocks "Freaky on a Friday Night" achievement
	function giveAchievement() {
		add(new AchievementObject('friday_night_play', camAchievement));
		FlxG.sound.play(Paths.sound('confirmMenu'), 0.7);
		trace('Giving achievement "friday_night_play"');
	}
	#end

	var selectedSomethin:Bool = false;

	override function update(elapsed:Float)
	{
		if (FlxG.sound.music.volume < 0.8)
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
	override function destroy() {
		instance = null;
		super.destroy();
	}
	
}