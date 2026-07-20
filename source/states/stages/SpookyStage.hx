package states.stages;

import flixel.FlxSprite;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxColor;
import ClientPrefs;
import BGSprite;
import Paths;

/**
 * Spooky stage (Week 2).
 * Public fields on PlayState that this manages:
 *   - halloweenBG
 *   - halloweenWhite
 * Private state:
 *   - lightningStrikeBeat, lightningOffset
 */
class SpookyStage extends StageBackdrop
{
	// Lightning tracking (previously on PlayState)
	public var lightningStrikeBeat:Int = 0;
	public var lightningOffset:Int = 8;

	public function new(playState:PlayState)
	{
		super(playState, 'spooky');
	}

	override public function beatHit():Void
	{
		if (FlxG.random.bool(10) && playState.curBeat > lightningStrikeBeat + lightningOffset)
			lightningStrikeShit();
	}

	override public function create():Void
	{
		if (!ClientPrefs.data.lowQuality)
		{
			playState.halloweenBG = new BGSprite('halloween_bg', -200, -100,
				['halloweem bg0', 'halloweem bg lightning strike']);
		}
		else
		{
			playState.halloweenBG = new BGSprite('halloween_bg_low', -200, -100);
		}
		add(playState.halloweenBG);

		playState.halloweenWhite = new BGSprite(null, -800, -400, 0, 0);
		playState.halloweenWhite.makeGraphic(Std.int(FlxG.width * 2), Std.int(FlxG.height * 2), FlxColor.WHITE);
		playState.halloweenWhite.alpha = 0;
		playState.halloweenWhite.blend = ADD;
		add(playState.halloweenWhite);

		precache('thunder_1', 'sound');
		precache('thunder_2', 'sound');
	}

	/** Called from PlayState.beatHit when curStage == 'spooky' and a random check passes. */
	public function maybeLightningStrike(curBeat:Int):Void
	{
		if (curBeat > lightningStrikeBeat + lightningOffset)
		{
			lightningStrikeShit();
		}
	}

	public function lightningStrikeShit():Void
	{
		FlxG.sound.play(Paths.soundRandom('thunder_', 1, 2));
		if (!ClientPrefs.data.lowQuality && playState.halloweenBG != null)
			playState.halloweenBG.animation.play('halloweem bg lightning strike');

		lightningStrikeBeat = playState.curBeat;
		lightningOffset = FlxG.random.int(8, 24);

		if (playState.boyfriend != null && playState.boyfriend.animOffsets.exists('scared'))
			playState.boyfriend.playAnim('scared', true);

		if (playState.gf != null && playState.gf.animOffsets.exists('scared'))
			playState.gf.playAnim('scared', true);

		if (ClientPrefs.data.camZooms)
		{
			FlxG.camera.zoom += 0.015;
			playState.camHUD.zoom += 0.03;

			if (!playState.camZooming)
			{
				FlxTween.tween(FlxG.camera, {zoom: playState.defaultCamZoom}, 0.5);
				FlxTween.tween(playState.camHUD, {zoom: 1}, 0.5);
			}
		}

		if (ClientPrefs.data.flashing && playState.halloweenWhite != null)
		{
			playState.halloweenWhite.alpha = 0.4;
			FlxTween.tween(playState.halloweenWhite, {alpha: 0.5}, 0.075);
			FlxTween.tween(playState.halloweenWhite, {alpha: 0}, 0.25, {startDelay: 0.15});
		}
	}
}
