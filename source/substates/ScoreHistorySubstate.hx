package substates;

import states.FreeplayState;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.math.FlxMath;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.util.FlxTimer;
import flixel.util.FlxSpriteUtil;
import states.LoadingState;
import states.PlayState;
import ClientPrefs;
import Highscore;
import Allscore;
import Replay;
import Song;
#if sys
import sys.FileSystem;
#end
import openfl.display.BitmapData;
import openfl.display.Shape;
import openfl.geom.Rectangle;
import mohong.TraceManager;
import CoolUtil;
import SUtil;

class ScoreHistorySubstate extends MusicBeatSubstate
{
	var bg:FlxSprite;
	var titleTxt:FlxText;
	var titleUnderline:FlxSprite;

	var dateListGroup:FlxTypedGroup<FlxText>;
	var dateListBG:FlxSprite;
	var selector:FlxSprite;

	var detailGroup:FlxTypedGroup<FlxText>;
	var detailBG:FlxSprite;

	var graphBG:FlxSprite;
	var graphNote:FlxSprite;

	var entries:Array<ScoreEntry> = [];
	var curSelected:Int = 0;
	var songName:String;
	var difficulty:Int;

	var scrollOffset:Float = 0;
	var itemHeight:Float = 40;
	var listStartY:Float = 160;
	var listVisibleHeight:Float = 400;

	var isEmpty:Bool = false;
	var emptyMsg:FlxText;

	var displayedScore:Int = 0;
	var targetScore:Int = 0;
	var displayedAccuracy:Float = 0;
	var targetAccuracy:Float = 0;
	var scoreText:FlxText;
	var accuracyText:FlxText;

	var lastSelected:Int = -1;

	var accentColor:FlxColor = FlxColor.fromRGB(0, 200, 220);
	var panelColor:FlxColor = FlxColor.fromRGB(15, 30, 40);
	var detailPanelColor:FlxColor = FlxColor.fromRGB(25, 40, 50);

	var scoreAnimCompleted:Bool = false;
	var ratingIcon:FlxSprite;
	var ratingIconTween:FlxTween;

	public function new(songName:String, difficulty:Int)
	{
		super();

		bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.alpha = 0.85;
		add(bg);

		this.songName = songName;
		this.difficulty = difficulty;
		try
		{
			// getHistory 现在只读对应歌曲/难度子目录, 无需全量扫描
			entries = Allscore.getHistory(songName, difficulty);
		}
		catch(e:Dynamic)
		{
			TraceManager.error('trace.scoreHistory.loadHistory', 'ScoreHistorySubstate - Failed to load history: {}', [e]);
			entries = [];
		}
		if (entries == null) entries = [];

		titleTxt = new FlxText(0, 25, FlxG.width, Language.get("ScoreHistorySubstate.title", "HISTORY"), 36);
		titleTxt.setFormat(Paths.languageFont(), 36, FlxColor.WHITE, CENTER);
		titleTxt.alpha = 0;
		add(titleTxt);

		var subtitleTxt = new FlxText(0, 65, FlxG.width, songName + " - " + CoolUtil.difficultyString(), 18);
		subtitleTxt.setFormat(Paths.languageFont(), 18, FlxColor.GRAY, CENTER);
		subtitleTxt.alpha = 0;
		add(subtitleTxt);

		titleUnderline = new FlxSprite().makeGraphic(240, 3, accentColor);
		titleUnderline.screenCenter(X);
		titleUnderline.y = 100;
		titleUnderline.scale.x = 0;
		add(titleUnderline);

		// dateListBG: 400x440, detailBG: 820x260, graphBG: 820x160
		dateListBG = createRoundedPanel(20, 130, 400, 440, panelColor);
		add(dateListBG);
		detailBG = createRoundedPanel(440, 130, 820, 260, detailPanelColor);
		add(detailBG);
		graphBG = createRoundedPanel(440, 410, 820, 160, panelColor);
		add(graphBG);

		dateListGroup = new FlxTypedGroup<FlxText>();
		add(dateListGroup);
		detailGroup = new FlxTypedGroup<FlxText>();
		add(detailGroup);

		selector = new FlxSprite().makeGraphic(370, 36, FlxColor.fromRGBFloat(0/255, 200/255, 220/255, 0.3));
		selector.visible = false;
		add(selector);

		// graphNote: 800x140 inside 820x160 panel (10px padding)
		graphNote = new FlxSprite(450, 420).makeGraphic(800, 140, FlxColor.TRANSPARENT);
		graphNote.alpha = 0;
		add(graphNote);

		ratingIcon = new FlxSprite();
		ratingIcon.visible = false;
		ratingIcon.alpha = 0;
		add(ratingIcon);

		var instructionsTxt = new FlxText(0, FlxG.height - 60, FlxG.width,
			Language.get("ScoreHistorySubstate.instructions", "UP/DOWN: Select  |  ENTER: Play  |  RESET: Delete  |  ESC: Back"), 14);
		instructionsTxt.setFormat(Paths.languageFont(), 14, FlxColor.GRAY, CENTER);
		instructionsTxt.alpha = 0;
		add(instructionsTxt);

		#if android
		addVirtualPad(LEFT_FULL, SCORE_HISTORY_SUBSTATE);
		addPadCamera();
		#end

		refreshList();

		// -- Modern jelly entrance --
		titleTxt.scale.set(0.82, 0.82);
		FlxTween.tween(titleTxt, {alpha: 1}, 0.35, {ease: FlxEase.sineOut});
		FlxTween.tween(titleTxt.scale, {x: 1, y: 1}, 0.6, {ease: FlxEase.backOut});

		FlxTween.tween(subtitleTxt, {alpha: 1}, 0.4, {ease: FlxEase.quartOut, startDelay: 0.1});
		FlxTween.tween(titleUnderline.scale, {x: 1}, 0.5, {ease: FlxEase.quartOut, startDelay: 0.2});

		jellyPopIn(dateListBG, 0.15);
		jellyPopIn(detailBG, 0.2);
		jellyPopIn(graphBG, 0.25);

		FlxTween.tween(graphNote, {alpha: 1}, 0.5, {ease: FlxEase.quartOut, startDelay: 0.35});
		FlxTween.tween(instructionsTxt, {alpha: 1}, 0.4, {ease: FlxEase.quartOut, startDelay: 0.3});
	}

	/** Jelly pop-in for panels (spring scale + fade). */
	function jellyPopIn(spr:FlxSprite, delay:Float):Void
	{
		spr.scale.set(0.85, 0.85);
		FlxTween.tween(spr.scale, {x: 1, y: 1}, 0.5, {ease: FlxEase.backOut, startDelay: delay});
	}

	function createRoundedPanel(x:Float, y:Float, width:Int, height:Int, color:FlxColor):FlxSprite
	{
		#if android
		// 部分安卓设备上 FlxSpriteUtil.drawRoundRect 配合透明背景会导致崩溃，使用纯色矩形替代
		var panel = new FlxSprite(x, y).makeGraphic(width, height, color);
		#else
		var panel = new FlxSprite(x, y).makeGraphic(width, height, FlxColor.TRANSPARENT);
		FlxSpriteUtil.drawRoundRect(panel, 0, 0, width, height, 16, 16, color, {thickness: 0, color: FlxColor.TRANSPARENT});
		#end
		panel.alpha = 0.6;
		return panel;
	}

	override function create()
	{
		super.create();
	}

	function getRatingIconName(entry:ScoreEntry):String
	{
		if (entry == null) return "FALSE";

		var totalNotes:Float = entry.sicks + entry.goods + entry.bads + entry.shits + entry.misses;

		if (totalNotes <= 0)
			return "FALSE";

		var accuracy:Float = entry.ratingPercent;

		if (accuracy >= 1.0)
			return "phi";

		if (accuracy >= 0.95 && entry.misses == 0 && entry.bads == 0 && entry.shits == 0)
			return "fc v";

		if (accuracy >= 0.95 && entry.misses == 0)
			return "v";

		if (accuracy >= 0.9)
			return "v";

		if (accuracy >= 0.8)
			return "s";

		if (accuracy >= 0.7)
			return "a";

		if (accuracy >= 0.6)
			return "b";

		if (accuracy >= 0.4)
			return "c";

		if (accuracy >= 0.2)
			return "f";

		return "false";
	}

	function showRatingIcon(entry:ScoreEntry)
	{
		if (ratingIconTween != null)
			ratingIconTween.cancel();

		try
		{
			var iconName = getRatingIconName(entry);
			var iconPath = 'assets/images/freeplayr/$iconName.png';

			if (Paths.fileExists('images/freeplayr/$iconName.png', IMAGE))
				ratingIcon.loadGraphic(Paths.image('freeplayr/$iconName'));
			else
				ratingIcon.loadGraphic(Paths.image('freeplayr/FALSE'));

			ratingIcon.setGraphicSize(Std.int(ratingIcon.width * 0.5));
			ratingIcon.updateHitbox();
		}
		catch(e:Dynamic)
		{
			TraceManager.error('trace.scoreHistory.loadRatingIcon', 'ScoreHistorySubstate - Failed to load rating icon: {}', [e]);
			ratingIcon.visible = false;
			return;
		}
		ratingIcon.x = detailBG.x + detailBG.width - ratingIcon.width - 40;
		ratingIcon.y = FlxG.height + ratingIcon.height;
		ratingIcon.visible = true;
		ratingIcon.alpha = 1;

		ratingIconTween = FlxTween.tween(ratingIcon, {y: detailBG.y + detailBG.height - ratingIcon.height - 20}, 0.6, {
			ease: FlxEase.backOut,
			onComplete: function(_) {
				ratingIconTween = null;
			}
		});
	}

	function hideRatingIcon()
	{
		if (ratingIconTween != null)
			ratingIconTween.cancel();

		ratingIconTween = FlxTween.tween(ratingIcon, {alpha: 0, y: FlxG.height + ratingIcon.height}, 0.3, {
			ease: FlxEase.quadIn,
			onComplete: function(_) {
				ratingIcon.visible = false;
				ratingIconTween = null;
			}
		});
	}

	function refreshList()
	{
		dateListGroup.clear();
		detailGroup.clear();

		if (emptyMsg != null)
		{
			remove(emptyMsg);
			emptyMsg = null;
		}

		isEmpty = (entries.length == 0);

		if (isEmpty)
		{
			emptyMsg = new FlxText(0, 280, FlxG.width, Language.get("ScoreHistorySubstate.emptyMsg", "No recorded scores yet"), 20);
			emptyMsg.setFormat(Paths.languageFont(), 20, FlxColor.GRAY, CENTER);
			emptyMsg.alpha = 0;
			add(emptyMsg);
			FlxTween.tween(emptyMsg, {alpha: 1}, 0.3);
			selector.visible = false;
			hideRatingIcon();
			graphNote.alpha = 0;
			return;
		}

		for (i in 0...entries.length)
		{
			var e = entries[i];
			var dateParts = e.date.split(" ");
			var dateStr = dateParts.length > 1 ? dateParts[0] : e.date;
			var timeStr = dateParts.length > 1 ? dateParts[1] : "";
			var fullText = dateStr + "  " + timeStr + "  -  " + e.score + "pts";

			var dateText = new FlxText(40, 0, 360, fullText, 16);
			dateText.setFormat(Paths.languageFont(), 16, (i == curSelected) ? FlxColor.WHITE : FlxColor.fromRGB(180, 200, 210), LEFT);
			dateText.alpha = 0;
			dateListGroup.add(dateText);
		}

		scrollOffset = 0;
		updateListPositions();
		adjustScrollToSelected();
		updateSelectorPosition();
		updateDetails();

		for (i in 0...dateListGroup.members.length)
		{
			var item = dateListGroup.members[i];
			item.alpha = 0;
			item.x -= 8;
			FlxTween.tween(item, {x: item.x + 8, alpha: 1}, 0.28, {startDelay: i * 0.04, ease: FlxEase.sineOut});
		}
	}

	function updateListPositions()
	{
		if (isEmpty) return;
		var i = 0;
		for (text in dateListGroup.members)
		{
			text.y = listStartY + i * itemHeight - scrollOffset;
			i++;
		}
	}

	function adjustScrollToSelected()
	{
		if (isEmpty) return;

		var selectedY = listStartY + curSelected * itemHeight - scrollOffset;
		var minY = listStartY;
		var maxY = listStartY + listVisibleHeight - itemHeight;

		if (selectedY < minY)
			scrollOffset = listStartY + curSelected * itemHeight - minY;
		else if (selectedY > maxY)
			scrollOffset = listStartY + curSelected * itemHeight - maxY;

		var maxScroll = Math.max(0, entries.length * itemHeight - listVisibleHeight);
		scrollOffset = FlxMath.bound(scrollOffset, 0, maxScroll);

		for (i in 0...dateListGroup.members.length)
			dateListGroup.members[i].y = listStartY + i * itemHeight - scrollOffset;
	}

	function updateSelectorPosition()
	{
		if (isEmpty || curSelected < 0 || curSelected >= entries.length)
		{
			selector.visible = false;
			return;
		}

		var targetY = listStartY + curSelected * itemHeight - scrollOffset + 2;
		selector.y = FlxMath.lerp(selector.y, targetY, 0.3);
		selector.x = 30;
		selector.visible = true;
	}

	function updateSelectionColors()
	{
		if (isEmpty) return;
		for (i in 0...dateListGroup.members.length)
		{
			var item = dateListGroup.members[i];
			item.color = (i == curSelected) ? FlxColor.WHITE : FlxColor.fromRGB(180, 200, 210);
		}
	}

	function updateDetails()
	{
		detailGroup.clear();
		scoreAnimCompleted = false;
		hideRatingIcon();
		graphNote.alpha = 0;

		if (isEmpty || curSelected < 0 || curSelected >= entries.length) return;

		var e = entries[curSelected];
		var col1X:Float = 470;
		var col2X:Float = 900;
		var startY:Float = 148;
		var lineH:Float = 22;

		targetScore = e.score;
		targetAccuracy = (e.ratingPercent >= 0) ? e.ratingPercent * 100 : 0;
		if (lastSelected != curSelected)
		{
			displayedScore = 0;
			displayedAccuracy = 0;
		}

		// ---- Collect label/value pairs per column first (so we can measure label widths) ----
		var rows1:Array<{label:String, value:String, color:FlxColor, size:Int}> = [];
		var rows2:Array<{label:String, value:String, color:FlxColor, size:Int}> = [];

		function mk(label:String, value:String, color:FlxColor, ?size:Int = 17):{label:String, value:String, color:FlxColor, size:Int}
		{
			return {label: label, value: value, color: color, size: size};
		}

		// -- Left column --
		rows1.push(mk(Language.get("ScoreHistorySubstate.date", "Date"), e.date, FlxColor.WHITE));
		rows1.push(mk(Language.get("ScoreHistorySubstate.score", "Score"), Std.string(displayedScore), FlxColor.fromRGB(255, 215, 0), 20));
		rows1.push(mk(Language.get("ScoreHistorySubstate.accuracy", "Accuracy"), Highscore.floorDecimal(displayedAccuracy, 2) + '%', FlxColor.WHITE, 18));
		rows1.push(mk(Language.get("ScoreHistorySubstate.rating", "Grade"), e.ratingName, getGradeColor(e.ratingName)));
		rows1.push(mk(Language.get("ScoreHistorySubstate.songRating", "Song Rating"), e.ratingFC, FlxColor.WHITE));
		rows1.push(mk(Language.get("ScoreHistorySubstate.maxCombo", "Max Combo"), Std.string(e.maxCombo), FlxColor.WHITE));

		var hasReplay = Allscore.hasReplayData(e);
		rows1.push(mk(Language.get("ScoreHistorySubstate.replayData", "Replay"),
			hasReplay ? Language.get("ScoreHistorySubstate.replayDataYes", "Available") : Language.get("ScoreHistorySubstate.replayDataNo", "Not Available"),
			hasReplay ? FlxColor.GREEN : FlxColor.RED));

		// -- Right column --
		if (e.marvelouses != null)
			rows2.push(mk(Language.get("ScoreHistorySubstate.marvelouses", "Marvelouses"), Std.string(e.marvelouses), FlxColor.fromRGB(255, 215, 0)));
		rows2.push(mk(Language.get("ScoreHistorySubstate.sicks", "Sicks"), Std.string(e.sicks), FlxColor.fromRGB(0, 255, 255)));
		rows2.push(mk(Language.get("ScoreHistorySubstate.goods", "Goods"), Std.string(e.goods), FlxColor.WHITE));
		rows2.push(mk(Language.get("ScoreHistorySubstate.bads", "Bads"), Std.string(e.bads), FlxColor.GRAY));
		rows2.push(mk(Language.get("ScoreHistorySubstate.shits", "Shits"), Std.string(e.shits), FlxColor.GRAY));
		rows2.push(mk(Language.get("ScoreHistorySubstate.misses", "Misses"), Std.string(e.misses), FlxColor.fromRGB(255, 100, 100)));
		rows2.push(mk(Language.get("ScoreHistorySubstate.songSpeed", "Song Speed"), Std.string(e.songSpeed), FlxColor.fromRGB(200, 200, 200)));
		rows2.push(mk(Language.get("ScoreHistorySubstate.playbackRate", "Playback Rate"), Std.string(e.playbackRate), FlxColor.fromRGB(200, 200, 200)));
		rows2.push(mk(Language.get("ScoreHistorySubstate.songSpeedType", "Speed Type"), e.songSpeedType, FlxColor.fromRGB(200, 200, 200)));

		if (e.details != null && e.details.length >= 24)
		{
			// LeatherEngine 移植: 判定类型 (预设名或 Custom), 老记录从窗口反查
			var judgeType:String = (e.details.length > 26 && e.details[26] != null)
				? Std.string(e.details[26])
				: '';
			var judgeStr = "";
			// LeatherEngine 移植: 有 judgementTimings (details[24]) 时优先展示 4 档窗口
			if (e.details.length > 24 && e.details[24] != null)
			{
				var timings:Array<Dynamic> = e.details[24];
				if (timings != null && timings.length >= 4)
				{
					if (judgeType.length == 0)
						judgeType = backend.Ratings.presetNameForTimings([
							Std.parseInt(timings[0]), Std.parseInt(timings[1]),
							Std.parseInt(timings[2]), Std.parseInt(timings[3])
						]);
					judgeStr += Std.string(timings[0]) + " / ";
				}
			}
			judgeStr += Std.string(e.details[20]) + " / " + Std.string(e.details[21])
				+ " / " + Std.string(e.details[22]) + " / " + Std.string(e.details[23]) + "f";
			if (judgeType.length == 0)
				judgeType = Language.get("ScoreHistorySubstate.custom", "Custom");
			rows2.push(mk(Language.get("ScoreHistorySubstate.judgeWindows", "Judge Type / Win"), judgeType + " (" + judgeStr + ")", FlxColor.fromRGB(180, 180, 200)));
		}

		// ---- Measure widest label per column (capped so long labels never crush the value column) ----
		var LABEL_CAP:Float = 200;
		var col1LabelW:Float = 0;
		for (r in rows1)
		{
			var p:FlxText = new FlxText(0, 0, 0, r.label + ":", 17);
			p.setFormat(Paths.languageFont(), 17, FlxColor.WHITE, LEFT);
			if (p.width > col1LabelW) col1LabelW = p.width;
			p.destroy();
		}
		if (col1LabelW > LABEL_CAP) col1LabelW = LABEL_CAP;

		var col2LabelW:Float = 0;
		for (r in rows2)
		{
			var p:FlxText = new FlxText(0, 0, 0, r.label + ":", 17);
			p.setFormat(Paths.languageFont(), 17, FlxColor.WHITE, LEFT);
			if (p.width > col2LabelW) col2LabelW = p.width;
			p.destroy();
		}
		if (col2LabelW > LABEL_CAP) col2LabelW = LABEL_CAP;

		var col1ValX:Float = col1X + col1LabelW + 12;
		var col2ValX:Float = col2X + col2LabelW + 12;
		// Guarantee generous value room so long strings (judge windows, speed type) never clip/wrap
		var col1ValW:Float = Math.max(180, Math.min(260, col2X - col1ValX - 24));
		var col2ValW:Float = Math.max(220, Math.min(360, detailBG.x + detailBG.width - col2ValX - 16));

		// ---- Render with spring entrance (long labels wrap to 2 lines so values stay readable) ----
		var gi:Int = 0;
		var y:Float = startY;
		for (r in rows1)
		{
			var labelOver:Bool = false;
			{
				var p:FlxText = new FlxText(0, 0, 0, r.label + ":", 17);
				p.setFormat(Paths.languageFont(), 17, FlxColor.WHITE, LEFT);
				labelOver = p.width > col1LabelW;
				p.destroy();
			}
			var lh:Float = labelOver ? lineH * 2 : lineH;

			var labelTxt = new FlxText(col1X, y, col1LabelW + 4, r.label + ":", 17);
			labelTxt.setFormat(Paths.languageFont(), 17, FlxColor.fromRGB(140, 150, 160), LEFT);
			labelTxt.scrollFactor.set();
			if (labelOver) labelTxt.textField.wordWrap = true;
			labelTxt.alpha = 0;
			detailGroup.add(labelTxt);

			var valTxt = new FlxText(col1ValX, y, col1ValW, r.value, r.size);
			valTxt.setFormat(Paths.languageFont(), r.size, r.color, LEFT);
			valTxt.scrollFactor.set();
			valTxt.alpha = 0;
			detailGroup.add(valTxt);

			FlxTween.tween(labelTxt, {alpha: 1}, 0.2, {startDelay: gi * 0.03});
			FlxTween.tween(valTxt, {alpha: 1}, 0.2, {startDelay: gi * 0.03});

			// Keep references for the live score/accuracy counters
			if (gi == 1) scoreText = valTxt;
			if (gi == 2) accuracyText = valTxt;
			y += lh;
			gi++;
		}

		gi = 0;
		y = startY;
		for (r in rows2)
		{
			var labelOver:Bool = false;
			{
				var p:FlxText = new FlxText(0, 0, 0, r.label + ":", 17);
				p.setFormat(Paths.languageFont(), 17, FlxColor.WHITE, LEFT);
				labelOver = p.width > col2LabelW;
				p.destroy();
			}
			var lh:Float = labelOver ? lineH * 2 : lineH;

			var labelTxt = new FlxText(col2X, y, col2LabelW + 4, r.label + ":", 17);
			labelTxt.setFormat(Paths.languageFont(), 17, FlxColor.fromRGB(140, 150, 160), LEFT);
			labelTxt.scrollFactor.set();
			if (labelOver) labelTxt.textField.wordWrap = true;
			labelTxt.alpha = 0;
			detailGroup.add(labelTxt);

			var valTxt = new FlxText(col2ValX, y, col2ValW, r.value, r.size);
			valTxt.setFormat(Paths.languageFont(), r.size, r.color, LEFT);
			valTxt.scrollFactor.set();
			valTxt.alpha = 0;
			detailGroup.add(valTxt);

			FlxTween.tween(labelTxt, {alpha: 1}, 0.2, {startDelay: gi * 0.03});
			FlxTween.tween(valTxt, {alpha: 1}, 0.2, {startDelay: gi * 0.03});
			y += lh;
			gi++;
		}

		updateGraph(e);
	}

	function updateGraph(e:ScoreEntry)
	{
		if (e.details == null || e.details.length < 11) return;
		var noteTime:Array<Float> = e.details[9];
		var noteMs:Array<Float> = e.details[10];
		var songLen:Float = e.details[2];
		if (noteTime == null || noteMs == null || songLen <= 0) return;

		var sickWindow = ClientPrefs.data.sickWindow;
		var goodWindow = ClientPrefs.data.goodWindow;
		var badWindow = ClientPrefs.data.badWindow;
		var marvelousWindow = ClientPrefs.data.marvelousWindow;
		var hasMarvelous = ClientPrefs.data.marvelousRatings;
		var safeZoneOffset:Float = (ClientPrefs.data.safeFrames / 60) * 1000;

		// LeatherEngine 移植: 优先使用该成绩记录实际使用的判定窗口 (details[24])
		if (e.details != null && e.details.length > 24 && e.details[24] != null)
		{
			var recTimings:Array<Dynamic> = e.details[24];
			if (recTimings != null && recTimings.length >= 4)
			{
				marvelousWindow = recTimings[0];
				sickWindow = recTimings[1];
				goodWindow = recTimings[2];
				badWindow = recTimings[3];
			}
		}

		var drawW:Float = 800;
		var drawH:Float = 140;
		var noteSize:Float = 2.0;
		var moveSize:Float = 0.8;
		var len:Int = Math.floor(Math.min(noteTime.length, noteMs.length));

		try
		{
			// Use OpenFL Shape/Graphics + BitmapData to guarantee a clean canvas each time.
			// FlxSpriteUtil keeps internal state that causes drawings to accumulate across calls.
			var shape = new Shape();
			var gfx = shape.graphics;
			gfx.clear();

			// Draw note dots
			for (i in 0...len)
			{
				var msAbs = Math.abs(noteMs[i]);
				var color:Int;

				if (hasMarvelous && msAbs <= marvelousWindow)
					color = 0xFFFFD700;
				else if (msAbs <= sickWindow)
					color = 0xFF00FFFF;
				else if (msAbs <= goodWindow)
					color = 0xFF00FF00;
				else if (msAbs <= badWindow)
					color = 0xFFFF7F00;
				else if (msAbs <= safeZoneOffset)
					color = 0xFFFF5858;
				else
					color = 0xFFFF0000;

				var timeFrac:Float = noteTime[i] / songLen;
				if (timeFrac < 0) timeFrac = 0;
				if (timeFrac > 1) timeFrac = 1;

				var x:Float = drawW * timeFrac;
				var y:Float;

				if (msAbs <= safeZoneOffset)
					y = drawH * 0.5 + drawH * 0.5 * moveSize * (noteMs[i] / safeZoneOffset);
				else
					y = drawH * 0.5 + drawH * 0.5 * 0.9;

				gfx.beginFill(color);
				gfx.drawCircle(x, y, noteSize);
				gfx.endFill();
			}

			// center line
			gfx.lineStyle(2, 0x7FFFFFFF);
			gfx.moveTo(0, drawH * 0.5);
			gfx.lineTo(drawW, drawH * 0.5);

			// marvelous window lines (LeatherEngine 移植)
			if (hasMarvelous && marvelousWindow <= sickWindow)
			{
				gfx.lineStyle(2, 0x7FFFD700);
				var my = drawH * 0.5 + drawH * 0.5 * moveSize * (marvelousWindow / safeZoneOffset);
				gfx.moveTo(0, my);
				gfx.lineTo(drawW, my);
				gfx.moveTo(0, drawH - my);
				gfx.lineTo(drawW, drawH - my);
			}

			// sick window lines
			gfx.lineStyle(2, 0x7F00FFFF);
			var sy = drawH * 0.5 + drawH * 0.5 * moveSize * (sickWindow / safeZoneOffset);
			gfx.moveTo(0, sy);
			gfx.lineTo(drawW, sy);
			gfx.moveTo(0, drawH - sy);
			gfx.lineTo(drawW, drawH - sy);

			// good window lines
			if (sickWindow <= goodWindow)
			{
				gfx.lineStyle(2, 0x7F00FF00);
				var gy = drawH * 0.5 + drawH * 0.5 * moveSize * (goodWindow / safeZoneOffset);
				gfx.moveTo(0, gy);
				gfx.lineTo(drawW, gy);
				gfx.moveTo(0, drawH - gy);
				gfx.lineTo(drawW, drawH - gy);
			}

			// bad window lines
			if (sickWindow <= badWindow || goodWindow <= badWindow)
			{
				gfx.lineStyle(2, 0x7FFF7F00);
				var by = drawH * 0.5 + drawH * 0.5 * moveSize * (badWindow / safeZoneOffset);
				gfx.moveTo(0, by);
				gfx.lineTo(drawW, by);
				gfx.moveTo(0, drawH - by);
				gfx.lineTo(drawW, drawH - by);
			}

			// shit boundary
			gfx.lineStyle(2, 0x7FFF5858);
			var shitY = drawH * 0.5 + drawH * 0.5 * moveSize;
			gfx.moveTo(0, shitY);
			gfx.lineTo(drawW, shitY);
			gfx.moveTo(0, drawH - shitY);
			gfx.lineTo(drawW, drawH - shitY);

			// Render shape to bitmap and load into sprite (completely replaces old graphic)
			var bmp = new BitmapData(Std.int(drawW), Std.int(drawH), true, 0x00000000);
			bmp.draw(shape);
			graphNote.loadGraphic(bmp);

			FlxTween.tween(graphNote, {alpha: 1}, 0.25);
		}
		catch(e:Dynamic)
		{
			TraceManager.error('trace.scoreHistory.renderGraph', 'ScoreHistorySubstate - Failed to render graph: {}', [e]);
			graphNote.alpha = 0;
		}
	}

	function getGradeColor(rating:String):FlxColor
	{
		return switch(rating.toUpperCase())
		{
			case "SFC", "GFC": FlxColor.fromRGB(255, 215, 0);
			case "FC": FlxColor.fromRGB(0, 255, 0);
			case "SDCB", "GSDCB": FlxColor.CYAN;
			case "CLEAR": FlxColor.WHITE;
			default: FlxColor.GRAY;
		}
	}

	function changeSelection(change:Int)
	{
		if (isEmpty) return;

		var previousSelected = curSelected;
		curSelected += change;
		if (curSelected < 0) curSelected = entries.length - 1;
		if (curSelected >= entries.length) curSelected = 0;

		if (curSelected == previousSelected) return;

		lastSelected = previousSelected;
		updateSelectionColors();
		adjustScrollToSelected();

		var targetY = listStartY + curSelected * itemHeight - scrollOffset + 2;
		FlxTween.tween(selector, {y: targetY}, 0.35, {ease: FlxEase.backOut});

		updateDetails();
		FlxG.sound.play(Paths.sound('scrollMenu'));
	}

	function playReplay(entry:ScoreEntry)
	{
		if (entry == null || entry.songName == null || entry.songName == "") return;

		try
		{
			#if sys
			// 将存储的 replay 数据转回 FrameSave 并写入临时文件
			var frames:Array<FrameSave> = [];
			if (entry.replayData != null)
			{
				frames = Replay.dynamicToFrames(entry.replayData);
			}
			Replay.dbgLog('[DEBUG-rpl] playReplay frames=' + frames.length + ' song=' + entry.songName + ' diff=' + entry.difficulty);

			// 构造 StateRecord
			var details:Array<Dynamic> = entry.details;
			var stateRecord:StateRecord = {
				songName: Paths.formatToSongPath(entry.songName),
				difficulty: entry.difficulty,
				playDate: entry.date,
				songLength: details != null && details.length > 2 ? details[2] : 0,
				songSpeed: entry.songSpeed,
				playbackRate: entry.playbackRate,
				healthGain: details != null && details.length > 13 ? details[13] : 1,
				healthLoss: details != null && details.length > 14 ? details[14] : 1,
				cpuControlled: details != null && details.length > 15 ? details[15] : false,
				practiceMode: details != null && details.length > 16 ? details[16] : false,
				instakillOnMiss: details != null && details.length > 17 ? details[17] : false,
				songScore: entry.score,
				ratingPercent: entry.ratingPercent,
				ratingFC: entry.ratingFC,
				songHits: details != null && details.length > 3 ? details[3] : 0,
				highestCombo: entry.maxCombo,
				songMisses: entry.misses,
				sicks: entry.sicks,
				goods: entry.goods,
				bads: entry.bads,
				shits: entry.shits,
				noteTime: details != null && details.length > 9 ? details[9] : [],
				noteMs: details != null && details.length > 10 ? details[10] : [],
				songSpeedType: entry.songSpeedType,
				sickWindow: details != null && details.length > 20 ? details[20] : 45,
				goodWindow: details != null && details.length > 21 ? details[21] : 90,
				badWindow: details != null && details.length > 22 ? details[22] : 135,
				safeFrames: details != null && details.length > 23 ? details[23] : 10,
				// LeatherEngine 移植: 从成绩详情恢复判定手感 (与结果界面一致)
				judgementTimings: details != null && details.length > 24 && details[24] != null ? details[24] : null,
				judgementPreset: details != null && details.length > 26 && details[26] != null ? details[26] : null,
				marvelousRatings: details != null && details.length > 25 && details[25] != null ? details[25] : null,
				replayVersion: 2
			};

			// 写入临时回放文件
			var tempDir:String = CoolUtil.getReplayTempDir();
			SUtil.mkDirs(tempDir);
			var tempPath:String = tempDir + 'replay_temp.rsd';
			Replay.saveToFile(frames, stateRecord, tempPath);
			Replay.preparedPath = tempPath;
			Replay.dbgLog('[DEBUG-rpl] playReplay wrote temp=' + tempPath);
			#end

			PlayState.replayMode = true;
			PlayState.isStoryMode = false;
			PlayState.storyDifficulty = entry.difficulty;
			PauseSubState.entries = entry;
			var songLowercase:String = Paths.formatToSongPath(entry.songName);
			var poop:String = Highscore.formatSong(songLowercase, entry.difficulty);
			PlayState.SONG = Song.loadFromJson(poop, songLowercase);
			Replay.dbgLog('[DEBUG-rpl] playReplay loaded song=' + (PlayState.SONG != null ? PlayState.SONG.song : 'NULL'));
			PlayState.changedDifficulty = false;
			close();
			Replay.dbgLog('[DEBUG-rpl] playReplay switching to PlayState');
			LoadingState.loadAndSwitchState(new PlayState());
		}
		catch(e:Dynamic)
		{
			Replay.dbgLog('[DEBUG-rpl] playReplay EXCEPTION: ' + Std.string(e));
			TraceManager.error('trace.scoreHistory.playReplay', 'ScoreHistorySubstate - Failed to play replay: {}', [e]);
		}
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		FreeplayState.instance.canInput = false;

		if (scoreText != null && accuracyText != null && !isEmpty)
		{
			if (Math.abs(displayedScore - targetScore) > 10)
			{
				displayedScore = Math.floor(FlxMath.lerp(displayedScore, targetScore, CoolUtil.boundTo(elapsed * 24, 0, 1)));
				scoreText.text = Std.string(displayedScore);
			}
			else if (displayedScore != targetScore)
			{
				displayedScore = targetScore;
				scoreText.text = Std.string(displayedScore);
			}

			if (Math.abs(displayedAccuracy - targetAccuracy) > 0.01)
			{
				displayedAccuracy = FlxMath.lerp(displayedAccuracy, targetAccuracy, CoolUtil.boundTo(elapsed * 12, 0, 1));
				accuracyText.text = Highscore.floorDecimal(displayedAccuracy, 2) + '%';
			}
			else if (displayedAccuracy != targetAccuracy)
			{
				displayedAccuracy = targetAccuracy;
				accuracyText.text = Highscore.floorDecimal(displayedAccuracy, 2) + '%';
			}

			if (!scoreAnimCompleted && displayedScore == targetScore && Math.abs(displayedAccuracy - targetAccuracy) <= 0.01)
			{
				scoreAnimCompleted = true;
				if (curSelected >= 0 && curSelected < entries.length)
					showRatingIcon(entries[curSelected]);
			}
		}

		if (!isEmpty && selector.visible)
			updateSelectorPosition();

		if (isEmpty)
		{
			if (controls.BACK) exitSubstate();
			return;
		}

		if (controls.BACK) exitSubstate();

		if (controls.ACCEPT)
		{
			var selected = entries[curSelected];
			if (selected == null) return;
			var hasReplay = Allscore.hasReplayData(selected);

			if (hasReplay)
			{
				FlxTween.tween(detailBG, {alpha: 0.8}, 0.1, {
					onComplete: function(_) { FlxTween.tween(detailBG, {alpha: 0.6}, 0.1); }
				});
				new FlxTimer().start(0.2, function(tmr) { playReplay(selected); });
			}
			else
			{
				var origX = detailBG.x;
				FlxTween.tween(detailBG, {x: origX - 5}, 0.05, {
					onComplete: function(_) {
						FlxTween.tween(detailBG, {x: origX + 5}, 0.05, {
							onComplete: function(_) {
								FlxTween.tween(detailBG, {x: origX}, 0.05);
							}
						});
					}
				});
			}
		}

		if (controls.UI_UP_P) changeSelection(-1);
		if (controls.UI_DOWN_P) changeSelection(1);

		if (controls.RESET #if android || virtualPad.buttonC.justPressed #end)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			Allscore.deleteEntry(songName, difficulty, curSelected);
			entries = Allscore.getHistory(songName, difficulty);

			if (entries.length == 0) curSelected = 0;
			else
			{
				if (curSelected >= entries.length) curSelected = entries.length - 1;
				if (curSelected < 0) curSelected = 0;
			}
			refreshList();
		}
	}

	function exitSubstate()
	{
		FlxTween.tween(titleTxt, {alpha: 0}, 0.2);
		FlxTween.tween(dateListBG, {alpha: 0}, 0.2);
		FlxTween.tween(detailBG, {alpha: 0}, 0.2);
		FlxTween.tween(graphBG, {alpha: 0}, 0.2);
		FlxTween.tween(graphNote, {alpha: 0}, 0.15);
		FlxTween.tween(selector, {alpha: 0}, 0.2);
		FlxTween.tween(ratingIcon, {alpha: 0}, 0.2);

		for (item in dateListGroup.members)
			FlxTween.tween(item, {alpha: 0}, 0.15);
		for (item in detailGroup.members)
			FlxTween.tween(item, {alpha: 0}, 0.15);

		new FlxTimer().start(0.2, function(tmr) {
			close();
			FreeplayState.instance.canInput = true;
		});
		FlxG.sound.play(Paths.sound('cancelMenu'), 1);
	}
}
