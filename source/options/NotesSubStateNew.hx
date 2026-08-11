package options;

#if desktop
import Discord.DiscordClient;
#end
import backend.MusicBeatSubstate;
import flixel.addons.display.FlxBackdrop;
import flixel.addons.display.FlxGridOverlay;
import flixel.addons.display.shapes.FlxShapeCircle;
import flixel.input.keyboard.FlxKey;
import flixel.input.gamepad.FlxGamepadInputID;
import lime.system.Clipboard;
import flixel.util.FlxGradient;
import shaders.RGBPalette;
import shaders.RGBPalette.RGBShaderReference;
import EKData;
import Note;
import states.PlayState;
import StrumNote;

/**
 * NotesSubStateNew — 0.7.3+ 风格的完整 Note 颜色编辑器 (RGB):
 * 色轮 / 亮度条 / 调色板 / 十六进制输入 / 复制粘贴。
 *
 * 按 FNF-PsychEngine-EK-0.7.3 (多k 分支) 的 NotesSubState 结构重写:
 *  - myNotes 用真正的 StrumNote 显示全部轨道 (press/confirm 动画 + RGB 染色);
 *  - bigNote 大箭头实时预览当前轨道的滚动帧;
 *  - CTRL / skinNote 点击切换像素/非像素材质 (pixelUI/noteSkins/NOTE_assets)。
 *
 * 适配本引擎 (0.6.3 基底) 的改动:
 *  - Note.colArray 是实例字段 (0.6.3 兼容, 模组会反射读写), 本界面用本地颜色名表。
 *  - Note.globalRgbShaders 按 noteData+mania 缓存, 统一走 Note.initializeGlobalRGBShader()。
 *  - 0.7.3 的 PlayState.stageUI 在本引擎不存在, 像素预览临时切换 PlayState.isPixelStage。
 *  - 色轮角度用本引擎 flixel 的 angleBetween (0°=上、顺时针), 与色轮图方向一致。
 *
 * 注意: 本界面编辑的是 arrowRGB (0.7.3 RGB 色板), 只在 rgbShader 生效时可见
 * (即 0.7.3/1.0.4 兼容模式下); 0.6.3 模式仍用旧版 HSV 编辑器改 arrowHSV。
 */
class NotesSubStateNew extends MusicBeatSubstate
{
	var onModeColumn:Bool = true;
	var curSelectedMode:Int = 0;
	var curSelectedNote:Int = 0;
	var onPixel:Bool = false;
	var dataArray:Array<Array<FlxColor>>;

	/** 进入本编辑器前的 PlayState.isPixelStage, 切材质时保存/恢复 (0.7.3 用 stageUI)。 */
	var _prevPixelStage:Bool = false;
	/** 本地颜色名表 (本引擎 Note.colArray 是私有实例字段, 不能静态访问)。 */
	static final COLOR_NAMES:Array<String> = ['purple', 'blue', 'green', 'red'];

	var hexTypeLine:FlxSprite;
	var hexTypeNum:Int = -1;
	var hexTypeVisibleTimer:Float = 0;

	var copyButton:FlxSprite;
	var pasteButton:FlxSprite;

	var colorGradient:FlxSprite;
	var colorGradientSelector:FlxSprite;
	var colorPalette:FlxSprite;
	var colorWheel:FlxSprite;
	var colorWheelSelector:FlxSprite;

	var alphabetR:Alphabet;
	var alphabetG:Alphabet;
	var alphabetB:Alphabet;
	var alphabetHex:Alphabet;

	var modeBG:FlxSprite;
	var notesBG:FlxSprite;

	// controller support
	var controllerPointer:FlxSprite;
	var _lastControllerMode:Bool = false;
	var tipTxt:FlxText;

	public function new() {
		super();

		#if desktop
		DiscordClient.changePresence("Note Colors Menu (0.7.3)", null);
		#end

		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.color = 0xFFEA71FD;
		bg.screenCenter();
		bg.antialiasing = ClientPrefs.data.globalAntialiasing;
		add(bg);

		var grid:FlxBackdrop = new FlxBackdrop(FlxGridOverlay.createGrid(80, 80, 160, 160, true, 0x33FFFFFF, 0x0));
		grid.velocity.set(40, 40);
		grid.alpha = 0;
		FlxTween.tween(grid, {alpha: 1}, 0.5, {ease: FlxEase.quadOut});
		add(grid);

		modeBG = new FlxSprite(215, 85).makeGraphic(315, 115, FlxColor.BLACK);
		modeBG.visible = false;
		modeBG.alpha = 0.4;
		add(modeBG);

		notesBG = new FlxSprite(140, 190).makeGraphic(480, 125, FlxColor.BLACK);
		notesBG.visible = false;
		notesBG.alpha = 0.4;
		add(notesBG);

		modeNotes = new FlxTypedGroup<FlxSprite>();
		add(modeNotes);
		myNotes = new FlxTypedGroup<StrumNote>();
		add(myNotes);

		var bg:FlxSprite = new FlxSprite(720).makeGraphic(FlxG.width - 720, FlxG.height, FlxColor.BLACK);
		bg.alpha = 0.25;
		add(bg);
		var bg:FlxSprite = new FlxSprite(750, 160).makeGraphic(FlxG.width - 780, 540, FlxColor.BLACK);
		bg.alpha = 0.25;
		add(bg);

		var text:Alphabet = new Alphabet(50, 86, 'CTRL', false);
		text.alignment = CENTERED;
		text.setScale(0.4);
		add(text);

		copyButton = new FlxSprite(760, 50).loadGraphic(Paths.image('noteColorMenu/copy'));
		copyButton.alpha = 0.6;
		add(copyButton);

		pasteButton = new FlxSprite(1180, 50).loadGraphic(Paths.image('noteColorMenu/paste'));
		pasteButton.alpha = 0.6;
		add(pasteButton);

		colorGradient = FlxGradient.createGradientFlxSprite(60, 360, [FlxColor.WHITE, FlxColor.BLACK]);
		colorGradient.setPosition(780, 200);
		add(colorGradient);

		colorGradientSelector = new FlxSprite(770, 200).makeGraphic(80, 10, FlxColor.WHITE);
		colorGradientSelector.offset.y = 5;
		add(colorGradientSelector);

		colorPalette = new FlxSprite(820, 580).loadGraphic(Paths.image('noteColorMenu/palette'));
		colorPalette.scale.set(20, 20);
		colorPalette.updateHitbox();
		colorPalette.antialiasing = false;
		add(colorPalette);

		colorWheel = new FlxSprite(860, 200).loadGraphic(Paths.image('noteColorMenu/colorWheel'));
		colorWheel.setGraphicSize(360, 360);
		colorWheel.updateHitbox();
		add(colorWheel);

		colorWheelSelector = new FlxShapeCircle(0, 0, 8, {thickness: 0}, FlxColor.WHITE);
		colorWheelSelector.offset.set(8, 8);
		colorWheelSelector.alpha = 0.6;
		add(colorWheelSelector);

		var txtX = 980;
		var txtY = 90;
		alphabetR = makeColorAlphabet(txtX - 100, txtY);
		add(alphabetR);
		alphabetG = makeColorAlphabet(txtX, txtY);
		add(alphabetG);
		alphabetB = makeColorAlphabet(txtX + 100, txtY);
		add(alphabetB);
		alphabetHex = makeColorAlphabet(txtX, txtY - 55);
		add(alphabetHex);
		hexTypeLine = new FlxSprite(0, 20).makeGraphic(5, 62, FlxColor.WHITE);
		hexTypeLine.visible = false;
		add(hexTypeLine);

		spawnNotes();
		updateNotes(true);
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);

		var tipX = 20;
		var tipY = 660;
		var tip:FlxText = new FlxText(tipX, tipY, 0, "Press RELOAD to Reset the selected Note Part.", 16);
		tip.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		tip.borderSize = 2;
		add(tip);

		tipTxt = new FlxText(tipX, tipY + 24, 0, '', 16);
		tipTxt.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		tipTxt.borderSize = 2;
		add(tipTxt);
		updateTip();

		controllerPointer = new FlxShapeCircle(0, 0, 20, {thickness: 0}, FlxColor.WHITE);
		controllerPointer.offset.set(20, 20);
		controllerPointer.screenCenter();
		controllerPointer.alpha = 0.6;
		add(controllerPointer);

		FlxG.mouse.visible = !ClientPrefs.data.controllerMode;
		controllerPointer.visible = ClientPrefs.data.controllerMode;
		_lastControllerMode = ClientPrefs.data.controllerMode;

		// 移动端/触屏: 虚拟按键 (方向=选择, A=确定, B=返回, C=重置), 与 ModSettings/NoteOffset 一致。
		// MusicBeatSubstate.addVirtualPad 在桌面端仅在开启 touchControls 时显示, 不会干扰纯鼠标操作。
		#if (TOUCH_CONTROLS || desktop)
		addVirtualPad(LEFT_FULL, A_B_C);
		addPadCamera();
		#end
	}

	function updateTip()
	{
		#if mobile
		tipTxt.text = 'Tap the selected Note in the top list to switch lanes.';
		#else
		tipTxt.text = 'Hold ' + (!ClientPrefs.data.controllerMode ? 'Shift' : 'Left Shoulder Button') + ' + Press RESET key to fully reset the selected Note.';
		#end
	}

	/** 移动端没有物理键盘, 十六进制键入会卡死在 typing 模式, 直接禁用。 */
	static inline function canTypeHex():Bool
	{
		#if mobile
		return false;
		#else
		return true;
		#end
	}

	/** 点按虚拟按键时交给 pad 处理, 不再穿透到编辑器。 */
	function isPointerOverPad():Bool
	{
		#if (TOUCH_CONTROLS || desktop)
		return virtualPad != null && virtualPad.isMouseOverAnyButton();
		#else
		return false;
		#end
	}

	var _storedColor:FlxColor;
	var changingNote:Bool = false;
	var holdingOnObj:FlxSprite;
	var allowedTypeKeys:Map<FlxKey, String> = [
		ZERO => '0', ONE => '1', TWO => '2', THREE => '3', FOUR => '4', FIVE => '5', SIX => '6', SEVEN => '7', EIGHT => '8', NINE => '9',
		NUMPADZERO => '0', NUMPADONE => '1', NUMPADTWO => '2', NUMPADTHREE => '3', NUMPADFOUR => '4', NUMPADFIVE => '5', NUMPADSIX => '6',
		NUMPADSEVEN => '7', NUMPADEIGHT => '8', NUMPADNINE => '9', A => 'A', B => 'B', C => 'C', D => 'D', E => 'E', F => 'F'];

	override function update(elapsed:Float) {
		if (controls.BACK) {
			FlxG.mouse.visible = false;
			FlxG.sound.play(Paths.sound('cancelMenu'));
			close();
			return;
		}

		super.update(elapsed);

		// Early controller checking
		if(FlxG.gamepads.anyJustPressed(ANY)) ClientPrefs.data.controllerMode = true;
		else if(FlxG.mouse.justPressed || FlxG.mouse.deltaScreenX != 0 || FlxG.mouse.deltaScreenY != 0) ClientPrefs.data.controllerMode = false;
		//

		var changedToController:Bool = false;
		if(ClientPrefs.data.controllerMode != _lastControllerMode)
		{
			FlxG.mouse.visible = !ClientPrefs.data.controllerMode;
			controllerPointer.visible = ClientPrefs.data.controllerMode;

			// changed to controller mid state
			if(ClientPrefs.data.controllerMode)
			{
				controllerPointer.x = FlxG.mouse.x;
				controllerPointer.y = FlxG.mouse.y;
				changedToController = true;
			}
			_lastControllerMode = ClientPrefs.data.controllerMode;
			updateTip();
		}

		// controller things
		var analogX:Float = 0;
		var analogY:Float = 0;
		var analogMoved:Bool = false;
		if(ClientPrefs.data.controllerMode && (changedToController || FlxG.gamepads.anyInput()))
		{
			for (gamepad in FlxG.gamepads.getActiveGamepads())
			{
				analogX = gamepad.getXAxis(LEFT_ANALOG_STICK);
				analogY = gamepad.getYAxis(LEFT_ANALOG_STICK);
				analogMoved = (analogX != 0 || analogY != 0);
				if(analogMoved) break;
			}
			controllerPointer.x = Math.max(0, Math.min(FlxG.width, controllerPointer.x + analogX * 1000 * elapsed));
			controllerPointer.y = Math.max(0, Math.min(FlxG.height, controllerPointer.y + analogY * 1000 * elapsed));
		}
		var controllerPressed:Bool = (ClientPrefs.data.controllerMode && controls.ACCEPT);
		//

		if(FlxG.keys.justPressed.CONTROL)
		{
			onPixel = !onPixel;
			spawnNotes();
			updateNotes(true);
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
		}

		// 触屏设备没有键盘: 若 hexTypeNum 被意外置入 typing 模式, 立即退出, 防止界面卡死。
		if(hexTypeNum > -1 && !canTypeHex())
		{
			hexTypeNum = -1;
			hexTypeLine.visible = false;
		}

		if(hexTypeNum > -1)
		{
			var keyPressed:FlxKey = cast (FlxG.keys.firstJustPressed(), FlxKey);
			hexTypeVisibleTimer += elapsed;
			var changed:Bool = false;
			if(changed = FlxG.keys.justPressed.LEFT)
				hexTypeNum--;
			else if(changed = FlxG.keys.justPressed.RIGHT)
				hexTypeNum++;
			else if(allowedTypeKeys.exists(keyPressed))
			{
				var curColor:String = alphabetHex.text;
				var newColor:String = curColor.substring(0, hexTypeNum) + allowedTypeKeys.get(keyPressed) + curColor.substring(hexTypeNum + 1);

				var colorHex:FlxColor = FlxColor.fromString('#' + newColor);
				setShaderColor(colorHex);
				_storedColor = getShaderColor();
				updateColors();

				// move you to next letter
				hexTypeNum++;
				changed = true;
			}
			else if(FlxG.keys.justPressed.ENTER)
				hexTypeNum = -1;

			var end:Bool = false;
			if(changed)
			{
				if (hexTypeNum > 5) //Typed last letter
				{
					hexTypeNum = -1;
					end = true;
					hexTypeLine.visible = false;
				}
				else
				{
					if(hexTypeNum < 0) hexTypeNum = 0;
					else if(hexTypeNum > 5) hexTypeNum = 5;
					centerHexTypeLine();
					hexTypeLine.visible = true;
				}
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
			}
			if(!end) hexTypeLine.visible = Math.floor(hexTypeVisibleTimer * 2) % 2 == 0;
		}
		else
		{
			var add:Int = 0;
			if(analogX == 0 && !changedToController)
			{
				if(controls.UI_LEFT_P) add = -1;
				else if(controls.UI_RIGHT_P) add = 1;
			}

			if(analogY == 0 && !changedToController && (controls.UI_UP_P || controls.UI_DOWN_P))
			{
				onModeColumn = !onModeColumn;
				modeBG.visible = onModeColumn;
				notesBG.visible = !onModeColumn;
			}

			if(add != 0)
			{
				if(onModeColumn) changeSelectionMode(add);
				else changeSelectionNote(add);
			}
			hexTypeLine.visible = false;
		}

		// Copy/Paste buttons
		var generalMoved:Bool = (FlxG.mouse.justMoved || analogMoved);
		var generalPressed:Bool = (FlxG.mouse.justPressed || controllerPressed);
		if(generalMoved)
		{
			copyButton.alpha = 0.6;
			pasteButton.alpha = 0.6;
		}

		if(pointerOverlaps(copyButton))
		{
			copyButton.alpha = 1;
			if(generalPressed)
			{
				Clipboard.text = getShaderColor().toHexString(false, false);
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
			}
			hexTypeNum = -1;
		}
		else if (pointerOverlaps(pasteButton))
		{
			pasteButton.alpha = 1;
			if(generalPressed)
			{
				var formattedText = Clipboard.text.trim().toUpperCase().replace('#', '').replace('0x', '');
				var newColor:Null<FlxColor> = FlxColor.fromString('#' + formattedText);
				if(newColor != null && formattedText.length == 6)
				{
					setShaderColor(newColor);
					FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
					_storedColor = getShaderColor();
					updateColors();
				}
				else //errored
					FlxG.sound.play(Paths.sound('cancelMenu'), 0.6);
			}
			hexTypeNum = -1;
		}

		// Click (虚拟按键上的点按交给 pad, 不穿透到编辑器)
		if(generalPressed && !isPointerOverPad())
		{
			hexTypeNum = -1;
			if (pointerOverlaps(modeNotes))
			{
				modeNotes.forEachAlive(function(note:FlxSprite) {
					if (curSelectedMode != note.ID && pointerOverlaps(note))
					{
						modeBG.visible = notesBG.visible = false;
						curSelectedMode = note.ID;
						onModeColumn = true;
						updateNotes();
						FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
					}
				});
			}
			else if (pointerOverlaps(myNotes))
			{
				myNotes.forEachAlive(function(note:StrumNote) {
					if (curSelectedNote != note.ID && pointerOverlaps(note))
					{
						modeBG.visible = notesBG.visible = false;
						curSelectedNote = note.ID;
						onModeColumn = false;
						updateBigNote();
						updateNotes();
						FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
					}
				});
			}
			else if (pointerOverlaps(colorWheel)) {
				_storedColor = getShaderColor();
				holdingOnObj = colorWheel;
			}
			else if (pointerOverlaps(colorGradient)) {
				_storedColor = getShaderColor();
				holdingOnObj = colorGradient;
			}
			else if (pointerOverlaps(colorPalette)) {
				setShaderColor(colorPalette.pixels.getPixel32(
					Std.int((pointerX() - colorPalette.x) / colorPalette.scale.x),
					Std.int((pointerY() - colorPalette.y) / colorPalette.scale.y)));
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
				updateColors();
			}
			else if (pointerOverlaps(skinNote))
			{
				onPixel = !onPixel;
				spawnNotes();
				updateNotes(true);
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
			}
			else if(canTypeHex() && pointerY() >= hexTypeLine.y && pointerY() < hexTypeLine.y + hexTypeLine.height &&
					Math.abs(pointerX() - 1000) <= 84)
			{
				hexTypeNum = 0;
				for (letter in alphabetHex.letters)
				{
					if(letter.x - letter.offset.x + letter.width <= pointerX()) hexTypeNum++;
					else break;
				}
				if(hexTypeNum > 5) hexTypeNum = 5;
				hexTypeLine.visible = true;
				centerHexTypeLine();
			}
			else holdingOnObj = null;
		}
		// holding
		if(holdingOnObj != null)
		{
			if (FlxG.mouse.justReleased || (ClientPrefs.data.controllerMode && controls.justReleased('accept')))
			{
				holdingOnObj = null;
				_storedColor = getShaderColor();
				updateColors();
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
			}
			else if (generalMoved || generalPressed)
			{
				if (holdingOnObj == colorGradient)
				{
					var newBrightness = 1 - FlxMath.bound((pointerY() - colorGradient.y) / colorGradient.height, 0, 1);
					_storedColor.alpha = 1;
					if(_storedColor.brightness == 0) //prevent bug
						setShaderColor(FlxColor.fromRGBFloat(newBrightness, newBrightness, newBrightness));
					else
						setShaderColor(FlxColor.fromHSB(_storedColor.hue, _storedColor.saturation, newBrightness));
					updateColors(_storedColor);
				}
				else if (holdingOnObj == colorWheel)
				{
					var center:FlxPoint = new FlxPoint(colorWheel.x + colorWheel.width/2, colorWheel.y + colorWheel.height/2);
					var mouse:FlxPoint = pointerFlxPoint();
					var dx:Float = pointerX() - center.x;
					var dy:Float = pointerY() - center.y;
					var hue:Float = (Math.atan2(dy, dx) * 180 / Math.PI + 90 + 360) % 360;
					var sat:Float = FlxMath.bound(mouse.distanceTo(center) / colorWheel.width*2, 0, 1);
					if(sat != 0) setShaderColor(FlxColor.fromHSB(hue, sat, _storedColor.brightness));
					else setShaderColor(FlxColor.fromRGBFloat(_storedColor.brightness, _storedColor.brightness, _storedColor.brightness));
					updateColors();
				}
			}
		}
		else if(((controls.RESET #if (TOUCH_CONTROLS || desktop) || (virtualPad != null && virtualPad.buttonC.justPressed) #end) && hexTypeNum < 0))
		{
			if(FlxG.keys.pressed.SHIFT || FlxG.gamepads.anyJustPressed(LEFT_SHOULDER))
			{
				for (i in 0...3)
				{
					var strumRGB:RGBShaderReference = myNotes.members[curSelectedNote].rgbShader;
					var color:FlxColor = !onPixel ? ClientPrefs.defaultData.arrowRGB[curSelectedNote][i] :
													ClientPrefs.defaultData.arrowRGBPixel[curSelectedNote][i];
					switch(i)
					{
						case 0:
							getShader().r = strumRGB.r = color;
						case 1:
							getShader().g = strumRGB.g = color;
						case 2:
							getShader().b = strumRGB.b = color;
					}
					dataArray[curSelectedNote][i] = color;
				}
			}
			setShaderColor(!onPixel ? ClientPrefs.defaultData.arrowRGB[curSelectedNote][curSelectedMode] : ClientPrefs.defaultData.arrowRGBPixel[curSelectedNote][curSelectedMode]);
			FlxG.sound.play(Paths.sound('cancelMenu'), 0.6);
			updateColors();
		}
	}

	function pointerOverlaps(obj:Dynamic)
	{
		if (!ClientPrefs.data.controllerMode) return FlxG.mouse.overlaps(obj);
		return FlxG.overlap(controllerPointer, obj);
	}

	function pointerX():Float
	{
		if (!ClientPrefs.data.controllerMode) return FlxG.mouse.x;
		return controllerPointer.x;
	}
	function pointerY():Float
	{
		if (!ClientPrefs.data.controllerMode) return FlxG.mouse.y;
		return controllerPointer.y;
	}
	function pointerFlxPoint():FlxPoint
	{
		if (!ClientPrefs.data.controllerMode) return FlxG.mouse.getScreenPosition();
		return controllerPointer.getScreenPosition();
	}

	function centerHexTypeLine()
	{
		if(hexTypeNum > 0)
		{
			var letter = alphabetHex.letters[hexTypeNum-1];
			hexTypeLine.x = letter.x - letter.offset.x + letter.width;
		}
		else
		{
			var letter = alphabetHex.letters[0];
			hexTypeLine.x = letter.x - letter.offset.x;
		}
		hexTypeLine.x += hexTypeLine.width;
		hexTypeVisibleTimer = 0;
	}

	function changeSelectionMode(change:Int = 0) {
		curSelectedMode += change;
		if (curSelectedMode < 0)
			curSelectedMode = 2;
		if (curSelectedMode >= 3)
			curSelectedMode = 0;

		modeBG.visible = true;
		notesBG.visible = false;
		updateNotes();
		FlxG.sound.play(Paths.sound('scrollMenu'));
	}
	function changeSelectionNote(change:Int = 0) {
		curSelectedNote += change;
		if (curSelectedNote < 0)
			curSelectedNote = dataArray.length-1;
		if (curSelectedNote >= dataArray.length)
			curSelectedNote = 0;

		modeBG.visible = false;
		notesBG.visible = true;
		updateBigNote();
		updateNotes();
		FlxG.sound.play(Paths.sound('scrollMenu'));
	}

	// alphabets
	function makeColorAlphabet(x:Float = 0, y:Float = 0):Alphabet
	{
		var text:Alphabet = new Alphabet(x, y, '', true);
		text.alignment = CENTERED;
		text.setScale(0.6);
		add(text);
		return text;
	}

	// notes sprites functions
	var skinNote:FlxSprite;
	var modeNotes:FlxTypedGroup<FlxSprite>;
	var myNotes:FlxTypedGroup<StrumNote>;
	var bigNote:Note;
	public function spawnNotes()
	{
		dataArray = !onPixel ? ClientPrefs.data.arrowRGB : ClientPrefs.data.arrowRGBPixel;
		_prevPixelStage = PlayState.isPixelStage;
		PlayState.isPixelStage = onPixel;

		// clear groups
		modeNotes.forEachAlive(function(note:FlxSprite) {
			note.kill();
			note.destroy();
		});
		myNotes.forEachAlive(function(note:StrumNote) {
			note.kill();
			note.destroy();
		});
		modeNotes.clear();
		myNotes.clear();

		if(skinNote != null)
		{
			remove(skinNote);
			skinNote.destroy();
		}
		if(bigNote != null)
		{
			remove(bigNote);
			bigNote.destroy();
		}

		var res:Int = onPixel ? 17 : 160;
		skinNote = new FlxSprite(48, 24).loadGraphic(Paths.image('noteColorMenu/' + (onPixel ? 'notePixel' : 'note')), true, res, res);
		skinNote.antialiasing = ClientPrefs.data.globalAntialiasing;
		skinNote.setGraphicSize(68);
		skinNote.updateHitbox();
		skinNote.animation.add('anim', [0], 24, true);
		skinNote.animation.play('anim', true);
		if(onPixel) skinNote.antialiasing = false;
		add(skinNote);

		for (i in 0...3)
		{
			var newNote:FlxSprite = new FlxSprite(230 + (100 * i), 100).loadGraphic(Paths.image('noteColorMenu/' + (onPixel ? 'notePixel' : 'note')), true, onPixel ? 17 : 160, onPixel ? 17 : 160);
			newNote.antialiasing = ClientPrefs.data.globalAntialiasing;
			newNote.setGraphicSize(85);
			newNote.updateHitbox();
			newNote.animation.add('anim', [i], 24, true);
			newNote.animation.play('anim', true);
			newNote.ID = i;
			if(onPixel) newNote.antialiasing = false;
			modeNotes.add(newNote);
		}

		Note.globalRgbShaders = [];
		for (i in 0...dataArray.length)
			Note.initializeGlobalRGBShader(i, 8);

		var laneCount:Int = dataArray.length;
		var laneGap:Float = 480 / laneCount;
		var noteSize:Int = Std.int(Math.min(102, laneGap * 0.9));
		for (i in 0...laneCount)
		{
			var newNote:StrumNote = new StrumNote(150 + (laneGap * i), 200, i, 0);
			newNote.ID = i;
			myNotes.add(newNote);
			newNote.texture = 'noteSkins/NOTE_assets';
			newNote.rgbShader.rebind(Note.initializeGlobalRGBShader(i, 8));
			newNote.setGraphicSize(noteSize);
			newNote.updateHitbox();
			newNote.setPosition(150 + (laneGap * i), 200); 
		}

		bigNote = new Note(0, 0, null, false);
		bigNote.texture = 'noteSkins/NOTE_assets';
		bigNote.setPosition(250, 325);
		bigNote.setGraphicSize(250);
		bigNote.updateHitbox();
		updateBigNote();
		for (i in 0...dataArray.length)
		{
			var base:Int = EKData.getBaseTexture(8, i);
			if (!onPixel) bigNote.animation.addByPrefix('note$i', COLOR_NAMES[base] + '0', 24, true);
			else bigNote.animation.add('note$i', [base + 4], 24, true);
		}
		insert(members.indexOf(myNotes) + 1, bigNote);

		PlayState.isPixelStage = _prevPixelStage;
		_storedColor = getShaderColor();
	}

	function updateBigNote()
	{
		if (bigNote == null) return;
		var palette:RGBPalette = getShader();
		bigNote.rgbShader.parent = palette;
		bigNote.shader = palette.shader;
	}

	function updateNotes(?instant:Bool = false)
	{
		for (note in modeNotes)
			note.alpha = (curSelectedMode == note.ID) ? 1 : 0.6;

		for (note in myNotes)
		{
			var newAnim:String = (curSelectedNote == note.ID) ? 'confirm' : 'pressed';
			note.alpha = (curSelectedNote == note.ID) ? 1 : 0.6;
			if(note.animation.curAnim == null || note.animation.curAnim.name != newAnim)
				note.playAnim(newAnim, true);
			if(instant && note.animation.curAnim != null) note.animation.curAnim.finish();
		}
		if (bigNote != null) bigNote.animation.play('note$curSelectedNote', true);
		updateColors();
	}

	function updateColors(specific:Null<FlxColor> = null)
	{
		var color:FlxColor = getShaderColor();
		var wheelColor:FlxColor = specific == null ? getShaderColor() : specific;
		alphabetR.text = Std.string(color.red);
		alphabetG.text = Std.string(color.green);
		alphabetB.text = Std.string(color.blue);
		alphabetHex.text = color.toHexString(false, false);
		for (letter in alphabetHex.letters) letter.color = color;

		colorWheel.color = FlxColor.fromHSB(0, 0, color.brightness);
		colorWheelSelector.setPosition(colorWheel.x + colorWheel.width/2, colorWheel.y + colorWheel.height/2);
		if(wheelColor.brightness != 0)
		{
			var hueWrap:Float = wheelColor.hue * Math.PI / 180;
			colorWheelSelector.x += Math.sin(hueWrap) * colorWheel.width/2 * wheelColor.saturation;
			colorWheelSelector.y -= Math.cos(hueWrap) * colorWheel.height/2 * wheelColor.saturation;
		}
		colorGradientSelector.y = colorGradient.y + colorGradient.height * (1 - color.brightness);

		var strumRGB:RGBShaderReference = myNotes.members[curSelectedNote].rgbShader;
		switch(curSelectedMode)
		{
			case 0:
				getShader().r = strumRGB.r = color;
			case 1:
				getShader().g = strumRGB.g = color;
			case 2:
				getShader().b = strumRGB.b = color;
		}
	}

	function setShaderColor(value:FlxColor) dataArray[curSelectedNote][curSelectedMode] = value;
	function getShaderColor() return dataArray[curSelectedNote][curSelectedMode];
	/**
	 * 当前轨道色板: 直接用 spawnNotes 时按 9K 布局缓存的色板对象
	 * (像素/非像素在 onPixel 切换时已按当时 isPixelStage 创建好),
	 * 不能再重新 initialize——那样会按恢复后的 PlayState.isPixelStage
	 * 取错 arrowRGB / arrowRGBPixel。
	 */
	function getShader():RGBPalette
	{
		var palette:RGBPalette = Note.globalRgbShaders[curSelectedNote + 8 * 64];
		if (palette == null)
			palette = Note.initializeGlobalRGBShader(curSelectedNote, 8);
		return palette;
	}
}
