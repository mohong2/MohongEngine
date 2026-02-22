package;
//来自于NF引擎的键盘显示
import flixel.input.keyboard.FlxKey;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.Shape;
import openfl.utils.Assets;
import flixel.util.FlxSave;
import InputFormatter;
import options.OptionsHelpers;

class KeyboardDisplay extends FlxSpriteGroup
{
	public static var saveBitmap:DisBitmap;

	public var leftArray:Array<TimeDis> = [];
	public var downArray:Array<TimeDis> = [];
	public var upArray:Array<TimeDis> = [];
	public var rightArray:Array<TimeDis> = [];

	public var _x:Float;
	public var _y:Float;
	public var _width:Float;
	public var _height:Float;
	public var kpsText:FlxText;
	public var totalText:FlxText;

	var total:Int = 0;

	public static var instance:KeyboardDisplay;

	public function new(X:Float, Y:Float)
	{
		super();
		instance = this;

		_x = X;
		_y = Y;
		_width = (KeyButton.size + 4) * 4;
		_height = (KeyButton.size + 4) * 2;

		for (i in 0...4)
		{
			var obj:KeyButton = new KeyButton(X + (KeyButton.size + 4) * i, Y, KeyButton.size, KeyButton.size);
			add(obj);
		}
		for (i in 0...4)
		{
			var obj:KeyButtonAlpha = new KeyButtonAlpha(X + (KeyButton.size + 4) * i, Y);
			add(obj);
		}
		var textArray:Array<String> = createArray();
		for (i in 0...4)
		{
			var obj:FlxText = new FlxText(X + (KeyButton.size + 4) * i + members[4 + i].width / 2, Y + members[4 + i].height / 2, 50, textArray[i], 10, false);
			obj.setFormat(Assets.getFont("assets/fonts/montserrat.ttf").fontName, 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, 0x00);
			obj.x -= obj.width / 2;
			obj.y -= obj.height / 2;
			obj.color = OptionsHelpers.colorArray(ClientPrefs.data.keyboardTextColor);
			obj.alpha = ClientPrefs.data.keyboardAlpha;
			add(obj);
		}
		for (i in 0...2)
		{
			var obj:KeyButton = new KeyButton(X + (KeyButton.size + 4) * i * 2, Y + KeyButton.size + 4, KeyButton.size * 2 + 4, KeyButton.size);
			add(obj);
		}
		var textArray:Array<String> = ['KPS', 'total'];
		for (i in 0...2)
		{
			var obj:FlxText = new FlxText(members[12 + i].x + members[12 + i].width / 2, members[12 + i].y + members[12 + i].height / 4,
				KeyButton.size * 2 + 4, textArray[i], 20, false);
			obj.setFormat(Assets.getFont("assets/fonts/montserrat.ttf").fontName, 25, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, 0x00);
			obj.x -= obj.width / 2;
			obj.y -= obj.height / 2;
			obj.color = OptionsHelpers.colorArray(ClientPrefs.data.keyboardTextColor);
			obj.alpha = ClientPrefs.data.keyboardAlpha;
			obj.antialiasing = ClientPrefs.data.globalAntialiasing;
			add(obj);
		}
		kpsText = new FlxText(members[12].x + members[12].width / 2, members[12].y + members[12].height / 5 * 3.5, KeyButton.size * 2 + 4, '0', 15, false);
		kpsText.setFormat(Assets.getFont("assets/fonts/montserrat.ttf").fontName, 15, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, 0x00);
		kpsText.x -= kpsText.width / 2;
		kpsText.y -= kpsText.height / 2;
		kpsText.color = OptionsHelpers.colorArray(ClientPrefs.data.keyboardTextColor);
		kpsText.alpha = ClientPrefs.data.keyboardAlpha;

		if (FlxG.save.data.keyboardtotal != null)
			total = FlxG.save.data.keyboardtotal;
		totalText = new FlxText(members[13].x + members[13].width / 2, members[13].y + members[13].height / 5 * 3.5, KeyButton.size * 2 + 4,
			Std.string(total), 15, false);
		totalText.setFormat(Assets.getFont("assets/fonts/montserrat.ttf").fontName, 15, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, 0x00);
		totalText.x -= totalText.width / 2;
		totalText.y -= totalText.height / 2;
		totalText.color = OptionsHelpers.colorArray(ClientPrefs.data.keyboardTextColor);
		totalText.alpha = ClientPrefs.data.keyboardAlpha;
		add(kpsText);
		add(totalText);

		saveBitmap = new DisBitmap();

		var obj:TimeDis = new TimeDis(0, 0, _x, _y);
		obj.visible = false; // 把纹理保存在运存中,如果你愿意这玩意出bug就试试删了它
	}

	public function pressed(key:Int)
	{
		members[4 + key].alpha = 1 * ClientPrefs.data.keyboardAlpha;
		members[8 + key].color = FlxColor.BLACK;
		/*
		if (!PlayState.replayMode)*/
			total++;
		totalText.text = Std.string(total);
		hitArray.unshift(Date.now());
		
		//你看Mohong Engine有replay这个东西吗?
		if (!ClientPrefs.data.keyboardTimeDisplay)
			return;

		var obj:TimeDis = new TimeDis(key, Conductor.songPosition, _x, _y);
		add(obj);

		switch (key)
		{
			case 0:
				if (leftArray.length > 0 && leftArray[leftArray.length - 1].endTime == -999999)
					leftArray[leftArray.length - 1].endTime = Conductor.songPosition;
				leftArray.push(obj);
			case 1:
				if (downArray.length > 0 && downArray[downArray.length - 1].endTime == -999999)
					downArray[downArray.length - 1].endTime = Conductor.songPosition;
				downArray.push(obj);
			case 2:
				if (upArray.length > 0 && upArray[upArray.length - 1].endTime == -999999)
					upArray[upArray.length - 1].endTime = Conductor.songPosition;
				upArray.push(obj);
			case 3:
				if (rightArray.length > 0 && rightArray[rightArray.length - 1].endTime == -999999)
					rightArray[rightArray.length - 1].endTime = Conductor.songPosition;
				rightArray.push(obj);
		}
	}

	public function released(key:Int)
	{
		members[4 + key].alpha = 0;
		members[8 + key].color = OptionsHelpers.colorArray(ClientPrefs.data.keyboardTextColor);

		switch (key)
		{
			case 0:
				if (leftArray.length > 0 && leftArray[leftArray.length - 1].endTime == -999999)
					leftArray[leftArray.length - 1].endTime = Conductor.songPosition;
			case 1:
				if (downArray.length > 0 && downArray[downArray.length - 1].endTime == -999999)
					downArray[downArray.length - 1].endTime = Conductor.songPosition;
			case 2:
				if (upArray.length > 0 && upArray[upArray.length - 1].endTime == -999999)
					upArray[upArray.length - 1].endTime = Conductor.songPosition;
			case 3:
				if (rightArray.length > 0 && rightArray[rightArray.length - 1].endTime == -999999)
					rightArray[rightArray.length - 1].endTime = Conductor.songPosition;
		}
	}

	public function save()
	{
		FlxG.save.data.keyboardtotal = total;
		FlxG.save.flush();
	}
		public static function getKeyBinds():Map<String, Array<FlxKey>>
	{
		return ClientPrefs.keyBinds;
	}

	public function createArray():Array<String>
	{
		var array:Array<String> = [];
		var keyBinds = getKeyBinds();
		array.push(InputFormatter.getKeyName(keyBinds.get('note_left')[0]));
		array.push(InputFormatter.getKeyName(keyBinds.get('note_down')[0]));
		array.push(InputFormatter.getKeyName(keyBinds.get('note_up')[0]));
		array.push(InputFormatter.getKeyName(keyBinds.get('note_right')[0]));
		return array;
	}

	public function removeObj(obj:TimeDis)
	{
		switch (obj.line)
		{
			case 0:
				leftArray.remove(obj);
			case 1:
				downArray.remove(obj);
			case 2:
				upArray.remove(obj);
			case 3:
				rightArray.remove(obj);
		}
		remove(obj, true);
		obj.destroy();
	}

	public var kps:Int = 0;
	public var kpsCheck:Int = 0;
	public var hitArray:Array<Date> = [];

	public function dataUpdate(elapsed:Float)
	{
		var balls = hitArray.length - 1;
		while (balls >= 0)
		{
			var cock:Date = hitArray[balls];
			if (cock != null && cock.getTime() + 1000 < Date.now().getTime())
				hitArray.remove(cock);
			else
				balls = 0;
			balls--;
		}
		kps = hitArray.length;

		if (kpsCheck != kps)
		{
			kpsCheck = kps;
			kpsText.text = Std.string(kps);
		}
	}
}

class KeyButton extends FlxSprite
{
	var bgAlpha = 0.3 * ClientPrefs.data.keyboardAlpha;
	var lineAlpha = 0.8 * ClientPrefs.data.keyboardAlpha;

	public static var size = 50;

	public function new(X:Float, Y:Float, Width:Int, Height:Int)
	{
		super(X, Y);

		var shape:Shape = new Shape();
		shape.graphics.lineStyle(2, FlxColor.WHITE, lineAlpha);
		shape.graphics.drawRoundRect(0, 0, Width, Height, Std.int(size / 3), Std.int(size / 3));
		shape.graphics.lineStyle();
		shape.graphics.beginFill(FlxColor.WHITE, bgAlpha);
		shape.graphics.drawRoundRect(0, 0, Width, Height, Std.int(size / 3), Std.int(size / 3));
		shape.graphics.endFill();

		var BitmapData:BitmapData = new BitmapData(Width, Height, 0x00FFFFFF);
		BitmapData.draw(shape);

		loadGraphic(BitmapData);
		antialiasing = ClientPrefs.data.globalAntialiasing;
		color = OptionsHelpers.colorArray(ClientPrefs.data.keyboardBGColor);
	}
}

class KeyButtonAlpha extends FlxSprite
{
	var size = KeyButton.size;

	public var tween = FlxTween;

	public function new(X:Float, Y:Float)
	{
		super(X, Y);

		var shape:Shape = new Shape();
		shape.graphics.beginFill(FlxColor.WHITE, 1);
		shape.graphics.drawRoundRect(0, 0, size, size, Std.int(size / 3), Std.int(size / 3));
		shape.graphics.endFill();

		var BitmapData:BitmapData = new BitmapData(size, size, 0x00FFFFFF);
		BitmapData.draw(shape);

		loadGraphic(BitmapData);
		antialiasing = ClientPrefs.data.globalAntialiasing;
		alpha = 0;
	}
}

class TimeDis extends FlxSprite
{
	public var startTime:Float;
	public var endTime:Float = -999999;
	public var line:Int;

	var durationTime:Float = ClientPrefs.data.keyboardTime;

	public function new(Line:Int, Time:Float, X:Float, Y:Float)
	{
		this.line = Line;
		super(X + Line * (KeyButton.size + 4), Y - 4 - KeyboardDisplay.saveBitmap.bitmapData.height);
		this.startTime = Time;
		loadGraphic(KeyboardDisplay.saveBitmap.bitmapData);
		_frame.frame.height = 1;
		color = OptionsHelpers.colorArray(ClientPrefs.data.keyboardBGColor);
		alpha = ClientPrefs.data.keyboardAlpha;
	}

	var saveTime:Float;

	override function update(elapsed:Float)
	{
		if (endTime == -999999)
		{
			_frame.frame.y = (1 - ((Conductor.songPosition - startTime) / durationTime)) * KeyboardDisplay.saveBitmap.bitmapData.height;
			_frame.frame.height = ((Conductor.songPosition - startTime) / durationTime) * KeyboardDisplay.saveBitmap.bitmapData.height;
			offset.y = -(1 - ((Conductor.songPosition - startTime) / durationTime)) * KeyboardDisplay.saveBitmap.bitmapData.height;
			if (_frame.frame.y < 0)
				_frame.frame.y = 0;
			if (Conductor.songPosition - startTime > durationTime)
				offset.y = 0;
			saveTime = Conductor.songPosition;
		}
		else
		{
			if (endTime - startTime < durationTime)
				_frame.frame.y = (1 - ((Conductor.songPosition - startTime) / durationTime)) * KeyboardDisplay.saveBitmap.bitmapData.height;
			else
				_frame.frame.y = (1 - ((Conductor.songPosition - (endTime - durationTime)) / durationTime)) * KeyboardDisplay.saveBitmap.bitmapData.height;
			offset.y -= -((Conductor.songPosition - saveTime) / durationTime) * KeyboardDisplay.saveBitmap.bitmapData.height;
			saveTime = Conductor.songPosition;
		}
		if (_frame.frame.height > KeyboardDisplay.saveBitmap.bitmapData.height)
			_frame.frame.height = KeyboardDisplay.saveBitmap.bitmapData.height;
		if (_frame.frame.height <= 0)
			_frame.frame.height = 1; // fix bug

		if (endTime != -999999 && Conductor.songPosition - endTime > durationTime)
			KeyboardDisplay.instance.removeObj(this);
	}
}

class DisBitmap extends Bitmap
{
	var Width:Int = KeyButton.size;
	var Height:Int = Std.int(KeyButton.size * 3);

	var colorArray:Array<FlxColor> = [];

	public function new()
	{
		super();

		var BitmapData:BitmapData = new BitmapData(Width, Height, true, 0);
		var shape:Shape = new Shape();

		for (i in 0...Width + 1)
		{
			shape.graphics.beginFill(FlxColor.WHITE, i / Width);
			shape.graphics.drawRect(0, i, Width, 1);
			shape.graphics.endFill();
		}
		shape.graphics.beginFill(FlxColor.WHITE);
		shape.graphics.drawRect(0, Width, Width, Height - Width);
		shape.graphics.endFill();
		BitmapData.draw(shape);

		this.bitmapData = BitmapData;
	}
}

