package states.stages;

import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.system.FlxSound;
import flixel.util.FlxTimer;
import BackgroundDancer;
import BGSprite;
import ClientPrefs;
import Achievements;
import CoolUtil;
import Paths;

/**
 * Limo stage (Week 4).
 * Public fields on PlayState managed:
 *   - limoKillingState, limo, limoMetalPole, limoLight
 *   - limoCorpse, limoCorpseTwo, bgLimo
 *   - grpLimoParticles, grpLimoDancers, fastCar
 */
class LimoStage extends StageBackdrop
{
	public var limoSpeed:Float = 0;
	public var fastCarCanDrive:Bool = true;
	public var carTimer:FlxTimer;

	public function new(playState:PlayState)
	{
		super(playState, 'limo');
	}

	override public function create():Void
	{
		var skyBG:BGSprite = new BGSprite('limo/limoSunset', -120, -50, 0.1, 0.1);
		add(skyBG);

		if (!ClientPrefs.data.lowQuality)
		{
			playState.limoMetalPole = new BGSprite('gore/metalPole', -500, 220, 0.4, 0.4);
			add(playState.limoMetalPole);

			playState.bgLimo = new BGSprite('limo/bgLimo', -150, 480, 0.4, 0.4,
				['background limo pink'], true);
			add(playState.bgLimo);

			playState.limoCorpse = new BGSprite('gore/noooooo', -500,
				playState.limoMetalPole.y - 130, 0.4, 0.4, ['Henchmen on rail'], true);
			add(playState.limoCorpse);

			playState.limoCorpseTwo = new BGSprite('gore/noooooo', -500,
				playState.limoMetalPole.y, 0.4, 0.4, ['henchmen death'], true);
			add(playState.limoCorpseTwo);

			playState.grpLimoDancers = new FlxTypedGroup<BackgroundDancer>();
			add(playState.grpLimoDancers);

			for (i in 0...5)
			{
				var dancer:BackgroundDancer = new BackgroundDancer(
					(370 * i) + 170, playState.bgLimo.y - 400);
				dancer.scrollFactor.set(0.4, 0.4);
				playState.grpLimoDancers.add(dancer);
			}

			playState.limoLight = new BGSprite('gore/coldHeartKiller',
				playState.limoMetalPole.x - 180, playState.limoMetalPole.y - 80, 0.4, 0.4);
			add(playState.limoLight);

			playState.grpLimoParticles = new FlxTypedGroup<BGSprite>();
			add(playState.grpLimoParticles);

			// Precache blood
			var particle:BGSprite = new BGSprite('gore/stupidBlood', -400, -400, 0.4, 0.4,
				['blood'], false);
			particle.alpha = 0.01;
			playState.grpLimoParticles.add(particle);
			resetLimoKill();

			precache('dancerdeath', 'sound');
		}

		playState.limo = new BGSprite('limo/limoDrive', -120, 550, 1, 1,
			['Limo stage'], true);
		add(playState.limo);

		playState.fastCar = new BGSprite('limo/fastCarLol', -300, 160);
		playState.fastCar.active = true;
		playState.limoKillingState = 0;
	}

	override public function update(elapsed:Float):Void
	{
		if (ClientPrefs.data.lowQuality) return;

		// Clean up finished particle animations
		if (playState.grpLimoParticles != null)
		{
			playState.grpLimoParticles.forEach(function(spr:BGSprite)
			{
				if (spr.animation.curAnim != null && spr.animation.curAnim.finished)
				{
					playState.grpLimoParticles.remove(spr, true);
					spr.destroy();
				}
			});
		}

		// Limo killing state machine
		switch (playState.limoKillingState)
		{
			case 1:
				playState.limoMetalPole.x += 5000 * elapsed;
				playState.limoLight.x = playState.limoMetalPole.x - 180;
				playState.limoCorpse.x = playState.limoLight.x - 50;
				playState.limoCorpseTwo.x = playState.limoLight.x + 35;

				var dancers = playState.grpLimoDancers.members;
				for (i in 0...dancers.length)
				{
					if (dancers[i].x < FlxG.width * 1.5
						&& playState.limoLight.x > (370 * i) + 170)
					{
						switch (i)
						{
							case 0 | 3:
								if (i == 0) FlxG.sound.play(Paths.sound('dancerdeath'), 0.5);
								var diffStr:String = i == 3 ? ' 2 ' : ' ';
								spawnLimoParticle(dancers[i].x + 200, dancers[i].y,
									'hench leg spin' + diffStr + 'PINK');
								spawnLimoParticle(dancers[i].x + 160, dancers[i].y + 200,
									'hench arm spin' + diffStr + 'PINK');
								spawnLimoParticle(dancers[i].x, dancers[i].y + 50,
									'hench head spin' + diffStr + 'PINK');
								spawnBloodParticle(dancers[i].x - 110, dancers[i].y + 20);
							case 1:
								if (playState.limoCorpse != null)
									playState.limoCorpse.visible = true;
							case 2:
								if (playState.limoCorpseTwo != null)
									playState.limoCorpseTwo.visible = true;
						}
						dancers[i].x += FlxG.width * 2;
					}
				}

				if (playState.limoMetalPole.x > FlxG.width * 2)
				{
					resetLimoKill();
					limoSpeed = 800;
					playState.limoKillingState = 2;
				}

			case 2:
				limoSpeed -= 4000 * elapsed;
				playState.bgLimo.x -= limoSpeed * elapsed;
				if (playState.bgLimo.x > FlxG.width * 1.5)
				{
					limoSpeed = 3000;
					playState.limoKillingState = 3;
				}

			case 3:
				limoSpeed -= 2000 * elapsed;
				if (limoSpeed < 1000) limoSpeed = 1000;
				playState.bgLimo.x -= limoSpeed * elapsed;
				if (playState.bgLimo.x < -275)
				{
					playState.limoKillingState = 4;
					limoSpeed = 800;
				}

			case 4:
				playState.bgLimo.x = FlxMath.lerp(playState.bgLimo.x, -150,
					CoolUtil.boundTo(elapsed * 9, 0, 1));
				if (Math.round(playState.bgLimo.x) == -150)
				{
					playState.bgLimo.x = -150;
					playState.limoKillingState = 0;
				}
		}

		// Reposition dancers during reset animation
		if (playState.limoKillingState > 2 && playState.grpLimoDancers != null)
		{
			var dancers = playState.grpLimoDancers.members;
			for (i in 0...dancers.length)
				dancers[i].x = (370 * i) + playState.bgLimo.x + 280;
		}
	}

	override public function beatHit():Void
	{
		if (!ClientPrefs.data.lowQuality && playState.grpLimoDancers != null)
		{
			playState.grpLimoDancers.forEach(function(dancer) dancer.dance());
		}

		if (FlxG.random.bool(10) && fastCarCanDrive && playState.fastCar != null)
			fastCarDrive();
	}

	// ---- Event: Kill Henchmen ----
	public function killHenchmen():Void
	{
		if (!ClientPrefs.data.lowQuality && ClientPrefs.data.violence)
		{
			if (playState.limoKillingState < 1)
			{
				playState.limoMetalPole.x = -400;
				playState.limoMetalPole.visible = true;
				playState.limoLight.visible = true;
				if (playState.limoCorpse != null) playState.limoCorpse.visible = false;
				if (playState.limoCorpseTwo != null) playState.limoCorpseTwo.visible = false;
				playState.limoKillingState = 1;

				#if ACHIEVEMENTS_ALLOWED
				Achievements.henchmenDeath++;
				FlxG.save.data.henchmenDeath = Achievements.henchmenDeath;
				var achieve:String = playState.checkForAchievement(['roadkill_enthusiast']);
				if (achieve != null) {
					playState.startAchievement(achieve);
				} else {
					FlxG.save.flush();
				}
				FlxG.log.add('Deaths: ' + Achievements.henchmenDeath);
				#end
			}
		}
	}

	// ---- Helpers ----

	function spawnLimoParticle(x:Float, y:Float, anim:String):Void
	{
		if (playState.grpLimoParticles == null) return;
		var p:BGSprite = new BGSprite('gore/noooooo', x, y, 0.4, 0.4, [anim], false);
		playState.grpLimoParticles.add(p);
	}

	function spawnBloodParticle(x:Float, y:Float):Void
	{
		if (playState.grpLimoParticles == null) return;
		var p:BGSprite = new BGSprite('gore/stupidBlood', x, y, 0.4, 0.4, ['blood'], false);
		p.flipX = true;
		p.angle = -57.5;
		playState.grpLimoParticles.add(p);
	}

	public function resetFastCar():Void
	{
		if (playState.fastCar == null) return;
		playState.fastCar.x = -12600;
		playState.fastCar.y = FlxG.random.int(140, 250);
		playState.fastCar.velocity.x = 0;
		fastCarCanDrive = true;
	}

	function fastCarDrive():Void
	{
		if (playState.fastCar == null) return;
		FlxG.sound.play(Paths.soundRandom('carPass', 0, 1), 0.7);
		playState.fastCar.velocity.x = (FlxG.random.int(170, 220) / FlxG.elapsed) * 3;
		fastCarCanDrive = false;
		carTimer = new FlxTimer().start(2, function(_)
		{
			resetFastCar();
			carTimer = null;
		});
	}

	function resetLimoKill():Void
	{
		if (playState.limoMetalPole != null)
		{
			playState.limoMetalPole.x = -500;
			playState.limoMetalPole.visible = false;
		}
		if (playState.limoLight != null)
		{
			playState.limoLight.x = -500;
			playState.limoLight.visible = false;
		}
		if (playState.limoCorpse != null)
		{
			playState.limoCorpse.x = -500;
			playState.limoCorpse.visible = false;
		}
		if (playState.limoCorpseTwo != null)
		{
			playState.limoCorpseTwo.x = -500;
			playState.limoCorpseTwo.visible = false;
		}
	}
}
