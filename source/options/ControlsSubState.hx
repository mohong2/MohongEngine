package options;

import flixel.addons.display.FlxBackdrop;
#if cpp
import Discord.DiscordClient;
#end
import flash.text.TextField;
import flixel.addons.display.FlxGridOverlay;
import lime.utils.Assets;
import flixel.FlxSubState;
import flash.text.TextField;
import flixel.util.FlxSave;
import haxe.Json;
import flixel.input.keyboard.FlxKey;
import flixel.input.gamepad.FlxGamepadInputID;
import flixel.graphics.FlxGraphic;
import Controls;
import FlxTextMenuItem;
import FlxTextMenuItem.FlxTextAttached;
import flixel.addons.transition.FlxTransitionableState;

using StringTools;
import mohong.TraceManager;

class ControlsSubState extends MusicBeatSubstate {
	private static var curSelected:Int = 1;
	private static var curAlt:Bool = false;

	private static var defaultKey:String = 'Reset to Default Keys';
	private var bindLength:Int = 0;

	var onKeyboardMode:Bool = true;

	var optionShit:Array<Dynamic> = [
		[true, 'NOTES'],
		[true, 'controls.left', 'note_left'],
		[true, 'controls.down', 'note_down'],
		[true, 'controls.up', 'note_up'],
		[true, 'controls.right', 'note_right'],
		[true],
		[true, 'UI'],
		[true, 'controls.ui_left', 'ui_left'],
		[true, 'controls.ui_down', 'ui_down'],
		[true, 'controls.ui_up', 'ui_up'],
		[true, 'controls.ui_right', 'ui_right'],
		[true],
		[true, 'controls.reset', 'reset'],
		[true, 'controls.accept', 'accept'],
		[true, 'controls.back', 'back'],
		[true, 'controls.pause', 'pause'],
		[true],
		[false, 'VOLUME'],
		[false, 'controls.mute', 'volume_mute'],
		[false, 'controls.volume_up', 'volume_up'],
		[false, 'controls.volume_down', 'volume_down'],
		[false],
		[false, 'DEBUG'],
		[false, 'controls.debug_1', 'debug_1'],
		[false, 'controls.debug_2', 'debug_2']
	];

	private var grpOptions:FlxTypedGroup<FlxTextMenuItem>;
	private var grpInputs:Array<FlxTextAttached> = [];
	private var grpInputsAlt:Array<FlxTextAttached> = [];
	var rebindingKey:Bool = false;
	var nextAccept:Int = 5;

	var bg:FlxSprite;

	var controllerSpr:FlxSprite;
	var gamepadColor:FlxColor = 0xfffd7194;
	var keyboardColor:FlxColor = 0xff17719b;
	var colorTween:FlxTween;

	static var gamepadRebindDialogCount:Int = 0;

	public function new() {
		super();

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Controls Menu", null);
		#end

		bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.color = 0xff17719b;
		bg.screenCenter();
		bg.antialiasing = ClientPrefs.data.globalAntialiasing;
		add(bg);

		var grid:FlxBackdrop = new FlxBackdrop(FlxGridOverlay.createGrid(80, 80, 160, 160, true, 0x33FFFFFF, 0x0));
		grid.velocity.set(40, 40);
		grid.alpha = 0;
		FlxTween.tween(grid, {alpha: 1}, 0.5, {ease: FlxEase.quadOut});
		add(grid);

		grpOptions = new FlxTypedGroup<FlxTextMenuItem>();
		add(grpOptions);

		controllerSpr = new FlxSprite(50, 40).loadGraphic(Paths.image('controllertype'), true, 82, 60);
		controllerSpr.antialiasing = ClientPrefs.data.globalAntialiasing;
		controllerSpr.animation.add('keyboard', [0], 1, false);
		controllerSpr.animation.add('gamepad', [1], 1, false);
		add(controllerSpr);

		var ctrlLabel:Alphabet = new Alphabet(60, 90, 'CTRL', false);
		ctrlLabel.alignment = CENTERED;
		ctrlLabel.setScale(0.4);
		add(ctrlLabel);

		// Will be built in createTexts()
		createTexts();
		#if android
		addVirtualPad(LEFT_FULL, A_B);
		addPadCamera();
		#end
	}

	function swapMode()
	{
		if(colorTween != null) colorTween.destroy();
		colorTween = FlxTween.color(bg, 0.5, bg.color, onKeyboardMode ? gamepadColor : keyboardColor, {ease: FlxEase.linear});
		onKeyboardMode = !onKeyboardMode;

		curSelected = 0;
		curAlt = false;
		controllerSpr.animation.play(onKeyboardMode ? 'keyboard' : 'gamepad');
		createTexts();
	}

	var lastID:Int = 0;

	function createTexts()
	{
		// Append the default-key reset option if not already present
		if(optionShit.length == 0 || optionShit[optionShit.length - 1].length < 2 || optionShit[optionShit.length - 1][1] != defaultKey) {
			optionShit.push([true]);
			optionShit.push([true, defaultKey]);
		}

		// Clear existing items
		grpOptions.forEachAlive(function(text:FlxTextMenuItem) text.destroy());
		grpOptions.clear();
		while(grpInputs.length > 0) {
			var item:FlxTextAttached = grpInputs[0];
			grpInputs.remove(item);
			item.destroy();
		}
		while(grpInputsAlt.length > 0) {
			var item:FlxTextAttached = grpInputsAlt[0];
			grpInputsAlt.remove(item);
			item.destroy();
		}

		curOptions = [];
		curOptionsValid = [];
		bindLength = 0;
		var myID:Int = 0;
		for (i in 0...optionShit.length) {
			var option:Array<Dynamic> = optionShit[i];
			var showOption:Bool = (option[0] == true) || onKeyboardMode;
			if(!showOption) { myID++; continue; }

			var isCentered:Bool = (option.length < 3);
			var isDefaultKey:Bool = (option[Std.int(option.length - 1)] == defaultKey);
			if(unselectableCheck(i, true)) {
				isCentered = !isDefaultKey;
			}

			var displayText:String;
			if(isDefaultKey) {
				displayText = Language.get('controls.reset_to_default', defaultKey);
			} else if(isCentered) {
				displayText = (option.length > 1 && option[1] != null) ? option[1] : '';
			} else {
				displayText = Language.get(option[1], option[1]);
			}

			var optionText:FlxTextMenuItem = new FlxTextMenuItem(200, 300, displayText, 48);
			optionText.isMenuItem = true;
			if(isCentered) {
				optionText.screenCenter(X);
				optionText.y -= 55;
				optionText.startPosition.y -= 55;
			}
			optionText.changeX = false;
			optionText.distancePerItem.y = 60;
			optionText.targetY = myID;
			optionText.ID = myID;
			optionText.snapToPosition();
			optionText.y += FlxG.height * 2;
			grpOptions.add(optionText);

			if(!isCentered) {
				curOptions.push(i);
				curOptionsValid.push(myID);
				if(option.length > 2) { 
					addBindTexts(optionText, i);
					bindLength++;
				}
			}
			lastID = myID;
			myID++;
		}
		updateText();
	}

	var curOptions:Array<Int>;
	var curOptionsValid:Array<Int>;
	function getInputTextNum() {
		var num:Int = 0;
		for (i in 0...curSelected) {
			var realIndex:Int = curOptions[i];
			if(optionShit[realIndex].length > 2) {
				num++;
			}
		}
		return num;
	}

	function updateText(?move:Int = 0)
	{
		if(move != 0)
		{
			curSelected += move;

			if(curSelected < 0) curSelected = curOptions.length - 1;
			else if (curSelected >= curOptions.length) curSelected = 0;
		}

		var num:Int = curOptionsValid[curSelected];
		var addNum:Int = 0;
		if(num < 3) addNum = 3 - num;
		else if(num > lastID - 4) addNum = (lastID - 4) - num;

		for (item in grpOptions.members) {
			item.targetY = item.ID - num - addNum;
			var isSelectable = (curOptions.indexOf(item.ID) != -1);
			if(isSelectable) {
				item.alpha = (item.ID - num == 0) ? 1 : 0.6;
			} else {
				item.alpha = 1;
			}
		}

		for (i in 0...grpInputs.length) {
			grpInputs[i].alpha = 0.6;
		}
		for (i in 0...grpInputsAlt.length) {
			grpInputsAlt[i].alpha = 0.6;
		}
		if(curSelected >= 0 && curSelected < curOptionsValid.length) {
			var selID:Int = curOptionsValid[curSelected];
			if(curAlt) {
				for (i in 0...grpInputsAlt.length) {
					if(grpInputsAlt[i].ID == selID) {
						grpInputsAlt[i].alpha = 1;
						break;
					}
				}
			} else {
				for (i in 0...grpInputs.length) {
					if(grpInputs[i].ID == selID) {
						grpInputs[i].alpha = 1;
						break;
					}
				}
			}
		}
		FlxG.sound.play(Paths.sound('scrollMenu'));
	}

	var bindingBlack:FlxSprite;
	var bindingText:FlxTextMenuItem;
	var bindingText2:FlxTextMenuItem;

	var leaving:Bool = false;
	var bindingTime:Float = 0;
	var timeForMoving:Float = 0.1;
	override function update(elapsed:Float) {
		if(timeForMoving > 0)
		{
			timeForMoving = Math.max(0, timeForMoving - elapsed);
			super.update(elapsed);
			return;
		}

		if(!rebindingKey) {
			if(FlxG.keys.justPressed.CONTROL || FlxG.gamepads.anyJustPressed(LEFT_SHOULDER) || FlxG.gamepads.anyJustPressed(RIGHT_SHOULDER)) swapMode();

			if (controls.UI_UP_P) {
				changeSelection(-1);
			}
			if (controls.UI_DOWN_P) {
				changeSelection(1);
			}
			if (controls.UI_LEFT_P || controls.UI_RIGHT_P) {
				changeAlt();
			}

			if (controls.BACK) {
				ClientPrefs.reloadControls();
				FlxTransitionableState.skipNextTransOut = true;
				FlxG.resetState();
				FlxG.sound.play(Paths.sound('cancelMenu'));
			}

			if(controls.ACCEPT && nextAccept <= 0) {
				var realIndex:Int = curOptions[curSelected];
				if(optionShit[realIndex][Std.int(optionShit[realIndex].length - 1)] == defaultKey) {
					// Reset to Default - also reset gamepad binds
					ClientPrefs.resetKeys();
					ClientPrefs.reloadVolumeKeys(); // 立即清理 NONE 并同步音量键
					ClientPrefs.reloadControls();   // 立即刷新 Controls 系统

					reloadKeys();
					changeSelection();
					FlxG.sound.play(Paths.sound('confirmMenu'));
				} else if(!unselectableCheck(realIndex)) {
					startBinding();
				}
			}
		} else {
			updateBinding(elapsed);
		}
	
		if(nextAccept > 0) {
			nextAccept -= 1;
		}
		super.update(elapsed);
	}

	function startBinding()
	{
		var realIndex:Int = curOptions[curSelected];
		bindingBlack = new FlxSprite().makeGraphic(1, 1, /*FlxColor.BLACK*/ FlxColor.WHITE);
		bindingBlack.scale.set(FlxG.width, FlxG.height);
		bindingBlack.updateHitbox();
		bindingBlack.alpha = 0;
		FlxTween.tween(bindingBlack, {alpha: 0.6}, 0.35, {ease: FlxEase.linear});
		add(bindingBlack);

		bindingText = new FlxTextMenuItem(0, 160, Language.get("controls.rebinding_prefix", "Rebinding") + " " + Language.get(optionShit[realIndex][1], optionShit[realIndex][1]), 48);
		bindingText.fieldWidth = FlxG.width;
		bindingText.alignment = CENTER;
		add(bindingText);
		
		bindingText2 = new FlxTextMenuItem(0, 340, Language.get("controls.rebinding_hint", "Hold ESC to Cancel\nHold Backspace to Delete"), 48);
		bindingText2.fieldWidth = FlxG.width;
		bindingText2.alignment = CENTER;
		add(bindingText2);

		bindingTime = 0;
		rebindingKey = true;
		if (curAlt) {
			grpInputsAlt[getInputTextNum()].alpha = 0;
		} else {
			grpInputs[getInputTextNum()].alpha = 0;
		}
		FlxG.sound.play(Paths.sound('scrollMenu'));

		// Disable volume hotkeys while rebinding (prevents volume twitching)
		ClientPrefs.toggleVolumeKeys(false);
	}

	function updateBinding(?elapsed:Float = 0)
	{
		var altNum:Int = curAlt ? 1 : 0;
		var realIndex:Int = curOptions[curSelected];
		var curOption:String = optionShit[realIndex][2];

		// === Universal cancel/delete (works for keyboard AND gamepad in ANY mode) ===
		if (FlxG.keys.justPressed.ESCAPE) {
			// ESC always cancels immediately — no long press needed
			finishBindingCancel();
			FlxG.sound.play(Paths.sound('cancelMenu'));
			return;
		}
		if (FlxG.keys.justPressed.BACKSPACE) {
			// Backspace always clears the current slot immediately
			finishBindingDelete(curOption, altNum);
			FlxG.sound.play(Paths.sound('confirmMenu'));
			return;
		}

		// Long-press ESC/B or Backspace/Back for gamepad-style
		if(FlxG.keys.pressed.ESCAPE || FlxG.keys.pressed.BACKSPACE
			|| FlxG.gamepads.anyPressed(B) || FlxG.gamepads.anyPressed(BACK)
		)
		{
			bindingTime += elapsed;
			if(bindingTime > 0.5)
			{
				if(FlxG.keys.pressed.ESCAPE || (FlxG.gamepads.anyPressed(B)))
				{
					finishBindingCancel();
					FlxG.sound.play(Paths.sound('cancelMenu'));
				}
				else
				{
					finishBindingDelete(curOption, altNum);
					FlxG.sound.play(Paths.sound('cancelMenu'));
				}
			}
			return;
		}

		bindingTime = 0;

		// === Detect new key/button press ===
		if(!onKeyboardMode)
		{
			// Detect any keyboard key press (other than ESC/Backspace which are handled above)
			// while in gamepad rebinding mode, and show a friendly warning dialog.
			// Also triggers when pressing Enter/Accept — the universal handler above won't
			// catch it because Accept starts the binding, not during binding.
			var kbKey:Int = FlxG.keys.firstJustPressed();
			if(kbKey > -1 && kbKey != FlxKey.ESCAPE && kbKey != FlxKey.BACKSPACE)
			{
				gamepadRebindDialogCount++;
				var msg:String = Language.get('controls.hint_clown', "If you pressed Accept in Gamepad mode and nothing happened…\nnext time don't come to this setting without a controller!");
				if(gamepadRebindDialogCount > 1)
				{
					var countText:String = Language.get('controls.hint_attempt_count', 'Press count: {1}');
					countText = StringTools.replace(countText, '{1}', Std.string(gamepadRebindDialogCount));
					msg += '\n\n' + countText;
				}
				backend.Dialog.show(
					Language.get('controls.hint_swap', 'Press Ctrl or Shoulder buttons to toggle Keyboard/Gamepad mode'),
					msg,
					'Info'
				);
			}

			// Gamepad rebinding
			var changed:Bool = false;
			var curButtons:Array<FlxGamepadInputID> = ClientPrefs.gamepadBinds.get(curOption);

			if(FlxG.gamepads.anyJustPressed(ANY) || FlxG.gamepads.anyJustPressed(LEFT_TRIGGER) || FlxG.gamepads.anyJustPressed(RIGHT_TRIGGER) || FlxG.gamepads.anyJustReleased(ANY))
			{
				var keyPressed:Null<FlxGamepadInputID> = NONE;
				var keyReleased:Null<FlxGamepadInputID> = NONE;
				if(FlxG.gamepads.anyJustPressed(LEFT_TRIGGER)) keyPressed = LEFT_TRIGGER;
				else if(FlxG.gamepads.anyJustPressed(RIGHT_TRIGGER)) keyPressed = RIGHT_TRIGGER;
				else
				{
					for (i in 0...FlxG.gamepads.numActiveGamepads)
					{
						var gamepad = FlxG.gamepads.getByID(i);
						if(gamepad != null)
						{
							keyPressed = gamepad.firstJustPressedID();
							keyReleased = gamepad.firstJustReleasedID();

							if(keyPressed == null) keyPressed = NONE;
							if(keyReleased == null) keyReleased = NONE;
							if(keyPressed != NONE || keyReleased != NONE) break;
						}
					}
				}

				if (keyPressed != NONE && keyPressed != FlxGamepadInputID.BACK && keyPressed != FlxGamepadInputID.B)
				{
					curButtons[altNum] = keyPressed;
					changed = true;
				}
				else if (keyReleased != NONE && (keyReleased == FlxGamepadInputID.BACK || keyReleased == FlxGamepadInputID.B))
				{
					curButtons[altNum] = keyReleased;
					changed = true;
				}
			}

			if(changed)
			{
				if(curButtons[altNum] == curButtons[1 - altNum])
					curButtons[1 - altNum] = FlxGamepadInputID.NONE;

				ClientPrefs.clearInvalidKeys(curOption);
				finishBindingDone(curOption);
				FlxG.sound.play(Paths.sound('confirmMenu'));
			}
		}
		else
		{
			// Keyboard rebinding
			var keyPressed:Int = FlxG.keys.firstJustPressed();
			if (keyPressed > -1) {
				var keysArray:Array<FlxKey> = ClientPrefs.keyBinds.get(curOption);
				keysArray[altNum] = keyPressed;
				
				var opposite:Int = (curAlt ? 0 : 1);
				if(keysArray[opposite] == keysArray[1 - opposite]) {
					keysArray[opposite] = NONE;
				}
				ClientPrefs.clearInvalidKeys(curOption);
				
				finishBindingDone(curOption);
				FlxG.sound.play(Paths.sound('confirmMenu'));
			}
			
			bindingTime += elapsed;
			if(bindingTime > 5) {
				finishBindingTimedOut();
			}
		}
	}

	// Helper: cancel binding, restore alpha
	function finishBindingCancel()
	{
		if (curAlt) {
			grpInputsAlt[getInputTextNum()].alpha = 1;
		} else {
			grpInputs[getInputTextNum()].alpha = 1;
		}
		closeBinding();
	}

	// Helper: clear current slot and close
	function finishBindingDelete(curOption:String, altNum:Int)
	{
		if(!onKeyboardMode)
		{
			var buttonsArray:Array<FlxGamepadInputID> = ClientPrefs.gamepadBinds.get(curOption);
			buttonsArray[altNum] = NONE;
		}
		else
		{
			var keysArray:Array<FlxKey> = ClientPrefs.keyBinds.get(curOption);
			keysArray[altNum] = NONE;
		}
		ClientPrefs.clearInvalidKeys(curOption);
		reloadKeys();
		closeBinding();
	}

	// Helper: rebind succeeded, just close
	function finishBindingDone(curOption:String)
	{
		reloadKeys();
		closeBinding();
	}

	// Helper: rebind timed out (5s no input)
	function finishBindingTimedOut()
	{
		if (curAlt) {
			grpInputsAlt[getInputTextNum()].alpha = 1;
		} else {
			grpInputs[getInputTextNum()].alpha = 1;
		}
		closeBinding();
		bindingTime = 0;
		FlxG.sound.play(Paths.sound('scrollMenu'));
	}

	function closeBinding()
	{
		rebindingKey = false;
		remove(bindingBlack);
		bindingText.destroy();
		remove(bindingText);
		bindingText2.destroy();
		remove(bindingText2);
		ClientPrefs.reloadVolumeKeys();
	}

	function changeSelection(change:Int = 0) {
		updateText(change);
	}

	function changeAlt() {
		curAlt = !curAlt;
		if(curSelected >= 0 && curSelected < curOptionsValid.length) {
			var selID:Int = curOptionsValid[curSelected];
			for (i in 0...grpInputs.length) {
				grpInputs[i].alpha = 0.6;
				if(grpInputs[i].ID == selID && !curAlt) {
					grpInputs[i].alpha = 1;
				}
			}
			for (i in 0...grpInputsAlt.length) {
				grpInputsAlt[i].alpha = 0.6;
				if(grpInputsAlt[i].ID == selID && curAlt) {
					grpInputsAlt[i].alpha = 1;
				}
			}
		}
		FlxG.sound.play(Paths.sound('scrollMenu'));
	}

	private function unselectableCheck(num:Int, ?checkDefaultKey:Bool = false):Bool {
		var option:Array<Dynamic> = optionShit[num];
		if(option[Std.int(option.length - 1)] == defaultKey) {
			return checkDefaultKey;
		}
		return option.length < 3;
	}

	private function addBindTexts(optionText:FlxTextMenuItem, num:Int) {
		var bindKey:String = optionShit[num][2];
		if(!onKeyboardMode) {
			var keys:Array<Dynamic> = ClientPrefs.gamepadBinds.get(bindKey);
			var text1 = new FlxTextAttached(InputFormatter.getGamepadName(keys[0]), 48);
			text1.offsetX = 290;
			text1.offsetY = 0;
			text1.sprTracker = optionText;
			text1.ID = optionText.ID;
			grpInputs.push(text1);
			add(text1);

			var text2 = new FlxTextAttached(InputFormatter.getGamepadName(keys[1]), 48);
			text2.offsetX = 620;
			text2.offsetY = 0;
			text2.sprTracker = optionText;
			text2.ID = optionText.ID;
			grpInputsAlt.push(text2);
			add(text2);
			return;
		}

		var keys:Array<Dynamic> = ClientPrefs.keyBinds.get(bindKey);
		var text1 = new FlxTextAttached(InputFormatter.getKeyName(keys[0]), 48);
		text1.offsetX = 400;
		text1.offsetY = 0;
		text1.sprTracker = optionText;
		text1.ID = optionText.ID;
		grpInputs.push(text1);
		add(text1);

		var text2 = new FlxTextAttached(InputFormatter.getKeyName(keys[1]), 48);
		text2.offsetX = 650;
		text2.offsetY = 0;
		text2.sprTracker = optionText;
		text2.ID = optionText.ID;
		grpInputsAlt.push(text2);
		add(text2);
	}

	function reloadKeys() {
		while(grpInputs.length > 0) {
			var item:FlxTextAttached = grpInputs[0];
			grpInputs.remove(item);
			item.destroy();
		}
		while(grpInputsAlt.length > 0) {
			var item:FlxTextAttached = grpInputsAlt[0];
			grpInputsAlt.remove(item);
			item.destroy();
		}

		TraceManager.debug('trace.controls.keysReloaded', 'Reloaded keys: {}', [ClientPrefs.keyBinds]);

		// Rebuild bind texts for each optionShit index that's selectable
		for (i in 0...optionShit.length) {
			if(!unselectableCheck(i, true) && optionShit[i].length > 2) {
				// Find the corresponding FlxTextMenuItem by matching targetY/ID
				var bindKey:String = optionShit[i][2];
				var showOption:Bool = (optionShit[i][0] == true) || onKeyboardMode;
				if(!showOption) continue;
				for (opt in grpOptions.members) {
					if(opt.ID == curOptionsValid[curOptions.indexOf(i)]) {
						addBindTexts(opt, i);
						break;
					}
				}
			}
		}

		// Re-apply highlighting
		for (i in 0...grpInputs.length) {
			grpInputs[i].alpha = 0.6;
		}
		for (i in 0...grpInputsAlt.length) {
			grpInputsAlt[i].alpha = 0.6;
		}
		if(curSelected >= 0 && curSelected < curOptionsValid.length) {
			var selID:Int = curOptionsValid[curSelected];
			if(curAlt) {
				for (i in 0...grpInputsAlt.length) {
					if(grpInputsAlt[i].ID == selID) {
						grpInputsAlt[i].alpha = 1;
						break;
					}
				}
			} else {
				for (i in 0...grpInputs.length) {
					if(grpInputs[i].ID == selID) {
						grpInputs[i].alpha = 1;
						break;
					}
				}
			}
		}
	}
}