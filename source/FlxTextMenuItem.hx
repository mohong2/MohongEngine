package;

import flixel.text.FlxText;
import flixel.math.FlxPoint;
import flixel.math.FlxMath;
import flixel.FlxG;
import flixel.util.FlxColor;

class FlxTextMenuItem extends FlxText
{
	public var isMenuItem:Bool = true;
	public var targetY:Int = 0;
	public var changeX:Bool = true;
	public var changeY:Bool = true;

	public var distancePerItem:FlxPoint = new FlxPoint(20, 120);
	public var startPosition:FlxPoint = new FlxPoint(0, 0);

	// Arc positioning
	public var useArc:Bool = false;
	public var arcOriginX:Float = 0;
	public var arcOriginY:Float = 0;
	public var arcRadius:Float = 300;
	public var arcStartAngle:Float = -60;
	public var arcEndAngle:Float = 60;
	public var arcTotalItems:Int = 7;
	public var arcIndex:Int = 0;

	public function new(x:Float, y:Float, text:String, size:Int = 48)
	{
		super(x, y, 0, text, size);
		this.startPosition.x = x;
		this.startPosition.y = y;

		setFormat(Paths.languageFont(), size, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE_FAST, FlxColor.BLACK);
		this.borderSize = 4;
		antialiasing = ClientPrefs.data.globalAntialiasing;
	}

	override function update(elapsed:Float)
	{
		if (isMenuItem)
		{
			var lerpVal:Float = Math.exp(-elapsed * 9.6);
			if (useArc)
			{
				var fraction:Float = arcIndex / Math.max(arcTotalItems - 1, 1);
				var angle:Float = arcStartAngle + fraction * (arcEndAngle - arcStartAngle);
				var angleRad:Float = angle * Math.PI / 180;
				var targetX:Float = arcOriginX + arcRadius * Math.cos(angleRad);
				var targetYPos:Float = arcOriginY + arcRadius * Math.sin(angleRad);
				x = FlxMath.lerp(targetX, x, lerpVal);
				y = FlxMath.lerp(targetYPos, y, lerpVal);
			}
			else
			{
				if (changeX)
					x = FlxMath.lerp((targetY * distancePerItem.x) + startPosition.x, x, lerpVal);
				if (changeY)
					y = FlxMath.lerp((targetY * 1.3 * distancePerItem.y) + startPosition.y, y, lerpVal);
			}
		}
		super.update(elapsed);
	}

	public function snapToPosition()
	{
		if (isMenuItem)
		{
			if (useArc)
			{
				var fraction:Float = arcIndex / Math.max(arcTotalItems - 1, 1);
				var angle:Float = arcStartAngle + fraction * (arcEndAngle - arcStartAngle);
				var angleRad:Float = angle * Math.PI / 180;
				x = arcOriginX + arcRadius * Math.cos(angleRad);
				y = arcOriginY + arcRadius * Math.sin(angleRad);
			}
			else
			{
				if (changeX)
					x = (targetY * distancePerItem.x) + startPosition.x;
				if (changeY)
					y = (targetY * 1.3 * distancePerItem.y) + startPosition.y;
			}
		}
	}
}

class FlxTextAttached extends FlxText
{
	public var offsetX:Float = 0;
	public var offsetY:Float = 0;
	public var sprTracker:FlxSprite;
	public var copyVisible:Bool = true;
	public var copyAlpha:Bool = false;

	public function new(text:String = "", size:Int = 48, ?offsetX:Float = 0, ?offsetY:Float = 0)
	{
		super(0, 0, 0, text, size);
		this.offsetX = offsetX;
		this.offsetY = offsetY;
		
		setFormat(Paths.languageFont(), size, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE_FAST, FlxColor.BLACK);
		this.borderSize = 4;
		antialiasing = ClientPrefs.data.globalAntialiasing;
	}

	override function update(elapsed:Float)
	{
		if (sprTracker != null)
		{
			x = sprTracker.x + offsetX;
			y = sprTracker.y + offsetY;

			if (copyVisible)
			{
				visible = sprTracker.visible;
			}
			if (copyAlpha)
			{
				alpha = sprTracker.alpha;
			}
		}

		super.update(elapsed);
	}
}