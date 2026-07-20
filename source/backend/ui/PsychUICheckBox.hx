package backend.ui;

import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;

class PsychUICheckBox extends FlxSpriteGroup
{
	public static final CLICK_EVENT = 'checkbox_click';

	public var name:String;
	public var box:FlxSprite;
	public var text:FlxText;
	public var label(get, set):String;

	public var checked(default, set):Bool = false;
	public var onClick:Void->Void = null;

	/** If true, hover/click on the checkbox will scale it smoothly. */
	public var smoothAnimations:Bool = true;

	public function new(x:Float, y:Float, label:String, ?textWid:Int = 100, ?callback:Void->Void, ?font:String, ?size:Int = 10)
	{
		super(x, y);

		box = new FlxSprite();
		boxGraphic();
		add(box);

		text = new FlxText(box.width + 4, 0, textWid, label);
		if(font == null) text.font = 'assets/fonts/editors.ttf';
		else 
		text.font = Paths.font(font);
		text.borderSize = 2;
		text.size = size;
		add(text);

		this.onClick = callback;
	}

	public function boxGraphic()
	{
		box.loadGraphic(Paths.image('psych-ui/checkbox', 'embed'), true, 16, 16);
		box.animation.add('false', [0]);
		box.animation.add('true', [1]);
		box.animation.play('false');
	}

	public var broadcastCheckBoxEvent:Bool = true;
	var _hovered:Bool = false;
	override function update(elapsed:Float)
	{
		super.update(elapsed);

		var screenPos:FlxPoint = getScreenPosition(null, camera);
		var mousePos:FlxPoint = FlxG.mouse.getPositionInCameraView(camera);
		var overBox:Bool = (mousePos.x >= screenPos.x && mousePos.x < screenPos.x + width) &&
			(mousePos.y >= screenPos.y && mousePos.y < screenPos.y + height);

		// Hover scale effect
		if(overBox != _hovered)
		{
			_hovered = overBox;
			if(smoothAnimations)
			{
				FlxTween.cancelTweensOf(box, ['scale.x', 'scale.y']);
				FlxTween.tween(box.scale, {x: overBox ? 1.15 : 1.0, y: overBox ? 1.15 : 1.0}, 0.1, {ease: FlxEase.backOut});
			}
		}

		if(FlxG.mouse.justPressed && overBox)
		{
			checked = !checked;
			if(smoothAnimations)
			{
				FlxTween.cancelTweensOf(box, ['scale.x', 'scale.y']);
				box.scale.set(0.85, 0.85);
				FlxTween.tween(box.scale, {x: 1.0, y: 1.0}, 0.15, {ease: FlxEase.backOut});
			}
			if(onClick != null) onClick();
			if(broadcastCheckBoxEvent) PsychUIEventHandler.event(CLICK_EVENT, this);
		}
	}

	function set_checked(v:Bool):Bool
	{
		box.animation.play(Std.string(v));
		return (checked = v);
	}

	function get_label():String {
		return text.text;
	}
	function set_label(v:String):String {
		return (text.text = v);
	}
}