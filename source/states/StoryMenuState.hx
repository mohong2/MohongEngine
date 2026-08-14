package states;

import backend.seiun.ui.*;
import substates.ResetScoreSubState;
import substates.GameplayChangersSubstate;
import substates.ModSelectSubstate;
#if cpp
import Discord.DiscordClient;
#end
import flixel.FlxSubState;
import flixel.addons.transition.FlxTransitionableState;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.group.FlxGroup;
import flixel.group.FlxGroup.FlxTypedGroup;
import lime.net.curl.CURLCode;
import flixel.graphics.FlxGraphic;
import flixel.util.FlxTimer;
import WeekData;
import flixel.input.keyboard.FlxKey;

using StringTools;

class StoryMenuState extends SeiunMenuState
{
	public static var weekCompleted:Map<String, Bool> = new Map<String, Bool>();

	public var scoreText:FlxText;

	private static var lastDifficultyName:String = '';
	public var curDifficulty:Int = 1;

	public var txtWeekTitle:FlxText;
	public var bgSprite:FlxSprite;

	private static var curWeek:Int = 0;

	public var txtTracklist:FlxText;

	public var grpWeekText:FlxTypedGroup<MenuItem>;
	public var grpWeekCharacters:FlxTypedGroup<MenuCharacter>;

	public var grpLocks:FlxTypedGroup<FlxSprite>;

	public var difficultySelectors:FlxGroup;
	public var sprDifficulty:FlxSprite;
	public var leftArrow:FlxSprite;
	public var rightArrow:FlxSprite;

	public var loadedWeeks:Array<WeekData> = [];

	// === NEW: Mod folder filtering ===
	public var modList:Array<String> = [];
	static var curSelectedMod:Int = 0;
	static var lastSelectedModFolder:String = '';
	var pendingModIndex:Int = -1;

	// === Seiun menu animation layers ===
	var particleGroup:FlxTypedGroup<FlxSprite>;
	var auroraGlowA:FlxSprite;
	var auroraGlowB:FlxSprite;
	var weekGlows:FlxTypedGroup<FlxSprite>;
	var ambientTimer:Float = 0;

	override function create()
	{
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();

		PlayState.isStoryMode = true;
		WeekData.reloadWeekFiles(true);
		if(curWeek >= WeekData.weeksList.length) curWeek = 0;
		persistentUpdate = persistentDraw = true;

		scoreText = new FlxText(10, 10, 0, "SCORE: 49324858", 36);
		scoreText.setFormat("VCR OSD Mono", 32);

		txtWeekTitle = new FlxText(FlxG.width * 0.7, 10, 0, "", 32);
		txtWeekTitle.setFormat("VCR OSD Mono", 32, FlxColor.WHITE, RIGHT);
		txtWeekTitle.alpha = 0.7;

		var rankText:FlxText = new FlxText(0, 10);
		rankText.text = 'RANK: GREAT';
		rankText.setFormat(Paths.languageFont(), 32);
		rankText.size = scoreText.size;
		rankText.screenCenter(X);

		var ui_tex = Paths.getSparrowAtlas('campaign_menu_UI_assets');
		var bgYellow:FlxSprite = new FlxSprite(0, 56).makeGraphic(FlxG.width, 386, 0xFFF9CF51);
		bgSprite = new FlxSprite(0, 56);
		bgSprite.antialiasing = ClientPrefs.data.globalAntialiasing;

		if (MenuFX.enabled())
		{
			// ── Seiun aurora: warm gold glows behind the week list ──
			auroraGlowA = MenuFX.makeGlow(880, 0xFFF9CF51, 0.28);
			auroraGlowA.blend = ADD;
			auroraGlowA.scrollFactor.set(0, 0);
			auroraGlowA.screenCenter();
			add(auroraGlowA);

			auroraGlowB = MenuFX.makeGlow(720, 0xFFFF8A5C, 0.22);
			auroraGlowB.blend = ADD;
			auroraGlowB.scrollFactor.set(0, 0);
			auroraGlowB.screenCenter();
			add(auroraGlowB);

			// Week halos render behind the week text they highlight.
			weekGlows = new FlxTypedGroup<FlxSprite>();
			add(weekGlows);
		}

		grpWeekText = new FlxTypedGroup<MenuItem>();
		add(grpWeekText);

		var blackBarThingie:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, 56, FlxColor.BLACK);
		add(blackBarThingie);

		grpWeekCharacters = new FlxTypedGroup<MenuCharacter>();

		grpLocks = new FlxTypedGroup<FlxSprite>();
		add(grpLocks);

		#if desktop
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Menus", null);
		#end

		// Build mod folder list first
		buildModFolderList();
		FlxG.keys.preventDefaultKeys.remove(TAB);

		// Restore Paths to the persisted mod selection
		var modFolder:String = modList[curSelectedMod];
		Paths.currentModDirectory = modFolder;
		MenuFX.ensureMenuMusic(1);

		// Create mod filter header
		createModFilterUI();

		// Load weeks for the first mod folder (also creates characters)
		rebuildFilteredWeeks();

		difficultySelectors = new FlxGroup();
		add(difficultySelectors);

		leftArrow = new FlxSprite(grpWeekText.members[0].x + grpWeekText.members[0].width + 10, grpWeekText.members[0].y + 10);
		leftArrow.frames = ui_tex;
		leftArrow.animation.addByPrefix('idle', "arrow left");
		leftArrow.animation.addByPrefix('press', "arrow push left");
		leftArrow.animation.play('idle');
		leftArrow.antialiasing = ClientPrefs.data.globalAntialiasing;
		difficultySelectors.add(leftArrow);

		CoolUtil.difficulties = CoolUtil.defaultDifficulties.copy();
		if(lastDifficultyName == '')
		{
			lastDifficultyName = CoolUtil.defaultDifficulty;
		}
		curDifficulty = Math.round(Math.max(0, CoolUtil.defaultDifficulties.indexOf(lastDifficultyName)));
		
		sprDifficulty = new FlxSprite(0, leftArrow.y);
		sprDifficulty.antialiasing = ClientPrefs.data.globalAntialiasing;
		difficultySelectors.add(sprDifficulty);

		rightArrow = new FlxSprite(leftArrow.x + 376, leftArrow.y);
		rightArrow.frames = ui_tex;
		rightArrow.animation.addByPrefix('idle', 'arrow right');
		rightArrow.animation.addByPrefix('press', "arrow push right", 24, false);
		rightArrow.animation.play('idle');
		rightArrow.antialiasing = ClientPrefs.data.globalAntialiasing;
	 	difficultySelectors.add(rightArrow);

		add(bgYellow);
		add(bgSprite);
		add(grpWeekCharacters);

		var tracksSprite:FlxSprite = new FlxSprite(FlxG.width * 0.07, bgSprite.y + 425).loadGraphic(Paths.image('Menu_Tracks'));
		tracksSprite.antialiasing = ClientPrefs.data.globalAntialiasing;
		add(tracksSprite);

		txtTracklist = new FlxText(FlxG.width * 0.05, tracksSprite.y + 60, 0, "", 32);
		txtTracklist.alignment = CENTER;
		txtTracklist.font = rankText.font;
		txtTracklist.color = 0xFFe55777;
		add(txtTracklist);
		// add(rankText);
		add(scoreText);
		add(txtWeekTitle);

		// ── Particles: selection bursts + ambient sparkles ──
		if (MenuFX.enabled())
		{
			particleGroup = new FlxTypedGroup<FlxSprite>();
			add(particleGroup);
		}

		MenuFX.accentColor = 0xFFF9CF51;
		changeWeek();
		changeDifficulty();
		updateArrowVisibility();

		// ── Entry animation: week items fade in with a stagger. No x motion,
		//    so their screen-centered position stays fixed. ──
		for (i in 0...grpWeekText.length)
		{
			var it:MenuItem = grpWeekText.members[i];
			var delay:Float = Math.min(Math.abs(i - curWeek) * 0.04, 0.35);
			FlxTween.cancelTweensOf(it, ['alpha']);
			it.alpha = 0;
			FlxTween.tween(it, {alpha: (i == curWeek) ? 1 : 0.6}, 0.35, {startDelay: delay, ease: FlxEase.sineOut});
		}
		for (char in grpWeekCharacters.members)
		{
			if (char.character == '') continue;
			var bx:Float = char.scale.x;
			var by:Float = char.scale.y;
			char.alpha = 0;
			char.scale.set(bx * 0.8, by * 0.8);
			FlxTween.tween(char, {alpha: 1}, 0.35, {ease: FlxEase.sineOut});
			FlxTween.tween(char.scale, {x: bx, y: by}, 0.5, {ease: FlxEase.backOut});
		}
		#if (TOUCH_CONTROLS || desktop)
		addVirtualPad(LEFT_FULL, A_B_C_V_X_Y);
		#end
		super.create();

		#if LUA_ALLOWED
		initLuaScripts();
		setOnLuas('controls', controls);
		setOnLuas('state', this);
		callOnLuas('onCreatePost', []);
		#end
	}

	private function updateArrowVisibility():Void {
    if (CoolUtil.difficulties.length == 1) 
	{
	leftArrow.visible = false;
    rightArrow.visible = false;
	}
	else
	{
    leftArrow.visible = true;
    rightArrow.visible = true;
	}
}


	// === NEW: Mod folder filtering functions ===

	function buildModFolderList()
	{
		modList = WeekData.getModFolders();
		// Restore previously selected mod from static folder name
		curSelectedMod = 0;
		if (lastSelectedModFolder.length > 0)
		{
			var idx = modList.indexOf(lastSelectedModFolder);
			if (idx >= 0) curSelectedMod = idx;
		}
		if (curSelectedMod >= modList.length) curSelectedMod = 0;
	}

	function createModFilterUI()
	{
		// Small hint for mod switching
		var hint = new FlxText(FlxG.width - 5, FlxG.height - 30, 0,
			ClientPrefs.touchUIEnabled()
				? Language.get('Mod.hint.android', '[G] Switch Mod')
				: Language.get('Mod.hint', '[TAB] Switch Mod'),
			16);
		hint.setFormat(Paths.languageFont(), 16, FlxColor.WHITE, RIGHT);
		hint.alpha = 0.5;
		hint.x = FlxG.width - hint.width - 10;
		add(hint);
	}

	function refreshModFilterUI()
	{
		// No top bar to update
	}

	function openModSelect()
	{
		pendingModIndex = -1;
		persistentUpdate = false;
		openSubState(new ModSelectSubstate(
			modList,
			curSelectedMod,
			function(newModIndex:Int) {
				pendingModIndex = newModIndex;
			},
			function() {
				// Cancel
			}
		));
	}

	function applyPendingModSelection()
	{
		if (pendingModIndex < 0 || pendingModIndex >= modList.length || pendingModIndex == curSelectedMod)
		{
			pendingModIndex = -1;
			return;
		}

		curSelectedMod = pendingModIndex;
		lastSelectedModFolder = modList[curSelectedMod]; // Save for next state creation
		pendingModIndex = -1;
		curWeek = 0;

		var modFolder:String = modList[curSelectedMod];
		Paths.currentModDirectory = modFolder;

		// Reload menu music from the mod
		MenuFX.playMenuMusic(1);

		rebuildFilteredWeeks();
		// changeWeek(0) will reload the background based on the current week
		changeWeek(0);
		changeDifficulty();
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
	}

	function rebuildFilteredWeeks()
	{
		var currentModFolder:String = modList[curSelectedMod];

		// Clear existing week display
		grpWeekText.clear();
		grpLocks.clear();
		grpWeekCharacters.clear();
		if (weekGlows != null) weekGlows.clear();
		loadedWeeks = [];

		// Collect weeks from WeekData that belong to this mod folder
		var allWeeks = WeekData.getWeeksForModFolder(currentModFolder);
		var num:Int = 0;

		for (weekName in allWeeks)
		{
			var weekFile:WeekData = WeekData.weeksLoaded.get(weekName);
			if (weekFile == null) continue;

			var isLocked:Bool = weekIsLocked(weekName);
			if (!isLocked || !weekFile.hiddenUntilUnlocked)
			{
				loadedWeeks.push(weekFile);

				WeekData.setDirectoryFromWeek(weekFile);
				var weekThing:MenuItem = new MenuItem(0, bgSprite.y + 396, weekName);
				weekThing.y += ((weekThing.height + 20) * num);
				weekThing.targetY = num;
				grpWeekText.add(weekThing);

				weekThing.screenCenter(X);
				weekThing.antialiasing = ClientPrefs.data.globalAntialiasing;

				if (weekGlows != null)
				{
					// Soft glow behind every week item (selected one pulses)
					var glow:FlxSprite = MenuFX.makeGlow(300, 0xFFFFE9A0, 0.45);
					glow.scale.set(1.45, 0.85);
					glow.updateHitbox();
					glow.blend = ADD;
					glow.visible = false;
					glow.ID = grpWeekText.members.indexOf(weekThing);
					weekGlows.add(glow);
				}

				if (isLocked)
				{
					var ui_tex = Paths.getSparrowAtlas('campaign_menu_UI_assets');
					var lock:FlxSprite = new FlxSprite(weekThing.width + 10 + weekThing.x);
					lock.frames = ui_tex;
					lock.animation.addByPrefix('lock', 'lock');
					lock.animation.play('lock');
					lock.ID = grpWeekText.members.indexOf(weekThing);
					lock.antialiasing = ClientPrefs.data.globalAntialiasing;
					grpLocks.add(lock);
				}
				num++;
			}
		}

		if (loadedWeeks.length > 0)
		{
			curWeek = 0;
			if (curWeek >= loadedWeeks.length) curWeek = loadedWeeks.length - 1;

			WeekData.setDirectoryFromWeek(loadedWeeks[curWeek]);

			// Recreate week characters
			var charArray:Array<String> = loadedWeeks[curWeek].weekCharacters;
			for (char in 0...3)
			{
				var weekCharacterThing:MenuCharacter = new MenuCharacter((FlxG.width * 0.25) * (1 + char) - 150, charArray[char]);
				weekCharacterThing.y += 70;
				grpWeekCharacters.add(weekCharacterThing);
			}
		}
	}

	override function closeSubState() {
		if (pendingModIndex >= 0)
		{
			applyPendingModSelection();
		}
		persistentUpdate = true;
		changeWeek();
		changeDifficulty();
		refreshModFilterUI();
		#if (TOUCH_CONTROLS || desktop)
		removeVirtualPad();
		addVirtualPad(LEFT_FULL, A_B_C_V_X_Y);
		#end
		super.closeSubState();
	}

	override function update(elapsed:Float)
	{
		#if LUA_ALLOWED
		callOnLuas('onUpdate', [elapsed]);
		#end
		#if HSCRIPT_ALLOWED
		callOnHscript('onUpdate', [elapsed]);
		#end

		updateArrowVisibility();
		// scoreText.setFormat('VCR OSD Mono', 32);
		lerpScore = Math.floor(FlxMath.lerp(lerpScore, intendedScore, CoolUtil.boundTo(elapsed * 30, 0, 1)));
		if(Math.abs(intendedScore - lerpScore) < 10) lerpScore = intendedScore;

		scoreText.text = "WEEK SCORE:" + lerpScore;

		// FlxG.watch.addQuick('font', scoreText.font);

		if (!movedBack && !selectedWeek)
		{
			// === Mod folder switching: TAB (PC) / G button (Android) to open selection overlay ===
			if (FlxG.keys.justPressed.TAB
				#if (TOUCH_CONTROLS || desktop) || (virtualPad != null && virtualPad.buttonEx.justPressed) #end)
			{
				openModSelect();
			}

			// Skip week navigation when mod select is open
			if (persistentUpdate == false) // substate is open
			{
				super.update(elapsed);
				return;
			}

			var upP = controls.UI_UP_P;
			var downP = controls.UI_DOWN_P;
			if (upP)
			{
				changeWeek(-1);
				FlxG.sound.play(Paths.sound('scrollMenu'));
			}

			if (downP)
			{
				changeWeek(1);
				FlxG.sound.play(Paths.sound('scrollMenu'));
			}

			if(FlxG.mouse.wheel != 0)
			{
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
				changeWeek(-FlxG.mouse.wheel);
				changeDifficulty();
			}

			if (controls.UI_RIGHT)
				rightArrow.animation.play('press')
			else
				rightArrow.animation.play('idle');

			if (controls.UI_LEFT)
				leftArrow.animation.play('press');
			else
				leftArrow.animation.play('idle');

			if (controls.UI_RIGHT_P)
				changeDifficulty(1);
			else if (controls.UI_LEFT_P)
				changeDifficulty(-1);
			else if (upP || downP)
				changeDifficulty();

			if(#if (TOUCH_CONTROLS || desktop) (virtualPad != null && virtualPad.buttonX.justPressed) || #end FlxG.keys.justPressed.CONTROL)
			{
				persistentUpdate = false;
				openSubState(new GameplayChangersSubstate());
			}
			else if(#if (TOUCH_CONTROLS || desktop) (virtualPad != null && virtualPad.buttonY.justPressed) || #end controls.RESET)
			{
				persistentUpdate = false;
				openSubState(new ResetScoreSubState('', curDifficulty, '', curWeek));
				//FlxG.sound.play(Paths.sound('scrollMenu'));
			}
			else if (controls.ACCEPT)
			{
				selectWeek();
			}
		}

		if (controls.BACK && !movedBack && !selectedWeek)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			movedBack = true;
			// Seamless exit: week items fly out, then switch without a black fade
			for (i in 0...grpWeekText.length)
			{
				var it:MenuItem = grpWeekText.members[i];
				var delay:Float = (grpWeekText.length - 1 - i) * 0.03;
				FlxTween.tween(it, {alpha: 0, x: it.x - 300}, 0.28, {startDelay: delay, ease: FlxEase.quadIn});
			}
			for (char in grpWeekCharacters.members)
				FlxTween.tween(char, {alpha: 0}, 0.24, {ease: FlxEase.quadIn});
			new FlxTimer().start(0.42, function(tmr:FlxTimer)
			{
				MenuFX.menuSwitch(new MainMenuState());
			});
		}

		#if LUA_ALLOWED
		callOnLuas('onUpdatePost', [elapsed]);
		#end
		#if HSCRIPT_ALLOWED
		callOnHscript('onUpdatePost', [elapsed]);
		#end
		super.update(elapsed);

		// ── Seiun menu animations ──
		if (auroraGlowA != null)
		{
			var t:Float = MenuFX.time;
			MenuFX.driftGlow(auroraGlowA, t, FlxG.width * 0.45, FlxG.height * 0.4, 130, 60, 0.32, 0.26, 0, 0, 0.24, 0.07, 0.46, 0, 0xFFF9CF51, 0.05);
			MenuFX.driftGlow(auroraGlowB, t, FlxG.width * 0.75, FlxG.height * 0.62, 115, 60, 0.21, 0.3, 1.8, 0.9, 0.18, 0.06, 0.4, 0.8, 0xFFFF8A5C, 0.04);
		}

		// Week item glows follow the (lerped) item positions
		if (weekGlows != null)
		{
			for (i in 0...weekGlows.length)
			{
				var glow:FlxSprite = weekGlows.members[i];
				if (i >= grpWeekText.length) continue;
				var item:MenuItem = grpWeekText.members[i];
				var isSel:Bool = (i == curWeek);
				glow.visible = isSel;
				if (isSel)
				{
					glow.x = item.x + item.width * 0.5 - glow.width * glow.scale.x * 0.5;
					glow.y = item.y + item.height * 0.5 - glow.height * glow.scale.y * 0.5;
				}
			}
		}

		// Ambient sparkles drifting in the background
		ambientTimer += elapsed;
		if (ambientTimer > 0.18)
		{
			ambientTimer = 0;
			MenuFX.ambientSparkle(particleGroup,
				FlxG.random.float(0, FlxG.width),
				FlxG.random.float(FlxG.height * 0.1, FlxG.height * 0.9),
				FlxColor.fromRGB(255, 240, 200),
				FlxG.random.float(3, 6));
		}

		grpLocks.forEach(function(lock:FlxSprite)
		{
			lock.y = grpWeekText.members[lock.ID].y;
			lock.visible = (lock.y > FlxG.height / 2);
		});
	}

	var movedBack:Bool = false;
	var selectedWeek:Bool = false;
	var stopspamming:Bool = false;

	function selectWeek()
	{
		#if HSCRIPT_ALLOWED
		callOnHscript('onSelectWeek', []);
		#end
		if (!weekIsLocked(loadedWeeks[curWeek].fileName))
		{
			if (stopspamming == false)
			{
				FlxG.sound.play(Paths.sound('confirmMenu'));
				MenuFX.screenFlash(FlxG.camera, 0xFFFFFFFF, 0.42, 0.5);
				MenuFX.punchZoom(0.06);
				var selItem:MenuItem = grpWeekText.members[curWeek];
				MenuFX.burstParticles(particleGroup, selItem.x + selItem.width * 0.5, selItem.y + selItem.height * 0.5, 0xFFFFE9A0, 24, 340);

				grpWeekText.members[curWeek].startFlashing();

				for (char in grpWeekCharacters.members)
				{
					if (char.character != '' && char.hasConfirmAnimation)
					{
						char.animation.play('confirm');
					}
				}
				stopspamming = true;
			}

			// We can't use Dynamic Array .copy() because that crashes HTML5, here's a workaround.
			var songArray:Array<String> = [];
			var leWeek:Array<Dynamic> = loadedWeeks[curWeek].songs;
			for (i in 0...leWeek.length) {
				songArray.push(leWeek[i][0]);
			}

			// Nevermind that's stupid lmao
			PlayState.storyPlaylist = songArray;
			PlayState.isStoryMode = true;
			selectedWeek = true;

			var diffic = CoolUtil.getDifficultyFilePath(curDifficulty);
			if(diffic == null) diffic = '';

			PlayState.storyDifficulty = curDifficulty;

			PlayState.SONG = Song.loadFromJson(PlayState.storyPlaylist[0].toLowerCase() + diffic, PlayState.storyPlaylist[0].toLowerCase());
			PlayState.campaignScore = 0;
			PlayState.campaignMisses = 0;
			new FlxTimer().start(1, function(tmr:FlxTimer)
			{
				LoadingState.loadAndSwitchState(new PlayState(), true);
				FreeplayState.destroyFreeplayVocals();
			});
		} else {
			FlxG.sound.play(Paths.sound('cancelMenu'));
		}
	}

	var tweenDifficulty:FlxTween;
	function changeDifficulty(change:Int = 0):Void
	{
		#if HSCRIPT_ALLOWED
		callOnHscript('onChangeDifficulty', [change]);
		#end
		curDifficulty += change;

		if (curDifficulty < 0)
			curDifficulty = CoolUtil.difficulties.length-1;
		if (curDifficulty >= CoolUtil.difficulties.length)
			curDifficulty = 0;

		WeekData.setDirectoryFromWeek(loadedWeeks[curWeek]);

		var diff:String = CoolUtil.difficulties[curDifficulty];
		var newImage:FlxGraphic = Paths.languageImage('menudifficulties/' + Paths.formatToSongPath(diff));
		//trace(Paths.currentModDirectory + ', menudifficulties/' + Paths.formatToSongPath(diff));

		if(sprDifficulty.graphic != newImage)
		{
			sprDifficulty.loadGraphic(newImage);
			sprDifficulty.x = leftArrow.x + 60;
			sprDifficulty.x += (308 - sprDifficulty.width) / 3;
			sprDifficulty.alpha = 0;
			sprDifficulty.y = leftArrow.y - 15;

			if(tweenDifficulty != null) tweenDifficulty.cancel();
			tweenDifficulty = FlxTween.tween(sprDifficulty, {y: leftArrow.y + 15, alpha: 1}, 0.07, {onComplete: function(twn:FlxTween)
			{
				tweenDifficulty = null;
			}});
		}
		lastDifficultyName = diff;

		#if !switch
		intendedScore = Highscore.getWeekScore(loadedWeeks[curWeek].fileName, curDifficulty);
		#end
	}

	var lerpScore:Int = 0;
	var intendedScore:Int = 0;

	function changeWeek(change:Int = 0):Void
	{
		#if HSCRIPT_ALLOWED
		callOnHscript('onChangeWeek', [change]);
		#end
		curWeek += change;
		if (curWeek >= loadedWeeks.length)
			curWeek = 0;
		if (curWeek < 0)
			curWeek = loadedWeeks.length - 1;

		var leWeek:WeekData = loadedWeeks[curWeek];
		WeekData.setDirectoryFromWeek(leWeek);

		var leName:String = leWeek.storyName;
		txtWeekTitle.text = leName.toUpperCase();
		txtWeekTitle.x = FlxG.width - (txtWeekTitle.width + 10);

		var bullShit:Int = 0;

		var unlocked:Bool = !weekIsLocked(leWeek.fileName);
		for (item in grpWeekText.members)
		{
			item.targetY = bullShit - curWeek;
			if (item.targetY == Std.int(0) && unlocked)
				item.alpha = 1;
			else
				item.alpha = 0.6;
			bullShit++;
		}

		bgSprite.visible = true;
		var assetName:String = leWeek.weekBackground;
		if(assetName == null || assetName.length < 1) {
			bgSprite.visible = false;
		} else {
			bgSprite.loadGraphic(Paths.image('menubackgrounds/menu_' + assetName));
		}
		PlayState.storyWeek = curWeek;

		CoolUtil.difficulties = CoolUtil.defaultDifficulties.copy();
		var diffStr:String = WeekData.getCurrentWeek().difficulties;
		if(diffStr != null) diffStr = diffStr.trim(); //Fuck you HTML5
		difficultySelectors.visible = unlocked;

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
		updateText();

		// ── Seiun selection juice: camera kick, gold burst, character pop-in ──
		MenuFX.punchZoom(0.02);
		if (curWeek < grpWeekText.length && particleGroup != null)
		{
			var item:MenuItem = grpWeekText.members[curWeek];
			MenuFX.burstParticles(particleGroup, item.x + item.width * 0.5, item.y + item.height * 0.5, 0xFFFFE9A0, 10, 180);
		}
		for (char in grpWeekCharacters.members)
		{
			if (char.character == '') continue;
			var bx:Float = char.scale.x;
			var by:Float = char.scale.y;
			char.scale.set(bx * 0.85, by * 0.85);
			FlxTween.tween(char.scale, {x: bx, y: by}, 0.35, {ease: FlxEase.backOut});
		}
	}

	function weekIsLocked(name:String):Bool {
		var leWeek:WeekData = WeekData.weeksLoaded.get(name);
		return (!leWeek.startUnlocked && leWeek.weekBefore.length > 0 && (!weekCompleted.exists(leWeek.weekBefore) || !weekCompleted.get(leWeek.weekBefore)));
	}

	function updateText()
	{
		var weekArray:Array<String> = loadedWeeks[curWeek].weekCharacters;
		for (i in 0...grpWeekCharacters.length) {
			grpWeekCharacters.members[i].changeCharacter(weekArray[i]);
		}

		var leWeek:WeekData = loadedWeeks[curWeek];
		var stringThing:Array<String> = [];
		for (i in 0...leWeek.songs.length) {
			stringThing.push(leWeek.songs[i][0]);
		}

		txtTracklist.text = '';
		for (i in 0...stringThing.length)
		{
			txtTracklist.text += stringThing[i] + '\n';
		}

		txtTracklist.text = txtTracklist.text.toUpperCase();

		txtTracklist.screenCenter(X);
		txtTracklist.x -= FlxG.width * 0.35;

		#if !switch
		intendedScore = Highscore.getWeekScore(loadedWeeks[curWeek].fileName, curDifficulty);
		#end
	}

	override function onMenuBeat(beat:Int):Void
	{
		if (selectedWeek || movedBack || grpWeekText == null || grpWeekText.length == 0) return;

		if (curWeek >= 0 && curWeek < grpWeekText.length)
		{
			MenuFX.pulse(grpWeekText.members[curWeek], 0.08, 0.16);
			if (weekGlows != null && curWeek < weekGlows.length)
				MenuFX.glowPulse(weekGlows.members[curWeek], 0.9, 0.45, 0.4);
		}
		for (char in grpWeekCharacters.members)
		{
			if (char.character != '') MenuFX.pulse(char, 0.07, 0.18);
		}
		MenuFX.punchZoom(0.012);
	}

	override function destroy()
	{
		if (particleGroup != null)
			for (p in particleGroup) FlxTween.cancelTweensOf(p);
		super.destroy();
	}
}
