package editors;

#if cpp
import Discord.DiscordClient;
#end

import flixel.FlxObject;
import flixel.FlxCamera;
import flixel.addons.display.FlxGridOverlay;
import flixel.util.FlxColor;
import flixel.group.FlxSpriteGroup;
import flash.net.FileFilter;
import openfl.display.BitmapData;
import haxe.Json;
import Character;
import backend.ui.*;
import editors.content.EditorsText;
import editors.content.Prompt;
import editors.content.FileDialogHandler;
import editors.content.PsychJsonPrinter;
import states.TitleState;
import BGSprite;

#if MODS_ALLOWED
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

typedef StageSpriteData = {
	var tag:String; var image:String; var x:Float; var y:Float;
	var scaleX:Float; var scaleY:Float; var scrollX:Float; var scrollY:Float;
	var alpha:Float; var animated:Bool; var animPrefix:String;
	var animFramerate:Int; var animLooped:Bool; var antialiasing:Bool;
	var flipX:Bool; var flipY:Bool; var front:Bool;
}

class BackgroundEditorState extends MusicBeatState implements PsychUIEventHandler.PsychUIEvent
{
	/** Unsaved changes flag — central tracker + window title support. */
	public static var staticUnsavedChanges:Bool = false;
	public var unsavedChanges(get, set):Bool;
	function get_unsavedChanges():Bool return staticUnsavedChanges;
	function set_unsavedChanges(v:Bool):Bool
	{
		staticUnsavedChanges = v;
		backend.UnsavedChangesTracker.hasUnsavedChanges = v;
		if(v) backend.UnsavedChangesTracker.currentEditorState = this;
		if(unsavedLabel != null) unsavedLabel.visible = v;
		return staticUnsavedChanges;
	}

	var stageDirectory:String = ''; var currentStageName:String = 'stage'; var defaultZoom:Float = 0.9; var isPixelStage:Bool = false;
	var hideGF:Bool = false; var cameraSpeed:Float = 1.0;
	var bfX:Float = 770; var bfY:Float = 100;
	var dadX:Float = 100; var dadY:Float = 100;
	var gfX:Float = 400; var gfY:Float = 130;
	var camBfX:Float = 0; var camBfY:Float = 0;
	var camDadX:Float = 0; var camDadY:Float = 0;
	var camGfX:Float = 0; var camGfY:Float = 0;

	var sprites:Array<StageSpriteData> = []; var spritePreviews:Array<FlxSprite> = [];
	var selectedSprite:Int = -1;

	var canvasGroup:FlxTypedGroup<FlxSprite>; var gridBG:FlxSprite;
	var camEditor:FlxCamera; var camHUD:FlxCamera; var camMenu:FlxCamera; var camFollow:FlxObject;
	var selectionBorder:FlxSprite; var resizeHandles:Array<FlxSprite> = [];

	var charDad:Character; var charBF:Character; var charGF:Character;
	var charDadLabel:EditorsText; var charBFLabel:EditorsText; var charGFLabel:EditorsText;
	var charBorder:FlxSprite; var selectedChar:String = '';

	// ---- Direct-manipulation state (world-space, rewritten) ----
	var dragging:Bool = false;
	var dragKind:String = '';            // 'sprite' | 'char'
	var dragSpriteIndex:Int = -1;
	var dragCharKey:String = '';
	var dragStartWorldX:Float = 0;
	var dragStartWorldY:Float = 0;
	var dragStartObjX:Float = 0;
	var dragStartObjY:Float = 0;
	var resizing:Bool = false;
	var resizeCorner:Int = -1;
	var resizeStartScaleX:Float = 1;
	var resizeStartScaleY:Float = 1;
	var resizeStartX:Float = 0;
	var resizeStartY:Float = 0;
	var resizeStartWorldX:Float = 0;
	var resizeStartWorldY:Float = 0;
	var resizeFrameW:Float = 1;
	var resizeFrameH:Float = 1;

	var UI_box:PsychUIBox;
	var stageDropDown:PsychUIDropDownMenu; var spriteDropDown:PsychUIDropDownMenu;
	var tagInput:PsychUIInputText; var imageInput:PsychUIInputText;
	var xStepper:PsychUINumericStepper; var yStepper:PsychUINumericStepper;
	var scaleXStepper:PsychUINumericStepper; var scaleYStepper:PsychUINumericStepper;
	var scrollXStepper:PsychUINumericStepper; var scrollYStepper:PsychUINumericStepper;
	var alphaStepper:PsychUINumericStepper;
	var animatedCheck:PsychUICheckBox; var flipXCheck:PsychUICheckBox;
	var flipYCheck:PsychUICheckBox; var antialiasCheck:PsychUICheckBox;
	var frontCheck:PsychUICheckBox;
	var animPrefixInput:PsychUIInputText; var animFPStepper:PsychUINumericStepper;
	var animLoopCheck:PsychUICheckBox;

	var zoomStepper:PsychUINumericStepper; var pixelStageCheck:PsychUICheckBox;
	var hideGFCheck:PsychUICheckBox; var camSpeedStepper:PsychUINumericStepper;
	var camBfXStepper:PsychUINumericStepper; var camBfYStepper:PsychUINumericStepper;
	var camDadXStepper:PsychUINumericStepper;	var camDadYStepper:PsychUINumericStepper;
	var camGfXStepper:PsychUINumericStepper; var camGfYStepper:PsychUINumericStepper;
	var directoryInput:PsychUIInputText;

	var bfXStepper:PsychUINumericStepper; var bfYStepper:PsychUINumericStepper;
	var dadXStepper:PsychUINumericStepper; var dadYStepper:PsychUINumericStepper;
	var gfXStepper:PsychUINumericStepper; var gfYStepper:PsychUINumericStepper;

	var outputMsg:EditorsText; var outputTimer = 0.0;
	var _file:FileDialogHandler;

	// ---- Performance caches ----
	var _lastSelW:Float = -1; var _lastSelH:Float = -1;

	// ---- Mode Toggle ----
	var editMode:String = 'sprites'; // 'sprites' or 'characters'
	var modeToggleBtn:PsychUIButton;
	var modeBg:FlxSprite;

	// ---- Redesigned chrome ----
	var headerBg:FlxSprite;
	var objectPanelBg:FlxSprite;
	var bottomBarBg:FlxSprite;
	var stageNameText:EditorsText;
	var unsavedLabel:EditorsText;
	var objectListGroup:FlxTypedGroup<BgObjectListRow>;
	var objectListRows:Array<BgObjectListRow> = [];
	var objectListKinds:Array<String> = [];
	var objectListScroll:Int = 0;
	var objectListX:Float = 0;
	var objectListY:Float = 0;
	var objectListW:Float = 0;
	var objectListH:Float = 0;

	override function create() {
		#if cpp DiscordClient.changePresence("Background Editor", "Editing a Stage"); #end

		camEditor = new FlxCamera();
		camHUD = new FlxCamera(); camHUD.bgColor.alpha = 0;
		camMenu = new FlxCamera(); camMenu.bgColor.alpha = 0;
		FlxG.cameras.reset(camEditor);
		FlxG.cameras.add(camHUD, false); FlxG.cameras.add(camMenu, false);
		FlxG.cameras.setDefaultDrawTarget(camEditor, true);

		canvasGroup = new FlxTypedGroup<FlxSprite>(); add(canvasGroup);
		gridBG = FlxGridOverlay.create(50, 50, 3000, 3000, true, 0x33FFFFFF, 0x15FFFFFF);
		gridBG.setPosition(-1500, -1500); canvasGroup.add(gridBG);

		charBorder = new FlxSprite().makeGraphic(1, 1, FlxColor.TRANSPARENT);
		charBorder.cameras = [camEditor]; charBorder.visible = false; canvasGroup.add(charBorder);

		selectionBorder = new FlxSprite().makeGraphic(1, 1, FlxColor.TRANSPARENT);
		selectionBorder.cameras = [camEditor]; canvasGroup.add(selectionBorder);
		for (i in 0...4) { var h = new FlxSprite().makeGraphic(12,12,FlxColor.WHITE); h.cameras=[camEditor]; h.visible=false; resizeHandles.push(h); canvasGroup.add(h); }

		loadCharacterPreviews(); reorderCanvasLayers();

		// ---- Redesigned chrome: header, object explorer, inspector ----
		addHeader();
		addObjectListPanel();

		var panelX = FlxG.width - 370;
		var panelY = 54;
		var panelW = 360;
		var panelH = FlxG.height - panelY - 32 - 8;
		UI_box = new PsychUIBox(panelX, panelY, panelW, panelH, [
			T('sprites','Sprites'),
			T('characters','Characters'),
			T('stage','Stage')
		]);
		UI_box.cameras = [camMenu]; UI_box.scrollFactor.set(); add(UI_box);
		for (tab in UI_box.tabs) tab.text.font = 'assets/fonts/editors.ttf';

		addSpritesUI();
		addCharactersUI();
		addStageUI();
		UI_box.selectedIndex = (editMode == 'sprites') ? 0 : 1;

		addBottomBar();
		updateAnimatedFields();

		camFollow = new FlxObject(400, 200, 2, 2); camFollow.screenCenter(); add(camFollow);
		FlxG.camera.follow(camFollow);

		FlxG.mouse.visible = true;
		_file = new FileDialogHandler();
		super.create();

		// ---- Default: load "stage" scene ----
		refreshStageDropdown();
		loadStageByName('stage');
		rebuildObjectList();
	}

	// ---- Redesigned chrome helpers ----
	function addHeader()
	{
		headerBg = new FlxSprite(0, 0).makeGraphic(Std.int(FlxG.width), 46, FlxColor.BLACK);
		headerBg.scrollFactor.set(); headerBg.alpha = 0.9; headerBg.cameras = [camHUD]; add(headerBg);

		var backBtn = new PsychUIButton(10, 9, T('back','◀ Back'), function() confirmExitBackground(), 84, 28);
		backBtn.cameras = [camMenu]; backBtn.scrollFactor.set(); add(backBtn);

		var title = new EditorsText(100, 12, FlxG.width - 200, T('bg_title','Background Editor'), 18);
		title.setFormat(Paths.font("editors.ttf"), 18, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		title.borderSize = 2; title.scrollFactor.set(); title.cameras = [camHUD]; add(title);

		stageNameText = new EditorsText(0, 31, FlxG.width, '', 10);
		stageNameText.setFormat(Paths.font("editors.ttf"), 10, 0xFF9AA0B4, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		stageNameText.borderSize = 1; stageNameText.scrollFactor.set(); stageNameText.cameras = [camHUD]; add(stageNameText);

		unsavedLabel = new EditorsText(FlxG.width / 2 + 130, 13, 0, T('unsaved_badge','● Unsaved'), 11);
		unsavedLabel.color = 0xFFFFC46B;
		unsavedLabel.scrollFactor.set();
		unsavedLabel.cameras = [camHUD];
		unsavedLabel.visible = false;
		add(unsavedLabel);

		modeToggleBtn = new PsychUIButton(FlxG.width - 110, 9, getModeBtnLabel(), function() switchMode(), 96, 28);
		modeToggleBtn.cameras = [camMenu]; modeToggleBtn.scrollFactor.set(); add(modeToggleBtn);
	}

	function addObjectListPanel()
	{
		var x = 10.0;
		var y = 54.0;
		var w = 270.0;
		var h = FlxG.height - y - 32 - 8;
		objectPanelBg = PsychUIHelper.createRoundedRectSprite(Std.int(w), Std.int(h), 12);
		objectPanelBg.setPosition(x, y);
		objectPanelBg.color = 0xFF171922;
		objectPanelBg.alpha = 0.8;
		objectPanelBg.scrollFactor.set();
		objectPanelBg.cameras = [camMenu];
		add(objectPanelBg);

		var title = new EditorsText(x + 14, y + 10, 0, T('object_explorer','Objects'), 15);
		title.scrollFactor.set(); title.cameras = [camMenu]; add(title);

		var addBtn = new PsychUIButton(x + 14, y + 34, T('add_sprite_short','+ Sprite'), function() addNewSprite(), 82, 24);
		addBtn.cameras = [camMenu]; addBtn.scrollFactor.set(); addBtn.smoothAnimations = false; add(addBtn);

		var delBtn = new PsychUIButton(x + 102, y + 34, T('delete_short','Delete'), function() removeSelectedSprite(), 78, 24);
		delBtn.cameras = [camMenu]; delBtn.scrollFactor.set(); delBtn.smoothAnimations = false; add(delBtn);

		var upBtn = new PsychUIButton(x + 186, y + 34, '▲', function() moveSpriteLayer(-1), 30, 24);
		upBtn.cameras = [camMenu]; upBtn.scrollFactor.set(); upBtn.smoothAnimations = false; add(upBtn);

		var downBtn = new PsychUIButton(x + 220, y + 34, '▼', function() moveSpriteLayer(1), 30, 24);
		downBtn.cameras = [camMenu]; downBtn.scrollFactor.set(); downBtn.smoothAnimations = false; add(downBtn);

		objectListX = x + 12;
		objectListY = y + 66;
		objectListW = w - 24;
		objectListH = h - 78;

		objectListGroup = new FlxTypedGroup<BgObjectListRow>();
		objectListGroup.cameras = [camMenu];
		add(objectListGroup);
	}

	function addBottomBar()
	{
		bottomBarBg = new FlxSprite(0, FlxG.height - 32).makeGraphic(Std.int(FlxG.width), 32, FlxColor.BLACK);
		bottomBarBg.scrollFactor.set(); bottomBarBg.alpha = 0.88; bottomBarBg.cameras = [camHUD]; add(bottomBarBg);

		var tip = new EditorsText(10, FlxG.height - 24, 0,
			T('tip1','E/Q/Wheel-Zoom | R-Reset | JKLI/Arrows-Pan | F-Center | DEL-Remove'), 9);
		tip.color = 0xFF8A92A6; tip.scrollFactor.set(); tip.cameras = [camHUD]; add(tip);

		outputMsg = new EditorsText(0, FlxG.height - 24, FlxG.width - 410, '', 10);
		outputMsg.setFormat(Paths.font("editors.ttf"), 10, FlxColor.YELLOW, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		outputMsg.borderSize = 1; outputMsg.scrollFactor.set(); outputMsg.cameras = [camHUD]; outputMsg.visible = false; add(outputMsg);

		var bx = FlxG.width - 370 + 10;
		var btnW = 68;
		var by = FlxG.height - 32 + 5;
		addBB(bx, by, 'save_json', 'Save JSON', function() saveStageJSON(), btnW); bx += btnW + 4;
		addBB(bx, by, 'save_lua', 'Save LUA', function() saveAsLua(), btnW); bx += btnW + 4;
		addBB(bx, by, 'save_hscript', 'HSCRIPT', function() {
			openSubState(new Prompt(T('hscript_warn','Saving as HSCRIPT can only be used with Psych Engine 0.7.1h that supports HSCRIPT loading. Continue?'), function() saveAsHscript()));
		}, btnW); bx += btnW + 4;
		addBB(bx, by, 'clear_all', 'Clear', function() {
			openSubState(new Prompt(T('clear_confirm','Clear all sprites and reset stage?'), function() {
				sprites = []; clearSpritePreviews(); selectedSprite = -1; selectedChar = '';
				rebuildSpriteDropdown(); updateSelectionVisuals(); updateCharBorder(); reorderCanvasLayers(); markUnsaved();
			}));
		}, btnW);
	}

	function switchMode()
	{
		editMode = (editMode == 'sprites') ? 'characters' : 'sprites';
		modeToggleBtn.label = getModeBtnLabel();
		selectedSprite = -1;
		selectedChar = '';
		updateSelectionVisuals();
		updateCharBorder();
		UI_box.selectedIndex = (editMode == 'sprites') ? 0 : 1;
		rebuildObjectList();
		show(T('mode_switched','Switched to ' + editMode + ' mode'));
	}

	function confirmExitBackground()
	{
		if(unsavedChanges)
		{
			openSubState(new Prompt(T('unsaved_changes','You have unsaved changes. Exit anyway?'), function() {
				unsavedChanges = false;
				MusicBeatState.switchState(new editors.MasterEditorMenu());
				FlxG.mouse.visible = false;
				FlxG.sound.playMusic(Paths.music('freakyMenu'));
			}));
		}
		else
		{
			unsavedChanges = false;
			MusicBeatState.switchState(new editors.MasterEditorMenu());
			FlxG.mouse.visible = false;
			FlxG.sound.playMusic(Paths.music('freakyMenu'));
		}
	}

	function rebuildObjectList()
	{
		if(objectListGroup == null) return;
		objectListGroup.clear();
		for(row in objectListRows) if(row != null) row.destroy();
		objectListRows = [];
		objectListKinds = [];

		for(i in 0...sprites.length)
		{
			var s = sprites[i];
			var kind = 'sprite:' + i;
			objectListKinds.push(kind);
			var row = new BgObjectListRow(0, 0, Std.int(objectListW), 34);
			row.cameras = [camMenu];
			row.setInfo(s.tag, '[' + (s.front ? 'F' : 'B') + '] ' + (s.image == null || s.image == '' ? 'empty' : s.image), (editMode == 'sprites' && selectedSprite == i));
			objectListGroup.add(row);
			objectListRows.push(row);
		}

		// Character roles
		var charDefs:Array<{key:String, name:String, sub:String}> = [
			{key:'dad', name:'Opponent', sub:'X' + dadX + '  Y' + dadY},
			{key:'bf', name:'Boyfriend', sub:'X' + bfX + '  Y' + bfY},
			{key:'gf', name:'Girlfriend', sub:'X' + gfX + '  Y' + gfY}
		];
		for(c in charDefs)
		{
			objectListKinds.push('char:' + c.key);
			var row = new BgObjectListRow(0, 0, Std.int(objectListW), 34);
			row.cameras = [camMenu];
			var isSel = (editMode == 'characters' && selectedChar == c.key);
			row.setInfo(c.name, c.sub, isSel);
			objectListGroup.add(row);
			objectListRows.push(row);
		}

		layoutObjectList();
	}

	function layoutObjectList()
	{
		if(objectListRows.length == 0) return;
		var rowH:Float = 34;
		var gap:Float = 4;
		var visibleCount = Math.floor((objectListH + gap) / (rowH + gap));
		if(visibleCount < 1) visibleCount = 1;

		// Keep selected item visible
		var selectedRow:Int = -1;
		if(editMode == 'sprites' && selectedSprite >= 0) selectedRow = selectedSprite;
		else if(editMode == 'characters' && selectedChar != '')
		{
			for(i in 0...objectListKinds.length)
				if(objectListKinds[i] == 'char:' + selectedChar) { selectedRow = i; break; }
		}

		if(selectedRow >= 0)
		{
			if(selectedRow < objectListScroll) objectListScroll = selectedRow;
			if(selectedRow >= objectListScroll + visibleCount) objectListScroll = selectedRow - visibleCount + 1;
		}
		if(objectListScroll + visibleCount > objectListRows.length)
			objectListScroll = objectListRows.length - visibleCount;
		if(objectListScroll < 0) objectListScroll = 0;

		for(i in 0...objectListRows.length)
		{
			var vis = i >= objectListScroll && i < objectListScroll + visibleCount;
			objectListRows[i].visible = vis;
			objectListRows[i].active = vis;
			if(vis)
				objectListRows[i].setPosition(objectListX, objectListY + (i - objectListScroll) * (rowH + gap));
		}
	}

	function handleObjectListClick()
	{
		var mx = FlxG.mouse.screenX;
		var my = FlxG.mouse.screenY;
		if(mx < objectListX || mx > objectListX + objectListW || my < objectListY || my > objectListY + objectListH) return;

		for(i in 0...objectListRows.length)
		{
			var row = objectListRows[i];
			if(!row.visible) continue;
			if(mx >= row.x && mx <= row.x + row.bg.width && my >= row.y && my <= row.y + row.bg.height)
			{
				var kind = objectListKinds[i];
				if(kind.startsWith('sprite:'))
				{
					var idx = Std.parseInt(kind.substr(7));
					editMode = 'sprites';
					UI_box.selectedIndex = 0;
					modeToggleBtn.label = getModeBtnLabel();
					selectSprite(idx);
				}
				else if(kind.startsWith('char:'))
				{
					var key = kind.substr(5);
					editMode = 'characters';
					UI_box.selectedIndex = 1;
					modeToggleBtn.label = getModeBtnLabel();
					selectedSprite = -1;
					selectedChar = key;
					updateSelectionVisuals();
					updateCharBorder();
					disableSpriteUI();
					updateCharacterUIFromData();
					rebuildObjectList();
				}
				return;
			}
		}
	}

	function updateStageNameText()
	{
		if(stageNameText != null)
			stageNameText.text = T('current_stage','Stage: ') + (Paths.currentModDirectory.length > 0 ? '[' + Paths.currentModDirectory + '] ' : '') + currentStageName;
	}

	// ---- helpers ----
	function T(k:String, fb:String):String return Language.get(k, fb);
	function L(g:FlxSpriteGroup, x:Float, y:Float, k:String, fb:String):Void { var l=new EditorsText(x,y,0,T(k,fb),12); l.cameras=[camMenu]; l.scrollFactor.set(); g.add(l); }
	function B(g:FlxSpriteGroup, x:Float, y:Float, k:String, fb:String, cb:Void->Void, w=60):PsychUIButton { var b=new PsychUIButton(x,y,T(k,fb),cb,w,20); g.add(b); return b; }
	function N(v:Float):Float return Math.round(v);
	function chk(g:FlxSpriteGroup, x:Float, y:Float, k:String, fb:String, cb:Bool->Void):PsychUICheckBox { var c=new PsychUICheckBox(x,y,T(k,fb),60,null); c.onClick=function() cb(c.checked); g.add(c); return c; }
	function chkCompact(g:FlxSpriteGroup, x:Float, y:Float, lbl:String, cb:Bool->Void):PsychUICheckBox { var c=new PsychUICheckBox(x,y,lbl,80,null); c.onClick=function() cb(c.checked); g.add(c); return c; }
	function stp(g:FlxSpriteGroup, x:Float, y:Float, step:Float, def:Float, min:Float, max:Float, cb:Float->Void, ?dec:Int = 0):PsychUINumericStepper { var s=new PsychUINumericStepper(x,y,step,def,min,max,dec,80); s.textObj.font='assets/fonts/editors.ttf'; s.onValueChange=function() cb(s.value); g.add(s); return s; }
	function show(msg:String, err=false) { outputMsg.text=msg; outputMsg.color=err?FlxColor.RED:FlxColor.YELLOW; outputMsg.visible=true; outputTimer=3; }
	function getModeBtnLabel():String { return (editMode=='sprites') ? T('mode_sprites','[Sprites]') : T('mode_chars','[Characters]'); }
	function isSpriteMode():Bool { return editMode == 'sprites'; }
	function isCharMode():Bool { return editMode == 'characters'; }

	// ---- Characters ----
	function loadCharacterPreviews() {
		try { charDad = newCh(dadX,dadY,'dad',false,0xFF9999DD); } catch(e){}
		try { charBF = newCh(bfX,bfY,'bf',true,0xFFDD9999); } catch(e){}
		try { charGF = newCh(gfX,gfY,'gf',false,0xFF99DD99); } catch(e){}
		charDadLabel = mkLbl('DAD',FlxColor.CYAN); charBFLabel = mkLbl('BF',FlxColor.RED); charGFLabel = mkLbl('GF',FlxColor.LIME);
		updateCharPositions();
	}
	function newCh(x:Float,y:Float,n:String,p:Bool,co:Int):Character { var c=new Character(x,y,n,p); c.debugMode=true; c.alpha=0.55; c.color=co; c.cameras=[camEditor]; return c; }
	function mkLbl(t:String,c:FlxColor):EditorsText { var l=new EditorsText(0,0,0,t,12,false); l.setFormat(Paths.font("editors.ttf"),12,c,CENTER,FlxTextBorderStyle.OUTLINE,FlxColor.BLACK); l.borderSize=1; l.cameras=[camEditor]; return l; }
	function charScreenPos(ch:Character, sx:Float, sy:Float):{x:Float,y:Float}{return{x:sx+(ch!=null?ch.positionArray[0]:0),y:sy+(ch!=null?ch.positionArray[1]:0)};}
	var _lastCharW:Float = -1; var _lastCharH:Float = -1;
	function updateCharPositions(){
		if(charDad == null) return; // all or nothing – if dad failed, skip everything
		var dp = charScreenPos(charDad, dadX, dadY);
		charDad.setPosition(dp.x, dp.y);
		var bp = charScreenPos(charBF, bfX, bfY);
		charBF.setPosition(bp.x, bp.y);
		var gp = charScreenPos(charGF, gfX, gfY);
		charGF.setPosition(gp.x, gp.y);

		// Labels follow the CHARACTER's visual position (including positionArray)
		charDadLabel.setPosition(dp.x - charDadLabel.width / 2, dp.y - 50);
		charBFLabel.setPosition(bp.x - charBFLabel.width / 2, bp.y - 50);
		charGFLabel.setPosition(gp.x - charGFLabel.width / 2, gp.y - 50);
		charGF.visible = !hideGF;
		charGFLabel.visible = !hideGF;
		updateCharBorder();
	}
	function updateCharBorder(){
		if(selectedChar == '' || charBorder == null) { if(charBorder != null) charBorder.visible = false; return; }
		var ch = switch(selectedChar) { case 'dad': charDad; case 'bf': charBF; case 'gf': charGF; default: null; }
		if(ch == null || ch.graphic == null || ch.frameWidth <= 0 || ch.frameHeight <= 0) { charBorder.visible = false; return; }
		// Round dimensions to avoid stutter from sub-pixel frame size changes during animation
		var cw = Math.round(ch.frameWidth);
		var chh = Math.round(ch.frameHeight);
		if(cw != _lastCharW || chh != _lastCharH) {
			_lastCharW = cw;
			_lastCharH = chh;
			dashRect(charBorder, ch.frameWidth, ch.frameHeight);
		}
		charBorder.setPosition(ch.x, ch.y);
		charBorder.visible = true;
	}

	// ---- Layer Order ----
	function reorderCanvasLayers() { var all=canvasGroup.members.copy();for(m in all)canvasGroup.remove(m); canvasGroup.add(gridBG); for(i in 0...sprites.length)if(!sprites[i].front&&spritePreviews[i]!=null)canvasGroup.add(spritePreviews[i]); if(charGF!=null)canvasGroup.add(charGF);if(charGFLabel!=null)canvasGroup.add(charGFLabel); if(charDad!=null)canvasGroup.add(charDad);if(charDadLabel!=null)canvasGroup.add(charDadLabel); if(charBF!=null)canvasGroup.add(charBF);if(charBFLabel!=null)canvasGroup.add(charBFLabel); for(i in 0...sprites.length)if(sprites[i].front&&spritePreviews[i]!=null)canvasGroup.add(spritePreviews[i]); if(charBorder!=null)canvasGroup.add(charBorder);if(selectionBorder!=null)canvasGroup.add(selectionBorder);for(h in resizeHandles)if(h!=null)canvasGroup.add(h); }

	function stageFileName(f:String):String{var l=f.toLowerCase();for(ext in['.json','.lua','.hx','.hscript','.hsc','.hxs','.hxml']){if(l.endsWith(ext))return f.substr(0,f.length-ext.length);}return'';}

	// ---- Stage Loading (PlayState-style + mod scripts) ----
	function refreshStageDropdown() {
		if(stageDropDown==null)return;
		var stages:Array<String>=[T('select_stage','-- Select Stage --')]; var seen=new Map<String,Bool>();
		#if MODS_ALLOWED
		// Scan ALL mod subdirectories directly (not just enabled/global mods)
		var modsRoot=Sys.getCwd()+'mods/';if(FileSystem.exists(modsRoot)){for(modFolder in FileSystem.readDirectory(modsRoot)){var md=modsRoot+modFolder;if(!FileSystem.isDirectory(md))continue;var d=md+'/stages/';if(!FileSystem.exists(d))continue;for(f in FileSystem.readDirectory(d)){var n=stageFileName(f);if(n!=''&&!seen.exists(n)){seen.set(n,true);stages.push(n);}}}}
		// Preload stages
		var pre=Paths.getPreloadPath('stages/');if(FileSystem.exists(pre)){for(f in FileSystem.readDirectory(pre)){var n=stageFileName(f);if(n!=''&&!seen.exists(n)){seen.set(n,true);stages.push(n);}}}
		#else
		for(s in['stage','spooky','philly','limo','mall','mallEvil','school','schoolEvil','tank'])stages.push(s);
		#end
		stageDropDown.list=stages;
		stageDropDown.maxItems=12;
	}
	function loadStageByName(name:String) {
		currentStageName = name;
		sprites=[];clearSpritePreviews();selectedSprite=-1;selectedChar='';updateCharBorder();
		// Find and set the mod directory that contains this stage
		Paths.currentModDirectory='';Paths.setCurrentLevel('shared');
		#if MODS_ALLOWED
		var modsRoot=Sys.getCwd()+'mods/';if(FileSystem.exists(modsRoot)){for(modFolder in FileSystem.readDirectory(modsRoot)){var md=modsRoot+modFolder;if(!FileSystem.isDirectory(md))continue;var d=md+'/stages/';if(!FileSystem.exists(d))continue;for(f in FileSystem.readDirectory(d)){if(stageFileName(f)==name){Paths.currentModDirectory=modFolder;break;}}if(Paths.currentModDirectory!='')break;}}
		#end
		var loaded=false;
		// STEP 1: Load stage JSON FIRST to set directory (critical for Paths to find assets)
		try{var raw=tryLoadFile('stages/'+name+'.json');if(raw!=null){var json=Json.parse(raw);if(Reflect.hasField(json,'directory')){stageDirectory=json.directory;if(stageDirectory!='')Paths.setCurrentLevel(stageDirectory);}else Paths.setCurrentLevel('shared');if(Reflect.hasField(json,'defaultZoom'))defaultZoom=json.defaultZoom;if(Reflect.hasField(json,'isPixelStage'))isPixelStage=json.isPixelStage;if(Reflect.hasField(json,'boyfriend')){bfX=N(json.boyfriend[0]);bfY=N(json.boyfriend[1]);}if(Reflect.hasField(json,'girlfriend')){gfX=N(json.girlfriend[0]);gfY=N(json.girlfriend[1]);}if(Reflect.hasField(json,'opponent')){dadX=N(json.opponent[0]);dadY=N(json.opponent[1]);}if(Reflect.hasField(json,'hide_girlfriend'))hideGF=json.hide_girlfriend;if(Reflect.hasField(json,'camera_boyfriend')){camBfX=json.camera_boyfriend[0];camBfY=json.camera_boyfriend[1];}if(Reflect.hasField(json,'camera_opponent')){camDadX=json.camera_opponent[0];camDadY=json.camera_opponent[1];}if(Reflect.hasField(json,'camera_girlfriend')){camGfX=json.camera_girlfriend[0];camGfY=json.camera_girlfriend[1];}if(Reflect.hasField(json,'camera_speed'))cameraSpeed=json.camera_speed;loaded=true;}}catch(e){}
		// STEP 2: Create built-in stage sprites (Paths now uses correct directory+mod)
		loaded = loadBuiltInStageSprites(name) || loaded;
		// STEP 3: Try loading stage script for mod stages
		try{for(ext in['.lua','.hx','.hscript','.hsc','.hxs']){var script=tryLoadFile('stages/'+name+ext);if(script!=null){parseStageScript(script);loaded=true;break;}}}catch(e){}
		// STEP 4: Rebuild previews for all sprites
		for(j in 0...sprites.length) createSpritePreview(j);
		reorderCanvasLayers();rebuildSpriteDropdown();updateCharPositions();updateStageUIFromData();updateSelectionVisuals();
		unsavedChanges=false;updateCharBorder();updateStageNameText();rebuildObjectList();show(T('stage_loaded','Loaded: ')+name,!loaded);
	}
	function tryLoadFile(path:String):String{
		#if MODS_ALLOWED
		var p=Paths.modFolders(path);if(FileSystem.exists(p))return File.getContent(p);return null;
		#else
		var pre=Paths.getPreloadPath(path);if(openfl.Assets.exists(pre))return openfl.Assets.getText(pre);return null;
		#end
	}

	function loadBuiltInStageSprites(name:String):Bool {
		// Reproduce PlayState's switch(curStage) sprite creation as StageSpriteData entries
		switch(name) {
			case 'stage':
				addBGSprite('stageback', 'stageback', -600, -200, 0.9, 0.9, null);
				addBGSprite('stagefront', 'stagefront', -650, 600, 0.9, 0.9, null);
				addBGSprite('stagecurtains', 'stagecurtains', -500, -300, 1.3, 1.3, null);
				return true;
			case 'spooky':
				addBGSprite('halloween_bg', 'halloween_bg', -200, -100, 1, 1, ['halloweem bg0','halloweem bg lightning strike']);
				return true;
			case 'philly':
				addBGSprite('philly_sky', 'philly/sky', -100, 0, 0.1, 0.1, null);
				addBGSprite('philly_city', 'philly/city', -10, 0, 0.3, 0.3, null);
				addBGSprite('philly_window', 'philly/window', -10, 0, 0.3, 0.3, null);
				addBGSprite('philly_behindTrain', 'philly/behindTrain', -40, 50, 1, 1, null);
				addBGSprite('philly_train', 'philly/train', 2000, 360, 1, 1, null);
				addBGSprite('philly_street', 'philly/street', -40, 50, 1, 1, null);
				return true;
			case 'limo':
				addBGSprite('limo_sunset', 'limo/limoSunset', -120, -50, 0.1, 0.1, null);
				addBGSprite('limo_bgLimo', 'limo/bgLimo', -150, 480, 0.4, 0.4, ['background limo pink']);
				addBGSprite('limo_drive', 'limo/limoDrive', -120, 550, 1, 1, ['Limo stage']);
				addBGSprite('limo_fastCar', 'limo/fastCarLol', -300, 160, 1, 1, null);
				return true;
			case 'mall':
				addBGSprite('mall_walls', 'christmas/bgWalls', -1000, -500, 0.2, 0.2, null);
				addBGSprite('mall_tree', 'christmas/christmasTree', 370, -250, 0.40, 0.40, null);
				addBGSprite('mall_bottomBop', 'christmas/bottomBop', -300, 140, 0.9, 0.9, ['Bottom Level Boppers Idle']);
				addBGSprite('mall_snow', 'christmas/fgSnow', -600, 700, 1, 1, null);
				addBGSprite('mall_santa', 'christmas/santa', -840, 150, 1, 1, ['santa idle in fear']);
				return true;
			case 'mallEvil':
				addBGSprite('mallEvil_bg', 'christmas/evilBG', -400, -500, 0.2, 0.2, null);
				addBGSprite('mallEvil_tree', 'christmas/evilTree', 300, -300, 0.2, 0.2, null);
				addBGSprite('mallEvil_snow', 'christmas/evilSnow', -200, 700, 1, 1, null);
				return true;
			case 'school':
				addBGSprite('school_sky', 'weeb/weebSky', 0, 0, 0.1, 0.1, null);
				addBGSprite('school_school', 'weeb/weebSchool', -200, 0, 0.6, 0.90, null);
				addBGSprite('school_street', 'weeb/weebStreet', -200, 0, 0.95, 0.95, null);
				addBGSprite('school_trees', 'weeb/weebTrees', -580, -800, 0.85, 0.85, null);
				return true;
			case 'schoolEvil':
				addBGSprite('schoolEvil_bg', 'weeb/animatedEvilSchool', 400, 200, 0.8, 0.9, ['background 2']);
				return true;
			case 'tank':
				addBGSprite('tank_sky', 'tankSky', -400, -400, 0, 0, null);
				addBGSprite('tank_mountains', 'tankMountains', -300, -20, 0.2, 0.2, null);
				addBGSprite('tank_buildings', 'tankBuildings', -200, 0, 0.3, 0.3, null);
				addBGSprite('tank_ruins', 'tankRuins', -200, 0, 0.35, 0.35, null);
				addBGSprite('tank_watchtower', 'tankWatchtower', 100, 50, 0.5, 0.5, ['watchtower gradient color']);
				addBGSprite('tank_rolling', 'tankRolling', 300, 300, 0.5, 0.5, ['BG tank w lighting']);
				addBGSprite('tank_ground', 'tankGround', -420, -150, 1, 1, null);
				addBGSprite('tank0', 'tank0', -500, 650, 1.7, 1.5, ['fg']);
				addBGSprite('tank2', 'tank2', 450, 940, 1.5, 1.5, ['foreground']);
				addBGSprite('tank5', 'tank5', 1620, 700, 1.5, 1.5, ['fg']);
				return true;
			default: return false;
		}
	}
	function addBGSprite(tag:String, image:String, x:Float, y:Float, sx:Float, sy:Float, ?anims:Array<String>) {
		var anim = anims != null;
		sprites.push({tag:tag, image:image, x:N(x), y:N(y), scaleX:1, scaleY:1, scrollX:sx, scrollY:sy, alpha:1, animated:anim, animPrefix:anim?anims[0]:'', animFramerate:24, animLooped:true, antialiasing:true, flipX:false, flipY:false, front:false});
	}

	// ---- Sprite Management ----
	function addNewSprite() { sprites.push({tag:'sprite'+(sprites.length+1),image:'',x:0,y:0,scaleX:1,scaleY:1,scrollX:1,scrollY:1,alpha:1,animated:false,animPrefix:'',animFramerate:24,animLooped:true,antialiasing:true,flipX:false,flipY:false,front:false}); createSpritePreview(sprites.length-1);reorderCanvasLayers();rebuildSpriteDropdown();selectSprite(sprites.length-1);markUnsaved(); }
	function removeSelectedSprite() { if(selectedSprite<0)return; sprites.splice(selectedSprite,1);var p=spritePreviews[selectedSprite];if(p!=null){canvasGroup.remove(p);p.destroy();}spritePreviews.splice(selectedSprite,1);selectedSprite=-1;rebuildSpriteDropdown();updateSelectionVisuals();reorderCanvasLayers();markUnsaved(); }
	function duplicateSelectedSprite() { if(selectedSprite<0)return;var o=sprites[selectedSprite];sprites.push({tag:o.tag+'_copy',image:o.image,x:o.x+30,y:o.y+30,scaleX:o.scaleX,scaleY:o.scaleY,scrollX:o.scrollX,scrollY:o.scrollY,alpha:o.alpha,animated:o.animated,animPrefix:o.animPrefix,animFramerate:o.animFramerate,animLooped:o.animLooped,antialiasing:o.antialiasing,flipX:o.flipX,flipY:o.flipY,front:o.front});createSpritePreview(sprites.length-1);reorderCanvasLayers();rebuildSpriteDropdown();selectSprite(sprites.length-1);markUnsaved(); }
	function moveSpriteLayer(dir:Int) { if(selectedSprite<0||sprites.length<2)return;var ni=selectedSprite+dir;if(ni<0||ni>=sprites.length)return;swap(sprites,selectedSprite,ni);swap(spritePreviews,selectedSprite,ni);selectedSprite=ni;reorderCanvasLayers();rebuildSpriteDropdown();markUnsaved(); }
	inline function swap<T>(arr:Array<T>,i:Int,j:Int){var t=arr[i];arr[i]=arr[j];arr[j]=t;}

	function selectSprite(idx:Int){
		selectedSprite=idx;selectedChar='';editMode='sprites';
		if(UI_box!=null)UI_box.selectedIndex=0;
		if(modeToggleBtn!=null)modeToggleBtn.label=getModeBtnLabel();
		updateCharBorder();updateSpriteUIFromData();updateSelectionVisuals();
		if(idx>=0&&spriteDropDown!=null)spriteDropDown.selectedIndex=idx;
		rebuildObjectList();
	}
	function rebuildSpriteDropdown(){if(spriteDropDown==null)return;var list:Array<String>=[];for(i in 0...sprites.length)list.push('['+(sprites[i].front?'F':'B')+'] '+i+': '+sprites[i].tag);if(list.length==0)list.push(T('no_sprites','(no sprites)'));spriteDropDown.list=list;spriteDropDown.maxItems=12;if(selectedSprite>=0&&selectedSprite<list.length)spriteDropDown.selectedIndex=selectedSprite;rebuildObjectList();}
	function clearSpritePreviews(){for(p in spritePreviews){canvasGroup.remove(p);p.destroy();}spritePreviews=[];}

	function createSpritePreview(idx:Int){var d=sprites[idx];var spr=new FlxSprite(d.x,d.y);spr.origin.set(0,0);loadSpriteImg(spr,d);spr.scale.set(d.scaleX,d.scaleY);spr.alpha=d.alpha;spr.antialiasing=d.antialiasing;spr.flipX=d.flipX;spr.flipY=d.flipY;spritePreviews[idx]=spr;canvasGroup.add(spr);}
	function loadSpriteImg(spr:FlxSprite,d:StageSpriteData){if(d.image==null||d.image==''){spr.makeGraphic(100,100,FlxColor.fromRGB(100,100,100));return;}try{if(d.animated){if(Paths.fileExists('images/'+d.image+'.txt',TEXT))spr.frames=Paths.getPackerAtlas(d.image);else spr.frames=Paths.getSparrowAtlas(d.image);if(d.animPrefix!=''){spr.animation.addByPrefix('idle',d.animPrefix,d.animFramerate,d.animLooped);spr.animation.play('idle');}}else{var bmp=Paths.image(d.image);if(bmp!=null)spr.loadGraphic(bmp);else spr.makeGraphic(100,100,FlxColor.fromRGB(100,100,100));}}catch(e){spr.makeGraphic(100,100,FlxColor.fromRGB(150,50,50));}}
	function refreshSpritePreview(idx:Int){if(idx<0||idx>=spritePreviews.length)return;var spr=spritePreviews[idx];var d=sprites[idx];if(d.image!=null&&d.image!='')try{loadSpriteImg(spr,d);}catch(e){}spr.setPosition(d.x,d.y);spr.scale.set(d.scaleX,d.scaleY);spr.alpha=d.alpha;spr.antialiasing=d.antialiasing;spr.flipX=d.flipX;spr.flipY=d.flipY;updateSelectionVisuals();}
	function updateSpriteUIFromData(){if(selectedSprite<0||selectedSprite>=sprites.length){disableSpriteUI();return;}var d=sprites[selectedSprite];if(spriteDropDown!=null)spriteDropDown.selectedIndex=selectedSprite;if(tagInput!=null)tagInput.text=d.tag;if(imageInput!=null)imageInput.text=d.image;if(xStepper!=null)xStepper.value=d.x;if(yStepper!=null)yStepper.value=d.y;if(scaleXStepper!=null)scaleXStepper.value=d.scaleX;if(scaleYStepper!=null)scaleYStepper.value=d.scaleY;if(scrollXStepper!=null)scrollXStepper.value=d.scrollX;if(scrollYStepper!=null)scrollYStepper.value=d.scrollY;if(alphaStepper!=null)alphaStepper.value=d.alpha;if(animatedCheck!=null)animatedCheck.checked=d.animated;if(flipXCheck!=null)flipXCheck.checked=d.flipX;if(flipYCheck!=null)flipYCheck.checked=d.flipY;if(antialiasCheck!=null)antialiasCheck.checked=!d.antialiasing;if(frontCheck!=null)frontCheck.checked=d.front;if(animPrefixInput!=null)animPrefixInput.text=d.animPrefix;if(animFPStepper!=null)animFPStepper.value=d.animFramerate;if(animLoopCheck!=null)animLoopCheck.checked=d.animLooped;updateAnimatedFields();}
	function disableSpriteUI(){if(tagInput!=null)tagInput.text='';if(imageInput!=null)imageInput.text='';}
	function updateAnimatedFields(){var vis=selectedSprite>=0&&sprites.length>selectedSprite&&sprites[selectedSprite].animated;if(animPrefixInput!=null){animPrefixInput.visible=vis;animPrefixInput.active=vis;}if(animFPStepper!=null){animFPStepper.visible=vis;animFPStepper.active=vis;}if(animLoopCheck!=null){animLoopCheck.visible=vis;animLoopCheck.active=vis;}}
	function markUnsaved(){unsavedChanges=true;}

	// ---- Selection Visuals (with dimension caching for performance) ----
	function updateSelectionVisuals(){
		if(selectedSprite < 0 || selectedSprite >= spritePreviews.length) {
			selectionBorder.visible = false;
			for(h in resizeHandles) h.visible = false;
			return;
		}
		var spr = spritePreviews[selectedSprite];
		if(spr == null || spr.graphic == null || spr.frameWidth <= 0) {
			selectionBorder.visible = false;
			for(h in resizeHandles) h.visible = false;
			return;
		}
		var w = spr.frameWidth * spr.scale.x;
		var hh = spr.frameHeight * spr.scale.y;
		// Only regenerate dash rect when dimensions actually change (huge performance boost)
		if(w != _lastSelW || hh != _lastSelH) {
			_lastSelW = w;
			_lastSelH = hh;
			dashRect(selectionBorder, w, hh);
		}
		selectionBorder.setPosition(spr.x, spr.y);
		selectionBorder.visible = true;
		var hs = 12;
		var ps:Array<Array<Float>> = [[0.0, 0.0], [w - hs, 0.0], [0.0, hh - hs], [w - hs, hh - hs]];
		var hScale = 1 / FlxG.camera.zoom;
		for(i in 0...4) {
			var h = resizeHandles[i];
			h.scale.set(hScale, hScale);
			h.updateHitbox();
			h.setPosition(spr.x + ps[i][0], spr.y + ps[i][1]);
			h.visible = true;
		}
	}
	function dashRect(spr:FlxSprite, w:Float, h:Float) {
		var iw = Math.ceil(w) + 4;
		var ih = Math.ceil(h) + 4;
		if(iw < 4 || ih < 4) { spr.visible = false; return; }
		var bmp = new BitmapData(iw, ih, true, FlxColor.TRANSPARENT);
		dl(bmp, 2, 2, iw - 3, 2);
		dl(bmp, 2, ih - 3, iw - 3, ih - 3);
		dl(bmp, 2, 2, 2, ih - 3);
		dl(bmp, iw - 3, 2, iw - 3, ih - 3);
		spr.loadGraphic(bmp);
		spr.origin.set(2, 2);
	}
	function dl(bmp:BitmapData, x1:Int, y1:Int, x2:Int, y2:Int) {
		var dx = x2 - x1;
		var dy = y2 - y1;
		var dist = Math.ceil(Math.sqrt(dx * dx + dy * dy));
		if(dist < 1) return;
		var sx = dx / dist;
		var sy = dy / dist;
		var drawn = 0;
		var on = true;
		var cx:Float = x1;
		var cy:Float = y1;
		while(drawn < dist) {
			var len = on ? 6 : 4;
			for(i in 0...Math.round(len)) {
				var px = Math.round(cx);
				var py = Math.round(cy);
				if(px >= 0 && py >= 0 && px < bmp.width && py < bmp.height)
					if(on) bmp.setPixel32(px, py, FlxColor.WHITE);
				cx += sx;
				cy += sy;
				drawn++;
				if(drawn >= dist) break;
			}
			on = !on;
		}
	}

	// ---- Script Parsing / Save ----
	function extractImageName(fullPath:String):String{var p=fullPath.replace('\\','/');var idx=p.lastIndexOf('/images/');p=(idx>=0)?p.substr(idx+8):((idx=p.lastIndexOf('/'))>=0?p.substr(idx+1):p);for(ext in['.png','.jpg','.jpeg','.bmp'])if(p.endsWith(ext)){p=p.substr(0,p.lastIndexOf('.'));break;}return p;}

	function parseStageScript(script:String){
		sprites=[];clearSpritePreviews();selectedSprite=-1;
		var reLS=~/^makeLuaSprite\('([^']+)',\s*'([^']+)',\s*(-?[\d.]+),\s*(-?[\d.]+)\);/;
		var reLA=~/^makeAnimatedLuaSprite\('([^']+)',\s*'([^']+)',\s*(-?[\d.]+),\s*(-?[\d.]+)\);/;
		var reHS=~/^var\s+(\w+)\s*=\s*new\s+FlxSprite\((-?[\d.]+),\s*(-?[\d.]+)\);/;
		var reBF=~/"boyfriend"\s*:\s*\[(-?[\d.]+),\s*(-?[\d.]+)\]/;
		var reDad=~/"opponent"\s*:\s*\[(-?[\d.]+),\s*(-?[\d.]+)\]/;
		var reGf=~/"girlfriend"\s*:\s*\[(-?[\d.]+),\s*(-?[\d.]+)\]/;
		var reSF=~/setScrollFactor\('([^']+)',\s*(-?[\d.]+),\s*(-?[\d.]+)\);/;
		var reSFhs=~/\.scrollFactor\.set\((-?[\d.]+),\s*(-?[\d.]+)\);/;
		var reSC=~/scaleObject\('([^']+)',\s*(-?[\d.]+),\s*(-?[\d.]+)\);/;
		var reSChs=~/\.scale\.set\((-?[\d.]+),\s*(-?[\d.]+)\);/;
		var reAlpha=~/setProperty\('([^']+)\.alpha',\s*(-?[\d.]+)\);/;
		var reAhs=~/\.alpha\s*=\s*(-?[\d.]+);/;
		var reAA=~/setProperty\('([^']+)\.antialiasing',\s*false\);/;
		var reAAhs=~/\.antialiasing\s*=\s*false;/;
		var reFX=~/setProperty\('([^']+)\.flipX',\s*true\);/;
		var reFXhs=~/\.flipX\s*=\s*true;/;
		var reFY=~/setProperty\('([^']+)\.flipY',\s*true\);/;
		var reFYhs=~/\.flipY\s*=\s*true;/;
		var reFront=~/addLuaSprite\('([^']+)',\s*true\);/;
		var reAnim=~/addAnimationByPrefix\('([^']+)',\s*'[^']+',\s*'([^']+)',\s*(\d+),\s*(true|false)\);/;
		var reAnimhs=~/\.animation\.addByPrefix\('[^']+',\s*'([^']+)',\s*(\d+),\s*(true|false)\);/;
		var reLG=~/\.loadGraphic\(Paths\.image\('([^']+)'\)\);/;
		var reGSA=~/\.frames\s*=\s*Paths\.getSparrowAtlas\('([^']+)'\);/;

		for(line in script.split('\n')){var t=line.trim();
			if(reLS.match(t))sprites.push({tag:reLS.matched(1),image:reLS.matched(2),x:N(Std.parseFloat(reLS.matched(3))),y:N(Std.parseFloat(reLS.matched(4))),scaleX:1,scaleY:1,scrollX:1,scrollY:1,alpha:1,animated:false,animPrefix:'',animFramerate:24,animLooped:true,antialiasing:true,flipX:false,flipY:false,front:false});
			else if(reLA.match(t))sprites.push({tag:reLA.matched(1),image:reLA.matched(2),x:N(Std.parseFloat(reLA.matched(3))),y:N(Std.parseFloat(reLA.matched(4))),scaleX:1,scaleY:1,scrollX:1,scrollY:1,alpha:1,animated:true,animPrefix:'',animFramerate:24,animLooped:true,antialiasing:true,flipX:false,flipY:false,front:false});
			else if(reHS.match(t))sprites.push({tag:reHS.matched(1),image:'',x:N(Std.parseFloat(reHS.matched(2))),y:N(Std.parseFloat(reHS.matched(3))),scaleX:1,scaleY:1,scrollX:1,scrollY:1,alpha:1,animated:false,animPrefix:'',animFramerate:24,animLooped:true,antialiasing:true,flipX:false,flipY:false,front:false});
			if(sprites.length>0){var last=sprites[sprites.length-1];
				if(reSF.match(t)&&reSF.matched(1)==last.tag){last.scrollX=Std.parseFloat(reSF.matched(2));last.scrollY=Std.parseFloat(reSF.matched(3));}
				if(reSFhs.match(t)){last.scrollX=Std.parseFloat(reSFhs.matched(1));last.scrollY=Std.parseFloat(reSFhs.matched(2));}
				if(reSC.match(t)&&reSC.matched(1)==last.tag){last.scaleX=Std.parseFloat(reSC.matched(2));last.scaleY=Std.parseFloat(reSC.matched(3));}
				if(reSChs.match(t)){last.scaleX=Std.parseFloat(reSChs.matched(1));last.scaleY=Std.parseFloat(reSChs.matched(2));}
				if(reAlpha.match(t)&&reAlpha.matched(1)==last.tag)last.alpha=Std.parseFloat(reAlpha.matched(2));
				if(reAhs.match(t))last.alpha=Std.parseFloat(reAhs.matched(1));
				if((reAA.match(t)&&reAA.matched(1)==last.tag)||reAAhs.match(t))last.antialiasing=false;
				if((reFX.match(t)&&reFX.matched(1)==last.tag)||reFXhs.match(t))last.flipX=true;
				if((reFY.match(t)&&reFY.matched(1)==last.tag)||reFYhs.match(t))last.flipY=true;
				if(reFront.match(t)&&reFront.matched(1)==last.tag)last.front=true;
				if(reAnim.match(t)&&reAnim.matched(1)==last.tag){last.animated=true;last.animPrefix=reAnim.matched(2);last.animFramerate=Std.parseInt(reAnim.matched(3));last.animLooped=reAnim.matched(4)=='true';}
				if(reAnimhs.match(t)){last.animated=true;last.animPrefix=reAnimhs.matched(1);last.animFramerate=Std.parseInt(reAnimhs.matched(2));last.animLooped=reAnimhs.matched(3)=='true';}
				if(reLG.match(t))last.image=reLG.matched(1);
				if(reGSA.match(t)){last.image=reGSA.matched(1);last.animated=true;}
			}
			if(reBF.match(t)){bfX=N(Std.parseFloat(reBF.matched(1)));bfY=N(Std.parseFloat(reBF.matched(2)));}
			if(reDad.match(t)){dadX=N(Std.parseFloat(reDad.matched(1)));dadY=N(Std.parseFloat(reDad.matched(2)));}
			if(reGf.match(t)){gfX=N(Std.parseFloat(reGf.matched(1)));gfY=N(Std.parseFloat(reGf.matched(2)));}
		}
	}

	function updateStageUIFromData(){
		if(directoryInput != null) directoryInput.text = stageDirectory;
		if(zoomStepper != null) zoomStepper.value = defaultZoom;
		if(camSpeedStepper != null) camSpeedStepper.value = cameraSpeed;
		if(camBfXStepper != null) camBfXStepper.value = camBfX;
		if(camBfYStepper != null) camBfYStepper.value = camBfY;
		if(camDadXStepper != null) camDadXStepper.value = camDadX;
		if(camDadYStepper != null) camDadYStepper.value = camDadY;
		if(camGfXStepper != null) camGfXStepper.value = camGfX;
		if(camGfYStepper != null) camGfYStepper.value = camGfY;
		if(bfXStepper != null) bfXStepper.value = bfX;
		if(bfYStepper != null) bfYStepper.value = bfY;
		if(dadXStepper != null) dadXStepper.value = dadX;
		if(dadYStepper != null) dadYStepper.value = dadY;
		if(gfXStepper != null) gfXStepper.value = gfX;
		if(gfYStepper != null) gfYStepper.value = gfY;
		if(pixelStageCheck != null) pixelStageCheck.checked = isPixelStage;
		if(hideGFCheck != null) hideGFCheck.checked = hideGF;
	}

	function saveStageJSON(){_file.save('stage.json',PsychJsonPrinter.print({directory:stageDirectory,defaultZoom:defaultZoom,isPixelStage:isPixelStage,boyfriend:[bfX,bfY],girlfriend:[gfX,gfY],opponent:[dadX,dadY],hide_girlfriend:hideGF,camera_boyfriend:[camBfX,camBfY],camera_opponent:[camDadX,camDadY],camera_girlfriend:[camGfX,camGfY],camera_speed:cameraSpeed}),function(){unsavedChanges=false;show(T('saved_json','.json saved!'));});}
	function saveAsLua(){var buf=new StringBuf();buf.add('function onCreate()\n');for(s in sprites){buf.add('\t');if(s.animated){buf.add("makeAnimatedLuaSprite('"+s.tag+"','"+s.image+"',"+N(s.x)+","+N(s.y)+");\n");if(s.animPrefix!=''){buf.add('\taddAnimationByPrefix(\''+s.tag+"','idle','"+s.animPrefix+"',"+s.animFramerate+","+(s.animLooped?'true':'false')+");\n");buf.add('\tobjectPlayAnimation(\''+s.tag+"','idle',true);\n");}}else buf.add("makeLuaSprite('"+s.tag+"','"+s.image+"',"+N(s.x)+","+N(s.y)+");\n");if(s.scrollX!=1||s.scrollY!=1)buf.add("\tsetScrollFactor('"+s.tag+"',"+ff(s.scrollX)+","+ff(s.scrollY)+");\n");if(s.scaleX!=1||s.scaleY!=1)buf.add("\tscaleObject('"+s.tag+"',"+ff(s.scaleX)+","+ff(s.scaleY)+");\n");if(s.alpha!=1)buf.add("\tsetProperty('"+s.tag+".alpha',"+ff(s.alpha)+");\n");if(!s.antialiasing)buf.add("\tsetProperty('"+s.tag+".antialiasing',false);\n");if(s.flipX)buf.add("\tsetProperty('"+s.tag+".flipX',true);\n");if(s.flipY)buf.add("\tsetProperty('"+s.tag+".flipY',true);\n");buf.add("\taddLuaSprite('"+s.tag+"',"+(s.front?'true':'false')+");\n");if(sprites.indexOf(s)<sprites.length-1)buf.add('\n');}buf.add('\n\tclose(true);\nend\n');_file.save('stage.lua',buf.toString(),function(){unsavedChanges=false;show(T('saved_lua','.lua saved!'));});}
	function saveAsHscript(){var buf=new StringBuf();buf.add('function onCreate() {\n');for(s in sprites){var vn=~/[^a-zA-Z0-9_]/g.replace(s.tag,'_');buf.add('\tvar '+vn+' = new FlxSprite('+N(s.x)+','+N(s.y)+');\n');if(s.animated){buf.add('\t'+vn+'.frames = Paths.getSparrowAtlas(\''+s.image+'\');\n');if(s.animPrefix!=''){buf.add('\t'+vn+'.animation.addByPrefix(\'idle\',\''+s.animPrefix+'\','+s.animFramerate+','+(s.animLooped?'true':'false')+');\n');buf.add('\t'+vn+'.animation.play(\'idle\');\n');}}else buf.add('\t'+vn+'.loadGraphic(Paths.image(\''+s.image+'\'));\n');if(s.scrollX!=1||s.scrollY!=1)buf.add('\t'+vn+'.scrollFactor.set('+ff(s.scrollX)+','+ff(s.scrollY)+');\n');if(s.scaleX!=1||s.scaleY!=1)buf.add('\t'+vn+'.scale.set('+ff(s.scaleX)+','+ff(s.scaleY)+');\n');buf.add('\t'+vn+'.updateHitbox();\n');if(s.alpha!=1)buf.add('\t'+vn+'.alpha = '+ff(s.alpha)+';\n');if(!s.antialiasing)buf.add('\t'+vn+'.antialiasing = false;\n');if(s.flipX)buf.add('\t'+vn+'.flipX = true;\n');if(s.flipY)buf.add('\t'+vn+'.flipY = true;\n');if(s.front)buf.add('\tadd('+vn+');\n');else buf.add('\tgame.addBehindGF('+vn+');\n');if(sprites.indexOf(s)<sprites.length-1)buf.add('\n');}buf.add('}\n');_file.save('stage.hx',buf.toString(),function(){unsavedChanges=false;show(T('saved_hx','.hx saved!'));});}
	function ff(v:Float):String{var s=Std.string(v);if(s.indexOf('.')<0)s+='.0';return s;}

	// ---- UI ----
	function addSpritesUI(){
		var tab=UI_box.getTab(T('sprites','Sprites'));if(tab==null)return;var g=tab.menu;
		// Following NewChartingState pattern: wider controls, proper Y spacing, dropdowns LAST
		var yy = 10;
		var halfW = Std.int((UI_box.width - 30) / 2);

		// Row 0: Action buttons (wider gaps)
		B(g, 10, yy, 'add', '+ Add', function() addNewSprite(), 48);
		B(g, 64, yy, 'remove', '- Del', function() removeSelectedSprite(), 48);
		B(g, 118, yy, 'dup', 'Dup', function() duplicateSelectedSprite(), 44);
		B(g, 168, yy, 'up', '\x25B2', function() moveSpriteLayer(-1), 32);
		B(g, 206, yy, 'down', '\x25BC', function() moveSpriteLayer(1), 32);

		// Row 1: Tag
		yy += 36;
		var tagLbl = new EditorsText(10, yy - 15, 60, T('tag','Tag:'), 12);
		tagLbl.cameras = [camMenu]; tagLbl.scrollFactor.set(); g.add(tagLbl);
		tagInput = new PsychUIInputText(60, yy, halfW, '', 8);
		tagInput.onChange = function(_, v) { if(selectedSprite >= 0) { sprites[selectedSprite].tag = v; rebuildSpriteDropdown(); markUnsaved(); } };
		g.add(tagInput);

		// Row 2: Image name + reload + browse
		yy += 32;
		var imgLbl = new EditorsText(10, yy - 15, 60, T('image_name','Image:'), 12);
		imgLbl.cameras = [camMenu]; imgLbl.scrollFactor.set(); g.add(imgLbl);
		imageInput = new PsychUIInputText(60, yy, halfW, '', 8);
		imageInput.onChange = function(_, v) { if(selectedSprite >= 0) { sprites[selectedSprite].image = v; refreshSpritePreview(selectedSprite); markUnsaved(); } };
		g.add(imageInput);
		B(g, 60 + halfW + 4, yy - 2, 'reload', 'Reload', function() { if(selectedSprite >= 0) { refreshSpritePreview(selectedSprite); show('Reloaded.'); } }, 50);
		B(g, 60 + halfW + 58, yy - 2, 'browse', 'Browse', function() {
			if(selectedSprite < 0) { show(T('select_sprite_first','Select a sprite first!'), true); return; }
			_file.open('', T('select_image','Select Image'), [new FileFilter('Images','*.png;*.jpg;*.jpeg;*.bmp')], function() {
				if(_file.path != null) { var n = extractImageName(_file.path); sprites[selectedSprite].image = n; imageInput.text = n; refreshSpritePreview(selectedSprite); show('Image: '+n); markUnsaved(); }
			});
		}, 52);

		// Row 3: Position X, Y
		yy += 32;
		xStepper = stp(g, 10, yy, 10, 0, -9999, 9999, function(v) { if(selectedSprite >= 0) { sprites[selectedSprite].x = N(v); refreshSpritePreview(selectedSprite); markUnsaved(); } });
		L(g, 10, yy - 15, 'x', 'X:');
		yStepper = stp(g, 110, yy, 10, 0, -9999, 9999, function(v) { if(selectedSprite >= 0) { sprites[selectedSprite].y = N(v); refreshSpritePreview(selectedSprite); markUnsaved(); } });
		L(g, 110, yy - 15, 'y', 'Y:');

		// Row 4: Scale X, Y
		yy += 32;
		scaleXStepper = stp(g, 10, yy, 0.1, 1, 0.05, 10, function(v) { if(selectedSprite >= 0) { sprites[selectedSprite].scaleX = v; refreshSpritePreview(selectedSprite); markUnsaved(); } }, 2);
		L(g, 10, yy - 15, 'scale_x', 'Scale X:');
		scaleYStepper = stp(g, 110, yy, 0.1, 1, 0.05, 10, function(v) { if(selectedSprite >= 0) { sprites[selectedSprite].scaleY = v; refreshSpritePreview(selectedSprite); markUnsaved(); } }, 2);
		L(g, 110, yy - 15, 'scale_y', 'Scale Y:');

		// Row 5: Scroll X, Y + Alpha
		yy += 32;
		scrollXStepper = stp(g, 10, yy, 0.05, 1, 0, 2, function(v) { if(selectedSprite >= 0) { sprites[selectedSprite].scrollX = v; markUnsaved(); } }, 2);
		L(g, 10, yy - 15, 'scroll_x', 'Scrl X:');
		scrollYStepper = stp(g, 110, yy, 0.05, 1, 0, 2, function(v) { if(selectedSprite >= 0) { sprites[selectedSprite].scrollY = v; markUnsaved(); } }, 2);
		L(g, 110, yy - 15, 'scroll_y', 'Scrl Y:');
		alphaStepper = stp(g, 210, yy, 0.05, 1, 0.05, 1, function(v) { if(selectedSprite >= 0) { sprites[selectedSprite].alpha = v; refreshSpritePreview(selectedSprite); markUnsaved(); } }, 2);
		L(g, 210, yy - 15, 'alpha', 'Alpha:');

		// Row 6: Checkboxes (wider spacing)
		yy += 32;
		animatedCheck = chkCompact(g, 10, yy, T('animated','Animated'), function(v) { if(selectedSprite >= 0) { sprites[selectedSprite].animated = v; refreshSpritePreview(selectedSprite); updateAnimatedFields(); markUnsaved(); } });
		flipXCheck = chkCompact(g, 100, yy, T('flip_x','Flip X'), function(v) { if(selectedSprite >= 0) { sprites[selectedSprite].flipX = v; refreshSpritePreview(selectedSprite); markUnsaved(); } });
		flipYCheck = chkCompact(g, 190, yy, T('flip_y','Flip Y'), function(v) { if(selectedSprite >= 0) { sprites[selectedSprite].flipY = v; refreshSpritePreview(selectedSprite); markUnsaved(); } });
		yy += 26;
		antialiasCheck = chkCompact(g, 10, yy, T('no_aa','No AA'), function(v) { if(selectedSprite >= 0) { sprites[selectedSprite].antialiasing = !v; refreshSpritePreview(selectedSprite); markUnsaved(); } });
		frontCheck = chkCompact(g, 100, yy, T('front','Front'), function(v) { if(selectedSprite >= 0) { sprites[selectedSprite].front = v; reorderCanvasLayers(); rebuildSpriteDropdown(); markUnsaved(); } });

		// Row 7: Animation prefix + FPS + Loop
		yy += 32;
		var animLbl = new EditorsText(10, yy - 15, 0, T('anim_prefix','Anim:'), 12);
		animLbl.cameras = [camMenu]; animLbl.scrollFactor.set(); g.add(animLbl);
		animPrefixInput = new PsychUIInputText(50, yy, halfW, '', 8);
		animPrefixInput.onChange = function(_, v) { if(selectedSprite >= 0) { sprites[selectedSprite].animPrefix = v; markUnsaved(); } };
		g.add(animPrefixInput);
		animFPStepper = stp(g, 50 + halfW + 4, yy, 1, 24, 0, 60, function(v) { if(selectedSprite >= 0) { sprites[selectedSprite].animFramerate = Math.round(v); markUnsaved(); } });
		L(g, 50 + halfW + 4, yy - 15, 'fps', 'FPS:');
		animLoopCheck = chkCompact(g, 50 + halfW + 70, yy, T('loop','Loop'), function(v) { if(selectedSprite >= 0) { sprites[selectedSprite].animLooped = v; markUnsaved(); } });

		// ---- Sprite Dropdown added LAST so it renders on top ----
		yy += 32;
		var listLbl = new EditorsText(10, yy - 15, 0, T('sprite_list','Sprite List:'), 12);
		listLbl.cameras = [camMenu]; listLbl.scrollFactor.set(); g.add(listLbl);
		spriteDropDown = new PsychUIDropDownMenu(80, yy, [T('no_sprites','(no sprites)')], function(idx, _) { selectSprite(idx); });
		spriteDropDown.textObj.font = 'assets/fonts/editors.ttf';
		spriteDropDown.fieldWidth = Std.int(UI_box.width - 100);
		g.add(spriteDropDown);
	}

	function addStageUI(){
		var tab=UI_box.getTab(T('stage','Stage'));if(tab==null)return;var g=tab.menu;
		var yy = 10;

		// Stage name hint (auto-width)
		var hintLbl = new EditorsText(10, yy, 0, T('load_stage','Select a stage below:'), 12);
		hintLbl.cameras = [camMenu]; hintLbl.scrollFactor.set(); g.add(hintLbl);

		// Buttons row
		yy += 28;
		B(g, 10, yy - 2, 'refresh', 'Refresh', function() refreshStageDropdown(), 56);
		B(g, 70, yy - 2, 'center', 'Center View', function() resetCamera(), 80);

		// Directory input
		yy += 32;
		var dirLbl = new EditorsText(10, yy - 15, 0, T('directory','Dir:'), 12);
		dirLbl.cameras = [camMenu]; dirLbl.scrollFactor.set(); g.add(dirLbl);
		directoryInput = new PsychUIInputText(42, yy, Std.int(UI_box.width - 60), '', 8);
		directoryInput.onChange = function(_, v) { stageDirectory = v; markUnsaved(); };
		g.add(directoryInput);

		// Zoom & Camera Speed (wider spacing)
		yy += 32;
		zoomStepper = stp(g, 10, yy, 0.05, defaultZoom, 0.1, 3, function(v) { defaultZoom = v; markUnsaved(); }, 2);
		L(g, 10, yy - 15, 'default_zoom', 'Zoom:');
		camSpeedStepper = stp(g, 110, yy, 0.1, cameraSpeed, 0.1, 5, function(v) { cameraSpeed = v; markUnsaved(); }, 1);
		L(g, 110, yy - 15, 'camera_speed', 'Cam Speed:');

		// ---- Stage Dropdown added LAST so it renders on top ----
		yy += 36;
		stageDropDown = new PsychUIDropDownMenu(10, yy, [T('select_stage','-- Select Stage --')], function(idx, label) { if(idx > 0) loadStageByName(label); });
		stageDropDown.textObj.font = 'assets/fonts/editors.ttf';
		stageDropDown.fieldWidth = Std.int(UI_box.width - 30);
		g.add(stageDropDown);
		refreshStageDropdown();
	}

	function addCharactersUI(){
		var tab = UI_box.getTab(T('characters','Characters'));
		if(tab == null) return;
		var g = tab.menu;
		var yy = 10;

		// ---- BF ----
		var bfLbl = new EditorsText(10, yy - 15, 0, T('bf_xy','[BF]'), 13);
		bfLbl.cameras = [camMenu]; bfLbl.scrollFactor.set(); bfLbl.color = FlxColor.RED;
		g.add(bfLbl);
		yy += 20;
		L(g, 10, yy - 15, 'x', 'X:');
		bfXStepper = stp(g, 28, yy, 10, bfX, -9999, 9999, function(v) { bfX = N(v); updateCharPositions(); markUnsaved(); });
		L(g, 120, yy - 15, 'y', 'Y:');
		bfYStepper = stp(g, 138, yy, 10, bfY, -9999, 9999, function(v) { bfY = N(v); updateCharPositions(); markUnsaved(); });
		yy += 26;
		L(g, 10, yy - 15, 'cam_bf', 'Cam:');
		camBfXStepper = stp(g, 44, yy, 10, camBfX, -9999, 9999, function(v) { camBfX = v; markUnsaved(); });
		L(g, 130, yy - 15, 'cam_bf_y', 'Cam Y:');
		camBfYStepper = stp(g, 170, yy, 10, camBfY, -9999, 9999, function(v) { camBfY = v; markUnsaved(); });

		// ---- Dad ----
		yy += 36;
		var dadLbl = new EditorsText(10, yy - 15, 0, T('opp_xy','[Opponent]'), 13);
		dadLbl.cameras = [camMenu]; dadLbl.scrollFactor.set(); dadLbl.color = FlxColor.CYAN;
		g.add(dadLbl);
		yy += 20;
		L(g, 10, yy - 15, 'x', 'X:');
		dadXStepper = stp(g, 28, yy, 10, dadX, -9999, 9999, function(v) { dadX = N(v); updateCharPositions(); markUnsaved(); });
		L(g, 120, yy - 15, 'y', 'Y:');
		dadYStepper = stp(g, 138, yy, 10, dadY, -9999, 9999, function(v) { dadY = N(v); updateCharPositions(); markUnsaved(); });
		yy += 26;
		L(g, 10, yy - 15, 'cam_opp', 'Cam:');
		camDadXStepper = stp(g, 44, yy, 10, camDadX, -9999, 9999, function(v) { camDadX = v; markUnsaved(); });
		L(g, 130, yy - 15, 'cam_opp_y', 'Cam Y:');
		camDadYStepper = stp(g, 170, yy, 10, camDadY, -9999, 9999, function(v) { camDadY = v; markUnsaved(); });

		// ---- GF ----
		yy += 36;
		var gfLbl = new EditorsText(10, yy - 15, 0, T('gf_xy','[Girlfriend]'), 13);
		gfLbl.cameras = [camMenu]; gfLbl.scrollFactor.set(); gfLbl.color = FlxColor.LIME;
		g.add(gfLbl);
		yy += 20;
		L(g, 10, yy - 15, 'x', 'X:');
		gfXStepper = stp(g, 28, yy, 10, gfX, -9999, 9999, function(v) { gfX = N(v); updateCharPositions(); markUnsaved(); });
		L(g, 120, yy - 15, 'y', 'Y:');
		gfYStepper = stp(g, 138, yy, 10, gfY, -9999, 9999, function(v) { gfY = N(v); updateCharPositions(); markUnsaved(); });
		yy += 26;
		L(g, 10, yy - 15, 'cam_gf', 'Cam:');
		camGfXStepper = stp(g, 44, yy, 10, camGfX, -9999, 9999, function(v) { camGfX = v; markUnsaved(); });
		L(g, 130, yy - 15, 'cam_gf_y', 'Cam Y:');
		camGfYStepper = stp(g, 170, yy, 10, camGfY, -9999, 9999, function(v) { camGfY = v; markUnsaved(); });

		// ---- Options row ----
		yy += 36;
		hideGFCheck = chkCompact(g, 10, yy, T('hide_gf','Hide GF'), function(v) { hideGF = v; updateCharPositions(); markUnsaved(); });
		pixelStageCheck = chkCompact(g, 90, yy, T('pixel_stage','Pixel Stage'), function(v) { isPixelStage = v; markUnsaved(); });
	}

	function addBB(x:Float, y:Float, k:String, fb:String, cb:Void->Void, w:Int):Void {
		var b = new PsychUIButton(x, y, T(k, fb), cb, w, 20);
		b.cameras = [camMenu]; b.scrollFactor.set(); add(b);
	}

	// ---- Input ----
	override function update(elapsed:Float){
		MusicBeatState.camBeat = FlxG.camera;
		var inputs = [tagInput, imageInput, animPrefixInput, directoryInput];
		var blocked = false;
		for(t in inputs) if(t != null && PsychUIInputText.focusOn == t) { blocked = true; break; }
		if(blocked) { FlxG.sound.muteKeys = []; FlxG.sound.volumeDownKeys = []; FlxG.sound.volumeUpKeys = []; }
		else { FlxG.sound.muteKeys = TitleState.muteKeys; FlxG.sound.volumeDownKeys = TitleState.volumeDownKeys; FlxG.sound.volumeUpKeys = TitleState.volumeUpKeys; }
		if(outputTimer > 0) { outputTimer -= elapsed; if(outputTimer <= 0) outputMsg.visible = false; }
		if(!blocked && FlxG.mouse.justPressed) handleObjectListClick();
		if(!blocked && !PsychUIDropDownMenu.anyDropdownOpen && FlxG.mouse.wheel != 0 && FlxG.mouse.screenX >= objectListX && FlxG.mouse.screenX <= objectListX + objectListW && FlxG.mouse.screenY >= objectListY && FlxG.mouse.screenY <= objectListY + objectListH)
		{
			objectListScroll -= Std.int(FlxG.mouse.wheel);
			layoutObjectList();
		}
		if(!blocked && FlxG.keys.justPressed.ESCAPE) {
			if(unsavedChanges) openSubState(new Prompt(T('unsaved_changes','You have unsaved changes. Exit anyway?'), function() {
				unsavedChanges = false;
				MusicBeatState.switchState(new editors.MasterEditorMenu()); FlxG.mouse.visible = false; FlxG.sound.playMusic(Paths.music('freakyMenu'));
			}));
			else { unsavedChanges = false; MusicBeatState.switchState(new editors.MasterEditorMenu()); FlxG.mouse.visible = false; FlxG.sound.playMusic(Paths.music('freakyMenu')); }
			return;
		}
		if(!blocked && FlxG.keys.justPressed.DELETE && selectedSprite >= 0) removeSelectedSprite();
		handleCanvasInput(elapsed, blocked);
		if(charDad != null && charDad.isAnimationNull()) charDad.dance();
		if(charBF != null && charBF.isAnimationNull()) charBF.dance();
		if(charGF != null && charGF.isAnimationNull()) charGF.dance();
		super.update(elapsed);
	}

	function handleCanvasInput(elapsed:Float, blocked:Bool) {
		if(blocked) return;

		// ---- Camera & Zoom Controls ----
		if(FlxG.keys.pressed.E && FlxG.camera.zoom < 3) { FlxG.camera.zoom += elapsed * FlxG.camera.zoom; if(FlxG.camera.zoom > 3) FlxG.camera.zoom = 3; }
		if(FlxG.keys.pressed.Q && FlxG.camera.zoom > 0.1) { FlxG.camera.zoom -= elapsed * FlxG.camera.zoom; if(FlxG.camera.zoom < 0.1) FlxG.camera.zoom = 0.1; }
		if(FlxG.keys.justPressed.R) FlxG.camera.zoom = 1;
		if(!blocked && !PsychUIDropDownMenu.anyDropdownOpen && FlxG.mouse.wheel != 0 && FlxG.mouse.screenX > 290 && FlxG.mouse.screenX < FlxG.width - 370 && FlxG.mouse.screenY > 54 && FlxG.mouse.screenY < FlxG.height - 32)
			FlxG.camera.zoom += FlxG.mouse.wheel * 0.05 * FlxG.camera.zoom;
		if(FlxG.camera.zoom > 3) FlxG.camera.zoom = 3; else if(FlxG.camera.zoom < 0.1) FlxG.camera.zoom = 0.1;
		if(FlxG.mouse.pressedMiddle) { camFollow.x -= FlxG.mouse.deltaScreenX / FlxG.camera.zoom; camFollow.y -= FlxG.mouse.deltaScreenY / FlxG.camera.zoom; }
		if(FlxG.keys.justPressed.F) resetCamera();

		// ---- Pan ----
		var ps = 500 * elapsed;
		if(FlxG.keys.pressed.SHIFT) ps *= 4;
		if(FlxG.keys.pressed.I) camFollow.y -= ps;
		if(FlxG.keys.pressed.K) camFollow.y += ps;
		if(FlxG.keys.pressed.J) camFollow.x -= ps;
		if(FlxG.keys.pressed.L) camFollow.x += ps;
		if(selectedSprite < 0 && selectedChar == '') {
			if(FlxG.keys.pressed.UP) camFollow.y -= ps;
			if(FlxG.keys.pressed.DOWN) camFollow.y += ps;
			if(FlxG.keys.pressed.LEFT) camFollow.x -= ps;
			if(FlxG.keys.pressed.RIGHT) camFollow.x += ps;
		}

		var mx = FlxG.mouse.getWorldPosition(camEditor).x;
		var my = FlxG.mouse.getWorldPosition(camEditor).y;
		var msx = FlxG.mouse.screenX;
		var msy = FlxG.mouse.screenY;

		var inCanvas = msx > 290 && msx < FlxG.width - 370 && msy > 54 && msy < FlxG.height - 32;
		// Only start new interactions inside the canvas, but keep an active drag alive
		// even when the cursor travels over a panel.
		if(!inCanvas && !dragging && !resizing) return;
		if(FlxG.mouse.pressedMiddle) return;

		if(FlxG.mouse.justPressed && !dragging && !resizing) {
			// Resize handles first. Hit testing is done in screen space so it is
			// always accurate at any camera zoom / pan level.
			var corner = (selectedSprite >= 0) ? hitResizeHandleScreen(msx, msy) : -1;
			if(corner >= 0)
				startResize(corner, mx, my);
			else if(isCharMode())
				selectCharacterAt(msx, msy, mx, my);
			else
				selectSpriteAt(msx, msy, mx, my);

			rebuildObjectList();
		}

		// ---- Drag / resize using world-space deltas (robust at any zoom/pan) ----
		if((dragging || resizing) && FlxG.mouse.pressed)
		{
			if(resizing)
				updateResize(mx, my);
			else if(dragKind == 'sprite' && dragSpriteIndex >= 0 && dragSpriteIndex < sprites.length)
			{
				var idx = dragSpriteIndex;
				sprites[idx].x = N(dragStartObjX + (mx - dragStartWorldX));
				sprites[idx].y = N(dragStartObjY + (my - dragStartWorldY));
				refreshSpritePreview(idx);
				updateSpriteUIFromData();
			}
			else if(dragKind == 'char')
			{
				var dx = mx - dragStartWorldX;
				var dy = my - dragStartWorldY;
				switch(dragCharKey) {
					case 'bf': bfX = N(dragStartObjX + dx); bfY = N(dragStartObjY + dy);
					case 'dad': dadX = N(dragStartObjX + dx); dadY = N(dragStartObjY + dy);
					case 'gf': gfX = N(dragStartObjX + dx); gfY = N(dragStartObjY + dy);
				}
				updateCharPositions();
			}
		}

		if(FlxG.mouse.justReleased && (dragging || resizing))
		{
			endDrag();
			markUnsaved();
		}

		// ---- Keyboard Nudge (mode-aware) ----
		if(selectedSprite >= 0 && !dragging && isSpriteMode()) {
			var nudge = FlxG.keys.pressed.SHIFT ? 10 : 1;
			var nudged = false;
			if(FlxG.keys.justPressed.LEFT) { sprites[selectedSprite].x -= nudge; nudged = true; }
			if(FlxG.keys.justPressed.RIGHT) { sprites[selectedSprite].x += nudge; nudged = true; }
			if(FlxG.keys.justPressed.UP) { sprites[selectedSprite].y -= nudge; nudged = true; }
			if(FlxG.keys.justPressed.DOWN) { sprites[selectedSprite].y += nudge; nudged = true; }
			if(nudged) { refreshSpritePreview(selectedSprite); updateSpriteUIFromData(); markUnsaved(); }
		}
		if(selectedChar != '' && !dragging && isCharMode()) {
			var nudge = FlxG.keys.pressed.SHIFT ? 10 : 1;
			var nudged = false;
			if(FlxG.keys.justPressed.LEFT) { switch(selectedChar) { case 'bf': bfX -= nudge; case 'dad': dadX -= nudge; case 'gf': gfX -= nudge; } nudged = true; }
			if(FlxG.keys.justPressed.RIGHT) { switch(selectedChar) { case 'bf': bfX += nudge; case 'dad': dadX += nudge; case 'gf': gfX += nudge; } nudged = true; }
			if(FlxG.keys.justPressed.UP) { switch(selectedChar) { case 'bf': bfY -= nudge; case 'dad': dadY -= nudge; case 'gf': gfY -= nudge; } nudged = true; }
			if(FlxG.keys.justPressed.DOWN) { switch(selectedChar) { case 'bf': bfY += nudge; case 'dad': dadY += nudge; case 'gf': gfY += nudge; } nudged = true; }
			if(nudged) { updateCharPositions(); reorderCanvasLayers(); updateCharacterUIFromData(); markUnsaved(); }
		}
	}

	function resetCamera(){
		camFollow.setPosition(400, 200); // center on typical stage area
		camFollow.screenCenter();
		FlxG.camera.zoom = 1;
	}

	// ---- Screen-space hit helpers (accurate under any camera zoom/pan) ----
	function worldToScreenX(wx:Float):Float {
		return (wx - camEditor.scroll.x) * camEditor.zoom - 0.5 * camEditor.width * (camEditor.zoom - camEditor.initialZoom) + camEditor.x;
	}
	function worldToScreenY(wy:Float):Float {
		return (wy - camEditor.scroll.y) * camEditor.zoom - 0.5 * camEditor.height * (camEditor.zoom - camEditor.initialZoom) + camEditor.y;
	}

	function hitSpriteScreen(sx:Float, sy:Float):Int {
		var j = spritePreviews.length - 1;
		while(j >= 0) {
			var spr = spritePreviews[j];
			if(spr != null && spr.visible && spr.graphic != null) {
				var rx = worldToScreenX(spr.x);
				var ry = worldToScreenY(spr.y);
				var rw = spr.frameWidth * spr.scale.x * camEditor.zoom;
				var rh = spr.frameHeight * spr.scale.y * camEditor.zoom;
				if(sx >= rx && sx <= rx + rw && sy >= ry && sy <= ry + rh)
					return j;
			}
			j--;
		}
		return -1;
	}

	function hitResizeHandleScreen(sx:Float, sy:Float):Int {
		if(selectedSprite < 0 || selectedSprite >= spritePreviews.length) return -1;
		var spr = spritePreviews[selectedSprite];
		if(spr == null || spr.graphic == null || spr.frameWidth <= 0) return -1;
		var rx = worldToScreenX(spr.x);
		var ry = worldToScreenY(spr.y);
		var rw = spr.frameWidth * spr.scale.x * camEditor.zoom;
		var rh = spr.frameHeight * spr.scale.y * camEditor.zoom;
		var hs = 12.0; // screen-space handle target
		var pts:Array<Array<Float>> = [[0, 0], [rw - hs, 0], [0, rh - hs], [rw - hs, rh - hs]];
		for(i in 0...4) {
			if(sx >= rx + pts[i][0] && sx <= rx + pts[i][0] + hs && sy >= ry + pts[i][1] && sy <= ry + pts[i][1] + hs)
				return i;
		}
		return -1;
	}

	function overlapsCharScreen(ch:Character, sx:Float, sy:Float):Bool {
		if(ch == null || ch.graphic == null) return false;
		if(ch.frameWidth <= 0 || ch.frameHeight <= 0) return false;
		var rx = worldToScreenX(ch.x);
		var ry = worldToScreenY(ch.y);
		var rw = ch.frameWidth * camEditor.zoom;
		var rh = ch.frameHeight * camEditor.zoom;
		return sx >= rx && sx <= rx + rw && sy >= ry && sy <= ry + rh;
	}

	function selectSpriteAt(sx:Float, sy:Float, wx:Float, wy:Float) {
		selectedChar = '';
		updateCharBorder();
		var hit = hitSpriteScreen(sx, sy);
		if(hit >= 0) {
			selectSprite(hit);
			startDragSprite(hit, wx, wy);
		} else {
			selectedSprite = -1;
			if(spriteDropDown != null) spriteDropDown.selectedIndex = -1;
			updateSelectionVisuals();
			disableSpriteUI();
		}
	}

	function selectCharacterAt(sx:Float, sy:Float, wx:Float, wy:Float) {
		selectedSprite = -1;
		updateSelectionVisuals();
		selectedChar = '';
		updateCharBorder();
		if(overlapsCharScreen(charDad, sx, sy)) {
			selectedChar = 'dad'; updateCharBorder(); startDragChar('dad', wx, wy);
		} else if(overlapsCharScreen(charBF, sx, sy)) {
			selectedChar = 'bf'; updateCharBorder(); startDragChar('bf', wx, wy);
		} else if(!hideGF && overlapsCharScreen(charGF, sx, sy)) {
			selectedChar = 'gf'; updateCharBorder(); startDragChar('gf', wx, wy);
		} else {
			if(spriteDropDown != null) spriteDropDown.selectedIndex = -1;
			disableSpriteUI();
		}
		if(selectedChar != '') updateCharacterUIFromData();
	}

	function startDragSprite(idx:Int, wx:Float, wy:Float) {
		dragging = true;
		resizing = false;
		dragKind = 'sprite';
		dragSpriteIndex = idx;
		dragCharKey = '';
		dragStartWorldX = wx;
		dragStartWorldY = wy;
		dragStartObjX = sprites[idx].x;
		dragStartObjY = sprites[idx].y;
	}

	function startDragChar(key:String, wx:Float, wy:Float) {
		dragging = true;
		resizing = false;
		dragKind = 'char';
		dragSpriteIndex = -1;
		dragCharKey = key;
		dragStartWorldX = wx;
		dragStartWorldY = wy;
		switch(key) {
			case 'bf': dragStartObjX = bfX; dragStartObjY = bfY;
			case 'dad': dragStartObjX = dadX; dragStartObjY = dadY;
			case 'gf': dragStartObjX = gfX; dragStartObjY = gfY;
		}
	}

	function startResize(c:Int, wx:Float, wy:Float) {
		if(selectedSprite < 0 || selectedSprite >= sprites.length) return;
		var d = sprites[selectedSprite];
		dragging = true;
		resizing = true;
		dragKind = 'sprite';
		dragSpriteIndex = selectedSprite;
		dragCharKey = '';
		resizeCorner = c;
		resizeStartScaleX = d.scaleX;
		resizeStartScaleY = d.scaleY;
		resizeStartX = d.x;
		resizeStartY = d.y;
		resizeStartWorldX = wx;
		resizeStartWorldY = wy;
		var spr = spritePreviews[selectedSprite];
		resizeFrameW = (spr != null && spr.graphic != null) ? spr.frameWidth : 1;
		resizeFrameH = (spr != null && spr.graphic != null) ? spr.frameHeight : 1;
	}

	function updateResize(wx:Float, wy:Float) {
		if(selectedSprite < 0 || resizeCorner < 0) return;
		if(selectedSprite >= sprites.length) return;
		var d = sprites[selectedSprite];
		var ow = resizeFrameW;
		var oh = resizeFrameH;
		if(ow <= 0 || oh <= 0) return;

		var dx = wx - resizeStartWorldX;
		var dy = wy - resizeStartWorldY;
		var nsx = resizeStartScaleX;
		var nsy = resizeStartScaleY;
		var nx = resizeStartX;
		var ny = resizeStartY;

		switch(resizeCorner) {
			case 0:
				nsx = resizeStartScaleX - dx / ow;
				nsy = resizeStartScaleY - dy / oh;
				nx = resizeStartX + dx;
				ny = resizeStartY + dy;
			case 1:
				nsx = resizeStartScaleX + dx / ow;
				nsy = resizeStartScaleY - dy / oh;
				ny = resizeStartY + dy;
			case 2:
				nsx = resizeStartScaleX - dx / ow;
				nsy = resizeStartScaleY + dy / oh;
				nx = resizeStartX + dx;
			case 3:
				nsx = resizeStartScaleX + dx / ow;
				nsy = resizeStartScaleY + dy / oh;
		}

		if(nsx < 0.05) nsx = 0.05;
		if(nsy < 0.05) nsy = 0.05;
		if(nsx > 10) nsx = 10;
		if(nsy > 10) nsy = 10;

		d.scaleX = nsx;
		d.scaleY = nsy;
		d.x = nx;
		d.y = ny;
		refreshSpritePreview(selectedSprite);
		updateSpriteUIFromData();
	}

	function endDrag() {
		dragging = false;
		resizing = false;
		dragKind = '';
		dragSpriteIndex = -1;
		dragCharKey = '';
		resizeCorner = -1;
	}

	function updateCharacterUIFromData(){if(bfXStepper!=null)bfXStepper.value=bfX;if(bfYStepper!=null)bfYStepper.value=bfY;if(dadXStepper!=null)dadXStepper.value=dadX;if(dadYStepper!=null)dadYStepper.value=dadY;if(gfXStepper!=null)gfXStepper.value=gfX;if(gfYStepper!=null)gfYStepper.value=gfY;}

	public function UIEvent(id:String,sender:Dynamic){}
	override function destroy(){_file=null;charDad=null;charBF=null;charGF=null;super.destroy();}
}

// ---------------------------------------------------------------------------
// A compact row for the background editor's object explorer.
// ---------------------------------------------------------------------------
class BgObjectListRow extends FlxSpriteGroup
{
	public var bg:FlxSprite;
	public var accent:FlxSprite;
	public var titleText:EditorsText;
	public var subText:EditorsText;
	public var selected(default, set):Bool;

	public function new(x:Float, y:Float, w:Int, h:Int)
	{
		super(x, y);
		width = w;
		height = h;

		bg = PsychUIHelper.createRoundedRectSprite(w, h, 5);
		bg.color = 0xFF222633;
		bg.alpha = 0.95;
		add(bg);

		accent = new FlxSprite(0, 0).makeGraphic(3, h, FlxColor.TRANSPARENT);
		add(accent);

		titleText = new EditorsText(10, 3, w - 80, '', 11, false);
		titleText.color = 0xFFD5D9E6;
		add(titleText);

		subText = new EditorsText(w - 78, 5, 70, '', 8, false);
		subText.alignment = RIGHT;
		subText.color = 0xFF8A92A6;
		add(subText);

		selected = false;
	}

	public function setInfo(title:String, sub:String, isSelected:Bool)
	{
		titleText.text = title;
		subText.text = sub;
		this.selected = isSelected;
	}

	function set_selected(v:Bool):Bool
	{
		selected = v;
		if(selected)
		{
			bg.color = 0xFF35476B;
			accent.color = 0xFF4EA4FF;
			titleText.color = FlxColor.WHITE;
		}
		else
		{
			bg.color = 0xFF222633;
			accent.color = FlxColor.TRANSPARENT;
			titleText.color = 0xFFD5D9E6;
		}
		return v;
	}
}
