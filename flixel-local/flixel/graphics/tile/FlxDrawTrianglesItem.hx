package flixel.graphics.tile;

import flixel.FlxCamera;
import flixel.graphics.frames.FlxFrame;
import flixel.graphics.tile.FlxDrawBaseItem.FlxDrawItemType;
import flixel.math.FlxMatrix;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.util.FlxColor;
import openfl.display.Graphics;
import openfl.display.TriangleCulling;
import openfl.geom.ColorTransform;

typedef DrawData<T> = #if (flash || openfl >= "4.0.0") openfl.Vector<T> #else Array<T> #end;

/**
 * @author Zaphod
 */
class FlxDrawTrianglesItem extends FlxDrawBaseItem<FlxDrawTrianglesItem>
{
	static var point:FlxPoint = FlxPoint.get();
	static var rect:FlxRect = FlxRect.get();

	public var vertices:DrawData<Float> = new DrawData<Float>();
	public var indices:DrawData<Int> = new DrawData<Int>();
	public var uvtData:DrawData<Float> = new DrawData<Float>();
	public var colors:DrawData<Int> = new DrawData<Int>();

	public var verticesPosition:Int = 0;
	public var indicesPosition:Int = 0;
	public var colorsPosition:Int = 0;

	var bounds:FlxRect = FlxRect.get();

	public function new()
	{
		super();
		type = FlxDrawItemType.TRIANGLES;
	}

	override public function render(camera:FlxCamera):Void
	{
		if (!FlxG.renderTile)
			return;

		if (numTriangles <= 0)
			return;

		camera.canvas.graphics.beginBitmapFill(graphics.bitmap, null, true, (camera.antialiasing || antialiasing));
		#if !openfl_legacy
		camera.canvas.graphics.drawTriangles(vertices, indices, uvtData, TriangleCulling.NONE);
		#else
		camera.canvas.graphics.drawTriangles(vertices, indices, uvtData, TriangleCulling.NONE, (colored) ? colors : null, blending);
		#end
		camera.canvas.graphics.endFill();
		#if FLX_DEBUG
		if (FlxG.debugger.drawDebug)
		{
			var gfx:Graphics = camera.debugLayer.graphics;
			gfx.lineStyle(1, FlxColor.BLUE, 0.5);
			gfx.drawTriangles(vertices, indices);
		}
		#end

		super.render(camera);
	}

	override public function reset():Void
	{
		super.reset();
		verticesPosition = 0;
		indicesPosition = 0;
		colorsPosition = 0;
	}

	override public function dispose():Void
	{
		super.dispose();

		vertices = null;
		indices = null;
		uvtData = null;
		colors = null;
		bounds = null;
	}

	public function addTriangles(vertices:DrawData<Float>, indices:DrawData<Int>, uvtData:DrawData<Float>, ?colors:DrawData<Int>, ?position:FlxPoint,
			?cameraBounds:FlxRect):Void
	{
		if (position == null)
			position = point.set();

		if (cameraBounds == null)
			cameraBounds = rect.set(0, 0, FlxG.width, FlxG.height);

		var verticesLength:Int = vertices.length;
		var prevVerticesLength:Int = this.vertices.length;
		var numberOfVertices:Int = verticesLength >> 1;
		var prevIndicesLength:Int = this.indices.length;
		var prevUVTDataLength:Int = this.uvtData.length;
		var prevColorsLength:Int = this.colors.length;
		var prevNumberOfVertices:Int = prevVerticesLength >> 1;

		var tempX:Float, tempY:Float;
		var i:Int = 0;

		// Compute bounds first to cull invisible batches without mutating arrays
		var firstX = position.x + vertices[0];
		var firstY = position.y + vertices[1];
		bounds.set(firstX, firstY, 0, 0);
		i = 2;
		while (i < verticesLength)
		{
			tempX = position.x + vertices[i];
			tempY = position.y + vertices[i + 1];
			inflateBounds(bounds, tempX, tempY);
			i += 2;
		}

		if (!cameraBounds.overlaps(bounds))
		{
			// skip - batch is off-screen
		}
		else
		{
			var currentVertexPosition:Int = prevVerticesLength;
			i = 0;
			while (i < verticesLength)
			{
				this.vertices[currentVertexPosition++] = position.x + vertices[i];
				this.vertices[currentVertexPosition++] = position.y + vertices[i + 1];
				i += 2;
			}
			var uvtDataLength:Int = uvtData.length;
			for (i in 0...uvtDataLength)
			{
				this.uvtData[prevUVTDataLength + i] = uvtData[i];
			}

			var indicesLength:Int = indices.length;
			for (i in 0...indicesLength)
			{
				this.indices[prevIndicesLength + i] = indices[i] + prevNumberOfVertices;
			}

			if (colored)
			{
				for (i in 0...numberOfVertices)
				{
					this.colors[prevColorsLength + i] = colors[i];
				}

				colorsPosition += numberOfVertices;
			}

			verticesPosition += verticesLength;
			indicesPosition += indicesLength;
		}

		position.putWeak();
		cameraBounds.putWeak();
	}

	public static inline function inflateBounds(bounds:FlxRect, x:Float, y:Float):FlxRect
	{
		if (x < bounds.x)
		{
			bounds.width += bounds.x - x;
			bounds.x = x;
		}

		if (y < bounds.y)
		{
			bounds.height += bounds.y - y;
			bounds.y = y;
		}

		if (x > bounds.x + bounds.width)
		{
			bounds.width = x - bounds.x;
		}

		if (y > bounds.y + bounds.height)
		{
			bounds.height = y - bounds.y;
		}

		return bounds;
	}

	override public function addQuad(frame:FlxFrame, matrix:FlxMatrix, ?transform:ColorTransform):Void
	{
		var prevVerticesPos:Int = verticesPosition;
		var prevIndicesPos:Int = indicesPosition;
		var prevColorsPos:Int = colorsPosition;
		var prevNumberOfVertices:Int = verticesPosition >> 1;

		var fw = frame.frame.width;
		var fh = frame.frame.height;
		var a = matrix.a, b = matrix.b, c = matrix.c, d = matrix.d;
		var tx = matrix.tx, ty = matrix.ty;

		// (0,0) * matrix
		vertices[prevVerticesPos] = tx;
		vertices[prevVerticesPos + 1] = ty;

		uvtData[prevVerticesPos] = frame.uv.x;
		uvtData[prevVerticesPos + 1] = frame.uv.y;

		// (fw, 0) * matrix
		vertices[prevVerticesPos + 2] = a * fw + tx;
		vertices[prevVerticesPos + 3] = b * fw + ty;

		uvtData[prevVerticesPos + 2] = frame.uv.width;
		uvtData[prevVerticesPos + 3] = frame.uv.y;

		// (fw, fh) * matrix
		vertices[prevVerticesPos + 4] = a * fw + c * fh + tx;
		vertices[prevVerticesPos + 5] = b * fw + d * fh + ty;

		uvtData[prevVerticesPos + 4] = frame.uv.width;
		uvtData[prevVerticesPos + 5] = frame.uv.height;

		// (0, fh) * matrix
		vertices[prevVerticesPos + 6] = c * fh + tx;
		vertices[prevVerticesPos + 7] = d * fh + ty;

		uvtData[prevVerticesPos + 6] = frame.uv.x;
		uvtData[prevVerticesPos + 7] = frame.uv.height;

		indices[prevIndicesPos] = prevNumberOfVertices;
		indices[prevIndicesPos + 1] = prevNumberOfVertices + 1;
		indices[prevIndicesPos + 2] = prevNumberOfVertices + 2;
		indices[prevIndicesPos + 3] = prevNumberOfVertices + 2;
		indices[prevIndicesPos + 4] = prevNumberOfVertices + 3;
		indices[prevIndicesPos + 5] = prevNumberOfVertices;

		if (colored)
		{
			var color:FlxColor;
			if (transform != null)
			{
				#if !neko
				color = FlxColor.fromRGBFloat(transform.redMultiplier, transform.greenMultiplier, transform.blueMultiplier, transform.alphaMultiplier);
				#else
				color = FlxColor.fromRGBFloat(transform.redMultiplier, transform.greenMultiplier, transform.blueMultiplier, 1.0);
				#end
			}
			else
			{
				color = FlxColor.WHITE;
			}

			colors[prevColorsPos] = color;
			colors[prevColorsPos + 1] = color;
			colors[prevColorsPos + 2] = color;
			colors[prevColorsPos + 3] = color;

			colorsPosition += 4;
		}

		verticesPosition += 8;
		indicesPosition += 6;
	}

	override function get_numVertices():Int
	{
		return vertices.length >> 1;
	}

	override function get_numTriangles():Int
	{
		return Std.int(indices.length / 3);
	}
}
