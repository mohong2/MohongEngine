package states.stages;

import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import BGSprite;
import BackgroundGirls;
import ClientPrefs;
import Paths;
import substates.GameOverSubstate;

/**
 * School stage (Week 6 – Senpai, Roses).
 * Public fields on PlayState managed:
 *   - bgGirls
 */
class SchoolStage extends StageBackdrop
{
	public function new(playState:PlayState)
	{
		super(playState, 'school');
	}

	override public function create():Void
	{
		// Pixel death state overrides
		GameOverSubstate.deathSoundName = 'fnf_loss_sfx-pixel';
		GameOverSubstate.loopSoundName = 'gameOver-pixel';
		GameOverSubstate.endSoundName = 'gameOverEnd-pixel';
		GameOverSubstate.characterName = 'bf-pixel-dead';

		var bgSky:BGSprite = new BGSprite('weeb/weebSky', 0, 0, 0.1, 0.1);
		bgSky.antialiasing = false;
		add(bgSky);

		var repositionShit = -200;

		var bgSchool:BGSprite = new BGSprite('weeb/weebSchool', repositionShit, 0, 0.6, 0.90);
		bgSchool.antialiasing = false;
		add(bgSchool);

		var bgStreet:BGSprite = new BGSprite('weeb/weebStreet', repositionShit, 0, 0.95, 0.95);
		bgStreet.antialiasing = false;
		add(bgStreet);

		var widShit = Std.int(bgSky.width * 6);

		if (!ClientPrefs.data.lowQuality)
		{
			var fgTrees:BGSprite = new BGSprite('weeb/weebTreesBack',
				repositionShit + 170, 130, 0.9, 0.9);
			fgTrees.setGraphicSize(Std.int(widShit * 0.8));
			fgTrees.updateHitbox();
			fgTrees.antialiasing = false;
			add(fgTrees);
		}

		var bgTrees:FlxSprite = new FlxSprite(repositionShit - 380, -800);
		bgTrees.frames = Paths.getPackerAtlas('weeb/weebTrees');
		bgTrees.animation.add('treeLoop', [
			0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18], 12);
		bgTrees.animation.play('treeLoop');
		bgTrees.scrollFactor.set(0.85, 0.85);
		bgTrees.antialiasing = false;
		add(bgTrees);

		if (!ClientPrefs.data.lowQuality)
		{
			var treeLeaves:BGSprite = new BGSprite('weeb/petals', repositionShit, -40,
				0.85, 0.85, ['PETALS ALL'], true);
			treeLeaves.setGraphicSize(widShit);
			treeLeaves.updateHitbox();
			treeLeaves.antialiasing = false;
			add(treeLeaves);
		}

		bgSky.setGraphicSize(widShit);
		bgSchool.setGraphicSize(widShit);
		bgStreet.setGraphicSize(widShit);
		bgTrees.setGraphicSize(Std.int(widShit * 1.4));

		bgSky.updateHitbox();
		bgSchool.updateHitbox();
		bgStreet.updateHitbox();
		bgTrees.updateHitbox();

		if (!ClientPrefs.data.lowQuality)
		{
			playState.bgGirls = new BackgroundGirls(-100, 190);
			playState.bgGirls.scrollFactor.set(0.9, 0.9);
			playState.bgGirls.setGraphicSize(
				Std.int(playState.bgGirls.width * PlayState.daPixelZoom));
			playState.bgGirls.updateHitbox();
			add(playState.bgGirls);
		}
	}

	override public function beatHit():Void
	{
		if (!ClientPrefs.data.lowQuality && playState.bgGirls != null)
			playState.bgGirls.dance();
	}
}
