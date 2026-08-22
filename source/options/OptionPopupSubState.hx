package options;

import backend.MusicBeatSubstate;
import backend.UIScreen;
import Highscore;
import FlxTextMenuItem;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxColor;
import flixel.util.FlxSpriteUtil;

/**
 * Modal popup used by the settings UI for string dropdowns and numeric sliders.
 *
 * - String options: Enter/click opens a dropdown list; Up/Down or mouse hover
 *   moves the highlight; Enter/click confirms; ESC/Back cancels.
 * - Numeric options: Enter/click opens a slider; Left/Right or mouse drag
 *   changes a temporary value; Enter confirms; ESC/Back cancels.
 * - The popup is a real FlxSubState, so the parent settings view is paused
 *   while it is open. This also stops mouse and keyboard from fighting.
 */
class OptionPopupSubState extends MusicBeatSubstate
{
	public var option:Option;
	public var onConfirm:Void->Void = null;
	public var onCancel:Void->Void = null;

	var isDropdown:Bool = false;
	var firstUpdate:Bool = true;

	var substateCam:flixel.FlxCamera;

	var bg:FlxSprite;
	var panel:FlxSprite;
	var titleText:FlxText;
	var valueText:FlxText;

	// Dropdown
	var optionTexts:FlxTypedGroup<FlxTextMenuItem>;
	var dropdownSelector:FlxText;
	var curIndex:Int = 0;

	// Slider
	var sliderTrack:FlxSprite;
	var sliderFill:FlxSprite;
	var sliderKnob:FlxSprite;
	var minText:FlxText;
	var maxText:FlxText;
	var holdValue:Float = 0;
	var sliderDragging:Bool = false;

	public function new(option:Option, ?onConfirm:Void->Void, ?onCancel:Void->Void)
	{
		super();
		this.option = option;
		this.onConfirm = onConfirm;
		this.onCancel = onCancel;
		isDropdown = (option.type == 'string');
	}

	override function create():Void
	{
		super.create();

		substateCam = UIScreen.createScreenCamera();
		cameras = [substateCam];

		bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.fromRGBFloat(0, 0, 0, 0.55));
		bg.alpha = 0;
		add(bg);
		FlxTween.tween(bg, {alpha: 1}, 0.15, {ease: FlxEase.quadOut});

		var panelW:Int = 520;
		var panelH:Int = isDropdown ? (100 + option.options.length * 44 + 24) : 260;
		if (panelH > 520) panelH = 520;

		var panelX:Float = (FlxG.width - panelW) / 2;
		var panelY:Float = (FlxG.height - panelH) / 2;

		panel = UIScreen.makeGlassCard(panelX, panelY, panelW, panelH, 14, FlxColor.fromRGBFloat(0.07, 0.10, 0.18, 0.92));
		panel.alpha = 0;
		add(panel);
		FlxTween.tween(panel, {alpha: 1}, 0.2, {ease: FlxEase.backOut});

		titleText = new FlxText(panelX + 24, panelY + 18, panelW - 48, option.name, 26);
		titleText.setFormat(Paths.optionsfont(), 26, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		titleText.borderSize = 2.2;
		titleText.alpha = 0;
		add(titleText);
		FlxTween.tween(titleText, {alpha: 1}, 0.18, {ease: FlxEase.quadOut});

		valueText = new FlxText(panelX + 24, panelY + 54, panelW - 48, "", 18);
		valueText.setFormat(Paths.optionsfont(), 18, FlxColor.fromRGB(180, 200, 220), LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		valueText.borderSize = 2.0;
		valueText.alpha = 0;
		add(valueText);
		FlxTween.tween(valueText, {alpha: 1}, 0.18, {ease: FlxEase.quadOut});

		if (isDropdown)
		{
			buildDropdown(panelX, panelY, panelW);
		}
		else
		{
			buildSlider(panelX, panelY, panelW, panelH);
		}

		#if android
		addVirtualPad(LEFT_FULL, A_B);
		addPadCamera();
		#end
	}

	function buildDropdown(panelX:Float, panelY:Float, panelW:Int):Void
	{
		curIndex = option.options.indexOf(Std.string(option.getValue()));
		if (curIndex < 0) curIndex = 0;

		optionTexts = new FlxTypedGroup<FlxTextMenuItem>();
		add(optionTexts);

		var startY:Float = panelY + 86;
		var lineH:Float = 40;
		for (i in 0...option.options.length)
		{
			var t = new FlxTextMenuItem(panelX + 48, startY + i * lineH, option.options[i], 22);
			t.isMenuItem = false; // popup list should stay static
			t.snapToPosition();
			t.ID = i;
			t.alpha = 0;
			optionTexts.add(t);
			FlxTween.tween(t, {alpha: 1}, 0.16, {startDelay: 0.04 + i * 0.02, ease: FlxEase.quadOut});
		}

		dropdownSelector = new FlxText(panelX + 18, startY, 30, ">", 26);
		dropdownSelector.setFormat(Paths.optionsfont(), 26, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		dropdownSelector.borderSize = 2.2;
		dropdownSelector.alpha = 0;
		add(dropdownSelector);
		FlxTween.tween(dropdownSelector, {alpha: 1}, 0.16, {ease: FlxEase.quadOut});

		refreshDropdown();
	}

	function refreshDropdown():Void
	{
		for (item in optionTexts)
		{
			item.color = (item.ID == curIndex) ? FlxColor.WHITE : FlxColor.fromRGB(150, 165, 185);
			item.scale.set((item.ID == curIndex) ? 1.05 : 1.0, (item.ID == curIndex) ? 1.05 : 1.0);
		}
		if (optionTexts.length > 0 && optionTexts.members[curIndex] != null)
		{
			var sel = optionTexts.members[curIndex];
			dropdownSelector.y = sel.y;
		}
		valueText.text = option.options[curIndex];
	}

	function buildSlider(panelX:Float, panelY:Float, panelW:Int, panelH:Int):Void
	{
		holdValue = Std.parseFloat(Std.string(option.getValue()));
		if (Math.isNaN(holdValue)) holdValue = 0;
		if (option.minValue != null && holdValue < option.minValue) holdValue = option.minValue;
		if (option.maxValue != null && holdValue > option.maxValue) holdValue = option.maxValue;

		var trackX:Float = panelX + 60;
		var trackY:Float = panelY + 130;
		var trackW:Float = panelW - 120;
		var trackH:Int = 8;

		sliderTrack = new FlxSprite(trackX, trackY).makeGraphic(Std.int(trackW), trackH, FlxColor.fromRGB(45, 50, 65));
		sliderTrack.alpha = 0;
		add(sliderTrack);
		FlxTween.tween(sliderTrack, {alpha: 1}, 0.2, {ease: FlxEase.quadOut});

		sliderFill = new FlxSprite(trackX, trackY).makeGraphic(1, trackH, FlxColor.fromRGB(0, 200, 220));
		sliderFill.alpha = 0;
		add(sliderFill);
		FlxTween.tween(sliderFill, {alpha: 1}, 0.2, {ease: FlxEase.quadOut});

		sliderKnob = new FlxSprite(trackX + 2, trackY - 7).makeGraphic(16, 22, FlxColor.WHITE);
		sliderKnob.alpha = 0;
		add(sliderKnob);
		FlxTween.tween(sliderKnob, {alpha: 1}, 0.2, {ease: FlxEase.quadOut});

		minText = new FlxText(panelX + 24, panelY + 160, 180, Std.string(option.minValue), 15);
		minText.setFormat(Paths.optionsfont(), 15, FlxColor.fromRGB(150, 160, 180), LEFT);
		minText.alpha = 0;
		add(minText);

		maxText = new FlxText(panelX + panelW - 204, panelY + 160, 180, Std.string(option.maxValue), 15);
		maxText.setFormat(Paths.optionsfont(), 15, FlxColor.fromRGB(150, 160, 180), RIGHT);
		maxText.alpha = 0;
		add(maxText);

		FlxTween.tween(minText, {alpha: 1}, 0.18, {ease: FlxEase.quadOut});
		FlxTween.tween(maxText, {alpha: 1}, 0.18, {ease: FlxEase.quadOut});

		refreshSlider();
	}

	function sliderFraction():Float
	{
		var min:Float = (option.minValue != null) ? option.minValue : 0;
		var max:Float = (option.maxValue != null) ? option.maxValue : 1;
		if (max <= min) return 0;
		return FlxMath.bound((holdValue - min) / (max - min), 0, 1);
	}

	function refreshSlider():Void
	{
		if (sliderKnob == null) return;

		var trackW:Float = sliderTrack.width;
		var frac:Float = sliderFraction();
		var kx:Float = sliderTrack.x + frac * trackW - sliderKnob.width / 2;
		sliderKnob.x = kx;
		sliderFill.setGraphicSize(Std.int(trackW * frac), Std.int(sliderFill.height));
		sliderFill.updateHitbox();
		valueText.text = option.displayFormat.replace('%v', formatTempValue()).replace('%d', Std.string(option.defaultValue));
	}

	function formatTempValue():String
	{
		if (option.type == 'percent') return Std.string(Highscore.floorDecimal(holdValue * 100, option.decimals));
		if (option.type == 'int') return Std.string(Math.round(holdValue));
		return Std.string(Highscore.floorDecimal(holdValue, option.decimals));
	}

	function confirm():Void
	{
		if (isDropdown)
		{
			if (curIndex >= 0 && curIndex < option.options.length)
			{
				option.curOption = curIndex;
				option.setValue(option.options[curIndex]);
			}
		}
		else
		{
			if (option.type == 'int')
				holdValue = Math.round(holdValue);
			else if (option.type == 'float' || option.type == 'percent')
				holdValue = FlxMath.roundDecimal(holdValue, option.decimals);
			option.setValue(holdValue);
		}

		option.change();
		if (onConfirm != null) onConfirm();
		FlxG.sound.play(Paths.sound('confirmMenu'));
		close();
	}

	function cancel():Void
	{
		if (onCancel != null) onCancel();
		FlxG.sound.play(Paths.sound('cancelMenu'));
		close();
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);

		// The popup is opened during the same frame as the parent's Enter/click.
		// Skip one update so that input does not immediately confirm/cancel it.
		if (firstUpdate)
		{
			firstUpdate = false;
			return;
		}

		var keyboardUsed:Bool = false;

		if (isDropdown)
		{
			var changed:Bool = false;
			if (controls.UI_UP_P) { curIndex--; changed = true; keyboardUsed = true; }
			if (controls.UI_DOWN_P) { curIndex++; changed = true; keyboardUsed = true; }
			if (changed)
			{
				if (curIndex < 0) curIndex = option.options.length - 1;
				if (curIndex >= option.options.length) curIndex = 0;
				refreshDropdown();
				FlxG.sound.play(Paths.sound('scrollMenu'));
			}
			if (controls.ACCEPT) { keyboardUsed = true; confirm(); return; }
			if (controls.BACK) { keyboardUsed = true; cancel(); return; }
			if (!keyboardUsed) handleDropdownMouse();
		}
		else
		{
			var min:Float = (option.minValue != null) ? option.minValue : 0;
			var max:Float = (option.maxValue != null) ? option.maxValue : 1;
			var add:Float = (option.changeValue != null) ? option.changeValue : 1;
			if (controls.UI_LEFT_P) { holdValue -= add; keyboardUsed = true; }
			else if (controls.UI_RIGHT_P) { holdValue += add; keyboardUsed = true; }
			if (keyboardUsed)
			{
				holdValue = FlxMath.bound(holdValue, min, max);
				refreshSlider();
			}
			if (controls.ACCEPT) { keyboardUsed = true; confirm(); return; }
			if (controls.BACK) { keyboardUsed = true; cancel(); return; }
			if (!keyboardUsed) handleSliderMouse();
		}
	}

	function handleDropdownMouse():Void
	{
		var cam:flixel.FlxCamera = (substateCam != null) ? substateCam : FlxG.camera;
		var pt = FlxG.mouse.getWorldPosition(cam, FlxPoint.get());
		var mx:Float = pt.x;
		var my:Float = pt.y;
		pt.put();

		var hoverIndex:Int = -1;
		for (item in optionTexts)
		{
			if (mx >= item.x && mx <= item.x + item.width && my >= item.y && my <= item.y + item.height)
			{
				hoverIndex = item.ID;
				break;
			}
		}
		if (hoverIndex >= 0 && hoverIndex != curIndex)
		{
			curIndex = hoverIndex;
			refreshDropdown();
		}
		if (FlxG.mouse.justPressed)
		{
			if (hoverIndex >= 0)
			{
				curIndex = hoverIndex;
				confirm();
			}
			else if (mx < panel.x || mx > panel.x + panel.width || my < panel.y || my > panel.y + panel.height)
			{
				cancel();
			}
		}
	}

	function handleSliderMouse():Void
	{
		var cam:flixel.FlxCamera = (substateCam != null) ? substateCam : FlxG.camera;
		var pt = FlxG.mouse.getWorldPosition(cam, FlxPoint.get());
		var mx:Float = pt.x;
		var my:Float = pt.y;
		pt.put();

		var min:Float = (option.minValue != null) ? option.minValue : 0;
		var max:Float = (option.maxValue != null) ? option.maxValue : 1;
		var trackW:Float = sliderTrack.width;
		var trackX:Float = sliderTrack.x;
		var trackY:Float = sliderTrack.y;

		if (FlxG.mouse.justPressed)
		{
			if (my >= trackY - 14 && my <= trackY + 22 && mx >= trackX - 8 && mx <= trackX + trackW + 8)
			{
				sliderDragging = true;
			}
			else
			{
				// Click outside the panel cancels; inside panel does nothing.
				if (mx < panel.x || mx > panel.x + panel.width || my < panel.y || my > panel.y + panel.height)
					cancel();
			}
		}
		if (sliderDragging)
		{
			var frac:Float = FlxMath.bound((mx - trackX) / trackW, 0, 1);
			holdValue = min + frac * (max - min);
			refreshSlider();
			if (FlxG.mouse.justReleased)
			{
				sliderDragging = false;
			}
		}
	}

	override function destroy():Void
	{
		if (substateCam != null)
		{
			FlxG.cameras.remove(substateCam, true);
			substateCam = null;
		}
		super.destroy();
	}
}
