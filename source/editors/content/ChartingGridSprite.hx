package editors.content;

import flixel.addons.display.FlxGridOverlay;
import openfl.display.BitmapData;
import openfl.geom.Matrix;
import openfl.geom.Rectangle;

// Laggier than a single sprite for the grid, but this is to avoid having to re-create the sprite constantly
class ChartingGridSprite extends FlxSprite
{
	public var rows(default, set):Float = 16;
	public var columns(default, null):Int = 0;
	public var spacing(default, set):Int = 0;
	public var stripe:FlxSprite;
	public var stripes:Array<Int>;
	/** 网格单格像素宽 (多k: 随键数缩放, 默认沿用旧版编辑器 40)。 */
	public var gridSize:Int = 40;
	/** 首列 (事件列) 固定宽度; 0 = 所有列等宽。 */
	public var firstColWidth:Int = 0;

	var vortexLine:FlxSprite;
	public var vortexLineEnabled:Bool = false;
	public var vortexLineSpace:Float = 0;

	public function new(columns:Int, ?color1:FlxColor = 0xFFE6E6E6, ?color2:FlxColor = 0xFFD8D8D8, ?gridSize:Int = 0, ?firstColWidth:Int = 0)
	{
		super();
		this.columns = columns;
		this.gridSize = (gridSize > 0) ? gridSize : ChartingState.GRID_SIZE;
		this.firstColWidth = (firstColWidth > 0) ? firstColWidth : 0;
		scrollFactor.x = 0;
		active = false;

		// 宽度由图形像素决定 (事件列可能不等宽), 高度仍按 gridSize 缩放
		scale.set(1, this.gridSize);
		loadGrid(color1, color2);
		updateHitbox();
		recalcHeight();

		vortexLine = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);
		vortexLine.scale.x = this.width;
		vortexLine.scrollFactor.x = 0;
		vortexLine.color = 0xFF660000;
		vortexLine.updateHitbox();

		stripe = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);
		stripe.scrollFactor.x = 0;
		stripe.color = FlxColor.BLACK;
		updateStripes();
	}

	public function loadGrid(color1:FlxColor, color2:FlxColor)
	{
		var bmp:BitmapData;
		if (firstColWidth > 0)
		{
			// 首列固定宽 + 其余列 gridSize 宽, 拼成一张 2 行网格图
			var totalW:Int = firstColWidth + (columns - 1) * gridSize;
			bmp = new BitmapData(totalW, 2, false, color2);
			// 注意: createGrid(CellW, CellH, TotalW, TotalH, ...) 的宽高是像素总数
			var first:BitmapData = FlxGridOverlay.createGrid(firstColWidth, 1, firstColWidth, 2, true, color2, color1);
			bmp.draw(first, null, null, null, null, true);
			var rest:BitmapData = FlxGridOverlay.createGrid(gridSize, 1, gridSize * (columns - 1), 2, true, color1, color2);
			var mtx:Matrix = new Matrix(1, 0, 0, 1, firstColWidth, 0);
			bmp.draw(rest, mtx, null, null, null, true);
		}
		else
		{
			bmp = FlxGridOverlay.createGrid(gridSize, 1, gridSize * columns, 2, true, color1, color2);
		}
		loadGraphic(bmp, true, bmp.width, 1);
		animation.add('odd', [0], false);
		animation.add('even', [1], false);
		animation.play('even', true);
		updateHitbox();
		recalcHeight();
	}

	override function draw()
	{
		if(!visible || alpha == 0 || y - camera.scroll.y >= FlxG.height) return;
		scale.y = gridSize * Math.min(1, rows);
		offset.y = -0.5 * (scale.y - 1);

		super.draw();
		if(rows <= 1)
		{
			_drawStripes();
			return;
		}

		var initialY:Float = y;
		for (i in 1...Math.ceil(rows))
		{
			y += gridSize + spacing;
			if(y - camera.scroll.y >= FlxG.height)
				break;

			animation.play((i % 2 == 1) ? 'odd' : 'even', true);
			scale.y = gridSize * Math.min(1, rows - i);
			offset.y = -0.5 * (scale.y - 1);
			super.draw();
		}
		animation.play('even', true);
		y = initialY;

		_drawStripes();

		if(vortexLineEnabled)
		{
			vortexLine.x = this.x;
			vortexLine.y = this.y - 1;
			while (true)
			{
				vortexLine.y += vortexLineSpace;
				if(vortexLine.y >= this.y + this.height) break;

				vortexLine.draw();
			}
		}
	}

	function _drawStripes()
	{
		for (i => column in stripes)
		{
			var sx:Float = this.x;
			if (column > 0)
				sx = (firstColWidth > 0) ? (this.x + firstColWidth + (column - 1) * gridSize) : (this.x + gridSize * column);
			stripe.x = sx - stripe.width/2;
			stripe.draw();
		}
	}

	public function updateStripes()
	{
		if(stripe == null || !stripe.exists) return;
		stripe.y = this.y;
		stripe.setGraphicSize(2, Std.int(this.height));
		stripe.updateHitbox();
	}

	function set_rows(v:Float)
	{
		rows = v;
		recalcHeight();
		return rows;
	}

	function set_spacing(v:Int)
	{
		spacing = v;
		recalcHeight();
		return spacing;
	}

	function recalcHeight()
	{
		height = ((gridSize + spacing) * rows) - spacing;
		updateStripes();
	}
}
