package editors;

#if cpp
import Discord.DiscordClient;
#end
import flixel.addons.display.FlxGridOverlay;
import flixel.addons.transition.FlxTransitionableState;
import flixel.system.FlxSound;
import flixel.ui.FlxButton;
import openfl.net.FileReference;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import flash.net.FileFilter;
import haxe.Json;
import backend.ui.*;
#if sys
import sys.io.File;
import sys.FileSystem;
#end

using StringTools;
import mohong.TraceManager;

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

	function markUnsaved():Void { unsavedChanges = true; }
	function clearUnsaved():Void { unsavedChanges = false; }
	function confirmExitCredits():Void
	{
		if(unsavedChanges)
		{
			openSubState(new editors.content.Prompt(
				'There\'s unsaved progress,\nare you sure you want to exit?',
				function()
				{
					clearUnsaved();
					MusicBeatState.switchState(new editors.MasterEditorMenu());
				}
			));
		}
		else
		{
			MusicBeatState.switchState(new editors.MasterEditorMenu());
		}
	}

	var grpCredits:FlxTypedGroup<Alphabet>;
	var iconArray:Array<AttachedSprite> = [];
	var creditsStuff:Array<Array<String>> = [];

	var bg:FlxSprite;
	var descText:EditorsText;
	var descBox:FlxSprite;

	var curSelected:Int = 0;

	override function create() {
		#if cpp
		DiscordClient.changePresence("Credits Editor", "Editing Credits");
		#end

		bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.color = 0xFF353535;
		add(bg);

		grpCredits = new FlxTypedGroup<Alphabet>();
		add(grpCredits);

		creditsStuff = [
			['Mohong Engine Team'],
			['Mo_Hong', 'mohong', 'Main Programmer of mohong Engine', 'https://space.bilibili.com/672029688', '87ceeb'],
			['Li.tmc', 'Li.tmc', 'Engine icon', 'https://space.bilibili.com/3537117498051255', 'FF69B4'],
			[''],
			['Psych Engine Team'],
			['Shadow Mario', 'shadowmario', 'Main Programmer of Psych Engine', 'https://twitter.com/Shadow_Mario_', '444444'],
			['RiverOaken', 'river', 'Main Artist/Animator of Psych Engine', 'https://twitter.com/RiverOaken', 'B42F71'],
			['']
		];

		descBox = new FlxSprite().loadGraphic(Paths.image('customBox'));
		descBox.antialiasing = ClientPrefs.data.globalAntialiasing;
		descBox.alpha = 0.8;
		add(descBox);

		descText = new EditorsText(50, FlxG.height - 150, 1180, "", 24);
		descText.setFormat(Paths.font("editors.ttf"), 24, FlxColor.WHITE, CENTER);
		descText.scrollFactor.set();
		add(descText);

		reloadCreditsList();
		addEditorBox();
		changeSelection();

		FlxG.mouse.visible = true;
		#if (android || desktop)
		addVirtualPad(LEFT_FULL, A_B_C);
		#end
		super.create();
	}

	var UI_box:PsychUIBox;
	var blockPressWhileTypingOn:Array<PsychUIInputText> = [];

	function addEditorBox() {
		var tabs = [
			Language.get('creditsEditor_credits', 'Credits'),
			Language.get('creditsEditor_section', 'Section')
		];
		UI_box = new PsychUIBox(FlxG.width - 320, 20, 300, 400, tabs);
		UI_box.scrollFactor.set();

		addCreditsUI();
		addSectionUI();
		add(UI_box);
		for (tab in UI_box.tabs) tab.text.font = 'assets/fonts/editors.ttf';

		var loadButton = new PsychUIButton(UI_box.x, UI_box.y + UI_box.height + 10, Language.get('creditsEditor_load_credits', 'Load Credits'), function() {
			loadCredits();
		}, 80, 20);
		loadButton.x -= loadButton.width + 10;
		add(loadButton);

		var addButton = new PsychUIButton(UI_box.x, loadButton.y, Language.get('creditsEditor_add_entry', 'Add Entry'), function() {
			addCreditEntry();
		}, 80, 20);
		addButton.x -= addButton.width + 10;
		add(addButton);

		var removeButton = new PsychUIButton(UI_box.x, addButton.y + addButton.height + 10, Language.get('creditsEditor_remove_entry', 'Remove Entry'), function() {
			removeCreditEntry();
		}, 80, 20);
		removeButton.x -= removeButton.width + 10;
		add(removeButton);

		var saveButton = new PsychUIButton(UI_box.x, removeButton.y + removeButton.height + 10, Language.get('creditsEditor_save_credits', 'Save Credits'), function() {
			saveCredits();
		}, 80, 20);
		saveButton.x -= saveButton.width + 10;
		add(saveButton);
	}

	var nameInputText:PsychUIInputText;
	var iconInputText:PsychUIInputText;
	var descInputText:PsychUIInputText;
	var linkInputText:PsychUIInputText;
	var colorInputText:PsychUIInputText;
	var isSectionCheckbox:PsychUICheckBox;

	function addCreditsUI() {
		var tab = UI_box.getTab(Language.get('creditsEditor_credits', 'Credits'));
		if(tab == null) return;
		var tab_group = tab.menu;

		nameInputText = new PsychUIInputText(10, 30, 200, '', 8);
		blockPressWhileTypingOn.push(nameInputText);
		nameInputText.onChange = function(oldText:String, newText:String) {
			if(creditsStuff[curSelected] != null) {
				creditsStuff[curSelected][0] = newText;
				reloadCreditsList();
				updateDescBox();
			}
		};

		iconInputText = new PsychUIInputText(10, nameInputText.y + 50, 200, '', 8);
		blockPressWhileTypingOn.push(iconInputText);
		iconInputText.onChange = function(oldText:String, newText:String) {
			if(creditsStuff[curSelected] != null && !isSectionCheckbox.checked) {
				if(creditsStuff[curSelected].length < 2) creditsStuff[curSelected].push('');
				creditsStuff[curSelected][1] = newText;
				reloadCreditsList();
				updateDescBox();
			}
		};

		descInputText = new PsychUIInputText(10, iconInputText.y + 50, 200, '', 8);
		blockPressWhileTypingOn.push(descInputText);
		descInputText.onChange = function(oldText:String, newText:String) {
			if(creditsStuff[curSelected] != null && !isSectionCheckbox.checked) {
				if(creditsStuff[curSelected].length < 3) creditsStuff[curSelected].push('');
				creditsStuff[curSelected][2] = newText;
				reloadCreditsList();
				updateDescBox();
			}
		};

		linkInputText = new PsychUIInputText(10, descInputText.y + 50, 200, '', 8);
		blockPressWhileTypingOn.push(linkInputText);
		linkInputText.onChange = function(oldText:String, newText:String) {
			if(creditsStuff[curSelected] != null && !isSectionCheckbox.checked) {
				if(creditsStuff[curSelected].length < 4) creditsStuff[curSelected].push('');
				creditsStuff[curSelected][3] = newText;
				reloadCreditsList();
				updateDescBox();
			}
		};

		colorInputText = new PsychUIInputText(10, linkInputText.y + 50, 120, '', 8);
		blockPressWhileTypingOn.push(colorInputText);
		colorInputText.onChange = function(oldText:String, newText:String) {
			if(creditsStuff[curSelected] != null && !isSectionCheckbox.checked) {
				if(creditsStuff[curSelected].length < 5) creditsStuff[curSelected].push('');
				creditsStuff[curSelected][4] = newText;
				reloadCreditsList();
				updateDescBox();
			}
		};

		isSectionCheckbox = new PsychUICheckBox(colorInputText.x + 130, colorInputText.y, Language.get('creditsEditor_is_section_header', 'Is Section Header'), 100, null);
		isSectionCheckbox.onClick = function() {
			if(creditsStuff[curSelected] != null) {
				if(isSectionCheckbox.checked) {
					creditsStuff[curSelected] = [nameInputText.text];
				} else {
					var name:String = nameInputText.text;
					creditsStuff[curSelected] = [name, iconInputText.text, descInputText.text, linkInputText.text, colorInputText.text];
				}
			}
			updateInputFields();
		};

		var reloadIconButton = new PsychUIButton(10, colorInputText.y + 40, Language.get('creditsEditor_reload_icon', 'Reload Icon'), function() {
			reloadSelectedIcon();
		}, 80, 20);

		tab_group.add(new EditorsText(nameInputText.x, nameInputText.y - 18, 0, Language.get('creditsEditor_name', 'Name:')));
		tab_group.add(new EditorsText(iconInputText.x, iconInputText.y - 18, 0, Language.get('creditsEditor_icon', 'Icon:')));
		tab_group.add(new EditorsText(descInputText.x, descInputText.y - 18, 0, Language.get('creditsEditor_description', 'Description:')));
		tab_group.add(new EditorsText(linkInputText.x, linkInputText.y - 18, 0, Language.get('creditsEditor_link', 'Link:')));
		tab_group.add(new EditorsText(colorInputText.x, colorInputText.y - 18, 0, Language.get('creditsEditor_color', 'Color:')));

		tab_group.add(nameInputText);
		tab_group.add(iconInputText);
		tab_group.add(descInputText);
		tab_group.add(linkInputText);
		tab_group.add(colorInputText);
		tab_group.add(isSectionCheckbox);
		tab_group.add(reloadIconButton);
	}

	var moveUpButton:PsychUIButton;
	var moveDownButton:PsychUIButton;
	var addSectionButton:PsychUIButton;

	function addSectionUI() {
		var tab = UI_box.getTab(Language.get('creditsEditor_section', 'Section'));
		if(tab == null) return;
		var tab_group = tab.menu;

		moveUpButton = new PsychUIButton(20, 30, Language.get('creditsEditor_move_up', 'Move Up'), function() {
			moveEntry(-1);
		}, 80, 20);

		moveDownButton = new PsychUIButton(moveUpButton.x + moveUpButton.width + 10, 30, Language.get('creditsEditor_move_down', 'Move Down'), function() {
			moveEntry(1);
		}, 80, 20);

		addSectionButton = new PsychUIButton(20, moveUpButton.y + 50, Language.get('creditsEditor_add_section', 'Add Section'), function() {
			addSectionHeader();
		}, 80, 20);

		var addSpaceButton = new PsychUIButton(20, addSectionButton.y + 50, Language.get('creditsEditor_add_space', 'Add Space'), function() {
			addSpace();
		}, 80, 20);

		tab_group.add(new EditorsText(20, 10, 0, Language.get('creditsEditor_entry_management', 'Entry Management:')));
		tab_group.add(moveUpButton);
		tab_group.add(moveDownButton);
		tab_group.add(addSectionButton);
		tab_group.add(addSpaceButton);
	}

	function reloadCreditsList() {
		grpCredits.clear();
		iconArray = [];

		for (i in 0...creditsStuff.length) {
			var isSelectable:Bool = creditsStuff[i].length > 1;
			var creditText:Alphabet = new Alphabet(0, 0, creditsStuff[i][0], !isSelectable);
			creditText.isMenuItem = true;
			creditText.targetY = i;
			creditText.x = 100;
			creditText.y = (i * 60) + 200;
			grpCredits.add(creditText);

			if (isSelectable) {
				Paths.currentModDirectory = creditsStuff[i].length > 5 ? creditsStuff[i][5] : '';
				var icon:AttachedSprite = new AttachedSprite('credits/' + creditsStuff[i][1]);
				icon.xAdd = creditText.width + 10;
				icon.sprTracker = creditText;
				iconArray.push(icon);
				add(icon);
				Paths.currentModDirectory = '';
			}
		}
		changeSelection();
	}

	function changeSelection(change:Int = 0) {
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		curSelected += change;
		if (curSelected < 0) curSelected = creditsStuff.length - 1;
		if (curSelected >= creditsStuff.length) curSelected = 0;

		var bullShit:Int = 0;
		for (item in grpCredits.members) {
			item.targetY = bullShit - curSelected;
			bullShit++;

			item.alpha = 0.6;
			if (item.targetY == 0) {
				item.alpha = 1;
			}
		}

		updateInputFields();
		updateDescBox();
	}

	function updateInputFields() {
		var creditData:Array<String> = creditsStuff[curSelected];
		var isSection:Bool = creditData.length <= 1;

		isSectionCheckbox.checked = isSection;

		nameInputText.text = creditData[0];
		iconInputText.text = isSection ? '' : (creditData.length > 1 ? creditData[1] : '');
		descInputText.text = isSection ? '' : (creditData.length > 2 ? creditData[2] : '');
		linkInputText.text = isSection ? '' : (creditData.length > 3 ? creditData[3] : '');
		colorInputText.text = isSection ? '' : (creditData.length > 4 ? creditData[4] : '');

		updateInputVisibility();
	}

	function updateInputVisibility() {
		var isSection:Bool = isSectionCheckbox.checked;

		iconInputText.visible = !isSection;
		descInputText.visible = !isSection;
		linkInputText.visible = !isSection;
		colorInputText.visible = !isSection;
	}

	function updateDescBox() {
		var creditData:Array<String> = creditsStuff[curSelected];
		if (creditData.length > 2) {
			descText.text = creditData[2];
		} else {
			descText.text = creditData[0];
		}

		descBox.setPosition(descText.x - 10, descText.y - 10);
		descBox.setGraphicSize(Std.int(descText.width + 20), Std.int(descText.height + 20));
		descBox.updateHitbox();
	}

	function reloadSelectedIcon() {
		if (iconArray[curSelected] != null) {
			iconArray[curSelected].kill();
			iconArray.remove(iconArray[curSelected]);
		}

		var creditData:Array<String> = creditsStuff[curSelected];
		if (creditData.length > 1) {
			Paths.currentModDirectory = creditData.length > 5 ? creditData[5] : '';
			var icon:AttachedSprite = new AttachedSprite('credits/' + creditData[1]);
			icon.xAdd = grpCredits.members[curSelected].width + 10;
			icon.sprTracker = grpCredits.members[curSelected];
			iconArray[curSelected] = icon;
			add(icon);
			Paths.currentModDirectory = '';
		}
	}

	function addCreditEntry() {
		var newEntry:Array<String> = ['New Person', 'icon', 'Description', 'https://example.com', 'FFFFFF'];
		creditsStuff.insert(curSelected + 1, newEntry);
		reloadCreditsList();
		curSelected++;
		changeSelection();
	}

	function removeCreditEntry() {
		if (creditsStuff.length > 1) {
			creditsStuff.remove(creditsStuff[curSelected]);
			reloadCreditsList();
			changeSelection();
		}
	}

	function moveEntry(change:Int) {
		if (curSelected + change >= 0 && curSelected + change < creditsStuff.length) {
			var movedItem = creditsStuff[curSelected];
			creditsStuff.remove(movedItem);
			creditsStuff.insert(curSelected + change, movedItem);
			reloadCreditsList();
			curSelected += change;
			changeSelection();
		}
	}

	function addSectionHeader() {
		var newSection:Array<String> = ['New Section'];
		creditsStuff.insert(curSelected + 1, newSection);
		reloadCreditsList();
		curSelected++;
		changeSelection();
	}

	function addSpace() {
		var space:Array<String> = [''];
		creditsStuff.insert(curSelected + 1, space);
		reloadCreditsList();
		curSelected++;
		changeSelection();
	}

	public function UIEvent(id:String, sender:Dynamic) {
		// events handled via callbacks
	}

	override function update(elapsed:Float) {
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

			if(controls.UI_UP_P) {
				changeSelection(-1);
			}
			if(controls.UI_DOWN_P) {
				changeSelection(1);
			}

			if(#if (android || desktop) (virtualPad != null && virtualPad.buttonB.justPressed) || #end controls.BACK) {
				confirmExitCredits();
			}
		}

		super.update(elapsed);
	}

	var _file:FileReference = null;
	function loadCredits() {
		var jsonFilter:FileFilter = new FileFilter('JSON', 'json');
		_file = new FileReference();
		_file.addEventListener(Event.SELECT, onLoadComplete);
		_file.addEventListener(Event.CANCEL, onLoadCancel);
		_file.addEventListener(IOErrorEvent.IO_ERROR, onLoadError);
		_file.browse([jsonFilter]);
	}

	function onLoadComplete(_):Void {
		_file.removeEventListener(Event.SELECT, onLoadComplete);
		_file.removeEventListener(Event.CANCEL, onLoadCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onLoadError);

		#if sys
		var fullPath:String = null;
		@:privateAccess
		if(_file.__path != null) fullPath = _file.__path;

		if(fullPath != null) {
			var rawJson:String = File.getContent(fullPath);
			if(rawJson != null) {
				var loadedCredits:Array<Array<String>> = cast Json.parse(rawJson);
				if(loadedCredits != null && loadedCredits.length > 0) {
					creditsStuff = loadedCredits;
					reloadCreditsList();
					changeSelection();
				}
			}
		}
		_file = null;
		#else
		TraceManager.warn('trace.editor.fileLoadFailed', "File couldn't be loaded! You aren't on Desktop, are you?");
		#end
	}

	function onLoadCancel(_):Void {
		_file.removeEventListener(Event.SELECT, onLoadComplete);
		_file.removeEventListener(Event.CANCEL, onLoadCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onLoadError);
		_file = null;
		TraceManager.info('trace.editor.fileLoadCancelled', "Cancelled file loading.");
	}

	function onLoadError(_):Void {
		_file.removeEventListener(Event.SELECT, onLoadComplete);
		_file.removeEventListener(Event.CANCEL, onLoadCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onLoadError);
		_file = null;
		TraceManager.error('trace.editor.fileLoadProblem', "Problem loading file");
	}

	function saveCredits() {
		var data:String = Json.stringify(creditsStuff, "\t");
		if (data.length > 0) {
			#if android
			SUtil.saveContent("credits", ".json", data);
			#else
			_file = new FileReference();
			_file.addEventListener(Event.COMPLETE, onSaveComplete);
			_file.addEventListener(Event.CANCEL, onSaveCancel);
			_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
			_file.save(data, "credits.json");
			#end
		}
	}

	function onSaveComplete(_):Void {
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		FlxG.log.notice("Successfully saved credits.");
	}

	function onSaveCancel(_):Void {
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
	}

	function onSaveError(_):Void {
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		FlxG.log.error("Problem saving credits");
	}
}
