package states.stages;

import BGSprite;
import ClientPrefs;

/**
 * Mall stage (Week 5 – Cocoa, Eggnog).
 * Public fields on PlayState managed:
 *   - upperBoppers, bottomBoppers, santa, heyTimer
 */
class MallStage extends StageBackdrop
{
	public function new(playState:PlayState)
	{
		super(playState, 'mall');
	}

	override public function create():Void
	{
		var bg:BGSprite = new BGSprite('christmas/bgWalls', -1000, -500, 0.2, 0.2);
		bg.setGraphicSize(Std.int(bg.width * 0.8));
		bg.updateHitbox();
		add(bg);

		if (!ClientPrefs.data.lowQuality)
		{
			playState.upperBoppers = new BGSprite('christmas/upperBop', -240, -90,
				0.33, 0.33, ['Upper Crowd Bob']);
			playState.upperBoppers.setGraphicSize(Std.int(playState.upperBoppers.width * 0.85));
			playState.upperBoppers.updateHitbox();
			add(playState.upperBoppers);

			var bgEscalator:BGSprite = new BGSprite('christmas/bgEscalator', -1100, -600, 0.3, 0.3);
			bgEscalator.setGraphicSize(Std.int(bgEscalator.width * 0.9));
			bgEscalator.updateHitbox();
			add(bgEscalator);
		}

		var tree:BGSprite = new BGSprite('christmas/christmasTree', 370, -250, 0.40, 0.40);
		add(tree);

		playState.bottomBoppers = new BGSprite('christmas/bottomBop', -300, 140,
			0.9, 0.9, ['Bottom Level Boppers Idle']);
		playState.bottomBoppers.animation.addByPrefix('hey',
			'Bottom Level Boppers HEY', 24, false);
		playState.bottomBoppers.setGraphicSize(Std.int(playState.bottomBoppers.width * 1));
		playState.bottomBoppers.updateHitbox();
		add(playState.bottomBoppers);

		var fgSnow:BGSprite = new BGSprite('christmas/fgSnow', -600, 700);
		add(fgSnow);

		playState.santa = new BGSprite('christmas/santa', -840, 150, 1, 1,
			['santa idle in fear']);
		add(playState.santa);

		precache('Lights_Shut_off', 'sound');
	}

	override public function update(elapsed:Float):Void
	{
		if (playState.heyTimer > 0)
		{
			playState.heyTimer -= elapsed;
			if (playState.heyTimer <= 0)
			{
				if (playState.bottomBoppers != null)
					playState.bottomBoppers.dance(true);
				playState.heyTimer = 0;
			}
		}
	}

	override public function beatHit():Void
	{
		if (!ClientPrefs.data.lowQuality && playState.upperBoppers != null)
			playState.upperBoppers.dance(true);

		if (playState.heyTimer <= 0 && playState.bottomBoppers != null)
			playState.bottomBoppers.dance(true);

		if (playState.santa != null)
			playState.santa.dance(true);
	}
}
