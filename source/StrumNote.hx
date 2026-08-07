package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;

using StringTools;

class StrumNote extends FlxSprite
{
	private var colorSwap:ColorSwap;
	public var resetAnim:Float = 0;
	private var noteData:Int = 0;
	public var direction:Float = 90;//plan on doing scroll directions soon -bb
	public var downScroll:Bool = false;//plan on doing scroll directions soon -bb
	public var sustainReduce:Bool = true;

	/** 多k: 该 strum 所在轨道 (0 ~ ammo-1)。 */
	public var lane(default, null):Int = 0;

	public var animationArray:Array<String> = ['static', 'pressed', 'confirm'];
	public var static_anim(default, set):String = "static";
	public var pressed_anim(default, set):String = "pressed";
	public var confirm_anim(default, set):String = "confirm";

	private function set_static_anim(value:String):String {
		if (!PlayState.isPixelStage) {
			animation.addByPrefix('static', value);
			animationArray[0] = value;
			if (animation.curAnim != null && animation.curAnim.name == 'static') playAnim('static');
		}
		return value;
	}

	private function set_pressed_anim(value:String):String {
		if (!PlayState.isPixelStage) {
			animation.addByPrefix('pressed', value);
			animationArray[1] = value;
			if (animation.curAnim != null && animation.curAnim.name == 'pressed') playAnim('pressed');
		}
		return value;
	}

	private function set_confirm_anim(value:String):String {
		if (!PlayState.isPixelStage) {
			animation.addByPrefix('confirm', value);
			animationArray[2] = value;
			if (animation.curAnim != null && animation.curAnim.name == 'confirm') playAnim('confirm');
		}
		return value;
	}

	private var player:Int;

	public var texture(default, set):String = null;
	private function set_texture(value:String):String {
		if(texture != value) {
			texture = value;
			reloadNote();
		}
		return value;
	}

	/** SPACE strum 动作映射到 UP (用户要求: Space key 换用 up key)。 */
	inline static function strumToBase(strumAnim:String):String
	{
		return (strumAnim == 'SPACE') ? 'UP' : strumAnim;
	}

	public function new(x:Float, y:Float, leData:Int, player:Int) {
		noteData = leData;
		this.player = player;
		lane = leData;
		super(x, y);

		// 0.6.3 图集的 strum 动画按方向命名 (arrowLEFT / left press / left confirm),
		// SPACE 轨道复用 up 方向
		animationArray[0] = strumToBase(EKData.getStrumAnim(PlayState.mania, leData));
		animationArray[1] = animationArray[0].toLowerCase();
		animationArray[2] = animationArray[1];

		var skin:String = 'NOTE_assets';
		if(PlayState.SONG != null && PlayState.SONG.arrowSkin != null && PlayState.SONG.arrowSkin.length > 1)
			skin = PlayState.SONG.arrowSkin;
		// 多k: 统一使用原版 ColorSwap (保证着色器生效); 自定义皮肤不自动染色
		colorSwap = new ColorSwap();
		shader = colorSwap.shader;
		texture = skin;
		scrollFactor.set();
	}

	public function reloadNote()
	{
		var lastAnim:String = null;
		if(animation.curAnim != null) lastAnim = animation.curAnim.name;

		if(PlayState.isPixelStage)
		{
			loadGraphic(Paths.image('pixelUI/' + texture));
			width = width / 4;
			height = height / 5;
			loadGraphic(Paths.image('pixelUI/' + texture), true, Math.floor(width), Math.floor(height));
			antialiasing = false;
			var b:Int = EKData.getBaseTexture(PlayState.mania, lane);
			setGraphicSize(Std.int(width * PlayState.daPixelZoom * (EKData.pixelScales[PlayState.mania] / EKData.pixelScales[3])));
			updateHitbox();
			animation.add('static', [b]);
			animation.add('pressed', [b + 4, b + 8], 12, false);
			animation.add('confirm', [b + 12, b + 16], 24, false);
		}
		else
		{
			frames = Paths.getSparrowAtlas(texture);
			if (frames != null)
			{
				animation.addByPrefix('static', 'arrow' + animationArray[0]);
				animation.addByPrefix('pressed', animationArray[1] + ' press', 24, false);
				animation.addByPrefix('confirm', animationArray[1] + ' confirm', 24, false);

				antialiasing = ClientPrefs.data.globalAntialiasing;
				setGraphicSize(Std.int(width * 0.7 * Note.noteScale(PlayState.mania)));
			}
		}
		updateHitbox();

		if(lastAnim != null) playAnim(lastAnim, true);
	}

	public function postAddedToGroup() {
		playAnim('static');
		/**
		 * 多k 定位 (移植自 EK 0.6.3):
		 * 1K~3K 按宽度排, 4K 按 swagWidth, 5K+ 按 (width - lessX), 再加 xtra/50/玩家半屏/减 restPosition
		 **/
		switch (PlayState.mania)
		{
			case 0 | 1 | 2: x += width * noteData;
			case 3: x += (Note.swagWidth * noteData);
			default: x += ((width - EKData.lessX[PlayState.mania]) * noteData);
		}
		x += EKData.offsetX[PlayState.mania];
		x += 50;
		x += ((FlxG.width / 2) * player);
		ID = noteData;
		x -= EKData.restPosition[PlayState.mania];
	}

	override function update(elapsed:Float) {
		if(resetAnim > 0) {
			resetAnim -= elapsed;
			if(resetAnim <= 0) {
				playAnim('static');
				resetAnim = 0;
			}
		}
		if(animation.curAnim != null && animation.curAnim.name == 'confirm' && !PlayState.isPixelStage) {
			centerOrigin();
		}
		super.update(elapsed);
	}

	public function playAnim(anim:String, ?force:Bool = false) {
		animation.play(anim, force);
		centerOffsets();
		centerOrigin();
		if(animation.curAnim == null || animation.curAnim.name == 'static') {
			colorSwap.hue = 0;
			colorSwap.saturation = 0;
			colorSwap.brightness = 0;
		} else {
			// 按轨道颜色 (基底纹理色 + 目标色差值 + 用户 arrowHSV 偏移)
			applyLaneColor();

			if(animation.curAnim.name == 'confirm' && !PlayState.isPixelStage) {
				centerOrigin();
			}
		}
	}

	/** 按轨道颜色设置 ColorSwap (与 Note 一致)。 */
	public function applyLaneColor():Void
	{
		if (colorSwap == null) return;
		var delta:Array<Float> = EKData.getLaneColorSwap(PlayState.mania, lane);
		var colorIdx:Int = EKData.letterColorIndex.get(EKData.getLetter(PlayState.mania, lane));
		if (colorIdx < 0) colorIdx = lane;
		var hsv:Array<Int> = (colorIdx < ClientPrefs.data.arrowHSV.length) ? ClientPrefs.data.arrowHSV[colorIdx] : [0, 0, 0];
		var hue:Float = delta[0] + hsv[0] / 360;
		while (hue < 0) hue += 1;
		while (hue >= 1) hue -= 1;
		colorSwap.hue = hue;
		colorSwap.saturation = delta[1] + hsv[1] / 100;
		colorSwap.brightness = delta[2] + hsv[2] / 100;
	}
}
