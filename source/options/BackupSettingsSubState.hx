package options;

import backend.MusicBeatSubstate;
import backend.BackupUtil;
import editors.content.FileDialogHandler;
import haxe.Json;
import sys.io.File;
import sys.FileSystem;
import haxe.io.Bytes;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxSpriteUtil;
import flash.net.FileFilter;

#if android
import android.Tools as AndroidTools;
#end

class BackupSettingsSubState extends MusicBeatSubstate
{
	// ── UI ──
	var bg:FlxSprite;
	var titleTxt:FlxText;
	var infoPanel:FlxSprite;
	var infoTxt:FlxText;
	var statusTxt:FlxText;

	var cardExport:FlxSprite;
	var cardImport:FlxSprite;
	var cardExportLabel:FlxText;
	var cardExportDesc:FlxText;
	var cardImportLabel:FlxText;
	var cardImportDesc:FlxText;

	var closeBtn:FlxSprite;
	var closeBtnLabel:FlxText;

	// ── State ──
	var fileDialog:FileDialogHandler;
	static final FILE_FILTER:Array<FileFilter> = [new FileFilter('SeiunEngine Backup (*.SEB)', '*.SEB')];
	var isProcessing:Bool = false;

	static final ACCENT:FlxColor = 0xFF00C8DC;
	static final BG_COLOR:FlxColor = 0x0F1220;
	static final CARD_COLOR:FlxColor = 0x1A1E30;
	static final TEXT_SECONDARY:FlxColor = 0xFFB0B8D0;

	static var androidWarningShown:Bool = false;

	// ═══════════════════════════════════════════════════════════════
	override function create()
	{
		super.create();
		cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];
		buildBackground();
		buildTitle();
		buildInfoPanel();
		buildActionCards();
		buildStatusBar();
		buildCloseButton();
		playIntroAnimations();

		#if android
		if (!androidWarningShown) showAndroidWarning();
		#end
	}

	// ═══════════════════════════════════════════════════════════════
	//  BUILDERS
	// ═══════════════════════════════════════════════════════════════

	function buildBackground()
	{
		bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.fromRGBFloat(0.04, 0.06, 0.12, 0.94));
		bg.alpha = 0;
		add(bg);
	}

	function buildTitle()
	{
		titleTxt = new FlxText(0, 32, FlxG.width,
			Language.get("option.backup.settingsTitle", "Backup & Restore"), 38);
		titleTxt.setFormat(Paths.languageFont(), 38, FlxColor.WHITE, CENTER);
		titleTxt.alpha = 0;
		add(titleTxt);

		var subtitle = new FlxText(0, 78, FlxG.width,
			Language.get("option.backup.rctitle", "Save or load your game data"), 15);
		subtitle.setFormat(Paths.languageFont(), 15, TEXT_SECONDARY, CENTER);
		subtitle.alpha = 0;
		add(subtitle);
	}

	function buildInfoPanel()
	{
		final px = 50;
		final py = 115;
		final pw = Std.int(FlxG.width - 100);
		final ph = 85;

		infoPanel = new FlxSprite(px, py).makeGraphic(pw, ph, FlxColor.TRANSPARENT);
		FlxSpriteUtil.drawRoundRect(infoPanel, 0, 0, pw, ph, 12, 12, BG_COLOR, {thickness: 0});
		infoPanel.alpha = 0;
		add(infoPanel);

		infoTxt = new FlxText(px + 18, py + 12, pw - 36,
			Language.get("DataBackup.info",
				"Backup includes: Highscores, song ratings, settings, keybinds,\n"
				+ "score history, replay data, and week progress.\n"
				+ "Saved as an encrypted .SEB file."), 14);
		infoTxt.setFormat(Paths.languageFont(), 14, TEXT_SECONDARY, LEFT);
		infoTxt.alpha = 0;
		add(infoTxt);
	}

	function buildActionCards()
	{
		final cardW = Std.int(FlxG.width * 0.42);
		final cardH = 190;
		final gap = 30;
		final totalW = cardW * 2 + gap;
		final startX = (FlxG.width - totalW) / 2;
		final cardY = 230;

		cardExport = makeCard(startX, cardY, cardW, cardH);
		cardExport.alpha = 0;
		add(cardExport);

		cardExportLabel = new FlxText(startX + 20, cardY + 18, cardW - 40,
			Language.get("option.backup.export", "Backup Data"), 24);
		cardExportLabel.setFormat(Paths.languageFont(), 24, FlxColor.WHITE, LEFT);
		cardExportLabel.alpha = 0;
		add(cardExportLabel);

		cardExportDesc = new FlxText(startX + 20, cardY + 55, cardW - 40,
			Language.get("option.backup.export.desc",
				"Export all game data to a single encrypted backup file."), 14);
		cardExportDesc.setFormat(Paths.languageFont(), 14, TEXT_SECONDARY, LEFT);
		cardExportDesc.alpha = 0;
		add(cardExportDesc);

		var exportIconLbl = new FlxText(startX + cardW - 70, cardY + cardH - 56, 60, "⬆", 32);
		exportIconLbl.setFormat(Paths.languageFont(), 32, ACCENT, CENTER);
		exportIconLbl.alpha = 0;
		add(exportIconLbl);

		cardImport = makeCard(startX + cardW + gap, cardY, cardW, cardH);
		cardImport.alpha = 0;
		add(cardImport);

		cardImportLabel = new FlxText(startX + cardW + gap + 20, cardY + 18, cardW - 40,
			Language.get("option.backup.import", "Restore Data"), 24);
		cardImportLabel.setFormat(Paths.languageFont(), 24, FlxColor.WHITE, LEFT);
		cardImportLabel.alpha = 0;
		add(cardImportLabel);

		cardImportDesc = new FlxText(startX + cardW + gap + 20, cardY + 55, cardW - 40,
			Language.get("option.backup.import.desc",
				"Restore all game data from a previously created backup file."), 14);
		cardImportDesc.setFormat(Paths.languageFont(), 14, TEXT_SECONDARY, LEFT);
		cardImportDesc.alpha = 0;
		add(cardImportDesc);

		var importIconLbl = new FlxText(startX + cardW + gap + cardW - 70, cardY + cardH - 56, 60, "⬇", 32);
		importIconLbl.setFormat(Paths.languageFont(), 32, ACCENT, CENTER);
		importIconLbl.alpha = 0;
		add(importIconLbl);

		#if android
		var warnY = cardY + cardH + 16;
		var warnBar = new FlxSprite(startX, warnY).makeGraphic(Std.int(totalW), 4, FlxColor.fromRGB(255, 200, 50));
		warnBar.alpha = 0;
		add(warnBar);
		var warnTxt = new FlxText(startX, warnY + 8, totalW,
			"⚠ " + Language.get("DataBackup.androidWarning.title",
				"Android: Backup before uninstalling! Data will be lost."), 14);
		warnTxt.setFormat(Paths.languageFont(), 14, FlxColor.fromRGB(255, 200, 50), CENTER);
		warnTxt.alpha = 0;
		add(warnTxt);
		#end
	}

	function buildStatusBar()
	{
		statusTxt = new FlxText(50, FlxG.height - 90, FlxG.width - 100, "", 15);
		statusTxt.setFormat(Paths.languageFont(), 15, TEXT_SECONDARY, CENTER);
		statusTxt.alpha = 0;
		add(statusTxt);
	}

	function buildCloseButton()
	{
		final bw = 160;
		final bh = 40;
		final bx = (FlxG.width - bw) / 2;
		final by = FlxG.height - 55;

		closeBtn = new FlxSprite(bx, by).makeGraphic(bw, bh, FlxColor.TRANSPARENT);
		FlxSpriteUtil.drawRoundRect(closeBtn, 0, 0, bw, bh, 8, 8, 0xFF3A4050, {thickness: 0});
		closeBtn.alpha = 0;
		add(closeBtn);

		closeBtnLabel = new FlxText(0, 0, bw,
			Language.get("DataBackup.close", "✕  CLOSE"), 18);
		closeBtnLabel.setFormat(Paths.languageFont(), 18, FlxColor.WHITE, CENTER);
		closeBtnLabel.alpha = 0;
		add(closeBtnLabel);
		centerLabel(closeBtnLabel, closeBtn);
	}

	function playIntroAnimations()
	{
		FlxTween.tween(bg, {alpha: 1}, 0.35, {ease: FlxEase.quartOut});
		FlxTween.tween(titleTxt, {alpha: 1}, 0.3, {ease: FlxEase.quartOut, startDelay: 0.08});
		FlxTween.tween(infoPanel, {alpha: 0.5}, 0.3, {ease: FlxEase.quartOut, startDelay: 0.12});
		FlxTween.tween(infoTxt, {alpha: 1}, 0.3, {ease: FlxEase.quartOut, startDelay: 0.15});
		FlxTween.tween(cardExport, {alpha: 0.55}, 0.35, {ease: FlxEase.quartOut, startDelay: 0.2});
		FlxTween.tween(cardExportLabel, {alpha: 1}, 0.3, {ease: FlxEase.quartOut, startDelay: 0.25});
		FlxTween.tween(cardExportDesc, {alpha: 1}, 0.3, {ease: FlxEase.quartOut, startDelay: 0.28});
		FlxTween.tween(cardImport, {alpha: 0.55}, 0.35, {ease: FlxEase.quartOut, startDelay: 0.25});
		FlxTween.tween(cardImportLabel, {alpha: 1}, 0.3, {ease: FlxEase.quartOut, startDelay: 0.3});
		FlxTween.tween(cardImportDesc, {alpha: 1}, 0.3, {ease: FlxEase.quartOut, startDelay: 0.33});
		FlxTween.tween(closeBtn, {alpha: 0.6}, 0.3, {ease: FlxEase.quartOut, startDelay: 0.35});
		FlxTween.tween(closeBtnLabel, {alpha: 1}, 0.3, {ease: FlxEase.quartOut, startDelay: 0.38});
		FlxTween.tween(statusTxt, {alpha: 1}, 0.3, {ease: FlxEase.quartOut, startDelay: 0.4});
	}

	// ═══════════════════════════════════════════════════════════════
	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if (isProcessing) return;

		if (FlxG.mouse.justPressed)
		{
			if (overlapsCard(cardExport)) { doExport(); return; }
			if (overlapsCard(cardImport)) { doImport(); return; }
			if (FlxG.mouse.overlaps(closeBtn, FlxG.camera)) { doClose(); return; }
		}
		if (controls.ACCEPT) doExport();
		if (controls.BACK) doClose();
	}

	// ═══════════════════════════════════════════════════════════════
	//  EXPORT
	// ═══════════════════════════════════════════════════════════════

	function doExport()
	{
		if (isProcessing) return;
		isProcessing = true;
		setStatus(Language.get("DataBackup.collecting", "Collecting game data..."), 0xFFCCCC00);

		new FlxTimer().start(0.05, function(_) {
			try
			{
				var data:Dynamic = BackupUtil.collectGameData();
				var packed:Bytes = BackupUtil.encryptAndPack(data);
				var b64 = base64Encode(packed);

				ensureFileDialog();
				var ts = Date.now().toString().split(" ").join("_").split(":").join("-");
				fileDialog.save('SeiunEngine_Backup_$ts.SEB', b64, function() {
					var savePath:String = (fileDialog.path != null) ? fileDialog.path : "Unknown";
					onExportSuccess(savePath);
				}, function() {
					setStatus(Language.get("DataBackup.cancelled", "Cancelled."), TEXT_SECONDARY);
					isProcessing = false;
				}, function() {
					setStatus(Language.get("DataBackup.error.message", "Failed to save backup!"), 0xFFFF4444);
					isProcessing = false;
				});
			}
			catch (e:Dynamic)
			{
				setStatus('${Language.get("DataBackup.error.message", "Error")}: ${Std.string(e)}', 0xFFFF4444);
				isProcessing = false;
			}
		});
	}

	function onExportSuccess(savePath:String)
	{
		var msg = Language.get("DataBackup.success.message",
			"Game data has been successfully backed up!\n\nFile saved to:\n{path}")
			.replace("{path}", savePath);

		#if android
		AndroidTools.showAlertDialog(
			Language.get("DataBackup.success.title", "Success"),
			msg, {name: "OK", func: null}, null);
		#else
		backend.Dialog.show(
			Language.get("DataBackup.success.title", "Success"),
			msg, 'Info');
		#end

		setStatus(Language.get("DataBackup.success.title", "✅ Backup saved!"), 0xFF00CC00);
		isProcessing = false;
	}

	// ═══════════════════════════════════════════════════════════════
	//  IMPORT
	// ═══════════════════════════════════════════════════════════════

	function doImport()
	{
		if (isProcessing) return;
		isProcessing = true;
		setStatus(Language.get("DataBackup.selectFile", "Select a backup file..."), 0xFF00CCCC);

		ensureFileDialog();
		fileDialog.open(null, null, FILE_FILTER, function() {
			onFileSelected();
		}, function() {
			setStatus(Language.get("DataBackup.cancelled", "Cancelled."), TEXT_SECONDARY);
			isProcessing = false;
		}, function() {
			setStatus(Language.get("DataBackup.error.fileError", "Failed to read file!"), 0xFFFF4444);
			isProcessing = false;
		});
	}

	function onFileSelected()
	{
		// Try fileDialog.data first (content as string), fallback to reading from path
		var raw:String = fileDialog.data;
		if (raw == null || raw == "")
		{
			var path:String = fileDialog.path;
			if (path == null || path == "")
			{
				setStatus(Language.get("DataBackup.error.empty", "Empty or invalid file!"), 0xFFFF4444);
				isProcessing = false;
				return;
			}
			try { raw = File.getContent(path); } catch (e:Dynamic) {}
		}

		if (raw == null || raw == "")
		{
			setStatus(Language.get("DataBackup.error.empty", "Empty or invalid file!"), 0xFFFF4444);
			isProcessing = false;
			return;
		}

		setStatus(Language.get("DataBackup.decrypting", "Decrypting backup..."), 0xFFCCCC00);

		new FlxTimer().start(0.05, function(_) {
			try
			{
				var packed:Bytes = base64Decode(raw);
				if (packed == null)
				{
					setStatus(Language.get("DataBackup.error.invalidFile", "Invalid or corrupted backup!"), 0xFFFF4444);
					isProcessing = false;
					return;
				}

				var data:Dynamic = BackupUtil.decryptAndUnpack(packed);
				if (data == null)
				{
					setStatus(Language.get("DataBackup.error.invalidFile", "Invalid or corrupted backup!"), 0xFFFF4444);
					isProcessing = false;
					return;
				}

				var backupDate:String = (data.timestamp != null) ? data.timestamp : "Unknown";
				showRestoreConfirm(data, backupDate);
			}
			catch (e:Dynamic)
			{
				setStatus('${Language.get("DataBackup.error.fileError", "Read error")}: ${Std.string(e)}', 0xFFFF4444);
				isProcessing = false;
			}
		});
	}

	function showRestoreConfirm(data:Dynamic, backupDate:String)
	{
		setStatus("", TEXT_SECONDARY);

		var confirmTitle = Language.get("DataBackup.confirm.title", "Restore Data?");
		var confirmMsg = Language.get("DataBackup.confirm.message",
			"This will overwrite ALL current game data.\n\nBackup date: {date}\n\nThis cannot be undone! Continue?")
			.replace("{date}", backupDate);

		#if android
		AndroidTools.showAlertDialog(confirmTitle, confirmMsg,
			{name: Language.get("DataBackup.yes", "Yes"), func: function() { doRestore(data); }},
			{name: Language.get("DataBackup.no", "No"), func: function() {
				setStatus(Language.get("DataBackup.cancelled", "Cancelled."), TEXT_SECONDARY);
				isProcessing = false;
			}});
		#else
		backend.Dialog.showYesNo(confirmTitle, confirmMsg,
			function() { doRestore(data); },
			function() {
				setStatus(Language.get("DataBackup.cancelled", "Cancelled."), TEXT_SECONDARY);
				isProcessing = false;
			});
		#end
	}

	// ═══════════════════════════════════════════════════════════════
	//  RESTORE — writes data to disk AND forces full in-memory reload
	// ═══════════════════════════════════════════════════════════════

	function doRestore(data:Dynamic)
	{
		setStatus(Language.get("DataBackup.restoring", "Restoring data..."), 0xFFCCCC00);

		new FlxTimer().start(0.05, function(_) {
			try
			{
				var ok = BackupUtil.restoreFromBackup(data);
				if (!ok)
				{
					setStatus(Language.get("DataBackup.error.restoreFailed", "Restore failed!"), 0xFFFF4444);
					isProcessing = false;
					return;
				}

				// Force full reload from disk
				FlxG.save.bind('funkin', 'ninjamuffin99');
				Highscore.load();
				Allscore.load();
				ClientPrefs.loadPrefs();
				ClientPrefs.reloadControls();

				// Persist controls_v2 save (keybinds)
				var controlsSave = new flixel.util.FlxSave();
				controlsSave.bind('controls_v2', 'ninjamuffin99');
				controlsSave.data.customControls = ClientPrefs.keyBinds;
				controlsSave.flush();
				controlsSave.destroy();

				// Reload language so new locale takes effect immediately
				Language.load();

				FlxG.sound.play(Paths.sound('confirmMenu'));
				setStatus(Language.get("DataBackup.restored.status", "✅ Data restored! Reloading..."), 0xFF00CC00);

				// Close this substate → return to OptionsState → reset to refresh all UI
				new FlxTimer().start(0.6, function(_) {
					close();
					new FlxTimer().start(0.05, function(_) {
						FlxG.resetState();
					});
				});
			}
			catch (e:Dynamic)
			{
				setStatus('${Language.get("DataBackup.error.restoreFailed", "Error")}: ${Std.string(e)}', 0xFFFF4444);
				isProcessing = false;
			}
			isProcessing = true; // keep locked until reload
		});
	}

	// ═══════════════════════════════════════════════════════════════
	//  CLOSE
	// ═══════════════════════════════════════════════════════════════

	function doClose()
	{
		if (isProcessing) return;
		isProcessing = true;

		for (s in [bg, titleTxt, infoPanel, infoTxt, cardExport, cardImport,
				   closeBtn, cardExportLabel, cardExportDesc, cardImportLabel,
				   cardImportDesc, closeBtnLabel, statusTxt])
			if (s != null) FlxTween.tween(s, {alpha: 0}, 0.15);

		new FlxTimer().start(0.2, function(_) { close(); });
		FlxG.sound.play(Paths.sound('cancelMenu'));
	}

	// ═══════════════════════════════════════════════════════════════
	//  ANDROID WARNING
	// ═══════════════════════════════════════════════════════════════

	#if android
	function showAndroidWarning()
	{
		androidWarningShown = true;
		var t = Language.get("DataBackup.androidWarning.title", "Important: Backup Recommended");
		var m = Language.get("DataBackup.androidWarning.message",
			"Your game data is stored in internal storage.\n"
			+ "If you uninstall the game, ALL data will be lost!\n"
			+ "Please create a backup now to save your progress.");

		AndroidTools.showAlertDialog(t, m,
			{name: Language.get("DataBackup.backupNow", "Backup Now"), func: function() {
				new FlxTimer().start(0.3, function(_) doExport());
			}},
			{name: Language.get("DataBackup.later", "Later"), func: null});
	}
	#end

	// ═══════════════════════════════════════════════════════════════
	//  HELPERS
	// ═══════════════════════════════════════════════════════════════

	function ensureFileDialog()
	{
		if (fileDialog == null || !fileDialog.completed)
		{
			if (fileDialog != null) fileDialog.destroy();
			fileDialog = new FileDialogHandler();
		}
	}

	static function makeCard(x:Float, y:Float, w:Int, h:Int):FlxSprite
	{
		var s = new FlxSprite(x, y).makeGraphic(w, h, FlxColor.TRANSPARENT);
		FlxSpriteUtil.drawRoundRect(s, 0, 0, w, h, 14, 14, CARD_COLOR);
		FlxSpriteUtil.drawRoundRect(s, 0, 0, w, h, 14, 14, FlxColor.TRANSPARENT, {thickness: 2, color: 0xFF2A3050});
		return s;
	}

	function setStatus(msg:String, color:FlxColor)
	{
		statusTxt.text = msg;
		statusTxt.color = color;
		statusTxt.alpha = 1;
	}

	function centerLabel(t:FlxText, b:FlxSprite)
	{
		t.x = b.x + (b.width - t.width) / 2;
		t.y = b.y + (b.height - t.height) / 2 - 2;
	}

	function overlapsCard(c:FlxSprite):Bool
	{
		return FlxG.mouse.overlaps(c, FlxG.camera);
	}

	// ═══════════════════════════════════════════════════════════════
	//  BASE64
	// ═══════════════════════════════════════════════════════════════

	static var B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

	static function base64Encode(b:Bytes):String
	{
		var sb = new StringBuf();
		var i = 0, n = b.length;
		while (i < n)
		{
			var c1 = b.get(i++);
			var c2 = (i < n) ? b.get(i++) : -1;
			var c3 = (i < n) ? b.get(i++) : -1;
			sb.add(B64.charAt((c1 >> 2) & 0x3F));
			sb.add(B64.charAt(((c1 << 4) & 0x30) | ((c2 >> 4) & 0x0F)));
			if (c2 == -1) { sb.add("=="); }
			else {
				sb.add(B64.charAt(((c2 << 2) & 0x3C) | ((c3 >> 6) & 0x03)));
				if (c3 == -1) sb.add("=");
				else sb.add(B64.charAt(c3 & 0x3F));
			}
		}
		return sb.toString();
	}

	static function base64Decode(s:String):Bytes
	{
		try {
			s = s.split("\n").join("").split("\r").join("").split(" ").join("");
			var buf = new haxe.io.BytesOutput();
			var i = 0, n = s.length;
			while (i < n && s.charAt(i) != '=')
			{
				var a = B64.indexOf(s.charAt(i++));
				var b = (i < n && s.charAt(i) != '=') ? B64.indexOf(s.charAt(i++)) : 0;
				var c = (i < n && s.charAt(i) != '=') ? B64.indexOf(s.charAt(i++)) : 0;
				var d = (i < n && s.charAt(i) != '=') ? B64.indexOf(s.charAt(i++)) : 0;
				if (a < 0 || b < 0) break;
				buf.writeByte((a << 2) | ((b >> 4) & 0x03));
				if (c >= 0) buf.writeByte(((b << 4) & 0xF0) | ((c >> 2) & 0x0F));
				if (d >= 0) buf.writeByte(((c << 6) & 0xC0) | d);
			}
			return buf.getBytes();
		} catch (e:Dynamic) { return null; }
	}
}
