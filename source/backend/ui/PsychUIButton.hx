package backend.ui;

import backend.ui.PsychUIBox.UIStyleData;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.tweens.misc.NumTween;

class PsychUIButton extends FlxSpriteGroup
{
	public static final CLICK_EVENT = 'button_click';

	public var name:String;
	public var label(default, set):String;
	public var bg:FlxSprite;
	public var text:FlxText;

	public var onChangeState:String->Void;
	public var onClick:Void->Void;
	
	public var clickStyle:UIStyleData = {
		bgColor: FlxColor.BLACK,
		textColor: FlxColor.WHITE,
		bgAlpha: 1
	};
	public var hoverStyle:UIStyleData = {
		bgColor: FlxColor.WHITE,
		textColor: FlxColor.BLACK,
		bgAlpha: 1
	};
	public var normalStyle:UIStyleData = {
		bgColor: 0xFFAAAAAA,
		textColor: FlxColor.BLACK,
		bgAlpha: 1
	};

	/** Corner radius for the button background. Set to 0 for sharp corners. */
	public var borderRadius(default, set):Int = -1;

	// Persistent tween references – avoids VarTween reflection issues on FlxCallbackPoint (FlxSpriteGroup)
	var _hoverTween:NumTween;
	var _clickTween:NumTween;

	public function new(x:Float = 0, y:Float = 0, label:String = '', ?onClick:Void->Void = null, ?wid:Int = 80, ?hei:Int = 20, ?font:String, ?size:Int = 9, ?textX:Float = 0, ?textY:Float = 0)
	{
		super(x, y);
		bg = PsychUIHelper.createRoundedRectSprite(wid, hei, borderRadius);
		add(bg);
		bg.color = normalStyle.bgColor;
		bg.alpha = normalStyle.bgAlpha;

		text = new FlxText(textX, textY, 1, '');
		text.size = size;
		if(font == null) text.font = 'assets/fonts/editors.ttf';
		else text.font = Paths.font(font);
		text.alignment = CENTER;
		text.borderSize = 2;
		text.antialiasing = false;
		text.textField.sharpness = 400;
		add(text);

		this.label = label;
		resize(wid, hei);
		
		this.onClick = onClick;
		forceCheckNext = true;
		if(Language.has(label))
			text.text = Language.get(label);
	}

	public var isClicked:Bool = false;
	public var forceCheckNext:Bool = false;
	public var broadcastButtonEvent:Bool = true;

	/** If true, hover uses a subtle scale effect. */
	public var smoothAnimations(default, set):Bool = true;

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if(isClicked && !FlxG.mouse.pressed)
		{
			forceCheckNext = true;
			isClicked = false;
		}

		if(forceCheckNext || FlxG.mouse.justMoved || FlxG.mouse.justPressed || FlxG.mouse.justReleased)
		{
			var overlapped:Bool = (PsychUIEventHandler.overlaps(bg, camera));
			forceCheckNext = false;

			if(!isClicked)
			{
				var style:UIStyleData = (overlapped) ? hoverStyle : normalStyle;
				bg.color = style.bgColor;
				bg.alpha = style.bgAlpha;
				text.color = style.textColor;

				// subtle hover scale – use NumTween to avoid VarTween reflection issues on FlxCallbackPoint
				if(smoothAnimations)
				{
					var target:Float = overlapped ? 1.05 : 1.0;
					if(_hoverTween != null) _hoverTween.cancel();
					_hoverTween = FlxTween.num(scale.x, target, 0.1, {ease: FlxEase.backOut, onUpdate: function(t:FlxTween)
					{
						scale.x = cast(t, NumTween).value;
						scale.y = scale.x;
					}});
				}
			}

			if(overlapped && FlxG.mouse.justPressed)
			{
				isClicked = true;
				bg.color = clickStyle.bgColor;
				bg.alpha = clickStyle.bgAlpha;
				text.color = clickStyle.textColor;

				if(smoothAnimations)
				{
					if(_clickTween != null) _clickTween.cancel();
					scale.set(0.95, 0.95);
					_clickTween = FlxTween.num(0.95, 1.0, 0.15, {ease: FlxEase.backOut, onUpdate: function(t:FlxTween)
					{
						scale.x = cast(t, NumTween).value;
						scale.y = scale.x;
					}});
				}

				if(onClick != null) onClick();
				if(broadcastButtonEvent) PsychUIEventHandler.event(CLICK_EVENT, this);
			}
		}
	}

	public function resize(width:Int, height:Int)
	{
		// Scale the existing rounded-rect graphic to the new size
		bg.setGraphicSize(width, height);
		bg.updateHitbox();
		text.fieldWidth = width;
		text.x = bg.x;
		text.y = bg.y + (height / 2) - (text.height / 2);
	}

	function set_label(v:String)
	{
		if(text != null && text.exists) text.text = v;
		return (label = v);
	}

	function set_smoothAnimations(v:Bool):Bool
	{
		smoothAnimations = v;
		if(!v)
		{
			scale.set(1, 1);
			if(_hoverTween != null) _hoverTween.cancel();
			if(_clickTween != null) _clickTween.cancel();
		}
		return v;
	}

	function set_borderRadius(v:Int):Int
	{
		borderRadius = v;
		var w:Int = Std.int(bg.width);
		var h:Int = Std.int(bg.height);
		if(w < 2) w = 80;
		if(h < 2) h = 20;
		PsychUIHelper.makeRoundedRect(bg, w, h, (v < 0) ? -1 : v);
		// Reset scale after graphic replacement
		bg.setGraphicSize(w, h);
		bg.updateHitbox();
		return v;
	}

	override function destroy()
	{
		if(_hoverTween != null) _hoverTween.cancel();
		if(_clickTween != null) _clickTween.cancel();
		super.destroy();
	}
}