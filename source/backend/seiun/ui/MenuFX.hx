package backend.seiun.ui;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.FlxState;
import flixel.math.FlxPoint;
import backend.MusicBeatState;
import flixel.graphics.FlxGraphic;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxColor;
import flixel.util.FlxSpriteUtil;
import flixel.group.FlxGroup.FlxTypedGroup;
import openfl.display.BitmapData;

/**
 * Seiun Engine menu visual effects toolkit.
 *
 * All menu states share this static clock so that floating, bobbing and
 * pulsing animations stay perfectly continuous when the player moves from
 * one menu to another (main menu -> freeplay -> story menu -> ...).
 */
class MenuFX
{
	/** Continuous clock shared by every menu state (seconds). */
	public static var time:Float = 0;

	/** Continuous beat counter shared by every menu state. */
	public static var beat:Int = 0;

	/** BPM of the menu music used to drive beat-synced animations. */
	public static var bpm:Float = 102;

	/** True while the currently playing music is the menu theme. */
	public static var menuMusicActive:Bool = false;

	/** Accent color carried across states so backgrounds blend smoothly. */
	public static var accentColor:Int = 0xFFFD719B;

	/** Base zoom used by the beat-synced camera pulse. */
	public static var baseZoom:Float = 1;

	/** Whether the Seiun menu effects are enabled (settings toggle). */
	public static function enabled():Bool
	{
		return ClientPrefs.data == null || ClientPrefs.data.seiuMenuFx != false;
	}

	/**
	 * Smooth menu-to-menu switch: uses a short CustomFadeTransition so the
	 * old menu's items fly out, the screen briefly fades, and the next menu's
	 * items visibly fly in — no jarring cut.
	 */
	public static function menuSwitch(next:FlxState):Void
	{
		MusicBeatState.quickMenuTransition = true;
		MusicBeatState.switchState(next);
	}

	/**
	 * Start the menu music unless the same track is already playing.
	 * This keeps the song playing seamlessly across menu state switches.
	 */
	public static function ensureMenuMusic(volume:Float = 1):Void
	{
		if (menuMusicActive && FlxG.sound.music != null && FlxG.sound.music.playing)
		{
			FlxG.sound.music.volume = volume;
			return;
		}
		playMenuMusic(volume);
	}

	/** Restart the menu music from scratch (used after switching mods). */
	public static function playMenuMusic(volume:Float = 1):Void
	{
		FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
		FlxTween.tween(FlxG.sound.music, {volume: volume}, 0.5, {ease: FlxEase.sineOut});
		menuMusicActive = true;
	}

	/** Tell the toolkit the menu music is no longer playing (e.g. gameplay). */
	public static function markMenuMusicStopped():Void
	{
		menuMusicActive = false;
	}

	/** Small bounce used by beat pulses: decays smoothly over time. */
	public static function kick(t:Float, strength:Float = 1):Float
	{
		return Math.max(0, 1 - t) * strength;
	}

	/**
	 * Beat-synced camera zoom punch. The camera briefly zooms in and springs
	 * back to `baseZoom`.
	 */
	public static function punchZoom(amount:Float = 0.02, ?camera:FlxCamera):Void
	{
		if (!enabled()) return;
		var cam:FlxCamera = camera != null ? camera : FlxG.camera;
		FlxTween.cancelTweensOf(cam, ['zoom']);
		var target:Float = Math.max(0.05, baseZoom + amount);
		FlxTween.tween(cam, {zoom: target}, 0.06, {
			ease: FlxEase.quadOut,
			onComplete: function(twn:FlxTween)
			{
				FlxTween.tween(cam, {zoom: baseZoom}, 0.22, {ease: FlxEase.sineOut});
			}
		});
	}

	/**
	 * Quick scale punch on a sprite (scale up then spring back to its base).
	 * Does not fight other tweens: it stores and restores the pre-punch scale.
	 */
	public static function pulse(spr:FlxSprite, amount:Float = 0.14, duration:Float = 0.14):Void
	{
		if (!enabled()) return;
		if (spr == null || !spr.exists || !spr.visible) return;
		FlxTween.cancelTweensOf(spr.scale);
		var ox:Float = spr.scale.x;
		var oy:Float = spr.scale.y;
		spr.scale.set(ox * (1 + amount), oy * (1 + amount));
		FlxTween.tween(spr.scale, {x: ox, y: oy}, duration, {ease: FlxEase.quadOut});
	}

	/** Create a soft radial glow sprite with the given color and alpha. */
	public static function makeGlow(size:Float, color:Int, alpha:Float = 1):FlxSprite
	{
		var spr:FlxSprite = new FlxSprite();
		spr.loadGraphic(sharedGlowTexture(), false, 256, 256);
		spr.setGraphicSize(Std.int(Math.max(size, 8)), Std.int(Math.max(size, 8)));
		spr.updateHitbox();
		spr.antialiasing = true;
		spr.color = color;
		spr.alpha = alpha;
		return spr;
	}

	/** Shared soft radial gradient texture (white, center alpha 255). */
	static var _glowTexture:BitmapData = null;
	static function sharedGlowTexture():BitmapData
	{
		if (_glowTexture != null)
			return _glowTexture;

		var texSize:Int = 256;
		var bmp:BitmapData = new BitmapData(texSize, texSize, true, 0x00000000);
		var half:Float = texSize * 0.5;
		var invMax:Float = 1 / half;
		for (y in 0...texSize)
		{
			for (x in 0...texSize)
			{
				var dx:Float = (x + 0.5) - half;
				var dy:Float = (y + 0.5) - half;
				var d:Float = Math.sqrt(dx * dx + dy * dy) * invMax;
				if (d < 1)
				{
					var t:Float = 1 - d;
					var a:Int = Std.int(255 * t * t);
					if (a > 0)
						bmp.setPixel32(x, y, (a << 24) | 0xFFFFFF);
				}
			}
		}
		_glowTexture = bmp;
		return bmp;
	}

	/** Create a soft rectangular "light beam" glow used behind title text. */
	public static function makeBeamGlow(width:Float, height:Float, color:Int, alpha:Float = 1):FlxSprite
	{
		var w:Int = Std.int(Math.max(width, 8));
		var h:Int = Std.int(Math.max(height, 8));
		var spr:FlxSprite = new FlxSprite().makeGraphic(w, h, 0x00000000, true);
		var col:FlxColor = color;
		var steps:Int = 24;
		for (i in 0...steps)
		{
			var t:Float = 1 - (i / steps); // 1 center -> 0 edge
			var insetX:Float = (w * 0.5) * t * t;
			var insetY:Float = (h * 0.5) * t * t;
			var a:Int = Std.int(255 * alpha * (1 - t) * (1 - t));
			if (a < 1) a = 1;
			var rect:openfl.geom.Rectangle = new openfl.geom.Rectangle(insetX, insetY, w - insetX * 2, h - insetY * 2);
			spr.pixels.fillRect(rect, FlxColor.fromRGB(col.red, col.green, col.blue, a));
		}
		spr.updateHitbox();
		spr.antialiasing = ClientPrefs.data.globalAntialiasing;
		return spr;
	}

	/**
	 * Spawn a burst of small particles at (x, y). Particles fade out, shrink
	 * and fall with gravity. Recycles sprites from the group.
	 */
	public static function burstParticles(group:FlxTypedGroup<FlxSprite>, x:Float, y:Float, color:Int, count:Int = 12, speed:Float = 240):Void
	{
		if (!enabled() || group == null) return;
		for (i in 0...count)
		{
			var p:FlxSprite = group.recycle(FlxSprite);
			if (p == null) continue;
			if (p.graphic == null)
			{
				p.makeGraphic(7, 7, FlxColor.WHITE);
				p.antialiasing = false;
			}
			p.color = color;
			FlxTween.cancelTweensOf(p);
			p.reset(x + FlxG.random.float(-8, 8), y + FlxG.random.float(-8, 8));
			p.scale.set(FlxG.random.float(0.6, 1.2), FlxG.random.float(0.6, 1.2));
			p.alpha = 1;
			p.velocity.set();
			p.acceleration.set(0, 260);
			var ang:Float = FlxG.random.float(-Math.PI, 0) * 0.9 + Math.PI * 0.5;
			var sp:Float = FlxG.random.float(speed * 0.35, speed);
			p.velocity.x = Math.cos(ang) * sp;
			p.velocity.y = Math.sin(ang) * sp;
			p.angularVelocity = FlxG.random.float(-540, 540);
			var life:Float = FlxG.random.float(0.45, 0.85);
			FlxTween.tween(p, {alpha: 0}, life, {
				ease: FlxEase.quadIn,
				onComplete: function(twn:FlxTween) { p.kill(); }
			});
		}
	}

	/** Spawn a single sparkle that drifts upward and twinkles out. */
	public static function ambientSparkle(group:FlxTypedGroup<FlxSprite>, x:Float, y:Float, color:Int = 0xFFFFFFFF, size:Float = 4):Void
	{
		if (!enabled() || group == null) return;
		var p:FlxSprite = group.recycle(FlxSprite);
		if (p == null) return;
		if (p.graphic == null)
		{
			p.makeGraphic(5, 5, FlxColor.WHITE);
			p.antialiasing = false;
		}
		p.color = color;
		FlxTween.cancelTweensOf(p);
		p.reset(x, y);
		p.scale.set(size / 5, size / 5);
		p.alpha = 0;
		p.velocity.set(FlxG.random.float(-12, 12), FlxG.random.float(-70, -30));
		p.acceleration.set(0, -8);
		FlxTween.tween(p, {alpha: 0.9}, FlxG.random.float(0.2, 0.45), {
			onComplete: function(twn:FlxTween)
			{
				FlxTween.tween(p, {alpha: 0}, FlxG.random.float(0.5, 1.1), {
					onComplete: function(twn2:FlxTween) { p.kill(); }
				});
			}
		});
	}

	/** Expanding shockwave ring that fades out (used by selection confirmations). */
	public static function shockwaveRing(group:FlxTypedGroup<FlxSprite>, x:Float, y:Float, color:Int, maxRadius:Float = 260, thickness:Float = 9):Void
	{
		if (!enabled() || group == null) return;
		var size:Int = Std.int(maxRadius * 2.4);
		var ring:FlxSprite = new FlxSprite(x - size * 0.5, y - size * 0.5).makeGraphic(size, size, 0x00000000, true);
		FlxSpriteUtil.drawCircle(ring, size * 0.5, size * 0.5, size * 0.5 - thickness, 0x00000000,
			{thickness: thickness, color: color});
		ring.antialiasing = ClientPrefs.data.globalAntialiasing;
		ring.scale.set(0.08, 0.08);
		ring.alpha = 0.95;
		group.add(ring);
		FlxTween.tween(ring.scale, {x: 1, y: 1}, 0.55, {ease: FlxEase.cubeOut});
		FlxTween.tween(ring, {alpha: 0}, 0.55, {
			ease: FlxEase.sineOut,
			onComplete: function(twn:FlxTween)
			{
				group.remove(ring);
				ring.destroy();
			}
		});
	}

	/** Cycle the hue of a color over the shared menu clock. */
	public static function cycleHue(color:Int, speed:Float = 0.15):Int
	{
		var c:FlxColor = color;
		var h:Float = (c.hue + time * speed * 60) % 360;
		return FlxColor.fromHSB(h, c.saturation, c.brightness, c.alpha);
	}

	/** Blend two colors by amount (0 = a, 1 = b). */
	public static function mixColor(a:Int, b:Int, amount:Float):Int
	{
		amount = CoolUtil.boundTo(amount, 0, 1);
		var ca:FlxColor = a;
		var cb:FlxColor = b;
		return FlxColor.fromRGB(
			Std.int(ca.red + (cb.red - ca.red) * amount),
			Std.int(ca.green + (cb.green - ca.green) * amount),
			Std.int(ca.blue + (cb.blue - ca.blue) * amount),
			255
		);
	}

	/** Per-frame sine bob offset, phase-stable across states via shared time. */
	public static function bob(amp:Float, speed:Float, phase:Float):Float
	{
		return Math.sin(time * speed + phase) * amp;
	}

	/** Full-screen flash overlay that fades out. Add it to a camera. */
	public static function screenFlash(camera:FlxCamera, color:Int = 0xFFFFFFFF, maxAlpha:Float = 0.55, duration:Float = 0.45):Void
	{
		if (camera == null) return;
		var flash:FlxSprite = new FlxSprite().makeGraphic(Std.int(FlxG.width / camera.zoom), Std.int(FlxG.height / camera.zoom), color);
		flash.scrollFactor.set();
		flash.cameras = [camera];
		flash.alpha = maxAlpha;
		flash.blend = ADD;
		FlxG.state.add(flash);
		FlxTween.tween(flash, {alpha: 0}, duration, {
			ease: FlxEase.quadOut,
			onComplete: function(twn:FlxTween) { flash.kill(); }
		});
	}
}
