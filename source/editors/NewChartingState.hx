package editors;

import backend.PsychCamera;
import backend.ui.*;
import flixel.FlxSubState;
import flixel.util.FlxSave;
import flixel.util.FlxSort;
import flixel.util.FlxSpriteUtil;
import flixel.util.FlxStringUtil;
import flixel.util.FlxDestroyUtil;
import flixel.input.keyboard.FlxKey;

import lime.utils.Assets;
import lime.media.AudioBuffer;

import flash.media.Sound;
import flash.geom.Rectangle;

import haxe.Json;
import haxe.Exception;
import haxe.io.Bytes;

import openfl.utils.Assets as OpenFlAssets;

import editors.content.MetaNote;
import editors.content.VSlice;
import editors.content.Prompt;
import editors.content.*;

import Song;
import StageData;
import Highscore;
import backend.Difficulty;
import CoolUtil;
import mohong.TraceManager;

import Section.SwagSection;
import Character;
import HealthIcon;
import Note;
import StrumNote;

using DateTools;

typedef UndoStruct = {
	var action:UndoAction;
	var data:Dynamic;
}

enum abstract UndoAction(String)
{
	var ADD_NOTE = 'Add Note';
	var DELETE_NOTE = 'Delete Note';
	var MOVE_NOTE = 'Move Note';
	var SELECT_NOTE = 'Select Note';
}

enum abstract ChartingTheme(String)
{
	var LIGHT = 'light';
	var DARK = 'dark';
	var DEFAULT = 'default';
	var VSLICE = 'vslice';
	var CUSTOM = 'custom';
}

enum abstract WaveformTarget(String)
{
	var INST = 'inst';
	var PLAYER = 'voc';
	var OPPONENT = 'opp';
}

class NewChartingState extends MusicBeatState implements PsychUIEventHandler.PsychUIEvent
{
    public static var noteTypeList:Array<String> = 
    [
            '',
            'Alt Animation',
            'Hey!',
            'Hurt Note',
            'GF Sing',
            'No Animation'
    ];

	public static function getDefaultEvents():Array<Array<String>>
	{
		return [
			['', Language.get('newchartEditor_nothing', "Nothing. Yep, that's right.")],
			['Dadbattle Spotlight', Language.get('newchartEditor_dadbattle_spotlight', "Used in Dad Battle,\nValue 1: 0/1 = ON/OFF,\n2 = Target Dad\n3 = Target BF")],
			['Hey!', Language.get('newchartEditor_hey', "Plays the \"Hey!\" animation from Bopeebo,\nValue 1: BF = Only Boyfriend, GF = Only Girlfriend,\nSomething else = Both.\nValue 2: Custom animation duration,\nleave it blank for 0.6s")],
			['Set GF Speed', Language.get('newchartEditor_set_gf_speed', "Sets GF head bopping speed,\nValue 1: 1 = Normal speed,\n2 = 1/2 speed, 4 = 1/4 speed etc.\nUsed on Fresh during the beatbox parts.\n\nWarning: Value must be integer!")],
			['Philly Glow', Language.get('newchartEditor_philly_glow', "Exclusive to Week 3\nValue 1: 0/1/2 = OFF/ON/Reset Gradient\n \nNo, i won't add it to other weeks.")],
			['Kill Henchmen', Language.get('newchartEditor_kill_henchmen', "For Mom's songs, don't use this please, i love them :(")],
			['Add Camera Zoom', Language.get('newchartEditor_add_camera_zoom', "Used on MILF on that one \"hard\" part\nValue 1: Camera zoom add (Default: 0.015)\nValue 2: UI zoom add (Default: 0.03)\nLeave the values blank if you want to use Default.")],
			['BG Freaks Expression', Language.get('newchartEditor_bg_freaks_expression', "Should be used only in \"school\" Stage!")],
			['Trigger BG Ghouls', Language.get('newchartEditor_trigger_bg_ghouls', "Should be used only in \"schoolEvil\" Stage!")],
			['Play Animation', Language.get('newchartEditor_play_animation', "Plays an animation on a Character,\nonce the animation is completed,\nthe animation changes to Idle\n\nValue 1: Animation to play.\nValue 2: Character (Dad, BF, GF)")],
			['Camera Follow Pos', Language.get('newchartEditor_camera_follow_pos', "Value 1: X\nValue 2: Y\n\nThe camera won't change the follow point\nafter using this, for getting it back\nto normal, leave both values blank.")],
			['Alt Idle Animation', Language.get('newchartEditor_alt_idle_animation', "Sets a specified postfix after the idle animation name.\nYou can use this to trigger 'idle-alt' if you set\nValue 2 to -alt\n\nValue 1: Character to set (Dad, BF or GF)\nValue 2: New postfix (Leave it blank to disable)")],
			['Screen Shake', Language.get('newchartEditor_screen_shake', "Value 1: Camera shake\nValue 2: HUD shake\n\nEvery value works as the following example: \"1, 0.05\".\nThe first number (1) is the duration.\nThe second number (0.05) is the intensity.")],
			['Change Character', Language.get('newchartEditor_change_character', "Value 1: Character to change (Dad, BF, GF)\nValue 2: New character's name")],
			['Change Scroll Speed', Language.get('newchartEditor_change_scroll_speed', "Value 1: Scroll Speed Multiplier (1 is default)\nValue 2: Time it takes to change fully in seconds.")],
			['Set Property', Language.get('newchartEditor_set_property', "Value 1: Variable name\nValue 2: New value")],
			['Play Sound', Language.get('newchartEditor_play_sound', "Value 1: Sound file name\nValue 2: Volume (Default: 1), ranges from 0 to 1")]
		];
	}

	public static var defaultEvents(get, null):Array<Array<String>>;
	static function get_defaultEvents():Array<Array<String>>
	{
		return getDefaultEvents();
	}
	
	public static var keysArray:Array<FlxKey> = [ONE, TWO, THREE, FOUR, FIVE, SIX, SEVEN, EIGHT]; //Used for Vortex Editor
	public static var SHOW_EVENT_COLUMN = true;
	public static var GRID_COLUMNS_PER_PLAYER = 4;
	public static var GRID_PLAYERS = 2;
	public static var GRID_SIZE = 40;
	final BACKUP_EXT = '.bkp';

	public var quantizations:Array<Int> = [
		4,
		8,
		12,
		16,
		20,
		24,
		32,
		48,
		64,
		96,
		192
	];
	public var quantColors:Array<FlxColor> = [
		0xFFDF0000,
		0xFF4040CF,
		0xFFAF00AF,
		0xFFFFAF00,
		0xFFFFFFFF,
		0xFFFFA0FF,
		0xFFFF6030,
		0xFF00CFCF,
		0xFF00CF00,
		0xFF9F9F9F,
		0xFF3F3F3F,
	];
	var curQuant(default, set):Int = 16;
	function set_curQuant(v:Int)
	{
		curQuant = v;
		updateVortexColor();
		return curQuant;
	}
	function updateVortexColor()
		vortexIndicator.color = quantColors[Std.int(FlxMath.bound(quantizations.indexOf(curQuant), 0, quantColors.length - 1))];

	var sectionFirstNoteID:Int = 0;
	var sectionFirstEventID:Int = 0;
	var curSec:Int = 0;

	/** Unsaved changes flag — prompts confirm dialog on exit / playtest. */
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

	var chartEditorSave:FlxSave;
	var mainBox:PsychUIBox;
	var mainBoxPosition:FlxPoint = FlxPoint.get(920, 40);
	var infoBox:PsychUIBox;
	var infoBoxPosition:FlxPoint = FlxPoint.get(1000, 360);
	var upperBox:PsychUIBox;
	
	var camUI:FlxCamera;

	var prevGridBg:ChartingGridSprite;
	var gridBg:ChartingGridSprite;
	var nextGridBg:ChartingGridSprite;
	var waveformSprite:FlxSprite;
	var scrollY:Float = 0;
	
	var zoomList:Array<Float> = [
		0.25,
		0.5,
		1,
		2,
		3,
		4,
		6,
		8,
		12,
		16,
		24
	];
	var curZoom:Float = 1;

	var mustHitIndicator:FlxSprite;
	var eventIcon:FlxSprite;
	var icons:Array<HealthIcon> = [];

	var events:Array<EventMetaNote> = [];
	var notes:Array<MetaNote> = [];

	var behindRenderedNotes:FlxTypedGroup<MetaNote> = new FlxTypedGroup<MetaNote>();
	var curRenderedNotes:FlxTypedGroup<MetaNote> = new FlxTypedGroup<MetaNote>();
	var movingNotes:FlxTypedGroup<MetaNote> = new FlxTypedGroup<MetaNote>();
	var eventLockOverlay:FlxSprite;
	var vortexIndicator:FlxSprite;
	var strumLineNotes:FlxTypedGroup<StrumNote> = new FlxTypedGroup<StrumNote>();
	var dummyArrow:FlxSprite;
	var isMovingNotes:Bool = false;
	var movingNotesLastData:Int = 0;
	var movingNotesLastY:Float = 0;
	
	var vocals:FlxSound = new FlxSound();
	var opponentVocals:FlxSound = new FlxSound();

	var timeLine:FlxSprite;
	var infoText:EditorsText;

	var autoSaveIcon:FlxSprite;
	var outputTxt:EditorsText;
	var modIndicatorTxt:EditorsText;

	var selectionStart:FlxPoint = FlxPoint.get();
	var selectionBox:FlxSprite;

	var _shouldReset:Bool = true;
	public function new(?shouldReset:Bool = true)
	{
		this._shouldReset = shouldReset;
		super();
	}

	var bg:FlxSprite;
	var theme:ChartingTheme = DEFAULT;

	var copiedNotes:Array<Dynamic> = [];
	var copiedEvents:Array<Dynamic> = [];
	
	var _keysPressedBuffer:Array<Bool> = [];

	var tipBg:FlxSprite;
	var fullTipText:EditorsText;
	
	var vortexEnabled:Bool = false;
	var waveformEnabled:Bool = false;
	var waveformTarget:WaveformTarget = INST;

	public function initPsychCamera():PsychCamera
	{
		var camera = new PsychCamera();
		FlxG.cameras.reset(camera);
		FlxG.cameras.setDefaultDrawTarget(camera, true);
		//trace('initialized psych camera ' + Sys.cpuTime());
		return camera;
	}

	override function create()
	{
		clearUnsaved();
		if(Difficulty.list.length < 1) Difficulty.resetList();
		_keysPressedBuffer.resize(keysArray.length);

		if(_shouldReset) Conductor.songPosition = 0;
		persistentUpdate = false;
		FlxG.mouse.visible = true;
		FlxG.sound.list.add(vocals);
		FlxG.sound.list.add(opponentVocals);

		vocals.autoDestroy = false;
		vocals.looped = true;
		opponentVocals.autoDestroy = false;
		opponentVocals.looped = true;

		initPsychCamera();
		camUI = new FlxCamera();
		camUI.bgColor.alpha = 0;
		FlxG.cameras.add(camUI, false);

		chartEditorSave = new FlxSave();
		chartEditorSave.bind('chart_editor_data', CoolUtil.getSavePath());

		bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.data.globalAntialiasing;
		bg.scrollFactor.set();
		add(bg);

		if(chartEditorSave.data.autoSave != null) autoSaveCap = chartEditorSave.data.autoSave;
		if(chartEditorSave.data.backupLimit != null) backupLimit = chartEditorSave.data.backupLimit;
		if(chartEditorSave.data.vortex != null) vortexEnabled = chartEditorSave.data.vortex;

		if(chartEditorSave.data.customBgColor == null) chartEditorSave.data.customBgColor = '303030';
		if(chartEditorSave.data.customGridColors == null || chartEditorSave.data.customGridColors.length < 2)
			chartEditorSave.data.customGridColors = ['DFDFDF', 'BFBFBF'];
		if(chartEditorSave.data.customNextGridColors == null || chartEditorSave.data.customNextGridColors.length < 2)
			chartEditorSave.data.customNextGridColors = ['5F5F5F', '4A4A4A'];
		
		changeTheme(chartEditorSave.data.theme != null ? chartEditorSave.data.theme : DEFAULT, false);

		createGrids();

		waveformSprite = new FlxSprite(gridBg.x + (SHOW_EVENT_COLUMN ? GRID_SIZE : 0), 0).makeGraphic(1, 1, 0x00FFFFFF);
		waveformSprite.scrollFactor.x = 0;
		waveformSprite.visible = false;
		add(waveformSprite);

		dummyArrow = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);
		dummyArrow.setGraphicSize(GRID_SIZE, GRID_SIZE);
		dummyArrow.updateHitbox();
		dummyArrow.scrollFactor.x = 0;
		add(dummyArrow);

		vortexIndicator = new FlxSprite(gridBg.x - GRID_SIZE, FlxG.height/2).loadGraphic(Paths.image('editors/vortex_indicator'));
		vortexIndicator.setGraphicSize(GRID_SIZE);
		vortexIndicator.updateHitbox();
		vortexIndicator.scrollFactor.set();
		vortexIndicator.active = false;
		updateVortexColor();
		add(vortexIndicator);
		add(strumLineNotes);

		add(behindRenderedNotes);
		add(curRenderedNotes);
		add(movingNotes);

		eventLockOverlay = new FlxSprite(gridBg.x, 0).makeGraphic(1, 1, FlxColor.BLACK);
		eventLockOverlay.alpha = 0.6;
		eventLockOverlay.visible = false;
		eventLockOverlay.scrollFactor.x = 0;
		eventLockOverlay.scale.x = GRID_SIZE;
		eventLockOverlay.updateHitbox();
		add(eventLockOverlay);

		timeLine = new FlxSprite(gridBg.x, 0).makeGraphic(1, 1, FlxColor.WHITE);
		timeLine.setGraphicSize(Std.int(gridBg.width), 4);
		timeLine.updateHitbox();
		timeLine.screenCenter(Y);
		timeLine.scrollFactor.set();
		add(timeLine);
		
		var startX:Float = gridBg.x;
		var startY:Float = FlxG.height/2;
		vortexIndicator.visible = strumLineNotes.visible = strumLineNotes.active = vortexEnabled;
		if(SHOW_EVENT_COLUMN) startX += GRID_SIZE;

		for (i in 0...Std.int(GRID_PLAYERS * GRID_COLUMNS_PER_PLAYER))
		{
			var note:StrumNote = new StrumNote(startX + (GRID_SIZE * i), startY, i % GRID_COLUMNS_PER_PLAYER, 0);
			note.scrollFactor.set();
			note.playAnim('static');
			note.alpha = 0.4;
			note.updateHitbox();
			if(note.width > note.height)
				note.setGraphicSize(GRID_SIZE);
			else
				note.setGraphicSize(0, GRID_SIZE);
	
			note.updateHitbox();
			note.x += GRID_SIZE/2 - note.width/2;
			note.y += GRID_SIZE/2 - note.height/2;
			strumLineNotes.add(note);
		}

		var columns:Int = 0;
		var iconX:Float = gridBg.x;
		var iconY:Float = 50;
		if(SHOW_EVENT_COLUMN)
		{
			eventIcon = new FlxSprite(0, iconY).loadGraphic(Paths.image('editors/eventIcon'));
			eventIcon.antialiasing = ClientPrefs.data.globalAntialiasing;
			eventIcon.alpha = 0.6;
			eventIcon.setGraphicSize(30, 30);
			eventIcon.updateHitbox();
			eventIcon.scrollFactor.set();
			add(eventIcon);
			eventIcon.x = iconX + (GRID_SIZE * 0.5) - eventIcon.width/2;
			iconX += GRID_SIZE;

			columns++;
		}

		mustHitIndicator = FlxSpriteUtil.drawTriangle(new FlxSprite(0, iconY - 20).makeGraphic(16, 16, FlxColor.TRANSPARENT), 0, 0, 16);
		mustHitIndicator.scrollFactor.set();
		mustHitIndicator.flipY = true;
		mustHitIndicator.offset.x += mustHitIndicator.width/2;
		add(mustHitIndicator);

		var gridStripes:Array<Int> = [];
		for (i in 0...GRID_PLAYERS)
		{
			if(columns > 0) gridStripes.push(columns);
			columns += GRID_COLUMNS_PER_PLAYER;

			var icon:HealthIcon = new HealthIcon();
			icon.autoAdjustOffset = false;
			icon.y = iconY;
			icon.alpha = 0.6;
			icon.scrollFactor.set();
			icon.scale.set(0.3, 0.3);
			icon.updateHitbox();
			icon.ID = i+1;
			add(icon);
			icons.push(icon);
			
			icon.x = iconX + GRID_SIZE * (GRID_COLUMNS_PER_PLAYER/2) - icon.width/2;
			iconX += GRID_SIZE * GRID_COLUMNS_PER_PLAYER;
		}
		prevGridBg.stripes = nextGridBg.stripes = gridBg.stripes = gridStripes;
		
		selectionBox = new FlxSprite().makeGraphic(1, 1, FlxColor.CYAN);
		selectionBox.alpha = 0.4;
		selectionBox.blend = ADD;
		selectionBox.scrollFactor.set();
		selectionBox.visible = false;
		add(selectionBox);

		infoBox = new PsychUIBox(infoBoxPosition.x, infoBoxPosition.y, 220, 220, ['newchartEditor_information']);
		infoBox.scrollFactor.set();
		infoBox.cameras = [camUI];
		infoText = new EditorsText(15, 0, 230, '', 16);
		infoText.font = Paths.font('editors.ttf');
		infoText.scrollFactor.set();
		infoBox.getTab('newchartEditor_information').menu.add(infoText);
		add(infoBox);

		mainBox = new PsychUIBox(mainBoxPosition.x, mainBoxPosition.y, 300, 280, ['newchartEditor_charting', 'newchartEditor_data', 'newchartEditor_events', 'newchartEditor_note', 'newchartEditor_section', 'newchartEditor_song']);
		mainBox.selectedName = 'Song';
		mainBox.scrollFactor.set();
		mainBox.cameras = [camUI];
		add(mainBox);

		autoSaveIcon = new FlxSprite(50).loadGraphic(Paths.image('editors/autosave'));
		autoSaveIcon.screenCenter(Y);
		autoSaveIcon.scale.set(0.6, 0.6);
		autoSaveIcon.antialiasing = ClientPrefs.data.globalAntialiasing;
		autoSaveIcon.scrollFactor.set();
		autoSaveIcon.alpha = 0;
		add(autoSaveIcon);

		// save data positions for the UI boxes
		if(chartEditorSave.data.mainBoxPosition != null && chartEditorSave.data.mainBoxPosition.length > 1)
			mainBox.setPosition(chartEditorSave.data.mainBoxPosition[0], chartEditorSave.data.mainBoxPosition[1]);
		if(chartEditorSave.data.infoBoxPosition != null && chartEditorSave.data.infoBoxPosition.length > 1)
			infoBox.setPosition(chartEditorSave.data.infoBoxPosition[0], chartEditorSave.data.infoBoxPosition[1]);

		upperBox = new PsychUIBox(40, 40, 330, 300, ['newchartEditor_file', 'newchartEditor_edit', 'newchartEditor_view']);
		upperBox.scrollFactor.set();
		upperBox.isMinimized = true;
		upperBox.minimizeOnFocusLost = true;
		upperBox.canMove = false;
		upperBox.cameras = [camUI];
		upperBox.bg.visible = false;
		add(upperBox);

		outputTxt = new EditorsText(25, FlxG.height - 50, FlxG.width - 50, '', 20);
		outputTxt.borderSize = 2;
		outputTxt.font = 'assets/fonts/vcrcn.ttf';
		outputTxt.borderStyle = OUTLINE_FAST;
		outputTxt.scrollFactor.set();
		outputTxt.cameras = [camUI];
		outputTxt.alpha = 0;
		add(outputTxt);

		// Modified status indicator (shows ● when unsaved changes exist)
		modIndicatorTxt = new EditorsText(25, 8, 200, '', 14);
		modIndicatorTxt.font = Paths.font('editors.ttf');
		modIndicatorTxt.setFormat(null, 14, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE_FAST, FlxColor.BLACK);
		modIndicatorTxt.borderSize = 1;
		modIndicatorTxt.scrollFactor.set();
		modIndicatorTxt.cameras = [camUI];
		add(modIndicatorTxt);

		if(PlayState.SONG == null) //Atleast try to avoid crashes
		{
			openNewChart();
		}

		updateJsonData();
		
		// TABS
		////// for main box
		addChartingTab();
		addDataTab();
		addEventsTab();
		addNoteTab();
		addSectionTab();
		addSongTab();
		
		////// for upper box
		addFileTab();
		addEditTab();
		addViewTab();
		//

		loadMusic();
		reloadNotesDropdowns();
		if(!_shouldReset)
		{
			vocals.time = opponentVocals.time = FlxG.sound.music.time = Conductor.songPosition - Conductor.offset;
			if(FlxG.sound.music.time >= vocals.length)
				vocals.pause();
			if(FlxG.sound.music.time >= opponentVocals.length)
				opponentVocals.pause();
		}

		reloadNotes();
		updateGridVisibility();

		// CHARACTERS FOR THE DROP DOWNS
		var gameOverCharacters:Array<String> = loadFileList('characters/', 'data/characterList.txt');
		var characterList:Array<String> = gameOverCharacters.filter((name:String) -> (!name.endsWith('-dead') && !name.endsWith('-death')));
		playerDropDown.list = characterList;
		opponentDropDown.list = characterList;
		girlfriendDropDown.list = characterList;

		gameOverCharacters.insert(0, '');
		gameOverCharacters.sort(function(a:String, b:String)
		{
			if((a == '' || a.endsWith('-dead') || a.endsWith('-death')) && !(b == '' || b.endsWith('-dead') || b.endsWith('-death'))) return -1; //Prioritize "-dead" or "-death" characters
			return 0;
		});
		gameOverCharDropDown.list = gameOverCharacters;

		stageDropDown.list = loadFileList('stages/', 'data/stageList.txt');
		onChartLoaded();

		var tipText:EditorsText = new EditorsText(FlxG.width - 210, FlxG.height - 30, 200, Language.get('newchartEditor_press_f1_for_help', 'Press F1 for Help'), 20);
		tipText.cameras = [camUI];
		tipText.setFormat(Paths.font('editors.ttf'), 16, FlxColor.WHITE, RIGHT);
		tipText.borderColor = FlxColor.BLACK;
		tipText.scrollFactor.set();
		tipText.borderSize = 1;
		tipText.active = false;
		add(tipText);

		tipBg = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		tipBg.cameras = [camUI];
		tipBg.scale.set(FlxG.width, FlxG.height);
		tipBg.updateHitbox();
		tipBg.scrollFactor.set();
		tipBg.visible = tipBg.active = false;
		tipBg.alpha = 0.6;
		add(tipBg);
		
		fullTipText = new EditorsText(0, 0, FlxG.width - 200);
		fullTipText.setFormat(Paths.font('editors.ttf'), Std.parseInt(Language.get('newchartEditor_help_text_size', '24')), FlxColor.WHITE, CENTER);
		fullTipText.cameras = [camUI];
		fullTipText.scrollFactor.set();
		fullTipText.visible = fullTipText.active = false;
		var helpTexts:Array<String> = Language.get('newchartEditor_help_text', '').split('\n');
			if(helpTexts.length > 0 && helpTexts[0] != '')
			{
				fullTipText.text = helpTexts.join('\n');
			}
			else
			{
				fullTipText.text = [
					"W/S/Mouse Wheel - Move Conductor's Time",
					"A/D - Change Sections",
					"Q/E - Decrease/Increase Note Sustain Length",
					"Hold Shift/Alt to Increase/Decrease move by 4x",
					"",
					"F12 - Preview Chart",
					"Enter - Playtest Chart",
					"Space - Stop/Resume song",
					"",
					"Alt + Click - Select Note(s)",
					"Shift + Click - Select/Unselect Note(s)",
					"Right Click - Selection Box",
					"",
					"R - Reset Section",
					"Shift + R - Go Back to the Start of the Song",
					"Z/X - Zoom in/out",
					"Left/Right - Change Snap",
					#if FLX_PITCH
					"Left Bracket / Right Bracket - Change Song Playback Rate",
					"ALT + Left Bracket / Right Bracket - Reset Song Playback Rate",
					#end
					"",
					"Ctrl + Z - Undo",
					"Ctrl + Y - Redo",
					"Ctrl + X - Cut Selected Notes",
					"Ctrl + C - Copy Selected Notes",
					"Ctrl + V - Paste Copied Notes",
					"Ctrl + A - Select all in current Section",
					"Ctrl + S - Quicksave",
				].join('\n');
			}
    
		fullTipText.screenCenter();
		add(fullTipText);
		#if android
		addVirtualPad(LEFT_FULL, NEW_CHART_EDITOR);
		#end
		super.create();
	}

	var gridColors:Array<FlxColor>;
	var gridColorsOther:Array<FlxColor>;
	function changeTheme(changeTo:ChartingTheme, ?doSave:Bool = true)
	{
		var oldTheme:ChartingTheme = theme;
		theme = changeTo;
		chartEditorSave.data.theme = changeTo;
		if(doSave) chartEditorSave.flush();

		switch(theme)
		{
			case LIGHT:
				bg.color = 0xFFA0A0A0;
				gridColors = [0xFFDFDFDF, 0xFFBFBFBF];
				gridColorsOther = [0xFF5F5F5F, 0xFF4A4A4A];
			case DARK:
				bg.color = 0xFF222222;
				gridColors = [0xFF3F3F3F, 0xFF2F2F2F];
				gridColorsOther = [0xFF1F1F1F, 0xFF111111];
			case VSLICE:
				bg.color = 0xFF673AB7;
				gridColors = [0xFFD0D0D0, 0xFFAFAFAF];
				gridColorsOther = [0xFF595959, 0xFF464646];
			case CUSTOM:
				bg.color = CoolUtil.colorFromString(chartEditorSave.data.customBgColor);
				gridColors = [CoolUtil.colorFromString(chartEditorSave.data.customGridColors[0]), CoolUtil.colorFromString(chartEditorSave.data.customGridColors[1])];
				gridColorsOther = [CoolUtil.colorFromString(chartEditorSave.data.customNextGridColors[0]), CoolUtil.colorFromString(chartEditorSave.data.customNextGridColors[1])];
			default:
				bg.color = 0xFF303030;
				gridColors = [0xFFDFDFDF, 0xFFBFBFBF];
				gridColorsOther = [0xFF5F5F5F, 0xFF4A4A4A];
		}

		if(theme != oldTheme || theme == CUSTOM)
		{
			if(gridBg != null)
			{
				gridBg.loadGrid(gridColors[0], gridColors[1]);
				gridBg.vortexLineEnabled = vortexEnabled;
				gridBg.vortexLineSpace = GRID_SIZE * 4 * curZoom;
			}
			if(prevGridBg != null)
			{
				prevGridBg.loadGrid(gridColorsOther[0], gridColorsOther[1]);
				prevGridBg.vortexLineEnabled = vortexEnabled;
				prevGridBg.vortexLineSpace = GRID_SIZE * 4 * curZoom;
			}
			if(nextGridBg != null)
			{
				nextGridBg.loadGrid(gridColorsOther[0], gridColorsOther[1]);
				nextGridBg.vortexLineEnabled = vortexEnabled;
				nextGridBg.vortexLineSpace = GRID_SIZE * 4 * curZoom;
			}
		}
	}

	function openNewChart()
	{
		var song:SwagSong = {
			song: 'Test',
			notes: [],
			events: [],
			bpm: 150,
			needsVoices: true,
			speed: 1,
			offset: 0,

			arrowSkin: '',
			splashSkin: 'noteSplashes',
			player1: 'bf',
			player2: 'dad',
			gfVersion: 'gf',
			stage: 'stage',
			format: 'psych_v1',

            validScore: true,
		};
		Song.chartPath = null;
		loadChart(song);
	}

	function prepareReload()
	{
		if(unsavedChanges)
		{
			openSubState(new editors.content.Prompt(
				Language.get('newchartEditor_unsaved_reload', 'You have unsaved changes.\nReload anyway?'),
				function()
				{
					doPrepareReload();
				}
			));
		}
		else
		{
			doPrepareReload();
		}
	}

	function doPrepareReload():Void
	{
		updateJsonData();
		_cacheSections(); // must be called BEFORE reloadNotes so cachedSectionCrochets is fresh
		loadMusic();
		reloadNotes();
		onChartLoaded();
		updateHeads(true);
		
		autoSaveTime = 0;
		Conductor.songPosition = 0;
		if(FlxG.sound.music != null) FlxG.sound.music.time = 0;
		curSec = 0;
		loadSection();
		forceDataUpdate = true;
		clearUnsaved();
	}

	function onChartLoaded()
	{
		if(PlayState.SONG == null) return;

		// SONG TAB
		songNameInputText.text = PlayState.SONG.song;
		allowVocalsCheckBox.checked = (PlayState.SONG.needsVoices != false); //If the song for some reason does not have this value, it will be set to true

		bpmStepper.value = PlayState.SONG.bpm;
		scrollSpeedStepper.value = PlayState.SONG.speed;
		audioOffsetStepper.value = Reflect.hasField(PlayState.SONG, 'offset') ? PlayState.SONG.offset : 0;
		Conductor.offset = audioOffsetStepper.value;

		playerDropDown.selectedLabel = PlayState.SONG.player1;
		opponentDropDown.selectedLabel = PlayState.SONG.player2;
		girlfriendDropDown.selectedLabel = PlayState.SONG.gfVersion;
		stageDropDown.selectedLabel = PlayState.SONG.stage;
		StageData.loadDirectory(PlayState.SONG);

		// DATA TAB
		gameOverCharDropDown.selectedLabel = PlayState.SONG.gameOverChar;
		gameOverSndInputText.text = PlayState.SONG.gameOverSound;
		gameOverLoopInputText.text = PlayState.SONG.gameOverLoop;
		gameOverRetryInputText.text = PlayState.SONG.gameOverEnd;

		noRGBCheckBox.checked = (PlayState.SONG.disableNoteRGB == true);

		noteTextureInputText.text = PlayState.SONG.arrowSkin;
		noteSplashesInputText.text = PlayState.SONG.splashSkin;
	}
	
	var noteSelectionSine:Float = 0;
	var selectedNotes:Array<MetaNote> = [];
	var ignoreClickForThisFrame:Bool = false;
	var outputAlpha:Float = 0;
	var songFinished:Bool = false;

	#if android
	var _longPressNote:MetaNote = null;
	var _longPressTimer:Float = 0;
	var _longPressThreshold:Float = 0.4; // seconds
	#end

	var fileDialog:FileDialogHandler = new FileDialogHandler();
	var lastFocus:PsychUIInputText;

	var autoSaveTime:Float = 0;
	var autoSaveCap:Int = 2; //in minutes
	var backupLimit:Int = 10;

	var lastBeatHit:Int = 0;
	override function update(elapsed:Float)
	{
		if(!fileDialog.completed)
		{
			lastFocus = PsychUIInputText.focusOn;
			return;
		}

		for (num => key in keysArray)
			_keysPressedBuffer[num] = FlxG.keys.checkStatus(key, JUST_PRESSED);

		if(autoSaveCap > 0)
		{
			autoSaveTime += elapsed / 60.0;
			//trace(autoSaveTime);
			//#if debug if(FlxG.keys.justPressed.J) autoSaveTime += 20/60.0; #end
			if(autoSaveTime >= autoSaveCap #if debug || FlxG.keys.justPressed.NUMPADMULTIPLY #end)
			{
				FlxTween.cancelTweensOf(autoSaveIcon);
				autoSaveTime = 0;
				autoSaveIcon.alpha = 0;
				updateChartData();
				var chartName:String = 'unknown';
				if (PlayState.SONG.song != null) chartName = PlayState.SONG.song;
				if(Song.chartPath != null && PlayState.SONG.song != null)
				{
					chartName = Song.chartPath.replace('\\', '/');
					chartName = chartName.substring(chartName.lastIndexOf('/')+1, chartName.lastIndexOf('.'));
				}

				chartName += DateTools.format(Date.now(), '_%Y-%m-%d_%H-%M-%S');
				var songCopy:SwagSong = Reflect.copy(PlayState.SONG);
				Reflect.setField(songCopy, '__original_path', Song.chartPath);
				var dataToSave:String = haxe.Json.stringify(songCopy);
				//trace(chartName, dataToSave);
				if(!FileSystem.isDirectory('backups')) FileSystem.createDirectory('backups');
				File.saveContent('backups/$chartName.$BACKUP_EXT', dataToSave);

				if(backupLimit > 0)
				{
					var files:Array<String> = FileSystem.readDirectory('backups/').filter((file:String) -> file.endsWith('.$BACKUP_EXT'));
					if(files.length > backupLimit)
					{
						var incorrect:Array<String> = [];
						var map:Map<String, Float> = [];
						for(file in files)
						{
							var split:Array<String> = file.split('_');
							if(split.length > 2) //is properly formatted
							{
								try
								{
									var timeStr:String = split[split.length-1].replace('-', ':');
									timeStr = timeStr.substr(0, timeStr.indexOf('.'));

									var fileJoin:String = split[split.length-2] + ' ' + timeStr;
									var date:Date = Date.fromString(fileJoin);
									//trace(fileJoin, date.getTime());
									map.set(file, date.getTime());
								}
								catch(e:Exception)
								{
									incorrect.push(file);
								}
							}
							else incorrect.push(file);
						}

						if(incorrect.length > 0) files = files.filter((file:String) -> !incorrect.contains(file));
						files.sort(function(a:String, b:String) return map.get(a) > map.get(b) ? 1 : -1);

						while(files.length > backupLimit)
						{
							var file = files.shift();
							//trace('removed $file');
							try
							{
								FileSystem.deleteFile('backups/$file');
							}
							catch(e:Exception) {}
						}
					}
				}

				FlxTween.tween(autoSaveIcon, {alpha: 1}, 0.5, {onComplete: function(_)
					FlxTween.tween(autoSaveIcon, {alpha: 0}, 0.5, {startDelay: 2})
				});
			}
		}

		ClientPrefs.toggleVolumeKeys(PsychUIInputText.focusOn == null);

		var lastTime:Float = Conductor.songPosition;
		outputAlpha = Math.max(0, outputAlpha - elapsed);
		var holdingAlt:Bool = FlxG.keys.pressed.ALT;
		if(FlxG.sound.music != null)
		{
			if(PsychUIInputText.focusOn == null) //If not typing anything
			{
				if(FlxG.keys.justPressed.F12)
				{
					super.update(elapsed);
					openEditorPlayState();
					lastFocus = PsychUIInputText.focusOn;
					return;
				}
				else if(FlxG.keys.justPressed.F1)
				{
					var vis:Bool = !fullTipText.visible;
					tipBg.visible = tipBg.active = fullTipText.visible = fullTipText.active = vis;
				}

				var goingBack:Bool = false;
				if(FlxG.keys.pressed.RBRACKET || (FlxG.keys.pressed.LBRACKET && (goingBack = true)))
				{
					if(holdingAlt)
					{
						if(playbackRate != 1)
						{
							playbackRate = 1;
							setPitch();
						}
					}
					else
					{
						playbackRate = FlxMath.bound(playbackRate + elapsed * (!goingBack ? 1 : -1), playbackSlider.min, playbackSlider.max);
						setPitch();
					}
					playbackSlider.value = playbackRate;
				}

				if(vortexEnabled && _keysPressedBuffer.contains(true))
				{
					var typeSelected:String = noteTypes[noteTypeDropDown.selectedIndex];
					if(typeSelected != null)
					{
						typeSelected = typeSelected.trim();
						if(typeSelected.length < 1) typeSelected = null;
					}

					var sectionStart:Float = cachedSectionTimes[curSec];
					var strumTime:Float = Conductor.songPosition - sectionStart;
					strumTime -= strumTime % (Conductor.stepCrochet * 16 / curQuant);
					strumTime += sectionStart;

					TraceManager.debug('trace.editor.vortexPress', 'Vortex editor press at time: {}', [strumTime]);
					var deletedNotes:Array<MetaNote> = [];
					var addedNotes:Array<MetaNote> = [];
					for (num => press in _keysPressedBuffer)
					{
						if(!press) continue;

						// Try to find a note to delete first
						var didDelete:Bool = false;
						for (note in curRenderedNotes)
						{
							if(note == null || note.isEvent) continue;

							if(note.songData[1] == num && Math.abs(strumTime - note.strumTime) < 1)
							{
								deletedNotes.push(note);
								didDelete = true;
								break;
							}
						}

						if(didDelete) continue;

						// If no notes were found, add a new in its place
						var didAdd:Bool = false;
						var noteSetupData:Array<Dynamic> = [strumTime, num, 0];
						if(typeSelected != null) noteSetupData.push(typeSelected);
	
						var noteAdded:MetaNote = createNote(noteSetupData);
						for (num in sectionFirstNoteID...notes.length)
						{
							var note = notes[num];
							if(note.strumTime >= strumTime)
							{
								notes.insert(num, noteAdded);
								didAdd = true;
								break;
							}
						}
						if(!didAdd) notes.push(noteAdded);
						addedNotes.push(noteAdded);
					}

					if(deletedNotes.length > 0)
					{
						var wasSelected:Bool = false;
						for (note in deletedNotes)
						{
							if(selectedNotes.contains(note))
							{
								selectedNotes.remove(note);
								wasSelected = true;
							}
							notes.remove(note);
						}
						if(wasSelected) onSelectNote();
						addUndoAction(DELETE_NOTE, {notes: deletedNotes});
					}
					if(addedNotes.length > 0)
						addUndoAction(ADD_NOTE, {notes: addedNotes});

					softReloadNotes(true);
				}
				else if((#if android virtualPad.buttonLeft.justPressed || #end FlxG.keys.justPressed.A) != (#if android virtualPad.buttonRight.justPressed || #end FlxG.keys.justPressed.D) && !holdingAlt)
				{
					if(FlxG.sound.music.playing)
						setSongPlaying(false);

					var shiftAdd:Int = (#if android virtualPad.buttonY.pressed || #end FlxG.keys.pressed.SHIFT) ? 4 : 1;

					if(#if android virtualPad.buttonLeft.justPressed || #end FlxG.keys.justPressed.A)
					{
						if(curSec - shiftAdd < 0) shiftAdd = curSec;

						if(shiftAdd > 0)
						{
							loadSection(curSec - shiftAdd);
							var targetTime:Float = cachedSectionTimes[curSec] - Conductor.offset + 0.000001;
							FlxTween.cancelTweensOf(FlxG.sound.music);
							FlxTween.tween(FlxG.sound.music, {time: targetTime}, 0.2, {ease: FlxEase.circOut});
							Conductor.songPosition = targetTime;
						}
					}
					else if(#if android virtualPad.buttonRight.justPressed || #end FlxG.keys.justPressed.D)
					{
						if(curSec + shiftAdd >= PlayState.SONG.notes.length) shiftAdd = PlayState.SONG.notes.length - curSec - 1;
                        
						if(shiftAdd > 0)
						{
							loadSection(curSec + shiftAdd);
							var targetTime:Float = cachedSectionTimes[curSec] - Conductor.offset + 0.000001;
							FlxTween.cancelTweensOf(FlxG.sound.music);
							FlxTween.tween(FlxG.sound.music, {time: targetTime}, 0.2, {ease: FlxEase.circOut});
							Conductor.songPosition = targetTime;
						}
					}
				}
				else if(FlxG.keys.justPressed.HOME)
				{
					setSongPlaying(false);
					loadSection(0);
					FlxTween.cancelTweensOf(FlxG.sound.music);
					FlxTween.tween(FlxG.sound.music, {time: 0}, 0.3, {ease: FlxEase.circOut});
					Conductor.songPosition = 0;
				}
				else if(FlxG.keys.justPressed.END)
				{
					setSongPlaying(false);
					loadSection(PlayState.SONG.notes.length - 1);
					Conductor.songPosition = FlxG.sound.music.time = FlxG.sound.music.length - 1;
				}
				else if(FlxG.keys.justPressed.R)
				{
					var timeToGoBack:Float = 0;
					if(#if android !virtualPad.buttonY.pressed || #end !FlxG.keys.pressed.SHIFT) timeToGoBack = cachedSectionTimes[curSec] + (curSec > 0 ? 0.000001 : 0);
					else loadSection(0);
					FlxTween.cancelTweensOf(FlxG.sound.music);
					FlxTween.tween(FlxG.sound.music, {time: timeToGoBack}, 0.2, {ease: FlxEase.circOut});
					Conductor.songPosition = timeToGoBack;
				}
				else if(!PsychUIDropDownMenu.anyDropdownOpen && ((FlxG.keys.pressed.W #if android || virtualPad.buttonUp.pressed #end) != (FlxG.keys.pressed.S #if android || virtualPad.buttonDown.pressed #end) || FlxG.mouse.wheel != 0))
				{
					if(FlxG.sound.music.playing)
						setSongPlaying(false);

					if(mouseSnapCheckBox.checked && FlxG.mouse.wheel != 0)
					{
						var snap:Float = Conductor.stepCrochet / (curQuant/16) / curZoom;
						var timeAdd:Float = (#if android virtualPad.buttonY.pressed || #end FlxG.keys.pressed.SHIFT ? 4 : 1) / (holdingAlt ? 4 : 1) * -FlxG.mouse.wheel * snap;
						var targetTime:Float = Math.round((FlxG.sound.music.time + timeAdd) / snap) * snap;
						if(targetTime > 0) targetTime += 0.000001;
						FlxTween.cancelTweensOf(FlxG.sound.music);
						FlxTween.tween(FlxG.sound.music, {time: targetTime}, 0.15, {ease: FlxEase.circOut});
					}
					else
					{
						var speedMult:Float = (#if android virtualPad.buttonY.pressed || #end FlxG.keys.pressed.SHIFT ? 4 : 1) * (FlxG.mouse.wheel != 0 ? 4 : 1) / (holdingAlt ? 4 : 1);
						if((FlxG.keys.pressed.W #if android || virtualPad.buttonUp.pressed #end) || FlxG.mouse.wheel > 0)
							FlxG.sound.music.time -= Conductor.crochet * speedMult * 1.5 * elapsed / curZoom;
						else if((FlxG.keys.pressed.S #if android || virtualPad.buttonDown.pressed #end) || FlxG.mouse.wheel < 0)
							FlxG.sound.music.time += Conductor.crochet * speedMult * 1.5 * elapsed / curZoom;
					}

					FlxG.sound.music.time = FlxMath.bound(FlxG.sound.music.time, 0, FlxG.sound.music.length - 1);
					if(FlxG.sound.music.playing) setSongPlaying(!FlxG.sound.music.playing);
				}
				else if(#if android virtualPad.buttonX.justPressed || #end FlxG.keys.justPressed.SPACE)
				{
					setSongPlaying(!FlxG.sound.music.playing);
				}
			}

			if(!songFinished) Conductor.songPosition = FlxMath.bound(FlxG.sound.music.time + Conductor.offset, 0, FlxG.sound.music.length - 1);
			updateScrollY();
		}

		super.update(elapsed);

		if(songFinished)
		{
			onSongComplete();
			lastTime = FlxG.sound.music.time;
			songFinished = false;
		}
		else if(FlxG.sound.music != null)
		{
			if(FlxG.sound.music.time >= vocals.length)
				vocals.pause();
			if(FlxG.sound.music.time >= opponentVocals.length)
				opponentVocals.pause();

			while(curSec > 0 && Conductor.songPosition < cachedSectionTimes[curSec])
				loadSection(curSec - 1);
			while(curSec < cachedSectionTimes.length - 1 && Conductor.songPosition >= cachedSectionTimes[curSec + 1])
				loadSection(curSec + 1);
		}

		if(PsychUIInputText.focusOn == null && lastFocus == null)
		{
			var doCut:Bool = false;
			var canContinue:Bool = true;
			if(#if android virtualPad.buttonA.justPressed || #end FlxG.keys.justPressed.ENTER)
			{
				goToPlayState();
				return;
			}
			else if(FlxG.keys.pressed.CONTROL && !isMovingNotes && (FlxG.keys.justPressed.Z || FlxG.keys.justPressed.Y || FlxG.keys.justPressed.X ||
				FlxG.keys.justPressed.C || FlxG.keys.justPressed.V || FlxG.keys.justPressed.A || FlxG.keys.justPressed.S || FlxG.keys.justPressed.R))
			{
				canContinue = false;
				if(FlxG.keys.justPressed.Z)
					undo();
				else if(FlxG.keys.justPressed.Y)
					redo();
				else if((doCut = FlxG.keys.justPressed.X) || FlxG.keys.justPressed.C) // Cut (Ctrl + X) and Copy (Ctrl + C)
				{
					if(selectedNotes.length > 0)
					{
						copiedNotes = [];
						copiedEvents = [];
						var pushedNotes:Array<Array<Dynamic>> = [];

						for (note in selectedNotes)
						{
							if(note == null) continue;

							var copied:Array<Dynamic> = makeNoteDataCopy(note.songData, note.isEvent);
							pushedNotes.push(copied);
							if(note.isEvent) copiedEvents.push(copied);
							else copiedNotes.push(copied);
						}
						pushedNotes.sort((a:Array<Dynamic>, b:Array<Dynamic>) -> FlxSort.byValues(FlxSort.ASCENDING, a[0], b[0]));
						
						var minTime:Float = pushedNotes[0][0];
						for (note in pushedNotes)
							note[0] -= minTime;
					}
				}
				else if(FlxG.keys.justPressed.V) // Paste (Ctrl + V)
				{
					if(copiedNotes.length > 0 || copiedEvents.length > 0)
					{
						selectionBox.visible = false;
						stopMovingNotes();
						resetSelectedNotes();
						selectedNotes = pasteCopiedNotesToSection();
						selectedNotes.sort(PlayState.sortByTime);

						var didFind:Bool = false;
						var minNoteData:Float = Math.POSITIVE_INFINITY;
						for (note in selectedNotes)
						{
							if(note == null || note.isEvent) continue;

							if(minNoteData > note.songData[1]) minNoteData = note.songData[1];
							didFind = true;
						}
						if(!didFind) minNoteData = 0;
						
						var pushedNotes:Array<MetaNote> = [];
						var pushedEvents:Array<EventMetaNote> = [];
						for (note in selectedNotes)
						{
							if(note == null) continue;

							if(!note.isEvent)
							{
								note.changeNoteData(Std.int(note.songData[1] - minNoteData));
								pushedNotes.push(note);
							}
							else pushedEvents.push(cast (note, EventMetaNote));
						}
						addUndoAction(ADD_NOTE, {notes: pushedNotes, events: pushedEvents});
						moveSelectedNotes(Std.int(minNoteData), selectedNotes[0].y);
					}
				}
				else if(FlxG.keys.justPressed.A) // Select All (Ctrl + A)
				{
					var sel = selectedNotes;
					selectedNotes = curRenderedNotes.members.copy();
					addUndoAction(SELECT_NOTE, {old: sel, current: selectedNotes.copy()});
					onSelectNote();
					TraceManager.debug('trace.editor.noteSelected', 'Notes selected: {}', [selectedNotes.length]);
				}
				else if(FlxG.keys.justPressed.S) // Save (Ctrl + S)
					saveChart();
				else if(FlxG.keys.justPressed.R) // Reload (Ctrl + R)
				{
					if(Song.chartPath != null)
					{
						prepareReload();
						showOutput('newchartEditor_reloaded', false);
					}
					else
						showOutput('newchartEditor_no_chart_loaded', true);
				}
			}
			
			if(doCut || FlxG.keys.justPressed.DELETE || FlxG.keys.justPressed.BACKSPACE || (isMovingNotes && (FlxG.mouse.justPressedRight || FlxG.keys.justPressed.ESCAPE))) // Delete button
			{
				if(selectedNotes.length > 0)
				{
					var removedNotes:Array<MetaNote> = [];
					var removedEvents:Array<EventMetaNote> = [];
					while(selectedNotes.length > 0)
					{
						var note:MetaNote = selectedNotes[0];
						selectedNotes.shift();
						if(note == null) continue;
		
						var kind:String = !note.isEvent ? 'note' : 'event';
						TraceManager.debug('trace.editor.noteRemoved', 'Removed {} at time: {}', [kind, note.strumTime]);
						if(!note.isEvent)
						{
							notes.remove(note);
							removedNotes.push(note);
						}
						else
						{
							var ev:EventMetaNote = cast (note, EventMetaNote);
							events.remove(ev);
							removedEvents.push(ev);
						}
					}
					movingNotes.clear();
					isMovingNotes = false;
					selectedNotes = [];
					onSelectNote();
					softReloadNotes();
					addUndoAction(DELETE_NOTE, {notes: removedNotes, events: removedEvents});
				}
			}
			else if(canContinue)
			{
				if(FlxG.keys.justPressed.LEFT != FlxG.keys.justPressed.RIGHT) //Lower/Higher quant
				{
					if(FlxG.keys.justPressed.LEFT)
						curQuant = quantizations[Std.int(Math.max(quantizations.indexOf(curQuant) - 1, 0))];
					else
						curQuant = quantizations[Std.int(Math.min(quantizations.indexOf(curQuant) + 1, quantizations.length - 1))];
					forceDataUpdate = true;
				}
			if (#if android virtualPad.buttonZ.justPressed || #end FlxG.keys.justPressed.Z != #if android virtualPad.buttonD.justPressed || #end FlxG.keys.justPressed.X) //Decrease/Increase Zoom
				{
					if (#if android virtualPad.buttonZ.justPressed || #end FlxG.keys.justPressed.Z)
						curZoom = zoomList[Std.int(Math.max(zoomList.indexOf(curZoom) - 1, 0))];
					else
						curZoom = zoomList[Std.int(Math.min(zoomList.indexOf(curZoom) + 1, zoomList.length - 1))];
					notes.sort(PlayState.sortByTime);
					var noteSec:Int = 0;
					for (num => note in notes)
					{
						if(note == null) continue;
						while(noteSec < cachedSectionTimes.length - 1 && cachedSectionTimes[noteSec + 1] <= note.strumTime) noteSec++;
						note.updateSustainToZoom(cachedSectionCrochets[noteSec] / 4, curZoom);
						var targetY:Float = calcNoteY(note.strumTime, noteSec, curZoom);
						targetY += (GRID_SIZE/2 - note.height/2);
						note.chartY = targetY;
						// Skip per-note FlxTween for large note counts
						note.y = targetY;
					}

					noteSec = 0;
					for (event in events)
					{
						while(noteSec < cachedSectionTimes.length - 1 && cachedSectionTimes[noteSec + 1] <= event.strumTime) noteSec++;
						var targetY:Float = calcNoteY(event.strumTime, noteSec, curZoom);
						targetY += (GRID_SIZE/2 - event.height/2);
						event.y = targetY;
					}
					loadSection();
					showOutput('${Language.get('newchartEditor_error_zoom','Zoom')}: ${Math.round(curZoom * 100)}%');
					updateScrollY();
				}
			}
		}

		if(selectionBox.visible)
		{
			if(FlxG.mouse.releasedRight)
			{
				var sel = selectedNotes.copy();
				updateSelectionBox();
				if(#if android !virtualPad.buttonY.pressed || #end !FlxG.keys.pressed.SHIFT && !holdingAlt)
					resetSelectedNotes();

				var selectionBounds = selectionBox.getScreenBounds(null, camUI);
				for (note in curRenderedNotes)
				{
					if(note == null) continue;

					if(!selectedNotes.contains(note) || holdingAlt /*&& FlxG.overlap(selectionBox, note)*/) //overlap doesnt work here
					{
						var noteBounds = note.getScreenBounds(null, camUI);
						noteBounds.top -= scrollY;
						noteBounds.bottom -= scrollY;

						if(selectionBounds.overlaps(noteBounds))
						{
							if(holdingAlt && selectedNotes.contains(note))
							{
								selectedNotes.remove(note);
								note.colorTransform.redMultiplier = note.colorTransform.greenMultiplier = note.colorTransform.blueMultiplier = 1;
								if(note.animation.curAnim != null) note.animation.curAnim.curFrame = 0;
							}
							else selectedNotes.push(note);
							onSelectNote();
						}
					}
				}
				selectionBox.visible = false;
				addUndoAction(SELECT_NOTE, {old: sel, current: selectedNotes.copy()});
			}
			else if(FlxG.mouse.justMoved)
				updateSelectionBox();
		}
		else if(FlxG.mouse.pressedRight && (FlxG.mouse.deltaScreenX != 0 || FlxG.mouse.deltaScreenY != 0))
		{
			selectionBox.setPosition(FlxG.mouse.screenX, FlxG.mouse.screenY);
			selectionStart.set(FlxG.mouse.screenX, FlxG.mouse.screenY);
			selectionBox.visible = true;
			updateSelectionBox();
		}
		
		if(FlxG.mouse.justPressed && (FlxG.mouse.overlaps(mainBox.bg) || FlxG.mouse.overlaps(infoBox.bg)
			#if android
			|| (virtualPad != null && virtualPad.isMouseOverAnyButton())
			#end
		))
			ignoreClickForThisFrame = true;

		var minX:Float = gridBg.x;
		if(SHOW_EVENT_COLUMN && lockedEvents) minX += GRID_SIZE;

		if(isMovingNotes && FlxG.mouse.justReleased)
			stopMovingNotes();

		if(FlxG.mouse.x >= minX && FlxG.mouse.x < gridBg.x + gridBg.width)
		{
			var diffX:Float = FlxG.mouse.x - gridBg.x;
			var diffY:Float = FlxG.mouse.y - gridBg.y;
			if(#if android !virtualPad.buttonY.pressed || #end !FlxG.keys.pressed.SHIFT)
				diffY -= diffY % (GRID_SIZE / (curQuant/16));

			if(nextGridBg.visible) diffY = Math.min(diffY, gridBg.height + nextGridBg.height);
			else diffY = Math.min(diffY, gridBg.height);

			if(prevGridBg.visible) diffY = Math.max(diffY, -prevGridBg.height);
			else diffY = Math.max(diffY, 0);

			var noteData:Int = Math.floor(diffX / GRID_SIZE);
			dummyArrow.visible = !selectionBox.visible;
			dummyArrow.x = gridBg.x + noteData * GRID_SIZE;
			if(SHOW_EVENT_COLUMN)
				noteData--;

			if(#if android virtualPad.buttonY.pressed || #end FlxG.keys.pressed.SHIFT || FlxG.mouse.y >= gridBg.y || !prevGridBg.visible)
				dummyArrow.y = gridBg.y + diffY;
			else
			{
				var t:Float = (diffY - (GRID_SIZE / (curQuant/16)));
				if(FlxG.mouse.y >= gridBg.y) t *= curZoom;
				dummyArrow.y = gridBg.y + t;
			}

			if(isMovingNotes)
			{
				// Move note data
				var nData:Int = Std.int(Math.max(0, noteData));
				if(movingNotesLastData != nData)
				{
					var isFirst:Bool = true;
					var movingNotesMinData:Int = 0;
					var movingNotesMaxData:Int = 0;
					for (note in selectedNotes) //Find boundaries first
					{
						if(note == null || note.isEvent) continue;
	
						var data:Int = note.songData[1];
						if(isFirst || data < movingNotesMinData) movingNotesMinData = data;
						if(data > movingNotesMaxData) movingNotesMaxData = data;
						isFirst = false;
					}

					var diff:Int = nData - movingNotesLastData;
					var maxn:Int = (GRID_PLAYERS * GRID_COLUMNS_PER_PLAYER) - 1;
					movingNotesMinData += diff;
					movingNotesMaxData += diff;
					if(movingNotesMinData < 0)
						diff -= movingNotesMinData;
					else if(movingNotesMaxData > maxn)
						diff -= movingNotesMaxData - maxn;

					for (note in movingNotes)
					{
						if(note == null || note.isEvent) continue; //Events shouldn't change note data as they don't have one

						note.changeNoteData(note.songData[1] + diff);
						positionNoteXByData(note);
					}
				}
				movingNotesLastData = nData;

				// Move note strum time
				if(dummyArrow.y != movingNotesLastY)
				{
					var diff:Float = dummyArrow.y - movingNotesLastY;
					var curSecRow:Int = 0;
					for (note in movingNotes) //Try to figure out new strum time for the notes, DEFINITELY INACCURATE WITH BPM CHANGING, ALTHOUGH UNTESTED
					{
						if(note == null) continue;

						note.chartY += diff;
						var row:Float = (note.chartY / GRID_SIZE) * curZoom;
						while(curSecRow + 1 < cachedSectionRow.length && cachedSectionRow[curSecRow] <= row)
						{
							curSecRow++;
						}

						note.setStrumTime(Math.max(-5000, note.strumTime + (diff * cachedSectionCrochets[curSecRow] / 4) / GRID_SIZE * curZoom));
						positionNoteYOnTime(note, curSecRow);
						if(note.isEvent) cast (note, EventMetaNote).updateEventText();
					}
					movingNotesLastY = dummyArrow.y;
				}
			}
			else if(FlxG.mouse.justPressed && !ignoreClickForThisFrame)
			{
				if(FlxG.mouse.x >= gridBg.x && FlxG.mouse.x < gridBg.x + gridBg.width)
				{
					var closest:MetaNote = null;
					if(FlxG.mouse.overlaps(curRenderedNotes))
					{
						for (note in curRenderedNotes)
						{
							if(note != null && FlxG.mouse.overlaps(note))
							{
								var isMatch:Bool = (note.isEvent && noteData < 0) || (!note.isEvent && note.songData[1] == noteData);
								if(isMatch && (!note.isEvent || !lockedEvents))
								{
									closest = note;
									break;
								}
							}
						}
					}
					if(closest != null)
					{
						if(FlxG.keys.pressed.CONTROL) // Ctrl+Click = Select Note (like ChartingState)
						{
							var sel = selectedNotes.copy();
							resetSelectedNotes();
							selectedNotes.push(closest);
							addUndoAction(SELECT_NOTE, {old: sel, current: selectedNotes.copy()});
							TraceManager.debug('trace.editor.noteSelected', 'Notes selected: {}', [selectedNotes.length]);
						}
						else if(FlxG.keys.pressed.SHIFT || holdingAlt) // Shift/Alt+Click = Select/Unselect Note
						{
							var sel = selectedNotes.copy();
							if(!selectedNotes.contains(closest))
							{
								selectedNotes.push(closest);
								addUndoAction(SELECT_NOTE, {old: sel, current: selectedNotes.copy()});
							}
							else if(!holdingAlt)
							{
								resetSelectedNotes();
								selectedNotes.remove(closest);
								addUndoAction(SELECT_NOTE, {old: sel, current: selectedNotes.copy()});
							}
							TraceManager.debug('trace.editor.noteSelected', 'Notes selected: {}', [selectedNotes.length]);
						}
						else // Click = Delete immediately (like ChartingState)
						{
							#if android
							// On Android: start long-press timer instead of deleting immediately.
							// Hold finger on note > 0.4s to select it; release early to delete.
							_longPressNote = closest;
							_longPressTimer = 0;
							#else
							doDeleteNote(closest);
							#end
						}
						if(selectedNotes.length == 1) onSelectNote();
						forceDataUpdate = true;
					}
					else if(FlxG.keys.pressed.CONTROL) // Ctrl+Click on empty space = Move selected notes
					{
						if(selectedNotes.length > 0)
							moveSelectedNotes(noteData, dummyArrow.y);
						else
							showOutput('newchartEditor_error_note_must_select', true);
					}
					else if(!holdingAlt && FlxG.mouse.y >= gridBg.y && FlxG.mouse.y < gridBg.y + gridBg.height) // Add note
					{
						var strumTime:Float = (diffY / GRID_SIZE * (cachedSectionCrochets[curSec] / 4) / curZoom) + cachedSectionTimes[curSec];
						if(noteData >= 0)
						{
							TraceManager.debug('trace.editor.noteAdded', 'Added note at time: {}', [strumTime]);
							var didAdd:Bool = false;

							var noteSetupData:Array<Dynamic> = [strumTime, noteData, 0];
							var typeSelected:String = noteTypes[noteTypeDropDown.selectedIndex].trim();
							if(typeSelected != null && typeSelected.length > 0)
								noteSetupData.push(typeSelected);

							var noteAdded:MetaNote = createNote(noteSetupData);
							for (num in sectionFirstNoteID...notes.length)
							{
								var note = notes[num];
								if(note.strumTime >= strumTime)
								{
									notes.insert(num, noteAdded);
									didAdd = true;
									break;
								}
							}
							if(!didAdd) notes.push(noteAdded);

							if(!holdingAlt)
								resetSelectedNotes();

							selectedNotes.push(noteAdded);
							addUndoAction(ADD_NOTE, {notes: [noteAdded]});
						}
						else if(!lockedEvents)
						{
							TraceManager.debug('trace.editor.eventAdded', 'Added event at time: {}', [strumTime]);
							var didAdd:Bool = false;

							var eventAdded:EventMetaNote = createEvent([strumTime, [[eventsList[Std.int(Math.max(eventDropDown.selectedIndex, 0))][0], value1InputText.text, value2InputText.text]]]);
							for (num in sectionFirstEventID...events.length)
							{
								var event = events[num];
								if(event.strumTime >= strumTime)
								{
									events.insert(num, eventAdded);
									didAdd = true;
									break;
								}
							}
							if(!didAdd) events.push(eventAdded);

							if(!holdingAlt)
								resetSelectedNotes();

							selectedNotes.push(eventAdded);
							addUndoAction(ADD_NOTE, {events: [eventAdded]});
						}
						onSelectNote();
						softReloadNotes();
					}
				}
			}
		}
		else if(!ignoreClickForThisFrame)
		{
			if(FlxG.mouse.justPressed)
				resetSelectedNotes();

			dummyArrow.visible = false;
		}
		ignoreClickForThisFrame = false;

		#if android
		// Android long-press: hold finger on a note > 0.4s → select it (like Ctrl+Click)
		if (_longPressNote != null)
		{
			if (FlxG.mouse.justReleased)
			{
				// Released early → delete the note
				if (_longPressNote.exists)
					doDeleteNote(_longPressNote);
				_longPressNote = null;
			}
			else if (FlxG.mouse.pressed && FlxG.mouse.overlaps(_longPressNote))
			{
				_longPressTimer += elapsed;
				if (_longPressTimer >= _longPressThreshold)
				{
					// Long-press threshold reached → select the note (Ctrl+Click behavior)
					if (_longPressNote.exists)
					{
						var sel = selectedNotes.copy();
						resetSelectedNotes();
						selectedNotes.push(_longPressNote);
						addUndoAction(SELECT_NOTE, {old: sel, current: selectedNotes.copy()});
						onSelectNote();
						forceDataUpdate = true;
						TraceManager.debug('trace.editor.noteSelected', 'Android long-press selected note');
					}
					_longPressNote = null;
				}
			}
			else
			{
				// Finger moved off the note → cancel
				_longPressNote = null;
			}
		}
		#end

		if(Conductor.songPosition != lastTime || forceDataUpdate)
		{
			var curTime:String = FlxStringUtil.formatTime(Conductor.songPosition / 1000, true);
			var songLength:String = (FlxG.sound.music != null) ? FlxStringUtil.formatTime(FlxG.sound.music.length / 1000, true) : '???';
			var str:String =  '$curTime / $songLength' +
							  '\n\n${Language.get('newchartEditor_section',"Section")}: $curSec' +
							  '\n${Language.get('newchartEditor_beat',"Beat")}: $curBeat' +
							  '\n${Language.get('newchartEditor_step',"Step")}: $curStep' +
							  '\n\n${Language.get('newchartEditor_beat_snap',"Beat Snap")}: ${curQuant} / 16' +
							  '\n${Language.get('newchartEditor_selected',"Selected")}: ${selectedNotes.length}';
			if(str != infoText.text)
			{
				infoText.text = str;
				if(infoText.autoSize) infoText.autoSize = false;
			}

			var playing:Bool = (FlxG.sound.music != null && FlxG.sound.music.playing);
			var songPos:Float = Conductor.songPosition;

			// Mark dirty when position changes (triggers note alpha refresh)
			if(Conductor.songPosition != lastTime) _noteAlphaDirty = true;

			if(_noteAlphaDirty)
			{
				for (note in curRenderedNotes)
				{
					if(note == null || note.isEvent) continue;
					note.alpha = (note.strumTime >= songPos) ? 1 : 0.6;
				}
				_noteAlphaDirty = false;
			}

			// Only check hitsound / vortex animation while playing
			if(playing && lastTime < songPos)
			{
				var hitSoundPlayer:Bool = (hitsoundPlayerStepper.value > 0);
				var hitSoundOpp:Bool = (hitsoundOpponentStepper.value > 0);
				var vortexPlaying:Bool = (vortexEnabled && playing);
				for (note in curRenderedNotes)
				{
					if(note == null || note.isEvent) continue;
					if(songPos > note.strumTime && lastTime <= note.strumTime)
					{
						if(hitSoundPlayer && note.mustPress)
						{
							FlxG.sound.play(Paths.sound('hitsound'), hitsoundPlayerStepper.value);
							hitSoundPlayer = false;
						}
						else if(hitSoundOpp && !note.mustPress)
						{
							FlxG.sound.play(Paths.sound('hitsound'), hitsoundOpponentStepper.value);
							hitSoundOpp = false;
						}

						if(vortexPlaying)
						{
							var strumNote:StrumNote = strumLineNotes.members[note.songData[1]];
							if(strumNote != null)
							{
								strumNote.playAnim('confirm', true);
								strumNote.resetAnim = Math.max(Conductor.stepCrochet * 1.25, note.sustainLength) / 1000 / playbackRate;
							}
						}
					}
				}
			}
			forceDataUpdate = false;
			
			// moved from beatHit()
			if(metronomeStepper.value > 0 && lastBeatHit != curBeat)
				FlxG.sound.play(Paths.sound('Metronome_Tick'), metronomeStepper.value);

			lastBeatHit = curBeat;
		}

		if(selectedNotes.length > 0)
		{
			noteSelectionSine += elapsed;
			var sineValue:Float = 0.75 + Math.cos(Math.PI * noteSelectionSine * (isMovingNotes ? 8 : 2)) / 4;
			//trace(sineValue);

			var qPress = #if android virtualPad.buttonUp2.justPressed  || #end FlxG.keys.justPressed.Q;
			var ePress = #if android virtualPad.buttonDown2.justPressed  || #end FlxG.keys.justPressed.E;
			var addSus = (FlxG.keys.pressed.SHIFT ? 4 : 1) * (Conductor.stepCrochet / 2);
			if(qPress) addSus *= -1;

			if(qPress != ePress && selectedNotes.length != 1)
				susLengthStepper.value += addSus;

			var noteSec:Int = 0;
			for (note in selectedNotes)
			{
				if(note == null || !note.exists) continue;

				if(!note.isEvent)
				{
					if(qPress != ePress)
					{
						while(cachedSectionTimes.length > noteSec + 1 && cachedSectionTimes[noteSec + 1] <= note.strumTime)
							noteSec++;

						note.setSustainLength(note.sustainLength + addSus, cachedSectionCrochets[noteSec] / 4, curZoom);
						if(selectedNotes.length == 1)
							susLengthStepper.value = note.sustainLength;
					}
					note.animation.update(elapsed); //let selected notes be animated for better visibility
				}
				note.colorTransform.redMultiplier = note.colorTransform.greenMultiplier = note.colorTransform.blueMultiplier = sineValue;
			}
		}
		else noteSelectionSine = 0;

		outputTxt.alpha = outputAlpha;
		outputTxt.visible = (outputAlpha > 0);

		// Update modified indicator
		if(modIndicatorTxt != null)
		{
			if(unsavedChanges)
			{
				modIndicatorTxt.text = '● ' + Language.get('newchartEditor_modified', 'Modified');
				modIndicatorTxt.color = FlxColor.YELLOW;
			}
			else
			{
				modIndicatorTxt.text = '● ' + Language.get('newchartEditor_saved', 'Saved');
				modIndicatorTxt.color = FlxColor.LIME;
			}
		}

		FlxG.camera.scroll.y = scrollY;
		camUI.scroll.y = 0;
		lastFocus = PsychUIInputText.focusOn;
	}

	function moveSelectedNotes(noteData:Int = 0, lastY:Float) //This turns selected notes into moving notes
	{
		var originalNotes:Array<MetaNote> = [];
		var originalEvents:Array<EventMetaNote> = [];
		var movedNotes:Array<MetaNote> = [];
		var movedEvents:Array<EventMetaNote> = [];
		for (note in selectedNotes)
		{
			if(note == null) continue;

			if(!note.isEvent)
			{
				notes.remove(note);
				var secNum:Int = 0;
				for (time in cachedSectionTimes)
				{
					if(time > note.strumTime) break;
					secNum++;
				}
				originalNotes.push(note);
				var mov:MetaNote = createNote(note.songData, secNum);
				movingNotes.add(mov);
				movedNotes.push(mov);
			}
			else
			{
				events.remove(cast (note, EventMetaNote));
				originalEvents.push(cast (note, EventMetaNote));
				var mov:EventMetaNote = createEvent(note.songData);
				movingNotes.add(mov);
				movedEvents.push(mov);
			}
		}
		selectedNotes = movingNotes.members.copy();
		isMovingNotes = true;
		movingNotesLastY = lastY;
		movingNotesLastData = noteData;
		movingNotes.sort(cast PlayState.sortByTime);
		addUndoAction(MOVE_NOTE, {originalNotes: originalNotes, originalEvents: originalEvents, movedNotes: movedNotes, movedEvents: movedEvents});
		softReloadNotes();
	}

	function stopMovingNotes() //This turns moving notes into saved notes
	{
		var pushedNotes:Array<MetaNote> = [];
		var pushedEvents:Array<EventMetaNote> = [];
		movingNotes.forEachAlive(function(note:MetaNote)
		{
			if(!note.isEvent)
			{
				notes.push(note);
				pushedNotes.push(note);
			}
			else
			{
				events.push(cast (note, EventMetaNote));
				pushedEvents.push(cast (note, EventMetaNote));
			}
		});
		notes.sort(PlayState.sortByTime);
		events.sort(PlayState.sortByTime);
		movingNotes.clear();
		isMovingNotes = false;
		markUnsaved();
		softReloadNotes();
	}

	function makeNoteDataCopy(originalData:Array<Dynamic>, isEvent:Bool)
	{
		var dataCopy:Array<Dynamic> = originalData.copy();
		if(isEvent)
		{
			var eventGrp:Array<Array<Dynamic>> = cast dataCopy[1].copy();
			for (num => subEvent in eventGrp)
				eventGrp[num] = subEvent.copy();

			dataCopy[1] = eventGrp;
		}
		return dataCopy;
	}

	function updateScrollY()
	{
		var secStartTime:Null<Float> = cast cachedSectionTimes[curSec];
		var secCrochet:Null<Float> = cast cachedSectionCrochets[curSec];
		var secRows:Null<Float> = cast cachedSectionRow[curSec];
		if(secStartTime == null || secCrochet == null || secRows == null) return;

		scrollY = (((Conductor.songPosition - secStartTime) / secCrochet * GRID_SIZE * 4) + (secRows * GRID_SIZE)) * curZoom - FlxG.height/2;
	}

	function updateSelectionBox()
	{
		var diffX:Float = FlxG.mouse.screenX - selectionStart.x;
		var diffY:Float = FlxG.mouse.screenY - selectionStart.y;
		selectionBox.setPosition(selectionStart.x, selectionStart.y);

		if(diffX < 0) //Fixes negative X scale
		{
			diffX = Math.abs(diffX);
			selectionBox.x -= diffX;
		}
		if(diffY < 0) //Fixes negative Y scale
		{
			diffY = Math.abs(diffY);
			selectionBox.y -= diffY;
		}
		selectionBox.scale.set(diffX, diffY);
		selectionBox.updateHitbox();
	}

	/** Mark the chart as having unsaved changes. */
	function markUnsaved():Void
	{
		unsavedChanges = true;
	}

	/** Clear the unsaved changes flag (called after save / load / discard). */
	function clearUnsaved():Void
	{
		unsavedChanges = false;
	}

	function showOutput(message:String, isError:Bool = false, ?params:Array<Dynamic> = null)
	{
		if (Language.has(message))
			message = Language.get(message);
		if (params != null) {
			var paramIndex:Int = 0;
			while (message.indexOf('%s') != -1 && paramIndex < params.length) {
				message = StringTools.replace(message, '%s', Std.string(params[paramIndex]));
				paramIndex++;
			}
		}

		trace(message);
		outputTxt.text = message;
		outputTxt.y = FlxG.height - outputTxt.height - 30;
		outputTxt.font = 'assets/fonts/editors.ttf';
		outputAlpha = 4;


		if(isError)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'), 0.6);
			outputTxt.color = FlxColor.RED;
		}
		else
		{
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
			outputTxt.color = FlxColor.WHITE;
		}
	}

	/** Show an exit-confirmation prompt if there are unsaved changes. */
	function confirmExit(?onConfirm:Void->Void):Void
	{
		if(unsavedChanges)
		{
			openSubState(new editors.content.Prompt(
				Language.get('newchartEditor_unsaved_exit', 'There\'s unsaved progress,\nare you sure you want to exit?'),
				function()
				{
					clearUnsaved();
					if(onConfirm != null) onConfirm();
					else
					{
						PlayState.chartingMode = false;
						MusicBeatState.switchState(new editors.MasterEditorMenu());
						FlxG.sound.playMusic(Paths.music('freakyMenu'));
						FlxG.mouse.visible = false;
					}
				}
			));
		}
		else
		{
			if(onConfirm != null) onConfirm();
			else
			{
				PlayState.chartingMode = false;
				MusicBeatState.switchState(new editors.MasterEditorMenu());
				FlxG.sound.playMusic(Paths.music('freakyMenu'));
				FlxG.mouse.visible = false;
			}
		}
	}

	/** Show a confirmation prompt before playtesting if there are unsaved changes. */
	function confirmPlaytest():Void
	{
		if(unsavedChanges)
		{
			openSubState(new editors.content.Prompt(
				Language.get('newchartEditor_unsaved_playtest', 'You have unsaved changes.\nPlaytest anyway? (Changes won\'t be lost)'),
				function()
				{
					createPlaytestBackup();
					doGoToPlayState();
				},
				'newchartEditor_play', // Yes - "Play"
				'newchartEditor_cancel' // No - "Cancel"
			));
		}
		else
		{
			doGoToPlayState();
		}
	}

	/** Create a timestamped backup before playtesting, to prevent data loss. */
	function createPlaytestBackup():Void
	{
		#if sys
		try
		{
			var backupDir:String = 'backups/';
			if(!FileSystem.exists(backupDir)) FileSystem.createDirectory(backupDir);

			var chartName:String = Paths.formatToSongPath(PlayState.SONG.song);
			var timestamp:String = DateTools.format(Date.now(), '%Y-%m-%d_%H-%M-%S');
			var backupName:String = '${chartName}_playtest_$timestamp.$BACKUP_EXT';

			var songCopy:SwagSong = Reflect.copy(PlayState.SONG);
			Reflect.setField(songCopy, '__original_path', Song.chartPath);
			var dataToSave:String = haxe.Json.stringify(songCopy);
			File.saveContent('$backupDir$backupName', dataToSave);
			trace('Playtest backup saved: $backupName');
		}
		catch(e:Exception)
		{
			trace('Failed to create playtest backup: $e');
		}
		#end
	}

	/** Actually switch to PlayState (after save confirmation). */
	function doGoToPlayState():Void
	{
		persistentUpdate = false;
		FlxG.mouse.visible = false;
		chartEditorSave.flush();
		autosaveSong();
		updateChartData();
		StageData.loadDirectory(PlayState.SONG);
		PlayState.chartingMode = true;
		PlayState.replayMode = false;
		LoadingState.loadAndSwitchState(new PlayState());
		ClientPrefs.toggleVolumeKeys(true);
	}

	/** Delete a note/event immediately. Extracted as helper for Android long-press logic. */
	function doDeleteNote(note:MetaNote):Void
	{
		TraceManager.debug('trace.editor.noteRemoved', 'Removed {} at time: {}', [!note.isEvent ? 'note' : 'event', note.strumTime]);
		if(!note.isEvent)
			notes.remove(note);
		else
			events.remove(cast (note, EventMetaNote));

		selectedNotes.remove(note);
		curRenderedNotes.remove(note, true);
		addUndoAction(DELETE_NOTE, !note.isEvent ? {notes: [note]} : {events: [note]});
	}

	function resetSelectedNotes()
	{
		for (note in selectedNotes)
		{
			if(note == null || !note.exists) continue;

			note.colorTransform.redMultiplier = note.colorTransform.greenMultiplier = note.colorTransform.blueMultiplier = 1;
			if(note.animation.curAnim != null) note.animation.curAnim.curFrame = 0;
		}
		selectedNotes = [];
		onSelectNote();
		forceDataUpdate = true;
	}

	function onSelectNote()
	{
		if(selectedNotes.length == 1) //Only one note selected
		{
			var note:MetaNote = selectedNotes[0];
			strumTimeStepper.value = note.strumTime;
			if(!note.isEvent) //Normal note
			{
				if(!note.isEvent)
				{
					susLengthLastVal = susLengthStepper.value = note.sustainLength;
					noteTypeDropDown.selectedIndex = Std.int(Math.max(0, noteTypes.indexOf(note.noteType)));
				}
				else
				{
					susLengthLastVal = susLengthStepper.value = 0;
					noteTypeDropDown.selectedLabel = '';
				}
			}
			else //Event note
			{
				var eventNote:EventMetaNote = cast (selectedNotes[0], EventMetaNote);
				updateSelectedEventText();
			}
		}
		else if(selectedNotes.length > 1)
		{
			susLengthStepper.min = -susLengthStepper.max;
			susLengthLastVal = susLengthStepper.value = 0;
			strumTimeStepper.value = selectedNotes[0].strumTime;
			noteTypeDropDown.selectedLabel = '';
			eventDropDown.selectedLabel = '';
			value1InputText.text = '';
			value2InputText.text = '';
		}
		forceDataUpdate = true;
	}

	function updateSelectedEventText()
	{
		if(selectedNotes.length == 1 && selectedNotes[0].isEvent)
		{
			var eventNote:EventMetaNote = cast (selectedNotes[0], EventMetaNote);
			curEventSelected = Std.int(FlxMath.bound(curEventSelected, 0, eventNote.events.length - 1));
			selectedEventText.text = '${Language.get('newchartEditor_selected_event', 'Selected Event:')}: ${curEventSelected + 1} / ${eventNote.events.length}';
			selectedEventText.visible = true;
			
			var myEvent:Array<String> = eventNote.events[curEventSelected];
			if(myEvent != null)
			{
				var eventName:String = (myEvent[0] != null) ? myEvent[0] : '';
				for (num => event in eventsList)
				{
					if(event[0] == eventName)
					{
						eventDropDown.selectedIndex = num;
						break;
					}
				}
				value1InputText.text = (myEvent[1] != null) ? myEvent[1] : '';
				value2InputText.text = (myEvent[2] != null) ? myEvent[2] : '';
			}
		}
		else selectedEventText.visible = false;
	}

	function createGrids()
	{
		var destroyed:Bool = false;
		var stripes:Array<Int> = null;
		if(prevGridBg != null)
		{
			stripes = prevGridBg.stripes;
			remove(prevGridBg);
			remove(gridBg);
			remove(nextGridBg);
			prevGridBg = FlxDestroyUtil.destroy(prevGridBg);
			gridBg = FlxDestroyUtil.destroy(gridBg);
			nextGridBg = FlxDestroyUtil.destroy(nextGridBg);
			destroyed = true;
		}

		var columnCount:Int = (GRID_COLUMNS_PER_PLAYER * GRID_PLAYERS) + (SHOW_EVENT_COLUMN ? 1 : 0);
		gridBg = new ChartingGridSprite(columnCount, gridColors[0], gridColors[1]);
		gridBg.screenCenter(X);

		prevGridBg = new ChartingGridSprite(columnCount, gridColorsOther[0], gridColorsOther[1]);
		nextGridBg = new ChartingGridSprite(columnCount, gridColorsOther[0], gridColorsOther[1]);
		prevGridBg.x = nextGridBg.x = gridBg.x;
		prevGridBg.stripes = nextGridBg.stripes = gridBg.stripes = stripes;
		
		if(destroyed)
		{
			insert(getFirstNull(), prevGridBg);
			insert(getFirstNull(), nextGridBg);
			insert(getFirstNull(), gridBg);
			loadSection();
		}
		else
		{
			add(prevGridBg);
			add(nextGridBg);
			add(gridBg);
		}
	}

	var cachedSectionRow:Array<Int>;
	var cachedSectionTimes:Array<Float>;
	var cachedSectionCrochets:Array<Float>;
	var cachedSectionBPMs:Array<Float>;
	function loadChart(song:SwagSong)
	{
		PlayState.SONG = song;

		// Smart defaults matching PlayState.create() logic
		if(PlayState.SONG.stage == null || PlayState.SONG.stage.length < 1)
		{
			var songName:String = Paths.formatToSongPath(PlayState.SONG.song);
			switch(songName)
			{
				case 'spookeez' | 'south' | 'monster': PlayState.SONG.stage = 'spooky';
				case 'pico' | 'blammed' | 'philly' | 'philly-nice': PlayState.SONG.stage = 'philly';
				case 'milf' | 'satin-panties' | 'high': PlayState.SONG.stage = 'limo';
				case 'cocoa' | 'eggnog': PlayState.SONG.stage = 'mall';
				case 'winter-horrorland': PlayState.SONG.stage = 'mallEvil';
				case 'senpai' | 'roses': PlayState.SONG.stage = 'school';
				case 'thorns': PlayState.SONG.stage = 'schoolEvil';
				case 'ugh' | 'guns' | 'stress': PlayState.SONG.stage = 'tank';
				default: PlayState.SONG.stage = 'stage';
			}
		}
		if(PlayState.SONG.gfVersion == null || PlayState.SONG.gfVersion.length < 1)
		{
			switch(PlayState.SONG.stage)
			{
				case 'limo': PlayState.SONG.gfVersion = 'gf-car';
				case 'mall' | 'mallEvil': PlayState.SONG.gfVersion = 'gf-christmas';
				case 'school' | 'schoolEvil': PlayState.SONG.gfVersion = 'gf-pixel';
				case 'tank': PlayState.SONG.gfVersion = 'gf-tankmen';
				default: PlayState.SONG.gfVersion = 'gf';
			}
			var songName:String = Paths.formatToSongPath(PlayState.SONG.song);
			switch(songName)
			{
				case 'stress': PlayState.SONG.gfVersion = 'pico-speaker';
			}
		}
		if(PlayState.SONG.arrowSkin == null) PlayState.SONG.arrowSkin = '';
		if(PlayState.SONG.splashSkin == null) PlayState.SONG.splashSkin = 'noteSplashes';

		// Initialize pixel stage flag from the stage file
		var stageFile = StageData.getStageFile(PlayState.SONG.stage);
		if(stageFile != null) PlayState.isPixelStage = stageFile.isPixelStage;

		StageData.loadDirectory(PlayState.SONG);
		Conductor.bpm = PlayState.SONG.bpm;
		clearUnsaved();
	}

	function loadMusic(?killAudio:Bool = false)
	{
		setSongPlaying(false);
		var time:Float = Conductor.songPosition;

		if(killAudio)
		{
			var sndsToKill:Array<String> = [];
			for (key => snd in Paths.currentTrackedSounds)
			{
				//trace(key, snd);
				if(key.contains('/songs/${Paths.formatToSongPath(PlayState.SONG.song)}/') && snd != null)
				{
					sndsToKill.push(key);
					snd.close();
				}
			}

			for (key in sndsToKill)
			{
				Assets.cache.clear(key);
				Paths.currentTrackedSounds.remove(key);
				Paths.localTrackedAssets.remove(key);
			}
		}

		try
		{
			FlxG.sound.playMusic(Paths.inst(PlayState.SONG.song), 0);
			FlxG.sound.music.pause();
			FlxG.sound.music.time = time;
			FlxG.sound.music.onComplete = (function() songFinished = true);
		}
		catch(e:Exception)
		{
			FlxG.log.error('Error loading song: $e');
			return;
		}

		@:privateAccess vocals.cleanup(true);
		@:privateAccess opponentVocals.cleanup(true);
		if (PlayState.SONG.needsVoices)
		{
			try
			{
				var file:Dynamic = Paths.voices(Paths.formatToSongPath(PlayState.SONG.song));
				vocals = new FlxSound();
				opponentVocals = new FlxSound();
				if (Std.isOfType(file, Sound) || OpenFlAssets.exists(file)) {
					vocals.loadEmbedded(file);
					FlxG.sound.list.add(vocals);
				}
				var bfVocalPath = 'songs/' + Paths.formatToSongPath(PlayState.SONG.song) + '/Voices-Player.ogg';
				var dadVocalPath = 'songs/' + Paths.formatToSongPath(PlayState.SONG.song) + '/Voices-Opponent.ogg';

				#if MODS_ALLOWED
				if (sys.FileSystem.exists(Paths.modFolders(bfVocalPath))) {
					vocals.loadEmbedded(Paths.modFolders(bfVocalPath));
				} 
				#end
				if (OpenFlAssets.exists(bfVocalPath)) {
					vocals.loadEmbedded(bfVocalPath);
				}
				#if MODS_ALLOWED
				if (sys.FileSystem.exists(Paths.modFolders(dadVocalPath))) {
					opponentVocals.loadEmbedded(Paths.modFolders(dadVocalPath));
				}
				#end
				if (OpenFlAssets.exists(dadVocalPath)) {
					opponentVocals.loadEmbedded(dadVocalPath);
				}
			}
			catch (e:Dynamic) {
				CoolUtil.traceMsg('trace.vocalsError', 'Error loading vocals: {}', [e]);
			}
		}

		#if DISCORD_ALLOWED
		DiscordClient.changePresence('Chart Editor', 'Song: ' + PlayState.SONG.song);
		#end

		updateAudioVolume();
		setPitch();
		_cacheSections();
	}

	function onSongComplete()
	{
		TraceManager.debug('trace.editor.songCompleted', 'song completed');
		setSongPlaying(false);
		Conductor.songPosition = FlxG.sound.music.time = vocals.time = opponentVocals.time = FlxG.sound.music.length - 1;
		curSec = PlayState.SONG.notes.length - 1;
		forceDataUpdate = true;
	}

	function updateAudioVolume()
	{
		FlxG.sound.music.volume = instVolumeStepper.value;
		vocals.volume = playerVolumeStepper.value;
		opponentVocals.volume = opponentVolumeStepper.value;
		if(instMuteCheckBox.checked) FlxG.sound.music.volume = 0;
		if(playerMuteCheckBox.checked) vocals.volume = 0;
		if(opponentMuteCheckBox.checked) opponentVocals.volume = 0;
	}

	var playbackRate:Float = 1;
	function setPitch(?value:Null<Float>)
	{
		#if FLX_PITCH
		if(value == null) value = playbackRate;
		FlxG.sound.music.pitch = value;
		vocals.pitch = value;
		opponentVocals.pitch = value;
		#end
	}

	function setSongPlaying(doPlay:Bool)
	{
		if(FlxG.sound.music == null) return;

		vocals.time = FlxG.sound.music.time;
		opponentVocals.time = FlxG.sound.music.time;

		if(doPlay)
		{
			FlxG.sound.music.play();
			if(FlxG.sound.music.time < vocals.length) vocals.play(true, FlxG.sound.music.time);
			if(FlxG.sound.music.time < opponentVocals.length) opponentVocals.play(true, FlxG.sound.music.time);
			updateAudioVolume();
		}
		else
		{
			FlxG.sound.music.pause();
			vocals.pause();
			opponentVocals.pause();
		}

		for (note in strumLineNotes)
		{
			note.alpha = doPlay ? 1 : 0.4;
			if(!doPlay)
			{
				note.playAnim('static');
				note.resetAnim = 0;
			}
		}
	}

	function reloadNotes()
	{
		MetaNote.clearStaticCache();
		selectedNotes = [];
		for (note in notes) if(note != null) note.destroy();
		for (event in events) if(event != null) event.destroy();
		notes = [];
		events = [];
		undoActions = [];

		for (secNum => section in PlayState.SONG.notes)
			for (note in section.sectionNotes)
				if(note != null)
					notes.push(createNote(note, secNum));

		for (eventNum => event in PlayState.SONG.events)
			if(event != null && (cachedSectionTimes.length < 1 || event[0] < cachedSectionTimes[cachedSectionTimes.length-1])) //dont spawn events over the time limit
				events.push(createEvent(event));

		notes.sort(PlayState.sortByTime);
		events.sort(PlayState.sortByTime);

		TraceManager.debug('trace.editor.noteCount', 'Note count: {}', [notes.length]);
		TraceManager.debug('trace.editor.eventCount', 'Events count: {}', [events.length]);
		loadSection();
	}

		function createNote(note:Dynamic, ?secNum:Null<Int> = null)
		{
			if(secNum == null) secNum = curSec;
			var section = PlayState.SONG.notes[secNum];

			var daStrumTime:Float = note[0];
			var rawNoteData:Int = Std.int(note[1]);
			if (rawNoteData < 0) rawNoteData = 0; // safety: clamp negative values
			var daNoteData:Int = rawNoteData % GRID_COLUMNS_PER_PLAYER;
			// 谱面加载时已通过 Song.convert() 统一转为 psych_v1 格式
			// 转换后: data 0-3 = 玩家Note, data 4-7 = 对手Note
			// 因此使用新逻辑: (rawNoteData < GRID_COLUMNS_PER_PLAYER)
			var gottaHitNote:Bool = (rawNoteData < GRID_COLUMNS_PER_PLAYER);

			var swagNote:MetaNote = new MetaNote(daStrumTime, daNoteData, note);
			swagNote.mustPress = gottaHitNote;
			swagNote.setSustainLength(note[2], cachedSectionCrochets[secNum] / 4, curZoom);
			swagNote.gfNote = (section.gfSection && gottaHitNote);
			swagNote.noteType = note[3];
			swagNote.scrollFactor.x = 0;

			var colArray:Array<String> = ['purple', 'blue', 'green', 'red'];
			var animToPlay:String = colArray[daNoteData % 4] + 'Scroll';
			if(swagNote.animation.getByName(animToPlay) != null)
				swagNote.animation.play(animToPlay);

			var txt:FlxText = swagNote.findNoteTypeText(swagNote.noteType != null ? noteTypes.indexOf(swagNote.noteType) : 0);
			if(txt != null) txt.visible = showNoteTypeLabels;

			swagNote.updateHitbox();
			if(swagNote.width > swagNote.height)
				swagNote.setGraphicSize(GRID_SIZE);
			else
				swagNote.setGraphicSize(0, GRID_SIZE);

			swagNote.updateHitbox();
			swagNote.active = false;
			positionNoteXByData(swagNote);
			positionNoteYOnTime(swagNote, secNum);
			return swagNote;
		}

	function createEvent(event:Dynamic)
	{
		var daStrumTime:Float = event[0];
		var swagEvent:EventMetaNote = new EventMetaNote(daStrumTime, event);
		swagEvent.x = gridBg.x;
		swagEvent.eventText.x = swagEvent.x - swagEvent.eventText.width - 10;
		swagEvent.scrollFactor.x = 0;
		swagEvent.active = false;

		var secNum:Int = 0;
		for (i in 1...cachedSectionTimes.length)
		{
			if(cachedSectionTimes[i] > daStrumTime) break;
			secNum++;
		}
		positionNoteYOnTime(swagEvent, secNum);
		return swagEvent;
	}

	function _cacheSections()
	{
		var time:Float = 0;
		var row:Int = 0;
		cachedSectionRow = [];
		cachedSectionTimes = [];
		cachedSectionCrochets = [];
		cachedSectionBPMs = [];

		if(PlayState.SONG == null)
		{
			cachedSectionRow.push(0);
			cachedSectionTimes.push(0);
			cachedSectionCrochets.push(0);
			cachedSectionBPMs.push(0);
			return;
		}

		var bpm:Float = PlayState.SONG.bpm;
		var reachedLimit:Bool = false;
		for (secNum => section in PlayState.SONG.notes)
		{
			var secs:Null<Float> = cast section.sectionBeats;
			if(secs == null || Math.isNaN(secs) || secs <= 0) section.sectionBeats = 4;
	
			if(section.changeBPM) bpm = section.bpm;
			var beat:Float = Conductor.calculateCrochet(bpm);
			//trace(secBPM, beat);
			
			cachedSectionRow.push(row);
			cachedSectionTimes.push(time);
			cachedSectionCrochets.push(beat);
			cachedSectionBPMs.push(bpm);

			var lastTime:Float = time;
			var rowRound:Int = Math.round(4 * section.sectionBeats);
			row += rowRound;
			time += beat * (rowRound / 4);

			for (note in section.sectionNotes)
			{
				if(secNum > 0 && note[0] < lastTime) note[0] = lastTime;
				else if(secNum < PlayState.SONG.notes.length && note[0] >= time - 0.000001) note[0] = time - 0.000001;
			}

			if(FlxG.sound.music != null && time >= FlxG.sound.music.length)
			{
				var lastSectionNum:Int = PlayState.SONG.notes.length - 1;
				if(secNum < lastSectionNum) //Delete extra sections
				{
					while(PlayState.SONG.notes.length - 1 > secNum)
					{
						PlayState.SONG.notes.pop();
					}
	
					TraceManager.debug('trace.editor.breakingSection', 'breaking at section {}', [secNum]);
					reachedLimit = true;
					break;
				}
				else if(secNum == lastSectionNum)
				{
					TraceManager.debug('trace.editor.reachedLimit', 'reached limit at section {}', [secNum]);
					reachedLimit = true;
				}
			}
		}

		if(FlxG.sound.music != null && !reachedLimit) //Created sections to fill blank space
		{
			var lastSection = PlayState.SONG.notes[PlayState.SONG.notes.length-1];
			var beat:Float = Conductor.calculateCrochet(bpm);
			var sectionBeats:Float = lastSection != null ? lastSection.sectionBeats : 4;
			var rowRound:Int = Math.round(4 * sectionBeats);
			var timeAdd:Float = beat * (rowRound / 4);
			var mustHitSec:Bool = lastSection != null ? lastSection.mustHitSection : true;
			var changeBpmSec:Bool = lastSection != null ? lastSection.changeBPM : false;
			var altAnimSec:Bool = lastSection != null ? lastSection.altAnim : false;
			var gfSec:Bool = lastSection != null ? lastSection.gfSection : false;

			while(!reachedLimit)
			{
				PlayState.SONG.notes.push({
					sectionNotes: [],
					sectionBeats: sectionBeats,
					mustHitSection: mustHitSec,
					bpm: bpm,
					changeBPM: changeBpmSec,
					altAnim: altAnimSec,
					gfSection: gfSec
				});

				cachedSectionRow.push(row);
				cachedSectionTimes.push(time);
				cachedSectionCrochets.push(beat);
				cachedSectionBPMs.push(bpm);

				row += rowRound;
				time += timeAdd;

				if(time >= FlxG.sound.music.length)
				{
					TraceManager.debug('trace.editor.sectionsCreated', 'created sections until {}', [PlayState.SONG.notes.length-1]);
					reachedLimit = true;
				}
			}
		}
		cachedSectionRow.push(row);
		cachedSectionTimes.push(time);
	}

	var showPreviousSection:Bool = true;
	var showNextSection:Bool = true;
	var showNoteTypeLabels:Bool = true;
	var forceDataUpdate:Bool = true;
	function loadSection(?sec:Null<Int> = null)
	{
		if(sec != null) curSec = sec;
		curSec = Std.int(FlxMath.bound(curSec, 0, PlayState.SONG.notes.length-1));
		Conductor.bpm = cachedSectionBPMs[curSec];

		var hei:Float = 0;
		if(curSec > 0)
		{
			prevGridBg.y = cachedSectionRow[curSec-1] * GRID_SIZE * curZoom;
			prevGridBg.rows = 4 * PlayState.SONG.notes[curSec-1].sectionBeats * curZoom;
			prevGridBg.visible = showPreviousSection;
			hei += prevGridBg.height;
			eventLockOverlay.y = prevGridBg.y;
		}
		else prevGridBg.visible = false;

		if(curSec < PlayState.SONG.notes.length - 1)
		{
			nextGridBg.y = cachedSectionRow[curSec+1] * GRID_SIZE * curZoom;
			nextGridBg.rows = 4 * PlayState.SONG.notes[curSec+1].sectionBeats * curZoom;
			nextGridBg.visible = showNextSection;
			hei += nextGridBg.height;
		}
		else nextGridBg.visible = false;

		gridBg.y = cachedSectionRow[curSec] * GRID_SIZE * curZoom;
		gridBg.rows = 4 * PlayState.SONG.notes[curSec].sectionBeats * curZoom;
		hei += gridBg.height;

		if(!prevGridBg.visible) eventLockOverlay.y = gridBg.y;
		eventLockOverlay.scale.y = hei;
		eventLockOverlay.updateHitbox();

		softReloadNotes();
		updateHeads();

		var sec = getCurChartSection();
		if(sec != null)
		{
			mustHitCheckBox.checked = sec.mustHitSection;
			gfSectionCheckBox.checked = sec.gfSection;
			altAnimSectionCheckBox.checked = sec.altAnim;
			changeBpmCheckBox.checked = sec.changeBPM;
			changeBpmStepper.value = Conductor.bpm;
			beatsPerSecStepper.value = sec.sectionBeats;

			strumTimeStepper.step = Conductor.stepCrochet;
			susLengthStepper.step = cachedSectionCrochets[curSec] / 4 / 2;
			susLengthStepper.max = susLengthStepper.step * 128;
			if(selectedNotes.length > 1) susLengthStepper.min = -susLengthStepper.max;
			else susLengthStepper.min = 0;
		}
		prevGridBg.vortexLineEnabled = gridBg.vortexLineEnabled = nextGridBg.vortexLineEnabled = vortexEnabled;
		prevGridBg.vortexLineSpace = gridBg.vortexLineSpace = nextGridBg.vortexLineSpace = GRID_SIZE * 4 * curZoom;
		updateWaveform();
	}

	var _noteAlphaDirty:Bool = true; // Dirty flag: note alpha needs refresh

	/** Binary search: first index with strumTime >= target */
	function binarySearchNotes(arr:Array<MetaNote>, target:Float):Int
	{
		var lo:Int = 0, hi:Int = arr.length - 1;
		while(lo <= hi)
		{
			var mid:Int = (lo + hi) >>> 1;
			if(arr[mid] == null) { lo = mid + 1; continue; }
			if(arr[mid].strumTime < target) lo = mid + 1;
			else hi = mid - 1;
		}
		return lo;
	}

	/**
	 * Efficiently reload notes for current and adjacent sections.
	 * Uses binary search to locate section boundaries in the sorted array, avoiding full linear scan.
	 */
	function softReloadNotes(onlyCurrent:Bool = false)
	{
		if(!onlyCurrent) behindRenderedNotes.clear();
		curRenderedNotes.clear();

		final curStepCrochet:Float = cachedSectionCrochets[curSec] / 4;
		final songPos:Float = Conductor.songPosition;

		// 当前段落的时间范围
		final minTime:Float = getMinNoteTime(curSec);
		final maxTime:Float = getMaxNoteTime(curSec);

		// Adjacent section time ranges (lazy computed)
		var prevMinTime:Float = Math.NEGATIVE_INFINITY, prevMaxTime:Float = Math.NEGATIVE_INFINITY;
		var nextMinTime:Float = Math.NEGATIVE_INFINITY, nextMaxTime:Float = Math.NEGATIVE_INFINITY;
		if(!onlyCurrent)
		{
			if(prevGridBg.visible) { prevMinTime = getMinNoteTime(curSec-1); prevMaxTime = getMaxNoteTime(curSec-1); }
			if(nextGridBg.visible) { nextMinTime = getMinNoteTime(curSec+1); nextMaxTime = getMaxNoteTime(curSec+1); }
		}

		sectionFirstNoteID = 0;
		sectionFirstEventID = 0;
		var foundFirstNote:Bool = false;
		var foundFirstEvent:Bool = false;

		// Start from the first note that may fall in current section
		var startIdx:Int = binarySearchNotes(notes, minTime);
		for (num in startIdx...notes.length)
		{
			var note:MetaNote = notes[num];
			if(note == null) continue;
			final t:Float = note.strumTime;
			if(t >= maxTime) break; // Past section time range, stop

			if(!foundFirstNote) { sectionFirstNoteID = num; foundFirstNote = true; }
			curRenderedNotes.add(note);
			note.alpha = (t >= songPos) ? 1 : 0.6;
			if(note.hasSustain) note.updateSustainToZoom(curStepCrochet, curZoom);
		}

		// 相邻段落 Note（独立扫描，范围较小）
		if(!onlyCurrent)
		{
			if(prevGridBg.visible)
			{
				startIdx = binarySearchNotes(notes, prevMinTime);
				for (num in startIdx...notes.length)
				{
					var note:MetaNote = notes[num];
					if(note == null) continue;
					final t:Float = note.strumTime;
					if(t >= prevMaxTime) break;
					behindRenderedNotes.add(note);
					note.alpha = 0.4;
					if(note.hasSustain) note.updateSustainToZoom(curStepCrochet, curZoom);
				}
			}
			if(nextGridBg.visible)
			{
				startIdx = binarySearchNotes(notes, nextMinTime);
				for (num in startIdx...notes.length)
				{
					var note:MetaNote = notes[num];
					if(note == null) continue;
					final t:Float = note.strumTime;
					if(t >= nextMaxTime) break;
					behindRenderedNotes.add(note);
					note.alpha = 0.4;
					if(note.hasSustain) note.updateSustainToZoom(curStepCrochet, curZoom);
				}
			}
		}

		if(SHOW_EVENT_COLUMN)
		{
			// Events are typically few, linear scan is fine
			for (num => event in events)
			{
				if(event == null) continue;
				final t:Float = event.strumTime;

				if(t >= minTime && t < maxTime)
				{
					if(!foundFirstEvent) { sectionFirstEventID = num; foundFirstEvent = true; }
					curRenderedNotes.add(event);
					event.alpha = (t >= songPos) ? 1 : 0.6;
					event.eventText.visible = true;
				}
				else if(!onlyCurrent && ((prevGridBg.visible && t >= prevMinTime && t < prevMaxTime)
					|| (nextGridBg.visible && t >= nextMinTime && t < nextMaxTime)))
				{
					behindRenderedNotes.add(event);
					event.alpha = 0.4;
					event.eventText.visible = false;
				}
			}
		}
		_noteAlphaDirty = false;
	}

	function getMinNoteTime(sec:Int)
	{
		var minTime:Float = Math.NEGATIVE_INFINITY;
		if(sec > 0)
			minTime = cachedSectionTimes[sec];
		return minTime;
	}

	function getMaxNoteTime(sec:Int)
	{
		var maxTime:Float = Math.POSITIVE_INFINITY;
		if(sec < cachedSectionTimes.length)
			maxTime = cachedSectionTimes[sec + 1];
		return maxTime;
	}

	/** 根据 strumTime 和章节信息快速计算 Note 的 Y 坐标（不含居中偏移） */
	inline function calcNoteY(strumTime:Float, sec:Int, zoom:Float):Float
	{
		return Math.max(((strumTime - cachedSectionTimes[sec]) / cachedSectionCrochets[sec]) * GRID_SIZE * 4 * zoom + cachedSectionRow[sec] * GRID_SIZE * zoom, -150);
	}

	function positionNoteXByData(note:MetaNote, ?data:Null<Int> = null)
	{
		if(data == null) data = note.songData[1];

		var noteX:Float = gridBg.x + (GRID_SIZE - note.width) / 2;
		if(SHOW_EVENT_COLUMN) noteX += GRID_SIZE;

		noteX += GRID_SIZE * data;
		note.x = noteX;
		//trace(gridBg.x, noteX);
	}

	function positionNoteYOnTime(note:MetaNote, section:Int)
	{
		var noteY:Float = calcNoteY(note.strumTime, section, curZoom);
		note.y = noteY + (GRID_SIZE/2 - note.height/2);
		note.chartY = noteY;
	}

	var characterData:Dynamic = {};
	function updateJsonData():Void
	{
		for (i in 1...GRID_PLAYERS+1)
		{
			//trace('adding iconP$i');
			var data:CharacterFile = loadCharacterFile(Reflect.field(PlayState.SONG, 'player$i'));
			Reflect.setField(characterData, 'iconP$i', data != null && data.healthicon != null ? data.healthicon : 'face');
			//Reflect.setField(characterData, 'vocalsP$i', data != null && data.vocals_file != null ? data.vocals_file : '');
		}
	}
	
	var _lastSec:Int = -1;
	var _lastGfSection:Null<Bool> = null;
	function updateHeads(ignoreCheck:Bool = false):Void
	{
		var curSecData:SwagSection = PlayState.SONG.notes[curSec];
		var isGfSection:Bool = (curSecData != null && curSecData.gfSection == true);
		if(_lastGfSection == isGfSection && _lastSec == curSec && !ignoreCheck) return; //optimization

		for (i in 0...GRID_PLAYERS)
		{
			var icon:HealthIcon = icons[i];
			//trace('changing iconP${icon.ID}');
			var iconName:String = Reflect.field(characterData, 'iconP${icon.ID}');
			icon.changeIcon(iconName);
		}

		if(icons.length > 1)
		{
			var iconP1:HealthIcon = icons[0];
			var iconP2:HealthIcon = icons[1];
			var mustHitSection:Bool = (curSecData != null && curSecData.mustHitSection == true);
			if (isGfSection)
			{
				if (mustHitSection)
					iconP1.changeIcon('gf');
				else
					iconP2.changeIcon('gf');
			}

			if(mustHitSection)
				mustHitIndicator.x = iconP1.x + iconP1.width/2;
			else
				mustHitIndicator.x = iconP2.x + iconP2.width/2;
		}
		_lastGfSection = isGfSection;
		_lastSec = curSec;
	}

	var playbackSlider:PsychUISlider;

	var mouseSnapCheckBox:PsychUICheckBox;
	var ignoreProgressCheckBox:PsychUICheckBox;
	var hitsoundPlayerStepper:PsychUINumericStepper;
	var hitsoundOpponentStepper:PsychUINumericStepper;
	var metronomeStepper:PsychUINumericStepper;

	var instVolumeStepper:PsychUINumericStepper;
	var instMuteCheckBox:PsychUICheckBox;
	var playerVolumeStepper:PsychUINumericStepper;
	var playerMuteCheckBox:PsychUICheckBox;
	var opponentVolumeStepper:PsychUINumericStepper;
	var opponentMuteCheckBox:PsychUICheckBox;
	function addChartingTab()
	{
		var tab_group = mainBox.getTab('newchartEditor_charting').menu;
		var objX = 10;
		var objY = 10;

		var txt = new EditorsText(objX, objY, 280, Language.get("newchartEditor_any_options_note", "Any options here won't actually affect gameplay!"));
		txt.alignment = CENTER;
		tab_group.add(txt);

		objY += 25;
		playbackSlider = new PsychUISlider(50, objY, function(v:Float) setPitch(playbackRate = v), 1, 0.1, 5.0, 200);
		playbackSlider.label = Language.get('newchartEditor_playback_rate', 'Playback Rate');
		
		objY += 60;
		mouseSnapCheckBox = new PsychUICheckBox(objX, objY, Language.get('newchartEditor_mouse_scroll_snap', 'Mouse Scroll Snap'), 100, function() chartEditorSave.data.mouseScrollSnap = mouseSnapCheckBox.checked);
		mouseSnapCheckBox.checked = chartEditorSave.data.mouseScrollSnap;

		ignoreProgressCheckBox = new PsychUICheckBox(objX + 150, objY, Language.get('newchartEditor_ignore_progress_warnings', 'Ignore Progress Warnings'), 100, function() chartEditorSave.data.ignoreProgressWarns = ignoreProgressCheckBox.checked);
		ignoreProgressCheckBox.checked = chartEditorSave.data.ignoreProgressWarns;

		objY += 50;
		hitsoundPlayerStepper = new PsychUINumericStepper(objX, objY, 0.2, 0, 0, 1, 1);
		hitsoundOpponentStepper = new PsychUINumericStepper(objX + 100, objY, 0.2, 0, 0, 1, 1);
		metronomeStepper = new PsychUINumericStepper(objX + 200, objY, 0.2, 0, 0, 1, 1);

		objY += 50;
		instVolumeStepper = new PsychUINumericStepper(objX, objY, 0.1, 0.6, 0, 1, 1);
		instVolumeStepper.onValueChange = updateAudioVolume;
		playerVolumeStepper = new PsychUINumericStepper(objX + 100, objY, 0.1, 1, 0, 1, 1);
		playerVolumeStepper.onValueChange = updateAudioVolume;
		opponentVolumeStepper = new PsychUINumericStepper(objX + 200, objY, 0.1, 1, 0, 1, 1);
		opponentVolumeStepper.onValueChange = updateAudioVolume;

		objY += 25;
		instMuteCheckBox = new PsychUICheckBox(objX, objY, Language.get('newchartEditor_mute', 'Mute'), 60, updateAudioVolume);
		playerMuteCheckBox = new PsychUICheckBox(objX + 100, objY, Language.get('newchartEditor_mute', 'Mute'), 60, updateAudioVolume);
		opponentMuteCheckBox = new PsychUICheckBox(objX + 200, objY, Language.get('newchartEditor_mute', 'Mute'), 60, updateAudioVolume);

		tab_group.add(playbackSlider);
		tab_group.add(mouseSnapCheckBox);
		tab_group.add(ignoreProgressCheckBox);

		tab_group.add(new EditorsText(hitsoundPlayerStepper.x, hitsoundPlayerStepper.y - 15, 100, Language.get("newchartEditor_hitsound_player", 'Hitsound (Player):')));
		tab_group.add(new EditorsText(hitsoundOpponentStepper.x, hitsoundOpponentStepper.y - 15, 100, Language.get("newchartEditor_hitsound_opponent", 'Hitsound (Opp.):')));
		tab_group.add(new EditorsText(metronomeStepper.x, metronomeStepper.y - 15, 100, Language.get("newchartEditor_metronome", 'Metronome:')));
		tab_group.add(hitsoundPlayerStepper);
		tab_group.add(hitsoundOpponentStepper);
		tab_group.add(metronomeStepper);
		
		tab_group.add(new EditorsText(instVolumeStepper.x, instVolumeStepper.y - 15, 100, Language.get("newchartEditor_inst_volume", 'Inst. Volume:')));
		tab_group.add(new EditorsText(playerVolumeStepper.x, playerVolumeStepper.y - 15, 100, Language.get("newchartEditor_main_vocals", 'Main Vocals:')));
		tab_group.add(new EditorsText(opponentVolumeStepper.x, opponentVolumeStepper.y - 15, 100, Language.get("newchartEditor_opp_vocals", 'Opp. Vocals:')));
		tab_group.add(instVolumeStepper);
		tab_group.add(instMuteCheckBox);
		tab_group.add(playerVolumeStepper);
		tab_group.add(playerMuteCheckBox);
		tab_group.add(opponentVolumeStepper);
		tab_group.add(opponentMuteCheckBox);
	}

	var gameOverCharDropDown:PsychUIDropDownMenu;
	var gameOverSndInputText:PsychUIInputText;
	var gameOverLoopInputText:PsychUIInputText;
	var gameOverRetryInputText:PsychUIInputText;
	var noRGBCheckBox:PsychUICheckBox;
	var noteTextureInputText:PsychUIInputText;
	var noteSplashesInputText:PsychUIInputText;
	function addDataTab()
	{
		var tab_group = mainBox.getTab('newchartEditor_data').menu;
		var objX = 10;
		var objY = 25;
		gameOverCharDropDown = new PsychUIDropDownMenu(objX, objY, [''], function(id:Int, character:String)
		{
			PlayState.SONG.gameOverChar = character;
			if(character.length < 1) Reflect.deleteField(PlayState.SONG, 'gameOverChar');
			TraceManager.debug('trace.editor.characterSelected', 'selected {}', [character]);
		});

		objY += 40;
		gameOverSndInputText = new PsychUIInputText(objX, objY, 120, '', 8);
		gameOverSndInputText.onChange = function(old:String, cur:String)
		{
			PlayState.SONG.gameOverSound = cur;
			if(cur.trim().length < 1) Reflect.deleteField(PlayState.SONG, 'gameOverSound');
		}
		objY += 40;
		gameOverLoopInputText = new PsychUIInputText(objX, objY, 120, '', 8);
		gameOverLoopInputText.onChange = function(old:String, cur:String)
		{
			PlayState.SONG.gameOverLoop = cur;
			if(cur.trim().length < 1) Reflect.deleteField(PlayState.SONG, 'gameOverLoop');
		}
		objY += 40;
		gameOverRetryInputText = new PsychUIInputText(objX, objY, 120, '', 8);
		gameOverRetryInputText.onChange = function(old:String, cur:String)
		{
			PlayState.SONG.gameOverEnd = cur;
			if(cur.trim().length < 1) Reflect.deleteField(PlayState.SONG, 'gameOverEnd');
		}

		objY += 35;
		noRGBCheckBox = new PsychUICheckBox(objX, objY, Language.get('newchartEditor_disable_note_rgb', 'Disable Note RGB'), 100, updateNotesRGB);
		
		objY += 40;
		noteTextureInputText = new PsychUIInputText(objX, objY, 120, '');
		noteTextureInputText.unfocus = function()
		{
			var changed:Bool = false;
			if(PlayState.SONG.arrowSkin != noteTextureInputText.text) changed = true;
			PlayState.SONG.arrowSkin = noteTextureInputText.text.trim();
			if(PlayState.SONG.arrowSkin.trim().length < 1) PlayState.SONG.arrowSkin = null;

			if(changed)
			{
				var textureLoad:String = 'images/${noteTextureInputText.text}.png';
				if(Paths.fileExists(textureLoad, IMAGE) || noteTextureInputText.text.trim() == '')
				{
					for (note in notes)
					{
						if(note == null) continue;
						note.reloadNote(note.texture);
		
						if(note.width > note.height)
							note.setGraphicSize(GRID_SIZE);
						else
							note.setGraphicSize(0, GRID_SIZE);
		
						note.updateHitbox();
					}
					if(noteTextureInputText.text.trim().length > 0) showOutput('${Language.get('newchartEditor_error_note_texture','Note Texture')}: "$textureLoad"');
					else showOutput('newchartEditor_notes_reloaded_default');
					
				}
				else showOutput('newchartEditor_error_texture_not_found' + '($textureLoad)', true);
			}
		};

		noteSplashesInputText = new PsychUIInputText(objX + 140, objY, 120, '');
		noteSplashesInputText.onChange = function(old:String, cur:String)
		{
			PlayState.SONG.splashSkin = cur;
			if(cur.trim().length < 1) PlayState.SONG.splashSkin = null;
		}
	
		tab_group.add(new EditorsText(gameOverCharDropDown.x, gameOverCharDropDown.y - 15, 120, Language.get('newchartEditor_game_over_character', 'Game Over Character:')));
		tab_group.add(new EditorsText(gameOverSndInputText.x, gameOverSndInputText.y - 15, 180, Language.get('newchartEditor_game_over_death_sound', 'Game Over Death Sound (sounds/):')));
		tab_group.add(new EditorsText(gameOverLoopInputText.x, gameOverLoopInputText.y - 15, 180, Language.get('newchartEditor_game_over_loop_music', 'Game Over Loop Music (music/):')));
		tab_group.add(new EditorsText(gameOverRetryInputText.x, gameOverRetryInputText.y - 15, 180, Language.get('newchartEditor_game_over_retry_music', 'Game Over Retry Music (music/):')));
		tab_group.add(gameOverSndInputText);
		tab_group.add(gameOverLoopInputText);
		tab_group.add(gameOverRetryInputText);
		tab_group.add(noRGBCheckBox);

		tab_group.add(new EditorsText(noteTextureInputText.x, noteTextureInputText.y - 15, 100, Language.get('newchartEditor_note_texture', 'Note Texture:')));
		tab_group.add(new EditorsText(noteSplashesInputText.x, noteSplashesInputText.y - 15, 120, Language.get('newchartEditor_note_splashes_texture', 'Note Splashes Texture:')));
		tab_group.add(noteTextureInputText);
		tab_group.add(noteSplashesInputText);

		tab_group.add(gameOverCharDropDown); //lowest priority to display properly
	}

	var eventDropDown:PsychUIDropDownMenu;
	var value1InputText:PsychUIInputText;
	var value2InputText:PsychUIInputText;
	var selectedEventText:EditorsText;
	var eventDescriptionText:EditorsText;

	var eventsList:Array<Array<String>>;
	var curEventSelected:Int = 0;
	function addEventsTab()
	{
		var tab_group = mainBox.getTab('newchartEditor_events').menu;
		var objX = 10;
		var objY = 25;

		eventDropDown = new PsychUIDropDownMenu(objX, objY, [], function(id:Int, character:String)
		{
			var eventSelected:Array<String> = eventsList[id];
			var eventName:String = eventSelected[0];
			var description:String = eventSelected[1];
			eventDescriptionText.text = description;
			if(selectedNotes.length > 1)
			{
				for (note in selectedNotes)
				{
					if(note == null || !note.isEvent) continue;

					var event:EventMetaNote = cast (note, EventMetaNote);
					event.events[event.events.length - 1][0] = eventName;
					event.updateEventText();
				}
			}
			else if(selectedNotes.length == 1 && selectedNotes[0].isEvent)
			{
				var event:EventMetaNote = cast (selectedNotes[0], EventMetaNote);
				event.events[Std.int(FlxMath.bound(curEventSelected, 0, event.events.length - 1))][0] = eventName;
				event.updateEventText();
			}
		});

		function genericEventButton(func:EventMetaNote->Void)
		{
			if(selectedNotes.length == 1)
			{
				if(selectedNotes[0].isEvent)
				{
					var event:EventMetaNote = cast (selectedNotes[0], EventMetaNote);
					func(event);
					updateSelectedEventText();
				}
				else showOutput('newchartEditor_error_note_must_be_event', true);
			}
			else showOutput('newchartEditor_error_note_must_select', true);
		}

		var objX2 = 140;
		var removeButton:PsychUIButton = new PsychUIButton(objX2, objY, '-', function()
		{
			genericEventButton(function(event:EventMetaNote)
			{
				if(event.events.length > 1)
				{
					var selectedEvent = event.events[curEventSelected];
					if(selectedEvent != null)
					{
						event.events.remove(selectedEvent);
						event.updateEventText();
						curEventSelected--;
					}
					else showOutput('newchartEditor_error_no_event_selected', true);
				}
				else
				{
					selectedNotes.remove(event);
					events.remove(event);
					curRenderedNotes.remove(event, true);
					addUndoAction(DELETE_NOTE, {events: [event]});
				}
			});
		}, 20, Paths.font("editors.ttf"), 12);
		var addButton:PsychUIButton = new PsychUIButton(objX2 + 30, objY, '+', function()
		{
			genericEventButton(function(event:EventMetaNote)
			{
				event.events.push([eventsList[Std.int(Math.max(eventDropDown.selectedIndex, 0))][0], value1InputText.text, value2InputText.text]);
				event.updateEventText();
				curEventSelected++;
			});
		}, 20, Paths.font("editors.ttf"), 12);
		var leftButton:PsychUIButton = new PsychUIButton(objX2 + 80, objY, '<', function()
		{
			genericEventButton(function(event:EventMetaNote) curEventSelected = FlxMath.wrap(curEventSelected - 1, 0, event.events.length - 1));
		}, 20, Paths.font("editors.ttf"), 12);
		var rightButton:PsychUIButton = new PsychUIButton(objX2 + 110, objY, '>', function()
		{
			genericEventButton(function(event:EventMetaNote) curEventSelected = FlxMath.wrap(curEventSelected + 1, 0, event.events.length - 1));
		}, 20, Paths.font("editors.ttf"), 12);
		removeButton.normalStyle.bgColor = FlxColor.RED;
		removeButton.normalStyle.textColor = FlxColor.WHITE;
		addButton.normalStyle.bgColor = FlxColor.GREEN;
		addButton.normalStyle.textColor = FlxColor.WHITE;

		selectedEventText = new EditorsText(150, objY + 30, 150, '');
		selectedEventText.visible = false;

		function changeEventsValue(str:String, n:Int)
		{
			if(selectedNotes.length > 1)
			{
				for (note in selectedNotes)
				{
					if(note == null || !note.isEvent) continue;

					var event:EventMetaNote = cast (note, EventMetaNote);
					event.events[event.events.length - 1][n] = str;
					event.updateEventText();
				}
			}
			else if(selectedNotes.length == 1 && selectedNotes[0].isEvent)
			{
				var event:EventMetaNote = cast (selectedNotes[0], EventMetaNote);
				event.events[Std.int(FlxMath.bound(curEventSelected, 0, event.events.length - 1))][n] = str;
				event.updateEventText();
			}
		}

		objY += 70;
		value1InputText = new PsychUIInputText(objX, objY, 120, '', 8);
		value1InputText.onChange = function(old:String, cur:String) changeEventsValue(cur, 1);
		value2InputText = new PsychUIInputText(objX + 150, objY, 120, '', 8);
		value2InputText.onChange = function(old:String, cur:String) changeEventsValue(cur, 2);

		objY += 40;
		eventDescriptionText = new EditorsText(objX, objY, 280, defaultEvents[0][1]);

		tab_group.add(new EditorsText(eventDropDown.x, eventDropDown.y - 15, 80, Language.get('newchartEditor_event', 'Event:')));
		tab_group.add(new EditorsText(value1InputText.x, value1InputText.y - 15, 80, Language.get('newchartEditor_value_1', 'Value 1:')));
		tab_group.add(new EditorsText(value2InputText.x, value2InputText.y - 15, 80, Language.get('newchartEditor_value_2', 'Value 2:')));

		tab_group.add(removeButton);
		tab_group.add(addButton);
		tab_group.add(leftButton);
		tab_group.add(rightButton);
		tab_group.add(selectedEventText);

		tab_group.add(value1InputText);
		tab_group.add(value2InputText);
		tab_group.add(eventDescriptionText);
		
		tab_group.add(eventDropDown); //lowest priority to display properly
	}

	var susLengthLastVal:Float = 0; //used for multiple notes selected
	var susLengthStepper:PsychUINumericStepper;
	var strumTimeStepper:PsychUINumericStepper;
	var noteTypeDropDown:PsychUIDropDownMenu;
	var noteTypes:Array<String>;
	function addNoteTab()
	{
		var tab_group = mainBox.getTab('newchartEditor_note').menu;
		var objX = 10;
		var objY = 25;

		susLengthStepper = new PsychUINumericStepper(objX, objY, Conductor.stepCrochet / 2, 0, 0, Conductor.stepCrochet * 128, 1, 80);
		susLengthStepper.onValueChange = function()
		{
			var halfStep:Float = (Conductor.stepCrochet / 2);
			trace(halfStep, susLengthStepper.value);
			var val:Float = Math.round(susLengthStepper.value / halfStep) * halfStep;
			susLengthStepper.value = val;
			if(susLengthLastVal != susLengthStepper.value)
			{
				if(selectedNotes.length > 1)
				{
					for (note in selectedNotes)
					{
						if(note == null && !note.isEvent) continue;
						note.setSustainLength(note.sustainLength + (susLengthStepper.value - susLengthLastVal), Conductor.stepCrochet, curZoom);
					}
				}
				else if(selectedNotes.length == 1) selectedNotes[0].setSustainLength(susLengthStepper.value, Conductor.stepCrochet, curZoom);
				susLengthLastVal = susLengthStepper.value;
			}
		};

		objY += 40;
		strumTimeStepper = new PsychUINumericStepper(objX, objY, Conductor.stepCrochet, 0, -5000, Math.POSITIVE_INFINITY, 3, 120);
		strumTimeStepper.onValueChange = function()
		{
			if(selectedNotes.length < 1) return;

			var firstTime:Float = selectedNotes[0].strumTime;
			for (note in selectedNotes)
			{
				if(note == null) continue;

				note.setStrumTime(Math.max(-5000, strumTimeStepper.value + (note.strumTime - firstTime)));
				positionNoteYOnTime(note, curSec);

				if(note.isEvent)
				{
					cast (note, EventMetaNote).updateEventText();
				}
			}
			softReloadNotes();
		};
		
		objY += 40;
		noteTypeDropDown = new PsychUIDropDownMenu(objX, objY, [], function(id:Int, changeToType:String)
		{
			var newSelected:Array<MetaNote> = [];
			var typeSelected:String = noteTypes[id].trim();
			for (note in selectedNotes)
			{
				if(note == null || note.isEvent) continue;

				if(typeSelected != null && typeSelected.length > 0)
					note.songData[3] = typeSelected;
				else
					note.songData.remove(note.songData[3]);

				var id:Int = notes.indexOf(note);
				if(id > -1)
				{
					notes[id] = createNote(note.songData, curSec);
					actionReplaceNotes(note, notes[id]);
					newSelected.push(notes[id]);
					note.destroy();
				}
			}
			selectedNotes = newSelected;
			softReloadNotes();
		}, 150);
		
		tab_group.add(new EditorsText(susLengthStepper.x, susLengthStepper.y - 15, 80, Language.get('newchartEditor_sustain_length', 'Sustain length:')));
		tab_group.add(new EditorsText(strumTimeStepper.x, strumTimeStepper.y - 15, 100, Language.get('newchartEditor_note_hit_time', 'Note Hit time (ms):')));
		tab_group.add(new EditorsText(noteTypeDropDown.x, noteTypeDropDown.y - 15, 80, Language.get('newchartEditor_note_type', 'Note Type:')));
		tab_group.add(susLengthStepper);
		tab_group.add(strumTimeStepper);
		tab_group.add(noteTypeDropDown);
	}

	var mustHitCheckBox:PsychUICheckBox;
	var gfSectionCheckBox:PsychUICheckBox;
	var altAnimSectionCheckBox:PsychUICheckBox;

	var changeBpmCheckBox:PsychUICheckBox;
	var changeBpmStepper:PsychUINumericStepper;
	var beatsPerSecStepper:PsychUINumericStepper;

	function addSectionTab()
	{
		var affectNotes:PsychUICheckBox = null;
		var affectEvents:PsychUICheckBox = null;
		var copyLastSecStepper:PsychUINumericStepper = null;
		var tab_group = mainBox.getTab('newchartEditor_section').menu;
		var objX = 10;
		var objY = 10;
		function copyNotesOnSection(?secOff:Int = 0, ?showMessage:Bool = true) //Used on "Copy Section" and "Copy Last Section" buttons
		{
			var curSectionTime:Null<Float> = cachedSectionTimes[curSec - secOff];
			if(curSectionTime == null)
			{
				//showOutput('ERROR: Unknown section??', true);
				return;
			}

			var nextSectionTime:Null<Float> = cachedSectionTimes[curSec - secOff + 1];
			if(nextSectionTime == null) Math.POSITIVE_INFINITY;

			var notesCopyNum:Int = 0;
			if(affectNotes.checked)
			{
				copiedNotes = [];
				for (note in notes)
				{
					if(note.strumTime >= curSectionTime && note.strumTime < nextSectionTime)
					{
						var dataCopy:Array<Dynamic> = makeNoteDataCopy(note.songData, false);
						dataCopy[0] = note.strumTime - curSectionTime;
						copiedNotes.push(dataCopy);
						notesCopyNum++;
					}
				}
			}

			var eventsCopyNum:Int = 0;
			if(affectEvents.checked)
			{
				copiedEvents = [];
				for (event in events)
				{
					if(event.strumTime >= curSectionTime && event.strumTime < nextSectionTime)
					{
						var dataCopy:Array<Dynamic> = makeNoteDataCopy(event.songData, true);
						dataCopy[0] = event.strumTime - curSectionTime;
						copiedEvents.push(dataCopy);
						eventsCopyNum++;
					}
				}
			}

			if(showMessage)
			{
				if(notesCopyNum == 0 && eventsCopyNum == 0)
				{
					showOutput('newchartEditor_nothing_to_copy');
					return;
				}

				var str:String = '';
				if(notesCopyNum > 0) str += '${Language.get("newchartEditor_notes_copied",'Notes Copied')}: $notesCopyNum';
				if(eventsCopyNum > 0)
				{
					if(str.length > 0) str += '\n';
					str += '${Language.get("newchartEditor_events_copied",'Events Copied')}: $eventsCopyNum';
				}
	
				if(str.length > 0) showOutput(str);
			}
		}

		mustHitCheckBox = new PsychUICheckBox(objX, objY, Language.get('newchartEditor_must_hit_sec', 'Must Hit Sec.'), 70, function()
		{
			var sec = getCurChartSection();
			if(sec != null) sec.mustHitSection = mustHitCheckBox.checked;
			updateHeads(true);
		});
		gfSectionCheckBox = new PsychUICheckBox(objX + 100, objY, Language.get('newchartEditor_gf_section', 'GF Section'), 70, function()
		{
			var sec = getCurChartSection();
			if(sec != null) sec.gfSection = gfSectionCheckBox.checked;
			updateHeads(true);
		});
		altAnimSectionCheckBox = new PsychUICheckBox(objX + 200, objY, Language.get('newchartEditor_alt_anim', 'Alt Anim'), 70, function()
		{
			var sec = getCurChartSection();
			if(sec != null) sec.altAnim = altAnimSectionCheckBox.checked;
		});

		objY += 40;
		changeBpmCheckBox = new PsychUICheckBox(objX, objY, Language.get('newchartEditor_change_bpm', 'Change BPM'), 80, function()
		{
			var sec = getCurChartSection();
			if(sec != null)
			{
				var oldTimes:Array<Float> = cachedSectionTimes.copy();
				sec.changeBPM = changeBpmCheckBox.checked;
				if(!Reflect.hasField(sec, 'bpm')) sec.bpm = changeBpmStepper.value;
				adaptNotesToNewTimes(oldTimes);
			}
		});

		objY += 25;
		changeBpmStepper = new PsychUINumericStepper(objX, objY, 1, 0, 1, 400, 3);
		changeBpmStepper.onValueChange = function()
		{
			var sec = getCurChartSection();
			if(sec != null)
			{
				var oldTimes:Array<Float> = cachedSectionTimes.copy();
				sec.bpm = changeBpmStepper.value;
				sec.changeBPM = true;
				changeBpmCheckBox.checked = true;
				adaptNotesToNewTimes(oldTimes);
			}
		};

		beatsPerSecStepper = new PsychUINumericStepper(objX + 150, objY, 1, 4, 1, 16, 2);
		beatsPerSecStepper.onValueChange = function()
		{
			beatsPerSecStepper.value = Math.round(beatsPerSecStepper.value * 4) / 4;
			var sec = getCurChartSection();
			if(sec != null)
			{
				var oldTimes:Array<Float> = cachedSectionTimes.copy();
				sec.sectionBeats = beatsPerSecStepper.value;
				adaptNotesToNewTimes(oldTimes);
			}
		};

		objY += 40;
		var copyButton:PsychUIButton = new PsychUIButton(objX, objY, 'newchartEditor_copy_section', copyNotesOnSection.bind());
		var pasteButton:PsychUIButton = new PsychUIButton(objX + 100, objY, 'newchartEditor_paste_section', function()
		{
			pasteCopiedNotesToSection(affectNotes.checked, affectEvents.checked);
		});
		var clearButton:PsychUIButton = new PsychUIButton(objX + 200, objY, 'newchartEditor_clear', function()
		{
			for (note in curRenderedNotes)
			{
				if(note == null) continue;

				if(!note.isEvent && affectNotes.checked)
					notes.remove(note);
				if(note.isEvent && affectEvents.checked)
					events.remove(cast (note, EventMetaNote));

				selectedNotes.remove(note);
			}
			softReloadNotes(true);
		});
		clearButton.normalStyle.bgColor = FlxColor.RED;
		clearButton.normalStyle.textColor = FlxColor.WHITE;

		objY += 25;
		affectNotes = new PsychUICheckBox(objX, objY, Language.get('newchartEditor_notes', 'Notes'), 60);
		affectNotes.checked = true;
		affectEvents = new PsychUICheckBox(objX + 100, objY, Language.get('newchartEditor_events', 'Events'), 60);

		objY += 32;
		var copyLastSecButton:PsychUIButton = new PsychUIButton(objX, objY, 'newchartEditor_copy_last_section', function()
		{
			var lastCopiedNotes = copiedNotes;
			var lastCopiedEvents = copiedEvents;
			copyNotesOnSection(Std.int(copyLastSecStepper.value), false);
			pasteCopiedNotesToSection(affectNotes.checked, affectEvents.checked);
			copiedNotes = lastCopiedNotes;
			copiedEvents = lastCopiedEvents;
		});
		copyLastSecButton.resize(80, 26);
		copyLastSecStepper = new PsychUINumericStepper(objX + 110, objY + 2, 1, 1, -999, 999, 0);
		
		objY += 40;
		var swapSectionButton:PsychUIButton = new PsychUIButton(objX, objY, 'newchartEditor_swap_section', function()
		{
			var maxData:Int = GRID_COLUMNS_PER_PLAYER * GRID_PLAYERS;
			for (note in curRenderedNotes)
			{
				if(note != null && !note.isEvent)
				{
					var data:Int = note.songData[1] + GRID_COLUMNS_PER_PLAYER;
					if(data >= maxData) data -= maxData;
					note.changeNoteData(data);
					positionNoteXByData(note);
				}
			}
			softReloadNotes(true);
		});
		var duetSectionButton:PsychUIButton = new PsychUIButton(objX + 100, objY, 'newchartEditor_duet_section', function()
		{
			var side:Int = -1;
			for (note in curRenderedNotes.members)
			{
				if(note == null || note.isEvent) continue;

				//First figure out if there are notes on more than one player's sides to cancel operation early
				if(side > -1)
				{
					if(Math.floor(note.songData[1] / GRID_COLUMNS_PER_PLAYER) != side)
					{
						showOutput('newchartEditor_error_cannot_duet');
						return;
					}
				}
				else side = Math.floor(note.songData[1] / GRID_COLUMNS_PER_PLAYER);
			}

			var pushedNotes:Array<MetaNote> = [];
			for (note in curRenderedNotes.members)
			{
				if(note == null || note.isEvent) continue;

				for (i in 0...GRID_PLAYERS)
				{
					if(i == side) continue;

					var songDataCopy:Array<Dynamic> = note.songData.copy();
					songDataCopy[1] = note.noteData + i * GRID_COLUMNS_PER_PLAYER;
					var newNote = createNote(songDataCopy);
					notes.push(newNote);
					pushedNotes.push(newNote);
				}
			}
			notes.sort(PlayState.sortByTime);
			softReloadNotes(true);
			
			addUndoAction(ADD_NOTE, {notes: pushedNotes});
		});
		var mirrorNotesButton:PsychUIButton = new PsychUIButton(objX + 200, objY, 'newchartEditor_mirror_notes', function()
		{
			var maxData:Int = GRID_COLUMNS_PER_PLAYER * GRID_PLAYERS;
			for (note in curRenderedNotes)
			{
				if(note == null || note.isEvent) continue;

				var data:Int = Std.int(note.songData[1]);
				note.changeNoteData((Math.floor(data / GRID_COLUMNS_PER_PLAYER) * GRID_COLUMNS_PER_PLAYER) + GRID_COLUMNS_PER_PLAYER - note.noteData - 1);
				positionNoteXByData(note);
			}
			softReloadNotes(true);
		});

		tab_group.add(mustHitCheckBox);
		tab_group.add(gfSectionCheckBox);
		tab_group.add(altAnimSectionCheckBox);

		tab_group.add(new EditorsText(beatsPerSecStepper.x, beatsPerSecStepper.y - 15, 100, Language.get('newchartEditor_beats_per_section', 'Beats per Section:')));
		tab_group.add(changeBpmCheckBox);
		tab_group.add(changeBpmStepper);
		tab_group.add(beatsPerSecStepper);
		
		tab_group.add(copyButton);
		tab_group.add(pasteButton);
		tab_group.add(clearButton);
		tab_group.add(affectNotes);
		tab_group.add(affectEvents);

		tab_group.add(copyLastSecButton);
		tab_group.add(copyLastSecStepper);

		tab_group.add(swapSectionButton);
		tab_group.add(duetSectionButton);
		tab_group.add(mirrorNotesButton);
	}

	function reloadNotesDropdowns()
	{
		// Event drop down
		if(eventDropDown != null)
		{
			eventsList = [];
			var eventFiles:Array<String> = loadFileList('custom_events/', null, ['.txt']);
			for (file in eventFiles)
			{
				var desc:String;
				try {
					desc = Paths.getTextFromFile('custom_events/$file.txt');
				} catch(e:Dynamic) {
					desc = Language.get('newchartEditor_custom_event_desc', 'Custom event, no description available.');
				}
				eventsList.push([file, desc]);
			}

			for (id => event in defaultEvents)
				if(!eventsList.contains(event))
					eventsList.insert(id, event);
			
			var displayEventsList:Array<String> = [];
			for (id => data in eventsList)
			{
				if(id > 0)
					displayEventsList[id] = '$id. ${data[0]}';
				else
					displayEventsList.push('');
			}

			var lastSelected:String = eventDropDown.selectedLabel;
			eventDropDown.list = displayEventsList;
			eventDropDown.selectedLabel = lastSelected;
		}


		// Note type drop down
		if(noteTypeDropDown != null)
		{
			var exts:Array<String> = ['.txt'];
			#if LUA_ALLOWED exts.push('.lua'); #end
			#if HSCRIPT_ALLOWED exts.push('.hx'); #end
			noteTypes = loadFileList('custom_notetypes/', null, exts);
			for (id => noteType in noteTypeList)
				if(!noteTypes.contains(noteType))
					noteTypes.insert(id, noteType);

			if(Song.chartPath != null && Song.chartPath.length > 0)
			{
				var parentFolder:String = Song.chartPath.replace('\\', '/');
				parentFolder = parentFolder.substr(0, Song.chartPath.lastIndexOf('/')+1);
				var notetypeFile:Array<String> = CoolUtil.coolTextFile(parentFolder + 'notetypes.txt');
				if(notetypeFile.length > 0)
				{
					for (ntTyp in notetypeFile)
					{
						var name:String = ntTyp.trim();
						if(!noteTypes.contains(name))
							noteTypes.push(name);
					}
				}
			}
			
			var displayNoteTypes:Array<String> = noteTypes.copy();
			for (id => key in displayNoteTypes)
			{
				if(id == 0) continue;
				displayNoteTypes[id] = '$id. $key';
			}
			
			var lastSelected:String = noteTypeDropDown.selectedLabel;
			noteTypeDropDown.list = displayNoteTypes;
			noteTypeDropDown.selectedLabel = lastSelected;
		}
	}

	function pasteCopiedNotesToSection(?canCopyNotes:Bool = true, ?canCopyEvents:Bool = true, ?showMessage:Bool = true) //Used on "Paste Section" and "Copy Last Section" buttons
	{
		var curSectionTime:Null<Float> = cachedSectionTimes[curSec];
		if(curSectionTime == null)
		{
			showOutput('newchartEditor_error_unknown_section', true);
			return [];
		}

		var pushedNotes:Array<MetaNote> = [];
		var nts:Array<MetaNote> = [];
		var evs:Array<EventMetaNote> = [];
		if(canCopyNotes && copiedNotes.length > 0)
		{
			for (note in copiedNotes)
			{
				if(note == null) continue;
				var dataCopy:Array<Dynamic> = makeNoteDataCopy(note, false);
				dataCopy[0] += curSectionTime;

				var createdNote = createNote(dataCopy, curSec);
				notes.push(createdNote);
				pushedNotes.push(createdNote);
				nts.push(createdNote);
			}
			notes.sort(PlayState.sortByTime);
		}

		if(canCopyEvents && copiedEvents.length > 0)
		{
			for (event in copiedEvents)
			{
				if(event == null) continue;
				var dataCopy:Array<Dynamic> = makeNoteDataCopy(event, true);
				dataCopy[0] += curSectionTime;

				var createdEvent = createEvent(dataCopy);
				events.push(createdEvent);
				pushedNotes.push(createdEvent);
				evs.push(createdEvent);
			}
			events.sort(PlayState.sortByTime);
		}
		loadSection();
		
		if(showMessage)
		{
			if(nts.length == 0 && evs.length == 0)
			{
				showOutput('newchartEditor_nothing_to_paste', true);
				return [];
			}

			var str:String = '';
			if(nts.length > 0) str += '${Language.get("newchartEditor_notes_added",'Notes Added')}: ${nts.length}';
			if(evs.length > 0)
			{
				if(str.length > 0) str += '\n';
				str += '${Language.get("newchartEditor_events_added",'Events Added')}: ${evs.length}';
			}

			if(str.length > 0) showOutput(str);
		}
		addUndoAction(ADD_NOTE, {notes: nts, events: evs});
		return pushedNotes;
	}

	var songNameInputText:PsychUIInputText;
	var allowVocalsCheckBox:PsychUICheckBox;

	var bpmStepper:PsychUINumericStepper;
	var scrollSpeedStepper:PsychUINumericStepper;
	var audioOffsetStepper:PsychUINumericStepper;

	var stageDropDown:PsychUIDropDownMenu;
	var playerDropDown:PsychUIDropDownMenu;
	var opponentDropDown:PsychUIDropDownMenu;
	var girlfriendDropDown:PsychUIDropDownMenu;
	
	function addSongTab()
	{
		var tab_group = mainBox.getTab('newchartEditor_song').menu;
		var objX = 10;
		var objY = 25;

		songNameInputText = new PsychUIInputText(objX, objY, 100, 'None', 8);
		songNameInputText.onChange = function(old:String, cur:String) PlayState.SONG.song = cur;

		allowVocalsCheckBox = new PsychUICheckBox(objX, objY + 20, Language.get('newchartEditor_allow_vocals', 'Allow Vocals'), 80, function()
		{
			PlayState.SONG.needsVoices = allowVocalsCheckBox.checked;
			loadMusic();
		});
		var reloadAudioButton:PsychUIButton = new PsychUIButton(objX + 120, objY, 'newchartEditor_reload_audio', function() loadMusic(true), 80);

		#if mac
		var reloadJsonButton:PsychUIButton = new PsychUIButton(objX + 205, objY, 'newchartEditor_reload_json', function()
		{
			var cur = Paths.formatToSongPath(songNameInputText.text);
			var curdiff = Highscore.formatSong(cur, PlayState.storyDifficulty);
			var diff = false;
			var loadedChart:SwagSong = try {
				diff = true;
				Song.getChart(curdiff, cur);
			} catch (e) {
				diff = false;
				Song.getChart(cur, cur);
			}
			if(loadedChart == null || !Reflect.hasField(loadedChart, 'song'))
			{
				showOutput('newchartEditor_error_file_not_chart', true);
				return;
			}

			var func:Void->Void = function()
			{
				loadChart(loadedChart);
				Song.chartPath = diff ? curdiff : cur;
				reloadNotesDropdowns();
				prepareReload();
				showOutput('newchartEditor_chart_opened', false, [diff ? curdiff : cur]);
			}
					
			if(!ignoreProgressCheckBox.checked) openSubState(new Prompt('Warning: Any unsaved progress\nwill be lost.', func));
			else func();
		}, 80);
		#end

		objY += 65;
		bpmStepper = new PsychUINumericStepper(objX, objY, 1, 1, 1, 400, 3);
		bpmStepper.onValueChange = function()
		{
			var oldTimes:Array<Float> = cachedSectionTimes.copy();
			PlayState.SONG.bpm = bpmStepper.value;
			adaptNotesToNewTimes(oldTimes);
		};

		scrollSpeedStepper = new PsychUINumericStepper(objX + 90, objY, 0.1, 1, 0.1, 10, 2);
		scrollSpeedStepper.onValueChange = function() PlayState.SONG.speed = scrollSpeedStepper.value;

		audioOffsetStepper = new PsychUINumericStepper(objX + 180, objY, 1, 0, -500, 500, 0);
		audioOffsetStepper.onValueChange = function()
		{
			PlayState.SONG.offset = audioOffsetStepper.value;
			Conductor.offset = audioOffsetStepper.value;
			updateWaveform();
		};

		tab_group.add(new EditorsText(songNameInputText.x, songNameInputText.y - 15, 80, Language.get('newchartEditor_song_name', 'Song Name:')));
		tab_group.add(songNameInputText);
		tab_group.add(allowVocalsCheckBox);
		tab_group.add(reloadAudioButton);
		#if mac
		tab_group.add(reloadJsonButton);
		#end

		objY += 40;
		
		var characters:Array<String> = loadFileList('characters/', 'data/characterList.txt');
		
		playerDropDown = new PsychUIDropDownMenu(objX, objY, characters, function(id:Int, character:String)
		{
			PlayState.SONG.player1 = character;
			updateJsonData();
			updateHeads(true);
			loadMusic();
			TraceManager.debug('trace.editor.characterSelected', 'selected {}', [character]);
		});
		
		stageDropDown = new PsychUIDropDownMenu(objX + 140, objY, loadFileList('stages/', 'data/stageList.txt'), function(id:Int, stage:String)
		{
			PlayState.SONG.stage = stage;
			StageData.loadDirectory(PlayState.SONG);
			// Update pixel stage flag from the stage file, then reload note textures
			var sf = StageData.getStageFile(stage);
			if(sf != null) PlayState.isPixelStage = sf.isPixelStage;
			MetaNote.clearStaticCache();
			reloadNotes();
			TraceManager.debug('trace.editor.stageSelected', 'selected {}', [stage]);
		});
		
		opponentDropDown = new PsychUIDropDownMenu(objX, objY + 40, characters, function(id:Int, character:String)
		{
			PlayState.SONG.player2 = character;
			updateJsonData();
			updateHeads(true);
			loadMusic();
			TraceManager.debug('trace.editor.characterSelected', 'selected {}', [character]);
		});
		
		girlfriendDropDown = new PsychUIDropDownMenu(objX, objY + 80, characters, function(id:Int, character:String)
		{
			PlayState.SONG.gfVersion = character;
			TraceManager.debug('trace.editor.characterSelected', 'selected {}', [character]);
		});
		
		playerDropDown.selectedLabel = PlayState.SONG.player1;
		opponentDropDown.selectedLabel = PlayState.SONG.player2;
		girlfriendDropDown.selectedLabel = PlayState.SONG.gfVersion;
		stageDropDown.selectedLabel = PlayState.SONG.stage;

		tab_group.add(new EditorsText(bpmStepper.x, bpmStepper.y - 15, 50, Language.get('newchartEditor_bpm', 'BPM:')));
		tab_group.add(new EditorsText(scrollSpeedStepper.x, scrollSpeedStepper.y - 15, 80, Language.get('newchartEditor_scroll_speed', 'Scroll Speed:')));
		tab_group.add(new EditorsText(audioOffsetStepper.x, audioOffsetStepper.y - 15, 100, Language.get('newchartEditor_audio_offset', 'Audio Offset (ms):')));
		tab_group.add(bpmStepper);
		tab_group.add(scrollSpeedStepper);
		tab_group.add(audioOffsetStepper);

		tab_group.add(new EditorsText(stageDropDown.x, stageDropDown.y - 15, 80, Language.get('newchartEditor_stage', 'Stage:')));
		tab_group.add(new EditorsText(playerDropDown.x, playerDropDown.y - 15, 80, Language.get('newchartEditor_player', 'Player:')));
		tab_group.add(new EditorsText(opponentDropDown.x, opponentDropDown.y - 15, 80, Language.get('newchartEditor_opponent', 'Opponent:')));
		tab_group.add(new EditorsText(girlfriendDropDown.x, girlfriendDropDown.y - 15, 80, Language.get('newchartEditor_girlfriend', 'Girlfriend:')));
		tab_group.add(stageDropDown);
		tab_group.add(girlfriendDropDown);
		tab_group.add(opponentDropDown);
		tab_group.add(playerDropDown);
	}

	function addFileTab()
	{
		var tab = upperBox.getTab('newchartEditor_file');
		var tab_group = tab.menu;
		var btnX = tab.x - upperBox.x;
		var btnY = 1;
		var btnWid = Std.int(tab.width);

		var btn:PsychUIButton = new PsychUIButton(btnX, btnY, 'newchartEditor_new', function()
		{
			var func:Void->Void = function()
			{
				openNewChart();
				reloadNotesDropdowns();
				prepareReload();
			}

			if(!ignoreProgressCheckBox.checked) openSubState(new Prompt('newchartEditor_sure_to_start_over', func));
			else func();
		}, btnWid);
		btn.text.alignment = LEFT;
		tab_group.add(btn);

		btnY++;
		btnY += 20;
		var btn:PsychUIButton = new PsychUIButton(btnX, btnY, 'newchartEditor_open_chart', function()
		{
			if(!fileDialog.completed) return;
			upperBox.isMinimized = true;
			upperBox.bg.visible = false;

			fileDialog.open(function()
			{
				try
				{
					var filePath:String = fileDialog.path.replace('\\', '/');
					var loadedChart:SwagSong;

					// Detect CNE format
					if (CneExport.isCneFormat(fileDialog.data))
					{
						loadedChart = CneExport.cneToPsych(fileDialog.data);
						loadedChart.format = "psych_v1_convert";
					}
					else
					{
						loadedChart = Song.parseJSON(fileDialog.data, filePath.substr(filePath.lastIndexOf('/')));
					}

					if(loadedChart == null || !Reflect.hasField(loadedChart, 'song'))
					{
						showOutput('newchartEditor_error_file_not_chart', true);
						return;
					}

					var func:Void->Void = function()
					{
						loadChart(loadedChart);
						Song.chartPath = fileDialog.path;
						reloadNotesDropdowns();
						prepareReload();
						showOutput('newchartEditor_chart_opened', false, [Song.chartPath]);
					}
					
					if(!ignoreProgressCheckBox.checked) openSubState(new Prompt('newchartEditor_warning_unsaved_progress', func));
					else func();
				}
				catch(e:Exception)
				{
					showOutput('newchartEditor_error', true, [e.message]);
					TraceManager.error('trace.editor.exception', 'Exception: {}', [e.stack]);
				}
			});
		}, btnWid);
		btn.text.alignment = LEFT;
		tab_group.add(btn);

		btnY += 20;
		var btn:PsychUIButton = new PsychUIButton(btnX, btnY, 'newchartEditor_open_autosave', function()
		{
			if(!fileDialog.completed) return;
			upperBox.isMinimized = true;
			upperBox.bg.visible = false;

			if(!FileSystem.exists('backups/'))
			{
				showOutput('newchartEditor_error_no_autosave_folder', true);
				return;
			}
			
			var fileList:Array<String> = FileSystem.readDirectory('backups/').filter((file:String) -> file.endsWith('.$BACKUP_EXT'));
			if(fileList.length < 1)
			{
				showOutput('newchartEditor_error_no_autosave_files', true);
				return;
			}

			fileList.sort((a:String, b:String) -> (a.toUpperCase() < b.toUpperCase()) ? 1 : -1); //Sort alphabetically descending
			var maxItems:Int = Std.int(Math.min(5, fileList.length));
			var radioGrp:PsychUIRadioGroup = new PsychUIRadioGroup(0, 0, fileList, 25, maxItems, false, 240);
			radioGrp.checked = 0;

			var hei:Float = radioGrp.height + 160;
			openSubState(new BasePrompt(420, hei, 'newchartEditor_choose_autosave',
				function(state:BasePrompt) {
					upperBox.isMinimized = true;
					upperBox.bg.visible = false;

					radioGrp.screenCenter(X);
					radioGrp.y = state.bg.y + 80;
					radioGrp.cameras = state.cameras;
					state.add(radioGrp);

					var btn:PsychUIButton = new PsychUIButton(0, radioGrp.y + radioGrp.height + 20, 'newchartEditor_load', function()
					{
						var autosaveName:String = fileList[radioGrp.checked];
						var path:String = 'backups/$autosaveName';
						state.close();

						if(FileSystem.exists(path))
						{
							try
							{
								var loadedChart:SwagSong = Song.parseJSON(File.getContent(path), autosaveName, null);
								if(loadedChart == null || !Reflect.hasField(loadedChart, '__original_path'))
								{
									showOutput('newchartEditor_error_not_valid_autosave', true);
									return;
	
								}
	
								var originalPath:String = Reflect.field(loadedChart, '__original_path');
								Reflect.deleteField(loadedChart, '__original_path');
	
								var func:Void->Void = function()
								{
									Song.chartPath = FileSystem.exists(originalPath) ? originalPath : null;
									loadChart(loadedChart);
									reloadNotesDropdowns();
									prepareReload();
	
									showOutput('newchartEditor_autosave_opened', false, [autosaveName]);
								}
								
								if(!ignoreProgressCheckBox.checked) openSubState(new Prompt('newchartEditor_warning_unsaved_progress', func));
								else func();
							}
							catch(e:Exception)
							{
								showOutput('${Language.get('newchartEditor_error_on_loading_autosave', "Error on loading autosave")}: ${e.message}', true);
							}
						}
						else showOutput('newchartEditor_error_autosave_not_found', true);
					});
					btn.cameras = tab_group.cameras; 
					btn.screenCenter(X);
					state.add(btn);
				}
			));
		}, btnWid);
		btn.text.alignment = LEFT;
		tab_group.add(btn);

		if(SHOW_EVENT_COLUMN)
		{
			btnY += 20;
			var btn:PsychUIButton = new PsychUIButton(btnX, btnY, 'newchartEditor_open_events', function()
			{
				if(!fileDialog.completed) return;
				upperBox.isMinimized = true;
				upperBox.bg.visible = false;
	
				fileDialog.open(function()
				{
					try
					{
						var filePath:String = fileDialog.path.replace('\\', '/');
						var eventsFile:SwagSong = Song.parseJSON(fileDialog.data, filePath.substr(filePath.lastIndexOf('/')));
						if(eventsFile == null || Reflect.hasField(eventsFile, 'scrollSpeed') || eventsFile.events == null)
						{
							showOutput('newchartEditor_error_not_valid_events', true);
							return;
						}
	
						var loadedEvents:Array<Dynamic> = eventsFile.events;
						if(loadedEvents.length < 1)
						{
							showOutput('newchartEditor_error_events_empty', true);
							return;
						}
	
						openSubState(new BasePrompt(420, 400, 'newchartEditor_events_found',
							function(state:BasePrompt)
							{
								var btnY = 390;
								var btn:PsychUIButton = new PsychUIButton(0, btnY, 'newchartEditor_replace_all', function()
								{
									for (event in events)
									{
										if(event != null)
										{
											event.destroy();
											selectedNotes.remove(event);
										}
									}
									undoActions = [];
									events = [];
	
									for (event in loadedEvents)
										events.push(createEvent(event));
	
									softReloadNotes();
									state.close();
									showOutput('newchartEditor_events_loaded');
								});
								btn.normalStyle.bgColor = FlxColor.RED;
								btn.normalStyle.textColor = FlxColor.WHITE;
								btn.screenCenter(X);
								btn.x -= 125;
								btn.cameras = tab_group.cameras; 
								state.add(btn);
								
								var btn:PsychUIButton = new PsychUIButton(0, btnY, 'newchartEditor_add', function()
								{
									for (event in loadedEvents)
										events.push(createEvent(event));
	
									softReloadNotes();
									state.close();
									showOutput('newchartEditor_events_added_success');
								});
								btn.screenCenter(X);
								btn.cameras = tab_group.cameras; 
								state.add(btn);
						
								var btn:PsychUIButton = new PsychUIButton(0, btnY, 'newchartEditor_cancel', state.close);
								btn.screenCenter(X);
								btn.x += 125;
								btn.cameras = tab_group.cameras; 
								state.add(btn);
							}
						));
					}
					catch(e:Exception)
					{
						showOutput('newchartEditor_error', true, [e.message]);
						TraceManager.error('trace.editor.exception', 'Exception: {}', [e.stack]);
					}
				});
			}, btnWid);
			btn.text.alignment = LEFT;
			tab_group.add(btn);
		}

		btnY++;
		btnY += 20;
		var btn:PsychUIButton = new PsychUIButton(btnX, btnY, 'newchartEditor_save', function()
		{
			if(!fileDialog.completed) return;
			upperBox.isMinimized = true;
			upperBox.bg.visible = false;

			openSaveFormatPrompt();
		}, btnWid);
		btn.text.alignment = LEFT;
		tab_group.add(btn);

		btnY++;
		btnY += 20;
		var btn:PsychUIButton = new PsychUIButton(btnX, btnY, 'newchartEditor_reload_chart', function()
		{
			var func:Void->Void = function()
			{
				if(Song.chartPath == null)
				{
					showOutput('newchartEditor_error_must_save_first', true);
					return;
				}
	
				if(FileSystem.exists(Song.chartPath))
				{
					try
					{
						var rawContent:String = File.getContent(Song.chartPath);
						var reloadedChart:SwagSong;
						if (CneExport.isCneFormat(rawContent))
						{
							reloadedChart = CneExport.cneToPsych(rawContent);
							reloadedChart.format = "psych_v1_convert";
						}
						else
						{
							reloadedChart = Song.parseJSON(rawContent);
						}
						loadChart(reloadedChart);
						reloadNotesDropdowns();
						prepareReload();
						showOutput('newchartEditor_chart_reloaded');
					}
					catch(e:Exception)
					{
						showOutput('newchartEditor_error', true, [e.message]);
						TraceManager.error('trace.editor.exception', 'Exception: {}', [e.stack]);
					}
				}
				else showOutput('newchartEditor_error_must_save_first', true);
				
			}

			if(!ignoreProgressCheckBox.checked) openSubState(new Prompt('newchartEditor_warning_unsaved_progress', func));
			else func();
		}, btnWid);
		btn.text.alignment = LEFT;

		tab_group.add(btn);
		btnY += 20;
		var btn:PsychUIButton = new PsychUIButton(btnX, btnY, 'newchartEditor_old_reload_json', function()
		{
			var songLowercase:String = Paths.formatToSongPath(PlayState.SONG.song).toLowerCase();

			var func:Void->Void = function()
			{
				// Delay to ensure the Prompt fully closes before opening a new substate
				haxe.Timer.delay(function() {
					loadJsonWithDifficulty(songLowercase);
				}, 200);
			}

			if(!ignoreProgressCheckBox.checked)
				openSubState(new Prompt('newchartEditor_warning_unsaved_progress', func));
			else
				func();
		}, btnWid);
		btn.text.alignment = LEFT;
		tab_group.add(btn);
		
		btnY += 20;
		var btn:PsychUIButton = new PsychUIButton(btnX, btnY, 'newchartEditor_psych_to_vslice', function()
		{
			if(!fileDialog.completed) return;
			upperBox.isMinimized = true;
			upperBox.bg.visible = false;

			fileDialog.open('song.json', 'Open a Psych Engine Chart JSON', function()
			{
				var filePath:String = fileDialog.path.replace('\\', '/');
				var loadedChart:SwagSong = Song.parseJSON(fileDialog.data, filePath.substr(filePath.lastIndexOf('/')));
				if(loadedChart == null || !Reflect.hasField(loadedChart, 'song')) //Check if chart is ACTUALLY a chart and valid
				{
					showOutput('newchartEditor_error_file_not_psych_chart', true);
					return;
				}

				var pack:VSlicePackage = VSlice.export(loadedChart);
				if(pack.chart == null || pack.metadata == null)
				{
					showOutput('newchartEditor_error_not_valid_chart', true);
					return;
				}

				ClientPrefs.toggleVolumeKeys(false);
				openSubState(new BasePrompt('newchartEditor_metadata',
					function(state:BasePrompt)
					{
						var songName:String = Paths.formatToSongPath(pack.metadata.songName);
						var parentFolder:String = filePath.substring(0, filePath.lastIndexOf('/')+1);
						var artistInput, charterInput, difficultiesInput:PsychUIInputText = null;

						var btnX = 640;
						var btnY = 400;
						var btn:PsychUIButton = new PsychUIButton(btnX, btnY, 'newchartEditor_save', function()
						{
							try
							{
								var diffs:Array<String> = pack.metadata.playData.difficulties;
								if(diffs != null && diffs.length > 0)
								{
									var diffsFound:Array<String> = [];
									var defaultDiff:String = Paths.formatToSongPath(Difficulty.getDefault());
									for (diff in diffs)
									{
										var diffPostfix:String = (diff != defaultDiff) ? '-$diff' : '';
										var chartToFind:String = parentFolder + songName + diffPostfix + '.json';
										if(FileSystem.exists(chartToFind))
										{
											var diffChart:SwagSong = Song.parseJSON(File.getContent(chartToFind), songName + diffPostfix);
											if(diffChart != null)
											{
												var subpack:VSlicePackage = VSlice.export(diffChart, diff);
												var diffSpeed:Dynamic = Reflect.field(subpack.chart.scrollSpeed, diff);
												var diffNotes:Array<VSliceNote> = Reflect.field(subpack.chart.notes, diff);
												if(diffSpeed != null && diffNotes != null)
												{
													Reflect.setField(pack.chart.scrollSpeed, diff, diffSpeed);
													Reflect.setField(pack.chart.notes, diff, diffNotes);
												}
												//trace(diff, diffSpeed, diffNotes.length);
											}
										}
										else CoolUtil.traceMsg('trace.fileNotFound', 'File not found: {}', [chartToFind]);
									}
									
									var chartToFind:String = parentFolder + 'events.json';
									if(FileSystem.exists(chartToFind))
									{
										var eventsChart:SwagSong = Song.parseJSON(File.getContent(chartToFind), 'events');
										if(eventsChart != null)
										{
											var subpack:VSlicePackage = VSlice.export(eventsChart);
											if(subpack.chart.events != null && subpack.chart.events.length > 0)
											{
												for (event in subpack.chart.events)
												{
													if(event == null) continue;
													pack.chart.events.push(event);
												}
											}
											@:privateAccess pack.chart.events.sort(VSlice.sortByTime);
										}
									}

									fileDialog.openDirectory('Save V-Slice Chart/Metadata JSONs', function()
									{
										overwriteSavedSomething = false;
										var path:String = fileDialog.path.replace('\\', '/');
										if(path.endsWith('/')) path = path.substr(0, path.length-1);
										overwriteCheck('$path/$songName-chart.json', '$songName-chart.json', PsychJsonPrinter.print(pack.chart, ['events', 'notes', 'scrollSpeed']), function()
										{
											overwriteCheck('$path/$songName-metadata.json', '$songName-metadata.json', PsychJsonPrinter.print(pack.metadata, ['characters', 'difficulties', 'timeChanges']), function()
											{
												if(overwriteSavedSomething)
													showOutput('newchartEditor_files_saved', false, [path]);
											});
										});
									});
								}
								else showOutput('newchartEditor_error_need_one_difficulty', true);
							}
							catch(e:Exception)
							{
								showOutput('newchartEditor_error', true, [e.message]);
								TraceManager.error('trace.editor.exception', 'Exception: {}', [e.stack]);
							}
							state.close();
						});
						btn.normalStyle.bgColor = FlxColor.GREEN;
						btn.normalStyle.textColor = FlxColor.WHITE;
						btn.cameras = tab_group.cameras; 
						state.add(btn);
						
						var btn:PsychUIButton = new PsychUIButton(btnX + 100, btnY, 'newchartEditor_cancel', state.close);
						btn.cameras = tab_group.cameras; 
						state.add(btn);
						
						var textX = FlxG.width/2 - 180;
						var textY = 360;
						artistInput = new PsychUIInputText(textX, textY, 120, pack.metadata.artist, 8);
						artistInput.cameras = state.cameras;
						artistInput.onChange = function(old:String, cur:String) pack.metadata.artist = cur;
	
						charterInput = new PsychUIInputText(textX + 150, textY, 120, pack.metadata.charter, 8);
						charterInput.cameras = state.cameras;
						charterInput.onChange = function(old:String, cur:String) pack.metadata.charter = cur;

						var diffs:Array<String> = pack.metadata.playData.difficulties;
						if(diffs == null || diffs.length < 0) pack.metadata.playData.difficulties = diffs = ['easy', 'normal', 'hard'];
						difficultiesInput = new PsychUIInputText(textX, textY + 42, 160, diffs.join(', '), 8);
						difficultiesInput.cameras = state.cameras;
						difficultiesInput.forceCase = LOWER_CASE;
						difficultiesInput.onChange = function(old:String, cur:String)
						{
							pack.metadata.playData.difficulties = cur.split(',');

							var diffs:Array<String> = pack.metadata.playData.difficulties;
							for (num => diff in diffs)
								diffs[num] = Paths.formatToSongPath(diff);

							while(diffs.contains('')) //Clear invalids cuz people might be stupid
								diffs.remove('');
						}
						
						var artistTxt:EditorsText = new EditorsText(artistInput.x, artistInput.y - 15, 100, Language.get('newchartEditor_artist_composer', 'Artist/Composer:'));
						artistTxt.cameras = state.cameras;
						artistTxt.font = 'assets/fonts/editors.ttf';
						var charterTxt:EditorsText = new EditorsText(charterInput.x, charterInput.y - 15, 100, Language.get('newchartEditor_charter', 'Charter:'));
						charterTxt.cameras = state.cameras;
						charterTxt.font = 'assets/fonts/editors.ttf';
						var difficultiesTxt:EditorsText = new EditorsText(difficultiesInput.x, difficultiesInput.y - 15, 100, Language.get('newchartEditor_difficulties', 'Difficulties:'));
						difficultiesTxt.cameras = state.cameras;
						difficultiesTxt.font = 'assets/fonts/editors.ttf';
						state.add(artistTxt);
						state.add(charterTxt);
						state.add(difficultiesTxt);
						state.add(artistInput);
						state.add(charterInput);
						state.add(difficultiesInput);
					}
				));
			});
		},btnWid);
		btn.text.alignment = LEFT;
		tab_group.add(btn);

		btnY += 20;
		var btn:PsychUIButton = new PsychUIButton(btnX, btnY, 'newchartEditor_vslice_to_psych', function()
		{
			if(!fileDialog.completed) return;
			upperBox.isMinimized = true;
			upperBox.bg.visible = false;

			fileDialog.open('chart.json', 'Open a V-Slice Chart file', function()
			{
				var chart:VSliceChart = cast Json.parse(fileDialog.data);
				if(chart == null || chart.version == null || chart.notes == null || chart.scrollSpeed == null)
				{
					showOutput('newchartEditor_error_invalid_vslice_chart', true);
					return;
				}

				fileDialog.open('metadata.json', 'Open a V-Slice Metadata file', function()
				{
					var metadata:VSliceMetadata = cast Json.parse(fileDialog.data);
					if(metadata == null || metadata.version == null || metadata.playData == null || metadata.songName == null ||
						metadata.playData.difficulties == null || metadata.timeChanges == null || metadata.timeChanges.length < 1)
					{
						showOutput('newchartEditor_error_invalid_vslice_metadata', true);
						return;
					}

					try
					{
						var pack:PsychPackage = VSlice.convertToPsych(chart, metadata);
						if(pack.difficulties != null)
						{
							fileDialog.openDirectory('Save Converted Psych JSONs', function()
							{
								var path:String = fileDialog.path.replace('\\', '/');
								if(!path.endsWith('/')) path += '/';

								var diffs:Array<String> = metadata.playData.difficulties.copy();
								var defaultDiff:String = Paths.formatToSongPath(Difficulty.getDefault());
								function nextChart()
								{
									while(diffs.length > 0)
									{
										var diffName:String = diffs[0];
										diffs.remove(diffName);
										if(!pack.difficulties.exists(diffName)) continue;
		
										var diffPostfix:String = (diffName != defaultDiff) ? '-$diffName' : '';
										var chartData:SwagSong = pack.difficulties.get(diffName);
										var chartName:String = Paths.formatToSongPath(chartData.song) + diffPostfix + '.json';
										overwriteCheck(path + chartName, chartName, PsychJsonPrinter.print(chartData, ['sectionNotes', 'events']), nextChart, true);
										return;
									}
	
									if(pack.events != null)
									{
										overwriteCheck(path + 'events.json', 'events.json', PsychJsonPrinter.print(pack.events, ['events']), function()
										{
											if(overwriteSavedSomething)
												showOutput('newchartEditor_files_saved', false, [fileDialog.path]);
										}, true);
									}
									else if(overwriteSavedSomething)
										showOutput('newchartEditor_files_saved', false, [fileDialog.path]);
								}
								
								overwriteSavedSomething = false;
								nextChart();
							});
						}
						else showOutput('newchartEditor_error_no_difficulties', true);
					}
					catch(e:Exception)
					{
						showOutput('newchartEditor_error', true, [e.message]);
						TraceManager.error('trace.editor.exception', 'Exception: {}', [e.stack]);
					}
				});
			});
		},btnWid);
		btn.text.alignment = LEFT;
		tab_group.add(btn);
		/*
		btnY += 20;
		var btn:PsychUIButton = new PsychUIButton(btnX, btnY, 'newchartEditor_save_as_1x', function()
		{
			if(!fileDialog.completed) return;
			upperBox.isMinimized = true;
			upperBox.bg.visible = false;

			updateChartData();
			var chartName:String = Paths.formatToSongPath(PlayState.SONG.song) + '.json';
			if(Song.chartPath != null) chartName = Song.chartPath.substr(Song.chartPath.lastIndexOf('/')).trim();
			
			fileDialog.save(chartName, PsychJsonPrinter.print(PlayState.SONG, ['sectionNotes', 'events']),
				function()
				{
					var newPath:String = fileDialog.path;
					Song.chartPath = newPath.replace('\\', '/');
					reloadNotesDropdowns();
					showOutput('Chart saved as 1.x.x to: $newPath');
				}, null, function() showOutput('Error on saving chart!', true));
		}, btnWid);
		btn.text.alignment = LEFT;
		tab_group.add(btn);
		*/

		btnY++;
		btnY += 20;
		var btn:PsychUIButton = new PsychUIButton(btnX, btnY, 'newchartEditor_preview', openEditorPlayState, btnWid);
		btn.text.alignment = LEFT;
		tab_group.add(btn);
		
		btnY += 20;
		var btn:PsychUIButton = new PsychUIButton(btnX, btnY, 'newchartEditor_playtest', goToPlayState, btnWid);
		btn.text.alignment = LEFT;
		tab_group.add(btn);

		btnY++;
		btnY += 20;
		var btn:PsychUIButton = new PsychUIButton(btnX, btnY, 'newchartEditor_exit', function() confirmExit(), btnWid);
		btn.text.alignment = LEFT;
		tab_group.add(btn);
	}

	var lockedEvents:Bool = false;
	function addEditTab()
	{
		var tab = upperBox.getTab('newchartEditor_edit');
		var tab_group = tab.menu;
		var btnX = tab.x - upperBox.x;
		var btnY = 1;
		var btnWid = Std.int(tab.width);

		var btn:PsychUIButton = new PsychUIButton(btnX, btnY, 'newchartEditor_undo', undo, btnWid);
		btn.text.alignment = LEFT;
		tab_group.add(btn);

		btnY += 20;
		var btn:PsychUIButton = new PsychUIButton(btnX, btnY, 'newchartEditor_redo', redo, btnWid);
		btn.text.alignment = LEFT;
		tab_group.add(btn);

		btnY++;
		btnY += 20;
		var btn:PsychUIButton = new PsychUIButton(btnX, btnY, 'newchartEditor_select_all', function()
		{
			var sel = selectedNotes;
			selectedNotes = curRenderedNotes.members.copy();
			addUndoAction(SELECT_NOTE, {old: sel, current: selectedNotes.copy()});
			onSelectNote();
			TraceManager.debug('trace.editor.noteSelected', 'Notes selected: {}', [selectedNotes.length]);
		}, btnWid);
		btn.text.alignment = LEFT;
		tab_group.add(btn);

		if(SHOW_EVENT_COLUMN)
		{
			btnY++;
			btnY += 20;
			var btn:PsychUIButton = new PsychUIButton(btnX, btnY, 'newchartEditor_lock_events', btnWid);
			btn.onClick = function()
			{
				lockedEvents = !lockedEvents;
				if(lockedEvents) btn.text.text = Language.get('newchartEditor_unlock_events', 'Unlock Events');
				else btn.text.text = Language.get('newchartEditor_lock_events', 'Lock Events');
				eventLockOverlay.visible = lockedEvents;
	
				if(selectedNotes.length >= 1)
				{
					var sel = selectedNotes;
					var onlyNotes = selectedNotes.filter((note:MetaNote) -> !note.isEvent);
					resetSelectedNotes();
					selectedNotes = onlyNotes;
					addUndoAction(SELECT_NOTE, {old: sel, current: selectedNotes.copy()});
					if(selectedNotes.length == 1) onSelectNote();
				}
				softReloadNotes();
			};
			btn.text.alignment = LEFT;
			tab_group.add(btn);
		}
		
		btnY++;
		btnY += 20;
		var btn:PsychUIButton = new PsychUIButton(btnX, btnY, 'newchartEditor_autosave_settings', btnWid);
		btn.onClick = function()
		{
			upperBox.isMinimized = true;
			upperBox.bg.visible = false;
			openSubState(new BasePrompt(400, 160, 'newchartEditor_autosave_settings_title',
				function(state:BasePrompt)
				{
					var checkbox:PsychUICheckBox = null;
					var timeStepper:PsychUINumericStepper = null;

					timeStepper = new PsychUINumericStepper(state.bg.x + 50, state.bg.y + 90, 1, autoSaveCap, 1, 30, 0);
					timeStepper.onValueChange = function() {
						autoSaveTime = 0;
						checkbox.checked = true;
						autoSaveCap = chartEditorSave.data.autoSave = Std.int(timeStepper.value);
					};
					timeStepper.cameras = state.cameras;

					checkbox = new PsychUICheckBox(timeStepper.x + 80, timeStepper.y, Language.get('newchartEditor_enabled', 'Enabled'), 60, function() {
						autoSaveTime = 0;
						autoSaveCap = chartEditorSave.data.autoSave = checkbox.checked ? Std.int(timeStepper.value) : 0;
					});
					checkbox.checked = (autoSaveCap > 0);
					checkbox.cameras = state.cameras;
					
					var maxFileStepper:PsychUINumericStepper = new PsychUINumericStepper(checkbox.x + 140, checkbox.y, 1, backupLimit, 0, 50, 0);
					maxFileStepper.onValueChange = function() {
						autoSaveTime = 0;
						checkbox.checked = true;
						chartEditorSave.data.backupLimit = backupLimit = Std.int(maxFileStepper.value);
					};
					maxFileStepper.cameras = state.cameras;

					var txt1:EditorsText = new EditorsText(timeStepper.x, timeStepper.y - 15, 100, Language.get('newchartEditor_time_in_minutes', 'Time (in minutes):'));
					txt1.cameras = state.cameras;
					var txt2:EditorsText = new EditorsText(maxFileStepper.x, maxFileStepper.y - 15, 100, Language.get('newchartEditor_file_limit', 'File Limit:'));
					txt2.cameras = state.cameras;

					state.add(txt1);
					state.add(txt2);
					state.add(checkbox);
					state.add(timeStepper);
					state.add(maxFileStepper);
				}
			));

		};
		btn.text.alignment = LEFT;
		tab_group.add(btn);

		btnY++;
		btnY += 20;
		var btn:PsychUIButton = new PsychUIButton(btnX, btnY, 'newchartEditor_clear_all_notes', function()
		{
			var func:Void->Void = function()
			{
				resetSelectedNotes();
				addUndoAction(DELETE_NOTE, {notes: notes.copy()});
				notes = [];
				loadSection();
			}

			if(!ignoreProgressCheckBox.checked) openSubState(new Prompt('newchartEditor_delete_all_notes', func));
			else func();
		}, btnWid);
		btn.normalStyle.bgColor = FlxColor.RED;
		btn.normalStyle.textColor = FlxColor.WHITE;
		btn.text.alignment = LEFT;
		tab_group.add(btn);

		if(SHOW_EVENT_COLUMN)
		{
			btnY += 20;
			var btn:PsychUIButton = new PsychUIButton(btnX, btnY, 'newchartEditor_clear_all_events', function()
			{
				var func:Void->Void = function()
				{
					resetSelectedNotes();
					addUndoAction(DELETE_NOTE, {events: events.copy()});
					events = [];
					loadSection();
				}
	
				if(!ignoreProgressCheckBox.checked) openSubState(new Prompt('newchartEditor_delete_all_events', func));
				else func();
			}, btnWid);
			btn.normalStyle.bgColor = FlxColor.RED;
			btn.normalStyle.textColor = FlxColor.WHITE;
			btn.text.alignment = LEFT;
			tab_group.add(btn);
		}
	}

	var showLastGridButton:PsychUIButton;
	var showNextGridButton:PsychUIButton;
	var noteTypeLabelsButton:PsychUIButton;
	var vortexEditorButton:PsychUIButton;
	function addViewTab()
	{
		var tab = upperBox.getTab('newchartEditor_view');
		var tab_group = tab.menu;
		var btnX = tab.x - upperBox.x;
		var btnY = 1;
		var btnWid = Std.int(tab.width);

		if(chartEditorSave.data.waveformEnabled != null)
			waveformEnabled = chartEditorSave.data.waveformEnabled;
		if(chartEditorSave.data.waveformTarget != null)
			waveformTarget = chartEditorSave.data.waveformTarget;
		if(chartEditorSave.data.waveformColor != null)
			waveformSprite.color = CoolUtil.colorFromString(chartEditorSave.data.waveformColor);

		showLastGridButton = new PsychUIButton(btnX, btnY, '', function()
		{
			showPreviousSection = !showPreviousSection;
			updateGridVisibility();
		}, btnWid);
		showLastGridButton.text.alignment = LEFT;
		tab_group.add(showLastGridButton);

		btnY += 20;
		showNextGridButton = new PsychUIButton(btnX, btnY, '', function()
		{
			showNextSection = !showNextSection;
			updateGridVisibility();
		}, btnWid);
		showNextGridButton.text.alignment = LEFT;
		tab_group.add(showNextGridButton);

		btnY++;
		btnY += 20;
		noteTypeLabelsButton = new PsychUIButton(btnX, btnY, '', function()
		{
			showNoteTypeLabels = !showNoteTypeLabels;
			updateGridVisibility();
		}, btnWid);
		noteTypeLabelsButton.text.alignment = LEFT;
		tab_group.add(noteTypeLabelsButton);

		btnY++;
		btnY += 20;
		vortexEditorButton = new PsychUIButton(btnX, btnY, vortexEnabled ? 'newchartEditor_vortex_editor_on' : 'newchartEditor_vortex_editor_off', function()
		{
			vortexEnabled = !vortexEnabled;
			chartEditorSave.data.vortex = vortexEnabled;
			vortexIndicator.visible = strumLineNotes.visible = strumLineNotes.active = vortexEnabled;
			vortexEditorButton.text.text = vortexEnabled ? Language.get('newchartEditor_vortex_editor_on', 'Vortex Editor ON') : Language.get('newchartEditor_vortex_editor_off', 'Vortex Editor OFF');

			for (note in strumLineNotes)
			{
				note.playAnim('static');
				note.resetAnim = 0;
			}
			prevGridBg.vortexLineEnabled = gridBg.vortexLineEnabled = nextGridBg.vortexLineEnabled = vortexEnabled;
		}, btnWid);
		vortexEditorButton.text.y += 5;
		vortexEditorButton.text.alignment = LEFT;
		tab_group.add(vortexEditorButton);
		
		btnY++;
		btnY += 20;
		var btn:PsychUIButton = new PsychUIButton(btnX, btnY, 'newchartEditor_waveform', function()
		{
			ClientPrefs.toggleVolumeKeys(false);
			openSubState(new BasePrompt(320, 200, Language.get('newchartEditor_waveform_settings', 'Waveform Settings'),
				function(state:BasePrompt) {
					upperBox.isMinimized = true;
					upperBox.bg.visible = false;

					var check:PsychUICheckBox = new PsychUICheckBox(state.bg.x + 40, state.bg.y + 80, Language.get('newchartEditor_enabled', 'Enabled'), 60);
					check.onClick = function()
					{
						chartEditorSave.data.waveformEnabled = waveformEnabled = check.checked;
						updateWaveform();
					};
					check.cameras = state.cameras;
					check.checked = waveformEnabled;
					state.add(check);

					var waveformC:String = '0000FF';
					if(chartEditorSave.data.waveformColor != null)
						waveformC = chartEditorSave.data.waveformColor;

					var input:PsychUIInputText = new PsychUIInputText(check.x, check.y + 50, 60, waveformC, 10);
					input.onChange = function(old:String, cur:String)
					{
						chartEditorSave.data.waveformColor = cur;
						waveformSprite.color = CoolUtil.colorFromString(cur);
					}
					input.maxLength = 6;
					input.filterMode = ONLY_HEXADECIMAL;
					input.cameras = state.cameras;
					input.forceCase = UPPER_CASE;

					var options:Array<WaveformTarget> = [INST, PLAYER, OPPONENT];
					var radioGrp:PsychUIRadioGroup = new PsychUIRadioGroup(check.x + 120, check.y, [Language.get('newchartEditor_instrumental', 'Instrumental'), Language.get('newchartEditor_main_vocals_label', 'Main Vocals'), Language.get('newchartEditor_opponent_vocals_label', 'Opponent Vocals')]);
					radioGrp.cameras = state.cameras;
					radioGrp.onClick = function()
					{
						waveformTarget = chartEditorSave.data.waveformTarget = options[radioGrp.checked];
						updateWaveform();
					};
					radioGrp.checked = options.indexOf(waveformTarget);
					state.add(radioGrp);

					var txt1:EditorsText = new EditorsText(input.x, input.y - 15, 80, Language.get('newchartEditor_color_hex', 'Color (Hex):'));
					txt1.cameras = state.cameras;
					state.add(txt1);
					state.add(input);
				}
			));
		}, btnWid);
		btn.text.y += 5;
		btn.text.alignment = LEFT;
		tab_group.add(btn);

		btnY += 20;
		var btn:PsychUIButton = new PsychUIButton(btnX, btnY, 'newchartEditor_go_to', function()
		{
			upperBox.isMinimized = true;
			upperBox.bg.visible = false;
			openSubState(new BasePrompt(420, 200, 'newchartEditor_go_to_title',
				function(state:BasePrompt)
				{
					var curTime:Float = Conductor.songPosition;
					var currentSec:Int = curSec;

					var timeStepper:PsychUINumericStepper = new PsychUINumericStepper(state.bg.x + 100, state.bg.y + 90, 1, Math.floor(curTime)/1000, 0, FlxG.sound.music.length/1000 - 0.01, 2, 80);
					timeStepper.cameras = state.cameras;
					var sectionStepper:PsychUINumericStepper = new PsychUINumericStepper(timeStepper.x + 160, timeStepper.y, 1, currentSec, 0, PlayState.SONG.notes.length - 1, 0);
					sectionStepper.cameras = state.cameras;

					var txt1:EditorsText = new EditorsText(timeStepper.x, timeStepper.y - 15, 100, Language.get('newchartEditor_time_in_seconds', 'Time (in seconds):'));
					txt1.font = 'assets/fonts/editors.ttf';
					var txt2:EditorsText = new EditorsText(sectionStepper.x, sectionStepper.y - 15, 100, Language.get('newchartEditor_section', 'Section:'));
					txt2.font = 'assets/fonts/editors.ttf';

					txt1.cameras = state.cameras;
					txt2.cameras = state.cameras;
					state.add(txt1);
					state.add(txt2);
					state.add(timeStepper);
					state.add(sectionStepper);

					var timeTxt:EditorsText = new EditorsText(15, state.bg.y + state.bg.height - 75, 230, '', 16);
					timeTxt.alignment = CENTER;
					timeTxt.screenCenter(X);
					timeTxt.cameras = state.cameras;

					state.add(timeTxt);
					function updateTime()
					{
						var tm:String = FlxStringUtil.formatTime(curTime / 1000, true);
						var ln:String = FlxStringUtil.formatTime(FlxG.sound.music.length / 1000, true);
						timeTxt.text = '$tm / $ln';
					}
					updateTime();

					timeStepper.onValueChange = function()
					{
						curTime = timeStepper.value * 1000;
						for (i => time in cachedSectionTimes)
						{
							if(time <= curTime)
								currentSec = i;
							else break;
						}
						updateTime();
					};
					sectionStepper.onValueChange = function()
					{
						currentSec = Std.int(sectionStepper.value);
						curTime = cachedSectionTimes[currentSec] + 0.000001;
						updateTime();
					};

					var btn:PsychUIButton = new PsychUIButton(0, timeTxt.y + 35, 'newchartEditor_go_to', function()
					{
						curSec = currentSec;
						FlxG.sound.music.time = FlxMath.bound(curTime, 0, FlxG.sound.music.length - 1);
						loadSection();
						state.close();
					});

					btn.cameras = tab_group.cameras; 
					btn.screenCenter(X);
					btn.x -= 60;
					state.add(btn);

					var btn:PsychUIButton = new PsychUIButton(0, btn.y, 'newchartEditor_cancel', state.close);
					btn.cameras = tab_group.cameras; 
					btn.screenCenter(X);
					btn.x += 60;
					state.add(btn);
				}
			));
		}, btnWid);
		btn.text.y = btn.y + 3;
		btn.text.alignment = LEFT;
		btn.cameras = tab_group.cameras; 
		tab_group.add(btn);

		btnY++;
		btnY += 20;
		var btn:PsychUIButton = new PsychUIButton(btnX, btnY, 'newchartEditor_theme', function()
		{
			if(!fileDialog.completed) return;
			upperBox.isMinimized = true;
			upperBox.bg.visible = false;

			openSubState(new BasePrompt(500, 260, 'newchartEditor_theme_title',
				function(state:BasePrompt)
				{
					var btnY = 320;
					var btn:PsychUIButton = new PsychUIButton(0, btnY, 'newchartEditor_light', changeTheme.bind(LIGHT));
					btn.screenCenter(X);
					btn.x -= 180;
					btn.cameras = tab_group.cameras; 
					state.add(btn);
			
					var btn:PsychUIButton = new PsychUIButton(0, btnY, 'newchartEditor_dark', changeTheme.bind(DARK));
					btn.screenCenter(X);
					btn.x -= 60;
					btn.cameras = tab_group.cameras; 
					state.add(btn);
					
					var btn:PsychUIButton = new PsychUIButton(0, btnY, 'newchartEditor_default', changeTheme.bind(DEFAULT));
					btn.screenCenter(X);
					btn.cameras = tab_group.cameras; 
					btn.x += 60;
					state.add(btn);
			
					var btn:PsychUIButton = new PsychUIButton(0, btnY, 'newchartEditor_vslice', changeTheme.bind(VSLICE));
					btn.screenCenter(X);
					btn.x += 180;
					btn.cameras = tab_group.cameras; 
					state.add(btn);

					btnY += 60;
					var btn:PsychUIButton = new PsychUIButton(0, btnY, 'newchartEditor_custom', changeTheme.bind(CUSTOM));
					btn.screenCenter(X);
					btn.x -= 180;
					btn.cameras = tab_group.cameras; 
					state.add(btn);

					var customBgC:String = '303030';
					if(chartEditorSave.data.customBgColor != null)
						customBgC = chartEditorSave.data.customBgColor;

					var input:PsychUIInputText = new PsychUIInputText(0, btnY, 80, customBgC, 10);
					input.maxLength = 6;
					input.filterMode = ONLY_HEXADECIMAL;
					input.forceCase = UPPER_CASE;
					input.screenCenter(X);
					input.x -= 60;
					input.cameras = state.cameras;
					input.onChange = function(old:String, cur:String)
					{
						chartEditorSave.data.customBgColor = cur;
						changeTheme(CUSTOM);
					}

					var txt:EditorsText = new EditorsText(input.x, input.y - 15, 120, Language.get('newchartEditor_bg_color', 'BG Color:'));
					txt.font = 'assets/fonts/editors.ttf';
					txt.cameras = state.cameras;
					state.add(txt);
					state.add(input);

					var customGridC:Array<String> = ['DFDFDF', 'BFBFBF'];
					if(chartEditorSave.data.customGridColors != null && chartEditorSave.data.customGridColors.length > 1)
						customGridC = chartEditorSave.data.customGridColors;

					var input:PsychUIInputText = new PsychUIInputText(0, btnY, 80, customGridC[0], 10);
					input.maxLength = 6;
					input.filterMode = ONLY_HEXADECIMAL;
					input.forceCase = UPPER_CASE;
					input.screenCenter(X);
					input.x += 60;
					input.cameras = state.cameras;
					input.onChange = function(old:String, cur:String)
					{
						chartEditorSave.data.customGridColors[0] = cur;
						changeTheme(CUSTOM);
					}

					var txt:EditorsText = new EditorsText(input.x, input.y - 15, 120, Language.get('newchartEditor_grid_colors', 'Grid Colors:'));
					txt.font = 'assets/fonts/editors.ttf';
					txt.cameras = state.cameras;
					state.add(txt);
					state.add(input);

					var input:PsychUIInputText = new PsychUIInputText(0, btnY + 30, 80, customGridC[1], 10);
					input.maxLength = 6;
					input.filterMode = ONLY_HEXADECIMAL;
					input.forceCase = UPPER_CASE;
					input.screenCenter(X);
					input.x += 60;
					input.cameras = state.cameras;
					input.onChange = function(old:String, cur:String)
					{
						chartEditorSave.data.customGridColors[1] = cur;
						changeTheme(CUSTOM);
					}
					state.add(input);

					var customGridOtherC:Array<String> = ['5F5F5F', '4A4A4A'];
					if(chartEditorSave.data.customNextGridColors != null && chartEditorSave.data.customNextGridColors.length > 1)
						customGridOtherC = chartEditorSave.data.customNextGridColors;

					var input:PsychUIInputText = new PsychUIInputText(0, btnY, 80, customGridOtherC[0], 10);
					input.maxLength = 6;
					input.filterMode = ONLY_HEXADECIMAL;
					input.forceCase = UPPER_CASE;
					input.screenCenter(X);
					input.x += 180;
					input.cameras = state.cameras;
					input.onChange = function(old:String, cur:String)
					{
						chartEditorSave.data.customNextGridColors[0] = cur;
						changeTheme(CUSTOM);
					}

					var txt:EditorsText = new EditorsText(input.x, input.y - 15, 120, Language.get('newchartEditor_next_grid_colors', 'Next Grid Color:'));
					txt.font = 'assets/fonts/editors.ttf';
					txt.cameras = state.cameras;
					state.add(txt);
					state.add(input);

					var input:PsychUIInputText = new PsychUIInputText(0, btnY + 30, 80, customGridOtherC[1], 10);
					input.maxLength = 6;
					input.filterMode = ONLY_HEXADECIMAL;
					input.forceCase = UPPER_CASE;
					input.screenCenter(X);
					input.x += 180;
					input.cameras = state.cameras;
					input.onChange = function(old:String, cur:String)
					{
						chartEditorSave.data.customNextGridColors[1] = cur;
						changeTheme(CUSTOM);
					}
					state.add(input);
				}
			));
		}, btnWid);
		btn.text.alignment = LEFT;
		tab_group.add(btn);

		btnY += 20;
		var btn:PsychUIButton = new PsychUIButton(btnX, btnY, 'newchartEditor_reset_ui_boxes', function()
		{
			mainBox.setPosition(mainBoxPosition.x, mainBoxPosition.y);
			infoBox.setPosition(infoBoxPosition.x, infoBoxPosition.y);
			UIEvent(PsychUIBox.DROP_EVENT, btn); //to force a save
		}, btnWid);
		btn.text.y = btn.y + 5;
		btn.text.alignment = LEFT;
		tab_group.add(btn);
	}

	function updateChartData()
	{
		for (secNum => section in PlayState.SONG.notes)
			PlayState.SONG.notes[secNum].sectionNotes = [];

		notes.sort(PlayState.sortByTime);
		var noteSec:Int = 0;
		var nextSectionTime:Float = cachedSectionTimes[noteSec + 1];
		var curSectionTime:Float = cachedSectionTimes[noteSec];

		for (num => note in notes)
		{
			if(note == null) continue;

			while(cachedSectionTimes[noteSec + 1] <= note.strumTime)
			{
				noteSec++;
				nextSectionTime = cachedSectionTimes[noteSec + 1];
				curSectionTime = cachedSectionTimes[noteSec];
			}

			var arr:Array<Dynamic> = PlayState.SONG.notes[noteSec].sectionNotes;
			//trace('Added note with time ${note.songData[0]} at section $noteSec');
			arr.push(note.songData);
		}

		events.sort(PlayState.sortByTime);
		PlayState.SONG.events = [];
		for (event in events)
			PlayState.SONG.events.push(event.songData);
	}

	function saveChart()
	{
		updateChartData();
		var chartData:String = PsychJsonPrinter.print(PlayState.SONG, ['sectionNotes', 'events']);

		var chartName:String = Paths.formatToSongPath(PlayState.SONG.song) + '.json';
		if(Song.chartPath != null)
		{
			var lastSlash:Int = Song.chartPath.lastIndexOf('/');
			if(lastSlash >= 0)
				chartName = Song.chartPath.substring(lastSlash + 1);
			else
				chartName = Song.chartPath;
		}

		fileDialog.save(chartName, chartData,
			function()
			{
				var newPath:String = fileDialog.path;
				Song.chartPath = newPath.replace('\\', '/');
				reloadNotesDropdowns();
				clearUnsaved();
				showOutput('newchartEditor_chart_saved',false,[newPath]);
			}, null, function() showOutput('newchartEditor_error_save', true));
	}

	// ── Unified Save Format Prompt ──

	function openSaveFormatPrompt()
	{
		ClientPrefs.toggleVolumeKeys(false);

		var formatNames:Array<String> = [
			Language.get('newchartEditor_format_psych_v1', 'Psych Engine v1.0'),
			Language.get('newchartEditor_format_psych_v0', 'Psych Engine v0.x (Legacy)'),
			Language.get('newchartEditor_format_cne', 'Codename Engine (CNE)'),
			Language.get('newchartEditor_format_vslice', 'V-Slice'),
			Language.get('newchartEditor_format_events', 'Events Only')
		];

		var radioGrp:PsychUIRadioGroup = new PsychUIRadioGroup(0, 0, formatNames, 35, 5, false, 260);
		radioGrp.checked = 0;

		var promptHeight:Float = 100 + 5 * 35 + 70;
		openSubState(new BasePrompt(420, promptHeight,
			Language.get('newchartEditor_save_format_title', 'Save Chart As...'),
			function(state:BasePrompt)
			{
				radioGrp.x = state.bg.x + 30;
				radioGrp.y = state.bg.y + 55;
				radioGrp.cameras = state.cameras;
				state.add(radioGrp);

				var btnY:Float = state.bg.y + state.bg.height - 45;
				var saveBtn:PsychUIButton = new PsychUIButton(0, btnY, Language.get('newchartEditor_save_btn', 'Save'), function()
				{
					var choice:Int = radioGrp.checked;
					state.close();
					// Delay to ensure prompt closes before file dialog opens
					haxe.Timer.delay(function() {
						switch(choice)
						{
							case 0: saveChart();
							case 1: saveAsOldFormat();
							case 2: saveAsCne();
							case 3: saveAsVslice();
							case 4: saveEventsOnly();
						}
					}, 200);
				});
				saveBtn.screenCenter(X);
				saveBtn.x -= 80;
				saveBtn.cameras = state.cameras;
				saveBtn.normalStyle.bgColor = FlxColor.GREEN;
				saveBtn.normalStyle.textColor = FlxColor.WHITE;
				state.add(saveBtn);

				var cancelBtn:PsychUIButton = new PsychUIButton(0, btnY, Language.get('newchartEditor_cancel_btn', 'Cancel'), function()
				{
					state.close();
				});
				cancelBtn.screenCenter(X);
				cancelBtn.x += 80;
				cancelBtn.cameras = state.cameras;
				state.add(cancelBtn);
			}
		));
	}

	function saveAsOldFormat()
	{
		updateChartData();
		var oldFormatSong:SwagSong = convertToOldFormat(PlayState.SONG);

		var chartName:String = Paths.formatToSongPath(PlayState.SONG.song) + '.json';
		if(Song.chartPath != null)
		{
			var lastSlash:Int = Song.chartPath.lastIndexOf('/');
			if(lastSlash >= 0)
				chartName = Song.chartPath.substring(lastSlash + 1);
			else
				chartName = Song.chartPath;
		}

		fileDialog.save(chartName, Json.stringify({song: oldFormatSong}, "\t"),
			function()
			{
				var newPath:String = fileDialog.path;
				showOutput('newchartEditor_chart_saved_as_0x', false, [newPath]);
			}, null, function() showOutput('newchartEditor_error_save', true));
	}

	function saveAsCne()
	{
		updateChartData();
		var cneJson:String = CneExport.psychToCne(PlayState.SONG);

		var chartName:String = Paths.formatToSongPath(PlayState.SONG.song) + '.json';
		if(Song.chartPath != null)
		{
			var lastSlash:Int = Song.chartPath.lastIndexOf('/');
			if(lastSlash >= 0)
				chartName = Song.chartPath.substring(lastSlash + 1);
			else
				chartName = Song.chartPath;
		}
		// CNE chart files typically go in a charts/ subfolder, but we save as selected
		fileDialog.save(chartName, cneJson,
			function()
			{
				var newPath:String = fileDialog.path;
				Song.chartPath = newPath.replace('\\', '/');
				showOutput('newchartEditor_cne_saved', false, [newPath]);
			}, null, function() showOutput('newchartEditor_error_save', true));
	}

	function saveAsVslice()
	{
		updateChartData();
		var pack:VSlicePackage = VSlice.export(PlayState.SONG);

		fileDialog.openDirectory(Language.get('newchartEditor_save_vslice_dir', 'Save V-Slice Chart/Metadata JSONs'), function()
		{
			try
			{
				var path:String = fileDialog.path.replace('\\', '/');

				var chartName:String = Paths.formatToSongPath(PlayState.SONG.song);
				chartName = chartName.substring(chartName.lastIndexOf('/')+1);

				var chartFile:String = '$path/$chartName-chart.json';
				var metadataFile:String = '$path/$chartName-metadata.json';

				ClientPrefs.toggleVolumeKeys(false);
				openSubState(new BasePrompt('newchartEditor_metadata',
					function(state:BasePrompt)
					{
						var btnLX = 640;
						var btnLY = 400;
						var saveBtn:PsychUIButton = new PsychUIButton(btnLX, btnLY, Language.get('newchartEditor_save_btn', 'Save'), function()
						{
							overwriteSavedSomething = false;
							overwriteCheck(chartFile, '$chartName-chart.json', PsychJsonPrinter.print(pack.chart, ['events', 'notes', 'scrollSpeed']), function()
							{
								overwriteCheck(metadataFile, '$chartName-metadata.json', PsychJsonPrinter.print(pack.metadata, ['characters', 'difficulties', 'timeChanges']), function()
								{
									if(overwriteSavedSomething)
										showOutput('newchartEditor_files_saved', false, [path]);
								});
							});
							state.close();
						});
						saveBtn.normalStyle.bgColor = FlxColor.GREEN;
						saveBtn.normalStyle.textColor = FlxColor.WHITE;
						saveBtn.cameras = state.cameras;
						state.add(saveBtn);

						var cancelBtn:PsychUIButton = new PsychUIButton(btnLX + 100, btnLY, Language.get('newchartEditor_cancel_btn', 'Cancel'), state.close);
						cancelBtn.cameras = state.cameras;
						state.add(cancelBtn);

						var textX = FlxG.width/2 - 155;
						var textY = 360;
						var artistInput:PsychUIInputText = new PsychUIInputText(textX, textY, 120, pack.metadata.artist, 8);
						artistInput.cameras = state.cameras;
						artistInput.onChange = function(old:String, cur:String) pack.metadata.artist = cur;

						var charterInput:PsychUIInputText = new PsychUIInputText(textX + 190, textY, 120, pack.metadata.charter, 8);
						charterInput.cameras = state.cameras;
						charterInput.onChange = function(old:String, cur:String) pack.metadata.charter = cur;

						var artistTxt:EditorsText = new EditorsText(artistInput.x, artistInput.y - 15, 100, Language.get('newchartEditor_artist_composer', 'Artist/Composer:'));
						artistTxt.cameras = state.cameras;
						var charterTxt:EditorsText = new EditorsText(charterInput.x, charterInput.y - 15, 100, Language.get('newchartEditor_charter', 'Charter:'));
						charterTxt.cameras = state.cameras;
						state.add(artistTxt);
						state.add(charterTxt);
						state.add(artistInput);
						state.add(charterInput);
					}
				));
			}
			catch(e:Exception)
			{
				showOutput('newchartEditor_error', true, [e.message]);
			}
		});
	}

	function saveEventsOnly()
	{
		updateChartData();
		fileDialog.save('events.json', PsychJsonPrinter.print({events: PlayState.SONG.events, format: 'psych_v1'}, ['events']),
			function() showOutput('newchartEditor_events_saved', false, [fileDialog.path]), null,
			function() showOutput('newchartEditor_error_save_events', true));
	}
	
	inline function getCurChartSection()
	{
		return PlayState.SONG.notes != null ? PlayState.SONG.notes[curSec] : null;
	}
    /**
	function updateNotesRGB()
	{
		PlayState.SONG.disableNoteRGB = noRGBCheckBox.checked;

		for (note in notes)
		{
			if(note == null) continue;

			note.rgbShader.enabled = !noRGBCheckBox.checked;
			if(note.rgbShader.enabled)
			{
				var data = backend.NoteTypesConfig.loadNoteTypeData(note.noteType);
				if(data == null || data.length < 1) continue;

				for (line in data)
				{
					var prop:String = line.property.join('.');
					if(prop == 'rgbShader.enabled')
						note.rgbShader.enabled = line.value;
				}
			}
		}

		for (note in strumLineNotes)
			note.rgbShader.enabled = !noRGBCheckBox.checked;
	}
        */
        function updateNotesRGB():Void
        {
            var disableRGB:Bool = (PlayState.SONG.disableNoteRGB == true);

            for (note in curRenderedNotes)
            {
                if (note == null || note.noteData < 0) continue;

                if (note.colorSwap != null)
                {
                    if (disableRGB)
                    {
                        note.colorSwap.hue = 0;
                        note.colorSwap.saturation = 0;
                        note.colorSwap.brightness = 0;
                    }
                    else if (note.noteData < ClientPrefs.data.arrowHSV.length)
                    {
                        note.colorSwap.hue = ClientPrefs.data.arrowHSV[note.noteData][0] / 360;
                        note.colorSwap.saturation = ClientPrefs.data.arrowHSV[note.noteData][1] / 100;
                        note.colorSwap.brightness = ClientPrefs.data.arrowHSV[note.noteData][2] / 100;
                    }
                }
            }
        }


	function updateGridVisibility()
	{
		showLastGridButton.text.text = showPreviousSection	? Language.get('newchartEditor_hide_last_section', 'Hide Last Section') :  Language.get('newchartEditor_show_last_section', 'Show Last Section');
		showNextGridButton.text.text = showNextSection		? Language.get('newchartEditor_hide_next_section', 'Hide Next Section') :  Language.get('newchartEditor_show_next_section', 'Show Next Section');

		prevGridBg.visible = (curSec > 0 && showPreviousSection);
		nextGridBg.visible = (curSec < PlayState.SONG.notes.length - 1 && showNextSection);
		
		noteTypeLabelsButton.text.text = showNoteTypeLabels ? Language.get('newchartEditor_hide_note_labels', 'Hide Note Labels') : Language.get('newchartEditor_show_note_labels', 'Show Note Labels');
		for (num => text in MetaNote.noteTypeTexts)
			text.visible = showNoteTypeLabels;
		softReloadNotes();
	}

	function adaptNotesToNewTimes(oldTimes:Array<Float>)
	{
		undoActions = [];
		setSongPlaying(false);
		var gridLerp:Float = FlxMath.bound((scrollY + FlxG.height/2 - gridBg.y) / gridBg.height, 0.000001, 0.999999);
		notes.sort(PlayState.sortByTime);
		_cacheSections();

		var noteSec:Int = 0;
		var oldNextSectionTime:Float = oldTimes[noteSec + 1];
		var oldCurSectionTime:Float = oldTimes[noteSec];
		var nextSectionTime:Float = cachedSectionTimes[noteSec + 1];
		var curSectionTime:Float = cachedSectionTimes[noteSec];

		for (num => note in notes)
		{
			if(note == null || note.strumTime <= 0) continue;

			while(noteSec + 2 < oldTimes.length && oldTimes[noteSec + 1] <= note.strumTime)
			{
				noteSec++;
				oldNextSectionTime = oldTimes[noteSec + 1];
				oldCurSectionTime = oldTimes[noteSec];
				nextSectionTime = cachedSectionTimes[noteSec + 1];
				curSectionTime = cachedSectionTimes[noteSec];

				if(noteSec + 1 >= cachedSectionTimes.length)
				{
					TraceManager.warn('trace.editor.failsafe', 'failsafe, cancel early and delete notes after this');
					var changedSelected:Bool = false;
					for(i in num...notes.length)
					{
						var n = notes[num];
						if(n != null)
						{
							if(selectedNotes.contains(n))
							{
								selectedNotes.remove(n);
								changedSelected = true;
							}
							notes.remove(n);
							note.destroy();
						}
					}
					if(changedSelected) onSelectNote();
					loadSection();
					return;
				}
				//trace('changed section: $noteSec, $oldNextSectionTime, $oldCurSectionTime, $nextSectionTime, $curSectionTime');
			}

			var shouldBound:Bool = (note.strumTime >= oldCurSectionTime && note.strumTime < oldNextSectionTime);
			var strumTime:Float = note.strumTime;

			var ratio:Float = (nextSectionTime - curSectionTime) / (oldNextSectionTime - oldCurSectionTime);
			var adaptedStrumTime:Float = ((note.strumTime - oldCurSectionTime) * ratio) + curSectionTime;
			note.setStrumTime(adaptedStrumTime);
			if(shouldBound)
				note.setStrumTime(FlxMath.bound(note.strumTime, curSectionTime, nextSectionTime));

			positionNoteYOnTime(note, noteSec);
			note.updateSustainToStepCrochet(cachedSectionCrochets[noteSec] / 4);
		}
		
		for (event in events)
		{
			var secNum:Int = 0;
			for (time in cachedSectionTimes)
			{
				if(time > event.strumTime) break;
				secNum++;
			}
			positionNoteYOnTime(event, secNum);
		}
		
		var time:Float = FlxMath.remapToRange(gridLerp, 0, 1, cachedSectionTimes[curSec], cachedSectionTimes[curSec + 1]);
		if(Math.isNaN(time))
		{
			time = 0;
			curSec = 0;
		}
		
		if(FlxG.sound.music != null && time >= FlxG.sound.music.length)
		{
			time = FlxG.sound.music.length - 1;
			curSec = PlayState.SONG.notes.length - 1;
		}
		FlxG.sound.music.time = time;
		Conductor.songPosition = time;
		forceDataUpdate = true;
		loadSection();
	}

	public function UIEvent(id:String, sender:Dynamic)
	{
		//trace(id, sender);
		switch(id)
		{
			case PsychUIButton.CLICK_EVENT, PsychUIDropDownMenu.CLICK_EVENT:
				ignoreClickForThisFrame = true;

			case PsychUIBox.CLICK_EVENT:
				ignoreClickForThisFrame = true;

			case PsychUIBox.MINIMIZE_EVENT:
				chartEditorSave.data.mainBoxPosition = [mainBox.x, mainBox.y];
				chartEditorSave.data.infoBoxPosition = [infoBox.x, infoBox.y];
		}
	}
	function openEditorPlayState()
	{
		if(FlxG.sound.music == null)
		{
			showOutput('newchartEditor_error_load_valid_song', true);
			return;
		}

		// Warn about unsaved changes before previewing
		if(unsavedChanges)
		{
			openSubState(new editors.content.Prompt(
				Language.get('newchartEditor_unsaved_preview', 'You have unsaved changes.\nAutosave and preview?'),
				function()
				{
					autosaveSong();
					doOpenEditorPlayState();
				},
				'newchartEditor_save',
				'newchartEditor_cancel'
			));
		}
		else
		{
			doOpenEditorPlayState();
		}
	}

	function doOpenEditorPlayState():Void
	{
		setSongPlaying(false);
		chartEditorSave.flush(); //just in case a random crash happens before loading
		autosaveSong();
		LoadingState.loadAndSwitchState(new editors.EditorPlayState(sectionStartTime()));
		upperBox.isMinimized = true;
		upperBox.visible = mainBox.visible = infoBox.visible = false;
	}
    function autosaveSong():Void
	{
		FlxG.save.data.autosave = Json.stringify({
			"song": PlayState.SONG 
		});
		FlxG.save.flush();
	}
    function sectionStartTime(add:Int = 0):Float
	{
		var daBPM:Float = PlayState.SONG.bpm;
		var daPos:Float = 0;
		for (i in 0...curSec + add)
		{
			if(PlayState.SONG.notes[i] != null)
			{
				if (PlayState.SONG.notes[i].changeBPM)
				{
					daBPM = PlayState.SONG.notes[i].bpm;
				}
				daPos += getSectionBeats(i) * (1000 * 60 / daBPM);
			}
		}
		return daPos;
	}
    function getSectionBeats(?section:Null<Int> = null)
	{
		if (section == null) section = curSec;
		var val:Null<Float> = null;
		
		if(PlayState.SONG.notes[section] != null) val = PlayState.SONG.notes[section].sectionBeats;
		return val != null ? val : 4;
	}


	function goToPlayState()
	{
		confirmPlaytest();
	}

	override function closeSubState()
	{
		ClientPrefs.toggleVolumeKeys(true);
		super.closeSubState();
		upperBox.isMinimized = true;
		upperBox.visible = mainBox.visible = infoBox.visible = true;
		updateAudioVolume();
	}

	override function destroy()
	{
		//Note.globalRgbShaders = [];

		for (num => text in MetaNote.noteTypeTexts)
			text.destroy();

		MetaNote.noteTypeTexts = [];
		fileDialog.destroy();
		super.destroy();
	}

	function loadFileList(mainFolder:String, ?optionalList:String = null, ?fileTypes:Array<String> = null)
	{
		if(fileTypes == null) fileTypes = ['.json'];

		var fileList:Array<String> = [];
		var tempMap:Map<String, Bool> = new Map<String, Bool>();
		
		if(optionalList != null)
		{
			for (file in Paths.mergeAllTextsNamed(optionalList))
			{
				file = file.trim();
				if(file.length > 0 && !tempMap.exists(file))
				{
					fileList.push(file);
					tempMap.set(file, true);
				}
			}
		}

		var preloadPath:String = Paths.getPreloadPath(mainFolder);
		if(FileSystem.exists(preloadPath))
		{
			for (file in FileSystem.readDirectory(preloadPath))
			{
				var path = haxe.io.Path.join([preloadPath, file.trim()]);
				if (!FileSystem.isDirectory(path) && !file.startsWith('readme.'))
				{
					for (fileType in fileTypes)
					{
						var fileToCheck:String = file.substr(0, file.length - fileType.length);
						if(fileToCheck.length > 0 && path.endsWith(fileType) && !tempMap.exists(fileToCheck))
						{
							fileList.push(fileToCheck);
							tempMap.set(fileToCheck, true);
							break;
						}
					}
				}
			}
		}
		#if MODS_ALLOWED

		var modsPath:String = Paths.mods(mainFolder);
		if(FileSystem.exists(modsPath))
		{
			for (file in FileSystem.readDirectory(modsPath))
			{
				var path = haxe.io.Path.join([modsPath, file.trim()]);
				if (!FileSystem.isDirectory(path) && !file.startsWith('readme.'))
				{
					for (fileType in fileTypes)
					{
						var fileToCheck:String = file.substr(0, file.length - fileType.length);
						if(fileToCheck.length > 0 && path.endsWith(fileType) && !tempMap.exists(fileToCheck))
						{
							fileList.push(fileToCheck);
							tempMap.set(fileToCheck, true);
							break;
						}
					}
				}
			}
		}
		if(Paths.currentModDirectory != null && Paths.currentModDirectory.length > 0)
		{
			var currentModPath:String = Paths.mods(Paths.currentModDirectory + '/' + mainFolder);
			if(FileSystem.exists(currentModPath))
			{
				for (file in FileSystem.readDirectory(currentModPath))
				{
					var path = haxe.io.Path.join([currentModPath, file.trim()]);
					if (!FileSystem.isDirectory(path) && !file.startsWith('readme.'))
					{
						for (fileType in fileTypes)
						{
							var fileToCheck:String = file.substr(0, file.length - fileType.length);
							if(fileToCheck.length > 0 && path.endsWith(fileType) && !tempMap.exists(fileToCheck))
							{
								fileList.push(fileToCheck);
								tempMap.set(fileToCheck, true);
								break;
							}
						}
					}
				}
			}
		}

		for(mod in Paths.getGlobalMods())
		{
			var globalModPath:String = Paths.mods(mod + '/' + mainFolder);
			if(FileSystem.exists(globalModPath))
			{
				for (file in FileSystem.readDirectory(globalModPath))
				{
					var path = haxe.io.Path.join([globalModPath, file.trim()]);
					if (!FileSystem.isDirectory(path) && !file.startsWith('readme.'))
					{
						for (fileType in fileTypes)
						{
							var fileToCheck:String = file.substr(0, file.length - fileType.length);
							if(fileToCheck.length > 0 && path.endsWith(fileType) && !tempMap.exists(fileToCheck))
							{
								fileList.push(fileToCheck);
								tempMap.set(fileToCheck, true);
								break;
							}
						}
					}
				}
			}
		}
		#end

		return fileList;
	}
	
	function loadCharacterFile(char:String):CharacterFile
	{
		if(char != null)
		{
			try
			{
				var characterPath:String = 'characters/' + char + '.json';
				var path:String = '';
				
				#if MODS_ALLOWED
				path = Paths.modFolders(characterPath);
				if (!FileSystem.exists(path)) {
					path = Paths.getPreloadPath(characterPath);
				}
				#else
				path = Paths.getPreloadPath(characterPath);
				#end

				if (!FileSystem.exists(path))
				{
					path = Paths.getPreloadPath('characters/' + Character.DEFAULT_CHARACTER + '.json');
				}

				#if MODS_ALLOWED
				var rawJson = File.getContent(path);
				#else
				var rawJson = OpenFlAssets.getText(path);
				#end

				return cast Json.parse(rawJson);
			}
			catch (e:Dynamic) 
			{
				CoolUtil.traceMsg('trace.charLoadError', 'Error loading character: {} - {}', [char, e]);
			}
		}
		return null;
	}

	var overwriteSavedSomething:Bool = false;
	function overwriteCheck(savePath:String, overwriteName:String, saveData:String, continueFunc:Void->Void = null, ?continueOnCancel:Bool = false)
	{
		if(FileSystem.exists(savePath))
		{
			openSubState(new Prompt('${Language.get("newchartEditor_overwrite", "Overwrite")}: "$overwriteName"?', function()
			{
				overwriteSavedSomething = true;
				File.saveContent(savePath, saveData);
				if(continueFunc != null) continueFunc();
			},
			continueOnCancel ? (function() if(continueFunc != null) continueFunc()) : null));
		}
		else
		{
			overwriteSavedSomething = true;
			File.saveContent(savePath, saveData);
			if(continueFunc != null) continueFunc();
		}
	}

	// Undo/Redo stuff
	var undoActions:Array<UndoStruct> = [];
	var currentUndo:Int = 0;
	function addUndoAction(action:UndoAction, data:Dynamic)
	{
		function destroyFromArr(arr:Array<MetaNote>)
		{
			if(arr == null || arr.length < 1) return;

			for (note in arr)
				if(note != null)
					note.destroy();
		}

		//trace('pushed action: $action');
		if(currentUndo > 0) undoActions = undoActions.slice(currentUndo);
		currentUndo = 0;
		undoActions.insert(0, {action: action, data: data});
		markUnsaved(); // Any undoable action means chart data changed
		while(undoActions.length > 15)
		{
			var lastAction:UndoStruct = undoActions.pop();
			if(lastAction != null)
			{
				switch(lastAction.action)
				{
					case DELETE_NOTE:
						destroyFromArr(lastAction.data.notes);
						destroyFromArr(lastAction.data.events);
					case MOVE_NOTE:
						destroyFromArr(lastAction.data.originalNotes);
						destroyFromArr(lastAction.data.originalEvents);
					default:
				}
			}
		}
	}

	function undo()
	{
		if(isMovingNotes || currentUndo >= undoActions.length)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'), 0.4);
			return;
		}

		var action:UndoStruct = undoActions[currentUndo];
		switch(action.action)
		{
			case ADD_NOTE:
				actionRemoveNotes(action.data.notes, action.data.events);

			case DELETE_NOTE:
				actionPushNotes(action.data.notes, action.data.events);

			case MOVE_NOTE:
				actionRemoveNotes(action.data.movedNotes, action.data.movedEvents);
				actionPushNotes(action.data.originalNotes, action.data.originalEvents);
				onSelectNote();

			case SELECT_NOTE:
				resetSelectedNotes();
				selectedNotes = action.data.old;
				if(lockedEvents) selectedNotes = selectedNotes.filter((note:MetaNote) -> !note.isEvent);
				onSelectNote();
		}
		showOutput('${Language.get("newchartEditor_undo", "Undo")} #${currentUndo+1}: ${action.action}');
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
		currentUndo++;
	}
	function redo()
	{
		if(isMovingNotes || currentUndo < 1)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'), 0.4);
			return;
		}

		currentUndo--;
		var action:UndoStruct = undoActions[currentUndo];
		switch(action.action)
		{
			case ADD_NOTE:
				actionPushNotes(action.data.notes, action.data.events);

			case DELETE_NOTE:
				actionRemoveNotes(action.data.notes, action.data.events);

			case MOVE_NOTE:
				actionRemoveNotes(action.data.originalNotes, action.data.originalEvents);
				actionPushNotes(action.data.movedNotes, action.data.movedEvents);
				onSelectNote();

			case SELECT_NOTE:
				resetSelectedNotes();
				selectedNotes = action.data.current;
				if(lockedEvents) selectedNotes = selectedNotes.filter((note:MetaNote) -> !note.isEvent);
				onSelectNote();
		}
		showOutput('${Language.get("newchartEditor_redo", "Redo")} #${currentUndo+1}: ${action.action}');
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
	}

	function actionPushNotes(dataNotes:Array<MetaNote>, dataEvents:Array<EventMetaNote>)
	{
		resetSelectedNotes();
		if(dataNotes != null && dataNotes.length > 0)
		{
			for (note in dataNotes)
			{
				if(note != null)
				{
					notes.push(note);
					selectedNotes.push(note);
					note.songData[0] = note.strumTime;
					note.songData[1] = note.chartNoteData;
				}
			}
			notes.sort(PlayState.sortByTime);
		}
		if(dataEvents != null && dataEvents.length > 0)
		{
			for (event in dataEvents)
			{
				if(event != null)
				{
					events.push(event);
					selectedNotes.push(event);
					event.songData[0] = event.strumTime;
				}
			}
			events.sort(PlayState.sortByTime);
		}
		softReloadNotes();
	}

	function actionRemoveNotes(dataNotes:Array<MetaNote>, dataEvents:Array<EventMetaNote>)
	{
		if(dataNotes != null && dataNotes.length > 0)
		{
			for (note in dataNotes)
			{
				if(note != null)
				{
					notes.remove(note);
					selectedNotes.remove(note);

					if(note.exists)
					{
						note.colorTransform.redMultiplier = note.colorTransform.greenMultiplier = note.colorTransform.blueMultiplier = 1;
						if(note.animation.curAnim != null) note.animation.curAnim.curFrame = 0;
					}
				}

			}
		}
		if(dataEvents != null && dataEvents.length > 0)
		{
			for (event in dataEvents)
			{
				if(event != null)
				{
					trace(events.remove(event));
					selectedNotes.remove(event);

					if(event.exists)
					{
						event.colorTransform.redMultiplier = event.colorTransform.greenMultiplier = event.colorTransform.blueMultiplier = 1;
						if(event.animation.curAnim != null) event.animation.curAnim.curFrame = 0;
					}
				}
			}
		}
		softReloadNotes();
	}

	function actionReplaceNotes(oldNote:MetaNote, newNote:MetaNote)
	{
		for (act in undoActions)
		{
			for (field in Reflect.fields(act.data))
			{
				var fld:Array<MetaNote> = cast Reflect.field(act.data, field);
				if(fld != null && fld.length > 0)
					for (num => actNote in fld)
						if(actNote == oldNote)
							fld[num] = newNote;
			}
		}
	}

	// Ported from the old chart editor
	var wavData:Array<Array<Array<Float>>> = [[[0], [0]], [[0], [0]]];
	function updateWaveform() {
		#if (lime_cffi && !macro)
		if(curSec < 0 || curSec >= cachedSectionTimes.length || !waveformEnabled)
		{
			waveformSprite.visible = false;
			return;
		}

		waveformSprite.visible = true;
		waveformSprite.y = gridBg.y;
		var width:Int = Std.int(GRID_SIZE * GRID_COLUMNS_PER_PLAYER * GRID_PLAYERS);
		var height:Int = Std.int(gridBg.height);
		if(Std.int(waveformSprite.height) != height && waveformSprite.pixels != null)
		{
			waveformSprite.pixels.dispose();
			waveformSprite.pixels.disposeImage();
			waveformSprite.makeGraphic(width, height, 0x00FFFFFF);
		}
		waveformSprite.pixels.fillRect(new Rectangle(0, 0, width, height), 0x00FFFFFF);

		wavData[0][0].resize(0);
		wavData[0][1].resize(0);
		wavData[1][0].resize(0);
		wavData[1][1].resize(0);

		var sound:FlxSound = switch(waveformTarget)
		{
			case INST:
				FlxG.sound.music;
			case PLAYER:
				vocals;
			case OPPONENT:
				opponentVocals;
			default:
				null;
		}
		
		@:privateAccess
		if (sound != null && sound._sound != null && sound._sound.__buffer != null)
		{
			var bytes:Bytes = sound._sound.__buffer.data.toBytes();
			wavData = waveformData(sound._sound.__buffer, bytes, cachedSectionTimes[curSec] - Conductor.offset, cachedSectionTimes[curSec+1] - Conductor.offset, 1, wavData, height);
		}

		// Draws
		var gSize:Int = Std.int(GRID_SIZE * 8);
		var hSize:Int = Std.int(gSize / 2);
		var size:Float = 1;

		var leftLength:Int = (wavData[0][0].length > wavData[0][1].length ? wavData[0][0].length : wavData[0][1].length);
		var rightLength:Int = (wavData[1][0].length > wavData[1][1].length ? wavData[1][0].length : wavData[1][1].length);

		var length:Int = leftLength > rightLength ? leftLength : rightLength;

		for (index in 0...length)
		{
			var lmin:Float = FlxMath.bound(((index < wavData[0][0].length && index >= 0) ? wavData[0][0][index] : 0) * (gSize / 1.12), -hSize, hSize) / 2;
			var lmax:Float = FlxMath.bound(((index < wavData[0][1].length && index >= 0) ? wavData[0][1][index] : 0) * (gSize / 1.12), -hSize, hSize) / 2;

			var rmin:Float = FlxMath.bound(((index < wavData[1][0].length && index >= 0) ? wavData[1][0][index] : 0) * (gSize / 1.12), -hSize, hSize) / 2;
			var rmax:Float = FlxMath.bound(((index < wavData[1][1].length && index >= 0) ? wavData[1][1][index] : 0) * (gSize / 1.12), -hSize, hSize) / 2;

			waveformSprite.pixels.fillRect(new Rectangle(hSize - (lmin + rmin), index * size, (lmin + rmin) + (lmax + rmax), size), FlxColor.WHITE);
		}
		#else
		waveformSprite.visible = false;
		#end
	}

	function waveformData(buffer:AudioBuffer, bytes:Bytes, time:Float, endTime:Float, multiply:Float = 1, ?array:Array<Array<Array<Float>>>, ?steps:Float):Array<Array<Array<Float>>>
	{
		#if (lime_cffi && !macro)
		if (buffer == null || buffer.data == null) return [[[0], [0]], [[0], [0]]];

		var khz:Float = (buffer.sampleRate / 1000);
		var channels:Int = buffer.channels;

		var index:Int = Std.int(time * khz);

		var samples:Float = ((endTime - time) * khz);

		if (steps == null) steps = 1280;

		var samplesPerRow:Float = samples / steps;
		var samplesPerRowI:Int = Std.int(samplesPerRow);

		var gotIndex:Int = 0;

		var lmin:Float = 0;
		var lmax:Float = 0;

		var rmin:Float = 0;
		var rmax:Float = 0;

		var rows:Float = 0;

		var simpleSample:Bool = true;//samples > 17200;
		var v1:Bool = false;

		if (array == null) array = [[[0], [0]], [[0], [0]]];

		while (index < (bytes.length - 1)) {
			if (index >= 0) {
				var byte:Int = bytes.getUInt16(index * channels * 2);

				if (byte > 65535 / 2) byte -= 65535;

				var sample:Float = (byte / 65535);

				if (sample > 0)
					if (sample > lmax) lmax = sample;
				else if (sample < 0)
					if (sample < lmin) lmin = sample;

				if (channels >= 2) {
					byte = bytes.getUInt16((index * channels * 2) + 2);

					if (byte > 65535 / 2) byte -= 65535;

					sample = (byte / 65535);

					if (sample > 0) {
						if (sample > rmax) rmax = sample;
					} else if (sample < 0) {
						if (sample < rmin) rmin = sample;
					}
				}
			}

			v1 = samplesPerRowI > 0 ? (index % samplesPerRowI == 0) : false;
			while (simpleSample ? v1 : rows >= samplesPerRow) {
				v1 = false;
				rows -= samplesPerRow;

				gotIndex++;

				var lRMin:Float = Math.abs(lmin) * multiply;
				var lRMax:Float = lmax * multiply;

				var rRMin:Float = Math.abs(rmin) * multiply;
				var rRMax:Float = rmax * multiply;

				if (gotIndex > array[0][0].length) array[0][0].push(lRMin);
					else array[0][0][gotIndex - 1] = array[0][0][gotIndex - 1] + lRMin;

				if (gotIndex > array[0][1].length) array[0][1].push(lRMax);
					else array[0][1][gotIndex - 1] = array[0][1][gotIndex - 1] + lRMax;

				if (channels >= 2)
				{
					if (gotIndex > array[1][0].length) array[1][0].push(rRMin);
						else array[1][0][gotIndex - 1] = array[1][0][gotIndex - 1] + rRMin;

					if (gotIndex > array[1][1].length) array[1][1].push(rRMax);
						else array[1][1][gotIndex - 1] = array[1][1][gotIndex - 1] + rRMax;
				}
				else
				{
					if (gotIndex > array[1][0].length) array[1][0].push(lRMin);
						else array[1][0][gotIndex - 1] = array[1][0][gotIndex - 1] + lRMin;

					if (gotIndex > array[1][1].length) array[1][1].push(lRMax);
						else array[1][1][gotIndex - 1] = array[1][1][gotIndex - 1] + lRMax;
				}

				lmin = 0;
				lmax = 0;

				rmin = 0;
				rmax = 0;
			}

			index++;
			rows++;
			if(gotIndex > steps) break;
		}

		return array;
		#else
		return [[[0], [0]], [[0], [0]]];
		#end
	}
	function convertToOldFormat(song:SwagSong):SwagSong
	{
		// 深拷贝：避免修改 PlayState.SONG 的数据影响编辑器状态
		var oldSong:SwagSong = Reflect.copy(song);
		oldSong.notes = song.notes.copy();
		for (i in 0...oldSong.notes.length)
		{
			var srcSec = song.notes[i];
			var dstSec:SwagSection = Reflect.copy(srcSec);
			dstSec.sectionNotes = srcSec.sectionNotes.copy();
			for (j in 0...dstSec.sectionNotes.length)
				dstSec.sectionNotes[j] = srcSec.sectionNotes[j].copy();
			oldSong.notes[i] = dstSec;
		}
		oldSong.events = song.events.copy();
		for (i in 0...oldSong.events.length)
		{
			oldSong.events[i] = song.events[i].copy();
			// 二级 deep copy 事件子数组
			var evt:Array<Dynamic> = oldSong.events[i];
			if (evt.length > 1 && evt[1] != null)
			{
				evt[1] = evt[1].copy();
				for (j in 0...evt[1].length)
				{
					var sub:Array<Dynamic> = evt[1][j];
					if (sub != null) evt[1][j] = sub.copy();
				}
			}
		}

		// ── 确保旧引擎必需的字段 ──

		// 1. gfVersion 不可为 null（旧引擎 onLoadJson 会检查它）
		if (oldSong.gfVersion == null || oldSong.gfVersion.length == 0)
			oldSong.gfVersion = 'gf';

		// 2. player3 兼容字段：旧引擎在 gfVersion==null 时会回退到 player3
		Reflect.setField(oldSong, 'player3', oldSong.gfVersion);

		// 3. validScore：旧引擎 parseJSONshit() 会设置它，但旧格式需要它存在
		oldSong.validScore = true;

		// 4. 确保 arrowSkin / splashSkin 为字符串（旧格式中它们是必需字段）
		if (oldSong.arrowSkin == null) oldSong.arrowSkin = '';
		if (oldSong.splashSkin == null) oldSong.splashSkin = 'noteSplashes';

		// ── 移除新格式特有的字段（旧引擎不认识它们） ──
		for (field in ['format', 'offset', 'gameOverChar', 'gameOverSound', 'gameOverLoop', 'gameOverEnd', 'disableNoteRGB'])
		{
			if (Reflect.hasField(oldSong, field))
				Reflect.deleteField(oldSong, field);
		}

		// ── 将 psych_v1 格式的 note data 转换为旧格式 ──
		// psych_v1: data 0-3 = 当前活跃方（mustHitSection=true→BF, false→Dad）
		//           data 4-7 = 对方
		// 旧格式:   data 0-3 = 左半（mustHitSection=true→BF, false→Dad）
		//           data 4-7 = 右半（mustHitSection=true→Dad, false→BF）
		// 当 mustHitSection=false 时需要翻转 0-3 ↔ 4-7
		for (sec in oldSong.notes)
		{
			for (note in sec.sectionNotes)
			{
				// 跳过事件 note（data = -1）
				if (note[1] < 0) continue;

				// 转换 note data 布局
				if (!sec.mustHitSection)
				{
					if (note[1] >= 4)
						note[1] -= 4;
					else if (note[1] <= 3)
						note[1] += 4;
				}

				// 转换 noteType：字符串 → 数字索引（旧格式用数字）
				if (note.length > 3 && Std.isOfType(note[3], String) && note[3] != null && note[3].length > 0)
				{
					var typeIndex:Int = Note.defaultNoteTypes.indexOf(note[3]);
					note[3] = (typeIndex >= 0) ? typeIndex : 0;
				}
				else if (note.length <= 3)
				{
					note.push(0); // 补上默认 noteType
				}
				else
				{
					note[3] = 0;
				}
			}
		}

		// ── events 数组 ──
		// 旧 0.6.3 引擎的 SwagSong 原生支持 events 字段，onLoadJson 仅在
		// events==null 时才会从 inline notes 提取。我们直接保留 events 数组即可，
		// 不需要（也不能！）再写回 inline notes，否则 data=-1 的笔记会留在
		// sectionNotes 中，导致旧引擎创建 Note 时 noteData=-1 → colorSwap=null → 崩溃。
		// 若 events 为 null，设空数组以保持旧引擎兼容。
		if (oldSong.events == null)
			oldSong.events = [];

		return oldSong;
	}
	
	function getSectionBeatsForSong(song:SwagSong, section:Int):Float
	{
		var val:Null<Float> = null;
		if(song.notes[section] != null) val = song.notes[section].sectionBeats;
		return val != null ? val : 4;
	}

	// ---- Safe JSON loading with difficulty detection (ported from ChartingState) ----

	function loadJsonWithDifficulty(songLowercase:String):Void
	{
		// Ensure CoolUtil.difficulties matches Difficulty.list for Highscore.formatSong
		if(CoolUtil.difficulties.length < 1 && Difficulty.list.length > 0)
			CoolUtil.difficulties = Difficulty.list.copy();

		var foundDifficulties:Array<{name:String, index:Int}> = [];
		var defaultIndex:Int = 0;

		for(i in 0...Difficulty.list.length)
		{
			var diff:String = Difficulty.list[i];
			var chartName:String = songLowercase + Difficulty.getFilePath(i);

			var exists:Bool = false;
			#if MODS_ALLOWED
			if(FileSystem.exists(Paths.modsJson('$songLowercase/$chartName'))) exists = true;
			else if(FileSystem.exists(Paths.json('$songLowercase/$chartName'))) exists = true;
			#else
			{
				try {
					if(Assets.exists(Paths.json('$songLowercase/$chartName'))) exists = true;
				} catch(e:Dynamic) {}
			}
			#end

			if(exists)
			{
				foundDifficulties.push({name: diff, index: i});
				if(diff == Difficulty.getDefault()) defaultIndex = foundDifficulties.length - 1;
			}
		}

		if(foundDifficulties.length < 1)
		{
			// Try loading without any difficulty suffix
			var exists:Bool = false;
			#if MODS_ALLOWED
			if(FileSystem.exists(Paths.modsJson('$songLowercase/$songLowercase'))) exists = true;
			else if(FileSystem.exists(Paths.json('$songLowercase/$songLowercase'))) exists = true;
			#else
			{
				try {
					if(Assets.exists(Paths.json('$songLowercase/$songLowercase'))) exists = true;
				} catch(e:Dynamic) {}
			}
			#end

			if(exists)
				doLoadJson(songLowercase, -1);
			else
				showOutput('newchartEditor_error_not_valid_chart', true);
			return;
		}

		if(foundDifficulties.length == 1)
		{
			doLoadJson(songLowercase, foundDifficulties[0].index);
			return;
		}

		// Multiple difficulties found — show selection prompt
		var diffLabels:Array<String> = [];
		for(d in foundDifficulties)
			diffLabels.push(d.name);

		var radioGrp:PsychUIRadioGroup = new PsychUIRadioGroup(0, 0, diffLabels, 35, 6, false, 200);
		radioGrp.checked = defaultIndex;

		var itemCount:Int = Std.int(Math.min(diffLabels.length, 6));
		var promptHeight:Float = 100 + itemCount * 35 + 70;
		openSubState(new BasePrompt(420, promptHeight,
			'newchartEditor_select_difficulty',
			function(state:BasePrompt)
			{
				radioGrp.x = state.bg.x + 20;
				radioGrp.y = state.bg.y + 60;
				radioGrp.cameras = state.cameras;
				state.add(radioGrp);

				var btnY:Float = state.bg.y + state.bg.height - 45;
				var confirmBtn:PsychUIButton = new PsychUIButton(0, btnY, Language.get('newchartEditor_load_btn', 'Load'), function()
				{
					state.close();
					doLoadJson(songLowercase, foundDifficulties[radioGrp.checked].index);
				});
				confirmBtn.screenCenter(X);
				confirmBtn.x -= 100;
				confirmBtn.cameras = state.cameras;
				confirmBtn.normalStyle.bgColor = FlxColor.GREEN;
				confirmBtn.normalStyle.textColor = FlxColor.WHITE;
				state.add(confirmBtn);

				var cancelBtn:PsychUIButton = new PsychUIButton(0, btnY, Language.get('newchartEditor_cancel_btn', 'Cancel'), function()
				{
					state.close();
				});
				cancelBtn.screenCenter(X);
				cancelBtn.x += 100;
				cancelBtn.cameras = state.cameras;
				state.add(cancelBtn);
			}
		));
	}

	function doLoadJson(songLowercase:String, diffIndex:Int):Void
	{
		var loadedChart:SwagSong = null;

		if(diffIndex >= 0)
		{
			var chartName:String = songLowercase + Difficulty.getFilePath(diffIndex);
			loadedChart = Song.getChart(chartName, songLowercase);
			if(loadedChart != null && Reflect.hasField(loadedChart, 'song'))
				PlayState.storyDifficulty = diffIndex;
		}
		else
		{
			loadedChart = Song.getChart(songLowercase, songLowercase);
		}

		// Try CNE format detection if normal parse didn't yield a valid chart
		if(loadedChart == null || !Reflect.hasField(loadedChart, 'song'))
		{
			// Attempt to read the raw file and check for CNE format
			var rawJson:String = null;
			#if MODS_ALLOWED
			var moddyFile:String = Paths.modsJson('$songLowercase/$songLowercase');
			if(FileSystem.exists(moddyFile)) rawJson = File.getContent(moddyFile).trim();
			#end
			if(rawJson == null)
			{
				try {
					var path:String = Paths.json('$songLowercase/$songLowercase');
					#if sys
					if(FileSystem.exists(path)) rawJson = File.getContent(path).trim();
					#else
					if(Assets.exists(path)) rawJson = Assets.getText(path).trim();
					#end
				} catch(e:Dynamic) {}
			}

			if(rawJson != null && CneExport.isCneFormat(rawJson))
			{
				loadedChart = CneExport.cneToPsych(rawJson);
				loadedChart.format = "psych_v1_convert";
			}
		}

		if(loadedChart == null || !Reflect.hasField(loadedChart, 'song'))
		{
			showOutput('newchartEditor_error_not_valid_chart', true);
			return;
		}

		loadChart(loadedChart);
		Song.chartPath = songLowercase;
		reloadNotesDropdowns();
		prepareReload();
		showOutput('newchartEditor_chart_reloaded_old', false, [songLowercase]);
	}

}
