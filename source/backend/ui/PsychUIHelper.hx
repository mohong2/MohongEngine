package backend.ui;

import openfl.geom.Rectangle;

/**
 * Utility class for creating rounded-rectangle graphics.
 * Uses makeGraphic() + pixel manipulation, which is fully reliable on all targets.
 */
class PsychUIHelper
{
	/** Default corner radius used across all UI components. */
	public static var cornerRadius:Int = 8;

	/**
	 * Creates a white rounded-rectangle FlxSprite.
	 * The sprite is fully white with transparent corners, so `.color` / `.alpha` tinting works.
	 */
	public static function createRoundedRectSprite(width:Int, height:Int, ?radius:Int = -1):FlxSprite
	{
		if(radius < 0) radius = cornerRadius;
		var r:Int = Std.int(Math.max(1, Math.min(radius, Std.int(Math.min(width, height) / 2))));
		if(width < 2) width = 2;
		if(height < 2) height = 2;

		var sprite = new FlxSprite();
		sprite.makeGraphic(width, height, FlxColor.WHITE);

		if(r > 0) _punchCorners(sprite, width, height, r);

		return sprite;
	}

	/**
	 * Replaces the graphic of an existing FlxSprite with a white rounded-rectangle.
	 */
	public static function makeRoundedRect(sprite:FlxSprite, width:Int, height:Int, ?radius:Int = -1):Void
	{
		if(radius < 0) radius = cornerRadius;
		var r:Int = Std.int(Math.max(1, Math.min(radius, Std.int(Math.min(width, height) / 2))));
		if(width < 2) width = 2;
		if(height < 2) height = 2;

		sprite.makeGraphic(width, height, FlxColor.WHITE);

		if(r > 0) _punchCorners(sprite, width, height, r);
	}

	/** Helper: make the four corners transparent via circle-mask pixel ops. */
	static function _punchCorners(sprite:FlxSprite, width:Int, height:Int, r:Int):Void
	{
		var bmd = sprite.pixels;
		if(bmd == null) return;
		var rsq:Float = r * r;

		// Clear the four corner squares
		bmd.fillRect(new Rectangle(0, 0, r, r), FlxColor.TRANSPARENT);
		bmd.fillRect(new Rectangle(width - r, 0, r, r), FlxColor.TRANSPARENT);
		bmd.fillRect(new Rectangle(0, height - r, r, r), FlxColor.TRANSPARENT);
		bmd.fillRect(new Rectangle(width - r, height - r, r, r), FlxColor.TRANSPARENT);

		// Fill back pixels that are inside the circle radius (the "rounded" part)
		for(px in 0...r)
		{
			for(py in 0...r)
			{
				var dx:Float = (px + 0.5) - r;
				var dy:Float = (py + 0.5) - r;
				if(dx * dx + dy * dy <= rsq)
				{
					bmd.setPixel32(px, py, 0xFFFFFFFF);
					bmd.setPixel32(width - 1 - px, py, 0xFFFFFFFF);
					bmd.setPixel32(px, height - 1 - py, 0xFFFFFFFF);
					bmd.setPixel32(width - 1 - px, height - 1 - py, 0xFFFFFFFF);
				}
			}
		}

		sprite.pixels = bmd;
	}
}
