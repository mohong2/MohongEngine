package editors;

#if cpp
import Discord.DiscordClient;
#end

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import backend.ui.*;
import editors.content.EditorsText;
import editors.content.Prompt;
#if MODS_ALLOWED
import sys.io.File;
import sys.FileSystem;
#end

using StringTools;

/**
 * Credits Editor — completely redesigned around a two-pane workflow:
 *
 *  - Left pane: scrollable entry list (sections, spacers and members).
 *  - Right pane: contextual inspector + easy reorder/add/delete actions.
 *  - Top/bottom bars keep navigation, save/load and status always visible.
 *
 * Editing follows the actual in-game mod credits format:
 * `mods/<currentMod>/data/credits.txt`, one credit per line:
 *   Section Name
 *   Name::icon::description::link::color
 *   (blank line = spacer)
 */
class CreditsEditorState extends MusicBeatState implements PsychUIEventHandler.PsychUIEvent
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

	// ---- Layout constants ----
	static final TOP_H:Int = 52;
	static final BOTTOM_H:Int = 34;
	static final SIDE_GAP:Float = 12;
	static final LEFT_W:Float = 380;

	// ---- Data ----
	var credits:Array<Array<String>> = [];
	var curSelected:Int = 0;

	// ---- Panels ----
	var headerBg:FlxSprite;
	var leftPanelBg:FlxSprite;
	var rightPanelBg:FlxSprite;
	var bottomBg:FlxSprite;

	var titleText:EditorsText;
	var unsavedLabel:EditorsText;
	var listCountText:EditorsText;
	var currentModText:EditorsText;
	var statusText:EditorsText;
	var statusTimer:Float = 0.0;

	// ---- Left list ----
	var rowGroup:FlxTypedGroup<CreditsListRow>;
	var rows:Array<CreditsListRow> = [];
	var listX:Float = 0;
	var listY:Float = 0;
	var listW:Float = 0;
	var listH:Float = 0;
	var listScroll:Int = 0;

	// ---- Inspector widgets ----
	var nameInput:PsychUIInputText;
	var iconInput:PsychUIInputText;
	var descInput:PsychUIInputText;
	var linkInput:PsychUIInputText;
	var colorInput:PsychUIInputText;
	var modDirInput:PsychUIInputText;
	var sectionCheck:PsychUICheckBox;
	var colorSwatch:FlxSprite;

	var typeLabel:EditorsText;
	var actionHint:EditorsText;

	var blockPressWhileTypingOn:Array<PsychUIInputText> = [];
	var fieldLabels:Map<PsychUIInputText, EditorsText> = new Map();
	var updatingFields:Bool = false;

	override function create()
	{
		#if cpp
		DiscordClient.changePresence("Credits Editor", "Editing Credits");
		#end

		credits = [];

		_headerBg();
		_leftPanel();
		_rightPanel();
		_bottomBar();

		loadCurrentModCredits();
		rebuildList();
		if(credits.length > 0) selectIndex(0);

		FlxG.mouse.visible = true;

		#if (android || desktop)
		addVirtualPad(LEFT_FULL, A_B);
		#end

		super.create();
	}

	// ---- Layout builders ------------------------------------------------

	function _headerBg()
	{
		headerBg = new FlxSprite(0, 0).makeGraphic(Std.int(FlxG.width), TOP_H, FlxColor.BLACK);
		headerBg.scrollFactor.set();
		headerBg.alpha = 0.88;
		add(headerBg);

		var backBtn = new PsychUIButton(12, (TOP_H - 28) / 2, Language.get('creditsEditor_back', '◀ Back'), function() {
			confirmExit();
		}, 88, 28);
		add(backBtn);

		titleText = new EditorsText(0, (TOP_H - 30) / 2, FlxG.width, Language.get('creditsEditor_title', 'Credits Editor'), 20);
		titleText.setFormat(Paths.font("editors.ttf"), 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		titleText.borderSize = 2;
		titleText.scrollFactor.set();
		add(titleText);

		unsavedLabel = new EditorsText(FlxG.width / 2 + 120, (TOP_H - 26) / 2, 0, Language.get('creditsEditor_unsaved_badge', '● Unsaved'), 11);
		unsavedLabel.color = 0xFFFFC46B;
		unsavedLabel.scrollFactor.set();
		unsavedLabel.visible = false;
		add(unsavedLabel);

		var loadBtn = new PsychUIButton(FlxG.width - 210, (TOP_H - 28) / 2, Language.get('creditsEditor_load_credits', 'Load'), function() {
			loadCredits();
		}, 90, 28);
		add(loadBtn);

		var saveBtn = new PsychUIButton(FlxG.width - 110, (TOP_H - 28) / 2, Language.get('creditsEditor_save_credits', 'Save'), function() {
			saveCredits();
		}, 90, 28);
		add(saveBtn);
	}

	function _leftPanel()
	{
		leftPanelBg = makePanel(12, TOP_H + SIDE_GAP, LEFT_W, FlxG.height - TOP_H - BOTTOM_H - SIDE_GAP * 2, 0.78);
		add(leftPanelBg);

		var header = new EditorsText(24, TOP_H + 22, 0, Language.get('creditsEditor_list_title', 'Entries'), 16);
		header.color = FlxColor.WHITE;
		add(header);

		listCountText = new EditorsText(LEFT_W - 80, TOP_H + 24, 60, '', 11);
		listCountText.alignment = RIGHT;
		listCountText.color = 0xFF9AA0B4;
		add(listCountText);
		listCountText.text = Std.string(credits.length);

		currentModText = new EditorsText(24, TOP_H + 42, LEFT_W - 48, '', 10);
		currentModText.color = 0xFF8A92A6;
		add(currentModText);
		updateCurrentModText();

		listX = 24;
		listY = TOP_H + 52;
		listW = LEFT_W - 24;
		listH = FlxG.height - listY - BOTTOM_H - SIDE_GAP * 2;

		rowGroup = new FlxTypedGroup<CreditsListRow>();
		add(rowGroup);
	}

	function _rightPanel()
	{
		var rightX = 12 + LEFT_W + SIDE_GAP;
		var rightW = FlxG.width - rightX - 12;
		rightPanelBg = makePanel(rightX, TOP_H + SIDE_GAP, rightW, FlxG.height - TOP_H - BOTTOM_H - SIDE_GAP * 2, 0.78);
		add(rightPanelBg);

		// ---- Quick action toolbar ----
		var ax = rightX + 16;
		var ay = TOP_H + 24;
		actionBtn(ax, ay, Language.get('creditsEditor_add_entry', '+ Entry'), function() addEntry(), 86);
		actionBtn(ax + 94, ay, Language.get('creditsEditor_add_section', '+ Section'), function() addSectionHeader(), 100);
		actionBtn(ax + 202, ay, Language.get('creditsEditor_add_space', '+ Space'), function() addSpace(), 84);
		actionBtn(ax + 294, ay, Language.get('creditsEditor_duplicate', 'Duplicate'), function() duplicateEntry(), 92);
		actionBtn(ax + 394, ay, Language.get('creditsEditor_remove_entry', 'Delete'), function() removeCreditEntry(), 86);
		actionBtn(ax + 488, ay, Language.get('creditsEditor_move_up', '▲ Up'), function() moveEntry(-1), 70);
		actionBtn(ax + 566, ay, Language.get('creditsEditor_move_down', '▼ Down'), function() moveEntry(1), 80);

		// Divider
		var divY = ay + 42;
		var divider = new FlxSprite(rightX + 14, divY).makeGraphic(Std.int(rightW - 28), 1, 0x33FFFFFF);
		divider.scrollFactor.set();
		add(divider);

		// ---- Inspector ----
		var fy = divY + 16;
		var fieldW = Std.int(rightW - 160);
		var labelX = rightX + 22;
		var inputX = rightX + 100;
		var inputW = rightW - 130;

		typeLabel = new EditorsText(labelX, fy, 0, Language.get('creditsEditor_type', 'Type'), 12);
		typeLabel.color = 0xFFCCCCFF;
		add(typeLabel);
		sectionCheck = new PsychUICheckBox(inputX, fy - 3, Language.get('creditsEditor_is_section_header', 'Section Header'), 140, null);
		sectionCheck.onClick = function() { onSectionToggle(); };
		add(sectionCheck);

		fy += 34;
		nameInput = makeInput(inputX, fy, Std.int(inputW), Language.get('creditsEditor_name', 'Name'));
		fy += 46;
		iconInput = makeInput(inputX, fy, Std.int(inputW), Language.get('creditsEditor_icon', 'Icon'));
		fy += 46;
		descInput = makeInput(inputX, fy, Std.int(inputW), Language.get('creditsEditor_description', 'Description'));
		fy += 46;
		linkInput = makeInput(inputX, fy, Std.int(inputW), Language.get('creditsEditor_link', 'Link'));
		fy += 46;
		colorInput = makeInput(inputX, fy, Std.int(inputW - 50), Language.get('creditsEditor_color', 'Color'));

		colorSwatch = PsychUIHelper.createRoundedRectSprite(38, 28, 6);
		colorSwatch.setPosition(inputX + inputW - 42, fy + 1);
		colorSwatch.color = FlxColor.WHITE;
		add(colorSwatch);

		fy += 46;
		modDirInput = makeInput(inputX, fy, Std.int(inputW), Language.get('creditsEditor_mod_dir', 'Mod folder (advanced)'));
		modDirInput.visible = false;

		// Hint line
		actionHint = new EditorsText(rightX + 100, fy + 40, inputW,
			Language.get('creditsEditor_hint', 'Tip: select an entry on the list, then edit it here. Use ▲/▼ or the buttons to reorder.'), 11);
		actionHint.color = 0xFF8A92A6;
		add(actionHint);
	}

	function _bottomBar()
	{
		bottomBg = new FlxSprite(0, FlxG.height - BOTTOM_H).makeGraphic(Std.int(FlxG.width), BOTTOM_H, FlxColor.BLACK);
		bottomBg.scrollFactor.set();
		bottomBg.alpha = 0.85;
		add(bottomBg);

		var hint = new EditorsText(12, FlxG.height - BOTTOM_H + 9, 0,
			Language.get('creditsEditor_keys', '↑/↓ Select   ·   Delete removes selected   ·   Esc Back'), 10);
		hint.color = 0xFF9AA0B4;
		add(hint);

		statusText = new EditorsText(0, FlxG.height - BOTTOM_H + 8, FlxG.width, '', 11);
		statusText.setFormat(Paths.font("editors.ttf"), 11, FlxColor.YELLOW, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		statusText.borderSize = 1;
		statusText.scrollFactor.set();
		statusText.visible = false;
		add(statusText);
	}

	function makePanel(x:Float, y:Float, w:Float, h:Float, alpha:Float):FlxSprite
	{
		var p = PsychUIHelper.createRoundedRectSprite(Std.int(w), Std.int(h), 12);
		p.setPosition(x, y);
		p.color = 0xFF171922;
		p.alpha = alpha;
		p.scrollFactor.set();
		add(p);
		return p;
	}

	function actionBtn(x:Float, y:Float, label:String, cb:Void->Void, w:Int)
	{
		var b = new PsychUIButton(x, y, label, cb, w, 26);
		b.borderRadius = 6;
		b.smoothAnimations = false;
		add(b);
		return b;
	}

	function makeInput(x:Float, y:Float, w:Int, label:String):PsychUIInputText
	{
		var lbl = new EditorsText(x - 78, y + 2, 70, label, 10);
		lbl.color = 0xFFB8BFD1;
		add(lbl);

		var input = new PsychUIInputText(x, y, w, '', 9);
		input.borderRadius = 5;
		blockPressWhileTypingOn.push(input);
		input.onChange = function(oldText:String, newText:String) { onFieldChange(input, newText); };
		fieldLabels.set(input, lbl);
		add(input);
		return input;
	}

	// ---- List handling ---------------------------------------------------

	function rebuildList()
	{
		rowGroup.clear();
		for(row in rows) if(row != null) row.destroy();
		rows = [];

		for(i in 0...credits.length)
		{
			var row = new CreditsListRow(0, 0, Std.int(listW), 56);
			var isSection = credits[i].length <= 1;
			row.setInfo(credits[i][0], isSection ? Language.get('creditsEditor_section_badge', 'SECTION') : getEntrySubtitle(i), isSection);
			if(!isSection)
				row.setIcon(credits[i].length > 1 ? credits[i][1] : '', credits[i].length > 5 ? credits[i][5] : '');
			rowGroup.add(row);
			rows.push(row);
		}

		if(listCountText != null) listCountText.text = Std.string(credits.length);
		layoutList();
	}

	function getEntrySubtitle(i:Int):String
	{
		if(i < 0 || i >= credits.length) return '';
		var d = credits[i];
		if(d.length > 2 && d[2] != null && d[2].length > 0) return d[2];
		if(d.length > 1 && d[1] != null && d[1].length > 0) return d[1];
		return '';
	}

	function layoutList()
	{
		if(rows.length == 0) return;
		var rowH:Float = 56;
		var gap:Float = 6;
		var visibleCount = Math.floor((listH + gap) / (rowH + gap));
		if(visibleCount < 1) visibleCount = 1;

		var start = listScroll;
		if(curSelected < start) { start = curSelected; listScroll = start; }
		if(curSelected >= start + visibleCount) { start = curSelected - visibleCount + 1; listScroll = start; }
		if(start + visibleCount > rows.length) { start = rows.length - visibleCount; listScroll = start; }
		if(start < 0) { start = 0; listScroll = 0; }

		for(i in 0...rows.length)
		{
			var vis = i >= start && i < start + visibleCount;
			rows[i].visible = vis;
			rows[i].active = vis;
			if(vis)
				rows[i].setPosition(listX, listY + (i - start) * (rowH + gap));
		}
	}

	function selectIndex(index:Int)
	{
		var n = credits.length;
		if(n == 0) { curSelected = -1; clearInspectorFields(); return; }
		curSelected = (index + n) % n;

		for(i in 0...rows.length)
			rows[i].selected = (i == curSelected);

		layoutList();
		updateInputFields();
	}

	function updateRowTitle(i:Int)
	{
		if(i < 0 || i >= rows.length) return;
		rows[i].setInfo(credits[i][0], credits[i].length <= 1 ? Language.get('creditsEditor_section_badge', 'SECTION') : getEntrySubtitle(i), credits[i].length <= 1);
	}

	// ---- Inspector --------------------------------------------------------

	function updateCurrentModText()
	{
		if(currentModText == null) return;
		var mod:String = (Paths.currentModDirectory != null && Paths.currentModDirectory.length > 0)
			? Paths.currentModDirectory
			: Language.get('creditsEditor_no_mod', 'No Mod');
		currentModText.text = Language.get('creditsEditor_current_mod', 'Mod: ') + mod;
	}

	function clearInspectorFields()
	{
		if(nameInput == null) return;
		updatingFields = true;
		nameInput.text = '';
		iconInput.text = '';
		descInput.text = '';
		linkInput.text = '';
		colorInput.text = '';
		modDirInput.text = '';
		sectionCheck.checked = false;
		colorSwatch.color = FlxColor.WHITE;
		updateFieldVisibility();
		updatingFields = false;
	}

	function updateInputFields()
	{
		if(credits.length == 0 || curSelected < 0) return;
		var d = credits[curSelected];
		var isSection = d.length <= 1;

		updatingFields = true;

		sectionCheck.checked = isSection;
		nameInput.text = d[0];
		iconInput.text = isSection ? '' : (d.length > 1 ? d[1] : '');
		descInput.text = isSection ? '' : (d.length > 2 ? d[2] : '');
		linkInput.text = isSection ? '' : (d.length > 3 ? d[3] : '');
		colorInput.text = isSection ? '' : (d.length > 4 ? d[4] : '');
		modDirInput.text = isSection ? '' : (d.length > 5 ? d[5] : '');

		updateFieldVisibility();
		updateColorSwatch();

		updatingFields = false;
	}

	function updateFieldVisibility()
	{
		var isSection = sectionCheck.checked;
		setFieldVisible(iconInput, !isSection);
		setFieldVisible(descInput, !isSection);
		setFieldVisible(linkInput, !isSection);
		setFieldVisible(colorInput, !isSection);
		colorSwatch.visible = !isSection;
		setFieldVisible(modDirInput, false); // advanced, hidden by default
	}

	function setFieldVisible(input:PsychUIInputText, visible:Bool)
	{
		input.visible = visible;
		input.active = visible;
		if(fieldLabels.exists(input))
			fieldLabels.get(input).visible = visible;
	}

	function updateColorSwatch()
	{
		var hex = colorInput.text.trim();
		if(hex.length < 3) { colorSwatch.color = FlxColor.WHITE; return; }
		if(hex.startsWith('#')) hex = hex.substr(1);
		if(hex.length > 0 && !hex.startsWith('0x') && !hex.startsWith('0X'))
			hex = '0x' + hex;
		try {
			var c = FlxColor.fromString(hex);
			colorSwatch.color = (c != null) ? c : FlxColor.WHITE;
		} catch(e:Dynamic) {
			colorSwatch.color = FlxColor.WHITE;
		}
	}

	function onFieldChange(input:PsychUIInputText, newText:String)
	{
		if(updatingFields || curSelected < 0 || curSelected >= credits.length) return;
		var d = credits[curSelected];

		if(input == nameInput) {
			d[0] = newText;
			updateRowTitle(curSelected);
		}
		else if(!sectionCheck.checked) {
			if(input == iconInput) { setCreditField(d, 1, newText); rows[curSelected].setIcon(newText, d.length > 5 ? d[5] : ''); updateRowTitle(curSelected); }
			else if(input == descInput) { setCreditField(d, 2, newText); updateRowTitle(curSelected); }
			else if(input == linkInput) setCreditField(d, 3, newText);
			else if(input == colorInput) { setCreditField(d, 4, newText); updateColorSwatch(); }
			else if(input == modDirInput) setCreditField(d, 5, newText);
		}
		markUnsaved();
	}

	function setCreditField(d:Array<String>, idx:Int, value:String)
	{
		while(d.length <= idx) d.push('');
		d[idx] = value;
	}

	function onSectionToggle()
	{
		if(curSelected < 0 || curSelected >= credits.length) return;
		var d = credits[curSelected];
		if(sectionCheck.checked)
		{
			credits[curSelected] = [d[0]];
		}
		else
		{
			var modFolder:String = (modDirInput.text != null && modDirInput.text.length > 0) ? modDirInput.text : Paths.currentModDirectory;
			credits[curSelected] = [
				d[0],
				iconInput.text,
				descInput.text,
				linkInput.text,
				colorInput.text,
				modFolder
			];
		}
		rebuildList();
		selectIndex(curSelected);
		markUnsaved();
	}

	// ---- Actions -----------------------------------------------------------

	function addEntry()
	{
		var idx = (curSelected < 0) ? credits.length : curSelected + 1;
		var entry:Array<String> = ['New Person', 'icon', 'Description', 'https://example.com', 'FFFFFF'];
		if(Paths.currentModDirectory != null && Paths.currentModDirectory.length > 0)
			entry.push(Paths.currentModDirectory);
		credits.insert(idx, entry);
		rebuildList();
		selectIndex(idx);
		markUnsaved();
	}

	function addSectionHeader()
	{
		var idx = (curSelected < 0) ? credits.length : curSelected + 1;
		credits.insert(idx, ['New Section']);
		rebuildList();
		selectIndex(idx);
		markUnsaved();
	}

	function addSpace()
	{
		var idx = (curSelected < 0) ? credits.length : curSelected + 1;
		credits.insert(idx, ['']);
		rebuildList();
		selectIndex(idx);
		markUnsaved();
	}

	function duplicateEntry()
	{
		if(credits.length == 0 || curSelected < 0) return;
		var copy:Array<String> = credits[curSelected].copy();
		if(copy.length > 1)
			copy[0] = copy[0] + ' (copy)';
		else if(copy.length > 0)
			copy[0] = copy[0] + ' (copy)';
		credits.insert(curSelected + 1, copy);
		rebuildList();
		selectIndex(curSelected + 1);
		markUnsaved();
	}

	function removeCreditEntry()
	{
		if(credits.length <= 1 || curSelected < 0) return;
		credits.remove(credits[curSelected]);
		rebuildList();
		if(curSelected >= credits.length) curSelected = credits.length - 1;
		selectIndex(curSelected);
		markUnsaved();
	}

	function moveEntry(change:Int)
	{
		if(credits.length == 0 || curSelected < 0) return;
		var target = curSelected + change;
		if(target < 0 || target >= credits.length) return;
		var item = credits[curSelected];
		credits.remove(item);
		credits.insert(target, item);
		rebuildList();
		selectIndex(target);
		markUnsaved();
	}

	// ---- Mod-based file I/O --------------------------------------------------

	function getCurrentCreditsPath():String
	{
		#if MODS_ALLOWED
		if(Paths.currentModDirectory != null && Paths.currentModDirectory.length > 0)
			return Paths.mods(Paths.currentModDirectory + '/data/credits.txt');
		return Paths.mods('data/credits.txt');
		#else
		return '';
		#end
	}

	function loadCurrentModCredits()
	{
		#if MODS_ALLOWED
		var path:String = getCurrentCreditsPath();
		if(path.length > 0 && FileSystem.exists(path))
		{
			try
			{
				parseCreditsText(File.getContent(path));
				clearUnsaved();
			}
			catch(e:Dynamic)
			{
				credits = [];
				showStatus(Language.get('creditsEditor_load_failed', 'Could not load credits file.'), true);
			}
		}
		else
		{
			credits = [];
		}
		#else
		credits = [];
		#end
	}

	function loadCredits()
	{
		#if MODS_ALLOWED
		var path:String = getCurrentCreditsPath();
		if(path.length > 0 && FileSystem.exists(path))
		{
			try
			{
				parseCreditsText(File.getContent(path));
				rebuildList();
				if(credits.length > 0) selectIndex(0);
				clearUnsaved();
				showStatus(Language.get('creditsEditor_loaded', 'Credits loaded from current mod!'));
			}
			catch(e:Dynamic)
			{
				showStatus(Language.get('creditsEditor_load_failed', 'Could not load credits file.'), true);
			}
		}
		else
		{
			credits = [];
			curSelected = -1;
			rebuildList();
			clearInspectorFields();
			showStatus(Language.get('creditsEditor_no_credits', 'This mod has no credits file yet. Create one from scratch!'));
		}
		#else
		showStatus(Language.get('creditsEditor_no_credits', 'Credits editor requires mods.'), true);
		#end
	}

	function saveCredits()
	{
		#if MODS_ALLOWED
		if(credits == null) return;
		var path:String = getCurrentCreditsPath();
		if(path.length == 0)
		{
			showStatus(Language.get('creditsEditor_save_failed', 'Could not determine credits path.'), true);
			return;
		}

		try
		{
			var dir = path.substr(0, path.lastIndexOf('/'));
			if(!FileSystem.exists(dir)) FileSystem.createDirectory(dir);
			File.saveContent(path, creditsToText());
			clearUnsaved();
			showStatus(Language.get('creditsEditor_saved', 'Credits saved to the current mod!'));
		}
		catch(e:Dynamic)
		{
			showStatus(Language.get('creditsEditor_save_failed', 'Could not save credits file.'), true);
		}
		#else
		showStatus(Language.get('creditsEditor_save_failed', 'Credits editor requires mods.'), true);
		#end
	}

	function parseCreditsText(text:String)
	{
		credits = [];
		if(text == null) return;
		var lines:Array<String> = text.split('\n');
		for(line in lines)
		{
			line = line.replace('\r', '');
			if(line.length == 0)
			{
				credits.push(['']);
				continue;
			}
			var arr:Array<String> = line.replace('\\n', '\n').split('::');
			if(arr.length == 0) arr.push('');
			// Match CreditsState: an entry from a mod remembers its source mod folder.
			if(arr.length >= 5 && Paths.currentModDirectory != null && Paths.currentModDirectory.length > 0)
				arr.push(Paths.currentModDirectory);
			credits.push(arr);
		}
	}

	function creditsToText():String
	{
		var buf = new StringBuf();
		for(entry in credits)
		{
			if(entry == null || entry.length == 0)
			{
				buf.add('\n');
				continue;
			}

			if(entry.length <= 1)
			{
				buf.add(entry[0] == null ? '' : entry[0]);
			}
			else
			{
				buf.add(entry[0] == null ? '' : entry[0]);
				buf.add('::');
				buf.add(entry.length > 1 && entry[1] != null ? entry[1] : '');
				buf.add('::');
				buf.add(entry.length > 2 && entry[2] != null ? entry[2] : '');
				buf.add('::');
				buf.add(entry.length > 3 && entry[3] != null ? entry[3] : '');
				buf.add('::');
				buf.add(entry.length > 4 && entry[4] != null ? entry[4] : '');
			}
			buf.add('\n');
		}
		return buf.toString();
	}

	// ---- Misc ---------------------------------------------------------------

	function markUnsaved():Void { unsavedChanges = true; if(unsavedLabel != null) unsavedLabel.visible = true; }
	function clearUnsaved():Void { unsavedChanges = false; if(unsavedLabel != null) unsavedLabel.visible = false; }

	function showStatus(msg:String, err:Bool = false)
	{
		statusText.text = msg;
		statusText.color = err ? FlxColor.RED : FlxColor.YELLOW;
		statusText.visible = true;
		statusTimer = 3;
	}

	function confirmExit()
	{
		if(unsavedChanges)
		{
			openSubState(new Prompt(
				Language.get('creditsEditor_unsaved', 'There\'s unsaved progress,\nare you sure you want to exit?'),
				function()
				{
					clearUnsaved();
					MusicBeatState.switchState(new editors.MasterEditorMenu());
					FlxG.mouse.visible = false;
				}
			));
		}
		else
		{
			MusicBeatState.switchState(new editors.MasterEditorMenu());
			FlxG.mouse.visible = false;
		}
	}

	function handleListClick()
	{
		var mx = FlxG.mouse.screenX;
		var my = FlxG.mouse.screenY;
		if(mx < listX || mx > listX + listW || my < listY || my > listY + listH) return;

		for(i in 0...rows.length)
		{
			var row = rows[i];
			if(!row.visible) continue;
			if(mx >= row.x && mx <= row.x + row.bg.width && my >= row.y && my <= row.y + row.bg.height)
			{
				selectIndex(i);
				return;
			}
		}
	}

	public function UIEvent(id:String, sender:Dynamic) {}

	override function update(elapsed:Float)
	{
		var blocked = false;
		for(inputText in blockPressWhileTypingOn)
		{
			if(PsychUIInputText.focusOn == inputText)
			{
				FlxG.sound.muteKeys = [];
				FlxG.sound.volumeDownKeys = [];
				FlxG.sound.volumeUpKeys = [];
				blocked = true;
				if(FlxG.keys.justPressed.ENTER) PsychUIInputText.focusOn = null;
				break;
			}
		}

		if(!blocked)
		{
			FlxG.sound.muteKeys = TitleState.muteKeys;
			FlxG.sound.volumeDownKeys = TitleState.volumeDownKeys;
			FlxG.sound.volumeUpKeys = TitleState.volumeUpKeys;

			if(FlxG.mouse.justPressed) handleListClick();
			if(FlxG.mouse.wheel != 0 && FlxG.mouse.screenX >= listX && FlxG.mouse.screenX <= listX + listW && FlxG.mouse.screenY >= listY && FlxG.mouse.screenY <= listY + listH)
			{
				listScroll -= Std.int(FlxG.mouse.wheel);
				layoutList();
			}

			if(controls.UI_UP_P) selectIndex(curSelected - 1);
			if(controls.UI_DOWN_P) selectIndex(curSelected + 1);
			if(FlxG.keys.justPressed.DELETE) removeCreditEntry();
			if(controls.BACK) confirmExit();
		}

		if(statusTimer > 0)
		{
			statusTimer -= elapsed;
			if(statusTimer <= 0) statusText.visible = false;
		}

		super.update(elapsed);
	}
}

// ---------------------------------------------------------------------------
// A single row in the credit list.
// ---------------------------------------------------------------------------
class CreditsListRow extends FlxSpriteGroup
{
	public var bg:FlxSprite;
	public var accent:FlxSprite;
	public var icon:FlxSprite;
	public var titleText:EditorsText;
	public var subText:EditorsText;
	public var badge:EditorsText;
	public var selected(default, set):Bool;

	public function new(x:Float, y:Float, w:Int, h:Int)
	{
		super(x, y);
		width = w;
		height = h;

		bg = PsychUIHelper.createRoundedRectSprite(w, h, 6);
		bg.color = 0xFF262A38;
		bg.alpha = 0.95;
		add(bg);

		accent = new FlxSprite(0, 0).makeGraphic(4, h, FlxColor.TRANSPARENT);
		add(accent);

		icon = new FlxSprite(10, (h - 28) / 2);
		icon.visible = false;
		add(icon);

		titleText = new EditorsText(48, 7, w - 90, '', 13, false);
		titleText.color = FlxColor.WHITE;
		add(titleText);

		subText = new EditorsText(48, 27, w - 90, '', 10, false);
		subText.color = 0xFF9AA0B4;
		add(subText);

		badge = new EditorsText(w - 78, 20, 68, '', 8, false);
		badge.alignment = RIGHT;
		badge.color = 0xFF8A92A6;
		add(badge);

		selected = false;
	}

	public function setInfo(title:String, sub:String, isSection:Bool)
	{
		titleText.text = title;
		subText.text = sub;
		badge.text = isSection ? Language.get('creditsEditor_section_badge', 'SECTION') : '';
		if(isSection)
		{
			badge.color = 0xFFFFC46B;
			subText.color = 0xFF8A92A6;
		}
		else
		{
			badge.color = 0xFF8A92A6;
			subText.color = 0xFF9AA0B4;
		}
	}

	public function setIcon(name:String, modDir:String)
	{
		if(name == null || name.length == 0) { icon.visible = false; return; }
		Paths.currentModDirectory = modDir;
		try
		{
			var bmp = Paths.image('credits/' + name);
			if(bmp != null)
			{
				icon.loadGraphic(bmp);
				var maxSide = 28;
				var scale = Math.min(maxSide / icon.width, maxSide / icon.height);
				icon.scale.set(scale, scale);
				icon.updateHitbox();
				icon.visible = true;
			}
			else icon.visible = false;
		}
		catch(e:Dynamic)
		{
			icon.visible = false;
		}
		Paths.currentModDirectory = '';
	}

	function set_selected(v:Bool):Bool
	{
		selected = v;
		if(selected)
		{
			bg.color = 0xFF3B4A6B;
			accent.color = 0xFF4EA4FF;
			titleText.color = FlxColor.WHITE;
		}
		else
		{
			bg.color = 0xFF262A38;
			accent.color = FlxColor.TRANSPARENT;
			titleText.color = 0xFFD5D9E6;
		}
		return v;
	}
}
