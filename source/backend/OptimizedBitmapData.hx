package backend;

import lime.graphics.Image;
import openfl.display.BitmapData;
import openfl.geom.Rectangle;
import flixel.FlxG;

// GPU-only BitmapData: uploads to GL then drops the CPU image.
// Based on Codename Engine's OptimizedBitmapData (https://github.com/CodenameCrew/CodenameEngine).
// Usage: fromBitmapData(decoded) -> uploads; dispose the original afterwards.
class OptimizedBitmapData extends BitmapData
{
	public static function fromBitmapData(bitmap:BitmapData):OptimizedBitmapData
	{
		if (bitmap == null || bitmap.image == null || bitmap.image.buffer == null)
			return null;

		try
		{
			var opt = new OptimizedBitmapData(0, 0, true, 0);
			opt.__fromImage(bitmap.image);
			return opt;
		}
		catch (e:Dynamic)
		{
			return null;
		}
	}

	@:noCompletion private override function __fromImage(image:#if lime Image #else Dynamic #end):Void
	{
		#if lime
		if (image != null && image.buffer != null)
		{
			this.image = image;

			width = image.width;
			height = image.height;
			rect = new Rectangle(0, 0, image.width, image.height);

			#if sys
			image.format = BGRA32;
			image.premultiplied = true;
			#end

			__isValid = true;
			readable = true;

			if (FlxG.stage != null && FlxG.stage.context3D != null)
			{
				getTexture(FlxG.stage.context3D);
				// do NOT call getSurface() — its zero-copy Cairo surface keeps the pixels alive
				this.image = null;
			}
		}
		#end
	}
}
