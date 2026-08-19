package;

 
 
import flixel.graphics.frames.FlxAtlasFrames;
 

using StringTools;

class Boyfriend extends Character
{
	public var startedDeath:Bool = false;

	public function new(x:Float, y:Float, ?char:String = 'bf')
	{
		super(x, y, char, true);
	}

	override function update(elapsed:Float)
	{
		if (!debugMode && !isAnimationNull())
		{
			var animName:String = getAnimationName();
			if (animName.startsWith('sing'))
			{
				holdTimer += elapsed;
			}
			else
				holdTimer = 0;

			if (animName.endsWith('miss') && isAnimationFinished() && !debugMode)
			{
				playAnim('idle', true, false, 10);
			}

			if (animName == 'firstDeath' && isAnimationFinished() && startedDeath)
			{
				playAnim('deathLoop');
			}
		}

		super.update(elapsed);
	}
}
