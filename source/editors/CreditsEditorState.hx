package editors;

#if cpp
import Discord.DiscordClient;
#end
import flixel.addons.display.FlxGridOverlay;
import flixel.addons.transition.FlxTransitionableState;
import flixel.system.FlxSound;
import flixel.addons.ui.FlxInputText;
import flixel.addons.ui.FlxUI9SliceSprite;
import flixel.addons.ui.FlxUI;
import flixel.addons.ui.FlxUICheckBox;
import flixel.addons.ui.FlxUIInputText;
import flixel.addons.ui.FlxUINumericStepper;
import flixel.addons.ui.FlxUITabMenu;
import flixel.ui.FlxButton;
import openfl.net.FileReference;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import flash.net.FileFilter;
import haxe.Json;
#if sys
import sys.io.File;
import sys.FileSystem;
#end

using StringTools;

class CreditsEditorState extends MusicBeatState
{
	var grpCredits:FlxTypedGroup<Alphabet>;
	var iconArray:Array<AttachedSprite> = [];
	var creditsStuff:Array<Array<String>> = [];

	var bg:FlxSprite;
	var descText:FlxText;
	var descBox:FlxUI9SliceSprite;

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

		// Load default credits data
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

		descBox = new FlxUI9SliceSprite(0, 0, Paths.getSparrowAtlas('customBox'), new flash.geom.Rectangle(16, 16, 80, 80));
		descBox.antialiasing = ClientPrefs.data.globalAntialiasing;
		descBox.alpha = 0.8;
		add(descBox);

		descText = new FlxText(50, FlxG.height - 150, 1180, "", 24);
		descText.setFormat(Paths.languageFont(), 24, FlxColor.WHITE, CENTER);
		descText.scrollFactor.set();
		add(descText);

		reloadCreditsList();
		addEditorBox();
		changeSelection();
		
		FlxG.mouse.visible = true;
		#if android
		addVirtualPad(LEFT_FULL, A_B_C);
		#end
		super.create();
	}

	var UI_box:FlxUITabMenu;
	var blockPressWhileTypingOn:Array<FlxUIInputText> = [];
	
	function addEditorBox() {
		var tabs = [
			{name: 'Credits', label: 'Credits'},
			{name: 'Section', label: 'Section'}
		];
		UI_box = new FlxUITabMenu(null, tabs, true);
		UI_box.resize(300, 400);
		UI_box.x = FlxG.width - UI_box.width - 20;
		UI_box.y = 20;
		UI_box.scrollFactor.set();
		
		addCreditsUI();
		addSectionUI();
		add(UI_box);

		var loadButton:FlxButton = new FlxButton(UI_box.x, UI_box.y + UI_box.height + 10, "Load Credits", function() {
			loadCredits();
		});
		loadButton.x -= loadButton.width + 10;
		add(loadButton);
		
		var addButton:FlxButton = new FlxButton(UI_box.x, loadButton.y, "Add Entry", function() {
			addCreditEntry();
		});
		addButton.x -= addButton.width + 10;
		add(addButton);
		
		var removeButton:FlxButton = new FlxButton(UI_box.x, addButton.y + addButton.height + 10, "Remove Entry", function() {
			removeCreditEntry();
		});
		removeButton.x -= removeButton.width + 10;
		add(removeButton);

		var saveButton:FlxButton = new FlxButton(UI_box.x, removeButton.y + removeButton.height + 10, "Save Credits", function() {
			saveCredits();
		});
		saveButton.x -= saveButton.width + 10;
		add(saveButton);
	}

	var nameInputText:FlxUIInputText;
	var iconInputText:FlxUIInputText;
	var descInputText:FlxUIInputText;
	var linkInputText:FlxUIInputText;
	var colorInputText:FlxUIInputText;
	var isSectionCheckbox:FlxUICheckBox;
	
	function addCreditsUI() {
		var tab_group = new FlxUI(null, UI_box);
		tab_group.name = "Credits";

		nameInputText = new FlxUIInputText(10, 30, 200, '', 8);
		blockPressWhileTypingOn.push(nameInputText);
		
		iconInputText = new FlxUIInputText(10, nameInputText.y + 50, 200, '', 8);
		blockPressWhileTypingOn.push(iconInputText);
		
		descInputText = new FlxUIInputText(10, iconInputText.y + 50, 200, '', 8);
		blockPressWhileTypingOn.push(descInputText);
		
		linkInputText = new FlxUIInputText(10, descInputText.y + 50, 200, '', 8);
		blockPressWhileTypingOn.push(linkInputText);
		
		colorInputText = new FlxUIInputText(10, linkInputText.y + 50, 120, '', 8);
		blockPressWhileTypingOn.push(colorInputText);

		isSectionCheckbox = new FlxUICheckBox(colorInputText.x + 130, colorInputText.y, null, null, "Is Section Header", 100);
		isSectionCheckbox.callback = function() {
			updateInputFields();
		};

		var reloadIconButton:FlxButton = new FlxButton(10, colorInputText.y + 40, "Reload Icon", function() {
			reloadSelectedIcon();
		});

		tab_group.add(new FlxText(nameInputText.x, nameInputText.y - 18, 0, 'Name:'));
		tab_group.add(new FlxText(iconInputText.x, iconInputText.y - 18, 0, 'Icon:'));
		tab_group.add(new FlxText(descInputText.x, descInputText.y - 18, 0, 'Description:'));
		tab_group.add(new FlxText(linkInputText.x, linkInputText.y - 18, 0, 'Link:'));
		tab_group.add(new FlxText(colorInputText.x, colorInputText.y - 18, 0, 'Color:'));
		
		tab_group.add(nameInputText);
		tab_group.add(iconInputText);
		tab_group.add(descInputText);
		tab_group.add(linkInputText);
		tab_group.add(colorInputText);
		tab_group.add(isSectionCheckbox);
		tab_group.add(reloadIconButton);
		
		UI_box.addGroup(tab_group);
	}

	var moveUpButton:FlxButton;
	var moveDownButton:FlxButton;
	var addSectionButton:FlxButton;
	
	function addSectionUI() {
		var tab_group = new FlxUI(null, UI_box);
		tab_group.name = "Section";

		moveUpButton = new FlxButton(20, 30, "Move Up", function() {
			moveEntry(-1);
		});
		
		moveDownButton = new FlxButton(moveUpButton.x + moveUpButton.width + 10, 30, "Move Down", function() {
			moveEntry(1);
		});
		
		addSectionButton = new FlxButton(20, moveUpButton.y + 50, "Add Section", function() {
			addSectionHeader();
		});

		var addSpaceButton:FlxButton = new FlxButton(20, addSectionButton.y + 50, "Add Space", function() {
			addSpace();
		});

		tab_group.add(new FlxText(20, 10, 0, 'Entry Management:'));
		tab_group.add(moveUpButton);
		tab_group.add(moveDownButton);
		tab_group.add(addSectionButton);
		tab_group.add(addSpaceButton);
		
		UI_box.addGroup(tab_group);
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

	override function getEvent(id:String, sender:Dynamic, data:Dynamic, ?params:Array<Dynamic>) {
		if(id == FlxUIInputText.CHANGE_EVENT && (sender is FlxUIInputText)) {
			if(creditsStuff[curSelected] != null) {
				var isSection:Bool = isSectionCheckbox.checked;
				
				if (isSection) {
					creditsStuff[curSelected] = [nameInputText.text];
				} else {
					creditsStuff[curSelected][0] = nameInputText.text;
					if (creditsStuff[curSelected].length < 2) creditsStuff[curSelected].push('');
					creditsStuff[curSelected][1] = iconInputText.text;
					if (creditsStuff[curSelected].length < 3) creditsStuff[curSelected].push('');
					creditsStuff[curSelected][2] = descInputText.text;
					if (creditsStuff[curSelected].length < 4) creditsStuff[curSelected].push('');
					creditsStuff[curSelected][3] = linkInputText.text;
					if (creditsStuff[curSelected].length < 5) creditsStuff[curSelected].push('');
					creditsStuff[curSelected][4] = colorInputText.text;
				}
				
				reloadCreditsList();
				updateDescBox();
			}
		}
	}

	override function update(elapsed:Float) {
		var blockInput:Bool = false;
		for (inputText in blockPressWhileTypingOn) {
			if(inputText.hasFocus) {
				FlxG.sound.muteKeys = [];
				FlxG.sound.volumeDownKeys = [];
				FlxG.sound.volumeUpKeys = [];
				blockInput = true;
				if(FlxG.keys.justPressed.ENTER) inputText.hasFocus = false;
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
			
			if(#if android virtualPad.buttonB.justPressed || #end controls.BACK) {
				MusicBeatState.switchState(new editors.MasterEditorMenu());
				FlxG.sound.playMusic(Paths.music('freakyMenu'));
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
		trace("File couldn't be loaded! You aren't on Desktop, are you?");
		#end
	}

	function onLoadCancel(_):Void {
		_file.removeEventListener(Event.SELECT, onLoadComplete);
		_file.removeEventListener(Event.CANCEL, onLoadCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onLoadError);
		_file = null;
		trace("Cancelled file loading.");
	}

	function onLoadError(_):Void {
		_file.removeEventListener(Event.SELECT, onLoadComplete);
		_file.removeEventListener(Event.CANCEL, onLoadCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onLoadError);
		_file = null;
		trace("Problem loading file");
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