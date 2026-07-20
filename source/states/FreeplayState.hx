package states;

import substates.ResetScoreSubState;
import substates.GameplayChangersSubstate;
import substates.ScoreHistorySubstate;
import substates.ModSelectSubstate;

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
import mohong.TraceManager;
import flixel.input.keyboard.FlxKey;
#if MODS_ALLOWED
import sys.FileSystem;
#end

using StringTools;

class FreeplayState extends MusicBeatState
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

	// 新增：错误提示相关变量
	public var missingTextBG:FlxSprite;
	public var missingText:FlxText;
	public var isShowingError:Bool = false;

	// === NEW: Mod folder filtering ===
	public static inline var ALL_FILTER:String = '__ALL__'; // Sentinel for "show all songs"
	public var modList:Array<String> = [];        // Unique mod folders (sorted, vanilla first, ALL_FILTER first)
	public var filteredSongIndices:Array<Int> = []; // Maps visual index → songs array index
	static var curSelectedMod:Int = 0;            // Persists across state recreations
	static var lastSelectedModFolder:String = ALL_FILTER;  // Folder name for restoring after state rebuild; starts at "All"
	var modFilterText:FlxText;                    // Shows current filter name

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
				// Pass the week's mod folder to identify which mod this song belongs to
				var weekModFolder:String = (leWeek.folder != null && leWeek.folder.length > 0) ? leWeek.folder : '';
				addSong(song[0], i, song[1], FlxColor.fromRGB(colors[0], colors[1], colors[2]), weekModFolder);
			}
		}
		// The globally active mod (selected via MainMenuState's ModSelectSubstate)
		// always determines asset loading.  Freeplay's own mod filter is only
		// for song display — it does NOT change which mod's assets are used.
		// However, if the Freeplay filter is set to a specific mod folder, we
		// must point Paths.currentModDirectory there so PlayState can resolve
		// the mod's audio/images when the user enters a song.
		Paths.currentModDirectory = MainMenuState.selectedModFolder;

		// === Build mod folder list and restore last selected mod ===
		buildModList();
		FlxG.keys.preventDefaultKeys.remove(TAB);

		// Apply the restored filter: for ALL_FILTER keep the MainMenu mod,
		// for a specific mod switch to it.
		if (curSelectedMod >= 0 && curSelectedMod < modList.length)
		{
			var selMod:String = modList[curSelectedMod];
			if (selMod != ALL_FILTER) Paths.currentModDirectory = selMod;
		}

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

		// === Create mod filter header bar ===
		createModFilterUI();

		// === Only create song items for the currently selected mod folder ===
		rebuildFilteredSongs();
		WeekData.setDirectoryFromWeek();

		// Sync the asset directory with Freeplay's own mod filter.
		// This ensures PlayState loads the correct mod resources without touching
		// MainMenuState.selectedModFolder (the "fully loaded mod").
		// NOTE: must be placed AFTER WeekData.setDirectoryFromWeek() which resets to "".
		if (curSelectedMod >= 0 && curSelectedMod < modList.length)
		{
			var selMod:String = modList[curSelectedMod];
			if (selMod != ALL_FILTER) Paths.currentModDirectory = selMod;
		}

		// Always reload background and menu music from the (possibly updated) directory.
		// This also cleanly replaces any music started by PlayStateResultsSubstate / PauseSubState
		// before switching back here, so there is no one-frame "vanilla music" artifact.
		bg.loadGraphic(Paths.image('menuDesat'));
		bg.screenCenter();
		bg.antialiasing = ClientPrefs.data.globalAntialiasing;
		FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
		FlxTween.tween(FlxG.sound.music, {volume: 1}, 0.5);

		scoreText = new FlxText(FlxG.width * 0.7, 5, 0, "", 32);
		scoreText.setFormat(Paths.languageFont(), 32, FlxColor.WHITE, RIGHT);

		scoreBG = new FlxSprite(scoreText.x - 6, 0).makeGraphic(1, 66, 0xFF000000);
		scoreBG.alpha = 0.6;
		add(scoreBG);

		diffText = new FlxText(scoreText.x, scoreText.y + 36, 0, "", 24);
		diffText.font = Paths.font("vcr.ttf"); 
		add(diffText);

		add(scoreText);

		missingTextBG = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		missingTextBG.alpha = 0.6;
		missingTextBG.visible = false;
		add(missingTextBG);
		
		missingText = new FlxText(50, 0, FlxG.width - 100, '', 24);
		missingText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		missingText.scrollFactor.set();
		missingText.visible = false;
		add(missingText);

		if(curSelected >= filteredSongIndices.length) curSelected = 0;
		var initSong = getCurrentSong();
		if(initSong != null) {
			bg.color = initSong.color;
			intendedColor = bg.color;
		}


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
		var leText:String = Language.get("FreeplayState.leText", "Press X to listen to the Song / Press C to open the Gameplay Changers Menu / Press Y to Reset your Score and Accuracy. / Press V to view the Score History.");
		var size:Int = 16;

		#if android
		var leText:String = Language.get("FreeplayState.leText.android", "Press X to listen to the Song / Press C to open the Gameplay Changers Menu / Press Y to Reset your Score and Accuracy. / Press V to view the Score History.");
		var size:Int = 16;
		#end

		#else
		var leText:String = Language.get("FreeplayState.leText.NOTRELOAD_ALL", "Press CTRL to open the Gameplay Changers Menu / Press RESET to Reset your Score and Accuracy. / Press H to view the Score History.");
		var size:Int = 18;

		#if android
		var leText:String = Language.get("FreeplayState.leText.NOTRELOAD_ALL.android", "Press C to open the Gameplay Changers Menu / Press Y to Reset your Score and Accuracy. / Press V to view the Score History.");
		var size:Int = 16;
		#end

		#end
		var text:FlxText = new FlxText(textBG.x, textBG.y + 4, FlxG.width, leText, size);
		text.setFormat(Paths.languageFont(), size, FlxColor.WHITE, RIGHT);
		text.scrollFactor.set();
		add(text);
		#if android
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


	override function closeSubState() {
		if (pendingModIndex >= 0)
		{
			applyPendingModSelection();
		}
		changeSelection(0, false);
		persistentUpdate = true;
		canInput = true;
		#if android
		removeVirtualPad();
		addVirtualPad(LEFT_FULL, A_B_C_V_X_Y);
		#end
		super.closeSubState();
	}

	public function addSong(songName:String, weekNum:Int, songCharacter:String, color:Int, ?modFolder:String = '')
	{
		songs.push(new SongMetadata(songName, weekNum, songCharacter, color, modFolder));
	}

	// === NEW: Mod folder filtering functions ===

	/** Get the real songs[] index for the currently selected filtered item */
	function getRealSelectedIndex():Int
	{
		if (filteredSongIndices.length == 0) return -1;
		if (curSelected < 0 || curSelected >= filteredSongIndices.length) return -1;
		return filteredSongIndices[curSelected];
	}

	/** Get the current SongMetadata from the filtered list */
	function getCurrentSong():SongMetadata
	{
		var idx = getRealSelectedIndex();
		return (idx >= 0) ? songs[idx] : null;
	}

	function buildModList()
	{
		modList = [];
		// "All Songs" filter goes first
		modList.push(ALL_FILTER);
		for (song in songs)
		{
			var mf:String = (song.modFolder != null && song.modFolder.length > 0) ? song.modFolder : '';
			if (!modList.contains(mf))
				modList.push(mf);
		}
		// Sort the non-sentinel entries: vanilla first, then alphabetically
		var tail:Array<String> = modList.filter(function(v) return v != ALL_FILTER);
		tail.sort(function(a, b) {
			if (a == '') return -1;
			if (b == '') return 1;
			return (a < b) ? -1 : ((a > b) ? 1 : 0);
		});
		modList = [ALL_FILTER].concat(tail);

		// Restore previously selected mod:
		// - If lastSelectedModFolder is ALL_FILTER (initial/default), stay on "All" (index 0).
		// - Otherwise try to restore the exact folder the user picked (including '' for Vanilla).
		curSelectedMod = 0;
		if (lastSelectedModFolder != ALL_FILTER)
		{
			var idx = modList.indexOf(lastSelectedModFolder);
			if (idx >= 0) curSelectedMod = idx;
		}
		if (curSelectedMod >= modList.length) curSelectedMod = 0;
	}

	function createModFilterUI()
	{
		// Current filter name (top-left)
		modFilterText = new FlxText(10, 10, 0, '', 20);
		modFilterText.setFormat(Paths.languageFont(), 20, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		modFilterText.borderSize = 1.5;
		modFilterText.scrollFactor.set();
		add(modFilterText);

		// Small hint for mod switching
		var hint = new FlxText(FlxG.width - 5, FlxG.height - 50, 0,
			#if android
			Language.get('Mod.hint.android', '[G] Switch Mod'),
			#else
			Language.get('Mod.hint', '[TAB] Switch Mod'),
			#end
			16);
		hint.setFormat(Paths.languageFont(), 16, FlxColor.WHITE, RIGHT);
		hint.alpha = 0.5;
		hint.x = FlxG.width - hint.width - 10;
		add(hint);
	}

	function refreshModFilterUI()
	{
		updateModFilterText();
	}

	// Pending mod switch (set by substate callback, applied in closeSubState)
	var pendingModIndex:Int = -1;

	function openModSelect()
	{
		// Stop preview if playing
		if (playingMusic) stopPreview();

		pendingModIndex = -1;
		persistentUpdate = false;
		var substate = new ModSelectSubstate(
			modList,
			curSelectedMod,
			function(newModIndex:Int) {
				pendingModIndex = newModIndex;
			},
			function() {
				// Cancel - do nothing
			}
		);
		// Freeplay 的模组切换仅用于过滤歌曲列表，不涉及游戏重启，隐藏重启警告
		substate.suppressRestartWarning = true;
		openSubState(substate);
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
		curSelected = 0;
		holdTime = 0;

		// When the user picks a different mod filter via TAB, switch asset
		// loading to that mod so background, character icons, menu music etc.
		// resolve correctly.  This does NOT affect the "fully loaded mod"
		// selected in MainMenuState — that one controls TitleState, window
		// title/icon and other global aspects.
		var modFolder:String = modList[curSelectedMod];
		if (modFolder == ALL_FILTER)
		{
			// "All" filter — keep MainMenu's active mod for asset loading
			Paths.currentModDirectory = MainMenuState.selectedModFolder;
		}
		else
		{
			Paths.currentModDirectory = modFolder;
		}

		// Reload background image from the (possibly new) mod — for ALL_FILTER
		// this stays on MainMenu's mod so the background is consistent.
		bg.loadGraphic(Paths.image('menuDesat'));
		bg.screenCenter();
		bg.antialiasing = ClientPrefs.data.globalAntialiasing;

		// Reload menu music: will pick up mod's freakyMenu.ogg if it exists
		FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
		FlxTween.tween(FlxG.sound.music, {volume: 1}, 0.5);

		// Rebuild song list with the new mod's songs
		rebuildFilteredSongs();
		changeSelection(0, false);
		changeDiff();

		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
	}

	function rebuildFilteredSongs()
	{
		// Clear existing song display
		grpSongs.clear();
		for (icon in iconArray)
		{
			remove(icon);
			icon.destroy();
		}
		iconArray = [];
		mouseOverlapIndex = -1; // Reset mouse tracking to prevent stale index crash

		// Build filtered indices
		var currentModFolder:String = modList[curSelectedMod];
		var isAllFilter:Bool = (currentModFolder == ALL_FILTER);
		filteredSongIndices = [];
		for (i in 0...songs.length)
		{
			if (isAllFilter)
			{
				filteredSongIndices.push(i); // Show ALL songs
			}
			else
			{
				var mf:String = (songs[i].modFolder != null && songs[i].modFolder.length > 0) ? songs[i].modFolder : '';
				if (mf == currentModFolder)
					filteredSongIndices.push(i);
			}
		}

		// Create display items for filtered songs
		var savedModDir:String = Paths.currentModDirectory;
		for (vi in 0...filteredSongIndices.length)
		{
			var realIndex:Int = filteredSongIndices[vi];
			var songData:SongMetadata = songs[realIndex];

			// Use plain song name (mod is shown at top)
			var songText:Alphabet = new Alphabet(90, 325, songData.songName, true);
			songText.isMenuItem = true;
			songText.targetY = vi;
			grpSongs.add(songText);

			var maxWidth = 980;
			if (songText.width > maxWidth)
			{
				songText.scaleX = maxWidth / songText.width;
			}
			songText.snapToPosition();

			// Temporarily switch to the song's original mod folder to load its
			// character icon, then restore the active (fully loaded) mod.
			Paths.currentModDirectory = songData.folder;
			var icon:HealthIcon = new HealthIcon(songData.songCharacter);
			Paths.currentModDirectory = savedModDir;
			icon.sprTracker = songText;
			iconArray.push(icon);
			add(icon);
		}

		if (filteredSongIndices.length > 0)
		{
			if (curSelected >= filteredSongIndices.length) curSelected = filteredSongIndices.length - 1;
			if (curSelected < 0) curSelected = 0;
			bg.color = songs[filteredSongIndices[curSelected]].color;
			intendedColor = bg.color;
		}

		// Update the filter display text
		updateModFilterText();
	}

	function updateModFilterText()
	{
		if (modFilterText == null) return;
		var currentModFolder:String = modList[curSelectedMod];
		var label:String;
		if (currentModFolder == ALL_FILTER)
			label = Language.get("FreeplayState.allMods", "All Mods");
		else
			label = WeekData.getModFolderDisplayName(currentModFolder);
		modFilterText.text = Language.get("FreeplayState.modFilter", "Mod: ") + label;
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
		#if LUA_ALLOWED
		callOnLuas('onUpdate', [elapsed]);
		#end
		#if HSCRIPT_ALLOWED
		callOnHscript('onUpdate', [elapsed]);
		#end

		var curSong = getCurrentSong();
		if(curSong != null) currentsongname = curSong.songName;
		
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
		var history = #if android virtualPad.buttonV.justPressed || #end FlxG.keys.justPressed.H;
		// === Mod folder switching: TAB (PC) / G button (Android) to open selection overlay ===
		if (!playingMusic)
		{
			if (FlxG.keys.justPressed.TAB
				#if android || virtualPad.buttonEx.justPressed #end)
			{
				openModSelect();
				return;
			}
		}
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
		if(filteredSongIndices.length > 1)
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
	

		if (controls.BACK && canInput)
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
		if (space && canInput)
    	{
		var realIdx = getRealSelectedIndex();
        if (instPlaying != realIdx && !playingMusic)
        {
            startPreview();
        }
        else if (instPlaying == realIdx && playingMusic)
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
		else if(history)
		{
			canInput = false;
			persistentUpdate = false;
    		openSubState(new ScoreHistorySubstate(getCurrentSong().songName, curDifficulty));
		}
		else if(space && canInput)
		{
			var realIdx = getRealSelectedIndex();
			if(instPlaying != realIdx)
			{
				#if PRELOAD_ALL
				destroyFreeplayVocals();
				FlxG.sound.music.volume = 0;

				// Temporarily switch to the song's mod folder for chart/voice loading,
				// then restore the globally active mod.
				var prevModDir:String = Paths.currentModDirectory;
				Paths.currentModDirectory = getCurrentSong().folder;
				var poop:String = Highscore.formatSong(getCurrentSong().songName.toLowerCase(), curDifficulty);
				PlayState.SONG = Song.loadFromJson(poop, getCurrentSong().songName.toLowerCase());
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
				Paths.currentModDirectory = prevModDir;
				instPlaying = realIdx;
				#end
			}
		}
		else if (accepted && canInput && !isShowingError)
		{
			PlayState.replayMode = false;
			var selectedSong:Alphabet = grpSongs.members[curSelected];
			var icon:HealthIcon = iconArray[curSelected]; 
			
			var curSongData = getCurrentSong();
			var songLowercase:String = Paths.formatToSongPath(curSongData.songName);
			var poop:String = Highscore.formatSong(songLowercase, curDifficulty);
			
			// Switch to the song's own mod folder so chart JSON loads correctly.
			// DO NOT restore prevModDir after success — PlayState must keep this
			// mod directory to resolve the mod's audio/images during gameplay.
			// FreeplayState.create() will re-sync the directory when we return.
			var prevModDir:String = Paths.currentModDirectory;
			Paths.currentModDirectory = curSongData.folder;
			try
			{
				var testSong = Song.loadFromJson(poop, songLowercase);
				if (testSong == null)
				{
					Paths.currentModDirectory = prevModDir;
					throw "Song data is null";
				}
				PlayState.SONG = testSong;
				PlayState.isStoryMode = false;
				PlayState.storyDifficulty = curDifficulty;
				// Intentionally NOT restoring prevModDir — PlayState needs this.
			}
			catch(e:Dynamic)
			{
				Paths.currentModDirectory = prevModDir;
				TraceManager.error('trace.freeplay.loadError', 'ERROR! {}', [e]);
				var errorStr:String = e.toString();
				if (Std.string(e).startsWith('[file_contents,assets/data/')) 
					errorStr = 'Missing file: ' + errorStr.substring(34, errorStr.length-1);
				else if (errorStr == "Song data is null")
					errorStr = "Song data is empty or corrupted";
				
				missingText.text = 'ERROR WHILE LOADING CHART:\n$errorStr';
				missingText.screenCenter(Y);
				missingText.visible = true;
				missingTextBG.visible = true;
				FlxG.sound.play(Paths.sound('cancelMenu'));
				
				isShowingError = true;
				canInput = true;
				persistentUpdate = true;
				return;
			}
			
			canInput = false;
			persistentUpdate = false;
			FlxG.sound.play(Paths.sound('confirmMenu'), 0.7);
			
			TraceManager.info('trace.freeplay.currentWeek', 'CURRENT WEEK: {}', [WeekData.getWeekFileName()]);
				if(colorTween != null) {
				colorTween.cancel();
			}
						
			missingText.visible = false;
			missingTextBG.visible = false;

			#if android
			// 在切换状态前移除虚拟手柄，防止按键状态残留到 PlayState
			removeVirtualPad();
			#end

			if (FlxG.keys.pressed.SHIFT){
			if(ClientPrefs.data.newchartingstate)
			LoadingState.loadAndSwitchState(new editors.NewChartingState());
			else
				LoadingState.loadAndSwitchState(new editors.ChartingState());
			}else{
				LoadingState.loadAndSwitchState(new PlayState());
			}

			FlxG.sound.music.volume = 0;
								
			destroyFreeplayVocals();

			for (i in 0...grpSongs.length) {
				if(i != curSelected) {
					FlxTween.tween(grpSongs.members[i], {
						alpha: 0,
						x: grpSongs.members[i].x + 200
					}, 0.8, {ease: FlxEase.quadOut});
				}
			}

			trace(poop);
		}
		else if(#if android virtualPad.buttonY.justPressed ||#end controls.RESET)
		{
			persistentUpdate = false;
			var resetSong = getCurrentSong();
			openSubState(new ResetScoreSubState(resetSong.songName, curDifficulty, resetSong.songCharacter));
			FlxG.sound.play(Paths.sound('scrollMenu'));
		}
		#if HSCRIPT_ALLOWED
		callOnHscript('onUpdatePost', [elapsed]);
		#end
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

		var curSong = getCurrentSong();
		#if !switch
		if(curSong != null) {
			intendedScore = Highscore.getScore(curSong.songName, curDifficulty);
			intendedRating = Highscore.getRating(curSong.songName, curDifficulty);
		}
		#end

		PlayState.storyDifficulty = curDifficulty;
		if (CoolUtil.difficulties.length == 1) diffText.text = '' + CoolUtil.difficultyString() + ' ';
		else 
		diffText.text = '< ' + CoolUtil.difficultyString() + ' >';

		positionHighscore();
		missingText.visible = false;
		missingTextBG.visible = false;
		isShowingError = false;
	}

	public function changeSelection(change:Int = 0, playSound:Bool = true)
	{
		
		if(playSound) FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		curSelected += change;

		var maxVis:Int = filteredSongIndices.length;
		if (curSelected < 0)
			curSelected = maxVis - 1;
		if (curSelected >= maxVis)
			curSelected = 0;

		var curSong = getCurrentSong();
		if(curSong == null) return;
			
		var newColor:Int = curSong.color;
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
		
		missingText.visible = false;
		missingTextBG.visible = false;
		isShowingError = false;
		
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
		if(curSong != null) {
			intendedScore = Highscore.getScore(curSong.songName, curDifficulty);
			intendedRating = Highscore.getRating(curSong.songName, curDifficulty);
		}
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

		// NOTE: Do NOT set Paths.currentModDirectory here!
		// The globally active mod (selected via ModSelectSubstate / MainMenuState)
		// must stay intact. Song-specific mod folders are only used temporarily
		// when actually loading chart/voice data (see preview & accept handlers).
		PlayState.storyWeek = curSong.week;

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
		var previewSong = getCurrentSong();

		// Temporarily switch to the song's mod for chart/voice loading,
		// then restore the globally active mod.
		var prevModDir:String = Paths.currentModDirectory;
		Paths.currentModDirectory = previewSong.folder;
		var poop:String = Highscore.formatSong(previewSong.songName.toLowerCase(), curDifficulty);
		PlayState.SONG = Song.loadFromJson(poop, previewSong.songName.toLowerCase());
		
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
		Paths.currentModDirectory = prevModDir;
		#end
		
		instPlaying = getRealSelectedIndex();
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
			var pSong = getCurrentSong();
			previewSongTxt.text = 'PLAYING: ' + (pSong != null ? pSong.songName : '?') + ' (PAUSED)';
		}
	}

	public function resumePreview()
	{
		if (playingMusic && paused)
		{
			paused = false;
			FlxG.sound.music.resume();
			if (vocals != null) vocals.resume();
			var pSong = getCurrentSong();
			previewSongTxt.text = 'PLAYING: ' + (pSong != null ? pSong.songName : '?');
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
		var pSong = getCurrentSong();
		var pName:String = (pSong != null) ? pSong.songName : '?';
		if (paused)
			previewSongTxt.text = 'PLAYING: ' + pName + rateText + ' (PAUSED)';
		else
			previewSongTxt.text = 'PLAYING: ' + pName + rateText;
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
	public var modFolder:String = "";

	public function new(song:String, week:Int, songCharacter:String, color:Int, ?modFolder:String = '')
	{
		this.songName = song;
		this.week = week;
		this.songCharacter = songCharacter;
		this.color = color;
		this.folder = Paths.currentModDirectory;
		if(this.folder == null) this.folder = '';
		this.modFolder = (modFolder != null && modFolder.length > 0) ? modFolder : this.folder;
	}
}