package states;

import flixel.graphics.FlxGraphic;
#if cpp
import Discord.DiscordClient;
#end
import flixel.addons.display.FlxGridOverlay;
import flixel.addons.transition.FlxTransitionableState;
import lime.utils.Assets;
import flixel.system.FlxSound;
import openfl.utils.Assets as OpenFlAssets;
import sys.io.File;
import sys.FileSystem;
import haxe.Json;
import haxe.format.JsonParser;
import openfl.display.BitmapData;
import flash.geom.Rectangle;
import flixel.FlxBasic;
import options.ModSettingsSubState;
import flixel.util.FlxSpriteUtil;
import WeekData;
import flixel.ui.FlxButton;
import AttachedSprite;
import sys.io.Process;
import lime.system.System;
import openfl.Lib;
import tjson.TJSON;

using StringTools;

class ModsMenuState extends ScriptState
{
	var bg:FlxSprite;
	var icon:FlxSprite;
	var modName:Alphabet;
	var modDesc:FlxText;
	var modRestartText:FlxText;
	var modsList:Array<Dynamic> = [];

	var bgList:FlxSprite;
	var buttonReload:MenuButton;
	var buttonModFolder:MenuButton;
	var buttonToggleAll:MenuButton;
	var buttons:Array<MenuButton> = [];
	var settingsButton:MenuButton;

	var bgTitle:FlxSprite;
	var bgDescription:FlxSprite;
	var bgButtons:FlxSprite;

	var modsGroup:FlxTypedGroup<ModItem>;
	var curSelectedMod:Int = 0;
	
	var hoveringOnMods:Bool = true;
	var curSelectedButton:Int = -1;
	var modNameInitialY:Float = 0;

	var noModsSine:Float = 0;
	var noModsTxt:FlxText;

	var _lastControllerMode:Bool = false;
	var startMod:String = null;

	public static var instance:ModsMenuState;

	public function new(startMod:String = null)
	{
		this.startMod = startMod;
		super();
	}
	
	override function create()
	{
		 
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();
		persistentUpdate = false;
		WeekData.setDirectoryFromWeek();

		#if cpp
		DiscordClient.changePresence("In the Menus", null);
		#end
		// Parse mods list
		modsList = [];
		var path:String = 'modsList.txt';
		if(FileSystem.exists(path))
		{
			var leMods:Array<String> = CoolUtil.coolTextFile(path);
			for (i in 0...leMods.length)
			{
				if(leMods.length > 1 && leMods[0].length > 0) {
					var modSplit:Array<String> = leMods[i].split('|');
					if(!Paths.ignoreModFolders.contains(modSplit[0].toLowerCase()))
					{
						modsList.push([modSplit[0], (modSplit[1] == '1')]);
					}
				}
			}
		}

		// Find mod folders
		if (FileSystem.exists("modsList.txt")){
			for (folder in Paths.getModDirectories())
			{
				if(!Paths.ignoreModFolders.contains(folder))
				{
					var found = false;
					for (mod in modsList) {
						if (mod[0] == folder) {
							found = true;
							break;
						}
					}
					if (!found) {
						modsList.push([folder, true]);
					}
				}
			}
		}
		saveTxt();

		bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.color = 0xFF665AFF;
		bg.antialiasing = ClientPrefs.data.globalAntialiasing;
		add(bg);
		bg.screenCenter();

		bgList = FlxSpriteUtil.drawRoundRect(new FlxSprite(40, 40).makeGraphic(340, 440, FlxColor.TRANSPARENT), 0, 0, 340, 440, 15, 15, FlxColor.BLACK);
		bgList.alpha = 0.6;
		add(bgList);

		modsGroup = new FlxTypedGroup<ModItem>();

		for (i in 0...modsList.length)
		{
			if(startMod == modsList[i][0]) curSelectedMod = i;
			var modItem:ModItem = new ModItem(modsList[i][0]);
			if(!modsList[i][1]) // Disabled
			{
				modItem.icon.color = 0xFFFF6666;
				modItem.text.color = FlxColor.GRAY;
			}
			modsGroup.add(modItem);
		}

		var mod:ModItem = modsGroup.members[curSelectedMod];
		if(mod != null) bg.color = mod.bgColor;

		// Buttons
		var buttonX = bgList.x;
		var buttonWidth = Std.int(bgList.width);
		var buttonHeight = 80;

		buttonReload = new MenuButton(buttonX, bgList.y + bgList.height + 20, buttonWidth, buttonHeight, "RELOAD", reload);
		add(buttonReload);
		
		buttonToggleAll = new MenuButton(buttonX, buttonReload.y + buttonReload.bg.height + 20, buttonWidth, buttonHeight, "ENABLE ALL" , function() {
			var allEnabled = true;
			for (mod in modsList) {
				if (!mod[1]) {
					allEnabled = false;
					break;
				}
			}
			
			for (i in 0...modsList.length) {
				modsList[i][1] = !allEnabled;
			}
			
			for (mod in modsGroup.members)
			{
				mod.icon.color = !allEnabled ? FlxColor.WHITE : 0xFFFF6666;
				mod.text.color = !allEnabled ? FlxColor.WHITE : FlxColor.GRAY;
			}
			
			buttonToggleAll.textOn.text = buttonToggleAll.textOff.text = !allEnabled ? 
				"DISABLE ALL" : "ENABLE ALL";
			buttonToggleAll.bg.color = !allEnabled ? 0xFFFF6666 : FlxColor.GREEN;
			
			updateModDisplayData();
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
		});
		buttonToggleAll.bg.color = FlxColor.GREEN;
		add(buttonToggleAll);

		if(modsList.length < 1)
		{
			buttonToggleAll.visible = false;

			var myX = bgList.x + bgList.width + 20;
			noModsTxt = new FlxText(myX, 0, FlxG.width - myX - 20, Language.get("Mod.noModsTxt", "NO MODS INSTALLED\nPRESS BACK TO EXIT AND INSTALL A MOD"), 48);
			if(FlxG.random.bool(0.1)) noModsTxt.text += '\nBITCH.';
			noModsTxt.setFormat(Paths.languageFont(), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			noModsTxt.borderSize = 2;
			add(noModsTxt);
			noModsTxt.screenCenter(Y);

			var txt = new FlxText(bgList.x + 15, bgList.y + 15, bgList.width - 30, Language.get("Mod.noMods", "No Mods found."), 16);
			txt.setFormat(Paths.languageFont(), 16, FlxColor.WHITE);
			add(txt);

			FlxG.autoPause = false;
			changeSelectedMod();
			return super.create();
		}
		
		bgTitle = FlxSpriteUtil.drawRoundRectComplex(new FlxSprite(bgList.x + bgList.width + 20, 40).makeGraphic(840, 180, FlxColor.TRANSPARENT), 0, 0, 840, 180, 15, 15, 0, 0, FlxColor.BLACK);
		bgTitle.alpha = 0.6;
		add(bgTitle);

		icon = new FlxSprite(bgTitle.x + 15, bgTitle.y + 15);
		icon.antialiasing = ClientPrefs.data.globalAntialiasing;
		add(icon);

		modNameInitialY = icon.y + 80;
		modName = new Alphabet(icon.x + 165, modNameInitialY, "", true);
		modName.scaleY = 0.8;
		add(modName);

		bgDescription = FlxSpriteUtil.drawRoundRectComplex(new FlxSprite(bgTitle.x, bgTitle.y + 200).makeGraphic(840, 450, FlxColor.TRANSPARENT), 0, 0, 840, 450, 0, 0, 15, 15, FlxColor.BLACK);
		bgDescription.alpha = 0.6;
		add(bgDescription);
		
		modDesc = new FlxText(bgDescription.x + 15, bgDescription.y + 15, bgDescription.width - 30, "", 24);
		modDesc.setFormat(Paths.languageFont(), 24, FlxColor.WHITE, LEFT);
		add(modDesc);

		var myHeight = 100;
		modRestartText = new FlxText(bgDescription.x + 15, bgDescription.y + bgDescription.height - myHeight - 25, bgDescription.width - 30, 
			Language.get("Mod.restartNote", "* Moving or Toggling On/Off this Mod will restart the game."), 16);
		modRestartText.setFormat(Paths.languageFont(), 16, FlxColor.WHITE, RIGHT);
		add(modRestartText);

		bgButtons = FlxSpriteUtil.drawRoundRectComplex(new FlxSprite(bgDescription.x, bgDescription.y + bgDescription.height - myHeight).makeGraphic(840, myHeight, FlxColor.TRANSPARENT), 0, 0, 840, myHeight, 0, 0, 15, 15, FlxColor.WHITE);
		bgButtons.color = FlxColor.BLACK;
		bgButtons.alpha = 0.2;
		add(bgButtons);

		var buttonsX = bgButtons.x + 320;
		var buttonsY = bgButtons.y + 10;

		var button = new MenuButton(buttonsX, buttonsY, 80, 80, Paths.image('modsMenuButtons'), function() moveModToPosition(0), 54, 54); //Move to the top
		button.icon.animation.add('icon', [0]);
		button.icon.animation.play('icon', true);
		add(button);
		buttons.push(button);

		var button = new MenuButton(buttonsX + 100, buttonsY, 80, 80, Paths.image('modsMenuButtons'), function() moveModToPosition(curSelectedMod - 1), 54, 54); //Move up
		button.icon.animation.add('icon', [1]);
		button.icon.animation.play('icon', true);
		add(button);
		buttons.push(button);

		var button = new MenuButton(buttonsX + 200, buttonsY, 80, 80, Paths.image('modsMenuButtons'), function() moveModToPosition(curSelectedMod + 1), 54, 54); //Move down
		button.icon.animation.add('icon', [2]);
		button.icon.animation.play('icon', true);
		add(button);
		buttons.push(button);
		
		if(modsList.length < 2)
		{
			for (button in buttons)
				button.enabled = false;
		}

		settingsButton = new MenuButton(buttonsX + 300, buttonsY, 80, 80, Paths.image('modsMenuButtons'), function() //Settings
		{
			var curMod:ModItem = modsGroup.members[curSelectedMod];
			if(curMod != null && curMod.settings != null && curMod.settings.length > 0)
			{
				openSubState(new ModSettingsSubState(curMod.settings, curMod.folder, curMod.name));
			}
			else
			{
				FlxG.sound.play(Paths.sound('cancelMenu'));
			}
		}, 54, 54);

		settingsButton.icon.animation.add('icon', [3]);
		settingsButton.icon.animation.play('icon', true);
		add(settingsButton);
		buttons.push(settingsButton);

		if(modsGroup.members[curSelectedMod].settings == null || modsGroup.members[curSelectedMod].settings.length < 1)
			settingsButton.enabled = false;

		var button = new MenuButton(buttonsX + 400, buttonsY, 80, 80, Paths.image('modsMenuButtons'), function() //On/Off
		{
			var curMod:ModItem = modsGroup.members[curSelectedMod];
			var mod:String = curMod.folder;
			if(modsList[curSelectedMod][1]) // Enabled
			{
				modsList[curSelectedMod][1] = false;
				curMod.icon.color = 0xFFFF6666;
				curMod.text.color = FlxColor.GRAY;
			}
			else // Disabled
			{
				modsList[curSelectedMod][1] = true;
				curMod.icon.color = FlxColor.WHITE;
				curMod.text.color = FlxColor.WHITE;
			}

			if(curMod.mustRestart) waitingToRestart = true;
			updateModDisplayData();
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
		}, 54, 54);
		button.icon.animation.add('icon', [4]);
		button.icon.animation.play('icon', true);
		add(button);
		buttons.push(button);
		button.focusChangeCallback = function(focus:Bool) {
			if(!focus)
				button.bg.color = modsList[curSelectedMod][1] ? FlxColor.GREEN : 0xFFFF6666;
		};

		if(modsList.length < 1)
		{
			for (btn in buttons) btn.enabled = false;
			button.focusChangeCallback = null;
		}
		
		add(modsGroup);
		changeSelectedMod();
		#if android
		addVirtualPad(UP_DOWN, B);
		#end

		super.create();
	}
	
	var nextAttempt:Float = 1;
	var holdingMod:Bool = false;
	var mouseOffsets:FlxPoint = new FlxPoint();
	var holdingElapsed:Float = 0;
	var gottaClickAgain:Bool = false;

	var holdTime:Float = 0;
	var colorTween:FlxTween;
	var waitingToRestart:Bool = false;

	override function update(elapsed:Float)
	{

		if(controls.BACK)
		{
			if(colorTween != null) {
				colorTween.cancel();
			}
			saveTxt();

			FlxG.sound.play(Paths.sound('cancelMenu'));
			if(waitingToRestart)
			{
				TitleState.initialized = false;
				TitleState.closedState = false;
				FlxG.sound.music.fadeOut(0.3);
				FlxG.camera.fade(FlxColor.BLACK, 0.5, false, FlxG.resetGame, false);
			}
			else MusicBeatState.switchState(new MainMenuState());

			persistentUpdate = false;
			FlxG.autoPause = ClientPrefs.data.autoPause;
			FlxG.mouse.visible = false;
			return;
		}


		if(controls.UI_DOWN_R || controls.UI_UP_R) holdTime = 0;

		if(modsList.length > 0)
		{
			if(holdingMod)
			{
				holdingMod = false;
				holdingElapsed = 0;
				updateItemPositions();
			}

			var lastMode = hoveringOnMods;
			if(modsList.length > 1)
			{
				if(FlxG.mouse.justPressed)
				{
					for (i in centerMod-2...centerMod+3)
					{
						var mod = modsGroup.members[i];
						if(mod != null && mod.visible && FlxG.mouse.overlaps(mod))
						{
							hoveringOnMods = true;
							mouseOffsets.x = FlxG.mouse.x - mod.x;
							mouseOffsets.y = FlxG.mouse.y - mod.y;
							curSelectedMod = i;
							changeSelectedMod();
							break;
						}
					}
					hoveringOnMods = true;
					gottaClickAgain = false;
				}

				if(hoveringOnMods)
				{
					var shiftMult:Int = (FlxG.keys.pressed.SHIFT) ? 4 : 1;
					if(controls.UI_DOWN_P)
						changeSelectedMod(shiftMult);
					else if(controls.UI_UP_P)
						changeSelectedMod(-shiftMult);
					else if(FlxG.mouse.wheel != 0)
						changeSelectedMod(-FlxG.mouse.wheel * shiftMult, true);
					else if(FlxG.keys.justPressed.HOME)
						changeSelectedMod(-999);
					else if(FlxG.keys.justPressed.END)
						changeSelectedMod(999);
					else if(controls.UI_UP || controls.UI_DOWN)
					{
						var lastHoldTime:Float = holdTime;
						holdTime += elapsed;
						if(holdTime > 0.5 && Math.floor(lastHoldTime * 8) != Math.floor(holdTime * 8)) changeSelectedMod(shiftMult * (controls.UI_UP ? -1 : 1));
					}
					else if(FlxG.mouse.pressed && !gottaClickAgain)
					{
						var curMod:ModItem = modsGroup.members[curSelectedMod];
						if(curMod != null)
						{
							if(!holdingMod && FlxG.mouse.justMoved && FlxG.mouse.overlaps(curMod)) holdingMod = true;

							if(holdingMod)
							{
								var moved:Bool = false;
								for (i in centerMod-2...centerMod+3)
								{
									var mod = modsGroup.members[i];
									if(mod != null && mod.visible && FlxG.mouse.overlaps(mod) && curSelectedMod != i)
									{
										moveModToPosition(i);
										moved = true;
										break;
									}
								}
								
								if(!moved)
								{
									var factor:Float = -1;
									if(FlxG.mouse.y < bgList.y)
										factor = Math.abs(Math.max(0.2, Math.min(0.5, 0.5 - (bgList.y - FlxG.mouse.y) / 100)));
									else if(FlxG.mouse.y > bgList.y + bgList.height)
										factor = Math.abs(Math.max(0.2, Math.min(0.5, 0.5 - (FlxG.mouse.y - bgList.y - bgList.height) / 100)));
	
									if(factor >= 0)
									{
										holdingElapsed += elapsed;
										if(holdingElapsed >= factor)
										{
											holdingElapsed = 0;
											var newPos = curSelectedMod;
											if(FlxG.mouse.y < bgList.y) newPos--;
											else newPos++;
											moveModToPosition(Std.int(Math.max(0, Math.min(modsGroup.length - 1, newPos))));
										}
									}
								}
								curMod.x = FlxG.mouse.x - mouseOffsets.x;
								curMod.y = FlxG.mouse.y - mouseOffsets.y;
							}
						}
					}
					else if(FlxG.mouse.justReleased && holdingMod)
					{
						holdingMod = false;
						holdingElapsed = 0;
						updateItemPositions();
					}
				}
			}
		}
		else
		{
			noModsSine += 180 * elapsed;
			noModsTxt.alpha = 1 - Math.sin((Math.PI * noModsSine) / 180);
			
			// Keep refreshing mods list every 2 seconds until you add a mod on the folder
			nextAttempt -= elapsed;
			if(nextAttempt < 0)
			{
				nextAttempt = 2;
				Paths.getModDirectories();
				modsList = [];
				if(FileSystem.exists("modsList.txt")){
					for (folder in Paths.getModDirectories())
					{
						if(!Paths.ignoreModFolders.contains(folder))
						{
							var found = false;
							for (mod in modsList) {
								if (mod[0] == folder) {
									found = true;
									break;
								}
							}
							if (!found) {
								modsList.push([folder, true]);
							}
						}
					}
				}
				if(modsList.length > 0)
				{
					trace('mod(s) found! reloading');
					reload();
				}
			}
		}
		super.update(elapsed);
	}

	function changeSelectedMod(add:Int = 0, isMouseWheel:Bool = false)
	{
		var max = modsList.length - 1;
		if(max < 0) return;

		var lastSelected = curSelectedMod;
		curSelectedMod += add;

		var limited:Bool = false;
		if(curSelectedMod < 0)
		{
			curSelectedMod = 0;
			limited = true;
		}
		else if(curSelectedMod > max)
		{
			curSelectedMod = max;
			limited = true;
		}
		
		if(!isMouseWheel && limited && Math.abs(add) == 1)
		{
			if(add < 0) // pressed up on first mod
			{
				curSelectedMod = lastSelected;
				hoveringOnMods = false;
				curSelectedButton = -1;
				return;
			}
			else // pressed down on last mod
			{
				curSelectedMod = lastSelected;
				hoveringOnMods = false;
				curSelectedButton = -2;
				return;
			}
		}
		
		holdingMod = false;
		holdingElapsed = 0;
		gottaClickAgain = true;
		updateModDisplayData();
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
	}

	function updateModDisplayData()
	{
		var curMod:ModItem = modsGroup.members[curSelectedMod];
		if(curMod == null) return;

		if(colorTween != null)
		{
			colorTween.cancel();
			colorTween.destroy();
		}
		colorTween = FlxTween.color(bg, 0.5, bg.color, curMod.bgColor);

		if(Math.abs(centerMod - curSelectedMod) > 2)
		{
			if(centerMod < curSelectedMod)
				centerMod = curSelectedMod - 2;
			else centerMod = curSelectedMod + 2;
		}
		updateItemPositions();

		if (curMod.icon != null) {
			icon.loadGraphic(curMod.icon.graphic);
			icon.setGraphicSize(150, 150);
			icon.updateHitbox();
		}

		modName.text = curMod.name;
		modName.setScale(0.8, 0.8);
		modName.x = icon.x + 165;
		modName.y = modNameInitialY - (modName.height / 2);
		
		modRestartText.visible = curMod.mustRestart;
		modDesc.text = curMod.desc;
		if (ClientPrefs.data.language != 'English' && curMod.langdescription != null) {
			modDesc.text = curMod.langdescription;
		}
		if (curMod.mustRestart) {
			modDesc.text += "\n" + Language.get("Mod.restart", "(This Mod will restart the game!)");
		}

		settingsButton.enabled = (curMod.settings != null && curMod.settings.length > 0);
	}

	var centerMod:Int = 2;
	function updateItemPositions()
	{
		#if HSCRIPT_ALLOWED
		callOnHscript('onUpdateItemPositions', []);
		#end
		var maxVisible = Math.max(4, centerMod + 2);
		var minVisible = Math.max(0, centerMod - 2);
		for (i => mod in modsGroup.members)
		{
			if(mod == null) continue;

			mod.visible = (i >= minVisible && i <= maxVisible);
			mod.x = bgList.x + 5;
			mod.y = bgList.y + (86 * (i - centerMod + 2)) + 5;
			
			mod.alpha = 0.6;
			if(i == curSelectedMod) mod.alpha = 1;
			mod.selectBg.visible = (i == curSelectedMod);
		}
	}

	function moveModToPosition(position:Int)
	{
		if(position >= modsList.length) position = 0;
		else if(position < 0) position = modsList.length-1;

		if(position == curSelectedMod) return;

		var doRestart:Bool = modsList[curSelectedMod][0].mustRestart || modsList[position][0].mustRestart;
		
		var temp = modsList[curSelectedMod];
		modsList[curSelectedMod] = modsList[position];
		modsList[position] = temp;
		
		var tempMeta = modsGroup.members[curSelectedMod];
		modsGroup.members[curSelectedMod] = modsGroup.members[position];
		modsGroup.members[position] = tempMeta;
		
		curSelectedMod = position;
		updateModDisplayData();
		updateItemPositions();
		
		if(doRestart) {
			waitingToRestart = true;
		}
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
	}

	function reload()
	{
		#if HSCRIPT_ALLOWED
		callOnHscript('onReload', []);
		#end
		saveTxt();
		FlxG.autoPause = ClientPrefs.data.autoPause;
		FlxTransitionableState.skipNextTransIn = true;
		FlxTransitionableState.skipNextTransOut = true;
		var curMod:ModItem = modsGroup.members[curSelectedMod];
		MusicBeatState.switchState(new ModsMenuState(curMod != null ? curMod.folder : null));
	}
	
	function saveTxt()
	{
		var fileStr:String = '';
		for (values in modsList)
		{
			if(fileStr.length > 0) fileStr += '\n';
			fileStr += values[0] + '|' + (values[1] ? '1' : '0');
		}

		var path:String = 'modsList.txt';
		File.saveContent(path, fileStr);
		Paths.pushGlobalMods();
	}
	override function destroy() {
		instance = null;
		super.destroy();
	}
}

class ModItem extends FlxSpriteGroup
{
	public var selectBg:FlxSprite;
	public var icon:FlxSprite;
	public var text:FlxText;
	public var totalFrames:Int = 0;

	// options
	public var name:String = 'Unknown Mod';
	public var desc:String = 'No description provided.';
	public var langdescription:String = null;
	public var iconFps:Int = 10;
	public var bgColor:FlxColor = 0xFF665AFF;
	public var folder:String = 'unknownMod';
	public var mustRestart:Bool = false;
	public var settings:Array<Dynamic> = null;

	public function new(folder:String)
	{
		super();

		this.folder = folder;
		this.name = folder;
		var path = Paths.mods(folder + '/pack.json');
		if(FileSystem.exists(path)) {
			try {
				var rawJson:String = File.getContent(path);
				if(rawJson != null && rawJson.length > 0) {
					var stuff:Dynamic = Json.parse(rawJson);
					
						var name:String = Reflect.getProperty(stuff, "name");
						if(name != null && name.length > 0)
						{
							this.name = name;
						}
						if(name == 'Name')
						{
							this.name = folder;
						}
					
					if(Reflect.hasField(stuff, "description")) this.desc = Reflect.field(stuff, "description");
					if(Language.get("Mod.description") != null && Reflect.hasField(stuff, Language.get("Mod.description"))) this.langdescription = Reflect.field(stuff, Language.get("Mod.description"));
					if(Reflect.hasField(stuff, "restart")) this.mustRestart = Reflect.field(stuff, "restart");
					
					if(Reflect.hasField(stuff, "color")) {
						var colors:Array<Int> = Reflect.field(stuff, "color");
						if(colors != null && colors.length >= 3) {
							this.bgColor = FlxColor.fromRGB(colors[0], colors[1], colors[2]);
						}
					}
				}
			} catch (e:Dynamic) {
				trace('Error loading mod metadata: $e');
			}
		}

		path = Paths.mods('$folder/data/settings.json');
		if(FileSystem.exists(path))
		{
			var data:String = File.getContent(path);
			try
			{
				settings = tjson.TJSON.parse(data);
			}
			catch(e:Dynamic)
			{
				trace('Error loading mod settings: $e');
			}
		}

		selectBg = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);
		selectBg.alpha = 0.8;
		selectBg.visible = false;
		add(selectBg);

		icon = new FlxSprite(5, 5);
		icon.antialiasing = ClientPrefs.data.globalAntialiasing;
		add(icon);

		text = new FlxText(95, 38, 230, "", 16);
		text.setFormat(Paths.languageFont(), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		text.borderSize = 2;
		text.y -= Std.int(text.height / 2);
		add(text);

		// Load mod icon
		var iconPath = Paths.mods('${folder}/pack.png');
		if(FileSystem.exists(iconPath)) {
			var bmp = BitmapData.fromFile(iconPath);
			icon.loadGraphic(bmp, true, 150, 150);
			totalFrames = Math.floor(bmp.width / 150) * Math.floor(bmp.height / 150);
		} else {
			icon.loadGraphic(Paths.image('unknownMod'), true, 150, 150);
		}
		icon.scale.set(0.5, 0.5);
		icon.updateHitbox();
		
		text.text = this.name;
		selectBg.scale.set(width + 5, height + 5);
		selectBg.updateHitbox();
	}
}

class MenuButton extends FlxSpriteGroup
{
	public var bg:FlxSprite;
	public var textOn:Alphabet;
	public var textOff:Alphabet;
	public var icon:FlxSprite;
	public var onClick:Void->Void = null;
	public var enabled(default, set):Bool = true;
	public var onFocus(default, set):Bool = false;
	public var ignoreCheck:Bool = false;
	
	public function new(x:Float, y:Float, width:Int, height:Int, ?text:String = null, ?img:FlxGraphic = null, onClick:Void->Void = null, animWidth:Int = 0, animHeight:Int = 0)
	{
		super(x, y);
		
		bg = FlxSpriteUtil.drawRoundRect(new FlxSprite().makeGraphic(width, height, FlxColor.TRANSPARENT), 0, 0, width, height, 15, 15, FlxColor.WHITE);
		bg.color = FlxColor.BLACK;
		add(bg);

		if(text != null)
		{
			textOn = new Alphabet(0, 0, "", false);
			textOn.setScale(0.6);
			textOn.text = text;
			textOn.alpha = 0.6;
			textOn.visible = false;
			centerOnBg(textOn);
			textOn.y -= 30;
			add(textOn);
			
			textOff = new Alphabet(0, 0, "", true);
			textOff.setScale(0.52);
			textOff.text = text;
			textOff.alpha = 0.6;
			centerOnBg(textOff);
			add(textOff);
		}
		else if(img != null)
		{
			icon = new FlxSprite();
			if(animWidth > 0 || animHeight > 0) icon.loadGraphic(img, true, animWidth, animHeight);
			else icon.loadGraphic(img);
			centerOnBg(icon);
			add(icon);
		}

		this.onClick = onClick;
		setButtonVisibility(false);
	}

	function set_enabled(newValue:Bool)
	{
		enabled = newValue;
		setButtonVisibility(false);
		alpha = enabled ? 1 : 0.4;
		return newValue;
	}

	function set_onFocus(newValue:Bool)
	{
		if(enabled) setButtonVisibility(newValue);
		onFocus = newValue;
		return newValue;
	}

	public var focusChangeCallback:Bool->Void = null;
	public function setButtonVisibility(focusVal:Bool)
	{
		alpha = 1;
		bg.color = focusVal ? FlxColor.WHITE : FlxColor.BLACK;
		bg.alpha = focusVal ? 0.8 : 0.6;

		var focusAlpha = focusVal ? 1 : 0.6;
		if(textOn != null && textOff != null)
		{
			textOn.alpha = textOff.alpha = focusAlpha;
			textOn.visible = focusVal;
			textOff.visible = !focusVal;
		}
		else if(icon != null)
		{
			icon.alpha = focusAlpha;
			icon.color = focusVal ? FlxColor.BLACK : FlxColor.WHITE;
		}

		if(!enabled) alpha = 0.4;
		if(focusChangeCallback != null) focusChangeCallback(focusVal);
	}

	public function centerOnBg(spr:FlxSprite)
	{
		spr.x = bg.width/2 - spr.width/2;
		spr.y = bg.height/2 - spr.height/2;
	}
	
	override public function update(elapsed:Float)
	{
		super.update(elapsed);
		
		if(!enabled)
		{
			onFocus = false;
			return;
		}

		if(!ignoreCheck && FlxG.mouse.justMoved && FlxG.mouse.visible)
			onFocus = FlxG.mouse.overlaps(this);

		if(onFocus && onClick != null && FlxG.mouse.justPressed)
			onClick();
	}
}