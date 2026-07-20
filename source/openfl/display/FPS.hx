package openfl.display;

import flixel.FlxG;
import flixel.math.FlxMath;
import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.system.System;
import openfl.text.Font;
import openfl.text.TextField;
import openfl.text.TextFieldAutoSize;
import openfl.text.TextFormat;
import openfl.text.TextFormatAlign;
import openfl.geom.Matrix;
import states.MainMenuState;
#if gl_stats
import openfl.display._internal.stats.Context3DStats;
import openfl.display._internal.stats.DrawCallContext;
#end
#if flash
import openfl.Lib;
#end

#if !openfl_debug
@:fileXml('tags="haxe,release"')
@:noDebug
#end
class FPS extends Sprite
{
	public var currentFPS(default, null):Int;

	private var cacheCount:Int;
	private var currentTime:Float;
	private var times:Array<Float>;
	private var maxMemory:Float = 0;
	private var dataFont:Font;
	private var fpsHistory:Array<Float>;
	private var memHistory:Array<Float>;
	private var memChartCeil:Float = 100;
	private var sampleAccum:Float = 0;

	private static inline var P:Float = 10;
	private static inline var CH_W:Float = 280;
	private static inline var CH_H:Float = 52;
	private static inline var INTERVALS:Int = 6;
	private static inline var LABEL_W:Float = 40;
	private static inline var SAMPLE_MS:Float = 25;
	private static inline var HISTORY_MAX:Int = 10;

	var mode:Int = 0;
	var baseColor:Int;

	var fpsNum:TextField;
	var fpsLbl:TextField;
	var memPre:TextField;
	var memNum:TextField;
	var memUnit:TextField;
	var memMax:TextField;
	var verText:TextField;
	var dcText:TextField;

	var fpsChart:Shape;
	var memChart:Shape;
	var div1:Shape;
	var div2:Shape;
	var fpsCVal:TextField;
	var memCVal:TextField;

	var fpsYLab:Array<TextField>;
	var memYLab:Array<TextField>;

	var _lastFPS:Int = -1;
	var _lastMem:Float = -1;
	var _lastColor:Int = -1;
	var _lastMode:Int = -1;

	public function new(x:Float = 10, y:Float = 10, color:Int = 0xFFFFFF)
	{
		super();

		this.x = x;
		this.y = y;
		this.baseColor = color;

		dataFont = new Font("assets/fonts/vcrcn.ttf");

		currentFPS = 0;
		mouseEnabled = false;
		mouseChildren = false;

		cacheCount = 0;
		currentTime = 0;
		times = [];
		fpsHistory = [];
		memHistory = [];

		fpsNum   = mkField();
		fpsLbl   = mkField();
		memPre   = mkField();
		memNum   = mkField();
		memUnit  = mkField();
		memMax   = mkField();
		verText  = mkField();
		dcText   = mkField();

		fpsChart = new Shape();
		memChart = new Shape();
		div1 = new Shape();
		div2 = new Shape();
		addChild(fpsChart);
		addChild(memChart);
		addChild(div1);
		addChild(div2);

		fpsCVal = mkField();
		memCVal = mkField();

		fpsYLab = [for (i in 0...4) mkField()];
		memYLab = [for (i in 0...4) mkField()];

		#if flash
		addEventListener(Event.ENTER_FRAME, function(e) {
			var time = Lib.getTimer();
			__enterFrame(time - currentTime);
		});
		#end
	}

	function mkField():TextField
	{
		var tf = new TextField();
		tf.selectable = false;
		tf.mouseEnabled = false;
		tf.autoSize = TextFieldAutoSize.LEFT;
		addChild(tf);
		return tf;
	}

	private #if !flash override #end function __enterFrame(deltaTime:Float):Void
	{
		if (FlxG.keys.justPressed.F3)
		{
			mode = (mode + 1) % 3;
			if (mode == 2)
			{
				visible = false;
				ClientPrefs.data.showFPS = false;
			}
			else
			{
				visible = true;
				ClientPrefs.data.showFPS = true;
			}
		}

		currentTime += deltaTime;
		times.push(currentTime);
		while (times[0] < currentTime - 1000)
			times.shift();

		var nowFPS = times.length;
		if (nowFPS > ClientPrefs.data.framerate) nowFPS = ClientPrefs.data.framerate;
		currentFPS = nowFPS;

		sampleAccum += deltaTime;
		if (sampleAccum >= SAMPLE_MS)
		{
			sampleAccum = 0;
			fpsHistory.push(currentFPS);
			if (fpsHistory.length > HISTORY_MAX) fpsHistory.shift();

			var mem = Math.abs(FlxMath.roundDecimal(System.totalMemory / 1000000, 1));
			if (mem > maxMemory) maxMemory = mem;
			memHistory.push(mem);
			if (memHistory.length > HISTORY_MAX) memHistory.shift();

			if (visible) updateDisplay();
		}
	}

	function updateDisplay():Void
	{
		var mem = Math.abs(FlxMath.roundDecimal(System.totalMemory / 1000000, 1));
		var fn  = (dataFont != null && dataFont.fontName != null) ? dataFont.fontName : "_sans";

		var c = baseColor;
		if (mem > 3000 || currentFPS <= ClientPrefs.data.framerate / 2)
			c = 0xFF5555;
		else if (mem > 2000 || currentFPS <= ClientPrefs.data.framerate / 1.5)
			c = 0xFFB347;

		if (mode == 0)
			compact(fn, c, mem);
		else
			debug(fn, c, mem);

		drawBg();
	}

	function compact(fn:String, c:Int, mem:Float):Void
	{
		hideDebug();

		var mp = formatMemory(mem).split(" ");
		var y0 = P;

		setFmt(fpsNum,  fn, 15, c,         1.0, currentFPS + "", P, y0);
		setFmt(fpsLbl,  fn, 12, 0xAAAAAA,  0,   "FPS",  fpsNum.x + fpsNum.width + 7, y0 + 1);
		setFmt(memNum,  fn, 15, 0xDDDDDD,  1.0, mp[0],  fpsLbl.x + fpsLbl.width + 12, y0);
		setFmt(memUnit, fn, 12, 0xAAAAAA,  0,   mp[1],  memNum.x + memNum.width + 4, y0 + 1);

		setFmt(verText, fn, 10, 0x999999, 0, "v" + MainMenuState.seiunengineVersion,
			P, y0 + fpsNum.height + 2);
	}

	function debug(fn:String, c:Int, mem:Float):Void
	{
		var mp = formatMemory(mem).split(" ");
		var xp = formatMemory(maxMemory).split(" ");
		var ver = MainMenuState.seiunengineVersion;

		var r1y = P;
		setFmt(fpsNum, fn, 24, c,        1.2, currentFPS + "", P, r1y);
		setFmt(fpsLbl, fn, 14, 0xAAAAAA, 0,   "FPS",
			fpsNum.x + fpsNum.width + 10, r1y + 3);

		var r2y = r1y + fpsNum.height + 8;
		var r2off = r2y + 2;
		setFmt(memPre,  fn, 12, 0x888888, 0, "MEM", P, r2off);
		setFmt(memNum,  fn, 18, c,        1.2, mp[0], memPre.x + memPre.width + 5, r2y);
		setFmt(memUnit, fn, 12, 0xCCCCCC, 0,   mp[1], memNum.x + memNum.width + 5, r2off);
		setFmt(memMax,  fn, 12, 0x777777, 0,
			"/ max " + xp[0] + " " + xp[1], memUnit.x + memUnit.width + 7, r2off);

		var hdrBot = r2y + memNum.height;

		drawDiv(div1, hdrBot + 6, CH_W + LABEL_W);

		var chY = hdrBot + 12;
		fpsChart.visible = true;
		fpsChart.x = P + LABEL_W;
		fpsChart.y = chY;
		var fpsMax:Float = ClientPrefs.data.framerate;
		drawChart(fpsChart, fpsHistory, fpsMax, CH_W, CH_H, 0x44FF66, 0.9, true);
		layoutYLabels(fpsYLab, chY, ClientPrefs.data.framerate, fn, 0x44FF66);
		setFmt(fpsCVal, fn, 10, 0x44FF66, 0, currentFPS + " fps",
			P + LABEL_W + CH_W - 59, chY + 3);

		memChartCeil = computeCeil(memHistory);
		var mcy = chY + CH_H + 10;
		memChart.visible = true;
		memChart.x = P + LABEL_W;
		memChart.y = mcy;
		drawChart(memChart, memHistory, memChartCeil, CH_W, CH_H, 0xFFB347, 0.8, false);
		layoutYLabels(memYLab, mcy, memChartCeil, fn, 0xFFB347);
		setFmt(memCVal, fn, 10, 0xFFB347, 0, formatCompactMem(mem),
			P + LABEL_W + CH_W - 59, mcy + 3);

		var cBot = mcy + CH_H;
		drawDiv(div2, cBot + 6, CH_W + LABEL_W);

		var fy = cBot + 12;
		#if (gl_stats && !disable_cffi && (!html5 || !canvas))
		var dc = "DC tot:" + Context3DStats.totalDrawCalls()
			+ "  stg:" + Context3DStats.contextDrawCalls(DrawCallContext.STAGE)
			+ "  3D:" + Context3DStats.contextDrawCalls(DrawCallContext.STAGE3D);
		setFmt(dcText, fn, 11, 0x777777, 0, dc, P, fy);
		fy += dcText.height + 4;
		dcText.visible = true;
		#else
		dcText.visible = false;
		#end

		setFmt(verText, fn, 12, 0x999999, 0, "SeiunEngine v" + ver, P, fy);
	}

	function layoutYLabels(labels:Array<TextField>, chartY:Float, maxVal:Float,
			fn:String, col:Int):Void
	{
		var fracs:Array<Float> = [1.0, 2.0/3.0, 1.0/3.0, 0.0];
		for (i in 0...labels.length)
		{
			var val:Float = maxVal * fracs[i];
			var labelText:String;
			if (maxVal >= 100)
				labelText = Std.string(Math.round(val));
			else if (maxVal >= 10)
				labelText = FlxMath.roundDecimal(val, 1) + "";
			else
				labelText = FlxMath.roundDecimal(val, 2) + "";

			var tf = labels[i];
			tf.visible = true;
			tf.text = labelText;
			var f = new TextFormat(fn, 8, 0x777777);
			f.align = TextFormatAlign.RIGHT;
			tf.setTextFormat(f);
			tf.x = P + LABEL_W - tf.width - 4;
			var frac:Float = fracs[i];
			tf.y = chartY + CH_H * (1 - frac) - tf.height / 2;
		}
	}

	function hideDebug():Void
	{
		memPre.visible   = false;
		memMax.visible   = false;
		dcText.visible   = false;
		fpsChart.visible = false;
		memChart.visible = false;
		div1.visible     = false;
		div2.visible     = false;
		fpsCVal.visible  = false;
		memCVal.visible  = false;
		for (tf in fpsYLab) tf.visible = false;
		for (tf in memYLab) tf.visible = false;
	}

	function setFmt(tf:TextField, font:String, size:Int, color:Int,
			letter:Float, text:String, px:Float, py:Float):Void
	{
		var sameText = (tf.text == text && tf.x == px && tf.y == py);
		var sameSize = (tf.textWidth > 0 && Std.int(tf.getTextFormat().size) == size);
		if (!sameText || !tf.visible || !sameSize)
		{
			tf.visible = true;
			tf.text = text;
			var f = new TextFormat(font, size, color);
			if (letter > 0) f.letterSpacing = letter;
			tf.setTextFormat(f);
			tf.x = px;
			tf.y = py;
		}
	}

	function computeCeil(h:Array<Float>):Float
	{
		if (h.length == 0) return 100;
		var pk:Float = 0;
		var s:Int = h.length - 60;
		if (s < 0) s = 0;
		for (i in s...h.length)
			if (h[i] > pk) pk = h[i];
		var prop = Math.ceil(pk * 1.2 / 100) * 100;
		if (prop < 100) prop = 100;
		if (prop > memChartCeil) return prop;
		return FlxMath.lerp(memChartCeil, prop, 0.03);
	}

	function drawDiv(sh:Shape, y:Float, w:Float):Void
	{
		sh.visible = true;
		var g = sh.graphics;
		g.clear();
		g.lineStyle(1, 0xFFFFFF, 0.06);
		g.moveTo(P, y);
		g.lineTo(P + w, y);
	}

	function formatCompactMem(megas:Float):String
	{
		if (megas >= 1024) return FlxMath.roundDecimal(megas / 1024, 1) + "GB";
		return Math.round(megas) + "MB";
	}

	function drawBg():Void
	{
		graphics.clear();
		if (mode == 2) return;

		var w:Float, h:Float;

		if (mode == 1)
		{
			w = CH_W + LABEL_W + P * 2;
			var bot = verText.y + verText.height;
			if (dcText.visible) bot = max(bot, dcText.y + dcText.height);
			h = bot + P;
		}
		else
		{
			var right = P, bot = P;
			for (k in [fpsNum, fpsLbl, memNum, memUnit, verText])
			{
				if (!k.visible) continue;
				if (k.x + k.width > right) right = k.x + k.width;
				if (k.y + k.height > bot)   bot   = k.y + k.height;
			}
			w = right + P;
			h = bot + P;
		}

		graphics.beginFill(0x000000, 0.45);
		graphics.drawRoundRect(0, 0, w, h, 8, 8);
		graphics.endFill();
		graphics.lineStyle(1, 0xFFFFFF, 0.06);
		graphics.drawRoundRect(0, 0, w, h, 8, 8);
	}

	function formatMemory(megas:Float):String
	{
		if (megas >= 1024) return FlxMath.roundDecimal(megas / 1024, 2) + " GB";
		return megas + " MB";
	}

	function getColorForFPS(fps:Float, maxFPS:Float):Int
	{
		var t = fps / maxFPS;
		if (t >= 0.9) return 0x66FF66;
		if (t >= 0.7) return 0xCCFF66;
		if (t >= 0.5) return 0xFFDD44;
		if (t >= 0.3) return 0xFF8844;
		return 0xFF4444;
	}

	function drawChart(sh:Shape, data:Array<Float>, maxV:Float,
			w:Float, h:Float, col:Int, alpha:Float, dynamicColor:Bool = false):Void
	{
		var gfx = sh.graphics;
		gfx.clear();
		var len = data.length;
		if (len < 2) return;
		var rng = maxV;
		if (rng <= 0) rng = 1;

		for (k in 0...(INTERVALS + 1))
		{
			var frac:Float = k / INTERVALS;
			var gy = h * (1 - frac);
			gfx.lineStyle(1, 0xFFFFFF, 0.04);
			gfx.moveTo(0, gy);
			gfx.lineTo(w, gy);
		}

		gfx.lineStyle(1, 0xFFFFFF, 0.08);
		gfx.drawRect(0, 0, w, h);

		var points:Array<{x:Float, y:Float}> = [];
		for (i in 0...len)
		{
			var x = (i / (len - 1)) * w;
			var y = h - (data[i] / rng) * h;
			if (y < 0.5) y = 0.5;
			if (y > h) y = h;
			points.push({x: x, y: y});
		}

		var fillCol = col;
		if (dynamicColor)
		{
			var latestFPS = data[len - 1];
			var maxFPS = ClientPrefs.data.framerate;
			fillCol = getColorForFPS(latestFPS, maxFPS);
		}

		var matrix = new Matrix();
		matrix.createGradientBox(w, h, Math.PI / 2, 0, 0);
		gfx.beginGradientFill(openfl.display.GradientType.LINEAR,
			[fillCol, fillCol], [0.45, 0.05], [0, 255], matrix);
		gfx.moveTo(points[0].x, points[0].y);
		for (i in 1...len)
			gfx.lineTo(points[i].x, points[i].y);
		gfx.lineTo(w, h);
		gfx.lineTo(0, h);
		gfx.endFill();

		if (dynamicColor)
		{
			var maxFPS:Float = ClientPrefs.data.framerate;
			for (i in 0...(len - 1))
			{
				var avg = (data[i] + data[i+1]) / 2;
				var lineCol = getColorForFPS(avg, maxFPS);
				gfx.lineStyle(3, lineCol, alpha);
				gfx.moveTo(points[i].x, points[i].y);
				gfx.lineTo(points[i+1].x, points[i+1].y);
			}
		}
		else
		{
			gfx.lineStyle(3, col, alpha);
			gfx.moveTo(points[0].x, points[0].y);
			for (i in 1...len)
				gfx.lineTo(points[i].x, points[i].y);
		}
	}

	static inline function max(a:Float, b:Float):Float { return a > b ? a : b; }
}