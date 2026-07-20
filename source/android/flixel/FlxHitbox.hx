package android.flixel;

import flixel.input.keyboard.FlxKey;
import flixel.util.FlxDestroyUtil;
import android.flixel.FlxButton;
import openfl.display.BitmapData;
import openfl.display.Shape;
import openfl.geom.Matrix;
import Replay;

/**
 * A zone with 4 hint's (A hitbox).
 * It's really easy to customize the layout.
 *
 * @author Mihai Alexandru (M.A. Jigsaw)
 */
class FlxHitbox extends FlxSpriteGroup
{
	final offsetFir:Int = (ClientPrefs.data.hitboxPos ? Std.int(FlxG.height / 4) * 3 : 0);
	final offsetSec:Int = (ClientPrefs.data.hitboxPos ? 0 : Std.int(FlxG.height / 4));
	final bottomHeight:Int = 120; // 底部区域高度

	public var hints(default, null):Array<FlxButton>;

	/**
	 * Create the zone.
	 * 
	 * @param ammo The ammount of hints you want to create.
	 * @param perHintWidth The width that the hints will use.
	 * @param perHintHeight The height that the hints will use.
	 * @param colors The color per hint.
	 */
	public function new(ammo:UInt, perHintWidth:Int, perHintHeight:Int, colors:Array<FlxColor>):Void
	{
		super();

		hints = new Array<FlxButton>();

		if (colors == null || (colors != null && colors.length < ammo))
			colors = [0xFFFFFF, 0xFFFFFF, 0xFFFFFF, 0xFFFFFF];

		var topHeight = perHintHeight - bottomHeight;
		var halfWidth = Std.int(FlxG.width / 2);

		// 计算 4 个主按键的 Y 和高度（根据额外按钮开关/位置动态调整）
		var mainY:Int;
		var mainH:Int;
		var extraY:Int = 0;
		var showExtra:Bool = ClientPrefs.data.hitboxExtraToggle;

		if (showExtra)
		{
			if (ClientPrefs.data.hitboxExtraPos == "Top")
			{
				// 额外按钮在顶部 → 主按键下移
				extraY = 0;
				if (ClientPrefs.data.mobileCEx)
				{
					mainY = offsetSec + bottomHeight;
					mainH = Std.int(FlxG.height / ammo) * 3 - bottomHeight;
				}
				else
				{
					mainY = bottomHeight;
					mainH = topHeight;
				}
			}
			else
			{
				// 额外按钮在底部 → 主按键保持在上方
				if (ClientPrefs.data.mobileCEx)
				{
					mainY = offsetSec;
					mainH = Std.int(FlxG.height / ammo) * 3;
				}
				else
				{
					mainY = 0;
					mainH = topHeight;
				}
				extraY = mainY + mainH;
			}
		}
		else
		{
			// 无额外按钮 → 4 个主按键铺满可用区域
			if (ClientPrefs.data.mobileCEx)
			{
				mainY = offsetSec;
				mainH = Std.int(FlxG.height / ammo) * 3;
			}
			else
			{
				mainY = 0;
				mainH = perHintHeight;
			}
		}

		// 创建 4 个方向键（传入 hintIndex 以从设置读取键值并模拟键盘按键）
		for (i in 0...ammo)
			add(hints[i] = createHint(i * perHintWidth, mainY, perHintWidth, mainH, colors[i], i));

		// 额外 SPACE / SHIFT 按钮
		if (showExtra)
		{
			add(hints[4] = createHint(0, extraY, halfWidth, bottomHeight, 0xFFFF00));
			add(hints[5] = createHint(halfWidth, extraY, halfWidth, bottomHeight, 0x00FFFF));
		}

		if (ClientPrefs.data.mobileCEx)
			add(hints[6] = createHint(0, offsetFir, FlxG.width, Std.int(FlxG.height / 4), 0xFF0066FF));

		scrollFactor.set();
	}

	/**
	 * Clean up memory.
	 */
	override public function destroy():Void
	{
		super.destroy();

		for (i in 0...hints.length)
			hints[i] = FlxDestroyUtil.destroy(hints[i]);

		hints.splice(0, hints.length);
	}

	// FlxHitbox.hx 的 createHint 方法中添加键盘触发逻辑

	private function createHint(X:Float, Y:Float, Width:Int, Height:Int, Color:Int = 0xFFFFFF, ?hintIndex:Int = -1):FlxButton
	{
		final guh2:Float = 0.00001;
		final guh:Float = ClientPrefs.data.mobileCAlpha >= 0.9 ? ClientPrefs.data.mobileCAlpha - 0.2 : ClientPrefs.data.mobileCAlpha;
		var hint:FlxButton = new FlxButton(X, Y);
		hint.loadGraphic(createHintGraphic(Width, Height, Color));
		hint.solid = false;
		hint.multiTouch = true;
		hint.immovable = true;
		hint.moves = false;
		hint.antialiasing = ClientPrefs.data.globalAntialiasing;
		hint.scrollFactor.set();
		hint.alpha = guh2;

		// ---- 从设置读取键值，直接通知 Replay 录制（不修改 FlxG.keys，避免 Controls 二次判定） ----
		var notifyKeyName:String = null;
		if (hintIndex >= 0 && hintIndex < 4)
		{
			var bindName:String = switch(hintIndex) {
				case 0: 'note_left';
				case 1: 'note_down';
				case 2: 'note_up';
				case 3: 'note_right';
				default: null;
			}
			if (bindName != null)
			{
				var noteKeys:Array<FlxKey> = ClientPrefs.keyBinds.get(bindName);
				if (noteKeys != null && noteKeys.length > 0)
					notifyKeyName = Std.string(noteKeys[0]);
			}
		}
		else if (Color == 0xFFFF00)
			notifyKeyName = Std.string(FlxKey.SPACE);
		else if (Color == 0x00FFFF)
			notifyKeyName = Std.string(FlxKey.SHIFT);

		if (notifyKeyName != null)
		{
			hint.onDown.callback = function() { Replay.notifyPress(notifyKeyName); };
			hint.onUp.callback = function() { Replay.notifyRelease(notifyKeyName); };
			hint.onOut.callback = function() { Replay.notifyRelease(notifyKeyName); };
		}

		// ---- 视觉反馈（仅在非隐藏模式下） ----
		if (ClientPrefs.data.hitboxType != "Hidden")
		{
			var oldDown = hint.onDown.callback;
			var oldUp = hint.onUp.callback;
			var oldOut = hint.onOut.callback;

			hint.onDown.callback = function()
			{
				if (oldDown != null) oldDown();
				if (hint.alpha != guh) hint.alpha = guh;
			}
			hint.onUp.callback = function()
			{
				if (oldUp != null) oldUp();
				if (hint.alpha != guh2) hint.alpha = guh2;
			}
			hint.onOut.callback = function()
			{
				if (oldOut != null) oldOut();
				if (hint.alpha != guh2) hint.alpha = guh2;
			}
		}
		#if FLX_DEBUG
		hint.ignoreDrawDebug = true;
		#end
		return hint;
}

	private function createHintGraphic(Width:Int, Height:Int, Color:Int = 0xFFFFFF):BitmapData
	{
		var guh:Float = ClientPrefs.data.mobileCAlpha;
		if (guh >= 0.9)
			guh = ClientPrefs.data.mobileCAlpha - 0.07;
		var shape:Shape = new Shape();
		shape.graphics.beginFill(Color);
		if (ClientPrefs.data.hitboxType == "No Gradient")
		{
			var matrix:Matrix = new Matrix();
			matrix.createGradientBox(Width, Height, 0, 0, 0);

			shape.graphics.beginGradientFill(RADIAL, [Color, Color], [0, guh], [60, 255], matrix, PAD, RGB, 0);
			shape.graphics.drawRect(0, 0, Width, Height);
			shape.graphics.endFill();
		}
		else if (ClientPrefs.data.hitboxType == "No Gradient (Old)")
		{
			shape.graphics.lineStyle(10, Color, 1);
			shape.graphics.drawRect(0, 0, Width, Height);
			shape.graphics.endFill();
		}
		else
		{
			shape.graphics.lineStyle(3, Color, 1);
			shape.graphics.drawRect(0, 0, Width, Height);
			shape.graphics.lineStyle(0, 0, 0);
			shape.graphics.drawRect(3, 3, Width - 6, Height - 6);
			shape.graphics.endFill();
			shape.graphics.beginGradientFill(RADIAL, [Color, FlxColor.TRANSPARENT], [guh, 0], [0, 255], null, null, null, 0.5);
			shape.graphics.drawRect(3, 3, Width - 6, Height - 6);
			shape.graphics.endFill();
		}
		var bitmap:BitmapData = new BitmapData(Width, Height, true, 0);
		bitmap.draw(shape, true);
		return bitmap;
	}
}