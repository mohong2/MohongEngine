package android.flixel;

import flixel.input.keyboard.FlxKey;
import EKData.Keybinds;
import states.PlayState;
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

		var mainY:Int;
		var mainH:Int;
		var extraY:Int = 0;
		var showExtra:Bool = ClientPrefs.data.hitboxExtraToggle;

		if (showExtra)
		{
			if (ClientPrefs.data.hitboxExtraPos == "Top")
			{
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

		for (i in 0...ammo)
			add(hints[i] = createHint(i * perHintWidth, mainY, perHintWidth, mainH, colors[i], i));

		// 多k: 轨道数 >4 时不再叠加额外的 2 个功能键, 避免覆盖轨道色块
		if (showExtra && ammo <= 4)
		{
			add(hints[4] = createHint(0, extraY, halfWidth, bottomHeight, 0xFFFF00));
			add(hints[5] = createHint(halfWidth, extraY, halfWidth, bottomHeight, 0x00FFFF));
		}

		if (ClientPrefs.data.mobileCEx && ammo <= 4)
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

		var notifyKeyName:String = null;
		var isMultiK:Bool = (PlayState.SONG != null && PlayState.SONG.mania != null && PlayState.SONG.mania != Note.defaultMania);
		if (isMultiK)
		{
			// 多k: 所有轨道直接按多k键位 (0-3 也读多k键位)
			var mania:Int = (PlayState.SONG != null && PlayState.SONG.mania != null) ? PlayState.SONG.mania : Note.defaultMania;
			var binds:Array<Array<Dynamic>> = Keybinds.fill();
			if (mania >= 0 && mania < binds.length && hintIndex >= 0 && hintIndex < binds[mania].length)
			{
				var laneKeys:Array<FlxKey> = binds[mania][hintIndex];
				if (laneKeys != null && laneKeys.length > 0)
					notifyKeyName = Std.string(laneKeys[0]);
			}
		}
		else if (hintIndex >= 0 && hintIndex < 4)
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

		// 多k: 4K 以上轨道 (或整个多k Hitbox) → 直接驱动 PlayState 按键
		if (hintIndex >= 4 || isMultiK)
		{
			if (notifyKeyName == null)
				notifyKeyName = Std.string(FlxKey.NONE);
		}

		if (notifyKeyName != null)
		{
			hint.onDown.callback = function() { Replay.notifyPress(notifyKeyName); };
			hint.onUp.callback = function() { Replay.notifyRelease(notifyKeyName); };
			hint.onOut.callback = function() { Replay.notifyRelease(notifyKeyName); };
		}

		// 多k: 直接驱动按键 (同时保留 Replay 录制)
		if (hintIndex >= 4 || isMultiK)
		{
			var oldDown = hint.onDown.callback;
			var oldUp = hint.onUp.callback;
			var oldOut = hint.onOut.callback;
			hint.onDown.callback = function()
			{
				if (oldDown != null) oldDown();
				if (PlayState.instance != null) PlayState.instance.mobileKeyPressed(hintIndex);
			};
			hint.onUp.callback = function()
			{
				if (oldUp != null) oldUp();
				if (PlayState.instance != null) PlayState.instance.mobileKeyReleased(hintIndex);
			};
			hint.onOut.callback = function()
			{
				if (oldOut != null) oldOut();
				if (PlayState.instance != null) PlayState.instance.mobileKeyReleased(hintIndex);
			};
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
