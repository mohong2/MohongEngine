package substates;

import states.PlayState;
import states.FreeplayState;
import states.StoryMenuState;
import states.LoadingState;
import states.MainMenuState;
import backend.MusicBeatState;
import backend.MusicBeatSubstate;
import ClientPrefs;
import Highscore;
import Song;
import Allscore;
import Replay;
import substates.PauseSubState;
import CustomFadeTransition;
import WeekData;
import flixel.FlxSprite;
import flixel.FlxG;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.util.FlxTimer;
import flixel.util.FlxSpriteUtil;
import flixel.addons.transition.FlxTransitionableState;
import CoolUtil;
import SUtil;

class PlayStateResultsSubstate extends MusicBeatSubstate
{
	var bg:FlxSprite;

	var titleTxt:FlxText;
	var titleUnderline:FlxSprite;

	var leftPanel:FlxSprite;
	var graphPanel:FlxSprite;
	var statsPanel:FlxSprite;

	var leftTextGroup:FlxTypedGroup<FlxText>;
	var graphNote:FlxSprite;

	var barBGGroup:FlxTypedGroup<FlxSprite>;
	var barGroup:FlxTypedGroup<FlxSprite>;
	var barTextGroup:FlxTypedGroup<FlxText>;

	var continueBtn:FlxSprite;
	var continueTxt:FlxText;
	var replayBtn:FlxSprite;
	var replayTxt:FlxText;

	var displayedScore:Int = 0;
	var targetScore:Int = 0;
	var displayedAccuracy:Float = 0;
	var targetAccuracy:Float = 0;
	var scoreAnimDone:Bool = false;

	var accentColor:FlxColor = FlxColor.fromRGB(0, 200, 220);
	var panelBgColor:FlxColor = FlxColor.fromRGB(15, 18, 30);

	var safeZoneOffset:Float = (ClientPrefs.data.safeFrames / 60) * 1000;

	/** Dedicated screen-space camera, isolated from PlayState's scrolling cameras. */
	var substateCam:flixel.FlxCamera;

	var noteMs:Array<Float>;
	var noteTime:Array<Float>;
	var songLength:Float;

	var closeCheck:Bool = false;
	var confirmContinue:Bool = false;
	var confirmReplay:Bool = false;
	var ratingIcon:FlxSprite;
	var ratingIconTween:FlxTween;

	var hitColorArray:Array<FlxColor> = [
		FlxColor.fromRGB(0, 255, 255),
		FlxColor.fromRGB(0, 255, 0),
		FlxColor.fromRGB(255, 127, 0),
		FlxColor.fromRGB(255, 88, 88),
		FlxColor.fromRGB(255, 0, 0)
	];

	var hitNames:Array<String> = ["Sick", "Good", "Bad", "Shit", "Miss"];

	public function new()
	{
		super();

		FlxG.camera.scroll.set(0, 0);
		FlxG.camera.target = null;

		// [FIX] Create a dedicated static camera for the substate
		// PlayState's game camera moves during gameplay, which would misalign mouse hit detection.
		// Using a fresh camera with no scroll/zoom ensures buttons remain clickable at correct positions.
		substateCam = new flixel.FlxCamera();
		substateCam.bgColor.alpha = 0;
		FlxG.cameras.add(substateCam, false);
		cameras = [substateCam];

		var game = PlayState.instance;
		if (game == null) {
			close();
			return;
		}

		// Hide all PlayState UI elements
		game.camHUD.visible = false;
		game.healthBar.visible = false;
		if (game.healthBarBG != null) game.healthBarBG.visible = false;
		game.scoreTxt.visible = false;
		game.iconP1.visible = false;
		game.iconP2.visible = false;
		game.timeBar.visible = false;
		game.timeBarBG.visible = false;
		game.timeTxt.visible = false;
		game.keyboardDisplay.visible = false;
		game.strumLineNotes.visible = false;
		// ratingIcon moved to end of constructor so it renders on top of all panels

		noteMs = game.NoteMs;
		noteTime = game.NoteTime;
		songLength = game.songLength;

		targetScore = game.songScore;
		// [CRASH FIX] ratingPercent might be NaN on some devices; handle gracefully
		targetAccuracy = (Math.isNaN(game.ratingPercent) || game.ratingPercent < 0) ? 0 : game.ratingPercent * 100;

		// -- Acrylic-style background (full screen) --
		bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.fromRGBFloat(0.06, 0.08, 0.14, 0.85));
		bg.alpha = 0;
		add(bg);

		// -- Title --
		titleTxt = new FlxText(0, 30, FlxG.width, Language.get("ResultsScreen.title", "RESULTS"), 42);
		titleTxt.setFormat(Paths.languageFont(), 42, FlxColor.WHITE, CENTER);
		titleTxt.alpha = 0;
		add(titleTxt);

		var subtitleTxt = new FlxText(0, 78, FlxG.width, PlayState.SONG.song + " - " + CoolUtil.difficultyString(), 18);
		subtitleTxt.setFormat(Paths.languageFont(), 18, FlxColor.GRAY, CENTER);
		subtitleTxt.alpha = 0;
		add(subtitleTxt);

		titleUnderline = new FlxSprite().makeGraphic(320, 3, accentColor);
		titleUnderline.screenCenter(X);
		titleUnderline.y = 112;
		titleUnderline.scale.x = 0;
		add(titleUnderline);

		// -- Panels (full-width layout) --
		var panelY:Float = 135;
		var leftW:Int = 580;
		var leftH:Int = 470;
		var rightX:Float = 620;
		var rightW:Int = 640;
		var graphH:Int = 255;
		var statsH:Int = 180;

		leftPanel = createRoundedPanel(20, panelY, leftW, leftH, panelBgColor);
		add(leftPanel);

		graphPanel = createRoundedPanel(rightX, panelY, rightW, graphH, panelBgColor);
		add(graphPanel);

		statsPanel = createRoundedPanel(rightX, panelY + graphH + 20, rightW, statsH, panelBgColor);
		add(statsPanel);

		// -- Left panel: text info --
		leftTextGroup = new FlxTypedGroup<FlxText>();
		add(leftTextGroup);
		buildLeftInfo(game);

		// -- Graph note: note timing scatter plot --
		graphNote = new FlxSprite(rightX + 10, panelY + 10).makeGraphic(rightW - 20, graphH - 20, FlxColor.TRANSPARENT);
		graphNote.alpha = 0;
		add(graphNote);
		graphNoteDraw();

		// -- Hit distribution bars --
		barBGGroup = new FlxTypedGroup<FlxSprite>();
		add(barBGGroup);
		barGroup = new FlxTypedGroup<FlxSprite>();
		add(barGroup);
		barTextGroup = new FlxTypedGroup<FlxText>();
		add(barTextGroup);
		buildHitBars(game);

		// -- Buttons --
		var btnY:Float = panelY + leftH + 15;
		continueBtn = createButton(320, btnY, 300, 52, accentColor);
		continueBtn.alpha = 0;
		add(continueBtn);

		continueTxt = new FlxText(0, 0, 300, Language.get("ResultsScreen.continue", "CONTINUE"), 22);
		continueTxt.setFormat(Paths.languageFont(), 22, FlxColor.WHITE, CENTER);
		continueTxt.alpha = 0;
		add(continueTxt);
		centerTextOnButton(continueTxt, continueBtn);

		replayBtn = createButton(660, btnY, 300, 52, FlxColor.fromRGB(85, 90, 105));
		replayBtn.alpha = 0;
		add(replayBtn);

		replayTxt = new FlxText(0, 0, 300, Language.get("ResultsScreen.replay", "REPLAY"), 22);
		replayTxt.setFormat(Paths.languageFont(), 22, FlxColor.WHITE, CENTER);
		replayTxt.alpha = 0;
		add(replayTxt);
		centerTextOnButton(replayTxt, replayBtn);

		// -- Instructions --
		var instructions = new FlxText(0, FlxG.height - 40, FlxG.width,
			Language.get("ResultsScreen.instructions", "ENTER / CLICK: Select  |  ARROWS: Switch  |  ESC: Continue"), 13);
		instructions.setFormat(Paths.languageFont(), 13, FlxColor.GRAY, CENTER);
		instructions.alpha = 0;
		add(instructions);

		#if android
		addVirtualPad(LEFT_RIGHT, A_B);
		addPadCamera();
		#end

		// [FIX] ratingIcon must be added LAST so it renders on TOP of all panels/text
		ratingIcon = new FlxSprite();
		ratingIcon.visible = false;
		ratingIcon.alpha = 0;
		ratingIcon.cameras = cameras;
		add(ratingIcon);

		// -- Fade in --
		startIntroTween(subtitleTxt, instructions);
	}

	/**
	 * Check if any touch just pressed/released for mobile support.
	 * Returns true if there was a touch interaction.
	 */
	function checkTouchInteraction():Bool
	{
		#if mobile
		for (touch in FlxG.touches.list)
		{
			if (touch.justReleased) return true;
		}
		#end
		return false;
	}

	/**
	 * Manual AABB overlap check using the substate camera's world space.
	 * Avoids Flixel's built-in overlaps() which can misalign when
	 * PlayState's main cameras (camGame/camHUD) have scroll/zoom offsets.
	 */
	function overlapsInSubstateCam(btn:FlxSprite, pointX:Float, pointY:Float):Bool
	{
		return (pointX >= btn.x && pointX <= btn.x + btn.width
			&& pointY >= btn.y && pointY <= btn.y + btn.height);
	}

	/**
	 * Check if a specific button was touched (mobile).
	 */
	function touchOverlapsButton(btn:FlxSprite):Bool
	{
		#if mobile
		var cam = (substateCam != null) ? substateCam : FlxG.camera;
		for (touch in FlxG.touches.list)
		{
			if (touch.justReleased)
			{
				var worldPt = touch.getWorldPosition(cam, flixel.math.FlxPoint.get());
				var hit = overlapsInSubstateCam(btn, worldPt.x, worldPt.y);
				worldPt.put();
				if (hit) return true;
			}
		}
		#end
		return false;
	}

	function startIntroTween(subtitleTxt:FlxText, instructions:FlxText)
	{
		FlxTween.tween(bg, {alpha: 1}, 0.5, {ease: FlxEase.quartOut});
		FlxTween.tween(titleTxt, {alpha: 1}, 0.45, {ease: FlxEase.quartOut, startDelay: 0.15});
		FlxTween.tween(subtitleTxt, {alpha: 1}, 0.45, {ease: FlxEase.quartOut, startDelay: 0.25});
		FlxTween.tween(titleUnderline.scale, {x: 1}, 0.55, {ease: FlxEase.quartOut, startDelay: 0.35});

		FlxTween.tween(leftPanel, {alpha: 0.78}, 0.45, {ease: FlxEase.quartOut, startDelay: 0.3});
		FlxTween.tween(graphPanel, {alpha: 0.78}, 0.45, {ease: FlxEase.quartOut, startDelay: 0.35});
		FlxTween.tween(statsPanel, {alpha: 0.78}, 0.45, {ease: FlxEase.quartOut, startDelay: 0.4});

		FlxTween.tween(graphNote, {alpha: 1}, 0.45, {ease: FlxEase.quartOut, startDelay: 0.45});

		for (i in 0...leftTextGroup.members.length)
			FlxTween.tween(leftTextGroup.members[i], {alpha: 1}, 0.25, {startDelay: 0.5 + i * 0.025, ease: FlxEase.quartOut});

		new FlxTimer().start(0.7, function(_) {
			for (i in 0...barBGGroup.members.length)
				FlxTween.tween(barBGGroup.members[i], {alpha: 1}, 0.2);
			for (i in 0...barGroup.members.length)
				barTween(barGroup.members[i], i);
			for (i in 0...barTextGroup.members.length)
				FlxTween.tween(barTextGroup.members[i], {alpha: 1}, 0.25, {startDelay: i * 0.05});
		});

		new FlxTimer().start(0.9, function(_) {
			FlxTween.tween(continueBtn, {alpha: 1}, 0.35);
			FlxTween.tween(continueTxt, {alpha: 1}, 0.35);
			FlxTween.tween(replayBtn, {alpha: 1}, 0.35);
			FlxTween.tween(replayTxt, {alpha: 1}, 0.35);
			FlxTween.tween(instructions, {alpha: 1}, 0.35);
		});
	}

	function createRoundedPanel(x:Float, y:Float, width:Int, height:Int, color:FlxColor):FlxSprite
	{
		var panel = new FlxSprite(x, y).makeGraphic(width, height, FlxColor.TRANSPARENT);
		FlxSpriteUtil.drawRoundRect(panel, 0, 0, width, height, 18, 18, color, {thickness: 0, color: FlxColor.TRANSPARENT});
		panel.alpha = 0;
		return panel;
	}

	function createButton(x:Float, y:Float, w:Int, h:Int, color:FlxColor):FlxSprite
	{
		var btn = new FlxSprite(x, y).makeGraphic(w, h, FlxColor.TRANSPARENT);
		FlxSpriteUtil.drawRoundRect(btn, 0, 0, w, h, 14, 14, color, {thickness: 0, color: FlxColor.TRANSPARENT});
		FlxSpriteUtil.drawRoundRect(btn, 2, 2, w - 4, h - 4, 12, 12, FlxColor.fromRGB(22, 25, 34), {thickness: 0, color: FlxColor.TRANSPARENT});
		return btn;
	}

	function centerTextOnButton(txt:FlxText, btn:FlxSprite)
	{
		txt.x = btn.x + (btn.width - txt.width) / 2;
		txt.y = btn.y + (btn.height - txt.height) / 2 - 2;
	}

	function buildLeftInfo(game:PlayState)
	{
		var isReplay = PlayState.replayMode;

		// Get best saved stats for comparison
		var best:ScoreEntry = null;
		if (isReplay)
		{
			var history = Allscore.getHistory(PlayState.SONG.song, PlayState.storyDifficulty);
			if (history.length > 0)
				best = history[0];
		}

		function fmtDev(current:Int, bestVal:Int):String
		{
			if (best == null) return Std.string(current);
			var diff = current - bestVal;
			var sign = (diff >= 0) ? "+" : "";
			return current + " (" + sign + diff + ")";
		}

		var items:Array<{label:String, value:String, color:FlxColor}> = [];

		items.push({label: Language.get("ResultsScreen.score", "Score"), value: "0", color: FlxColor.fromRGB(255, 215, 0)});
		items.push({label: Language.get("ResultsScreen.accuracy", "Accuracy"), value: "0.00%", color: FlxColor.WHITE});
		items.push({label: Language.get("ResultsScreen.grade", "Grade"), value: game.ratingName + (game.ratingFC != "" ? " - " + game.ratingFC : ""), color: getGradeColor(game.ratingName)});
		items.push({label: Language.get("ResultsScreen.maxCombo", "Max Combo"), value: fmtDev(game.maxcombo, best != null ? best.maxCombo : 0), color: FlxColor.WHITE});
		items.push({label: Language.get("ResultsScreen.hits", "Hits"), value: Std.string(game.songHits), color: FlxColor.WHITE});
		items.push({label: Language.get("ResultsScreen.comboBreaks", "Combo Breaks"), value: Std.string(game.songMisses), color: FlxColor.fromRGB(255, 100, 100)});

		items.push({label: "", value: "", color: FlxColor.WHITE});

		items.push({label: Language.get("ResultsScreen.sicks", "Sicks"), value: fmtDev(game.sicks, best != null ? best.sicks : 0), color: FlxColor.fromRGB(0, 255, 255)});
		items.push({label: Language.get("ResultsScreen.goods", "Goods"), value: fmtDev(game.goods, best != null ? best.goods : 0), color: FlxColor.WHITE});
		items.push({label: Language.get("ResultsScreen.bads", "Bads"), value: fmtDev(game.bads, best != null ? best.bads : 0), color: FlxColor.GRAY});
		items.push({label: Language.get("ResultsScreen.shits", "Shits"), value: fmtDev(game.shits, best != null ? best.shits : 0), color: FlxColor.GRAY});
		items.push({label: Language.get("ResultsScreen.misses", "Misses"), value: fmtDev(game.songMisses, best != null ? best.misses : 0), color: FlxColor.fromRGB(255, 100, 100)});

		items.push({label: "", value: "", color: FlxColor.WHITE});

		items.push({label: Language.get("ResultsScreen.songSpeed", "Song Speed"), value: Std.string(game.songSpeed), color: FlxColor.fromRGB(200, 200, 200)});
		items.push({label: Language.get("ResultsScreen.playbackRate", "Playback Rate"), value: "x" + game.playbackRate, color: FlxColor.fromRGB(200, 200, 200)});

		var botplayStr = game.cpuControlled
			? Language.get("ResultsScreen.on", "ON")
			: Language.get("ResultsScreen.off", "OFF");
		var practiceStr = game.practiceMode
			? Language.get("ResultsScreen.on", "ON")
			: Language.get("ResultsScreen.off", "OFF");
		var instakillStr = game.instakillOnMiss
			? Language.get("ResultsScreen.on", "ON")
			: Language.get("ResultsScreen.off", "OFF");

		items.push({label: Language.get("ResultsScreen.botplay", "Botplay"), value: botplayStr, color: game.cpuControlled ? FlxColor.fromRGB(255, 165, 0) : FlxColor.GRAY});
		items.push({label: Language.get("ResultsScreen.practice", "Practice"), value: practiceStr, color: game.practiceMode ? FlxColor.GREEN : FlxColor.GRAY});
		items.push({label: Language.get("ResultsScreen.instakill", "Instakill"), value: instakillStr, color: game.instakillOnMiss ? FlxColor.RED : FlxColor.GRAY});

		// --- Build left column text ---
		var startY:Float = leftPanel.y + 16;
		var lineH:Float = 22;
		for (i in 0...items.length)
		{
			var item = items[i];
			if (item.label == "" && item.value == "")
				continue;

			var labelX:Float = leftPanel.x + 18;
			var y:Float = startY + i * lineH;

			var labelTxt = new FlxText(labelX, y, 145, item.label + ":", 16);
			labelTxt.setFormat(Paths.languageFont(), 16, FlxColor.fromRGB(140, 150, 160), LEFT);
			labelTxt.alpha = 0;
			leftTextGroup.add(labelTxt);

			var valTxt = new FlxText(labelX + 150, y, 400, item.value, 16);
			valTxt.setFormat(Paths.languageFont(), 16, item.color, LEFT);
			valTxt.alpha = 0;
			leftTextGroup.add(valTxt);
		}

		// --- Status footer: starts at second column (value column) x ---
		var statusY:Float = leftPanel.y + leftPanel.height - 95;
		var statusX:Float = leftPanel.x + 290; // third column, separate from label/value grid
		var statusLineH:Float = 15;

		function addStatusLine(idx:Int, text:String, color:FlxColor)
		{
			var y = statusY + idx * statusLineH;
			var t = new FlxText(statusX, y, 390, text, 13);
			t.setFormat(Paths.languageFont(), 13, color, LEFT);
			t.alpha = 0;
			leftTextGroup.add(t);
		}

		var si:Int = 0;

		// Judgment window info (always shown)
		var judgeInfo = Language.get("ResultsScreen.judgeWindows", "Judge") + ": "
			+ Std.string(ClientPrefs.data.sickWindow) + " / "
			+ Std.string(ClientPrefs.data.goodWindow) + " / "
			+ Std.string(ClientPrefs.data.badWindow) + " / "
			+ Std.string(ClientPrefs.data.safeFrames) + "f";
		addStatusLine(si++, judgeInfo, FlxColor.fromRGB(180, 180, 200));

		var shouldSave = !isReplay && !game.practiceMode && !game.cpuControlled && !PlayState.chartingMode;
		var validScore = shouldSave && (PlayState.SONG.validScore || PlayState.SONG.validScore == null);
		addStatusLine(si++, Language.get("ResultsScreen.validScore", "Valid") + ": "
			+ (validScore ? Language.get("ResultsScreen.yes", "YES") : Language.get("ResultsScreen.no", "NO")),
			validScore ? FlxColor.GREEN : FlxColor.RED);

		var replaySaved = shouldSave && (game.replayExam != null && game.replayExam.getFrameData().length > 0);
		addStatusLine(si++, Language.get("ResultsScreen.replaySaved", "Saved") + ": "
			+ (replaySaved ? Language.get("ResultsScreen.yes", "YES") : Language.get("ResultsScreen.no", "NO")),
			replaySaved ? FlxColor.GREEN : FlxColor.GRAY);

		if (isReplay)
		{
			addStatusLine(si++, Language.get("ResultsScreen.mode", "Mode") + ": "
				+ Language.get("ResultsScreen.replayMode", "REPLAY"),
				FlxColor.fromRGB(255, 200, 100));
		}

		if (best != null)
		{
			var scoreDiff = game.songScore - best.score;
			var curAcc:Float = (Math.isNaN(game.ratingPercent) || game.ratingPercent < 0) ? 0 : game.ratingPercent;
			var bestAcc:Float = (Math.isNaN(best.ratingPercent) || best.ratingPercent < 0) ? 0 : best.ratingPercent;
			var accDiff = (curAcc * 100) - (bestAcc * 100);
			var scoreSign = (scoreDiff >= 0) ? "+" : "";
			var accSign = (accDiff >= 0) ? "+" : "";
			addStatusLine(si++, Language.get("ResultsScreen.overallDeviation", "Diff") + ": "
				+ scoreSign + scoreDiff + "pts / " + accSign + Highscore.floorDecimal(accDiff, 2) + "%",
				(scoreDiff >= 0) ? FlxColor.GREEN : FlxColor.RED);
		}
	}

	function buildHitBars(game:PlayState)
	{
		var totalNotes = game.sicks + game.goods + game.bads + game.shits + game.songMisses;
		if (totalNotes <= 0) totalNotes = 1;

		var barMaxW:Int = Std.int(statsPanel.width - 175);
		var barH:Int = 18;
		var barX:Float = statsPanel.x + 18;
		var startY:Float = statsPanel.y + 14;
		var gap:Float = 10;

		var counts:Array<Int> = [game.sicks, game.goods, game.bads, game.shits, game.songMisses];

		for (i in 0...5)
		{
			var y:Float = startY + i * (barH + gap);

			var barBG = new FlxSprite(barX, y).makeGraphic(barMaxW, barH, FlxColor.fromRGB(32, 35, 45));
			barBG.alpha = 0;
			barBGGroup.add(barBG);

			var w:Int = Math.ceil(barMaxW * (counts[i] / totalNotes));
			if (w < 2 && counts[i] > 0) w = 2;

			var bar = new FlxSprite(barX, y).makeGraphic(w, barH, hitColorArray[i]);
			bar.alpha = 0;
			barGroup.add(bar);

			var percent = Math.ceil(counts[i] / totalNotes * 10000) / 100;
			var hitLabel = Language.get("ResultsScreen." + hitNames[i].toLowerCase(), hitNames[i]);
			var barTxt = new FlxText(barX + barMaxW + 10, y - 1, 155, hitLabel + ": " + counts[i] + " (" + percent + "%)", 15);
			barTxt.setFormat(Paths.languageFont(), 15, hitColorArray[i], LEFT);
			barTxt.alpha = 0;
			barTextGroup.add(barTxt);
		}
	}

	function barTween(sprite:FlxSprite, index:Int)
	{
		sprite.scale.x = 0.001;
		sprite.alpha = 1;
		new FlxTimer().start(0.01 * index, function(_) {
			FlxTween.tween(sprite.scale, {x: 1}, 0.4, {ease: FlxEase.quartOut});
		});
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

	function getRatingIconName(ratingPercent:Float, ratingFC:String, sicks:Int, goods:Int, bads:Int, shits:Int, misses:Int):String
	{
		var totalNotes:Float = sicks + goods + bads + shits + misses;
		if (totalNotes <= 0) return "FALSE";
		if (ratingPercent >= 1.0) return "phi";
		if (ratingPercent >= 0.95 && misses == 0 && bads == 0 && shits == 0) return "fc v";
		if (ratingPercent >= 0.95 && misses == 0) return "v";
		if (ratingPercent >= 0.9) return "v";
		if (ratingPercent >= 0.8) return "s";
		if (ratingPercent >= 0.7) return "a";
		if (ratingPercent >= 0.6) return "b";
		if (ratingPercent >= 0.4) return "c";
		if (ratingPercent >= 0.2) return "f";
		return "false";
	}

	function showRatingIcon()
	{
		if (ratingIconTween != null) ratingIconTween.cancel();
		var game = PlayState.instance;
		if (game == null) return;

		// [CRASH FIX] Guard against NaN ratingPercent
		var safePercent:Float = (Math.isNaN(game.ratingPercent) || game.ratingPercent < 0) ? 0 : game.ratingPercent;
		var iconName = getRatingIconName(safePercent, game.ratingFC, game.sicks, game.goods, game.bads, game.shits, game.songMisses);
		if (Paths.fileExists("images/freeplayr/" + iconName + ".png", IMAGE))
			ratingIcon.loadGraphic(Paths.image("freeplayr/" + iconName));
		else
			ratingIcon.loadGraphic(Paths.image("freeplayr/FALSE"));
		ratingIcon.setGraphicSize(Std.int(ratingIcon.width * 0.6));
		ratingIcon.updateHitbox();
		ratingIcon.x = leftPanel.x + leftPanel.width - ratingIcon.width - 20;
		ratingIcon.y = leftPanel.y + leftPanel.height - ratingIcon.height - 20;
		ratingIcon.visible = true;
		ratingIcon.alpha = 0;
		ratingIconTween = FlxTween.tween(ratingIcon, {alpha: 1}, 0.5, {ease: FlxEase.backOut});
	}

	function graphNoteDraw()
	{
		// [CRASH FIX] Guard against zero/negative dimensions
		if (graphNote.width <= 0 || graphNote.height <= 0) return;

		var sickWindow = ClientPrefs.data.sickWindow;
		var goodWindow = ClientPrefs.data.goodWindow;
		var badWindow = ClientPrefs.data.badWindow;

		var drawX:Float = 0;
		var drawW:Float = graphNote.width;
		var drawH:Float = graphNote.height;

		// [CRASH FIX] Use try-catch to prevent crashes on devices that don't support FlxSpriteUtil drawing
		try
		{
			// Fill with dark background first (solid color avoids alpha-only bitmap issues on some GPUs)
			FlxSpriteUtil.fill(graphNote, FlxColor.fromRGB(10, 12, 22));
			// beginDraw requires FillColor + optional lineStyle
			FlxSpriteUtil.beginDraw(FlxColor.TRANSPARENT);

			var noteSize:Float = 2.2;
			var moveSize:Float = 0.8;
			var len:Int = (noteTime != null && noteMs != null) ? Math.floor(Math.min(noteTime.length, noteMs.length)) : 0;

			for (i in 0...len)
			{
				if (songLength <= 0) continue;

				var msAbs = Math.abs(noteMs[i]);
				var color:FlxColor;

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

				var timeFrac:Float = noteTime[i] / songLength;
				if (timeFrac < 0) timeFrac = 0;
				if (timeFrac > 1) timeFrac = 1;

				var x:Float = drawX + drawW * timeFrac;
				var y:Float;

				if (msAbs <= safeZoneOffset)
					y = drawH * 0.5 + drawH * 0.5 * moveSize * (noteMs[i] / safeZoneOffset);
				else
					y = drawH * 0.5 + drawH * 0.5 * 0.9;

				FlxSpriteUtil.drawCircle(graphNote, x, y, noteSize, color);
			}

			// center line
			FlxSpriteUtil.drawRect(graphNote, drawX, drawH * 0.5 - 1, drawW, 2, 0x7FFFFFFF);

			// sick window
			var sy = drawH * 0.5 + drawH * 0.5 * moveSize * (sickWindow / safeZoneOffset) - 1;
			FlxSpriteUtil.drawRect(graphNote, drawX, sy, drawW, 2, 0x7F00FFFF);
			FlxSpriteUtil.drawRect(graphNote, drawX, drawH * 0.5 - (sy - drawH * 0.5) - 1, drawW, 2, 0x7F00FFFF);

			// good window
			if (sickWindow <= goodWindow)
			{
				var gy = drawH * 0.5 + drawH * 0.5 * moveSize * (goodWindow / safeZoneOffset) - 1;
				FlxSpriteUtil.drawRect(graphNote, drawX, gy, drawW, 2, 0x7F00FF00);
				FlxSpriteUtil.drawRect(graphNote, drawX, drawH * 0.5 - (gy - drawH * 0.5) - 1, drawW, 2, 0x7F00FF00);
			}

			// bad window
			if (sickWindow <= badWindow || goodWindow <= badWindow)
			{
				var by = drawH * 0.5 + drawH * 0.5 * moveSize * (badWindow / safeZoneOffset) - 1;
				FlxSpriteUtil.drawRect(graphNote, drawX, by, drawW, 2, 0x7FFF7F00);
				FlxSpriteUtil.drawRect(graphNote, drawX, drawH * 0.5 - (by - drawH * 0.5) - 1, drawW, 2, 0x7FFF7F00);
			}

			// shit boundary
			var shitY = drawH * 0.5 + drawH * 0.5 * moveSize - 1;
			FlxSpriteUtil.drawRect(graphNote, drawX, shitY, drawW, 2, 0x7FFF5858);
			FlxSpriteUtil.drawRect(graphNote, drawX, drawH * 0.5 - (shitY - drawH * 0.5) - 1, drawW, 2, 0x7FFF5858);

			// miss boundary
			var missY = drawH * 0.5 + drawH * 0.5 * 0.9 - 1;
			FlxSpriteUtil.drawRect(graphNote, drawX, missY, drawW, 2, 0x7FFF0000);

			FlxSpriteUtil.endDraw(graphNote);

			graphNote.updateHitbox();
		}
		catch (e:Dynamic)
		{
			CoolUtil.traceMsg('trace.resultsGraphError', 'Failed to draw results graph: {}', [Std.string(e)]);
			// If graph drawing fails, just fill with a dark background
			try { FlxSpriteUtil.fill(graphNote, FlxColor.fromRGB(10, 12, 22)); } catch (_:Dynamic) {}
			try { FlxSpriteUtil.endDraw(graphNote); } catch (_:Dynamic) {}
		}
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (!scoreAnimDone)
		{
			if (Math.abs(displayedScore - targetScore) > 10)
				displayedScore = Math.floor(FlxMath.lerp(displayedScore, targetScore, CoolUtil.boundTo(elapsed * 28, 0, 1)));
			else if (displayedScore != targetScore)
				displayedScore = targetScore;

			if (Math.abs(displayedAccuracy - targetAccuracy) > 0.01)
				displayedAccuracy = FlxMath.lerp(displayedAccuracy, targetAccuracy, CoolUtil.boundTo(elapsed * 14, 0, 1));
			else if (displayedAccuracy != targetAccuracy)
				displayedAccuracy = targetAccuracy;

			if (leftTextGroup.members.length > 1)
				leftTextGroup.members[1].text = Std.string(displayedScore);
			if (leftTextGroup.members.length > 3)
				leftTextGroup.members[3].text = Highscore.floorDecimal(displayedAccuracy, 2) + "%";

			if (displayedScore == targetScore && Math.abs(displayedAccuracy - targetAccuracy) <= 0.01)
			{
				scoreAnimDone = true;
				showRatingIcon();
			}
		}

		if (closeCheck) return;

		if (FlxG.keys.justPressed.ESCAPE #if android || FlxG.android.justReleased.BACK #end)
		{
			doContinue();
			return;
		}

		if (controls.ACCEPT)
		{
			if (confirmContinue)
				doContinue();
			else if (confirmReplay)
				doReplay();
			else
				confirmContinueSelection();
			return;
		}

		if (controls.UI_LEFT_P || controls.UI_RIGHT_P)
		{
			if (confirmContinue)
				confirmReplaySelection();
			else
				confirmContinueSelection();
		}

		// Desktop mouse: use manual AABB check in substate camera world space
		// to avoid PlayState camera scroll/zoom offsetting hit positions.
		var cam = (substateCam != null) ? substateCam : FlxG.camera;
		if (FlxG.mouse.justPressed)
		{
			var mousePt = FlxG.mouse.getWorldPosition(cam, flixel.math.FlxPoint.get());
			if (overlapsInSubstateCam(continueBtn, mousePt.x, mousePt.y))
			{
				mousePt.put();
				confirmContinueSelection();
			}
			else if (overlapsInSubstateCam(replayBtn, mousePt.x, mousePt.y))
			{
				mousePt.put();
				confirmReplaySelection();
			}
			else
				mousePt.put();
		}

		#if mobile
		if (touchOverlapsButton(continueBtn))
			confirmContinueSelection();
		if (touchOverlapsButton(replayBtn))
			confirmReplaySelection();
		#end
	}

	function swapSelection()
	{
		if (confirmContinue)
			confirmReplaySelection();
		else
			confirmContinueSelection();
	}

	function confirmContinueSelection()
	{
		if (confirmContinue)
		{
			doContinue();
		}
		else
		{
			confirmContinue = true;
			confirmReplay = false;
			updateButtonHighlights();
			FlxG.sound.play(Paths.sound('scrollMenu'));

			new FlxTimer().start(1.5, function(_) {
				if (confirmContinue && !closeCheck)
				{
					confirmContinue = false;
					updateButtonHighlights();
				}
			});
		}
	}

	function confirmReplaySelection()
	{
		if (confirmReplay)
		{
			doReplay();
		}
		else
		{
			confirmReplay = true;
			confirmContinue = false;
			updateButtonHighlights();
			FlxG.sound.play(Paths.sound('scrollMenu'));

			new FlxTimer().start(1.5, function(_) {
				if (confirmReplay && !closeCheck)
				{
					confirmReplay = false;
					updateButtonHighlights();
				}
			});
		}
	}

	function updateButtonHighlights()
	{
		continueTxt.text = confirmContinue
			? "> " + Language.get("ResultsScreen.continue", "CONTINUE") + " <"
			: Language.get("ResultsScreen.continue", "CONTINUE");
		continueTxt.x = continueBtn.x + (continueBtn.width - continueTxt.width) / 2;

		replayTxt.text = confirmReplay
			? "> " + Language.get("ResultsScreen.replay", "REPLAY") + " <"
			: Language.get("ResultsScreen.replay", "REPLAY");
		replayTxt.x = replayBtn.x + (replayBtn.width - replayTxt.width) / 2;
	}

	function doContinue()
	{
		if (closeCheck) return;
		closeCheck = true;
		exitAndGo(false);
	}

	function doReplay()
	{
		if (closeCheck) return;
		closeCheck = true;
		exitAndGo(true);
	}

	function exitAndGo(replay:Bool)
	{
		FlxTween.tween(titleTxt, {alpha: 0}, 0.2);
		FlxTween.tween(leftPanel, {alpha: 0}, 0.2);
		FlxTween.tween(graphPanel, {alpha: 0}, 0.2);
		FlxTween.tween(statsPanel, {alpha: 0}, 0.2);
		FlxTween.tween(graphNote, {alpha: 0}, 0.18);
		FlxTween.tween(ratingIcon, {alpha: 0}, 0.18);
		FlxTween.tween(continueBtn, {alpha: 0}, 0.18);
		FlxTween.tween(continueTxt, {alpha: 0}, 0.18);
		FlxTween.tween(replayBtn, {alpha: 0}, 0.18);
		FlxTween.tween(replayTxt, {alpha: 0}, 0.18);

		for (item in leftTextGroup.members)
			FlxTween.tween(item, {alpha: 0}, 0.12);
		for (item in barBGGroup.members)
			FlxTween.tween(item, {alpha: 0}, 0.12);
		for (item in barGroup.members)
			FlxTween.tween(item, {alpha: 0}, 0.12);
		for (item in barTextGroup.members)
			FlxTween.tween(item, {alpha: 0}, 0.12);

		FlxG.sound.play(Paths.sound('cancelMenu'));

		new FlxTimer().start(0.25, function(_) {
			close();

			var game = PlayState.instance;
			game.playbackRate = 1;

			if (replay)
			{
				PlayState.replayMode = true;
				PlayState.isStoryMode = false;

				// Load the most recent history entry so PauseSubState can show replay info
				var history = Allscore.getHistory(PlayState.SONG.song, PlayState.storyDifficulty);
				if (history.length > 0)
				{
					PauseSubState.entries = history[0];

					// 准备回放文件: 将存储的 replay 数据转回 FrameSave 并写入临时文件
					#if sys
					var entry = history[0];
					var frames:Array<FrameSave> = [];
					if (entry.replayData != null)
					{
						frames = Replay.dynamicToFrames(entry.replayData);
					}

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

					var tempDir:String = CoolUtil.getReplayTempDir();
					SUtil.mkDirs(tempDir);
					var tempPath:String = tempDir + 'replay_temp.rsd';
					Replay.saveToFile(frames, stateRecord, tempPath);
					Replay.preparedPath = tempPath;
					#end
				}

				var songLowercase:String = Paths.formatToSongPath(PlayState.SONG.song);
				var poop:String = Highscore.formatSong(songLowercase, PlayState.storyDifficulty);
				PlayState.SONG = Song.loadFromJson(poop, songLowercase);
				PlayState.changedDifficulty = false;
				close();
				LoadingState.loadAndSwitchState(new PlayState());
				return;
			}

			if (PlayState.isStoryMode)
			{
				PlayState.campaignScore += game.songScore;
				PlayState.campaignMisses += game.songMisses;
				PlayState.storyPlaylist.remove(PlayState.storyPlaylist[0]);

				if (PlayState.storyPlaylist.length <= 0)
				{
					Paths.currentModDirectory = MainMenuState.selectedModFolder;
					FlxG.sound.playMusic(Paths.music('freakyMenu'));
					PlayState.cancelMusicFadeTween();
					if (FlxTransitionableState.skipNextTransIn)
						CustomFadeTransition.nextCamera = null;
					MusicBeatState.switchState(new StoryMenuState());

					if (!ClientPrefs.getGameplaySetting('practice', false) && !ClientPrefs.getGameplaySetting('botplay', false))
					{
						StoryMenuState.weekCompleted.set(WeekData.weeksList[PlayState.storyWeek], true);
						if (PlayState.SONG.validScore)
							Highscore.saveWeekScore(WeekData.getWeekFileName(), PlayState.campaignScore, PlayState.storyDifficulty);
						FlxG.save.data.weekCompleted = StoryMenuState.weekCompleted;
						FlxG.save.flush();
					}
					PlayState.changedDifficulty = false;
				}
				else
				{
					var difficulty:String = CoolUtil.getDifficultyFilePath();
					FlxTransitionableState.skipNextTransIn = true;
					FlxTransitionableState.skipNextTransOut = true;

					PlayState.SONG = Song.loadFromJson(PlayState.storyPlaylist[0] + difficulty, PlayState.storyPlaylist[0]);
					FlxG.sound.music.stop();
					PlayState.cancelMusicFadeTween();
					LoadingState.loadAndSwitchState(new PlayState());
				}
			}
			else
			{
				Paths.currentModDirectory = MainMenuState.selectedModFolder;
				PlayState.cancelMusicFadeTween();
				if (FlxTransitionableState.skipNextTransIn)
					CustomFadeTransition.nextCamera = null;
				MusicBeatState.switchState(new FreeplayState());
				// 音乐交给 FreeplayState.create() 统一处理（优先使用模组筛选目录）
				PlayState.changedDifficulty = false;
			}
		});
	}
}
