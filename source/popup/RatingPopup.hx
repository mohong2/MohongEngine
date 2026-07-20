package popup;

import flixel.FlxSprite;
import flixel.FlxG;
import flixel.FlxCamera;
import flixel.group.FlxSpriteGroup;
import flixel.tweens.FlxTween;

/**
 * Object pool for rating popups.
 * Eliminates GC churn from frequent sprite creation in popUpScore().
 *
 * Usage:
 *   var rp = new RatingPopup();
 *   rp.targetCameras = [camHUD];
 *   add(rp.container);
 *   rp.show("sick", 123, playbackRate, ...);
 *
 * Soft-coded: tweak static vars at runtime.
 */
class RatingPopup
{
	// ---- tunable animation params ----
	public static var RATING_SCALE:Float          = 0.7;
	public static var COMBO_SCALE:Float           = 0.7;
	public static var NUM_SCALE:Float             = 0.5;
	public static var PIXEL_RATING_SCALE:Float    = 0.85;
	public static var PIXEL_COMBO_SCALE:Float     = 0.85;
	public static var PIXEL_NUM_SCALE:Float       = 1.0;

	public static var ACCEL_Y_RATING:Float        = 550;
	public static var VEL_Y_RATING_MIN:Float      = 140;
	public static var VEL_Y_RATING_MAX:Float      = 175;
	public static var VEL_X_RATING_MIN:Float      = 0;
	public static var VEL_X_RATING_MAX:Float      = 10;

	public static var ACCEL_Y_COMBO_MIN:Float     = 200;
	public static var ACCEL_Y_COMBO_MAX:Float     = 300;
	public static var VEL_Y_COMBO_MIN:Float       = 140;
	public static var VEL_Y_COMBO_MAX:Float       = 160;
	public static var VEL_X_COMBO_MIN:Float       = 1;
	public static var VEL_X_COMBO_MAX:Float       = 10;

	public static var ACCEL_Y_NUM_MIN:Float       = 200;
	public static var ACCEL_Y_NUM_MAX:Float       = 300;
	public static var VEL_Y_NUM_MIN:Float         = 140;
	public static var VEL_Y_NUM_MAX:Float         = 160;
	public static var VEL_X_NUM_MIN:Float         = -5;
	public static var VEL_X_NUM_MAX:Float         = 5;

	public static var FADE_DURATION:Float         = 0.2;
	public static var FADE_DELAY_RATING:Float     = 0.001;
	public static var FADE_DELAY_COMBO:Float      = 0.002;
	public static var FADE_DELAY_NUM:Float        = 0.002;

	public static var RATING_X_OFFSET:Float       = -40;
	public static var RATING_Y_OFFSET:Float       = -60;
	public static var COMBO_Y_OFFSET:Float        = 60;
	public static var NUM_Y_OFFSET:Float          = 80;
	public static var NUM_SPACING:Float           = 43;
	public static var NUM_X_START:Float           = -90;
	public static var COMBO_X_EXTRA:Float         = 50;

	public static var POOL_SIZE:Int               = 8;
	public static var NUM_POOL_SIZE:Int           = 30;

	// ---- instance state ----
	public var container:FlxSpriteGroup;

	var _ratingPool:Array<FlxSprite> = [];
	var _comboPool:Array<FlxSprite> = [];
	var _numPool:Array<FlxSprite> = [];

	/** Single combined tween map to reduce 3× lookup in clearAll. */
	var _tweens:Map<FlxSprite, FlxTween> = new Map();

	public var targetCameras:Array<FlxCamera> = null;
	public var antialiasing:Bool = true;
	public var isPixel:Bool = false;
	public var daPixelZoom:Float = 6;

	public function new()
	{
		container = new FlxSpriteGroup();
		for (i in 0...POOL_SIZE) {
			_ratingPool.push(_deadSprite());
			_comboPool.push(_deadSprite());
		}
		for (i in 0...NUM_POOL_SIZE) _numPool.push(_deadSprite());
	}

	static inline function _deadSprite():FlxSprite {
		var s = new FlxSprite();
		s.kill();
		return s;
	}

	/** Acquire a sprite from pool — cursor-based O(1) average. */
	/** Acquire a dead sprite from pool (linear scan — pool is small). */
	function _acquire(pool:Array<FlxSprite>):FlxSprite {
		for (s in pool) {
			if (!s.alive) { s.revive(); return s; }
		}
		var s = new FlxSprite();
		pool.push(s);
		return s;
	}

	inline function _cancelTween(spr:FlxSprite) {
		var t = _tweens.get(spr);
		if (t != null) { t.cancel(); _tweens.remove(spr); }
	}

	/** Remove all sprites from container, return to pool. */
	public function clearAll():Void
	{
		var arr = container.members;
		if (arr.length == 0) return;
		// iterate backward, removing via pop for O(1) per removal
		var i = arr.length - 1;
		while (i >= 0) {
			var spr = arr[i];
			if (spr != null && spr.alive) {
				_cancelTween(spr);
				spr.kill();
			}
			arr.pop();
			i--;
		}
	}

	inline function _show(spr:FlxSprite):Void {
		container.add(spr);
	}

	public function show(ratingKey:String, combo:Int, rate:Float, baseX:Float,
		hideHud:Bool, showRating:Bool, showCombo:Bool, showComboNum:Bool,
		comboOffset:Array<Float>, crochet:Float, comboStacking:Bool):Void
	{
		if (!comboStacking) clearAll();

		var px:String  = isPixel ? 'pixelUI/' : '';
		var sx:String  = isPixel ? '-pixel' : '';
		var pr:Float   = rate;
		var pz:Float   = daPixelZoom;
		var cam:Array<FlxCamera> = targetCameras;
		var aa:Bool    = antialiasing;

		var offRX:Float = comboOffset.length > 0 ? comboOffset[0] : 0;
		var offRY:Float = comboOffset.length > 1 ? comboOffset[1] : 0;
		var offNX:Float = comboOffset.length > 2 ? comboOffset[2] : 0;
		var offNY:Float = comboOffset.length > 3 ? comboOffset[3] : 0;

		var rFunc = function(spr:FlxSprite) {
			_cancelTween(spr);
			var t = FlxTween.tween(spr, {alpha: 0}, FADE_DURATION / pr, {
				startDelay: crochet * FADE_DELAY_RATING / pr,
				onComplete: function(_) { _tweens.remove(spr); spr.kill(); }
			});
			_tweens.set(spr, t);
		};

		// ---- rating sprite (members[0]) ----
		if (showRating)
		{
			var r = _acquire(_ratingPool);
			_configRating(r, Paths.image(px + ratingKey + sx),
				baseX + RATING_X_OFFSET + offRX,
				RATING_Y_OFFSET - offRY,
				!hideHud, cam, aa,
				ACCEL_Y_RATING * pr * pr,
				-FlxG.random.float(VEL_Y_RATING_MIN, VEL_Y_RATING_MAX) * pr,
				-FlxG.random.float(VEL_X_RATING_MIN, VEL_X_RATING_MAX) * pr,
				isPixel ? (pz * PIXEL_RATING_SCALE) : RATING_SCALE);
			_show(r);
			rFunc(r);
		}

		// ---- number sprites (members[1+]) ----
		var maxX:Float = 0;
		if (showComboNum)
		{
			var digits:Array<Int> = _splitDigits(combo);
			for (loop in 0...digits.length)
			{
				var ns = _acquire(_numPool);
				_cancelTween(ns);
				_configSprite(ns, Paths.image(px + 'num' + digits[loop] + sx),
					baseX + (NUM_SPACING * loop) + NUM_X_START + offNX,
					NUM_Y_OFFSET - offNY,
					!hideHud, cam, aa,
					FlxG.random.float(ACCEL_Y_NUM_MIN, ACCEL_Y_NUM_MAX) * pr * pr,
					-FlxG.random.float(VEL_Y_NUM_MIN, VEL_Y_NUM_MAX) * pr,
					-FlxG.random.float(VEL_X_NUM_MIN, VEL_X_NUM_MAX) * pr,
					isPixel ? (pz * PIXEL_NUM_SCALE) : NUM_SCALE);
				_show(ns);

				var t = FlxTween.tween(ns, {alpha: 0}, FADE_DURATION / pr, {
					startDelay: crochet * FADE_DELAY_NUM / pr,
					onComplete: function(_) { _tweens.remove(ns); ns.kill(); }
				});
				_tweens.set(ns, t);

				if (ns.x > maxX) maxX = ns.x;
			}
		}

		// ---- combo word sprite (members[last]) ----
		if (showCombo)
		{
			var c = _acquire(_comboPool);
			_cancelTween(c);
			_configSprite(c, Paths.image(px + 'combo' + sx),
				baseX + offRX,
				COMBO_Y_OFFSET - offRY,
				!hideHud, cam, aa,
				FlxG.random.float(ACCEL_Y_COMBO_MIN, ACCEL_Y_COMBO_MAX) * pr * pr,
				-FlxG.random.float(VEL_Y_COMBO_MIN, VEL_Y_COMBO_MAX) * pr,
				-FlxG.random.float(VEL_X_COMBO_MIN, VEL_X_COMBO_MAX) * pr,
				isPixel ? (pz * PIXEL_COMBO_SCALE) : COMBO_SCALE);
			c.x = maxX + COMBO_X_EXTRA;
			_show(c);

			var t = FlxTween.tween(c, {alpha: 0}, FADE_DURATION / pr, {
				startDelay: crochet * FADE_DELAY_COMBO / pr,
				onComplete: function(_) { _tweens.remove(c); c.kill(); }
			});
			_tweens.set(c, t);
		}
	}

	inline function _configRating(spr:FlxSprite, graphic:Dynamic,
		x:Float, yOff:Float, visible:Bool,
		cameras:Array<FlxCamera>, aa:Bool,
		accelY:Float, velY:Float, velX:Float,
		scale:Float):Void
	{
		spr.alpha = 1; spr.scale.set(1, 1);
		spr.acceleration.set(0, 0); spr.velocity.set(0, 0); spr.angle = 0;
		spr.loadGraphic(graphic);
		spr.screenCenter();
		spr.x = x; spr.y += yOff;
		spr.acceleration.y = accelY; spr.velocity.y = velY; spr.velocity.x = velX;
		spr.visible = visible; spr.antialiasing = aa;
		if (cameras != null) spr.cameras = cameras;
		if (scale > 0) spr.setGraphicSize(Std.int(spr.width * scale));
		spr.updateHitbox();
	}

	inline function _configSprite(spr:FlxSprite, graphic:Dynamic,
		x:Float, yOff:Float, visible:Bool,
		cameras:Array<FlxCamera>, aa:Bool,
		accelY:Float, velY:Float, velX:Float,
		scale:Float):Void
	{
		spr.alpha = 1; spr.scale.set(1, 1);
		spr.acceleration.set(0, 0); spr.velocity.set(0, 0); spr.angle = 0;
		spr.loadGraphic(graphic);
		spr.screenCenter();
		spr.x = x; spr.y += yOff;
		spr.acceleration.y = accelY; spr.velocity.y = velY; spr.velocity.x = velX;
		spr.visible = visible; spr.antialiasing = aa;
		if (cameras != null) spr.cameras = cameras;
		if (scale > 0) spr.setGraphicSize(Std.int(spr.width * scale));
		spr.updateHitbox();
	}

	static function _splitDigits(n:Int):Array<Int>
	{
		if (n == 0) return [0];
		var d:Array<Int> = [];
		while (n > 0) { d.push(n % 10); n = Math.floor(n / 10); }
		d.reverse();
		if (d.length == 2) d.insert(0, 0);
		return d;
	}

	public function destroyAll():Void
	{
		for (arr in [_ratingPool, _comboPool, _numPool])
			for (s in arr) s.destroy();
		_ratingPool = null; _comboPool = null; _numPool = null;
	}
}
