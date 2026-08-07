package popup;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.util.FlxColor;

/**
 * Simple in-game modal popup - cross-platform fallback for dialogs.
 * 游戏内弹窗兜底（iOS / 没有 zenity 等外部工具的 Linux / macOS）。
 * Uses system font so Chinese text renders correctly.
 */
class DialogPopup extends FlxSpriteGroup
{
	static var _active:DialogPopup = null;

	var _buttons:Array<FlxSprite> = [];
	var _callbacks:Array<Void->Void> = [];

	public static function show(title:String, message:String, labels:Array<String>, callbacks:Array<Void->Void>):Void
	{
		if (_active != null)
			_active.destroyPopup();
		_active = new DialogPopup(title, message, labels, callbacks);
		FlxG.state.add(_active);
	}

	public function new(title:String, message:String, labels:Array<String>, callbacks:Array<Void->Void>)
	{
		super();

		scrollFactor.set();
		_callbacks = (callbacks == null) ? [] : callbacks;

		var overlay = new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, 0xAA000000);
		overlay.scrollFactor.set();
		add(overlay);

		var boxW:Int = 480;
		var boxH:Int = 230;
		var boxX:Float = (FlxG.width - boxW) / 2;
		var boxY:Float = (FlxG.height - boxH) / 2;

		var box = new FlxSprite(boxX, boxY).makeGraphic(boxW, boxH, FlxColor.fromRGB(38, 40, 54));
		box.scrollFactor.set();
		add(box);

		var titleText = new FlxText(boxX + 22, boxY + 16, boxW - 44, title, 20, false);
		titleText.scrollFactor.set();
		add(titleText);

		var msgText = new FlxText(boxX + 22, boxY + 60, boxW - 44, message, 13, false);
		msgText.scrollFactor.set();
		add(msgText);

		if (labels == null || labels.length == 0)
			labels = ['OK'];

		var btnH:Float = 36;
		var gap:Float = 12;
		var widths:Array<Float> = [];
		var totalW:Float = 0;
		for (label in labels)
		{
			var w:Float = Math.max(100, 20 + label.length * 14);
			widths.push(w);
			totalW += w + gap;
		}
		totalW -= gap;

		var x:Float = boxX + (boxW - totalW) / 2;
		var y:Float = boxY + boxH - btnH - 16;
		for (i in 0...labels.length)
		{
			var bg = new FlxSprite(x, y).makeGraphic(Std.int(widths[i]), Std.int(btnH), FlxColor.fromRGB(74, 82, 108));
			bg.scrollFactor.set();
			add(bg);

			var lbl = new FlxText(x, y + (btnH - 18) / 2, widths[i], labels[i], 14, false);
			lbl.alignment = FlxTextAlign.CENTER;
			lbl.scrollFactor.set();
			add(lbl);

			_buttons.push(bg);
			x += widths[i] + gap;
		}
	}

	public function destroyPopup():Void
	{
		if (_active == this)
			_active = null;
		destroy();
	}

	function fire(index:Int):Void
	{
		var cb = (index >= 0 && index < _callbacks.length) ? _callbacks[index] : null;
		destroyPopup();
		if (cb != null)
			cb();
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (FlxG.keys.justPressed.ENTER)
			fire(0);
		else if (FlxG.keys.justPressed.ESCAPE)
			fire(_buttons.length - 1);

		if (FlxG.mouse.justPressed)
		{
			var mx = FlxG.mouse.screenX;
			var my = FlxG.mouse.screenY;
			for (i in 0..._buttons.length)
			{
				var b = _buttons[i];
				if (mx >= b.x && mx <= b.x + b.width && my >= b.y && my <= b.y + b.height)
				{
					fire(i);
					break;
				}
			}
		}
	}
}
