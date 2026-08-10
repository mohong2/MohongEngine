package editors;

#if cpp
import Discord.DiscordClient;
#end

import flixel.addons.display.FlxGridOverlay;
import flixel.addons.transition.FlxTransitionableState;
import flixel.system.FlxSound;
import flixel.ui.FlxButton;

import openfl.events.Event;
import openfl.events.IOErrorEvent;
import flash.net.FileFilter;
import haxe.Json;
import DialogueBoxPsych;
import lime.system.Clipboard;
import Alphabet;
import backend.ui.*;
import editors.content.FileDialogHandler;
#if sys
import sys.io.File;
#end

using StringTools;

class DialogueEditorState extends MusicBeatState implements PsychUIEventHandler.PsychUIEvent
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
	function confirmExitDialogue():Void
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
	var box:FlxSprite;
	var daText:TypedAlphabet;

	var selectedText:EditorsText;
	var animText:EditorsText;

	var defaultLine:DialogueLine;
	var dialogueFile:DialogueFile = null;

	override function create() {
		persistentUpdate = persistentDraw = true;
		FlxG.camera.bgColor = FlxColor.fromHSL(0, 0, 0.5);

		defaultLine = {
			portrait: DialogueCharacter.DEFAULT_CHARACTER,
			expression: 'talk',
			text: DEFAULT_TEXT,
			boxState: DEFAULT_BUBBLETYPE,
			speed: 0.05,
			sound: ''
		};

		dialogueFile = {
			dialogue: [
				copyDefaultLine()
			]
		};

		character = new DialogueCharacter();
		character.scrollFactor.set();
		add(character);

		box = new FlxSprite(70, 370);
		box.frames = Paths.getSparrowAtlas('speech_bubble');
		box.scrollFactor.set();
		box.antialiasing = ClientPrefs.data.globalAntialiasing;
		box.animation.addByPrefix('normal', 'speech bubble normal', 24);
		box.animation.addByPrefix('angry', 'AHH speech bubble', 24);
		box.animation.addByPrefix('center', 'speech bubble middle', 24);
		box.animation.addByPrefix('center-angry', 'AHH Speech Bubble middle', 24);
		box.animation.play('normal', true);
		box.setGraphicSize(Std.int(box.width * 0.9));
		box.updateHitbox();
		add(box);

		addEditorBox();
		FlxG.mouse.visible = true;

		var addLineText:EditorsText = new EditorsText(10, 10, FlxG.width - 20, 'Press O to remove the current dialogue line, Press P to add another line after the current one.', 8);
		addLineText.setFormat(Paths.font("editors.ttf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		addLineText.scrollFactor.set();
		add(addLineText);

		selectedText = new EditorsText(10, 32, FlxG.width - 20, '', 8);
		selectedText.setFormat(Paths.font("editors.ttf"), 24, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		selectedText.scrollFactor.set();
		add(selectedText);

		animText = new EditorsText(10, 62, FlxG.width - 20, '', 8);
		animText.setFormat(Paths.font("editors.ttf"), 24, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		animText.scrollFactor.set();
		add(animText);

		daText = new TypedAlphabet(DialogueBoxPsych.DEFAULT_TEXT_X, DialogueBoxPsych.DEFAULT_TEXT_Y, DEFAULT_TEXT);
		daText.scaleX = 0.7;
		daText.scaleY = 0.7;
		add(daText);
		changeText();
		#if (android || desktop)
		addVirtualPad(LEFT_FULL, A_B_X_Y);
		#end
		super.create();
	}

	var UI_box:PsychUIBox;
	function addEditorBox() {
		var tabs = [
			Language.get('dialogueEditor_dialogue_line', 'Dialogue Line')
		];
		UI_box = new PsychUIBox(FlxG.width - 260, 10, 250, 210, tabs);
		UI_box.scrollFactor.set();
		UI_box.alpha = 0.8;
		addDialogueLineUI();
		add(UI_box);
		for (tab in UI_box.tabs) tab.text.font = 'assets/fonts/editors.ttf';
	}

	var characterInputText:PsychUIInputText;
	var lineInputText:PsychUIInputText;
	var angryCheckbox:PsychUICheckBox;
	var speedStepper:PsychUINumericStepper;
	var soundInputText:PsychUIInputText;
	function addDialogueLineUI() {
		var tab = UI_box.getTab(Language.get('dialogueEditor_dialogue_line', 'Dialogue Line'));
		if(tab == null) return;
		var tab_menu = tab.menu;

		characterInputText = new PsychUIInputText(10, 20, 80, DialogueCharacter.DEFAULT_CHARACTER, 8);
		blockPressWhileTypingOn.push(characterInputText);
		characterInputText.onChange = function(oldText:String, newText:String) {
			character.reloadCharacterJson(newText);
			reloadCharacter();
			if(character.jsonFile.animations.length > 0) {
				curAnim = 0;
				if(character.jsonFile.animations.length > curAnim && character.jsonFile.animations[curAnim] != null) {
					character.playAnim(character.jsonFile.animations[curAnim].anim, daText.finishedText);
					animText.text = 'Animation: ' + character.jsonFile.animations[curAnim].anim + ' (' + (curAnim + 1) +' / ' + character.jsonFile.animations.length + ') - Press W or S to scroll';
				} else {
					animText.text = 'ERROR! NO ANIMATIONS FOUND';
				}
				characterAnimSpeed();
			}
			dialogueFile.dialogue[curSelected].portrait = newText;
			reloadText(false);
			updateTextBox();
		};

		speedStepper = new PsychUINumericStepper(10, characterInputText.y + 40, 0.005, 0.05, 0, 0.5, 3);
		speedStepper.textObj.font = 'assets/fonts/editors.ttf';
		speedStepper.onValueChange = function() {
			dialogueFile.dialogue[curSelected].speed = speedStepper.value;
			if(Math.isNaN(dialogueFile.dialogue[curSelected].speed) || dialogueFile.dialogue[curSelected].speed == null || dialogueFile.dialogue[curSelected].speed < 0.001) {
				dialogueFile.dialogue[curSelected].speed = 0.0;
			}
			daText.delay = dialogueFile.dialogue[curSelected].speed;
			reloadText(false);
		};

		angryCheckbox = new PsychUICheckBox(speedStepper.x + 120, speedStepper.y, Language.get('dialogueEditor_angry_textbox', 'Angry Textbox'), 200, null);
		angryCheckbox.onClick = function() {
			updateTextBox();
			dialogueFile.dialogue[curSelected].boxState = (angryCheckbox.checked ? 'angry' : 'normal');
		};

		soundInputText = new PsychUIInputText(10, speedStepper.y + 40, 150, '', 8);
		blockPressWhileTypingOn.push(soundInputText);
		soundInputText.onChange = function(oldText:String, newText:String) {
			daText.finishText();
			dialogueFile.dialogue[curSelected].sound = newText;
			daText.sound = newText;
			if(daText.sound == null) daText.sound = '';
		};

		lineInputText = new PsychUIInputText(10, soundInputText.y + 35, 200, DEFAULT_TEXT, 8);
		blockPressWhileTypingOn.push(lineInputText);
		lineInputText.onChange = function(oldText:String, newText:String) {
			dialogueFile.dialogue[curSelected].text = newText;
			daText.text = newText;
			if(daText.text == null) daText.text = '';
			reloadText(true);
		};

		var loadButton = new PsychUIButton(20, lineInputText.y + 25, Language.get('dialogueEditor_load_dialogue', 'Load Dialogue'), function() {
			loadDialogue();
		}, 80, 20);
		var saveButton = new PsychUIButton(loadButton.x + 120, loadButton.y, Language.get('dialogueEditor_save_dialogue', 'Save Dialogue'), function() {
			saveDialogue();
		}, 80, 20);

		tab_menu.add(new EditorsText(10, speedStepper.y - 18, 0, Language.get('dialogueEditor_speed', 'Interval/Speed (ms):')));
		tab_menu.add(new EditorsText(10, characterInputText.y - 18, 0, Language.get('dialogueEditor_character', 'Character:')));
		tab_menu.add(new EditorsText(10, soundInputText.y - 18, 0, Language.get('dialogueEditor_sound_file', 'Sound file name:')));
		tab_menu.add(new EditorsText(10, lineInputText.y - 18, 0, Language.get('dialogueEditor_text', 'Text:')));
		tab_menu.add(characterInputText);
		tab_menu.add(angryCheckbox);
		tab_menu.add(speedStepper);
		tab_menu.add(soundInputText);
		tab_menu.add(lineInputText);
		tab_menu.add(loadButton);
		tab_menu.add(saveButton);
	}

	function copyDefaultLine():DialogueLine {
		var copyLine:DialogueLine = {
			portrait: defaultLine.portrait,
			expression: defaultLine.expression,
			text: defaultLine.text,
			boxState: defaultLine.boxState,
			speed: defaultLine.speed,
			sound: ''
		};
		return copyLine;
	}

	function updateTextBox() {
		box.flipX = false;
		var isAngry:Bool = angryCheckbox.checked;
		var anim:String = isAngry ? 'angry' : 'normal';

		switch(character.jsonFile.dialogue_pos) {
			case 'left':
				box.flipX = true;
			case 'center':
				if(isAngry) {
					anim = 'center-angry';
				} else {
					anim = 'center';
				}
		}
		box.animation.play(anim, true);
		DialogueBoxPsych.updateBoxOffsets(box);
	}

	function reloadCharacter() {
		character.frames = Paths.getSparrowAtlas('dialogue/' + character.jsonFile.image);
		character.jsonFile = character.jsonFile;
		character.reloadAnimations();
		character.setGraphicSize(Std.int(character.width * DialogueCharacter.DEFAULT_SCALE * character.jsonFile.scale));
		character.updateHitbox();
		character.x = DialogueBoxPsych.LEFT_CHAR_X;
		character.y = DialogueBoxPsych.DEFAULT_CHAR_Y;

		switch(character.jsonFile.dialogue_pos) {
			case 'right':
				character.x = FlxG.width - character.width + DialogueBoxPsych.RIGHT_CHAR_X;

			case 'center':
				character.x = FlxG.width / 2;
				character.x -= character.width / 2;
		}
		character.x += character.jsonFile.position[0];
		character.y += character.jsonFile.position[1];
		character.playAnim();
		characterAnimSpeed();

		if(character.animation.curAnim != null && character.jsonFile.animations != null) {
			animText.text = 'Animation: ' + character.jsonFile.animations[curAnim].anim + ' (' + (curAnim + 1) +' / ' + character.jsonFile.animations.length + ') - Press W or S to scroll';
		} else {
			animText.text = 'ERROR! NO ANIMATIONS FOUND';
		}
	}

	private static var DEFAULT_TEXT:String = "coolswag";
	private static var DEFAULT_SPEED:Float = 0.05;
	private static var DEFAULT_BUBBLETYPE:String = "normal";
	function reloadText(skipDialogue:Bool) {
		var textToType:String = lineInputText.text;
		if(textToType == null || textToType.length < 1) textToType = ' ';

		daText.text = textToType;
		daText.resetDialogue();

		if(skipDialogue)
			daText.finishText();
		else if(daText.delay > 0)
		{
			if(character.jsonFile.animations.length > curAnim && character.jsonFile.animations[curAnim] != null) {
				character.playAnim(character.jsonFile.animations[curAnim].anim);
			}
			characterAnimSpeed();
		}

		daText.y = DialogueBoxPsych.DEFAULT_TEXT_Y;
		if(daText.rows > 2) daText.y -= DialogueBoxPsych.LONG_TEXT_ADD;

		#if cpp
		var rpcText:String = lineInputText.text;
		if(rpcText == null || rpcText.length < 1) rpcText = '(Empty)';
		if(rpcText.length < 3) rpcText += '   ';
		DiscordClient.changePresence("Dialogue Editor", rpcText);
		#end
	}

	public function UIEvent(id:String, sender:Dynamic) {
		// events handled via callbacks
	}

	var curSelected:Int = 0;
	var curAnim:Int = 0;
	var blockPressWhileTypingOn:Array<PsychUIInputText> = [];
	var transitioning:Bool = false;
	override function update(elapsed:Float) {
		if(transitioning) {
			super.update(elapsed);
			return;
		}

		if(character.animation.curAnim != null) {
			if(daText.finishedText) {
				if(character.animationIsLoop() && character.animation.curAnim.finished) {
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

				if(FlxG.keys.justPressed.ENTER) {
					if(inputText == lineInputText) {
						inputText.text += '\\n';
						inputText.caretIndex += 2;
					} else {
						PsychUIInputText.focusOn = null;
					}
				}
				break;
			}
		}

		if(!blockInput) {
			FlxG.sound.muteKeys = TitleState.muteKeys;
			FlxG.sound.volumeDownKeys = TitleState.volumeDownKeys;
			FlxG.sound.volumeUpKeys = TitleState.volumeUpKeys;
			if(#if (android || desktop) (virtualPad != null && virtualPad.buttonY.justPressed) || #end FlxG.keys.justPressed.SPACE) {
				reloadText(false);
			}
			if(#if (android || desktop) (virtualPad != null && virtualPad.buttonB.justPressed) || #end FlxG.keys.justPressed.ESCAPE) {
				confirmExitDialogue();
				FlxG.sound.playMusic(Paths.music('freakyMenu'), 1);
				transitioning = true;
			}
			var negaMult:Array<Int> = [1, -1];
			var controlAnim:Array<Bool> = [FlxG.keys.justPressed.W #if (android || desktop) || (virtualPad != null && virtualPad.buttonUp.justPressed) #end, FlxG.keys.justPressed.S #if (android || desktop) || (virtualPad != null && virtualPad.buttonDown.justPressed)#end ];
			var controlText:Array<Bool> = [FlxG.keys.justPressed.D	#if (android || desktop) || (virtualPad != null && virtualPad.buttonRight.justPressed) #end , FlxG.keys.justPressed.A #if (android || desktop) || (virtualPad != null && virtualPad.buttonLeft.justPressed) #end];
			for (i in 0...controlAnim.length) {
				if(controlAnim[i] && character.jsonFile.animations.length > 0) {
					curAnim -= negaMult[i];
					if(curAnim < 0) curAnim = character.jsonFile.animations.length - 1;
					else if(curAnim >= character.jsonFile.animations.length) curAnim = 0;

					var animToPlay:String = character.jsonFile.animations[curAnim].anim;
					if(character.dialogueAnimations.exists(animToPlay)) {
						character.playAnim(animToPlay, daText.finishedText);
						dialogueFile.dialogue[curSelected].expression = animToPlay;
					}
					animText.text = 'Animation: ' + animToPlay + ' (' + (curAnim + 1) +' / ' + character.jsonFile.animations.length + ') - Press W or S to scroll';
				}
				if(controlText[i]) {
					changeText(negaMult[i]);
				}
			}

			if(#if (android || desktop) (virtualPad != null && virtualPad.buttonA.justPressed) ||#end FlxG.keys.justPressed.O) {
				dialogueFile.dialogue.remove(dialogueFile.dialogue[curSelected]);
				if(dialogueFile.dialogue.length < 1)
				{
					dialogueFile.dialogue = [
						copyDefaultLine()
					];
				}
				changeText();
			} else if(#if (android || desktop) (virtualPad != null && virtualPad.buttonX.justPressed) ||#end FlxG.keys.justPressed.P) {
				dialogueFile.dialogue.insert(curSelected + 1, copyDefaultLine());
				changeText(1);
			}
		}
		super.update(elapsed);
	}

	function changeText(add:Int = 0) {
		curSelected += add;
		if(curSelected < 0) curSelected = dialogueFile.dialogue.length - 1;
		else if(curSelected >= dialogueFile.dialogue.length) curSelected = 0;

		var curDialogue:DialogueLine = dialogueFile.dialogue[curSelected];
		characterInputText.text = curDialogue.portrait;
		lineInputText.text = curDialogue.text;
		angryCheckbox.checked = (curDialogue.boxState == 'angry');
		speedStepper.value = curDialogue.speed;

		if (curDialogue.sound == null) curDialogue.sound = '';
		soundInputText.text = curDialogue.sound;

		daText.delay = speedStepper.value;
		daText.sound = soundInputText.text;
		if(daText.sound != null && daText.sound.trim() == '') daText.sound = 'dialogue';

		curAnim = 0;
		character.reloadCharacterJson(characterInputText.text);
		reloadCharacter();
		reloadText(false);
		updateTextBox();

		var leLength:Int = character.jsonFile.animations.length;
		if(leLength > 0) {
			for (i in 0...leLength) {
				var leAnim:DialogueAnimArray = character.jsonFile.animations[i];
				if(leAnim != null && leAnim.anim == curDialogue.expression) {
					curAnim = i;
					break;
				}
			}
			character.playAnim(character.jsonFile.animations[curAnim].anim, daText.finishedText);
			animText.text = 'Animation: ' + character.jsonFile.animations[curAnim].anim + ' (' + (curAnim + 1) +' / ' + leLength + ') - Press W or S to scroll';
		} else {
			animText.text = 'ERROR! NO ANIMATIONS FOUND';
		}
		characterAnimSpeed();

		selectedText.text = 'Line: (' + (curSelected + 1) + ' / ' + dialogueFile.dialogue.length + ') - Press A or D to scroll';
	}

	function characterAnimSpeed() {
		if(character.animation.curAnim != null) {
			var speed:Float = speedStepper.value;
			var rate:Float = 24 - (((speed - 0.05) / 5) * 480);
			if(rate < 12) rate = 12;
			else if(rate > 48) rate = 48;
			character.animation.curAnim.frameRate = rate;
		}
	}

	var fileDialog:FileDialogHandler = new FileDialogHandler();
	function loadDialogue() {
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
			var loadedDialog:DialogueFile = cast Json.parse(rawJson);
			if(loadedDialog.dialogue != null && loadedDialog.dialogue.length > 0)
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
				dialogueFile = loadedDialog;
				changeText();
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

	function saveDialogue() {
		var data:String = Json.stringify(dialogueFile, "\t");
		if (data.length > 0)
		{
			fileDialog.save('dialogue', data, function() {
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
}
