package states.stages;

import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.util.FlxColor;
import flixel.system.FlxSound;
import flixel.math.FlxMath;
import BGSprite;
import ClientPrefs;
import PhillyGlow;
import animateatlas.AtlasFrameMaker;
import Conductor;
import Paths;
import Character;

/**
 * Philly stage (Week 3).
 * Public fields on PlayState managed:
 *   - phillyLightsColors, phillyWindow, phillyStreet, phillyTrain
 *   - blammedLightsBlack, phillyWindowEvent, trainSound
 *   - phillyGlowGradient, phillyGlowParticles
 */
class PhillyStage extends StageBackdrop
{
	// Train state
	public var trainMoving:Bool = false;
	public var trainFrameTiming:Float = 0;
	public var trainCars:Int = 8;
	public var trainFinishing:Bool = false;
	public var trainCooldown:Int = 0;
	public var startedMoving:Bool = false;

	public function new(playState:PlayState)
	{
		super(playState, 'philly');
	}

	override public function create():Void
	{
		if (!ClientPrefs.data.lowQuality)
		{
			var bg:BGSprite = new BGSprite('philly/sky', -100, 0, 0.1, 0.1);
			add(bg);
		}

		var city:BGSprite = new BGSprite('philly/city', -10, 0, 0.3, 0.3);
		city.setGraphicSize(Std.int(city.width * 0.85));
		city.updateHitbox();
		add(city);

		playState.phillyLightsColors = [
			0xFF31A2FD, 0xFF31FD8C, 0xFFFB33F5, 0xFFFD4531, 0xFFFBA633
		];

		playState.phillyWindow = new BGSprite('philly/window', city.x, city.y, 0.3, 0.3);
		playState.phillyWindow.setGraphicSize(Std.int(playState.phillyWindow.width * 0.85));
		playState.phillyWindow.updateHitbox();
		add(playState.phillyWindow);
		playState.phillyWindow.alpha = 0;

		if (!ClientPrefs.data.lowQuality)
		{
			var streetBehind:BGSprite = new BGSprite('philly/behindTrain', -40, 50);
			add(streetBehind);
		}

		playState.phillyTrain = new BGSprite('philly/train', 2000, 360);
		add(playState.phillyTrain);

		playState.trainSound = new FlxSound().loadEmbedded(Paths.sound('train_passes'));
		FlxG.sound.list.add(playState.trainSound);

		playState.phillyStreet = new BGSprite('philly/street', -40, 50);
		add(playState.phillyStreet);
	}

	override public function update(elapsed:Float):Void
	{
		// Train movement
		if (trainMoving)
		{
			trainFrameTiming += elapsed;
			if (trainFrameTiming >= 1 / 24)
			{
				updateTrainPos();
				trainFrameTiming = 0;
			}
		}

		// Window fade
		if (playState.phillyWindow != null)
			playState.phillyWindow.alpha -= (Conductor.crochet / 1000) * FlxG.elapsed * 1.5;

		// Glow particle cleanup
		if (playState.phillyGlowParticles != null)
		{
			var i:Int = playState.phillyGlowParticles.members.length - 1;
			while (i > 0)
			{
				var particle = playState.phillyGlowParticles.members[i];
				if (particle.alpha < 0)
				{
					playState.phillyGlowParticles.remove(particle, true);
					particle.destroy();
				}
				--i;
			}
		}
	}

	override public function beatHit():Void
	{
		if (!trainMoving)
			trainCooldown += 1;

		if (playState.curBeat % 4 == 0)
		{
			playState.curLight = FlxG.random.int(0, playState.phillyLightsColors.length - 1, [playState.curLight]);
			if (playState.phillyWindow != null)
			{
				playState.phillyWindow.color = playState.phillyLightsColors[playState.curLight];
				playState.phillyWindow.alpha = 1;
			}
		}

		if (playState.curBeat % 8 == 4 && FlxG.random.bool(30) && !trainMoving && trainCooldown > 8)
		{
			trainCooldown = FlxG.random.int(-4, 0);
			trainStart();
		}
	}

	// ---- Philly Glow event handler ----
	override public function eventTrigger(eventName:String, value1:String, value2:String):Bool
	{
		if (eventName != 'Philly Glow') return false;

		var lightId:Int = Std.parseInt(value1);
		if (Math.isNaN(lightId)) lightId = 0;

		var doFlash:Void->Void = function()
		{
			var color:FlxColor = FlxColor.WHITE;
			if (!ClientPrefs.data.flashing) color.alphaFloat = 0.5;
			FlxG.camera.flash(color, 0.15, null, true);
		};

		var chars:Array<Character> = [playState.boyfriend, playState.gf, playState.dad];

		switch (lightId)
		{
			case 0:
				if (playState.phillyGlowGradient != null && playState.phillyGlowGradient.visible)
				{
					doFlash();
					if (ClientPrefs.data.camZooms)
					{
						FlxG.camera.zoom += 0.5;
						playState.camHUD.zoom += 0.1;
					}

					playState.blammedLightsBlack.visible = false;
					playState.phillyWindowEvent.visible = false;
					playState.phillyGlowGradient.visible = false;
					playState.phillyGlowParticles.visible = false;
					playState.curLightEvent = -1;

					for (who in chars) { if (who != null) who.color = FlxColor.WHITE; }
					if (playState.phillyStreet != null) playState.phillyStreet.color = FlxColor.WHITE;
				}

			case 1:
				playState.curLightEvent = FlxG.random.int(0, playState.phillyLightsColors.length - 1, [playState.curLightEvent]);
				var color:FlxColor = playState.phillyLightsColors[playState.curLightEvent];

				if (playState.phillyGlowGradient == null || !playState.phillyGlowGradient.visible)
				{
					doFlash();
					if (ClientPrefs.data.camZooms)
					{
						FlxG.camera.zoom += 0.5;
						playState.camHUD.zoom += 0.1;
					}

					playState.blammedLightsBlack.visible = true;
					playState.blammedLightsBlack.alpha = 1;
					playState.phillyWindowEvent.visible = true;
					playState.phillyGlowGradient.visible = true;
					playState.phillyGlowParticles.visible = true;
				}
				else if (ClientPrefs.data.flashing)
				{
					var colorButLower:FlxColor = color;
					colorButLower.alphaFloat = 0.25;
					FlxG.camera.flash(colorButLower, 0.5, null, true);
				}

				var charColor:FlxColor = color;
				if (!ClientPrefs.data.flashing) charColor.saturation *= 0.5;
				else charColor.saturation *= 0.75;

				for (who in chars) { if (who != null) who.color = charColor; }

				if (playState.phillyGlowParticles != null)
				{
					playState.phillyGlowParticles.forEachAlive(function(p) { p.color = color; });
				}
				if (playState.phillyGlowGradient != null) playState.phillyGlowGradient.color = color;
				if (playState.phillyWindowEvent != null) playState.phillyWindowEvent.color = color;

				color.brightness *= 0.5;
				if (playState.phillyStreet != null) playState.phillyStreet.color = color;

			case 2:
				if (!ClientPrefs.data.lowQuality
					&& playState.phillyGlowGradient != null
					&& playState.phillyGlowParticles != null)
				{
					var particlesNum:Int = FlxG.random.int(8, 12);
					var width:Float = (2000 / particlesNum);
					var color:FlxColor = playState.phillyLightsColors[playState.curLightEvent];
					for (j in 0...3)
					{
						for (i in 0...particlesNum)
						{
							var particle:PhillyGlow.PhillyGlowParticle =
								new PhillyGlow.PhillyGlowParticle(
									-400 + width * i + FlxG.random.float(-width / 5, width / 5),
									playState.phillyGlowGradient.originalY + 200 + (FlxG.random.float(0, 125) + j * 40),
									color);
							playState.phillyGlowParticles.add(particle);
						}
					}
				}
				if (playState.phillyGlowGradient != null) playState.phillyGlowGradient.bop();
		}

		return true;
	}

	// ---- Train helpers ----

	function trainStart():Void
	{
		trainMoving = true;
		if (playState.trainSound != null && !playState.trainSound.playing)
			playState.trainSound.play(true);
	}

	function updateTrainPos():Void
	{
		if (playState.trainSound != null && playState.trainSound.time >= 4700)
		{
			startedMoving = true;
			if (playState.gf != null)
			{
				playState.gf.playAnim('hairBlow');
				playState.gf.specialAnim = true;
			}
		}

		if (startedMoving && playState.phillyTrain != null)
		{
			playState.phillyTrain.x -= 400;

			if (playState.phillyTrain.x < -2000 && !trainFinishing)
			{
				playState.phillyTrain.x = -1150;
				trainCars -= 1;
				if (trainCars <= 0) trainFinishing = true;
			}

			if (playState.phillyTrain.x < -4000 && trainFinishing)
				trainReset();
		}
	}

	function trainReset():Void
	{
		if (playState.gf != null)
		{
			playState.gf.danced = false;
			playState.gf.playAnim('hairFall');
			playState.gf.specialAnim = true;
		}
		if (playState.phillyTrain != null)
			playState.phillyTrain.x = FlxG.width + 200;
		trainMoving = false;
		trainCars = 8;
		trainFinishing = false;
		startedMoving = false;
	}
}
