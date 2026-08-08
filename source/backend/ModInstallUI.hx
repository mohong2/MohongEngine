package backend;

import backend.ui.PsychUIButton;
import backend.ui.PsychUIInputText;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.ui.FlxBar;
import flixel.util.FlxColor;

/**
 * Overlay for the drop-to-install workflow:
 *  - progress mode (extracting / downloading, with progress bar)
 *  - prompt mode (naming a zip whose inner folder is called "mods")
 *  - result mode (success / error message with an OK button)
 *
 * All displayed state is pulled from ModInstaller each frame.
 */
class ModInstallUI extends MusicBeatSubstate
{
	var bg:FlxSprite;
	var titleText:FlxText;
	var statusText:FlxText;
	var detailText:FlxText;
	var progressBarBG:FlxSprite;
	var progressBar:FlxBar;
	var indeterminateBar:FlxSprite;
	var indeterminateDir:Int = 1;
	var promptText:FlxText;
	var promptError:FlxText;
	var inputText:PsychUIInputText;
	var resultText:FlxText;
	var okButton:PsychUIButton;
	var cancelButton:PsychUIButton;

	var mode:String = 'progress'; // progress | prompt | result
	var inputFocusRequested:Bool = false;

	override function create()
	{
		bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.scrollFactor.set(0, 0);
		bg.alpha = 0.85;
		add(bg);

		titleText = new FlxText(0, 150, FlxG.width, '', 30);
		titleText.scrollFactor.set(0, 0);
		titleText.setFormat(Paths.languageFont(), 30, FlxColor.WHITE, CENTER);
		add(titleText);

		statusText = new FlxText(0, 205, FlxG.width, '', 18);
		statusText.scrollFactor.set(0, 0);
		statusText.setFormat(Paths.languageFont(), 18, 0xFFCCCCCC, CENTER);
		add(statusText);

		detailText = new FlxText(0, 232, FlxG.width - 160, '', 14);
		detailText.scrollFactor.set(0, 0);
		detailText.setFormat(Paths.languageFont(), 14, 0xFFAAAAAA, CENTER);
		detailText.visible = false;
		detailText.screenCenter(X);
		add(detailText);

		var barX:Int = Std.int(FlxG.width / 2 - 300);
		var barY:Int = 262;
		progressBarBG = new FlxSprite(barX - 3, barY - 3).makeGraphic(606, 24, FlxColor.WHITE);
		progressBarBG.scrollFactor.set(0, 0);
		add(progressBarBG);

		progressBar = new FlxBar(barX, barY, LEFT_TO_RIGHT, 600, 18);
		progressBar.scrollFactor.set(0, 0);
		progressBar.setRange(0, 100);
		progressBar.percent = 0;
		add(progressBar);

		indeterminateBar = new FlxSprite(barX, barY).makeGraphic(80, 18, FlxColor.WHITE);
		indeterminateBar.scrollFactor.set(0, 0);
		indeterminateBar.visible = false;
		add(indeterminateBar);

		promptText = new FlxText(0, 160, FlxG.width, '', 20);
		promptText.scrollFactor.set(0, 0);
		promptText.setFormat(Paths.languageFont(), 20, FlxColor.WHITE, CENTER);
		promptText.visible = false;
		add(promptText);

		promptError = new FlxText(0, 280, FlxG.width, '', 15);
		promptError.scrollFactor.set(0, 0);
		promptError.setFormat(Paths.languageFont(), 15, 0xFFFF6666, CENTER);
		promptError.visible = false;
		add(promptError);

		inputText = new PsychUIInputText(FlxG.width / 2 - 220, 230, 440, '', 18);
		inputText.scrollFactor.set(0, 0);
		inputText.maxLength = 80;
		inputText.visible = false;
		add(inputText);

		resultText = new FlxText(0, 190, FlxG.width - 120, '', 18);
		resultText.scrollFactor.set(0, 0);
		resultText.setFormat(Paths.languageFont(), 18, FlxColor.WHITE, CENTER);
		resultText.visible = false;
		resultText.screenCenter(X);
		add(resultText);

		cancelButton = new PsychUIButton(0, 0, '取消', function() ModInstaller.get().cancelTask(), 140, 36);
		cancelButton.scrollFactor.set(0, 0);
		cancelButton.visible = false;
		add(cancelButton);

		okButton = new PsychUIButton(0, 0, '确定', function() onOk(), 140, 36);
		okButton.scrollFactor.set(0, 0);
		okButton.visible = false;
		add(okButton);

		super.create();
	}

	override function update(elapsed:Float)
	{
		var m:ModInstaller = ModInstaller.get();

		// --- Sync with manager state ---
		titleText.text = m.title;

		if (m.showPrompt)
		{
			mode = 'prompt';
			showPromptMode(m);
		}
		else if (m.showResult)
		{
			mode = 'result';
			showResultMode(m);
		}
		else
		{
			mode = 'progress';
			showProgressMode(m);
		}

		// --- Keyboard shortcuts ---
		if (FlxG.keys.justPressed.ESCAPE || FlxG.keys.justPressed.BACKSPACE)
		{
			handleCancel();
		}

		if (mode == 'prompt' && (FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.TAB))
		{
			confirmInput();
		}

		super.update(elapsed);
	}

	function showProgressMode(m:ModInstaller):Void
	{
		statusText.visible = true;
		statusText.text = m.status;
		detailText.visible = m.detailText != null && m.detailText.length > 0;
		detailText.text = detailText.visible ? truncate(m.detailText, 84) : '';
		promptText.visible = false;
		promptError.visible = false;
		inputText.visible = false;
		resultText.visible = false;
		okButton.visible = false;
		cancelButton.visible = m.canCancel;
		cancelButton.onClick = function() ModInstaller.get().cancelTask();
		cancelButton.x = FlxG.width / 2 - 70;
		cancelButton.y = 330;

		progressBarBG.visible = true;
		if (m.indeterminate)
		{
			progressBar.visible = false;
			indeterminateBar.visible = true;
			indeterminateBar.x += 3 * indeterminateDir;
			if (indeterminateBar.x > FlxG.width / 2 + 220)
			{
				indeterminateBar.x = FlxG.width / 2 + 220;
				indeterminateDir = -1;
			}
			else if (indeterminateBar.x < FlxG.width / 2 - 300)
			{
				indeterminateBar.x = FlxG.width / 2 - 300;
				indeterminateDir = 1;
			}
		}
		else
		{
			progressBar.visible = true;
			indeterminateBar.visible = false;
			progressBar.percent = Math.max(0, Math.min(100, m.progress * 100));
		}
	}

	function showPromptMode(m:ModInstaller):Void
	{
		statusText.visible = false;
		detailText.visible = false;
		progressBarBG.visible = false;
		progressBar.visible = false;
		indeterminateBar.visible = false;
		promptText.visible = true;
		promptText.text = m.promptMessage;
		resultText.visible = false;
		okButton.visible = true;
		okButton.label = '确定';
		okButton.x = FlxG.width / 2 - 150;
		okButton.y = 320;
		cancelButton.visible = true;
		cancelButton.label = '取消';
		cancelButton.onClick = function() ModInstaller.get().cancelPrompt();
		cancelButton.x = FlxG.width / 2 + 10;
		cancelButton.y = 320;

		inputText.visible = true;
		if (!inputFocusRequested)
		{
			inputFocusRequested = true;
			inputText.text = m.promptDefault;
			focusInput();
		}
	}

	function showResultMode(m:ModInstaller):Void
	{
		statusText.visible = false;
		detailText.visible = false;
		progressBarBG.visible = false;
		progressBar.visible = false;
		indeterminateBar.visible = false;
		promptText.visible = false;
		promptError.visible = false;
		inputText.visible = false;
		resultText.visible = true;
		resultText.text = m.resultMessage;
		resultText.screenCenter(XY);
		okButton.visible = true;
		okButton.label = '好的';
		okButton.x = FlxG.width / 2 - 70;
		okButton.y = resultText.y + resultText.height + 40;
		cancelButton.visible = false;
	}

	function confirmInput():Void
	{
		ModInstaller.get().confirmName(inputText.text);
	}

	function handleCancel():Void
	{
		var m:ModInstaller = ModInstaller.get();
		if (mode == 'prompt')
		{
			m.cancelPrompt();
		}
		else if (mode == 'progress' && m.busy && m.canCancel)
		{
			m.cancelTask();
		}
		else if (mode == 'result')
		{
			closeMe();
		}
	}

	function onOk():Void
	{
		if (mode == 'prompt')
			confirmInput();
		else if (mode == 'result')
			closeMe();
	}

	function closeMe():Void
	{
		if (PsychUIInputText.focusOn == inputText) PsychUIInputText.focusOn = null;
		close();
	}

	public function focusInput():Void
	{
		if (inputText != null)
		{
			PsychUIInputText.focusOn = inputText;
		}
	}

	public function showPromptError(msg:String):Void
	{
		promptError.text = msg;
		promptError.visible = true;
	}

	static function truncate(s:String, max:Int):String
	{
		if (s.length <= max) return s;
		return s.substr(0, max - 3) + '…';
	}

	override function close()
	{
		ModInstaller.get().onUIClosed();
		super.close();
	}
}
