package states;

import states.substates.ResetScoreSubState;
import states.substates.GameplayChangersSubstate;
import flixel.ui.FlxBar;
import flixel.effects.FlxFlicker;
#if cpp
import Discord.DiscordClient;
#end
import editors.ChartingState;
import flash.text.TextField;
import flixel.addons.display.FlxGridOverlay;
import flixel.addons.transition.FlxTransitionableState;
import lime.utils.Assets;
import flixel.system.FlxSound;
import openfl.utils.Assets as OpenFlAssets;
import WeekData;
#if MODS_ALLOWED
import sys.FileSystem;
#end

using StringTools;

class FreeplayState extends ScriptState
{
	public static var instance:FreeplayState = null;
	public var songs:Array<SongMetadata> = [];
	public var playingMusic:Bool = false;
	public var paused:Bool = false;
	public var curTime:Float = 0;
	public var previewSongTxt:FlxText;
	public var previewTimeTxt:FlxText;
	public var progressBar:FlxBar;
	public var confirmTween:FlxTween;
	public var canInput:Bool = true; 
	public var previewBG:FlxSprite;
	public var wasVisible:Map<FlxSprite, Bool> = new Map(); 
	public var playbackRate:Float = 1.0;
	public var selector:FlxText;
	public static var curSelected:Int = 0;
	public static var vocals:FlxSound = null;
	public var currentsongname:String = "";
	public var curDifficulty:Int = -1;
	public static var lastDifficultyName:String = '';
	public var scoreBG:FlxSprite;
	public var scoreText:FlxText;
	public var diffText:FlxText;
	public var lerpScore:Int = 0;
	public var lerpRating:Float = 0;
	public var intendedScore:Int = 0;
	public var intendedRating:Float = 0;
	
	public var grpSongs:FlxTypedGroup<Alphabet>;
	public var iconArray:Array<HealthIcon> = [];

	public var bg:FlxSprite;
	public var intendedColor:Int;
	public var colorTween:FlxTween;
	public var mouseOverlapIndex:Int = -1;
	
	private var curPlaying:Bool = false;
	private var holdTime:Float = 0;
	private var instPlaying:Int = -1;

	override function create()
	{
		//Paths.clearStoredMemory();
		//Paths.clearUnusedMemory();
		instance = this;
		persistentUpdate = true;
		PlayState.isStoryMode = false;
		WeekData.reloadWeekFiles(false);
		FlxG.mouse.visible = true;
		#if cpp
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Menus", null);
		#end

		for (i in 0...WeekData.weeksList.length) {
			if(weekIsLocked(WeekData.weeksList[i])) continue;

			var leWeek:WeekData = WeekData.weeksLoaded.get(WeekData.weeksList[i]);
			var leSongs:Array<String> = [];
			var leChars:Array<String> = [];

			for (j in 0...leWeek.songs.length)
			{
				leSongs.push(leWeek.songs[j][0]);
				leChars.push(leWeek.songs[j][1]);
			}

			WeekData.setDirectoryFromWeek(leWeek);
			for (song in leWeek.songs)
			{
				var colors:Array<Int> = song[2];
				if(colors == null || colors.length < 3)
				{
					colors = [146, 113, 253];
				}
				addSong(song[0], i, song[1], FlxColor.fromRGB(colors[0], colors[1], colors[2]));
			}
		}
		WeekData.loadTheFirstEnabledMod();

		/*		//KIND OF BROKEN NOW AND ALSO PRETTY USELESS//

		var initSonglist = CoolUtil.coolTextFile(Paths.txt('freeplaySonglist'));
		for (i in 0...initSonglist.length)
		{
			if(initSonglist[i] != null && initSonglist[i].length > 0) {
				var songArray:Array<String> = initSonglist[i].split(":");
				addSong(songArray[0], 0, songArray[1], Std.parseInt(songArray[2]));
			}
		}*/

		bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.data.globalAntialiasing;
		add(bg);
		bg.screenCenter();

		grpSongs = new FlxTypedGroup<Alphabet>();
		add(grpSongs);

		previewBG = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		previewBG.alpha = 0.7;
		previewBG.visible = false;
		add(previewBG);
		
		previewSongTxt = new FlxText(0, 50, FlxG.width, "", 32);
		previewSongTxt.setFormat(Paths.languageFont(), 32, FlxColor.WHITE, CENTER);
		previewSongTxt.scrollFactor.set();
		previewSongTxt.visible = false;
		add(previewSongTxt);
		
		previewTimeTxt = new FlxText(0, 100, FlxG.width, "", 24);
		previewTimeTxt.setFormat(Paths.languageFont(), 24, FlxColor.WHITE, CENTER);
		previewTimeTxt.scrollFactor.set();
		previewTimeTxt.visible = false;
		add(previewTimeTxt);
		
		progressBar = new FlxBar(50, 140, LEFT_TO_RIGHT, FlxG.width - 100, 15, null, "", 0, 100, true);
		progressBar.createFilledBar(0xFF444444, FlxColor.WHITE);
		progressBar.visible = false;
		add(progressBar);

		for (i in 0...songs.length)
		{
			var songText:Alphabet = new Alphabet(90, 325, songs[i].songName, true);
			songText.isMenuItem = true;
			songText.targetY = i - curSelected;
			grpSongs.add(songText);

			var maxWidth = 980;
			if (songText.width > maxWidth)
			{
				songText.scaleX = maxWidth / songText.width;
			}
			songText.snapToPosition();

			Paths.currentModDirectory = songs[i].folder;
			var icon:HealthIcon = new HealthIcon(songs[i].songCharacter);
			icon.sprTracker = songText;

			// using a FlxGroup is too much fuss!
			iconArray.push(icon);
			add(icon);

			//songText.x += 40;
			// DONT PUT X IN THE FIRST PARAMETER OF new ALPHABET() !!
			// songText.screenCenter(X);
		}
		WeekData.setDirectoryFromWeek();

		scoreText = new FlxText(FlxG.width * 0.7, 5, 0, "", 32);
		scoreText.setFormat(Paths.languageFont(), 32, FlxColor.WHITE, RIGHT);

		scoreBG = new FlxSprite(scoreText.x - 6, 0).makeGraphic(1, 66, 0xFF000000);
		scoreBG.alpha = 0.6;
		add(scoreBG);

		diffText = new FlxText(scoreText.x, scoreText.y + 36, 0, "", 24);
		diffText.font = Paths.font("vcr.ttf"); 
		add(diffText);

		add(scoreText);

		if(curSelected >= songs.length) curSelected = 0;
		bg.color = songs[curSelected].color;
		intendedColor = bg.color;


		if(lastDifficultyName == '')
		{
			lastDifficultyName = CoolUtil.defaultDifficulty;
		}

		curDifficulty = Math.round(Math.max(0, CoolUtil.defaultDifficulties.indexOf(lastDifficultyName)));
		
		changeSelection();
		changeDiff();

		var swag:Alphabet = new Alphabet(1, 0, "swag");

		// JUST DOIN THIS SHIT FOR TESTING!!!
		/* 
			var md:String = Markdown.markdownToHtml(Assets.getText('CHANGELOG.md'));

			var texFel:TextField = new TextField();
			texFel.width = FlxG.width;
			texFel.height = FlxG.height;
			// texFel.
			texFel.htmlText = md;

			FlxG.stage.addChild(texFel);

			// scoreText.textField.htmlText = md;

			trace(md);
		 */

		var textBG:FlxSprite = new FlxSprite(0, FlxG.height - 26).makeGraphic(FlxG.width, 26, 0xFF000000);
		textBG.alpha = 0.6;
		add(textBG);


		#if PRELOAD_ALL
		var leText:String = Language.get("FreeplayState.leText", "Press X to listen to the Song / Press C to open the Gameplay Changers Menu / Press Y to Reset your Score and Accuracy.");
		var size:Int = 16;
		#else
		var leText:String = Language.get("FreeplayState.leText.NOTRELOAD_ALL", "Press CTRL to open the Gameplay Changers Menu / Press RESET to Reset your Score and Accuracy.");
		var size:Int = 18;
		#end
		var text:FlxText = new FlxText(textBG.x, textBG.y + 4, FlxG.width, leText, size);
		text.setFormat(Paths.languageFont(), size, FlxColor.WHITE, RIGHT);
		text.scrollFactor.set();
		add(text);
		#if android
		addVirtualPad(LEFT_FULL, A_B_C_X_Y_Z);
		#end
		super.create();
	}


	override function closeSubState() {
		changeSelection(0, false);
		persistentUpdate = true;
		#if android
		removeVirtualPad();
		addVirtualPad(LEFT_FULL, A_B_C_X_Y_Z);
		#end
		super.closeSubState();
	}

	public function addSong(songName:String, weekNum:Int, songCharacter:String, color:Int)
	{
		songs.push(new SongMetadata(songName, weekNum, songCharacter, color));
	}

	public function weekIsLocked(name:String):Bool {
		var leWeek:WeekData = WeekData.weeksLoaded.get(name);
		return (!leWeek.startUnlocked && leWeek.weekBefore.length > 0 && (!StoryMenuState.weekCompleted.exists(leWeek.weekBefore) || !StoryMenuState.weekCompleted.get(leWeek.weekBefore)));
	}

	/*public function addWeek(songs:Array<String>, weekNum:Int, weekColor:Int, ?songCharacters:Array<String>)
	{
		if (songCharacters == null)
			songCharacters = ['bf'];

		var num:Int = 0;
		for (song in songs)
		{
			addSong(song, weekNum, songCharacters[num]);
			this.songs[this.songs.length-1].color = weekColor;

			if (songCharacters.length != 1)
				num++;
		}
	}*/

	override function update(elapsed:Float)
	{
		currentsongname = songs[curSelected].songName;
		
		if (FlxG.sound.music.volume < 0.7)
		{
			FlxG.sound.music.volume += 0.5 * FlxG.elapsed;
		}

		lerpScore = Math.floor(FlxMath.lerp(lerpScore, intendedScore, CoolUtil.boundTo(elapsed * 24, 0, 1)));
		lerpRating = FlxMath.lerp(lerpRating, intendedRating, CoolUtil.boundTo(elapsed * 12, 0, 1));

		if (Math.abs(lerpScore - intendedScore) <= 10)
			lerpScore = intendedScore;
		if (Math.abs(lerpRating - intendedRating) <= 0.01)
			lerpRating = intendedRating;

		var ratingSplit:Array<String> = Std.string(Highscore.floorDecimal(lerpRating * 100, 2)).split('.');
		if(ratingSplit.length < 2) { //No decimals, add an empty space
			ratingSplit.push('');
		}
		
		while(ratingSplit[1].length < 2) { //Less than 2 decimals in it, add decimals then
			ratingSplit[1] += '0';
		}
		scoreText.text = Language.get("FreeplayState.scoreText", "PERSONAL BEST:") + lerpScore + ' (' + ratingSplit.join('.') + '%)';
		positionHighscore();

		var upP = controls.UI_UP_P;
		var downP = controls.UI_DOWN_P;
		var accepted = controls.ACCEPT;
		var space = #if android virtualPad.buttonX.justPressed  || #end	FlxG.keys.justPressed.SPACE;
		var ctrl = #if android virtualPad.buttonC.justPressed   || #end FlxG.keys.justPressed.CONTROL;
		#if !android
		var newMouseOverlapIndex = -1;
		for (i in 0...grpSongs.length) {
			var song = grpSongs.members[i];
			var icon = iconArray[i];
			if (FlxG.mouse.overlaps(song) || FlxG.mouse.overlaps(icon)) {
				newMouseOverlapIndex = i;
				break;
			}
		}
		
		if (mouseOverlapIndex != newMouseOverlapIndex) {
			if (mouseOverlapIndex >= 0 && mouseOverlapIndex != curSelected) {
				grpSongs.members[mouseOverlapIndex].alpha = 0.6;
				iconArray[mouseOverlapIndex].alpha = 0.6;
			}
			
			if (newMouseOverlapIndex >= 0 && newMouseOverlapIndex != curSelected) {
				grpSongs.members[newMouseOverlapIndex].alpha = 1.0;
				iconArray[newMouseOverlapIndex].alpha = 1.0;
			}
			
			mouseOverlapIndex = newMouseOverlapIndex;
		}
		
		if (FlxG.mouse.justPressed && mouseOverlapIndex >= 0 && mouseOverlapIndex != curSelected && !playingMusic) {
			curSelected = mouseOverlapIndex;
			changeSelection();
			changeDiff();
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
		}
		#end
		if (FlxG.mouse.justPressed && mouseOverlapIndex == curSelected && !playingMusic) {
			if (canInput) {
				accepted = true; 
			}
		}

		var shiftMult:Int = 1;
		if(#if android virtualPad.buttonZ.pressed || #end FlxG.keys.pressed.SHIFT) shiftMult = 3;
		if (!playingMusic){
		if(songs.length > 1)
		{
			if (upP)
			{
				changeSelection(-shiftMult);
				holdTime = 0;
			}
			if (downP)
			{
				changeSelection(shiftMult);
				holdTime = 0;
			}
		
			if(controls.UI_DOWN || controls.UI_UP)
			{
				var checkLastHold:Int = Math.floor((holdTime - 0.5) * 10);
				holdTime += elapsed;
				var checkNewHold:Int = Math.floor((holdTime - 0.5) * 10);

				if(holdTime > 0.5 && checkNewHold - checkLastHold > 0)
				{
					changeSelection((checkNewHold - checkLastHold) * (controls.UI_UP ? -shiftMult : shiftMult));
					changeDiff();
				}
			}

			if(FlxG.mouse.wheel != 0)
			{
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.2);
				changeSelection(-shiftMult * FlxG.mouse.wheel, false);
				changeDiff();
				}
			}
	
		if (controls.UI_LEFT_P)
			changeDiff(-1);
		else if (controls.UI_RIGHT_P)
			changeDiff(1);
		else if (upP || downP) changeDiff();
}
	

		if (controls.BACK)
		{
			if (playingMusic)
			{
				stopPreview();
			}else{
			persistentUpdate = false;
			if(colorTween != null) {
				colorTween.cancel();
			}
			FlxG.sound.play(Paths.sound('cancelMenu'));
			MusicBeatState.switchState(new MainMenuState());
			}
		}
		if (FlxG.keys.justPressed.SPACE && canInput)
    	{
        if (instPlaying != curSelected && !playingMusic)
        {
            startPreview();
        }
        else if (instPlaying == curSelected && playingMusic)
        {
            if (paused)
            {
                resumePreview();
            }
            else
            {
                pausePreview();
            }
        }
		}
		if (playingMusic && !paused)
    	{
        curTime = FlxG.sound.music.time;
        updatePreviewTexts();
        
        if (controls.UI_LEFT_P)
        {
            jumpPreview(-5000);
        }
        if (controls.UI_RIGHT_P)
        {
            jumpPreview(5000);
        }
        
        if (controls.RESET)
        {
            jumpPreview(0); 
        }
        

        if (curTime >= FlxG.sound.music.length)
        {
            stopPreview();
        }
    }
	    if (playingMusic)
   		 {
			if (FlxG.keys.justPressed.UP #if android || virtualPad.buttonUp.justPressed #end)
			{
				playbackRate += 0.05;
				if (playbackRate > 3.0) playbackRate = 3.0;
				setPlaybackRate();
				updatePreviewTexts();
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.5);
			}
			else if (FlxG.keys.justPressed.DOWN	#if android || virtualPad.buttonDown.justPressed #end)
			{
				playbackRate -= 0.05;
				if (playbackRate < 0.25) playbackRate = 0.25;
				setPlaybackRate();
				updatePreviewTexts();
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.5);
			}
	}
		if(ctrl)
		{
			persistentUpdate = false;
			openSubState(new GameplayChangersSubstate());
		}
		else if(space)
		{
			if(instPlaying != curSelected)
			{
				#if PRELOAD_ALL
				destroyFreeplayVocals();
				FlxG.sound.music.volume = 0;
				Paths.currentModDirectory = songs[curSelected].folder;
				var poop:String = Highscore.formatSong(songs[curSelected].songName.toLowerCase(), curDifficulty);
				PlayState.SONG = Song.loadFromJson(poop, songs[curSelected].songName.toLowerCase());
				if (PlayState.SONG.needsVoices)
					vocals = new FlxSound().loadEmbedded(Paths.voices(PlayState.SONG.song));
				else
					vocals = new FlxSound();

				FlxG.sound.list.add(vocals);
				FlxG.sound.playMusic(Paths.inst(PlayState.SONG.song), 0.7);
				vocals.play();
				vocals.persist = true;
				vocals.looped = true;
				vocals.volume = 0.7;
				instPlaying = curSelected;
				#end
			}
		}

		else if (accepted)
		{
		canInput = false;
		persistentUpdate = false;
		
		FlxG.sound.play(Paths.sound('confirmMenu'), 0.7);
		var selectedSong:Alphabet = grpSongs.members[curSelected];
		var icon:HealthIcon = iconArray[curSelected]; 
		
		FlxFlicker.flicker(selectedSong, 1, 0.07, false, true, function(flick:FlxFlicker) {

			confirmTween = FlxTween.tween(selectedSong, {
				x: selectedSong.x - 600,
				alpha: 0
			}, 2.0, {
				ease: FlxEase.quadIn
			});
			
			FlxTween.tween(icon, {
				alpha: 0,
				scale: { x: 0.5, y: 0.5 }
			}, 1.0, {
				ease: FlxEase.cubeOut,
				onComplete: function(twn:FlxTween) {
					
					var songLowercase:String = Paths.formatToSongPath(songs[curSelected].songName);
					var poop:String = Highscore.formatSong(songLowercase, curDifficulty);
					PlayState.SONG = Song.loadFromJson(poop, songLowercase);
					LoadingState.loadAndSwitchState(new PlayState());
				}
			});
		});
    

    for (i in 0...grpSongs.length) {
        if(i != curSelected) {
            FlxTween.tween(grpSongs.members[i], {
                alpha: 0,
                x: grpSongs.members[i].x + 200
            }, 0.8, {ease: FlxEase.quadOut});
        }
    }

			var songLowercase:String = Paths.formatToSongPath(songs[curSelected].songName);
			var poop:String = Highscore.formatSong(songLowercase, curDifficulty);
			/*#if MODS_ALLOWED
			if(!sys.FileSystem.exists(Paths.modsJson(songLowercase + '/' + poop)) && !sys.FileSystem.exists(Paths.json(songLowercase + '/' + poop))) {
			#else
			if(!OpenFlAssets.exists(Paths.json(songLowercase + '/' + poop))) {
			#end
				poop = songLowercase;
				curDifficulty = 1;
				trace('Couldnt find file');
			}*/
			trace(poop);
			PlayState.SONG = Song.loadFromJson(poop, songLowercase);
			PlayState.isStoryMode = false;
			PlayState.storyDifficulty = curDifficulty;


			trace('CURRENT WEEK: ' + WeekData.getWeekFileName());
			if(colorTween != null) {
				colorTween.cancel();
			}
			
			if (FlxG.keys.pressed.SHIFT){
				LoadingState.loadAndSwitchState(new ChartingState());
			}else{
				LoadingState.loadAndSwitchState(new PlayState());
			}

			FlxG.sound.music.volume = 0;
					
			destroyFreeplayVocals();
		}
		else if(#if android virtualPad.buttonY.justPressed ||#end controls.RESET)
		{
			persistentUpdate = false;
			openSubState(new ResetScoreSubState(songs[curSelected].songName, curDifficulty, songs[curSelected].songCharacter));
			FlxG.sound.play(Paths.sound('scrollMenu'));
		}
		super.update(elapsed);
	}

	public static function destroyFreeplayVocals() {
		if(vocals != null) {
			vocals.stop();
			vocals.destroy();
		}
		vocals = null;
	}

	public function changeDiff(change:Int = 0)
	{
		curDifficulty += change;

		if (curDifficulty < 0)
			curDifficulty = CoolUtil.difficulties.length-1;
		if (curDifficulty >= CoolUtil.difficulties.length)
			curDifficulty = 0;

		lastDifficultyName = CoolUtil.difficulties[curDifficulty];

		#if !switch
		intendedScore = Highscore.getScore(songs[curSelected].songName, curDifficulty);
		intendedRating = Highscore.getRating(songs[curSelected].songName, curDifficulty);
		#end

		PlayState.storyDifficulty = curDifficulty;
		if (CoolUtil.difficulties.length == 1) diffText.text = '' + CoolUtil.difficultyString() + ' ';
		else 
		diffText.text = '< ' + CoolUtil.difficultyString() + ' >';

		positionHighscore();
	}

	public function changeSelection(change:Int = 0, playSound:Bool = true)
	{
		
		if(playSound) FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		curSelected += change;

		if (curSelected < 0)
			curSelected = songs.length - 1;
		if (curSelected >= songs.length)
			curSelected = 0;
			
		var newColor:Int = songs[curSelected].color;
		if(newColor != intendedColor) {
			if(colorTween != null) {
				colorTween.cancel();
			}
			intendedColor = newColor;
			colorTween = FlxTween.color(bg, 1, bg.color, intendedColor, {
				onComplete: function(twn:FlxTween) {
					colorTween = null;
				}
			});
		}
		for (i in 0...grpSongs.length) {
        var item = grpSongs.members[i];
        var icon = iconArray[i];
		var targetScale = (i == curSelected) ? 1.2 : 0.85;
        FlxTween.cancelTweensOf(item.scale);
        FlxTween.cancelTweensOf(icon.scale);
        
        FlxTween.tween(item.scale, {x: targetScale, y: targetScale}, 0.25, {
            ease: FlxEase.quadOut
        });
        
        FlxTween.tween(icon.scale, {x: targetScale, y: targetScale}, 0.25, {
            ease: FlxEase.quadOut
        });
    }


    for (i in 0...iconArray.length) {
        iconArray[i].alpha = 0.6;
        
        if (iconArray[i].frameCount == 3) {
            iconArray[i].animation.curAnim.curFrame = 0;
        }
    }

    iconArray[curSelected].alpha = 1;
    
    if (iconArray[curSelected].frameCount == 3) {
        iconArray[curSelected].animation.curAnim.curFrame = 2;
    }


		// selector.y = (70 * curSelected) + 30;

		#if !switch
		intendedScore = Highscore.getScore(songs[curSelected].songName, curDifficulty);
		intendedRating = Highscore.getRating(songs[curSelected].songName, curDifficulty);
		#end

		var bullShit:Int = 0;

		for (i in 0...iconArray.length)
		{
			iconArray[i].alpha = 0.6;
		}

		iconArray[curSelected].alpha = 1;

		for (item in grpSongs.members)
		{
			item.targetY = bullShit - curSelected;
			bullShit++;

			item.alpha = 0.6;
			// item.setGraphicSize(Std.int(item.width * 0.8));

			if (item.targetY == 0)
			{
				item.alpha = 1;
				// item.setGraphicSize(Std.int(item.width));
			}
		}
		
		Paths.currentModDirectory = songs[curSelected].folder;
		PlayState.storyWeek = songs[curSelected].week;

		CoolUtil.difficulties = CoolUtil.defaultDifficulties.copy();
		var diffStr:String = WeekData.getCurrentWeek().difficulties;
		if(diffStr != null) diffStr = diffStr.trim(); //Fuck you HTML5

		if(diffStr != null && diffStr.length > 0)
		{
			var diffs:Array<String> = diffStr.split(',');
			var i:Int = diffs.length - 1;
			while (i > 0)
			{
				if(diffs[i] != null)
				{
					diffs[i] = diffs[i].trim();
					if(diffs[i].length < 1) diffs.remove(diffs[i]);
				}
				--i;
			}

			if(diffs.length > 0 && diffs[0].length > 0)
			{
				CoolUtil.difficulties = diffs;
			}
		}
		
		if(CoolUtil.difficulties.contains(CoolUtil.defaultDifficulty))
		{
			curDifficulty = Math.round(Math.max(0, CoolUtil.defaultDifficulties.indexOf(CoolUtil.defaultDifficulty)));
		}
		else
		{
			curDifficulty = 0;
		}

		var newPos:Int = CoolUtil.difficulties.indexOf(lastDifficultyName);
		//trace('Pos of ' + lastDifficultyName + ' is ' + newPos);
		if(newPos > -1)
		{
			curDifficulty = newPos;
		}
	}

	public function positionHighscore() {
		scoreText.x = FlxG.width - scoreText.width - 6;

		scoreBG.scale.x = FlxG.width - scoreText.x + 6;
		scoreBG.x = FlxG.width - (scoreBG.scale.x / 2);
		diffText.x = Std.int(scoreBG.x + (scoreBG.width / 2));
		diffText.x -= diffText.width / 2;
	}
	
	public function startPreview()
	{
		#if PRELOAD_ALL
		destroyFreeplayVocals();
		FlxG.sound.music.volume = 0;
		Paths.currentModDirectory = songs[curSelected].folder;
		var poop:String = Highscore.formatSong(songs[curSelected].songName.toLowerCase(), curDifficulty);
		PlayState.SONG = Song.loadFromJson(poop, songs[curSelected].songName.toLowerCase());
		
		if (PlayState.SONG.needsVoices)
			vocals = new FlxSound().loadEmbedded(Paths.voices(PlayState.SONG.song));
		else
			vocals = new FlxSound();

		FlxG.sound.list.add(vocals);
		FlxG.sound.playMusic(Paths.inst(PlayState.SONG.song), 0.7);
		vocals.play();
		vocals.persist = true;
		vocals.looped = true;
		vocals.volume = 0.7;
		#end
		
		instPlaying = curSelected;
		playingMusic = true;
		paused = false;
		curTime = 0;
		playbackRate = 1.0;
		
		hideNonPreviewElements();
		
		previewBG.visible = true;
		previewSongTxt.visible = true;
		previewTimeTxt.visible = true;
		progressBar.visible = true;
		updatePreviewTexts(); 
	}

	public function stopPreview()
	{
		playingMusic = false;
		paused = false;
		playbackRate = 1.0;
		destroyFreeplayVocals();
		FlxG.sound.music.stop();
		FlxG.sound.music.volume = 0;
		instPlaying = -1;
		
		previewBG.visible = false;
		previewSongTxt.visible = false;
		previewTimeTxt.visible = false;
		progressBar.visible = false;
		
		restoreNonPreviewElements();
		
		FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
		FlxTween.tween(FlxG.sound.music, {volume: 1}, 1);
	}


	public function setPlaybackRate()
	{
		FlxG.sound.music.pitch = playbackRate;
		if (vocals != null) vocals.pitch = playbackRate;
	}
	
	public function pausePreview()
	{
		if (playingMusic && !paused)
		{
			paused = true;
			FlxG.sound.music.pause();
			if (vocals != null) vocals.pause();
			previewSongTxt.text = 'PLAYING: ' + songs[curSelected].songName + ' (PAUSED)';
		}
	}

	public function resumePreview()
	{
		if (playingMusic && paused)
		{
			paused = false;
			FlxG.sound.music.resume();
			if (vocals != null) vocals.resume();
			previewSongTxt.text = 'PLAYING: ' + songs[curSelected].songName;
		}
	}

	public function jumpPreview(amount:Float)
	{
		if (!playingMusic) return;
		
		var wasPlaying = !paused;
		if (wasPlaying) pausePreview();
		
		curTime += amount;
		if (curTime < 0) curTime = 0;
		if (curTime > FlxG.sound.music.length) curTime = FlxG.sound.music.length;
		
		FlxG.sound.music.time = curTime;
		if (vocals != null) vocals.time = curTime;
		
		if (wasPlaying) resumePreview();
		
		updatePreviewTexts();
	}

	public function updatePreviewTexts()
	{
		if (!playingMusic) return;
		
		var timeStr = formatTime(curTime / 1000) + ' / ' + formatTime(FlxG.sound.music.length / 1000);
		previewTimeTxt.text = timeStr;

		if (FlxG.sound.music.length > 0) {
			var progress = (curTime / FlxG.sound.music.length) * 100;
			progressBar.value = progress;
		}

		var rateText = ' (' + playbackRate + 'x)';
		if (paused)
			previewSongTxt.text = 'PLAYING: ' + songs[curSelected].songName + rateText + ' (PAUSED)';
		else
			previewSongTxt.text = 'PLAYING: ' + songs[curSelected].songName + rateText;
	}
	
	public function formatTime(seconds:Float):String
	{
		var minutes:Int = Math.floor(seconds / 60);
		var sec:Int = Math.floor(seconds % 60);
		return minutes + ':' + (sec < 10 ? '0' : '') + sec;
	}
	
	public function hideNonPreviewElements()
	{
		wasVisible = new Map();
		
		for (i in 0...grpSongs.length) {
			if (i != curSelected) {
				wasVisible.set(grpSongs.members[i], grpSongs.members[i].visible);
				grpSongs.members[i].visible = false;
			}
		}
		
		for (i in 0...iconArray.length) {
			if (i != curSelected) {
				wasVisible.set(iconArray[i], iconArray[i].visible);
				iconArray[i].visible = false;
			}
		}
		
		wasVisible.set(scoreBG, scoreBG.visible);
		wasVisible.set(scoreText, scoreText.visible);
		wasVisible.set(diffText, diffText.visible);
		
		scoreBG.visible = false;
		scoreText.visible = false;
		diffText.visible = false;
	}

	public function restoreNonPreviewElements()
	{
		for (i in 0...grpSongs.length) {
			if (i != curSelected) {
				if (wasVisible.exists(grpSongs.members[i])) {
					grpSongs.members[i].visible = wasVisible.get(grpSongs.members[i]);
				}
			}
		}
		
		for (i in 0...iconArray.length) {
			if (i != curSelected) {
				if (wasVisible.exists(iconArray[i])) {
					iconArray[i].visible = wasVisible.get(iconArray[i]);
				}
			}
		}
		if (wasVisible.exists(scoreBG)) scoreBG.visible = wasVisible.get(scoreBG);
		if (wasVisible.exists(scoreText)) scoreText.visible = wasVisible.get(scoreText);
		if (wasVisible.exists(diffText)) diffText.visible = wasVisible.get(diffText);
	}
	override function destroy()
    {
		instance = null;
        super.destroy();
    }
}

class SongMetadata
{
	public var songName:String = "";
	public var week:Int = 0;
	public var songCharacter:String = "";
	public var color:Int = -7179779;
	public var folder:String = "";

	public function new(song:String, week:Int, songCharacter:String, color:Int)
	{
		this.songName = song;
		this.week = week;
		this.songCharacter = songCharacter;
		this.color = color;
		this.folder = Paths.currentModDirectory;
		if(this.folder == null) this.folder = '';
	}
}