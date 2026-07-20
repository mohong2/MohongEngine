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
			Allscore.load();
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

		FlxTween.tween(titleTxt, {alpha: 1}, 0.4, {ease: FlxEase.quartOut});
		FlxTween.tween(subtitleTxt, {alpha: 1}, 0.4, {ease: FlxEase.quartOut, startDelay: 0.1});
		FlxTween.tween(titleUnderline.scale, {x: 1}, 0.5, {ease: FlxEase.quartOut, startDelay: 0.2});
		FlxTween.tween(dateListBG, {alpha: 0.6}, 0.4, {ease: FlxEase.quartOut, startDelay: 0.15});
		FlxTween.tween(detailBG, {alpha: 0.6}, 0.4, {ease: FlxEase.quartOut, startDelay: 0.2});
		FlxTween.tween(graphBG, {alpha: 0.6}, 0.4, {ease: FlxEase.quartOut, startDelay: 0.25});
		FlxTween.tween(graphNote, {alpha: 1}, 0.5, {ease: FlxEase.quartOut, startDelay: 0.35});
		FlxTween.tween(instructionsTxt, {alpha: 1}, 0.4, {ease: FlxEase.quartOut, startDelay: 0.3});
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
			FlxTween.tween(item, {alpha: 1}, 0.3, {startDelay: i * 0.03, ease: FlxEase.quartOut});
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

		function addLine(x:Float, lineNum:Int, label:String, value:String, color:FlxColor, ?valueSize:Int = 17):FlxText
		{
			var labelTxt = new FlxText(x, startY + lineNum * lineH, 140, label + ":", 17);
			labelTxt.setFormat(Paths.languageFont(), 17, FlxColor.fromRGB(140, 150, 160), LEFT);
			labelTxt.scrollFactor.set();
			labelTxt.alpha = 0;
			detailGroup.add(labelTxt);

			var valTxt = new FlxText(x + 120, startY + lineNum * lineH, 280, value, valueSize);
			valTxt.setFormat(Paths.languageFont(), valueSize, color, LEFT);
			valTxt.scrollFactor.set();
			valTxt.alpha = 0;
			detailGroup.add(valTxt);

			FlxTween.tween(labelTxt, {alpha: 1}, 0.2, {startDelay: lineNum * 0.03});
			FlxTween.tween(valTxt, {alpha: 1}, 0.2, {startDelay: lineNum * 0.03});
			return valTxt;
		}

		// -- Left column --
		var ln:Int = 0;
		addLine(col1X, ln++, Language.get("ScoreHistorySubstate.date", "Date"), e.date, FlxColor.WHITE);

		targetScore = e.score;
		targetAccuracy = (e.ratingPercent >= 0) ? e.ratingPercent * 100 : 0;

		if (lastSelected != curSelected)
		{
			displayedScore = 0;
			displayedAccuracy = 0;
		}

		scoreText = addLine(col1X, ln++, Language.get("ScoreHistorySubstate.score", "Score"), Std.string(displayedScore), FlxColor.fromRGB(255, 215, 0), 20);
		accuracyText = addLine(col1X, ln++, Language.get("ScoreHistorySubstate.accuracy", "Accuracy"), Highscore.floorDecimal(displayedAccuracy, 2) + '%', FlxColor.WHITE, 18);
		addLine(col1X, ln++, Language.get("ScoreHistorySubstate.rating", "Grade"), e.ratingName, getGradeColor(e.ratingName));
		addLine(col1X, ln++, Language.get("ScoreHistorySubstate.songRating", "Song Rating"), e.ratingFC, FlxColor.WHITE);
		addLine(col1X, ln++, Language.get("ScoreHistorySubstate.maxCombo", "Max Combo"), Std.string(e.maxCombo), FlxColor.WHITE);

		var hasReplay = Allscore.hasReplayData(e);
		addLine(col1X, ln++, Language.get("ScoreHistorySubstate.replayData", "Replay"),
			hasReplay ? Language.get("ScoreHistorySubstate.replayDataYes", "Available") : Language.get("ScoreHistorySubstate.replayDataNo", "Not Available"),
			hasReplay ? FlxColor.GREEN : FlxColor.RED);

		// -- Right column --
		ln = 0;
		addLine(col2X, ln++, Language.get("ScoreHistorySubstate.sicks", "Sicks"), Std.string(e.sicks), FlxColor.fromRGB(0, 255, 255));
		addLine(col2X, ln++, Language.get("ScoreHistorySubstate.goods", "Goods"), Std.string(e.goods), FlxColor.WHITE);
		addLine(col2X, ln++, Language.get("ScoreHistorySubstate.bads", "Bads"), Std.string(e.bads), FlxColor.GRAY);
		addLine(col2X, ln++, Language.get("ScoreHistorySubstate.shits", "Shits"), Std.string(e.shits), FlxColor.GRAY);
		addLine(col2X, ln++, Language.get("ScoreHistorySubstate.misses", "Misses"), Std.string(e.misses), FlxColor.fromRGB(255, 100, 100));
		addLine(col2X, ln++, Language.get("ScoreHistorySubstate.songSpeed", "Song Speed"), Std.string(e.songSpeed), FlxColor.fromRGB(200, 200, 200));
		addLine(col2X, ln++, Language.get("ScoreHistorySubstate.playbackRate", "Playback Rate"), Std.string(e.playbackRate), FlxColor.fromRGB(200, 200, 200));
		addLine(col2X, ln++, Language.get("ScoreHistorySubstate.songSpeedType", "Speed Type"), e.songSpeedType, FlxColor.fromRGB(200, 200, 200));

		// Judgment windows from replay data
		if (e.details != null && e.details.length >= 24)
		{
			var judgeStr = Std.string(e.details[20]) + " / " + Std.string(e.details[21])
				+ " / " + Std.string(e.details[22]) + " / " + Std.string(e.details[23]) + "f";
			addLine(col2X, ln++, Language.get("ScoreHistorySubstate.judgeWindows", "Judge Win S/G/B/SF"), judgeStr, FlxColor.fromRGB(180, 180, 200));
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
		var safeZoneOffset:Float = (ClientPrefs.data.safeFrames / 60) * 1000;

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

				if (msAbs <= sickWindow)
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
		FlxTween.tween(selector, {y: targetY}, 0.2, {ease: FlxEase.quartOut});

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
				replayVersion: 2
			};

			// 写入临时回放文件
			var tempDir:String = CoolUtil.getReplayTempDir();
			SUtil.mkDirs(tempDir);
			var tempPath:String = tempDir + 'replay_temp.rsd';
			Replay.saveToFile(frames, stateRecord, tempPath);
			Replay.preparedPath = tempPath;
			#end

			PlayState.replayMode = true;
			PlayState.isStoryMode = false;
			PlayState.storyDifficulty = entry.difficulty;
			PauseSubState.entries = entry;
			var songLowercase:String = Paths.formatToSongPath(entry.songName);
			var poop:String = Highscore.formatSong(songLowercase, entry.difficulty);
			PlayState.SONG = Song.loadFromJson(poop, songLowercase);
			PlayState.changedDifficulty = false;
			close();
			LoadingState.loadAndSwitchState(new PlayState());
		}
		catch(e:Dynamic)
		{
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
