package states.stages;

import flixel.group.FlxSpriteGroup;
import BGSprite;
import ClientPrefs;

/**
 * Default "stage" background (Week 1).
 * Public fields on PlayState that this manages:
 *   - dadbattleSmokes (FlxSpriteGroup, created even though unused on stage)
 */
class BaseStage extends StageBackdrop
{
	public function new(playState:PlayState)
	{
		super(playState, 'stage');
	}

	override public function create():Void
	{
		// Stage back
		var bg:BGSprite = new BGSprite('stageback', -600, -200, 0.9, 0.9);
		add(bg);

		// Stage front
		var stageFront:BGSprite = new BGSprite('stagefront', -650, 600, 0.9, 0.9);
		stageFront.setGraphicSize(Std.int(stageFront.width * 1.1));
		stageFront.updateHitbox();
		add(stageFront);

		if (!ClientPrefs.data.lowQuality)
		{
			var stageLight:BGSprite = new BGSprite('stage_light', -125, -100, 0.9, 0.9);
			stageLight.setGraphicSize(Std.int(stageLight.width * 1.1));
			stageLight.updateHitbox();
			add(stageLight);

			var stageLight2:BGSprite = new BGSprite('stage_light', 1225, -100, 0.9, 0.9);
			stageLight2.setGraphicSize(Std.int(stageLight2.width * 1.1));
			stageLight2.updateHitbox();
			stageLight2.flipX = true;
			add(stageLight2);

			var stageCurtains:BGSprite = new BGSprite('stagecurtains', -500, -300, 1.3, 1.3);
			stageCurtains.setGraphicSize(Std.int(stageCurtains.width * 0.9));
			stageCurtains.updateHitbox();
			add(stageCurtains);
		}

		// Dadbattle smoke group — created here for event compatibility, unused on this stage
		playState.dadbattleSmokes = new FlxSpriteGroup();
		add(playState.dadbattleSmokes);
	}
}
