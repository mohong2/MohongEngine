package editors;

#if cpp
import Discord.DiscordClient;
#end
import flixel.addons.display.FlxGridOverlay;
import flixel.addons.transition.FlxTransitionableState;

import flixel.system.FlxSound;
import flixel.ui.FlxButton;
import MenuCharacter;
import flash.net.FileFilter;
import haxe.Json;
import editors.content.FileDialogHandler;
import backend.ui.*;

using StringTools;

class MenuCharacterEditorState extends MusicBeatState implements PsychUIEventHandler.PsychUIEvent
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
	function confirmExitMenuChar():Void
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

	var grpWeekCharacters:FlxTypedGroup<MenuCharacter>;
	var characterFile:MenuCharacterFile = null;
	var txtOffsets:EditorsText;
	var defaultCharacters:Array<String> = ['dad', 'bf', 'gf'];

	override function create() {
		characterFile = {
			image: 'Menu_Dad',
			scale: 1,
			position: [0, 0],
			idle_anim: 'M Dad Idle',
			confirm_anim: 'M Dad Idle',
			flipX: false
		};
		#if cpp
		DiscordClient.changePresence("Menu Character Editor", "Editting: " + characterFile.image);
		#end

		grpWeekCharacters = new FlxTypedGroup<MenuCharacter>();
		for (char in 0...3)
		{
			var weekCharacterThing:MenuCharacter = new MenuCharacter((FlxG.width * 0.25) * (1 + char) - 150, defaultCharacters[char]);
			weekCharacterThing.y += 70;
			weekCharacterThing.alpha = 0.2;
			grpWeekCharacters.add(weekCharacterThing);
		}

		add(new FlxSprite(0, 56).makeGraphic(FlxG.width, 386, 0xFFF9CF51));
		add(grpWeekCharacters);

		txtOffsets = new EditorsText(20, 10, 0, "[0, 0]", 32);
		txtOffsets.setFormat("VCR OSD Mono", 32, FlxColor.WHITE, CENTER);
		txtOffsets.alpha = 0.7;
		add(txtOffsets);

		var tipText:EditorsText = new EditorsText(0, 540, FlxG.width,
			"Arrow Keys - Change Offset (Hold shift for 10x speed)
			\nSpace - Play \"Start Press\" animation (Boyfriend Character Type)", 16);
		tipText.setFormat(Paths.font("editors.ttf"), 16, FlxColor.WHITE, CENTER);
		tipText.scrollFactor.set();
		add(tipText);

		addEditorBox();
		FlxG.mouse.visible = true;
		updateCharTypeBox();
		#if (android || desktop)
		addVirtualPad(MENU_CHARACTER_EDITOR, MENU_CHARACTER_EDITOR);
		#end

		fileDialog = new FileDialogHandler();
		super.create();
	}

	var UI_typebox:PsychUIBox;
	var UI_mainbox:PsychUIBox;
	var blockPressWhileTypingOn:Array<PsychUIInputText> = [];
	function addEditorBox() {
		var typeTabs = [
			Language.get('menuCharacterEditor_character_type', 'Character Type')
		];
		UI_typebox = new PsychUIBox(100, FlxG.height - 230, 120, 180, typeTabs);
		UI_typebox.scrollFactor.set();
		addTypeUI();
		add(UI_typebox);
		for (tab in UI_typebox.tabs) tab.text.font = 'assets/fonts/editors.ttf';

		var charTabs = [
			Language.get('menuCharacterEditor_character', 'Character')
		];
		UI_mainbox = new PsychUIBox(FlxG.width - 340, FlxG.height - 230, 240, 180, charTabs);
		UI_mainbox.scrollFactor.set();
		addCharacterUI();
		add(UI_mainbox);
		for (tab in UI_mainbox.tabs) tab.text.font = 'assets/fonts/editors.ttf';

		var loadButton = new PsychUIButton(0, 480, Language.get('menuCharacterEditor_load_character', 'Load Character'), function() {
			loadCharacter();
		}, 80, 20);
		loadButton.screenCenter(X);
		loadButton.x -= 60;
		add(loadButton);

		var saveButton = new PsychUIButton(0, 480, Language.get('menuCharacterEditor_save_character', 'Save Character'), function() {
			saveCharacter();
		}, 80, 20);
		saveButton.screenCenter(X);
		saveButton.x += 60;
		add(saveButton);
	}

	var opponentCheckbox:PsychUICheckBox;
	var boyfriendCheckbox:PsychUICheckBox;
	var girlfriendCheckbox:PsychUICheckBox;
	var curTypeSelected:Int = 0;
	function addTypeUI() {
		var tab = UI_typebox.getTab(Language.get('menuCharacterEditor_character_type', 'Character Type'));
		if(tab == null) return;
		var tab_menu = tab.menu;

		opponentCheckbox = new PsychUICheckBox(10, 20, Language.get('menuCharacterEditor_opponent', 'Opponent'), 100, null);
		opponentCheckbox.onClick = function() {
			curTypeSelected = 0;
			updateCharTypeBox();
		};

		boyfriendCheckbox = new PsychUICheckBox(opponentCheckbox.x, opponentCheckbox.y + 40, Language.get('menuCharacterEditor_boyfriend', 'Boyfriend'), 100, null);
		boyfriendCheckbox.onClick = function() {
			curTypeSelected = 1;
			updateCharTypeBox();
		};

		girlfriendCheckbox = new PsychUICheckBox(boyfriendCheckbox.x, boyfriendCheckbox.y + 40, Language.get('menuCharacterEditor_girlfriend', 'Girlfriend'), 100, null);
		girlfriendCheckbox.onClick = function() {
			curTypeSelected = 2;
			updateCharTypeBox();
		};

		tab_menu.add(opponentCheckbox);
		tab_menu.add(boyfriendCheckbox);
		tab_menu.add(girlfriendCheckbox);
	}

	var imageInputText:PsychUIInputText;
	var idleInputText:PsychUIInputText;
	var confirmInputText:PsychUIInputText;
	var scaleStepper:PsychUINumericStepper;
	var flipXCheckbox:PsychUICheckBox;
	function addCharacterUI() {
		var tab = UI_mainbox.getTab(Language.get('menuCharacterEditor_character', 'Character'));
		if(tab == null) return;
		var tab_menu = tab.menu;

		imageInputText = new PsychUIInputText(10, 20, 80, characterFile.image, 8);
		blockPressWhileTypingOn.push(imageInputText);
		imageInputText.onChange = function(oldText:String, newText:String) {
			characterFile.image = newText;
		};

		idleInputText = new PsychUIInputText(10, imageInputText.y + 35, 100, characterFile.idle_anim, 8);
		blockPressWhileTypingOn.push(idleInputText);
		idleInputText.onChange = function(oldText:String, newText:String) {
			characterFile.idle_anim = newText;
		};

		confirmInputText = new PsychUIInputText(10, idleInputText.y + 35, 100, characterFile.confirm_anim, 8);
		blockPressWhileTypingOn.push(confirmInputText);
		confirmInputText.onChange = function(oldText:String, newText:String) {
			characterFile.confirm_anim = newText;
		};

		flipXCheckbox = new PsychUICheckBox(10, confirmInputText.y + 30, Language.get('menuCharacterEditor_flip_x', 'Flip X'), 100, null);
		flipXCheckbox.onClick = function() {
			grpWeekCharacters.members[curTypeSelected].flipX = flipXCheckbox.checked;
			characterFile.flipX = flipXCheckbox.checked;
		};

		var reloadImageButton = new PsychUIButton(140, confirmInputText.y + 30, Language.get('menuCharacterEditor_reload_char', 'Reload Char'), function() {
			reloadSelectedCharacter();
		}, 80, 20);

		scaleStepper = new PsychUINumericStepper(140, imageInputText.y, 0.05, 1, 0.1, 30, 2);
		scaleStepper.textObj.font = 'assets/fonts/editors.ttf';
		scaleStepper.onValueChange = function() {
			characterFile.scale = scaleStepper.value;
			reloadSelectedCharacter();
		};

		tab_menu.add(new EditorsText(10, imageInputText.y - 18, 0, Language.get('menuCharacterEditor_image_file', 'Image file name:')));
		tab_menu.add(new EditorsText(10, idleInputText.y - 18, 0, Language.get('menuCharacterEditor_idle_anim', 'Idle animation on the .XML:')));
		tab_menu.add(new EditorsText(scaleStepper.x, scaleStepper.y - 18, 0, Language.get('menuCharacterEditor_scale', 'Scale:')));
		tab_menu.add(new EditorsText(10, confirmInputText.y - 18, 0, Language.get('menuCharacterEditor_confirm_anim', 'Start Press animation on the .XML:')));
		tab_menu.add(flipXCheckbox);
		tab_menu.add(reloadImageButton);
		tab_menu.add(imageInputText);
		tab_menu.add(idleInputText);
		tab_menu.add(confirmInputText);
		tab_menu.add(scaleStepper);
	}

	function updateCharTypeBox() {
		opponentCheckbox.checked = false;
		boyfriendCheckbox.checked = false;
		girlfriendCheckbox.checked = false;

		switch(curTypeSelected) {
			case 0:
				opponentCheckbox.checked = true;
			case 1:
				boyfriendCheckbox.checked = true;
			case 2:
				girlfriendCheckbox.checked = true;
		}

		updateCharacters();
	}

	function updateCharacters() {
		for (i in 0...3) {
			var char:MenuCharacter = grpWeekCharacters.members[i];
			char.alpha = 0.2;
			char.character = '';
			char.changeCharacter(defaultCharacters[i]);
		}
		reloadSelectedCharacter();
	}

	function reloadSelectedCharacter() {
		var char:MenuCharacter = grpWeekCharacters.members[curTypeSelected];

		char.alpha = 1;
		char.frames = Paths.getSparrowAtlas('menucharacters/' + characterFile.image);
		char.animation.addByPrefix('idle', characterFile.idle_anim, 24);
		if(curTypeSelected == 1) char.animation.addByPrefix('confirm', characterFile.confirm_anim, 24, false);
		char.flipX = (characterFile.flipX == true);

		char.scale.set(characterFile.scale, characterFile.scale);
		char.updateHitbox();
		char.animation.play('idle');
		updateOffset();

		#if cpp
		DiscordClient.changePresence("Menu Character Editor", "Editting: " + characterFile.image);
		#end
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
			if(#if (android || desktop) (virtualPad != null && virtualPad.buttonB.justPressed) || #end FlxG.keys.justPressed.ESCAPE) {
				confirmExitMenuChar();
			}

			var shiftMult:Int = 1;
			if(#if (android || desktop) (virtualPad != null && virtualPad.buttonC.pressed) ||#end FlxG.keys.pressed.SHIFT) shiftMult = 10;

			if(#if (android || desktop) (virtualPad != null && virtualPad.buttonLeft.justPressed) ||#end FlxG.keys.justPressed.LEFT) {
				characterFile.position[0] += shiftMult;
				updateOffset();
			}
			if(#if (android || desktop) (virtualPad != null && virtualPad.buttonRight.justPressed) ||#end FlxG.keys.justPressed.RIGHT) {
				characterFile.position[0] -= shiftMult;
				updateOffset();
			}
			if(#if (android || desktop) (virtualPad != null && virtualPad.buttonUp.justPressed) ||#end FlxG.keys.justPressed.UP) {
				characterFile.position[1] += shiftMult;
				updateOffset();
			}
			if(#if (android || desktop) (virtualPad != null && virtualPad.buttonDown.justPressed) ||#end FlxG.keys.justPressed.DOWN) {
				characterFile.position[1] -= shiftMult;
				updateOffset();
			}

			if((#if (android || desktop) (virtualPad != null && virtualPad.buttonA.justPressed) || #end FlxG.keys.justPressed.SPACE) && curTypeSelected == 1) {
				grpWeekCharacters.members[curTypeSelected].animation.play('confirm', true);
			}
		}

		var char:MenuCharacter = grpWeekCharacters.members[1];
		if(char.animation.curAnim != null && char.animation.curAnim.name == 'confirm' && char.animation.curAnim.finished) {
			char.animation.play('idle', true);
		}

		super.update(elapsed);
	}

	function updateOffset() {
		var char:MenuCharacter = grpWeekCharacters.members[curTypeSelected];
		char.offset.set(characterFile.position[0], characterFile.position[1]);
		txtOffsets.text = '' + characterFile.position;
	}

	var fileDialog:FileDialogHandler;

	function loadCharacter() {
		var jsonFilter:FileFilter = new FileFilter('JSON', 'json');
		fileDialog.open(null, null, [jsonFilter], function() {
			if(fileDialog.data != null) {
				try {
					var loadedChar:MenuCharacterFile = cast Json.parse(fileDialog.data);
					if(loadedChar.idle_anim != null && loadedChar.confirm_anim != null)
					{
						CoolUtil.traceMsg('trace.fileLoaded', 'Successfully loaded file!');
						characterFile = loadedChar;
						reloadSelectedCharacter();
						imageInputText.text = characterFile.image;
						idleInputText.text = characterFile.idle_anim;
						confirmInputText.text = characterFile.confirm_anim;
						scaleStepper.value = characterFile.scale;
						updateOffset();
						return;
					}
				} catch(e:Dynamic) {
					CoolUtil.traceMsg('trace.fileProblem', 'Problem loading file: {}', [e]);
				}
			}
		}, function() {
			CoolUtil.traceMsg('trace.fileCancelled', 'Cancelled file loading.');
		}, function() {
			CoolUtil.traceMsg('trace.fileProblemSimple', 'Problem loading file');
		});
	}

	function saveCharacter() {
		var data:String = Json.stringify(characterFile, "\t");
		if (data.length > 0)
		{
			var splittedImage:Array<String> = imageInputText.text.trim().split('_');
			var characterName:String = splittedImage[splittedImage.length-1].toLowerCase().replace(' ', '');

			fileDialog.save(characterName + '.json', data, function() {
			CoolUtil.traceMsg('trace.charSaved', 'Character saved successfully!');
			}, null, function() {
				FlxG.log.error('Problem saving file');
			});
		}
	}
}
