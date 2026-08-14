package;

class MenuItem extends FlxSprite
{
	public var targetY:Float = 0;

	public function new(x:Float, y:Float, weekName:String = '')
	{
		super(x, y);
		loadGraphic(Paths.languageImage('storymenu/' + weekName));
		antialiasing = ClientPrefs.data.globalAntialiasing;
	}

	private var isFlashing:Bool = false;
	private var flashTime:Float = 0;

	public function startFlashing():Void
	{
		isFlashing = true;
		flashTime = 0;
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		y = FlxMath.lerp(y, (targetY * 120) + 480, CoolUtil.boundTo(elapsed * 10.2, 0, 1));

		if (isFlashing)
		{
			// Toggle every 0.1s (10 Hz) so the confirm flash is framerate independent.
			flashTime += elapsed;
			color = (Math.floor(flashTime * 10) % 2 == 0) ? 0xFF33FFFF : FlxColor.WHITE;
		}
		else
		{
			color = FlxColor.WHITE;
		}
	}
}