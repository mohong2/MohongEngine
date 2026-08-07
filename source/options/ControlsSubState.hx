package options;

import backend.MusicBeatSubstate;
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
		// 多k 键位 (键盘模式可见, 1K~18K)
		[false],
		[false, 'EK KEYS'],
		[false, '1 KEY', 'note_one1'],
		[false],
		[false, '2 KEYS'],
		[false, 'Left', 'note_two1'],
		[false, 'Right', 'note_two2'],
		[false],
		[false, '3 KEYS'],
		[false, 'Left', 'note_three1'],
		[false, 'Center', 'note_three2'],
		[false, 'Right', 'note_three3'],
		[false],
		[false, '5 KEYS'],
		[false, 'Left', 'note_five1'],
		[false, 'Down', 'note_five2'],
		[false, 'Center', 'note_five3'],
		[false, 'Up', 'note_five4'],
		[false, 'Right', 'note_five5'],
		[false],
		[false, '6 KEYS'],
		[false, 'Left 1', 'note_six1'],
		[false, 'Up', 'note_six2'],
		[false, 'Right 1', 'note_six3'],
		[false, 'Left 2', 'note_six4'],
		[false, 'Down', 'note_six5'],
		[false, 'Right 2', 'note_six6'],
		[false],
		[false, '7 KEYS'],
		[false, 'Left 1', 'note_seven1'],
		[false, 'Up', 'note_seven2'],
		[false, 'Right 1', 'note_seven3'],
		[false, 'Center', 'note_seven4'],
		[false, 'Left 2', 'note_seven5'],
		[false, 'Down', 'note_seven6'],
		[false, 'Right 2', 'note_seven7'],
		[false],
		[false, '8 KEYS'],
		[false, 'Left 1', 'note_eight1'],
		[false, 'Down 1', 'note_eight2'],
		[false, 'Up 1', 'note_eight3'],
		[false, 'Right 1', 'note_eight4'],
		[false, 'Left 2', 'note_eight5'],
		[false, 'Down 2', 'note_eight6'],
		[false, 'Up 2', 'note_eight7'],
		[false, 'Right 2', 'note_eight8'],
		[false],
		[false, '9 KEYS'],
		[false, 'Left 1', 'note_nine1'],
		[false, 'Down 1', 'note_nine2'],
		[false, 'Up 1', 'note_nine3'],
		[false, 'Right 1', 'note_nine4'],
		[false, 'Center', 'note_nine5'],
		[false, 'Left 2', 'note_nine6'],
		[false, 'Down 2', 'note_nine7'],
		[false, 'Up 2', 'note_nine8'],
		[false, 'Right 2', 'note_nine9'],
		[false],
		[false, '10 KEYS'],
		[false, 'Left 1', 'note_ten1'],
		[false, 'Down 1', 'note_ten2'],
		[false, 'Up 1', 'note_ten3'],
		[false, 'Right 1', 'note_ten4'],
		[false, 'Center 1', 'note_ten5'],
		[false, 'Center 2', 'note_ten6'],
		[false, 'Left 2', 'note_ten7'],
		[false, 'Down 2', 'note_ten8'],
		[false, 'Up 2', 'note_ten9'],
		[false, 'Right 2', 'note_ten10'],
		[false],
		[false, '11 KEYS'],
		[false, 'Left 1', 'note_elev1'],
		[false, 'Down 1', 'note_elev2'],
		[false, 'Up 1', 'note_elev3'],
		[false, 'Right 1', 'note_elev4'],
		[false, 'Left 2', 'note_elev5'],
		[false, 'Center 2', 'note_elev6'],
		[false, 'Right 2', 'note_elev7'],
		[false, 'Left 3', 'note_elev8'],
		[false, 'Down 2', 'note_elev9'],
		[false, 'Up 2', 'note_elev10'],
		[false, 'Right 3', 'note_elev11'],
		[false],
		[false, '12 KEYS'],
		[false, 'Left 1', 'note_twel1'],
		[false, 'Down 1', 'note_twel2'],
		[false, 'Up 1', 'note_twel3'],
		[false, 'Right 1', 'note_twel4'],
		[false, 'Left 2', 'note_twel5'],
		[false, 'Down 2', 'note_twel6'],
		[false, 'Up 2', 'note_twel7'],
		[false, 'Right 2', 'note_twel8'],
		[false, 'Left 3', 'note_twel9'],
		[false, 'Down 3', 'note_twel10'],
		[false, 'Up 3', 'note_twel11'],
		[false, 'Right 3', 'note_twel12'],
		[false],
		[false, '13 KEYS'],
		[false, 'Left 1', 'note_thir1'],
		[false, 'Down 1', 'note_thir2'],
		[false, 'Up 1', 'note_thir3'],
		[false, 'Right 1', 'note_thir4'],
		[false, 'Left 2', 'note_thir5'],
		[false, 'Down 2', 'note_thir6'],
		[false, 'Center', 'note_thir7'],
		[false, 'Up 2', 'note_thir8'],
		[false, 'Right 2', 'note_thir9'],
		[false, 'Left 3', 'note_thir10'],
		[false, 'Down 3', 'note_thir11'],
		[false, 'Up 3', 'note_thir12'],
		[false, 'Right 3', 'note_thir13'],
		[false],
		[false, '14 KEYS'],
		[false, 'Left 1', 'note_fourt1'],
		[false, 'Down 1', 'note_fourt2'],
		[false, 'Up 1', 'note_fourt3'],
		[false, 'Right 1', 'note_fourt4'],
		[false, 'Left 2', 'note_fourt5'],
		[false, 'Down 2', 'note_fourt6'],
		[false, 'Center 1', 'note_fourt7'],
		[false, 'Center 2', 'note_fourt8'],
		[false, 'Up 2', 'note_fourt9'],
		[false, 'Right 2', 'note_fourt10'],
		[false, 'Left 3', 'note_fourt11'],
		[false, 'Down 3', 'note_fourt12'],
		[false, 'Up 3', 'note_fourt13'],
		[false, 'Right 3', 'note_fourt14'],
		[false],
		[false, '15 KEYS'],
		[false, 'Left 1', 'note_151'],
		[false, 'Down 1', 'note_152'],
		[false, 'Up 1', 'note_153'],
		[false, 'Right 1', 'note_154'],
		[false, 'Left 2', 'note_155'],
		[false, 'Down 2', 'note_156'],
		[false, 'Center 1', 'note_157'],
		[false, 'Center 2', 'note_158'],
		[false, 'Center 3', 'note_159'],
		[false, 'Up 2', 'note_1510'],
		[false, 'Right 2', 'note_1511'],
		[false, 'Left 3', 'note_1512'],
		[false, 'Down 3', 'note_1513'],
		[false, 'Up 3', 'note_1514'],
		[false, 'Right 3', 'note_1515'],
		[false],
		[false, '16 KEYS'],
		[false, 'Left 1', 'note_161'],
		[false, 'Down 1', 'note_162'],
		[false, 'Up 1', 'note_163'],
		[false, 'Right 1', 'note_164'],
		[false, 'Left 2', 'note_165'],
		[false, 'Down 2', 'note_166'],
		[false, 'Up 2', 'note_167'],
		[false, 'Right 2', 'note_168'],
		[false, 'Left 3', 'note_169'],
		[false, 'Down 3', 'note_1610'],
		[false, 'Up 3', 'note_1611'],
		[false, 'Right 3', 'note_1612'],
		[false, 'Left 4', 'note_1613'],
		[false, 'Down 4', 'note_1614'],
		[false, 'Up 4', 'note_1615'],
		[false, 'Right 4', 'note_1616'],
		[false],
		[false, '17 KEYS'],
		[false, 'Left 1', 'note_171'],
		[false, 'Down 1', 'note_172'],
		[false, 'Up 1', 'note_173'],
		[false, 'Right 1', 'note_174'],
		[false, 'Left 2', 'note_175'],
		[false, 'Down 2', 'note_176'],
		[false, 'Up 2', 'note_177'],
		[false, 'Right 2', 'note_178'],
		[false, 'Center', 'note_179'],
		[false, 'Left 3', 'note_1710'],
		[false, 'Down 3', 'note_1711'],
		[false, 'Up 3', 'note_1712'],
		[false, 'Right 3', 'note_1713'],
		[false, 'Left 4', 'note_1714'],
		[false, 'Down 4', 'note_1715'],
		[false, 'Up 4', 'note_1716'],
		[false, 'Right 4', 'note_1717'],
		[false],
		[false, '18 KEYS'],
		[false, 'Left 1', 'note_181'],
		[false, 'Down 1', 'note_182'],
		[false, 'Up 1', 'note_183'],
		[false, 'Right 1', 'note_184'],
		[false, 'Center 1', 'note_185'],
		[false, 'Left 2', 'note_186'],
		[false, 'Down 2', 'note_187'],
		[false, 'Up 2', 'note_188'],
		[false, 'Right 2', 'note_189'],
		[false, 'Left 3', 'note_1810'],
		[false, 'Down 3', 'note_1811'],
		[false, 'Up 3', 'note_1812'],
		[false, 'Right 3', 'note_1813'],
		[false, 'Center 2', 'note_1814'],
		[false, 'Left 4', 'note_1815'],
		[false, 'Down 4', 'note_1816'],
		[false, 'Up 4', 'note_1817'],
		[false, 'Right 4', 'note_1818'],
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
