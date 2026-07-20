package states.stages;

import flixel.addons.effects.FlxTrail;
import BGSprite;
import ClientPrefs;
import substates.GameOverSubstate;

/**
 * School Evil stage (Week 6 – Thorns).
 * Public fields on PlayState managed:
 *   - bgGhouls
 */
class SchoolEvilStage extends StageBackdrop
{
	public function new(playState:PlayState)
	{
		super(playState, 'schoolEvil');
	}

	override public function create():Void
	{
		GameOverSubstate.deathSoundName = 'fnf_loss_sfx-pixel';
		GameOverSubstate.loopSoundName = 'gameOver-pixel';
		GameOverSubstate.endSoundName = 'gameOverEnd-pixel';
		GameOverSubstate.characterName = 'bf-pixel-dead';

		var posX = 400;
		var posY = 200;

		if (!ClientPrefs.data.lowQuality)
		{
			var bg:BGSprite = new BGSprite('weeb/animatedEvilSchool', posX, posY,
				0.8, 0.9, ['background 2'], true);
			bg.scale.set(6, 6);
			bg.antialiasing = false;
			add(bg);

			playState.bgGhouls = new BGSprite('weeb/bgGhouls', -100, 190, 0.9, 0.9,
				['BG freaks glitch instance'], false);
			playState.bgGhouls.setGraphicSize(
				Std.int(playState.bgGhouls.width * PlayState.daPixelZoom));
			playState.bgGhouls.updateHitbox();
			playState.bgGhouls.visible = false;
			playState.bgGhouls.antialiasing = false;
			add(playState.bgGhouls);
		}
		else
		{
			var bg:BGSprite = new BGSprite('weeb/animatedEvilSchool_low', posX, posY,
				0.8, 0.9);
			bg.scale.set(6, 6);
			bg.antialiasing = false;
			add(bg);
		}
	}

	override public function update(elapsed:Float):Void
	{
		if (!ClientPrefs.data.lowQuality
			&& playState.bgGhouls != null
			&& playState.bgGhouls.animation.curAnim != null
			&& playState.bgGhouls.animation.curAnim.finished)
		{
			playState.bgGhouls.visible = false;
		}
	}

	/**
	 * Called after dad is created to add his evil trail.
	 * (Cannot be done in create() because dad doesn't exist yet.)
	 */
	public function addEvilTrail():Void
	{
		if (playState.dad != null)
		{
			var evilTrail = new FlxTrail(playState.dad, null, 4, 24, 0.3, 0.069);
			addBehindDad(evilTrail);
		}
	}
}
