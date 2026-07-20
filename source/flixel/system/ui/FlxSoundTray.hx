package flixel.system.ui;

#if FLX_SOUND_SYSTEM
import flash.display.Bitmap;
import flash.display.BitmapData;
import flash.display.Sprite;
import flash.Lib;
import flash.text.TextField;
import flash.text.TextFormat;
import flash.text.TextFormatAlign;
import flixel.FlxG;
import flixel.system.FlxAssets;
import flixel.util.FlxColor;
#if flash
import flash.text.AntiAliasType;
import flash.text.GridFitType;
#end

/**
 * The flixel sound tray, the little volume meter that pops down sometimes.
 */
class FlxSoundTray extends Sprite
{
	/**
	 * Because reading any data from DisplayObject is insanely expensive in hxcpp, keep track of whether we need to update it or not.
	 */
	public var active:Bool;

	/**
	 * Helps us auto-hide the sound tray after a volume change.
	 */
	var _timer:Float;

	/**
	 * Helps display the volume bars on the sound tray.
	 */
	var _bars:Array<Bitmap>;

	/**
	 * The volume label text field, stored so we can update its text
	 * when the language changes (language is not loaded at construction time).
	 */
	var _volumeText:TextField;

	/**
	 * How wide the sound tray background is.
	 */
	var _width:Int = 80;

	var _defaultScale:Float = 2.0;

	/**
	 * Sets up the "sound tray", the little volume meter that pops down sometimes.
	 */
	@:keep
	public function new()
	{
		super();

		visible = false;
		scaleX = _defaultScale;
		scaleY = _defaultScale;
		var tmp:Bitmap = new Bitmap(new BitmapData(_width, 30, true, 0x7F000000));
		screenCenter();
		addChild(tmp);

		_volumeText = new TextField();
		_volumeText.width = tmp.width;
		_volumeText.height = tmp.height;
		_volumeText.multiline = true;
		_volumeText.wordWrap = true;
		_volumeText.selectable = false;

		#if flash
		_volumeText.embedFonts = true;
		_volumeText.antiAliasType = AntiAliasType.NORMAL;
		_volumeText.gridFitType = GridFitType.PIXEL;
		#else
		#end
		var dtf:TextFormat = new TextFormat('assets/fonts/editors.ttf', 10, 0xffffff);
		dtf.align = TextFormatAlign.CENTER;
		_volumeText.defaultTextFormat = dtf;
		addChild(_volumeText);
		_volumeText.text = Language.get('FlxSoundTray.volume.text', 'VOLUME');
		_volumeText.y = 16;

		var bx:Int = 10;
		var by:Int = 14;
		_bars = new Array();

		for (i in 0...10)
		{
			tmp = new Bitmap(new BitmapData(4, i + 1, false, FlxColor.WHITE));
			tmp.x = bx;
			tmp.y = by;
			addChild(tmp);
			_bars.push(tmp);
			bx += 6;
			by--;
		}

		y = -height;
		visible = false;
	}

	/**
	 * This function just updates the soundtray object.
	 */
	public function update(MS:Float):Void
	{
		// Animate stupid sound tray thing
		if (_timer > 0)
		{
			_timer -= MS / 1000;
		}
		else if (y > -height)
		{
			y -= (MS / 1000) * FlxG.height * 2;

			if (y <= -height)
			{
				visible = false;
				active = false;

				// Save sound preferences
				FlxG.save.data.mute = FlxG.sound.muted;
				FlxG.save.data.volume = FlxG.sound.volume;
				FlxG.save.flush();
			}
		}
	}

	/**
	 * Makes the little volume tray slide out.
	 *
	 * @param	Silent	Whether or not it should beep.
	 */
	public function show(Silent:Bool = false):Void
	{
		if (!Silent)
		{
			var sound = FlxAssets.getSound("flixel/sounds/beep");
			if (sound != null)
				FlxG.sound.load(sound).play();
		}

		// Update label text on every show so it reflects the currently loaded language.
		if (_volumeText != null)
			_volumeText.text = Language.get('FlxSoundTray.volume.text', 'VOLUME');

		_timer = 1;
		y = 0;
		visible = true;
		active = true;
		var globalVolume:Int = Math.round(FlxG.sound.volume * 10);

		if (FlxG.sound.muted)
		{
			globalVolume = 0;
		}

		for (i in 0..._bars.length)
		{
			if (i < globalVolume)
			{
				_bars[i].alpha = 1;
			}
			else
			{
				_bars[i].alpha = 0.5;
			}
		}
	}

	public function screenCenter():Void
	{
		scaleX = _defaultScale;
		scaleY = _defaultScale;

		x = (0.5 * (Lib.current.stage.stageWidth - _width * _defaultScale) - FlxG.game.x);
	}
}
#end
