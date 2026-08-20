package android;

 
 
 
import flixel.util.FlxDestroyUtil;
import flixel.util.FlxSignal;
import flixel.util.FlxColor;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxTileFrames;
import flixel.math.FlxPoint;
import openfl.display.BitmapData;
import openfl.utils.Assets;
import android.flixel.FlxButton;
import android.flixel.FlxHitbox;
import android.flixel.FlxVirtualPad;

/**
 * @author Mihai Alexandru (M.A. Jigsaw)
 */
class AndroidControls extends FlxSpriteGroup
{
	public static var customVirtualPad(get, set):FlxVirtualPad;
	public static var mode(get, set):String;
	public static var enabled(get, never):Bool;

	public var virtualPad:FlxVirtualPad;
	public var hitbox:FlxHitbox;
	public var pauseButton:FlxButton;

	/** 暂停键防误触：两次点击的最大间隔（秒）。 */
	static var DOUBLE_TAP_WINDOW:Float = 0.3;
	var lastPauseTapTime:Float = -9999;

	public function new()
	{
		super();

		// 多k: 安卓端当前谱面非 4K 时只允许 FlxHitbox
		var isMultiK:Bool = (PlayState.SONG != null && PlayState.SONG.mania != null && PlayState.SONG.mania != Note.defaultMania);

		switch (AndroidControls.mode)
		{
			case 'Pad-Right':
				if (isMultiK) createMultiKHitbox();
				else { virtualPad = new FlxVirtualPad(RIGHT_FULL, NONE, ClientPrefs.data.mobileCEx); add(virtualPad); }
			case 'Pad-Left':
				if (isMultiK) createMultiKHitbox();
				else { virtualPad = new FlxVirtualPad(LEFT_FULL, NONE, ClientPrefs.data.mobileCEx); add(virtualPad); }
			case 'Pad-Custom':
				if (isMultiK) createMultiKHitbox();
				else { virtualPad = AndroidControls.customVirtualPad; add(virtualPad); }
			case 'Hitbox':
				createMultiKHitbox();
			case 'Keyboard': // do nothing
		}
	}

	/** 在游戏内添加一个顶部右上角的虚拟暂停键（P）。 */
	public function addPauseButton():Void
	{
		if (pauseButton != null) return;
		pauseButton = createPauseButton();
		pauseButton.onDown.callback = function()
		{
			var now:Float = haxe.Timer.stamp();
			if (now - lastPauseTapTime <= DOUBLE_TAP_WINDOW)
			{
				// 第二次快速点击：放行，让 controls.PAUSE 正常触发暂停。
				lastPauseTapTime = -9999;
			}
			else
			{
				// 第一次点击：取消本次按下，避免误触直接暂停。
				lastPauseTapTime = now;
				@:privateAccess pauseButton.input.release();
			}
		};
		add(pauseButton);
	}

	function createPauseButton():FlxButton
	{
		var graphic:FlxGraphic;

		final path:String = 'shared:assets/shared/images/virtualpad/p.png';
		#if MODS_ALLOWED
		final modsPath:String = Paths.modsImages('virtualpad/p');
		if (sys.FileSystem.exists(modsPath))
			graphic = FlxGraphic.fromBitmapData(BitmapData.fromFile(modsPath));
		else #end if (Assets.exists(path))
			graphic = FlxGraphic.fromBitmapData(Assets.getBitmapData(path));
		else
			graphic = FlxGraphic.fromBitmapData(Assets.getBitmapData('shared:assets/shared/images/virtualpad/default.png'));

		var button:FlxButton = new FlxButton(FlxG.width - 100, 8);
		button.frames = FlxTileFrames.fromGraphic(graphic, FlxPoint.get(Std.int(graphic.width / 2), graphic.height));
		button.scale.set(0.65, 0.65);
		button.updateHitbox();
		button.solid = false;
		button.immovable = true;
		button.moves = false;
		button.scrollFactor.set();
		button.color = 0xFFCB00;
		button.antialiasing = ClientPrefs.data.globalAntialiasing;
		button.alpha = ClientPrefs.data.mobileCAlpha * 0.6;
		#if FLX_DEBUG
		button.ignoreDrawDebug = true;
		#end
		return button;
	}

	/** 多k: 按当前 k 值生成 FlxHitbox, 色块对应各轨道 Note 颜色。 */
	function createMultiKHitbox():Void
	{
		var ammo:Int = Note.ammo[PlayState.mania];
		var colors:Array<FlxColor> = [];
		for (lane in 0...ammo)
		{
			var c:Array<Int> = EKData.getLaneColor(PlayState.mania, lane);
			colors.push(FlxColor.fromRGB(c[0], c[1], c[2]));
		}
		hitbox = new FlxHitbox(ammo, Std.int(FlxG.width / ammo), FlxG.height, colors);
		add(hitbox);
	}

	override public function destroy():Void
	{
		super.destroy();

		if (virtualPad != null)
			virtualPad = FlxDestroyUtil.destroy(virtualPad);

		if (hitbox != null)
			hitbox = FlxDestroyUtil.destroy(hitbox);
	}

	private static function get_mode():String
	{
		if (FlxG.save.data.mobileCMode == null)
		{
			FlxG.save.data.mobileCMode = 'Pad-Right';
			FlxG.save.flush();
		}
	
		return FlxG.save.data.mobileCMode;
	}

	private static function set_mode(mode:String = 'Hitbox'):String
	{
		FlxG.save.data.mobileCMode = mode;
		FlxG.save.flush();

		return mode;
	}

	private static function get_customVirtualPad():FlxVirtualPad
	{
		var virtualPad:FlxVirtualPad = new FlxVirtualPad(RIGHT_FULL, NONE, ClientPrefs.data.mobileCEx);
		if (FlxG.save.data.buttons == null)
			return virtualPad;

		var tempCount:Int = 0;
		for (buttons in virtualPad)
		{
			buttons.x = FlxG.save.data.buttons[tempCount].x;
			buttons.y = FlxG.save.data.buttons[tempCount].y;
			tempCount++;
		}

		return virtualPad;
	}	


	private static function set_customVirtualPad(virtualPad:FlxVirtualPad):FlxVirtualPad
	{
		if (FlxG.save.data.buttons == null)
		{
			FlxG.save.data.buttons = new Array();
			for (buttons in virtualPad)
			{
				FlxG.save.data.buttons.push(FlxPoint.get(buttons.x, buttons.y));
				FlxG.save.flush();
			}
		}
		else
		{
			var tempCount:Int = 0;
			for (buttons in virtualPad)
			{
				FlxG.save.data.buttons[tempCount] = FlxPoint.get(buttons.x, buttons.y);
				FlxG.save.flush();
				tempCount++;
			}
		}

		return virtualPad;
	}

	private static function get_enabled():Bool
		return ClientPrefs.data.mobileCAlpha >= 0.1;
}
