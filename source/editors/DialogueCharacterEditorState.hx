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
import DialogueBoxPsych;
import editors.content.FileDialogHandler;

import lime.system.Clipboard;
import Alphabet;
import backend.ui.*;
#if sys
import sys.io.File;
#end

using StringTools;

class DialogueCharacterEditorState extends MusicBeatState implements PsychUIEventHandler.PsychUIEvent
{
	var box:FlxSprite;
	var daText:TypedAlphabet = null;

	private static var TIP_TEXT_MAIN:String =
	'JKLI - Move camera (Hold Shift to move 4x faster)
	\nQ/E - Zoom out/in
	\nR - Reset Camera
	\nH - Toggle Speech Bubble
	\nSpace - Reset text';

	private static var TIP_TEXT_OFFSET:String =
	'JKLI - Move camera (Hold Shift to move 4x faster)
	\nQ/E - Zoom out/in
	\nR - Reset Camera
	\nH - Toggle Ghosts
	\nWASD - Move Looping animation offset (Red)
	\nArrow Keys - Move Idle/Finished animation offset (Blue)
	\nHold Shift to move offsets 10x faster';

	var tipText:EditorsText;
	var offsetLoopText:EditorsText;
	var offsetIdleText:EditorsText;
	var animText:EditorsText;

	var camGame:FlxCamera;
	var camHUD:FlxCamera;

	var mainGroup:FlxSpriteGroup;
	var hudGroup:FlxSpriteGroup;

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
	function confirmExitDialogueChar():Void
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

	var character:DialogueCharacter;
	var ghostLoop:DialogueCharacter;
	var ghostIdle:DialogueCharacter;

	var curAnim:Int = 0;

	override function create() {
		persistentUpdate = persistentDraw = true;
		camGame = new FlxCamera();
		camHUD = new FlxCamera();
		camGame.bgColor = FlxColor.fromHSL(0, 0, 0.5);
		camHUD.bgColor.alpha = 0;

		FlxG.cameras.reset(camGame);
		FlxG.cameras.add(camHUD, false);
		FlxG.cameras.setDefaultDrawTarget(camGame, true);

		mainGroup = new FlxSpriteGroup();
		mainGroup.cameras = [camGame];
		hudGroup = new FlxSpriteGroup();
		hudGroup.cameras = [camGame];
		add(mainGroup);
		add(hudGroup);

		character = new DialogueCharacter();
		character.scrollFactor.set();
		mainGroup.add(character);

		ghostLoop = new DialogueCharacter();
		ghostLoop.alpha = 0;
		ghostLoop.color = FlxColor.RED;
		ghostLoop.isGhost = true;
		ghostLoop.jsonFile = character.jsonFile;
		ghostLoop.cameras = [camGame];
		add(ghostLoop);

		ghostIdle = new DialogueCharacter();
		ghostIdle.alpha = 0;
		ghostIdle.color = FlxColor.BLUE;
		ghostIdle.isGhost = true;
		ghostIdle.jsonFile = character.jsonFile;
		ghostIdle.cameras = [camGame];
		add(ghostIdle);

		box = new FlxSprite(70, 370);
		box.frames = Paths.getSparrowAtlas('speech_bubble');
		box.scrollFactor.set();
		box.antialiasing = ClientPrefs.data.globalAntialiasing;
		box.animation.addByPrefix('normal', 'speech bubble normal', 24);
		box.animation.addByPrefix('center', 'speech bubble middle', 24);
		box.animation.play('normal', true);
		box.setGraphicSize(Std.int(box.width * 0.9));
		box.updateHitbox();
		hudGroup.add(box);

		tipText = new EditorsText(10, 10, FlxG.width - 20, TIP_TEXT_MAIN, 8);
		tipText.setFormat(Paths.font("editors.ttf"), 16, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		tipText.cameras = [camHUD];
		tipText.scrollFactor.set();
		add(tipText);

		offsetLoopText = new EditorsText(10, 10, 0, '', 32);
		offsetLoopText.setFormat(Paths.font("editors.ttf"), 32, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		offsetLoopText.cameras = [camHUD];
		offsetLoopText.scrollFactor.set();
		add(offsetLoopText);
		offsetLoopText.visible = false;

		offsetIdleText = new EditorsText(10, 46, 0, '', 32);
		offsetIdleText.setFormat(Paths.font("editors.ttf"), 32, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		offsetIdleText.cameras = [camHUD];
		offsetIdleText.scrollFactor.set();
		add(offsetIdleText);
		offsetIdleText.visible = false;

		animText = new EditorsText(10, 22, FlxG.width - 20, '', 8);
		animText.setFormat(Paths.font("editors.ttf"), 24, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		animText.scrollFactor.set();
		animText.cameras = [camHUD];
		add(animText);

		reloadCharacter();
		updateTextBox();

		daText = new TypedAlphabet(DialogueBoxPsych.DEFAULT_TEXT_X, DialogueBoxPsych.DEFAULT_TEXT_Y, '', 0.05, false);
		daText.scaleX = 0.7;
		daText.scaleY = 0.7;
		daText.text = DEFAULT_TEXT;
		hudGroup.add(daText);

		addEditorBox();
		FlxG.mouse.visible = true;
		updateCharTypeBox();
		#if android
		addVirtualPad(DIALOGUE_PORTRAIT_EDITOR, DIALOGUE_PORTRAIT_EDITOR);
		addPadCamera();
		#end

		super.create();
	}

	var UI_typebox:PsychUIBox;
	var UI_mainbox:PsychUIBox;
	function addEditorBox() {
		var typeTabs = [
			Language.get('dialogueCharacterEditor_character_type', 'Character Type')
		];
		UI_typebox = new PsychUIBox(900, FlxG.height - 230, 120, 180, typeTabs);
		UI_typebox.scrollFactor.set();
		UI_typebox.camera = camHUD;
		addTypeUI();
		add(UI_typebox);
		for (tab in UI_typebox.tabs) tab.text.font = 'assets/fonts/editors.ttf';

		var mainTabs = [
			Language.get('dialogueCharacterEditor_animations', 'Animations'),
			Language.get('dialogueCharacterEditor_character', 'Character')
		];
		UI_mainbox = new PsychUIBox(UI_typebox.x + UI_typebox.width, FlxG.height - 300, 200, 250, mainTabs);
		UI_mainbox.scrollFactor.set();
		UI_mainbox.camera = camHUD;
		addAnimationsUI();
		addCharacterUI();
		add(UI_mainbox);
		for (tab in UI_mainbox.tabs) tab.text.font = 'assets/fonts/editors.ttf';
		UI_mainbox.selectedIndex = 1;
		lastTab = UI_mainbox.selectedName;
	}

	var leftCheckbox:PsychUICheckBox;
	var centerCheckbox:PsychUICheckBox;
	var rightCheckbox:PsychUICheckBox;
	function addTypeUI() {
		var tab = UI_typebox.getTab(Language.get('dialogueCharacterEditor_character_type', 'Character Type'));
		if(tab == null) return;
		var tab_group = tab.menu;

		leftCheckbox = new PsychUICheckBox(10, 20, Language.get('dialogueCharacterEditor_left', 'Left'), 100, null);
		leftCheckbox.onClick = function() {
			character.jsonFile.dialogue_pos = 'left';
			updateCharTypeBox();
		};

		centerCheckbox = new PsychUICheckBox(leftCheckbox.x, leftCheckbox.y + 40, Language.get('dialogueCharacterEditor_center', 'Center'), 100, null);
		centerCheckbox.onClick = function() {
			character.jsonFile.dialogue_pos = 'center';
			updateCharTypeBox();
		};

		rightCheckbox = new PsychUICheckBox(centerCheckbox.x, centerCheckbox.y + 40, Language.get('dialogueCharacterEditor_right', 'Right'), 100, null);
		rightCheckbox.onClick = function() {
			character.jsonFile.dialogue_pos = 'right';
			updateCharTypeBox();
		};

		tab_group.add(leftCheckbox);
		tab_group.add(centerCheckbox);
		tab_group.add(rightCheckbox);
	}

	var curSelectedAnim:String;
	var animationArray:Array<String> = [];
	var animationDropDown:PsychUIDropDownMenu;
	var animationInputText:PsychUIInputText;
	var loopInputText:PsychUIInputText;
	var idleInputText:PsychUIInputText;
	function addAnimationsUI() {
		var tab = UI_mainbox.getTab(Language.get('dialogueCharacterEditor_animations', 'Animations'));
		if(tab == null) return;
		var tab_group = tab.menu;

		animationDropDown = new PsychUIDropDownMenu(10, 30, [''], function(index:Int, label:String) {
			var anim:String = animationArray[index];
			if(character.dialogueAnimations.exists(anim)) {
				ghostLoop.playAnim(anim);
				ghostIdle.playAnim(anim, true);

				curSelectedAnim = anim;
				var animShit:DialogueAnimArray = character.dialogueAnimations.get(curSelectedAnim);
				offsetLoopText.text = 'Loop: ' + animShit.loop_offsets;
				offsetIdleText.text = 'Idle: ' + animShit.idle_offsets;

				animationInputText.text = animShit.anim;
				loopInputText.text = animShit.loop_name;
				idleInputText.text = animShit.idle_name;
			}
		});
		animationDropDown.textObj.font = 'assets/fonts/editors.ttf';

		animationInputText = new PsychUIInputText(15, 85, 80, '', 8);
		blockPressWhileTypingOn.push(animationInputText);
		loopInputText = new PsychUIInputText(animationInputText.x, animationInputText.y + 35, 150, '', 8);
		blockPressWhileTypingOn.push(loopInputText);
		idleInputText = new PsychUIInputText(loopInputText.x, loopInputText.y + 40, 150, '', 8);
		blockPressWhileTypingOn.push(idleInputText);

		var addUpdateButton = new PsychUIButton(10, idleInputText.y + 30, Language.get('dialogueCharacterEditor_add_update', 'Add/Update'), function() {
			var theAnim:String = animationInputText.text.trim();
			if(character.dialogueAnimations.exists(theAnim))
			{
				for (i in 0...character.jsonFile.animations.length) {
					var animArray:DialogueAnimArray = character.jsonFile.animations[i];
					if(animArray.anim.trim() == theAnim) {
						animArray.loop_name = loopInputText.text;
						animArray.idle_name = idleInputText.text;
						break;
					}
				}

				character.reloadAnimations();
				ghostLoop.reloadAnimations();
				ghostIdle.reloadAnimations();
				if(curSelectedAnim == theAnim) {
					ghostLoop.playAnim(theAnim);
					ghostIdle.playAnim(theAnim, true);
				}
			}
			else
			{
				var newAnim:DialogueAnimArray = {
					anim: theAnim,
					loop_name: loopInputText.text,
					loop_offsets: [0, 0],
					idle_name: idleInputText.text,
					idle_offsets: [0, 0]
				}
				character.jsonFile.animations.push(newAnim);

				var lastSelected:String = animationDropDown.selectedLabel;
				character.reloadAnimations();
				ghostLoop.reloadAnimations();
				ghostIdle.reloadAnimations();
				reloadAnimationsDropDown();
				animationDropDown.selectedLabel = lastSelected;
			}
		}, 100, 20);

		var removeUpdateButton = new PsychUIButton(115, addUpdateButton.y, Language.get('dialogueCharacterEditor_remove', 'Remove'), function() {
			for (i in 0...character.jsonFile.animations.length) {
				var animArray:DialogueAnimArray = character.jsonFile.animations[i];
				if(animArray != null && animArray.anim.trim() == animationInputText.text.trim()) {
					var lastSelected:String = animationDropDown.selectedLabel;
					character.jsonFile.animations.remove(animArray);
					character.reloadAnimations();
					ghostLoop.reloadAnimations();
					ghostIdle.reloadAnimations();
					reloadAnimationsDropDown();
					if(character.jsonFile.animations.length > 0 && lastSelected == animArray.anim.trim()) {
						var animToPlay:String = character.jsonFile.animations[0].anim;
						ghostLoop.playAnim(animToPlay);
						ghostIdle.playAnim(animToPlay, true);
					}
					animationDropDown.selectedLabel = lastSelected;
					animationInputText.text = '';
					loopInputText.text = '';
					idleInputText.text = '';
					break;
				}
			}
		}, 80, 20);

		tab_group.add(new EditorsText(animationDropDown.x, animationDropDown.y - 18, 0, Language.get('dialogueCharacterEditor_animations_label', 'Animations:')));
		tab_group.add(new EditorsText(animationInputText.x, animationInputText.y - 18, 0, Language.get('dialogueCharacterEditor_animation_name', 'Animation name:')));
		tab_group.add(new EditorsText(loopInputText.x, loopInputText.y - 18, 0, Language.get('dialogueCharacterEditor_loop_name', 'Loop name on .XML file:')));
		tab_group.add(new EditorsText(idleInputText.x, idleInputText.y - 18, 0, Language.get('dialogueCharacterEditor_idle_name', 'Idle/Finished name on .XML file:')));
		tab_group.add(animationInputText);
		tab_group.add(loopInputText);
		tab_group.add(idleInputText);
		tab_group.add(addUpdateButton);
		tab_group.add(removeUpdateButton);
		tab_group.add(animationDropDown);
		reloadAnimationsDropDown();
	}

	function reloadAnimationsDropDown() {
		animationArray = [];
		for (anim in character.jsonFile.animations) {
			animationArray.push(anim.anim);
		}

		if(animationArray.length < 1) animationArray = [''];
		animationDropDown.list = animationArray;
	}

	var imageInputText:PsychUIInputText;
	var scaleStepper:PsychUINumericStepper;
	var xStepper:PsychUINumericStepper;
	var yStepper:PsychUINumericStepper;
	var blockPressWhileTypingOn:Array<PsychUIInputText> = [];
	function addCharacterUI() {
		var tab = UI_mainbox.getTab(Language.get('dialogueCharacterEditor_character', 'Character'));
		if(tab == null) return;
		var tab_group = tab.menu;

		imageInputText = new PsychUIInputText(10, 30, 80, character.jsonFile.image, 8);
		blockPressWhileTypingOn.push(imageInputText);
		imageInputText.onChange = function(oldText:String, newText:String) {
			character.jsonFile.image = newText;
		};

		xStepper = new PsychUINumericStepper(imageInputText.x, imageInputText.y + 50, 10, character.jsonFile.position[0], -2000, 2000, 0);
		xStepper.textObj.font = 'assets/fonts/editors.ttf';
		xStepper.onValueChange = function() {
			character.jsonFile.position[0] = xStepper.value;
			reloadCharacter();
		};

		yStepper = new PsychUINumericStepper(imageInputText.x + 80, xStepper.y, 10, character.jsonFile.position[1], -2000, 2000, 0);
		yStepper.textObj.font = 'assets/fonts/editors.ttf';
		yStepper.onValueChange = function() {
			character.jsonFile.position[1] = yStepper.value;
			reloadCharacter();
		};

		scaleStepper = new PsychUINumericStepper(imageInputText.x, xStepper.y + 50, 0.05, character.jsonFile.scale, 0.1, 10, 2);
		scaleStepper.textObj.font = 'assets/fonts/editors.ttf';
		scaleStepper.onValueChange = function() {
			character.jsonFile.scale = scaleStepper.value;
			reloadCharacter();
		};

		var noAntialiasingCheckbox = new PsychUICheckBox(scaleStepper.x + 80, scaleStepper.y, Language.get('dialogueCharacterEditor_no_antialiasing', 'No Antialiasing'), 100, null);
		noAntialiasingCheckbox.checked = (character.jsonFile.no_antialiasing == true);
		noAntialiasingCheckbox.onClick = function() {
			character.jsonFile.no_antialiasing = noAntialiasingCheckbox.checked;
			character.antialiasing = !character.jsonFile.no_antialiasing;
		};

		tab_group.add(new EditorsText(10, imageInputText.y - 18, 0, Language.get('dialogueCharacterEditor_image_file', 'Image file name:')));
		tab_group.add(new EditorsText(10, xStepper.y - 18, 0, Language.get('dialogueCharacterEditor_position_offset', 'Position Offset:')));
		tab_group.add(new EditorsText(10, scaleStepper.y - 18, 0, Language.get('dialogueCharacterEditor_scale', 'Scale:')));
		tab_group.add(imageInputText);
		tab_group.add(xStepper);
		tab_group.add(yStepper);
		tab_group.add(scaleStepper);
		tab_group.add(noAntialiasingCheckbox);

		var reloadImageButton = new PsychUIButton(10, scaleStepper.y + 60, Language.get('dialogueCharacterEditor_reload_image', 'Reload Image'), function() {
			reloadCharacter();
		}, 80, 20);

		var loadButton = new PsychUIButton(reloadImageButton.x + 110, reloadImageButton.y, Language.get('dialogueCharacterEditor_load_character', 'Load Character'), function() {
			loadCharacter();
		}, 80, 20);
		var saveButton = new PsychUIButton(loadButton.x, reloadImageButton.y - 25, Language.get('dialogueCharacterEditor_save_character', 'Save Character'), function() {
			saveCharacter();
		}, 80, 20);
		tab_group.add(reloadImageButton);
		tab_group.add(loadButton);
		tab_group.add(saveButton);
	}

	function updateCharTypeBox() {
		leftCheckbox.checked = false;
		centerCheckbox.checked = false;
		rightCheckbox.checked = false;

		switch(character.jsonFile.dialogue_pos) {
			case 'left':
				leftCheckbox.checked = true;
			case 'center':
				centerCheckbox.checked = true;
			case 'right':
				rightCheckbox.checked = true;
		}
		reloadCharacter();
		updateTextBox();
	}

	private static var DEFAULT_TEXT:String = 'Lorem ipsum dolor sit amet';

	function reloadCharacter() {
		var charsArray:Array<DialogueCharacter> = [character, ghostLoop, ghostIdle];
		for (char in charsArray) {
			char.frames = Paths.getSparrowAtlas('dialogue/' + character.jsonFile.image);
			char.jsonFile = character.jsonFile;
			char.reloadAnimations();
			char.setGraphicSize(Std.int(char.width * DialogueCharacter.DEFAULT_SCALE * character.jsonFile.scale));
			char.updateHitbox();
		}
		character.x = DialogueBoxPsych.LEFT_CHAR_X;
		character.y = DialogueBoxPsych.DEFAULT_CHAR_Y;

		switch(character.jsonFile.dialogue_pos) {
			case 'right':
				character.x = FlxG.width - character.width + DialogueBoxPsych.RIGHT_CHAR_X;

			case 'center':
				character.x = FlxG.width / 2;
				character.x -= character.width / 2;
		}
		character.x += character.jsonFile.position[0] + mainGroup.x;
		character.y += character.jsonFile.position[1] + mainGroup.y;
		character.playAnim(character.jsonFile.animations[0].anim);
		if(character.jsonFile.animations.length > 0) {
			curSelectedAnim = character.jsonFile.animations[0].anim;
			var animShit:DialogueAnimArray = character.dialogueAnimations.get(curSelectedAnim);
			ghostLoop.playAnim(animShit.anim);
			ghostIdle.playAnim(animShit.anim, true);
			offsetLoopText.text = 'Loop: ' + animShit.loop_offsets;
			offsetIdleText.text = 'Idle: ' + animShit.idle_offsets;
		}

		curAnim = 0;
		animText.text = 'Animation: ' + character.jsonFile.animations[curAnim].anim + ' (' + (curAnim + 1) +' / ' + character.jsonFile.animations.length + ') - Press W or S to scroll';

		#if cpp
		DiscordClient.changePresence("Dialogue Character Editor", "Editting: " + character.jsonFile.image);
		#end
	}

	function updateTextBox() {
		box.flipX = false;
		var anim:String = 'normal';
		switch(character.jsonFile.dialogue_pos) {
			case 'left':
				box.flipX = true;
			case 'center':
				anim = 'center';
		}
		box.animation.play(anim, true);
		DialogueBoxPsych.updateBoxOffsets(box);
	}

	public function UIEvent(id:String, sender:Dynamic) {
		// events handled via callbacks
	}

	var currentGhosts:Int = 0;
	var lastTab:String = 'Character';
	var transitioning:Bool = false;
	override function update(elapsed:Float) {
		MusicBeatState.camBeat = FlxG.camera;
		if(transitioning) {
			super.update(elapsed);
			return;
		}

		if(character.animation.curAnim != null) {
			if(daText.finishedText) {
				if(character.animationIsLoop()) {
					character.playAnim(character.animation.curAnim.name, true);
				}
			} else if(character.animation.curAnim.finished) {
				character.animation.curAnim.restart();
			}
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

		if(!blockInput && PsychUIInputText.focusOn == null) {
			FlxG.sound.muteKeys = TitleState.muteKeys;
			FlxG.sound.volumeDownKeys = TitleState.volumeDownKeys;
			FlxG.sound.volumeUpKeys = TitleState.volumeUpKeys;
			if(#if android virtualPad.buttonA.justPressed || #end FlxG.keys.justPressed.SPACE && UI_mainbox.selectedName == Language.get('dialogueCharacterEditor_character', 'Character')) {
				character.playAnim(character.jsonFile.animations[curAnim].anim);
				daText.resetDialogue();
				updateTextBox();
			}

			var offsetAdd:Int = 1;
			var speed:Float = 300;
			if(#if android virtualPad.buttonZ.pressed ||#end FlxG.keys.pressed.SHIFT) {
				speed = 1200;
				offsetAdd = 10;
			}

			var negaMult:Array<Int> = [1, 1, -1, -1];
			var controlArray:Array<Bool> = [FlxG.keys.pressed.J, FlxG.keys.pressed.I, FlxG.keys.pressed.L, FlxG.keys.pressed.K];
			for (i in 0...controlArray.length) {
				if(controlArray[i]) {
					if(i % 2 == 1) {
						mainGroup.y += speed * elapsed * negaMult[i];
					} else {
						mainGroup.x += speed * elapsed * negaMult[i];
					}
				}
			}

			if(UI_mainbox.selectedName == Language.get('dialogueCharacterEditor_animations', 'Animations') && curSelectedAnim != null && character.dialogueAnimations.exists(curSelectedAnim)) {
				var moved:Bool = false;
				var animShit:DialogueAnimArray = character.dialogueAnimations.get(curSelectedAnim);
				var controlArrayLoop:Array<Bool> = [FlxG.keys.justPressed.A #if android ||	virtualPad.buttonLeft2.justPressed #end, FlxG.keys.justPressed.W #if android || virtualPad.buttonUp2.justPressed#end,  FlxG.keys.justPressed.D || #if android virtualPad.buttonRight2.justPressed ,#end  FlxG.keys.justPressed.S #if android ||  virtualPad.buttonDown2.justPressed #end];
				var controlArrayIdle:Array<Bool> = [FlxG.keys.justPressed.LEFT #if android ||	virtualPad.buttonLeft.justPressed #end, FlxG.keys.justPressed.UP #if android || virtualPad.buttonUp.justPressed#end,  FlxG.keys.justPressed.RIGHT || #if android virtualPad.buttonRight.justPressed,#end  FlxG.keys.justPressed.DOWN #if android ||  virtualPad.buttonDown.justPressed #end];
				for (i in 0...controlArrayLoop.length) {
					if(controlArrayLoop[i]) {
						if(i % 2 == 1) {
							animShit.loop_offsets[1] += offsetAdd * negaMult[i];
						} else {
							animShit.loop_offsets[0] += offsetAdd * negaMult[i];
						}
						moved = true;
					}
				}
				for (i in 0...controlArrayIdle.length) {
					if(controlArrayIdle[i]) {
						if(i % 2 == 1) {
							animShit.idle_offsets[1] += offsetAdd * negaMult[i];
						} else {
							animShit.idle_offsets[0] += offsetAdd * negaMult[i];
						}
						moved = true;
					}
				}

				if(moved) {
					offsetLoopText.text = 'Loop: ' + animShit.loop_offsets;
					offsetIdleText.text = 'Idle: ' + animShit.idle_offsets;
					ghostLoop.offset.set(animShit.loop_offsets[0], animShit.loop_offsets[1]);
					ghostIdle.offset.set(animShit.idle_offsets[0], animShit.idle_offsets[1]);
				}
			}

			if (FlxG.keys.pressed.Q && camGame.zoom > 0.1) {
				camGame.zoom -= elapsed * camGame.zoom;
				if(camGame.zoom < 0.1) camGame.zoom = 0.1;
			}
			if (FlxG.keys.pressed.E && camGame.zoom < 1) {
				camGame.zoom += elapsed * camGame.zoom;
				if(camGame.zoom > 1) camGame.zoom = 1;
			}
			if(#if android  virtualPad.buttonY.justPressed || #end FlxG.keys.justPressed.H) {
				if(UI_mainbox.selectedName == Language.get('dialogueCharacterEditor_animations', 'Animations')) {
					currentGhosts++;
					if(currentGhosts > 2) currentGhosts = 0;

					ghostLoop.visible = (currentGhosts != 1);
					ghostIdle.visible = (currentGhosts != 2);
					ghostLoop.alpha = (currentGhosts == 2 ? 1 : 0.6);
					ghostIdle.alpha = (currentGhosts == 1 ? 1 : 0.6);
				} else {
					hudGroup.visible = !hudGroup.visible;
				}
			}
			if(#if android virtualPad.buttonX.justPressed || #end FlxG.keys.justPressed.R) {
				camGame.zoom = 1;
				mainGroup.setPosition(0, 0);
				hudGroup.visible = true;
			}

			if(UI_mainbox.selectedName != lastTab) {
				if(UI_mainbox.selectedName == Language.get('dialogueCharacterEditor_animations', 'Animations')) {
					hudGroup.alpha = 0;
					mainGroup.alpha = 0;
					ghostLoop.alpha = 0.6;
					ghostIdle.alpha = 0.6;
					tipText.text = TIP_TEXT_OFFSET;
					offsetLoopText.visible = true;
					offsetIdleText.visible = true;
					animText.visible = false;
					currentGhosts = 0;
				} else {
					hudGroup.alpha = 1;
					mainGroup.alpha = 1;
					ghostLoop.alpha = 0;
					ghostIdle.alpha = 0;
					tipText.text = TIP_TEXT_MAIN;
					offsetLoopText.visible = false;
					offsetIdleText.visible = false;
					animText.visible = true;
					updateTextBox();
					daText.resetDialogue();

					if(curAnim < 0) curAnim = character.jsonFile.animations.length - 1;
					else if(curAnim >= character.jsonFile.animations.length) curAnim = 0;

					character.playAnim(character.jsonFile.animations[curAnim].anim);
					animText.text = 'Animation: ' + character.jsonFile.animations[curAnim].anim + ' (' + (curAnim + 1) +' / ' + character.jsonFile.animations.length + ') - Press W or S to scroll';
				}
				lastTab = UI_mainbox.selectedName;
				currentGhosts = 0;
			}

			if(UI_mainbox.selectedName == Language.get('dialogueCharacterEditor_character', 'Character'))
			{
				var negaMult:Array<Int> = [1, -1];
				var controlAnim:Array<Bool> = [FlxG.keys.justPressed.W, FlxG.keys.justPressed.S];

				if(controlAnim.contains(true))
				{
					for (i in 0...controlAnim.length) {
						if(controlAnim[i] && character.jsonFile.animations.length > 0) {
							curAnim -= negaMult[i];
							if(curAnim < 0) curAnim = character.jsonFile.animations.length - 1;
							else if(curAnim >= character.jsonFile.animations.length) curAnim = 0;

							var animToPlay:String = character.jsonFile.animations[curAnim].anim;
							if(character.dialogueAnimations.exists(animToPlay)) {
								character.playAnim(animToPlay, daText.finishedText);
							}
						}
					}
					animText.text = 'Animation: ' + character.jsonFile.animations[curAnim].anim + ' (' + (curAnim + 1) +' / ' + character.jsonFile.animations.length + ') - Press W or S to scroll';
				}
			}

			if(#if android FlxG.android.justPressed.BACK ||  virtualPad.buttonB.justPressed || #end FlxG.keys.justPressed.ESCAPE) {
				confirmExitDialogueChar();
				FlxG.sound.playMusic(Paths.music('freakyMenu'), 1);
				transitioning = true;
			}

			ghostLoop.setPosition(character.x, character.y);
			ghostIdle.setPosition(character.x, character.y);
			hudGroup.x = mainGroup.x;
			hudGroup.y = mainGroup.y;
		}
		super.update(elapsed);
	}

	var fileDialog:FileDialogHandler = new FileDialogHandler();

	function loadCharacter() {
		var jsonFilter:FileFilter = new FileFilter('JSON', 'json');
		fileDialog.open(null, null, [jsonFilter], function() {
			onLoadComplete();
		}, function() {
			onLoadCancel();
		}, function() {
			onLoadError();
		});
	}

	function onLoadComplete(?_):Void
	{
		#if sys
		var rawJson:String = fileDialog.data;
		if(rawJson != null) {
			var loadedChar:DialogueCharacterFile = cast Json.parse(rawJson);
			if(loadedChar.dialogue_pos != null)
			{
				var cutName:String = '';
				if(fileDialog.path != null)
				{
					var pathParts:Array<String> = fileDialog.path.split('\\');
					if(pathParts.length == 1) pathParts = fileDialog.path.split('/');
					var fileName:String = pathParts[pathParts.length - 1];
					if(fileName != null && fileName.length > 5) cutName = fileName.substr(0, fileName.length - 5);
				}
				CoolUtil.traceMsg('trace.fileLoaded', 'Successfully loaded file: {}', [cutName]);
				character.jsonFile = loadedChar;
				reloadCharacter();
				reloadAnimationsDropDown();
				updateCharTypeBox();
				updateTextBox();
				daText.resetDialogue();
				imageInputText.text = character.jsonFile.image;
				scaleStepper.value = character.jsonFile.scale;
				xStepper.value = character.jsonFile.position[0];
				yStepper.value = character.jsonFile.position[1];
				return;
			}
		}
		#else
		CoolUtil.traceMsg('trace.notDesktop', "File couldn't be loaded! You aren't on Desktop, are you?");
		#end
	}

	function onLoadCancel(?_):Void
	{
		CoolUtil.traceMsg('trace.fileCancelled', "Cancelled file loading.");
	}

	function onLoadError(?_):Void
	{
		CoolUtil.traceMsg('trace.fileProblemSimple', "Problem loading file");
	}

	function saveCharacter() {
		var data:String = Json.stringify(character.jsonFile, "\t");
		if (data.length > 0)
		{
			var splittedImage:Array<String> = imageInputText.text.trim().split('_');
			var characterName:String = splittedImage[0].toLowerCase().replace(' ', '');
			fileDialog.save(characterName, data, function() {
				onSaveComplete();
			}, function() {
				onSaveCancel();
			}, function() {
				onSaveError();
			});
		}
	}

	function onSaveComplete(?_):Void
	{
		FlxG.log.notice("Successfully saved file.");
	}

	function onSaveCancel(?_):Void
	{
		// user cancelled save
	}

	function onSaveError(?_):Void
	{
		FlxG.log.error("Problem saving file");
	}

	function ClipboardAdd(prefix:String = ''):String {
		if(prefix.toLowerCase().endsWith('v'))
		{
			prefix = prefix.substring(0, prefix.length-1);
		}

		var text:String = prefix + Clipboard.text.replace('\n', '');
		return text;
	}
}
