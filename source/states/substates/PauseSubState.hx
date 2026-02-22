package states.substates;

import options.OptionsState;
import Controls.Control;
import flixel.FlxSubState;
import flixel.addons.transition.FlxTransitionableState;
import flixel.input.keyboard.FlxKey;
import flixel.system.FlxSound;
import flixel.util.FlxStringUtil;
import flixel.util.FlxSpriteUtil;

class PauseSubState extends ScriptSubstate
{
	var menuItems:Array<String> = [];
	var menuItemsOG:Array<String> = ['Resume', 'Restart Song', 'Change Difficulty', 'Options', 'Exit to menu'];
	var difficultyChoices:Array<String> = [];
	var curSelected:Int = 0;

	var pauseMusic:FlxSound;
	var practiceText:FlxText;
	var skipTimeText:FlxText;
	var skipTimeTracker:FlxText;
	var curTime:Float = Math.max(0, Conductor.songPosition);

	// UI Elements
	var bg:FlxSprite;
	var menuBg:FlxSprite;
	var infoBg:FlxSprite;
	var menuItemsGroup:FlxSpriteGroup;
	var selectionIndicator:FlxSprite;
	
	var slideGroup:FlxSpriteGroup;

	public static var songName:String = '';

	public function new(x:Float, y:Float)
	{
		super();
		
		// Load language strings
		Language.load();

		if(CoolUtil.difficulties.length < 2) menuItemsOG.remove('Change Difficulty');

		if(PlayState.chartingMode)
		{
			menuItemsOG.insert(2, 'Leave Charting Mode');
			
			var num:Int = 0;
			if(!PlayState.instance.startingSong)
			{
				num = 1;
				menuItemsOG.insert(3, 'Skip Time');
			}
			menuItemsOG.insert(3 + num, 'End Song');
			menuItemsOG.insert(4 + num, 'Toggle Practice Mode');
			menuItemsOG.insert(5 + num, 'Toggle Botplay');
		}
		#if android 
		menuItemsOG.insert(2, 'Chart Editor');
		#end
		menuItems = menuItemsOG;

		for (i in 0...CoolUtil.difficulties.length) {
			difficultyChoices.push(CoolUtil.difficulties[i]);
		}
		difficultyChoices.push('BACK');

		bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.alpha = 0;
		bg.scrollFactor.set();
		add(bg);

		slideGroup = new FlxSpriteGroup();
		add(slideGroup);

		menuBg = FlxSpriteUtil.drawRoundRect(
			new FlxSprite(50, 50).makeGraphic(400, FlxG.height - 100, FlxColor.TRANSPARENT),
			0, 0, 400, FlxG.height - 100, 25, 25, FlxColor.BLACK
		);
		menuBg.alpha = 0.8;
		menuBg.scrollFactor.set();
		slideGroup.add(menuBg);

		infoBg = FlxSpriteUtil.drawRoundRect(
			new FlxSprite(menuBg.x + menuBg.width + 20, 50).makeGraphic(Std.int(FlxG.width - menuBg.width - 120), Std.int(FlxG.height - 100), FlxColor.TRANSPARENT),
			0, 0, FlxG.width - menuBg.width - 120, FlxG.height - 100, 25, 25, FlxColor.BLACK
		);
		infoBg.alpha = 0.6;
		infoBg.scrollFactor.set();
		slideGroup.add(infoBg);

		// Song info
		var songInfoText = new FlxText(infoBg.x + 20, infoBg.y + 20, infoBg.width - 40, Language.get("Paused", "Paused"), 32);
		songInfoText.setFormat(Paths.languageFont(), 32, FlxColor.WHITE, CENTER);
		songInfoText.scrollFactor.set();
		slideGroup.add(songInfoText);

		var songNameText = new FlxText(infoBg.x + 20, songInfoText.y + 50, infoBg.width - 40, PlayState.SONG.song, 28);
		songNameText.setFormat(Paths.languageFont(), 28, FlxColor.WHITE, CENTER);
		songNameText.scrollFactor.set();
		slideGroup.add(songNameText);

		var difficultyText = new FlxText(infoBg.x + 20, songNameText.y + 40, infoBg.width - 40, CoolUtil.difficultyString(), 24);
		difficultyText.setFormat(Paths.languageFont(), 24, FlxColor.WHITE, CENTER);
		difficultyText.scrollFactor.set();
		slideGroup.add(difficultyText);

		var blueballedText = new FlxText(infoBg.x + 20, difficultyText.y + 40, infoBg.width - 40, 
			Language.get("Blueballed", "Blueballed") + ": " + PlayState.deathCounter, 20);
		blueballedText.setFormat(Paths.languageFont(), 20, FlxColor.RED, CENTER);
		blueballedText.scrollFactor.set();
		slideGroup.add(blueballedText);

		// Practice mode text
		practiceText = new FlxText(infoBg.x + 20, blueballedText.y + 40, infoBg.width - 40, 
			Language.get("Practice Mode", "PRACTICE MODE"), 24);
		practiceText.setFormat(Paths.languageFont(), 24, FlxColor.CYAN, CENTER);
		practiceText.scrollFactor.set();
		practiceText.visible = PlayState.instance.practiceMode;
		slideGroup.add(practiceText);

		// Charting mode text
		var chartingText = new FlxText(infoBg.x + 20, practiceText.y + 40, infoBg.width - 40, 
			Language.get("Charting Mode", "CHARTING MODE"), 20);
		chartingText.setFormat(Paths.languageFont(), 20, FlxColor.RED, CENTER);
		chartingText.scrollFactor.set();
		chartingText.visible = PlayState.chartingMode;
		slideGroup.add(chartingText);

		// Menu items
		menuItemsGroup = new FlxSpriteGroup();
		slideGroup.add(menuItemsGroup);

		// Selection indicator
		selectionIndicator = new FlxSprite();
		selectionIndicator.makeGraphic(350, 40, FlxColor.WHITE);
		selectionIndicator.alpha = 0.2;
		selectionIndicator.scrollFactor.set();
		slideGroup.add(selectionIndicator);

		// Initialize menu
		regenMenu();

		// Background music
		pauseMusic = new FlxSound();
		if(songName != null) {
			pauseMusic.loadEmbedded(Paths.music(songName), true, true);
		} else if (songName != 'None') {
			pauseMusic.loadEmbedded(Paths.music(Paths.formatToSongPath(ClientPrefs.data.pauseMusic)), true, true);
		}
		pauseMusic.volume = 0;
		pauseMusic.play(false, FlxG.random.int(0, Std.int(pauseMusic.length / 2)));
		FlxG.sound.list.add(pauseMusic);

		bg.alpha = 0;
		slideGroup.y = FlxG.height;

		FlxTween.tween(bg, {alpha: 0.6}, 0.4, {ease: FlxEase.quartInOut});
		FlxTween.tween(slideGroup, {y: 0}, 0.5, {ease: FlxEase.backOut});

		cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];
		
		#if android
		addVirtualPad(LEFT_FULL, A);
		addPadCamera();
		#end
	}

	var holdTime:Float = 0;
	var cantUnpause:Float = 0.1;
	
	override function update(elapsed:Float)
	{
		cantUnpause -= elapsed;
		if (pauseMusic.volume < 0.5)
			pauseMusic.volume += 0.01 * elapsed;

		super.update(elapsed);
		updateSkipTextStuff();

		var upP = controls.UI_UP_P;
		var downP = controls.UI_DOWN_P;
		var accepted = controls.ACCEPT;

		if (upP)
		{
			changeSelection(-1);
		}
		if (downP)
		{
			changeSelection(1);
		}

		var daSelected:String = menuItems[curSelected];

		if (daSelected == 'Skip Time')
		{
			if (controls.UI_LEFT_P)
			{
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
				curTime -= 1000;
				holdTime = 0;
			}
			if (controls.UI_RIGHT_P)
			{
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
				curTime += 1000;
				holdTime = 0;
			}

			if(controls.UI_LEFT || controls.UI_RIGHT)
			{
				holdTime += elapsed;
				if(holdTime > 0.5)
				{
					curTime += 45000 * elapsed * (controls.UI_LEFT ? -1 : 1);
				}

				if(curTime >= FlxG.sound.music.length) curTime -= FlxG.sound.music.length;
				else if(curTime < 0) curTime += FlxG.sound.music.length;
				updateSkipTimeText();
			}
		}

		if (accepted && (cantUnpause <= 0 || !ClientPrefs.data.controllerMode))
		{
			if (menuItems == difficultyChoices)
			{
				if(menuItems.length - 1 != curSelected && difficultyChoices.contains(daSelected)) {
					var name:String = PlayState.SONG.song;
					var poop = Highscore.formatSong(name, curSelected);
					PlayState.SONG = Song.loadFromJson(poop, name);
					PlayState.storyDifficulty = curSelected;
					MusicBeatState.resetState();
					FlxG.sound.music.volume = 0;
					PlayState.changedDifficulty = true;
					PlayState.chartingMode = false;
					return;
				}

				menuItems = menuItemsOG;
				regenMenu();
			}

			switch (daSelected)
			{
				case "Resume":
					closeWithSlideAnimation();
				case 'Change Difficulty':
					menuItems = difficultyChoices;
					deleteSkipTimeText();
					regenMenu();
				case 'Toggle Practice Mode':
					PlayState.instance.practiceMode = !PlayState.instance.practiceMode;
					PlayState.changedDifficulty = true;
					practiceText.visible = PlayState.instance.practiceMode;
				case "Restart Song":
					restartSong();
				case "Leave Charting Mode":
					restartSong();
					PlayState.chartingMode = false;
				#if android
				case 'Chart Editor':
					PlayState.instance.openChartEditor();
				#end
				case 'Skip Time':
					if(curTime < Conductor.songPosition)
					{
						PlayState.startOnTime = curTime;
						restartSong(true);
					}
					else
					{
						if (curTime != Conductor.songPosition)
						{
							PlayState.instance.clearNotesBefore(curTime);
							PlayState.instance.setSongTime(curTime);
						}
						closeWithSlideAnimation();
					}
				case "End Song":
					closeWithSlideAnimation();
					PlayState.instance.finishSong(true);
				case 'Toggle Botplay':
					PlayState.instance.cpuControlled = !PlayState.instance.cpuControlled;
					PlayState.changedDifficulty = true;
					PlayState.instance.botplayTxt.visible = PlayState.instance.cpuControlled;
					PlayState.instance.botplayTxt.alpha = 1;
					PlayState.instance.botplaySine = 0;
				case 'Options':
					PlayState.instance.paused = true;
					PlayState.instance.vocals.volume = 0;
					MusicBeatState.switchState(new OptionsState());
					if(ClientPrefs.data.pauseMusic != 'None')
					{
						FlxG.sound.playMusic(Paths.music(Paths.formatToSongPath(ClientPrefs.data.pauseMusic)), pauseMusic.volume);
						FlxTween.tween(FlxG.sound.music, {volume: 1}, 0.8);
						FlxG.sound.music.time = pauseMusic.time;
					}
					OptionsState.onPlayState = true;
				case "Exit to menu":
					PlayState.deathCounter = 0;
					PlayState.seenCutscene = false;

					WeekData.loadTheFirstEnabledMod();
					if(PlayState.isStoryMode) {
						MusicBeatState.switchState(new StoryMenuState());
					} else {
						MusicBeatState.switchState(new FreeplayState());
					}
					PlayState.cancelMusicFadeTween();
					FlxG.sound.playMusic(Paths.music('freakyMenu'));
					PlayState.changedDifficulty = false;
					PlayState.chartingMode = false;
			}
		}
	}

	function closeWithSlideAnimation()
	{
		cantUnpause = 0.1;
		FlxTween.tween(slideGroup, {y: FlxG.height}, 0.4, {ease: FlxEase.quartIn, onComplete: function(_) {
			close();
		}});
		FlxTween.tween(bg, {alpha: 0}, 0.4, {ease: FlxEase.quartIn});
	}

	function deleteSkipTimeText()
	{
		if(skipTimeText != null)
		{
			skipTimeText.kill();
			remove(skipTimeText);
			skipTimeText.destroy();
		}
		skipTimeText = null;
		skipTimeTracker = null;
	}

	public static function restartSong(noTrans:Bool = false)
	{
		PlayState.instance.paused = true;
		FlxG.sound.music.volume = 0;
		PlayState.instance.vocals.volume = 0;

		if(noTrans)
		{
			FlxTransitionableState.skipNextTransOut = true;
			FlxG.resetState();
		}
		else
		{
			MusicBeatState.resetState();
		}
	}

	override function destroy()
	{
		if(pauseMusic != null) pauseMusic.destroy();
		super.destroy();
	}

	function changeSelection(change:Int = 0):Void
	{
		curSelected += change;

		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		if (curSelected < 0)
			curSelected = menuItems.length - 1;
		if (curSelected >= menuItems.length)
			curSelected = 0;

		var bullShit:Int = 0;

		for (item in menuItemsGroup.members)
		{
			item.alpha = 0.6;
			item.color = FlxColor.WHITE;

			if (bullShit == curSelected)
			{
				item.alpha = 1;
				item.color = FlxColor.CYAN;
				
				// Update selection indicator position
				selectionIndicator.x = menuBg.x + 25;
				selectionIndicator.y = item.y - 5;
				
				if(item == skipTimeTracker)
				{
					curTime = Math.max(0, Conductor.songPosition);
					updateSkipTimeText();
				}
			}
			bullShit++;
		}
	}

	function regenMenu():Void {
		for (i in 0...menuItemsGroup.members.length) {
			var obj = menuItemsGroup.members[0];
			obj.kill();
			menuItemsGroup.remove(obj, true);
			obj.destroy();
		}

		for (i in 0...menuItems.length) {
			var itemText = Language.get(menuItems[i], menuItems[i]);
			var item = new FlxText(menuBg.x + 40, menuBg.y + 30 + (i * 50), 320, itemText, 24);
			item.setFormat(Paths.languageFont(), 24, FlxColor.WHITE, LEFT);
			item.scrollFactor.set();
			item.alpha = 0.6;
			
			menuItemsGroup.add(item);

			if(menuItems[i] == 'Skip Time')
			{
				// Create skip time display text
				skipTimeText = new FlxText(infoBg.x + 20, infoBg.y + infoBg.height - 100, infoBg.width - 40, '', 20);
				skipTimeText.setFormat(Paths.languageFont(), 20, FlxColor.WHITE, CENTER);
				skipTimeText.scrollFactor.set();
				skipTimeText.borderSize = 2;
				skipTimeText.borderColor = FlxColor.BLACK;
				skipTimeTracker = item;
				slideGroup.add(skipTimeText);

				updateSkipTextStuff();
				updateSkipTimeText();
			}
		}
		curSelected = 0;
		changeSelection();
		
		// Show/hide selection indicator based on whether there are menu items
		selectionIndicator.visible = (menuItems.length > 0);
	}
	
	function updateSkipTextStuff()
	{
		if(skipTimeText == null || skipTimeTracker == null) return;

		// Position skip time text at the bottom of info panel
		skipTimeText.x = infoBg.x + 20;
		skipTimeText.y = infoBg.y + infoBg.height - 80;
		skipTimeText.visible = (skipTimeTracker.alpha >= 1);
	}

	function updateSkipTimeText()
	{
		if(skipTimeText != null)
			skipTimeText.text = FlxStringUtil.formatTime(Math.max(0, Math.floor(curTime / 1000)), false) + ' / ' + FlxStringUtil.formatTime(Math.max(0, Math.floor(FlxG.sound.music.length / 1000)), false);
	}
}