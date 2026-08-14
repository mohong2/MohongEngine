package editors;

#if cpp
import Discord.DiscordClient;
#end

import flixel.addons.display.FlxGridOverlay;
import flixel.addons.transition.FlxTransitionableState;
import flixel.system.FlxSound;
import openfl.utils.Assets;
import flixel.ui.FlxButton;
import flash.net.FileFilter;
import lime.system.Clipboard;
import editors.content.FileDialogHandler;
import haxe.Json;
import backend.ui.*;
#if sys
import sys.FileSystem;
#end
import WeekData;

using StringTools;

class WeekEditorState extends MusicBeatState implements PsychUIEventHandler.PsychUIEvent
{
	/** Unsaved changes flag — prompts confirm dialog on exit. */
	public static var staticUnsavedChanges:Bool = false;
	public var unsavedChanges(get, set):Bool;
	function get_unsavedChanges():Bool return staticUnsavedChanges;
	function set_unsavedChanges(v:Bool):Bool
	{
		staticUnsavedChanges = v;
		backend.UnsavedChangesTracker.hasUnsavedChanges = v;
		if(v) backend.UnsavedChangesTracker.currentEditorState = this;
		return staticUnsavedChanges;
	}

	var txtWeekTitle:EditorsText;
	var bgSprite:FlxSprite;
	var lock:FlxSprite;
	var txtTracklist:EditorsText;
	var grpWeekCharacters:FlxTypedGroup<MenuCharacter>;
	var weekThing:MenuItem;
	var missingFileText:EditorsText;

	var weekFile:WeekFile = null;
	public function new(weekFile:WeekFile = null)
	{
		super();
		this.weekFile = WeekData.createWeekFile();
		if(weekFile != null) this.weekFile = weekFile;
		else weekFileName = 'week1';
	}

	override function create() {
		txtWeekTitle = new EditorsText(FlxG.width * 0.7, 10, 0, "", 32);
		txtWeekTitle.setFormat("VCR OSD Mono", 32, FlxColor.WHITE, RIGHT);
		txtWeekTitle.alpha = 0.7;

		var ui_tex = Paths.getSparrowAtlas('campaign_menu_UI_assets');
		var bgYellow:FlxSprite = new FlxSprite(0, 56).makeGraphic(FlxG.width, 386, 0xFFF9CF51);
		bgSprite = new FlxSprite(0, 56);
		bgSprite.antialiasing = ClientPrefs.data.globalAntialiasing;

		weekThing = new MenuItem(0, bgSprite.y + 396, weekFileName);
		weekThing.y += weekThing.height + 20;
		weekThing.antialiasing = ClientPrefs.data.globalAntialiasing;
		add(weekThing);

		var blackBarThingie:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, 56, FlxColor.BLACK);
		add(blackBarThingie);

		grpWeekCharacters = new FlxTypedGroup<MenuCharacter>();

		lock = new FlxSprite();
		lock.frames = ui_tex;
		lock.animation.addByPrefix('lock', 'lock');
		lock.animation.play('lock');
		lock.antialiasing = ClientPrefs.data.globalAntialiasing;
		add(lock);

		missingFileText = new EditorsText(0, 0, FlxG.width, "");
		missingFileText.setFormat(Paths.font("editors.ttf"), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		missingFileText.borderSize = 2;
		missingFileText.visible = false;
		add(missingFileText);

		var charArray:Array<String> = weekFile.weekCharacters;
		for (char in 0...3)
		{
			var weekCharacterThing:MenuCharacter = new MenuCharacter((FlxG.width * 0.25) * (1 + char) - 150, charArray[char]);
			weekCharacterThing.y += 70;
			grpWeekCharacters.add(weekCharacterThing);
		}

		add(bgYellow);
		add(bgSprite);
		add(grpWeekCharacters);

		var tracksSprite:FlxSprite = new FlxSprite(FlxG.width * 0.07, bgSprite.y + 435).loadGraphic(Paths.image('Menu_Tracks'));
		tracksSprite.antialiasing = ClientPrefs.data.globalAntialiasing;
		add(tracksSprite);

		txtTracklist = new EditorsText(FlxG.width * 0.05, tracksSprite.y + 60, 0, "", 32);
		txtTracklist.alignment = CENTER;
		txtTracklist.font = 'assets/fonts/editors.ttf';
		txtTracklist.color = 0xFFe55777;
		add(txtTracklist);
		add(txtWeekTitle);

		addEditorBox();
		reloadAllShit();

		FlxG.mouse.visible = true;
		#if (android || desktop)
		addVirtualPad(UP_DOWN, B);
		#end
		super.create();
	}

	var UI_box:PsychUIBox;
	var blockPressWhileTypingOn:Array<PsychUIInputText> = [];
	function addEditorBox() {
		var tabs = [
			Language.get('weekEditor_week', 'Week'),
			Language.get('weekEditor_other', 'Other')
		];
		UI_box = new PsychUIBox(FlxG.width - 250, FlxG.height - 375, 250, 375, tabs);
		UI_box.scrollFactor.set();
		addWeekUI();
		addOtherUI();

		UI_box.selectedIndex = 0;
		add(UI_box);
		for (tab in UI_box.tabs) tab.text.font = 'assets/fonts/editors.ttf';

		var loadWeekButton = new PsychUIButton(0, 650, Language.get('weekEditor_load_week', 'Load Week'), function() {
			loadWeek();
		}, 80, 20);
		loadWeekButton.screenCenter(X);
		loadWeekButton.x -= 120;
		add(loadWeekButton);

		var freeplayButton = new PsychUIButton(0, 650, Language.get('weekEditor_freeplay_btn', 'Freeplay'), function() {
			MusicBeatState.switchState(new WeekEditorFreeplayState(weekFile));

		}, 80, 20);
		freeplayButton.screenCenter(X);
		add(freeplayButton);

		var saveWeekButton = new PsychUIButton(0, 650, Language.get('weekEditor_save_week', 'Save Week'), function() {
			saveWeek(weekFile);
		}, 80, 20);
		saveWeekButton.screenCenter(X);
		saveWeekButton.x += 120;
		add(saveWeekButton);
	}

	var songsInputText:PsychUIInputText;
	var backgroundInputText:PsychUIInputText;
	var displayNameInputText:PsychUIInputText;
	var weekNameInputText:PsychUIInputText;
	var weekFileInputText:PsychUIInputText;

	var opponentInputText:PsychUIInputText;
	var boyfriendInputText:PsychUIInputText;
	var girlfriendInputText:PsychUIInputText;

	var hideCheckbox:PsychUICheckBox;

	public static var weekFileName:String = 'week1';

	function addWeekUI() {
		var tab = UI_box.getTab(Language.get('weekEditor_week', 'Week'));
		if(tab == null) return;
		var tab_group = tab.menu;

		songsInputText = new PsychUIInputText(10, 30, 200, '', 8);
		blockPressWhileTypingOn.push(songsInputText);
		songsInputText.onChange = function(oldText:String, newText:String) {
			var splittedText:Array<String> = newText.trim().split(',');
			for (i in 0...splittedText.length) {
				splittedText[i] = splittedText[i].trim();
			}

			while(splittedText.length < weekFile.songs.length) {
				weekFile.songs.pop();
			}

			for (i in 0...splittedText.length) {
				if(i >= weekFile.songs.length) {
					weekFile.songs.push([splittedText[i], 'dad', [146, 113, 253]]);
				} else {
					weekFile.songs[i][0] = splittedText[i];
					if(weekFile.songs[i][1] == null || weekFile.songs[i][1] == '') {
						weekFile.songs[i][1] = 'dad';
						weekFile.songs[i][2] = [146, 113, 253];
					}
				}
			}
			updateText();
		};

		opponentInputText = new PsychUIInputText(10, songsInputText.y + 40, 70, '', 8);
		blockPressWhileTypingOn.push(opponentInputText);
		opponentInputText.onChange = function(oldText:String, newText:String) {
			weekFile.weekCharacters[0] = newText.trim();
			updateText();
		};

		boyfriendInputText = new PsychUIInputText(opponentInputText.x + 75, opponentInputText.y, 70, '', 8);
		blockPressWhileTypingOn.push(boyfriendInputText);
		boyfriendInputText.onChange = function(oldText:String, newText:String) {
			weekFile.weekCharacters[1] = newText.trim();
			updateText();
		};

		girlfriendInputText = new PsychUIInputText(boyfriendInputText.x + 75, opponentInputText.y, 70, '', 8);
		blockPressWhileTypingOn.push(girlfriendInputText);
		girlfriendInputText.onChange = function(oldText:String, newText:String) {
			weekFile.weekCharacters[2] = newText.trim();
			updateText();
		};

		backgroundInputText = new PsychUIInputText(10, opponentInputText.y + 40, 120, '', 8);
		blockPressWhileTypingOn.push(backgroundInputText);
		backgroundInputText.onChange = function(oldText:String, newText:String) {
			weekFile.weekBackground = newText.trim();
			reloadBG();
		};

		displayNameInputText = new PsychUIInputText(10, backgroundInputText.y + 60, 200, '', 8);
		blockPressWhileTypingOn.push(displayNameInputText);
		displayNameInputText.onChange = function(oldText:String, newText:String) {
			weekFile.storyName = newText.trim();
			updateText();
		};

		weekNameInputText = new PsychUIInputText(10, displayNameInputText.y + 60, 150, '', 8);
		blockPressWhileTypingOn.push(weekNameInputText);
		weekNameInputText.onChange = function(oldText:String, newText:String) {
			weekFile.weekName = newText.trim();
		};

		weekFileInputText = new PsychUIInputText(10, weekNameInputText.y + 40, 100, '', 8);
		blockPressWhileTypingOn.push(weekFileInputText);
		weekFileInputText.onChange = function(oldText:String, newText:String) {
			weekFileName = newText.trim();
			reloadWeekThing();
		};
		reloadWeekThing();

		hideCheckbox = new PsychUICheckBox(10, weekFileInputText.y + 40, Language.get('weekEditor_hide_story_mode', 'Hide Week from Story Mode?'), 100, null);
		hideCheckbox.onClick = function() {
			weekFile.hideStoryMode = hideCheckbox.checked;
		};

		tab_group.add(new EditorsText(songsInputText.x, songsInputText.y - 18, 0, Language.get('weekEditor_songs', 'Songs:')));
		tab_group.add(new EditorsText(opponentInputText.x, opponentInputText.y - 18, 0, Language.get('weekEditor_characters', 'Characters:')));
		tab_group.add(new EditorsText(backgroundInputText.x, backgroundInputText.y - 18, 0, Language.get('weekEditor_background_asset', 'Background Asset:')));
		tab_group.add(new EditorsText(displayNameInputText.x, displayNameInputText.y - 18, 0, Language.get('weekEditor_display_name', 'Display Name:')));
		tab_group.add(new EditorsText(weekNameInputText.x, weekNameInputText.y - 18, 0, Language.get('weekEditor_week_name', 'Week Name (for Reset Score Menu):')));
		tab_group.add(new EditorsText(weekFileInputText.x, weekFileInputText.y - 18, 0, Language.get('weekEditor_week_file', 'Week File:')));

		tab_group.add(songsInputText);
		tab_group.add(opponentInputText);
		tab_group.add(boyfriendInputText);
		tab_group.add(girlfriendInputText);
		tab_group.add(backgroundInputText);

		tab_group.add(displayNameInputText);
		tab_group.add(weekNameInputText);
		tab_group.add(weekFileInputText);
		tab_group.add(hideCheckbox);
	}

	var weekBeforeInputText:PsychUIInputText;
	var difficultiesInputText:PsychUIInputText;
	var lockedCheckbox:PsychUICheckBox;
	var hiddenUntilUnlockCheckbox:PsychUICheckBox;

	function addOtherUI() {
		var tab = UI_box.getTab(Language.get('weekEditor_other', 'Other'));
		if(tab == null) return;
		var tab_group = tab.menu;

		lockedCheckbox = new PsychUICheckBox(10, 30, Language.get('weekEditor_week_locked', 'Week starts Locked'), 100, null);
		lockedCheckbox.onClick = function() {
			weekFile.startUnlocked = !lockedCheckbox.checked;
			lock.visible = lockedCheckbox.checked;
			hiddenUntilUnlockCheckbox.alpha = 0.4 + 0.6 * (lockedCheckbox.checked ? 1 : 0);
		};

		hiddenUntilUnlockCheckbox = new PsychUICheckBox(10, lockedCheckbox.y + 25, Language.get('weekEditor_hidden_until_unlock', 'Hidden until Unlocked'), 110, null);
		hiddenUntilUnlockCheckbox.onClick = function() {
			weekFile.hiddenUntilUnlocked = hiddenUntilUnlockCheckbox.checked;
		};
		hiddenUntilUnlockCheckbox.alpha = 0.4;

		weekBeforeInputText = new PsychUIInputText(10, hiddenUntilUnlockCheckbox.y + 55, 100, '', 8);
		blockPressWhileTypingOn.push(weekBeforeInputText);
		weekBeforeInputText.onChange = function(oldText:String, newText:String) {
			weekFile.weekBefore = newText.trim();
		};

		difficultiesInputText = new PsychUIInputText(10, weekBeforeInputText.y + 60, 200, '', 8);
		blockPressWhileTypingOn.push(difficultiesInputText);
		difficultiesInputText.onChange = function(oldText:String, newText:String) {
			weekFile.difficulties = newText.trim();
		};

		tab_group.add(new EditorsText(weekBeforeInputText.x, weekBeforeInputText.y - 28, 0, Language.get('weekEditor_week_before', 'Week File name of the Week you have\nto finish for Unlocking:')));
		tab_group.add(new EditorsText(difficultiesInputText.x, difficultiesInputText.y - 20, 0, Language.get('weekEditor_difficulties', 'Difficulties:')));
		tab_group.add(new EditorsText(difficultiesInputText.x, difficultiesInputText.y + 20, 0, Language.get('weekEditor_default_difficulties', 'Default difficulties are "Easy, Normal, Hard"\nwithout quotes.')));
		tab_group.add(weekBeforeInputText);
		tab_group.add(difficultiesInputText);
		tab_group.add(hiddenUntilUnlockCheckbox);
		tab_group.add(lockedCheckbox);
	}

	function reloadAllShit() {
		if(weekFile.songs.length < 1) return;
		var weekString:String = weekFile.songs[0][0];
		for (i in 1...weekFile.songs.length) {
			weekString += ', ' + weekFile.songs[i][0];
		}
		songsInputText.text = weekString;
		backgroundInputText.text = weekFile.weekBackground;
		displayNameInputText.text = weekFile.storyName;
		weekNameInputText.text = weekFile.weekName;
		weekFileInputText.text = weekFileName;

		opponentInputText.text = weekFile.weekCharacters[0];
		boyfriendInputText.text = weekFile.weekCharacters[1];
		girlfriendInputText.text = weekFile.weekCharacters[2];

		hideCheckbox.checked = weekFile.hideStoryMode;

		weekBeforeInputText.text = weekFile.weekBefore;

		difficultiesInputText.text = '';
		if(weekFile.difficulties != null) difficultiesInputText.text = weekFile.difficulties;

		lockedCheckbox.checked = !weekFile.startUnlocked;
		lock.visible = lockedCheckbox.checked;

		hiddenUntilUnlockCheckbox.checked = weekFile.hiddenUntilUnlocked;
		hiddenUntilUnlockCheckbox.alpha = 0.4 + 0.6 * (lockedCheckbox.checked ? 1 : 0);

		reloadBG();
		reloadWeekThing();
		updateText();
	}

	function updateText()
	{
		for (i in 0...grpWeekCharacters.length) {
			grpWeekCharacters.members[i].changeCharacter(weekFile.weekCharacters[i]);
		}

		var stringThing:Array<String> = [];
		for (i in 0...weekFile.songs.length) {
			stringThing.push(weekFile.songs[i][0]);
		}

		txtTracklist.text = '';
		for (i in 0...stringThing.length)
		{
			txtTracklist.text += stringThing[i] + '\n';
		}

		txtTracklist.text = txtTracklist.text.toUpperCase();

		txtTracklist.screenCenter(X);
		txtTracklist.x -= FlxG.width * 0.35;

		txtWeekTitle.text = weekFile.storyName.toUpperCase();
		txtWeekTitle.x = FlxG.width - (txtWeekTitle.width + 10);
	}

	function reloadBG() {
		bgSprite.visible = true;
		var assetName:String = weekFile.weekBackground;

		var isMissing:Bool = true;
		if(assetName != null && assetName.length > 0) {
			if( #if MODS_ALLOWED FileSystem.exists(Paths.modsImages('menubackgrounds/menu_' + assetName)) || #end
			Assets.exists(Paths.getPath('images/menubackgrounds/menu_' + assetName + '.png', IMAGE), IMAGE)) {
				bgSprite.loadGraphic(Paths.image('menubackgrounds/menu_' + assetName));
				isMissing = false;
			}
		}

		if(isMissing) {
			bgSprite.visible = false;
		}
	}

	function reloadWeekThing() {
		weekThing.visible = true;
		missingFileText.visible = false;
		var assetName:String = weekFileInputText.text.trim();

		var isMissing:Bool = true;
		if(assetName != null && assetName.length > 0) {
			if( #if MODS_ALLOWED FileSystem.exists(Paths.modsImages('storymenu/' + assetName)) || #end
			Assets.exists(Paths.getPath('images/storymenu/' + assetName + '.png', IMAGE), IMAGE)) {
				weekThing.loadGraphic(Paths.languageImage('storymenu/' + assetName));
				isMissing = false;
			}
		}

		if(isMissing) {
			weekThing.visible = false;
			missingFileText.visible = true;
			missingFileText.text = 'MISSING FILE: images/storymenu/' + assetName + '.png';
		}
		recalculateStuffPosition();

		#if cpp
		DiscordClient.changePresence("Week Editor", "Editting: " + weekFileName);
		#end
	}

	public function UIEvent(id:String, sender:Dynamic) {
		// events handled via callbacks
	}

	override function update(elapsed:Float)
	{
		if(loadedWeek != null) {
			weekFile = loadedWeek;
			loadedWeek = null;

			reloadAllShit();
		}

		var blockInput:Bool = false;
		for (inputText in blockPressWhileTypingOn) {
			if(PsychUIInputText.focusOn == inputText) {
				FlxG.sound.muteKeys = [];
				FlxG.sound.volumeDownKeys = [];
				FlxG.sound.volumeUpKeys = [];
				blockInput = true;

				if(FlxG.keys.justPressed.ENTER) PsychUIInputText.focusOn = null;
				break;
			}
		}

		if(!blockInput) {
			FlxG.sound.muteKeys = TitleState.muteKeys;
			FlxG.sound.volumeDownKeys = TitleState.volumeDownKeys;
			FlxG.sound.volumeUpKeys = TitleState.volumeUpKeys;
			if(#if (android || desktop) (virtualPad != null && virtualPad.buttonB.justPressed) || #end FlxG.keys.justPressed.ESCAPE) {
				confirmExit();
			}
		}

		super.update(elapsed);

		lock.y = weekThing.y;
		missingFileText.y = weekThing.y + 36;
	}

	function recalculateStuffPosition() {
		weekThing.screenCenter(X);
		lock.x = weekThing.width + 10 + weekThing.x;
	}

	public static var loadedWeek:WeekFile = null;
	public static var loadError:Bool = false;
	static var fileDialog:FileDialogHandler;

	public static function loadWeek() {
		if(fileDialog == null) fileDialog = new FileDialogHandler();
		
		var jsonFilter:FileFilter = new FileFilter('JSON', 'json');
		
		fileDialog.open(null, null, [jsonFilter], function() {
			if(fileDialog.data != null) {
				try {
					var parsedWeek:WeekFile = cast Json.parse(fileDialog.data);
					if(parsedWeek.weekCharacters != null && parsedWeek.weekName != null)
					{
						// Extract filename without extension from path
						var path:String = fileDialog.path;
						var cutName:String = path.substr(path.lastIndexOf('/') + 1);
						cutName = cutName.substr(cutName.lastIndexOf('\\') + 1);
						if(cutName.indexOf('.') > -1) cutName = cutName.substr(0, cutName.lastIndexOf('.'));
						
						CoolUtil.traceMsg('trace.fileLoaded', 'Successfully loaded file: {}', [cutName]);
						loadError = false;
						loadedWeek = parsedWeek;
						weekFileName = cutName;
						return;
					}
				} catch(e:Dynamic) {
					CoolUtil.traceMsg('trace.fileProblem', 'Problem loading file: {}', [e]);
				}
			}
			loadError = true;
			loadedWeek = null;
		}, function() {
			CoolUtil.traceMsg('trace.fileCancelled', 'Cancelled file loading.');
		}, function() {
			CoolUtil.traceMsg('trace.fileProblemSimple', 'Problem loading file');
		});
	}

	/** Mark the week as having unsaved changes. */
	function markUnsaved():Void { unsavedChanges = true; }
	/** Clear the unsaved changes flag. */
	function clearUnsaved():Void { unsavedChanges = false; }

	/** Confirm exit if there are unsaved changes. */
	function confirmExit():Void
	{
		if(unsavedChanges)
		{
			openSubState(new editors.content.Prompt(
				'There\'s unsaved progress,\nare you sure you want to exit?',
				function()
				{
					clearUnsaved();
					MusicBeatState.switchState(new editors.MasterEditorMenu());
					FlxG.sound.playMusic(Paths.music('freakyMenu'));
				}
			));
		}
		else
		{
			MusicBeatState.switchState(new editors.MasterEditorMenu());
			FlxG.sound.playMusic(Paths.music('freakyMenu'));
		}
	}

	public static function saveWeek(weekFile:WeekFile) {
		var data:String = Json.stringify(weekFile, "\t");
		if (data.length > 0)
		{
			if(fileDialog == null) fileDialog = new FileDialogHandler();
			
			fileDialog.save(weekFileName + '.json', data, function() {
			staticUnsavedChanges = false;
			backend.UnsavedChangesTracker.hasUnsavedChanges = false;
			CoolUtil.traceMsg('trace.weekSaved', 'Week saved successfully!');
			}, null, function() {
				FlxG.log.error('Problem saving file');
			});
		}
	}
}

class WeekEditorFreeplayState extends MusicBeatState implements PsychUIEventHandler.PsychUIEvent
{
	/** Unsaved changes flag — prompts confirm dialog on exit. */
	public static var staticUnsavedChanges:Bool = false;
	public var unsavedChanges(get, set):Bool;
	function get_unsavedChanges():Bool return staticUnsavedChanges;
	function set_unsavedChanges(v:Bool):Bool
	{
		staticUnsavedChanges = v;
		backend.UnsavedChangesTracker.hasUnsavedChanges = v;
		if(v) backend.UnsavedChangesTracker.currentEditorState = this;
		return staticUnsavedChanges;
	}

	var weekFile:WeekFile = null;
	public function new(weekFile:WeekFile = null)
	{
		super();
		this.weekFile = WeekData.createWeekFile();
		if(weekFile != null) this.weekFile = weekFile;
	}

	var bg:FlxSprite;
	private var grpSongs:FlxTypedGroup<Alphabet>;
	private var iconArray:Array<HealthIcon> = [];

	var curSelected = 0;

	override function create() {
		bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.data.globalAntialiasing;

		bg.color = FlxColor.WHITE;
		add(bg);

		grpSongs = new FlxTypedGroup<Alphabet>();
		add(grpSongs);

		for (i in 0...weekFile.songs.length)
		{
			var songText:Alphabet = new Alphabet(90, 320, weekFile.songs[i][0], true);
			songText.isMenuItem = true;
			songText.targetY = i;
			grpSongs.add(songText);
			songText.snapToPosition();

			var icon:HealthIcon = new HealthIcon(weekFile.songs[i][1]);
			icon.sprTracker = songText;

			iconArray.push(icon);
			add(icon);
		}

		addEditorBox();
		changeSelection();
		#if (android || desktop)
		addVirtualPad(UP_DOWN, B);
		#end
		super.create();
	}

	var UI_box:PsychUIBox;
	var blockPressWhileTypingOn:Array<PsychUIInputText> = [];
	function addEditorBox() {
		var tabs = [
			Language.get('weekEditor_freeplay', 'Freeplay'),
		];
		UI_box = new PsychUIBox(FlxG.width - 350, FlxG.height - 260, 250, 200, tabs);
		UI_box.scrollFactor.set();

		UI_box.selectedIndex = 0;
		addFreeplayUI();
		add(UI_box);
		for (tab in UI_box.tabs) tab.text.font = 'assets/fonts/editors.ttf';

		var blackBlack:FlxSprite = new FlxSprite(0, 670).makeGraphic(FlxG.width, 50, FlxColor.BLACK);
		blackBlack.alpha = 0.6;
		add(blackBlack);

		var loadWeekButton = new PsychUIButton(0, 685, Language.get('weekEditor_load_week', 'Load Week'), function() {
			WeekEditorState.loadWeek();
		}, 80, 20);
		loadWeekButton.screenCenter(X);
		loadWeekButton.x -= 120;
		add(loadWeekButton);

		var storyModeButton = new PsychUIButton(0, 685, Language.get('weekEditor_story_mode', 'Story Mode'), function() {
			MusicBeatState.switchState(new WeekEditorState(weekFile));

		}, 80, 20);
		storyModeButton.screenCenter(X);
		add(storyModeButton);

		var saveWeekButton = new PsychUIButton(0, 685, Language.get('weekEditor_save_week', 'Save Week'), function() {
			WeekEditorState.saveWeek(weekFile);
		}, 80, 20);
		saveWeekButton.screenCenter(X);
		saveWeekButton.x += 120;
		add(saveWeekButton);
	}

	public function UIEvent(id:String, sender:Dynamic) {
		// events handled via callbacks
	}

	var bgColorStepperR:PsychUINumericStepper;
	var bgColorStepperG:PsychUINumericStepper;
	var bgColorStepperB:PsychUINumericStepper;
	var iconInputText:PsychUIInputText;
	function addFreeplayUI() {
		var tab = UI_box.getTab(Language.get('weekEditor_freeplay', 'Freeplay'));
		if(tab == null) return;
		var tab_group = tab.menu;

		bgColorStepperR = new PsychUINumericStepper(10, 40, 20, 255, 0, 255, 0);
		bgColorStepperR.textObj.font = 'assets/fonts/editors.ttf';
		bgColorStepperR.onValueChange = updateBG;
		bgColorStepperG = new PsychUINumericStepper(80, 40, 20, 255, 0, 255, 0);
		bgColorStepperG.textObj.font = 'assets/fonts/editors.ttf';
		bgColorStepperG.onValueChange = updateBG;
		bgColorStepperB = new PsychUINumericStepper(150, 40, 20, 255, 0, 255, 0);
		bgColorStepperB.textObj.font = 'assets/fonts/editors.ttf';
		bgColorStepperB.onValueChange = updateBG;

		var copyColor = new PsychUIButton(10, bgColorStepperR.y + 25, Language.get('weekEditor_copy_color', 'Copy Color'), function() {
			Clipboard.text = bg.color.red + ',' + bg.color.green + ',' + bg.color.blue;
		}, 80, 20);
		var pasteColor = new PsychUIButton(140, copyColor.y, Language.get('weekEditor_paste_color', 'Paste Color'), function() {
			if(Clipboard.text != null) {
				var leColor:Array<Int> = [];
				var splitted:Array<String> = Clipboard.text.trim().split(',');
				for (i in 0...splitted.length) {
					var toPush:Int = Std.parseInt(splitted[i]);
					if(!Math.isNaN(toPush)) {
						if(toPush > 255) toPush = 255;
						else if(toPush < 0) toPush *= -1;
						leColor.push(toPush);
					}
				}

				if(leColor.length > 2) {
					bgColorStepperR.value = leColor[0];
					bgColorStepperG.value = leColor[1];
					bgColorStepperB.value = leColor[2];
					updateBG();
				}
			}
		}, 80, 20);

		iconInputText = new PsychUIInputText(10, bgColorStepperR.y + 70, 100, '', 8);
		iconInputText.onChange = function(oldText:String, newText:String) {
			weekFile.songs[curSelected][1] = newText;
			iconArray[curSelected].changeIcon(newText);
		};

		var hideFreeplayCheckbox = new PsychUICheckBox(10, iconInputText.y + 30, Language.get('weekEditor_hide_freeplay', 'Hide Week from Freeplay?'), 100, null);
		hideFreeplayCheckbox.checked = weekFile.hideFreeplay;
		hideFreeplayCheckbox.onClick = function() {
			weekFile.hideFreeplay = hideFreeplayCheckbox.checked;
		};

		tab_group.add(new EditorsText(10, bgColorStepperR.y - 18, 0, Language.get('weekEditor_bg_color_rgb', 'Selected background Color R/G/B:')));
		tab_group.add(new EditorsText(10, iconInputText.y - 18, 0, Language.get('weekEditor_selected_icon', 'Selected icon:')));
		tab_group.add(bgColorStepperR);
		tab_group.add(bgColorStepperG);
		tab_group.add(bgColorStepperB);
		tab_group.add(copyColor);
		tab_group.add(pasteColor);
		tab_group.add(iconInputText);
		tab_group.add(hideFreeplayCheckbox);
	}

	function updateBG() {
		weekFile.songs[curSelected][2][0] = Math.round(bgColorStepperR.value);
		weekFile.songs[curSelected][2][1] = Math.round(bgColorStepperG.value);
		weekFile.songs[curSelected][2][2] = Math.round(bgColorStepperB.value);
		bg.color = FlxColor.fromRGB(weekFile.songs[curSelected][2][0], weekFile.songs[curSelected][2][1], weekFile.songs[curSelected][2][2]);
	}

	function changeSelection(change:Int = 0) {
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		curSelected += change;

		if (curSelected < 0)
			curSelected = weekFile.songs.length - 1;
		if (curSelected >= weekFile.songs.length)
			curSelected = 0;

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

			if (item.targetY == 0)
			{
				item.alpha = 1;
			}
		}
		trace(weekFile.songs[curSelected]);
		iconInputText.text = weekFile.songs[curSelected][1];
		bgColorStepperR.value = Math.round(weekFile.songs[curSelected][2][0]);
		bgColorStepperG.value = Math.round(weekFile.songs[curSelected][2][1]);
		bgColorStepperB.value = Math.round(weekFile.songs[curSelected][2][2]);
		updateBG();
	}

	override function update(elapsed:Float) {
		if(WeekEditorState.loadedWeek != null) {
			super.update(elapsed);
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
			MusicBeatState.switchState(new WeekEditorFreeplayState(WeekEditorState.loadedWeek));
			WeekEditorState.loadedWeek = null;
			return;
		}

		if(PsychUIInputText.focusOn == iconInputText) {
			FlxG.sound.muteKeys = [];
			FlxG.sound.volumeDownKeys = [];
			FlxG.sound.volumeUpKeys = [];
			if(FlxG.keys.justPressed.ENTER) {
				PsychUIInputText.focusOn = null;
			}
		} else {
			FlxG.sound.muteKeys = TitleState.muteKeys;
			FlxG.sound.volumeDownKeys = TitleState.volumeDownKeys;
			FlxG.sound.volumeUpKeys = TitleState.volumeUpKeys;
			if(#if (android || desktop) (virtualPad != null && virtualPad.buttonB.justPressed) ||#end FlxG.keys.justPressed.ESCAPE) {
				confirmExitFreeplay();
			}

			if(controls.UI_UP_P #if (android || desktop) || (virtualPad != null && virtualPad.buttonUp.justPressed) #end) changeSelection(-1);
			if(controls.UI_DOWN_P #if (android || desktop) || (virtualPad != null && virtualPad.buttonDown.justPressed) #end) changeSelection(1);
		}
		super.update(elapsed);
	}

	function markUnsavedFreeplay():Void { unsavedChanges = true; }
	function clearUnsavedFreeplay():Void { unsavedChanges = false; }
	function confirmExitFreeplay():Void
	{
		if(unsavedChanges)
		{
			openSubState(new editors.content.Prompt(
				'There\'s unsaved progress,\nare you sure you want to exit?',
				function()
				{
					clearUnsavedFreeplay();
					MusicBeatState.switchState(new editors.MasterEditorMenu());
					FlxG.sound.playMusic(Paths.music('freakyMenu'));
				}
			));
		}
		else
		{
			MusicBeatState.switchState(new editors.MasterEditorMenu());
			FlxG.sound.playMusic(Paths.music('freakyMenu'));
		}
	}
}
