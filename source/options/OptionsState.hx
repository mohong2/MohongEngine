package options;

import backend.MusicBeatState;
import backend.MusicBeatSubstate;
import states.MainMenuState;
import FlxTextMenuItem.FlxTextAttached;
import flixel.addons.display.FlxBackdrop;
#if cpp
import Discord.DiscordClient;
#end
import flixel.addons.display.FlxGridOverlay;
import flixel.FlxSubState;
import flixel.util.FlxSave;
import flixel.util.FlxTimer;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import haxe.Json;
import flixel.input.keyboard.FlxKey;
import flixel.graphics.FlxGraphic;
import flixel.util.FlxColor;
import openfl.Lib;
import flash.media.Sound;
import flixel.text.FlxText;
import flixel.FlxSprite;
import flixel.FlxBasic;
import Controls;
import flixel.math.FlxMath;
import Language;
import CoolUtil;
import Paths;
import ClientPrefs;
import Character;
import CheckboxThingie;
import Main;
import Note;
import StrumNote;
import StageData;
import states.PlayState;
import states.LoadingState;
import states.ModState;
import substates.ModSubState;
import mohong.TraceManager;
#if (desktop && cpp && windows)
import mohong.Windows;
import mohong.TraceConsole;
#end
#if android
import android.Tools as AndroidTools;
#end

using StringTools;

class OptionsState extends MusicBeatState
{
	static final MODE_CATEGORY:Int = 0;
	static final MODE_SETTINGS:Int = 1;
	static final TRANSITION_DURATION:Float = 0.3;
	static final ENTER_DURATION:Float = 0.4;

	// ═══════════════════════════════════════════════════════════════
	//  Category data — driven by OptionLoader
	// ═══════════════════════════════════════════════════════════════
	var optionIds:Array<String> = [];
	var optionTexts:Array<String> = [];

	/** Refresh category list from OptionLoader. */
	function refreshCategoryLists()
	{
		var categories = OptionLoader.getCategories(#if mobile true #else false #end);
		optionIds = [];
		optionTexts = [];
		for (cat in categories)
		{
			optionIds.push(cat.id);
			optionTexts.push(OptionLoader.getCategoryName(cat));
		}
	}

	static var curSelected:Int = 0;
	public static var onPlayState:Bool = false;

	var categorySprites:Array<FlxSprite>;
	var settingsSprites:Array<FlxSprite>;

	var catGrpOptions:FlxTypedGroup<FlxText>;
	var catGrid:FlxBackdrop;
	static var scrollOffset:Float = 0;
	var targetScrollOffset:Float = 0;
	var itemSpacing:Float = 105;
	var baseY:Float = 120;
	var visibleTop:Float = 0;
	var visibleBottom:Float = 720;
	var catSelectorLeft:FlxText;
	var catSelectorRight:FlxText;
	#if (TOUCH_CONTROLS || desktop)
	var catTipText:FlxText;
	#end
	var setGrpOptions:FlxTypedGroup<FlxTextMenuItem>;
	var setCheckboxGroup:FlxTypedGroup<CheckboxThingie>;
	var setGrpTexts:FlxTypedGroup<FlxTextAttached>;
	var setOptionsArray:Array<Option>;
	var setCurSelected:Int = 0;
	var setCurOption:Option = null;
	var setBoyfriend:Character = null;
	var setDescBox:FlxSprite;
	var setDescText:FlxText;
	var setTitleText:FlxTextMenuItem;

	/** 0.7.3+ Note 皮肤预览 (设置页顶部的四个 StrumNote)。 */
	var settingsNotes:FlxTypedGroup<StrumNote> = null;
	/** 预览滑入/滑出动画 (0.7.3 同款)。 */
	var settingsNotesTween:Array<FlxTween> = [];
	/** noteSkin 选项在设置列表里的行号 (-1 = 本页没有)。 */
	var settingsNoteSkinID:Int = -1;

	var currentMode:Int = MODE_CATEGORY;
	var currentSettingsPage:String = '';
	var settingsPreviewMode:Bool = false;
	var currentPreviewPage:String = '';
	var optionPopupOpen:Bool = false;
	var previewCam:flixel.FlxCamera = null;
	var transitioning:Bool = false;

	var nextAccept:Int = 5;
	var holdTime:Float = 0;
	var holdValue:Float = 0;

	var bg:FlxSprite;

	// ═══════════════════════════════════════════════════════════════
	//  CREATE
	// ═══════════════════════════════════════════════════════════════
	override function create()
	{
		#if desktop
		DiscordClient.changePresence("Options Menu", null);
		#end
		FlxG.mouse.visible = true;

		registerCallbacks();

		bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.color = 0xff17719b;
		bg.screenCenter();
		bg.antialiasing = ClientPrefs.data.globalAntialiasing;
		bg.alpha = 0;
		add(bg);

		categorySprites = [];
		settingsSprites = [];

		buildCategoryView();
		playEnterAnimation();
		syncDragToWheel();

		ClientPrefs.saveSettings();

		#if (TOUCH_CONTROLS || desktop)
		addVirtualPad(UP_DOWN, A_B_C);
		#end

		OptionLoader.reloadAll(); // hot‑reload on every entry

		super.create();
	}

	/** Register option onChange callbacks. */
	function registerCallbacks()
	{
		var callbacks = [
			'onChangeAntiAliasing'         => onChangeAntiAliasing,
			'onChangeSeparateUpdateDraw'   => onChangeSeparateUpdateDraw,
			'onChangeFramerate'            => onChangeFramerate,
			'onChangeDrawFramerate'        => onChangeDrawFramerate,
			#if desktop 'onChangeWindowMode' => onChangeWindowMode, 
			 'onChangeRunInBackground'      => onChangeRunInBackground,
			'onChangeBackgroundDim'        => onChangeBackgroundDim,#end
			'onChangeFPSCounter'           => onChangeFPSCounter,
			'onChangePauseMusic'           => onChangePauseMusic,
			'onChangeGameplayHitsoundVolume' => onChangeGameplayHitsoundVolume,
			'onChangeHitsound'             => onChangeHitsound,
			'onChangeMarvelousRatings'     => onChangeMarvelousRatings,
			'onChangeJudgementPreset'      => onChangeJudgementPreset,
			'onChangeMarvelousWindow'      => onChangeMarvelousWindow,
			'onChangeSickWindow'           => onChangeSickWindow,
			'onChangeGoodWindow'           => onChangeGoodWindow,
			'onChangeBadWindow'            => onChangeBadWindow,
			//'onChangeTailWindowMult'       => onChangeTailWindowMult,
			'onChangeLanguage'             => onChangeLanguage,
			'onChangeTraceConsole'         => onChangeTraceConsole,
			'onChangeTraceConsoleLevel'    => onChangeTraceConsoleLevel,
			'onChangeTouchSwipe'           => onChangeTouchSwipe,
			'onClearImageCache'            => onClearImageCache,
		];
		OptionLoader.setCallbacks(callbacks);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (transitioning) return;

		switch (currentMode)
		{
			case MODE_CATEGORY:  updateCategoryView(elapsed);
			case MODE_SETTINGS:  updateSettingsView(elapsed);
		}
	}

	function buildCategoryView()
	{
		refreshCategoryLists();
		categorySprites = [];

			catGrid = new FlxBackdrop(FlxGridOverlay.createGrid(80, 80, 160, 160, true, 0x33FFFFFF, 0x0));
		catGrid.velocity.set(40, 40);
		catGrid.alpha = 0;
		add(catGrid);
		categorySprites.push(catGrid);

		catGrpOptions = new FlxTypedGroup<FlxText>();
		add(catGrpOptions);

		for (i in 0...optionIds.length)
		{
			var txt = new FlxText(150, 0, 0, optionTexts[i], 32);
			txt.setFormat(Paths.optionsfont(), 50, FlxColor.WHITE, LEFT,
				FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			txt.borderSize = 2.5;
			txt.ID = i;
			catGrpOptions.add(txt);
			categorySprites.push(txt);
		}

		catSelectorLeft = new FlxText(0, 0, 0, ">", 32);
		catSelectorLeft.setFormat(Paths.optionsfont(), 50, FlxColor.WHITE, LEFT,
			FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		catSelectorLeft.borderSize = 2.5;
		add(catSelectorLeft);
		categorySprites.push(catSelectorLeft);

		catSelectorRight = new FlxText(0, 0, 0, "<", 32);
		catSelectorRight.setFormat(Paths.optionsfont(), 50, FlxColor.WHITE, LEFT,
			FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		catSelectorRight.borderSize = 2.5;
		add(catSelectorRight);
		categorySprites.push(catSelectorRight);

		#if (TOUCH_CONTROLS || desktop)
		if (ClientPrefs.touchUIEnabled())
		{
			catTipText = new FlxText(10, FlxG.height - 24, 0,
				Language.get("option.tipText", "Press C to customize your mobile controls"), 16);
			catTipText.setFormat(Paths.optionsfont(), 16, FlxColor.WHITE, LEFT,
				FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			catTipText.borderSize = 2.4;
			catTipText.scrollFactor.set();
			add(catTipText);
			categorySprites.push(catTipText);
		}
		#end

		targetScrollOffset = -(curSelected * itemSpacing);
		scrollOffset = targetScrollOffset;

		for (i in 0...catGrpOptions.length)
		{
			var item = catGrpOptions.members[i];
			if (item == null) continue;
			item.y = baseY + i * itemSpacing + scrollOffset;
		}

		changeCategorySelection(0);
	}

	function updateCategoryView(elapsed:Float)
	{
		scrollOffset = FlxMath.lerp(scrollOffset, targetScrollOffset,
			CoolUtil.boundTo(elapsed * 12, 0, 1));

		for (i in 0...catGrpOptions.length)
		{
			var item = catGrpOptions.members[i];
			if (item == null) continue;

			var screenY:Float = baseY + i * itemSpacing + scrollOffset;
			item.y = screenY;
			item.x = 150;

			var margin:Float = 80;
			var isVisible:Bool = (screenY + item.height > visibleTop - margin
							   && screenY < visibleBottom + margin);

			if (isVisible)
			{
				item.visible = true;
				item.active = true;
				var dist:Float = 0;
				if (screenY < visibleTop + margin)
					dist = (visibleTop + margin - screenY) / margin;
				else if (screenY + item.height > visibleBottom - margin)
					dist = (screenY + item.height - (visibleBottom - margin)) / margin;
				item.alpha = FlxMath.bound(1 - dist, 0, 1);
			}
			else
			{
				item.visible = false;
				item.active = false;
			}
		}

		var selItem = catGrpOptions.members[curSelected];
		if (selItem != null && selItem.visible)
		{
			catSelectorLeft.x = selItem.x - 63;
			catSelectorLeft.y = selItem.y;
			catSelectorRight.x = selItem.x + selItem.width + 15;
			catSelectorRight.y = selItem.y;
			catSelectorLeft.visible = true;
			catSelectorRight.visible = true;
			catSelectorLeft.alpha = selItem.alpha;
			catSelectorRight.alpha = selItem.alpha;
		}
		else
		{
			catSelectorLeft.visible = false;
			catSelectorRight.visible = false;
		}

		var keyboardUsed:Bool = controls.UI_UP_P || controls.UI_DOWN_P || controls.ACCEPT || controls.BACK;

		if (controls.UI_UP_P)    changeCategorySelection(-1);
		if (controls.UI_DOWN_P)  changeCategorySelection(1);

		if (!keyboardUsed)
		{
			if (FlxG.mouse.wheel > 0)   changeCategorySelection(-1);
			else if (FlxG.mouse.wheel < 0) changeCategorySelection(1);

			#if !TOUCH_CONTROLS
			{
				for (i in 0...catGrpOptions.length)
				{
					var item = catGrpOptions.members[i];
					if (item == null || !item.visible) continue;

					if (FlxG.mouse.overlaps(item, FlxG.camera))
					{
						if (curSelected != i)
						{
							curSelected = i;
							targetScrollOffset = -(i * itemSpacing);
							updateCategoryPreview();
							for (j in 0...catGrpOptions.length)
							{
								var other = catGrpOptions.members[j];
								if (other != null) other.alpha = (j == curSelected) ? 1.0 : 0.6;
							}
							catSelectorLeft.x = item.x - 63;
							catSelectorLeft.y = item.y;
							catSelectorRight.x = item.x + item.width + 15;
							catSelectorRight.y = item.y;
						}
						if (FlxG.mouse.justPressed && !(virtualPad != null && virtualPad.isMouseOverAnyButton()))
							openSelectedCategory(optionIds[curSelected]);
						break;
					}
				}
			}
			#else
			if ((FlxG.mouse.justPressed && !(virtualPad != null && virtualPad.isMouseOverAnyButton())) || (FlxG.touches.list.length > 0 && FlxG.touches.list[0].justReleased))
			{
				for (i in 0...catGrpOptions.length)
				{
					var item = catGrpOptions.members[i];
					if (item == null || !item.visible) continue;

					if (FlxG.mouse.overlaps(item, FlxG.camera)
						#if TOUCH_CONTROLS || (FlxG.touches.list.length > 0 && FlxG.touches.list[0].overlaps(item)) #end)
					{
						if (curSelected != i)
						{
							curSelected = i;
							targetScrollOffset = -(i * itemSpacing);
							updateCategoryPreview();
							for (j in 0...catGrpOptions.length)
							{
								var other = catGrpOptions.members[j];
								if (other != null) other.alpha = (j == curSelected) ? 1.0 : 0.6;
							}
							catSelectorLeft.x = item.x - 63;
							catSelectorLeft.y = item.y;
							catSelectorRight.x = item.x + item.width + 15;
							catSelectorRight.y = item.y;
						}
						else
						{
							openSelectedCategory(optionIds[curSelected]);
						}
						break;
					}
				}
			}
			#end
		}

		if (controls.ACCEPT)
			openSelectedCategory(optionIds[curSelected]);

		if (controls.BACK)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			playExitAnimation(function() {
				if (onPlayState)
				{
					StageData.loadDirectory(PlayState.SONG);
					LoadingState.loadAndSwitchState(new PlayState());
					FlxG.sound.music.volume = 0;
				}
				else
					MusicBeatState.switchState(new MainMenuState());
			});
		}

		#if (TOUCH_CONTROLS || desktop)
		if (virtualPad != null && virtualPad.buttonC.justPressed)
		{
			persistentUpdate = false;
			openSubState(new android.AndroidControlsSubState());
		}
		#end
	}

	function changeCategorySelection(change:Int = 0, ?playSound:Bool = true)
	{
		curSelected += change;
		if (curSelected < 0) curSelected = optionIds.length - 1;
		if (curSelected >= optionIds.length) curSelected = 0;

		targetScrollOffset = -(curSelected * itemSpacing);
		updateCategoryPreview();

		if (change != 0 && playSound) FlxG.sound.play(Paths.sound('scrollMenu'), 0.5);
	}

	/** Category preview temporarily disabled. Kept for later re-enable. */
	function updateCategoryPreview():Void
	{
		destroySettingsSprites();
		settingsPreviewMode = false;
		currentPreviewPage = '';
	}

	function bringCategoryToFront():Void
	{
		if (catGrpOptions != null) { remove(catGrpOptions); add(catGrpOptions); }
		if (catGrid != null) { remove(catGrid); add(catGrid); }
		if (catSelectorLeft != null) { remove(catSelectorLeft); add(catSelectorLeft); }
		if (catSelectorRight != null) { remove(catSelectorRight); add(catSelectorRight); }
		#if (TOUCH_CONTROLS || desktop)
		if (catTipText != null) { remove(catTipText); add(catTipText); }
		#end
	}

	function openSelectedCategory(id:String)
	{
		#if (TOUCH_CONTROLS || desktop)
		removeVirtualPad();
		#end

		var categories = OptionLoader.getCategories(true);
		var foundCat:Dynamic = null;
		for (cat in categories)
		{
			if (cat.id == id)
			{
				foundCat = cat;
				break;
			}
		}

		if (foundCat == null)
		{
			fallbackOpenCategory(id);
			return;
		}

		switch (foundCat.type)
		{
			case 'settings':
				switchToSettings(id);

			case 'substate':
				if (foundCat.substateClass == null)
				{
					fallbackOpenCategory(id);
					return;
				}

				// 触屏控制: 桌面端也直接打开安卓控件子状态 (同时强制编译该类)
				if (foundCat.id == 'touch_controls')
				{
					transitioning = true;
					playExitAnimation(function() {
						openSubState(new android.AndroidControlsSubState());
					});
					return;
				}

				// 模组分类 → 使用 ModSubState（脚本驱动）
				if (foundCat.modSource != null && foundCat.modSource.length > 0)
				{
					transitioning = true;
					playExitAnimation(function() {
						openSubState(new substates.ModSubState(foundCat.substateClass));
					});
					return;
				}

				// 内置分类 → 尝试编译类，失败则回退 ModSubState
				var resolvedClass = Type.resolveClass(foundCat.substateClass);
				if (resolvedClass != null)
				{
					var substateClass:Class<FlxSubState> = cast resolvedClass;
					transitioning = true;
					playExitAnimation(function() {
						openSubState(Type.createInstance(substateClass, []));
					});
				}
				else
				{
					transitioning = true;
					playExitAnimation(function() {
						openSubState(new substates.ModSubState(foundCat.substateClass));
					});
				}

			case 'state':
				if (foundCat.stateClass == null)
				{
					fallbackOpenCategory(id);
					return;
				}

				// 模组分类 → 使用 ModState（脚本驱动）
				if (foundCat.modSource != null && foundCat.modSource.length > 0)
				{
					LoadingState.loadAndSwitchState(new states.ModState(foundCat.stateClass));
					return;
				}

				// 内置分类 → 尝试编译类，失败则回退 ModState
				var resolvedStateClass = Type.resolveClass(foundCat.stateClass);
				if (resolvedStateClass != null)
				{
					var stateClass:Class<MusicBeatState> = cast resolvedStateClass;
					LoadingState.loadAndSwitchState(Type.createInstance(stateClass, []));
				}
				else
				{
					LoadingState.loadAndSwitchState(new states.ModState(foundCat.stateClass));
				}

			default:
				fallbackOpenCategory(id);
		}
	}

	/** Fallback hardcoded category routing. */
	function fallbackOpenCategory(id:String)
	{
		switch (id)
		{
			case 'notecolor':
				transitionToSettingsSubState('notecolor');
			case 'controls':
				transitionToSettingsSubState('controls');
			case 'backup':
				transitionToSettingsSubState('backup');
			case 'adjust':
				LoadingState.loadAndSwitchState(new options.NoteOffsetState());
			default:
				// 未知分类，回退到分类视图
				FlxG.sound.play(Paths.sound('cancelMenu'));
		}
	}

	/** For pages that use openSubState: exit animation first. */
	function transitionToSettingsSubState(id:String)
	{
		transitioning = true;
		playExitAnimation(function() {
			switch (id)
			{
				case 'notecolor': openSubState(new options.NotesSubState());
				case 'notecolor_rgb': openSubState(new options.NotesSubStateNew());
				case 'controls':  openSubState(new options.ControlsSubState());
				case 'backup':    openSubState(new options.BackupSettingsSubState());
			}
		});
	}

	// ═══════════════════════════════════════════════════════════════════════════
	//  Settings editing view
	// ═══════════════════════════════════════════════════════════════════════════

	function buildSettingsView(optionsArray:Array<Option>, title:String, rpcTitle:String, ?previewMode:Bool = false)
	{
		destroySettingsSprites();

		settingsPreviewMode = previewMode;
		currentPreviewPage = '';

		setOptionsArray = optionsArray;
		setCurSelected = 0;
		setCurOption = null;
		setBoyfriend = null;
		nextAccept = 5;
		holdTime = 0;
		holdValue = 0;
		settingsSprites = [];

		#if desktop
		DiscordClient.changePresence(rpcTitle, null);
		#end

		setGrpOptions = new FlxTypedGroup<FlxTextMenuItem>();
		add(setGrpOptions);

		setGrpTexts = new FlxTypedGroup<FlxTextAttached>();
		add(setGrpTexts);

		setCheckboxGroup = new FlxTypedGroup<CheckboxThingie>();
		add(setCheckboxGroup);

		setDescBox = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		setDescBox.alpha = 0.6;
		add(setDescBox);
		settingsSprites.push(setDescBox);

		setTitleText = new FlxTextMenuItem(75, 40, title, 32);
		setTitleText.alpha = 0.4;
		add(setTitleText);
		settingsSprites.push(setTitleText);

		setDescText = new FlxText(50, 600, 1180, "", 32);
		setDescText.setFormat(Paths.optionsfont(), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		setDescText.scrollFactor.set();
		setDescText.borderSize = 2.4;
		add(setDescText);
		settingsSprites.push(setDescText);

		for (i in 0...setOptionsArray.length)
		{
			var optionText = new FlxTextMenuItem(290, 260, setOptionsArray[i].name, 48);
			optionText.isMenuItem = true;
			optionText.targetY = i;
			setGrpOptions.add(optionText);

			if (setOptionsArray[i].type == 'button')
			{
				optionText.x -= 10;
				optionText.startPosition.x -= 10;
				var valueText = new FlxTextAttached(
					Language.get("option.traceConsole.pressEnter", "[Press ENTER]"),
					36, optionText.width + 80);
				valueText.sprTracker = optionText;
				valueText.copyAlpha = true;
				valueText.ID = i;
				setGrpTexts.add(valueText);
				setOptionsArray[i].setChild(valueText);
			}
			else if (setOptionsArray[i].type == 'bool')
			{
				var checkbox = new CheckboxThingie(optionText.x - 10, optionText.y, setOptionsArray[i].getValue() == true);
				checkbox.sprTracker = optionText;
				checkbox.ID = i;
				setCheckboxGroup.add(checkbox);
			}
			else
			{
				optionText.x -= 10;
				optionText.startPosition.x -= 10;
				var valueText = new FlxTextAttached('' + setOptionsArray[i].getValue(), 48, optionText.width + 80);
				valueText.sprTracker = optionText;
				valueText.copyAlpha = true;
				valueText.ID = i;
				setGrpTexts.add(valueText);
				setOptionsArray[i].setChild(valueText);
			}
			settingsSprites.push(optionText);

			if (setOptionsArray[i].showBoyfriend && setBoyfriend == null)
			{
				settingsReloadBoyfriend();
			}
			settingsUpdateText(setOptionsArray[i]);
		}

		changeSettingsSelection(0, !previewMode);
		settingsReloadCheckboxes();
		settingsSetupNotePreview(optionsArray);

		if (previewMode)
		{
			// Category view shows the complete settings page in a dimmed right-side window.
			setupSettingsPreviewCamera();
			setSettingsPreviewAlpha(0.18);
		}
		else
		{
			#if (TOUCH_CONTROLS || desktop)
			addVirtualPad(LEFT_FULL, A_B_C);
			addPadCamera();
			#end
		}
	}

	function setupSettingsPreviewCamera():Void
	{
		var camX:Int = 460;
		var camW:Int = Std.int(FlxG.width - camX - 20);
		if (camW <= 0) return;

		// Scale the full settings page so it fits inside the right-side preview window.
		var camZoom:Float = camW / FlxG.width;
		previewCam = new flixel.FlxCamera(camX, 0, camW, FlxG.height, camZoom);
		previewCam.bgColor.alpha = 0;
		FlxG.cameras.add(previewCam, false);

		for (s in settingsSprites)
			if (s != null) s.cameras = [previewCam];
		for (item in setGrpOptions.members)
			if (item != null) item.cameras = [previewCam];
		for (item in setGrpTexts.members)
			if (item != null) item.cameras = [previewCam];
		for (item in setCheckboxGroup.members)
			if (item != null) item.cameras = [previewCam];
		if (settingsNotes != null)
			for (note in settingsNotes)
				if (note != null) note.cameras = [previewCam];
		if (setBoyfriend != null)
			setBoyfriend.cameras = [previewCam];
	}

	function setSettingsPreviewAlpha(alpha:Float):Void
	{
		for (s in settingsSprites)
			if (s != null) s.alpha = alpha;
		for (item in setGrpOptions.members)
			if (item != null) item.alpha = alpha;
		for (item in setGrpTexts.members)
			if (item != null) item.alpha = alpha;
		for (item in setCheckboxGroup.members)
			if (item != null) item.alpha = alpha;
		if (settingsNotes != null)
			for (note in settingsNotes)
				if (note != null) note.alpha = alpha;
	}

	function destroySettingsSprites()
	{
		if (previewCam != null)
		{
			FlxG.cameras.remove(previewCam, true);
			previewCam = null;
		}

		if (settingsSprites != null)
		{
			for (s in settingsSprites)
			{
				if (s != null)
				{
					remove(s);
					s.destroy();
				}
			}
		}
		if (setGrpOptions != null) { remove(setGrpOptions); setGrpOptions.destroy(); setGrpOptions = null; }
		if (setGrpTexts != null) { remove(setGrpTexts); setGrpTexts.destroy(); setGrpTexts = null; }
		if (setCheckboxGroup != null) { remove(setCheckboxGroup); setCheckboxGroup.destroy(); setCheckboxGroup = null; }
		if (setBoyfriend != null) { remove(setBoyfriend); setBoyfriend.destroy(); setBoyfriend = null; }
		if (settingsNotes != null) { remove(settingsNotes); settingsNotes.destroy(); settingsNotes = null; }
		for (t in settingsNotesTween) if (t != null) t.cancel();
		settingsNotesTween = [];
		settingsNoteSkinID = -1;
	}

	/**
	 * 0.7.3+ Note 皮肤预览: 设置页存在 noteSkin 选项时, 顶部显示四个 StrumNote,
	 * 切换皮肤时实时刷新 (与 0.6.3/0.7.3 VisualsUI 的行为一致)。
	 */
	function settingsSetupNotePreview(optionsArray:Array<Option>)
	{
		if (settingsNotes != null) { remove(settingsNotes); settingsNotes.destroy(); settingsNotes = null; }
		settingsNoteSkinID = -1;
		for (t in settingsNotesTween) if (t != null) t.cancel();
		settingsNotesTween = [];

		var hasNoteSkin:Bool = false;
		for (i in 0...optionsArray.length)
		{
			var opt:Option = optionsArray[i];
			// 预览跟随 Note 皮肤 + Note 风格 (Old=flat / New=0.7.3 材质) 两个选项
			if (opt.variable == 'noteSkin' || opt.variable == 'noteStyle')
			{
				hasNoteSkin = true;
				// 预览滑入行: 优先 noteSkin, 只有 noteStyle 时用它
				if (opt.variable == 'noteSkin' || settingsNoteSkinID < 0)
					settingsNoteSkinID = i;
				var prevOnChange:Void->Void = opt.onChange;
				opt.onChange = function() {
					if (prevOnChange != null) prevOnChange();
					settingsReloadNoteSkin();
				};
			}
		}
		if (!hasNoteSkin) return;

		settingsNotes = new FlxTypedGroup<StrumNote>();
		add(settingsNotes);
		settingsNotesTween = [];
		for (i in 0...4)
		{
			var note:StrumNote = new StrumNote(370 + (560 / 4) * i, -200, i, 0);
			// 预览材质跟随 noteStyle (Old=flat NOTE_assets, New=noteSkins/NOTE_assets)
			note.texture = Note.defaultNoteSkin;
			note.reloadNote();
			note.centerOffsets();
			note.centerOrigin();
			note.playAnim('static');
			settingsNotes.add(note);
		}
		settingsNotes.visible = true;
		settingsReloadNoteSkin();
	}

	/** 按当前 noteSkin 刷新预览 (StrumNote.reloadNote 已内置皮肤后缀解析)。 */
	function settingsReloadNoteSkin()
	{
		if (settingsNotes == null) return;
		for (note in settingsNotes)
		{
			// noteStyle 变化时基底材质也要跟着换, 不能只靠 reloadNote 拼皮肤后缀
			note.texture = Note.defaultNoteSkin;
			// 不能靠 texture setter: texture 一直是基底名 (NOTE_assets), 改皮肤时值不变,
			// setter 会短路。reloadNote 内部会按 getNoteSkinPostfix 重新解析材质。
			note.reloadNote();
			note.centerOffsets();
			note.centerOrigin();
			note.playAnim('static');
		}
	}

	function updateSettingsView(elapsed:Float)
	{
		// Keyboard always wins on the frame it is used; mouse is ignored that frame.
		var keyboardUsed:Bool = controls.UI_UP_P || controls.UI_DOWN_P
			|| controls.ACCEPT || controls.BACK || controls.UI_LEFT_P || controls.UI_RIGHT_P
			|| controls.RESET;

		if (!keyboardUsed)
		{
			if (FlxG.mouse.wheel != 0)
			{
				changeSettingsSelection(-FlxG.mouse.wheel);
				FlxG.sound.play(Paths.sound('scrollMenu'));
			}

			// 虚拟按键上点击不穿透到选项行, 避免同时触发按键动作和行点击造成双重判定
			if (FlxG.mouse.justPressed && !(virtualPad != null && virtualPad.isMouseOverAnyButton()))
			{
				for (checkbox in setCheckboxGroup)
				{
					if (FlxG.mouse.overlaps(checkbox))
					{
						setCurSelected = checkbox.ID;
						changeSettingsSelection(0);
						FlxG.sound.play(Paths.sound('scrollMenu'));
						setOptionsArray[checkbox.ID].setValue(!setOptionsArray[checkbox.ID].getValue());
						setOptionsArray[checkbox.ID].change();
						settingsReloadCheckboxes();
						break;
					}
				}
				for (text in setGrpTexts)
				{
					if (FlxG.mouse.overlaps(text))
					{
						setCurSelected = text.ID;
						changeSettingsSelection(0);

						var option = setOptionsArray[text.ID];
						if (option.type == 'string' || option.type == 'int'
							|| option.type == 'float' || option.type == 'percent')
						{
							openOptionPopup(option);
						}
						else if (option.type == 'button')
						{
							// 触摸/鼠标点击动作行 = 按下 ACCEPT: 触发 onChange 执行动作。
							FlxG.sound.play(Paths.sound('scrollMenu'));
							option.setValue((option.getValue() == true) ? false : true);
							option.change();
						}
						break;
					}
				}
			}
		}

		if (controls.UI_UP_P)   changeSettingsSelection(-1);
		if (controls.UI_DOWN_P) changeSettingsSelection(1);

		if (controls.BACK)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			settingsSaveState();
			switchToCategory();
			return;
		}

		if (nextAccept <= 0)
		{
			var usesCheckbox = (setCurOption != null && (setCurOption.type == 'bool' || setCurOption.type == 'button'));

			if (usesCheckbox)
			{
				if (controls.ACCEPT)
				{
					FlxG.sound.play(Paths.sound('scrollMenu'));
					setCurOption.setValue((setCurOption.getValue() == true) ? false : true);
					setCurOption.change();
					settingsReloadCheckboxes();
				}
			}
			else if (setCurOption != null)
			{
				if (controls.ACCEPT && (setCurOption.type == 'string'
					|| setCurOption.type == 'int' || setCurOption.type == 'float'
					|| setCurOption.type == 'percent'))
				{
					openOptionPopup(setCurOption);
					return;
				}

				var isWindowMode:Bool = (setCurOption.variable == 'windowedmode');

				if (controls.UI_LEFT || controls.UI_RIGHT)
				{
					var pressed = (controls.UI_LEFT_P || controls.UI_RIGHT_P);
					if (holdTime > 0.5 || pressed)
					{
						if (pressed)
						{
							var add:Dynamic = null;
							if (setCurOption.type != 'string')
								add = controls.UI_LEFT ? -setCurOption.changeValue : setCurOption.changeValue;

							switch (setCurOption.type)
							{
								case 'int' | 'float' | 'percent':
									holdValue = setCurOption.getValue() + add;
									if (holdValue < setCurOption.minValue) holdValue = setCurOption.minValue;
									else if (holdValue > setCurOption.maxValue) holdValue = setCurOption.maxValue;

									switch (setCurOption.type)
									{
										case 'int':
											holdValue = Math.round(holdValue);
											setCurOption.setValue(holdValue);
										case 'float' | 'percent':
											holdValue = FlxMath.roundDecimal(holdValue, setCurOption.decimals);
											setCurOption.setValue(holdValue);
									}
									settingsUpdateText(setCurOption);
									setCurOption.change();
									FlxG.sound.play(Paths.sound('scrollMenu'));

								case 'string':
									var num:Int = setCurOption.curOption;
									if (controls.UI_LEFT_P) --num;
									else num++;

									if (num < 0) num = setCurOption.options.length - 1;
									else if (num >= setCurOption.options.length) num = 0;

									setCurOption.curOption = num;
									setCurOption.setValue(setCurOption.options[num]);
									settingsUpdateText(setCurOption);

									if (!isWindowMode) setCurOption.change();
									FlxG.sound.play(Paths.sound('scrollMenu'));
							}
						}
						else if (setCurOption.type != 'string')
						{
							holdValue += setCurOption.scrollSpeed * elapsed * (controls.UI_LEFT ? -1 : 1);
							if (holdValue < setCurOption.minValue) holdValue = setCurOption.minValue;
							else if (holdValue > setCurOption.maxValue) holdValue = setCurOption.maxValue;

							switch (setCurOption.type)
							{
								case 'int':
									setCurOption.setValue(Math.round(holdValue));
								case 'float' | 'percent':
									setCurOption.setValue(FlxMath.roundDecimal(holdValue, setCurOption.decimals));
							}
							settingsUpdateText(setCurOption);
							setCurOption.change();
						}
					}

					if (setCurOption.type != 'string') holdTime += elapsed;
				}
				else if (controls.UI_LEFT_R || controls.UI_RIGHT_R)
				{
					settingsClearHold();
				}

				if (isWindowMode && controls.ACCEPT)
				{
					FlxG.sound.play(Paths.sound('confirmMenu'));
					setCurOption.change();
				}
			}

			if (#if (TOUCH_CONTROLS || desktop) (virtualPad != null && virtualPad.buttonC.justPressed) || #end controls.RESET)
			{
				for (i in 0...setOptionsArray.length)
				{
					var leOption = setOptionsArray[i];
					// button 是动作行, 没有默认值可恢复; RESET 不能触发它的 onChange (会执行动作)。
					if (leOption.type == 'button')
						continue;
					leOption.setValue(leOption.defaultValue);
					if (leOption.type != 'bool')
					{
						if (leOption.type == 'string')
							leOption.curOption = leOption.options.indexOf(leOption.getValue());
						settingsUpdateText(leOption);
					}
					leOption.change();
				}
				FlxG.sound.play(Paths.sound('cancelMenu'));
				settingsReloadCheckboxes();
			}
		}

		if (setBoyfriend != null && !setBoyfriend.isAnimationNull() && setBoyfriend.isAnimationFinished())
			setBoyfriend.dance();

		if (nextAccept > 0) nextAccept -= 1;
	}

	function settingsUpdateText(option:Option)
	{
		var text:String = option.displayFormat;
		var val:Dynamic = option.getValue();
		if (option.type == 'percent') val *= 100;
		else if (option.type == 'string') val = option.localizedValueText(val);
		var def:Dynamic = option.defaultValue;
		// button 行的 child 是 "[Press ENTER]" 标签, 没有 %v 值可显示, 不能覆盖。
		if (option.type != 'button')
			option.text = text.replace('%v', val).replace('%d', def);
		if (option.child != null)
		{
			var parentText = setGrpOptions.members[setOptionsArray.indexOf(option)];
			if (parentText != null)
				option.child.offsetX = parentText.width + 80;
		}
	}

	function settingsClearHold()
	{
		if (holdTime > 0.5) FlxG.sound.play(Paths.sound('scrollMenu'));
		holdTime = 0;
	}

	function openOptionPopup(option:Option):Void
	{
		if (option == null) return;
		optionPopupOpen = true;
		#if (TOUCH_CONTROLS || desktop)
		removeVirtualPad();
		#end
		openSubState(new OptionPopupSubState(option, function() {
			settingsUpdateText(option);
		}));
	}

	function changeSettingsSelection(change:Int = 0, ?playSound:Bool = true)
	{
		setCurSelected += change;
		if (setCurSelected < 0) setCurSelected = setOptionsArray.length - 1;
		if (setCurSelected >= setOptionsArray.length) setCurSelected = 0;

		setDescText.text = setOptionsArray[setCurSelected].description;
		setDescText.screenCenter(Y);
		setDescText.y += 270;

		var bullShit:Int = 0;
		for (item in setGrpOptions.members)
		{
			item.targetY = bullShit - setCurSelected;
			bullShit++;
			item.alpha = 0.6;
			if (item.targetY == 0) item.alpha = 1;
		}
		for (text in setGrpTexts)
		{
			text.alpha = 0.6;
			if (text.ID == setCurSelected) text.alpha = 1;
		}

		setDescBox.setPosition(setDescText.x - 10, setDescText.y - 10);
		setDescBox.setGraphicSize(Std.int(setDescText.width + 20), Std.int(setDescText.height + 25));
		setDescBox.updateHitbox();

		if (setBoyfriend != null)
			setBoyfriend.visible = setOptionsArray[setCurSelected].showBoyfriend;
		// 0.7.3+ Note 皮肤预览: 只有选中 noteSkin 那一行才显示
		if (settingsNotes != null && settingsNoteSkinID >= 0)
		{
			// 0.7.3 同款: 选中 Note 皮肤行时滑入预览, 离开滑出
			var targetY:Float = (setCurSelected == settingsNoteSkinID) ? 120 : -200;
			for (i in 0...settingsNotes.members.length)
			{
				var note:StrumNote = settingsNotes.members[i];
				if (note == null) continue;
				if (settingsNotesTween[i] != null) settingsNotesTween[i].cancel();
				settingsNotesTween[i] = FlxTween.tween(note, {y: targetY},
					Math.abs(note.y - targetY) / 600, {ease: FlxEase.quadInOut});
			}
		}

		setCurOption = setOptionsArray[setCurSelected];
		if (playSound == true)
			FlxG.sound.play(Paths.sound('scrollMenu'));
	}

	function settingsReloadBoyfriend()
	{
		if (setBoyfriend != null)
		{
			remove(setBoyfriend);
			setBoyfriend.destroy();
		}

		setBoyfriend = new Character(840, 170, 'bf', true);
		setBoyfriend.setGraphicSize(Std.int(setBoyfriend.width * 0.75));
		setBoyfriend.updateHitbox();
		if (!setBoyfriend.isAnimationNull())
			setBoyfriend.dance();
		add(setBoyfriend);
		setBoyfriend.visible = false;
	}

	function settingsReloadCheckboxes()
	{
		for (checkbox in setCheckboxGroup)
			checkbox.daValue = (setOptionsArray[checkbox.ID].getValue() == true);
	}

	function settingsSaveState()
	{
		ClientPrefs.saveSettings();
	}

	// Options built from JSON via OptionLoader — see assets/data/options/

	// ═══════════════════════════════════════════════════════════════════════════
	//  Transition animations
	// ═══════════════════════════════════════════════════════════════════════════

	/** Enter animation: items slide up with overshoot. */
	function playEnterAnimation()
	{
		bg.alpha = 0;
		FlxTween.tween(bg, {alpha: 1}, ENTER_DURATION * 0.7, {ease: FlxEase.quadOut});

		tweenEnterSprites(function(sprite) {
			sprite.y += 60;
			sprite.alpha = 0;
			FlxTween.tween(sprite, {y: sprite.y - 60, alpha: 1}, ENTER_DURATION * 1.2, {
				ease: FlxEase.backOut,
				startDelay: Math.random() * 0.2
			});
		});
	}

	/** Exit animation: fade out all. */
	function playExitAnimation(?onComplete:Void->Void)
	{
		transitioning = true;

		FlxTween.tween(bg, {alpha: 0}, 0.25, {ease: FlxEase.quadIn});

		var sprites = (currentMode == MODE_CATEGORY) ? categorySprites : settingsSprites;
		if (sprites != null)
		{
			for (s in sprites)
			{
				if (s == null) continue;
				FlxTween.tween(s, {alpha: 0}, 0.2, {
					ease: FlxEase.quadIn,
					startDelay: Math.random() * 0.1
				});
			}
		}

		if (onComplete != null)
			new FlxTimer().start(0.3, function(_) { onComplete(); });
	}

	/** Switch to settings view: category slides left, settings slides in. */
	function switchToSettings(page:String)
	{
		if (transitioning) return;
		transitioning = true;

		var categories = OptionLoader.getCategories(#if mobile true #else false #end);
		var catDef:Dynamic = null;
		for (c in categories)
			if (c.id == page) { catDef = c; break; }

		if (catDef == null)
		{
			TraceManager.error('trace.options.unknownCategory', 'Unknown settings category: {}', [page]);
			transitioning = false;
			return;
		}

		var optionsArray:Array<Option> = OptionLoader.loadOptionsForCategory(catDef);
		var title:String = OptionLoader.getCategoryName(catDef);
		var rpcTitle = (catDef.rpcTitleKey != null)
			? Language.get(catDef.rpcTitleKey, title + ' Settings Menu')
			: title + ' Settings Menu';

		if (optionsArray == null || optionsArray.length == 0)
		{
			TraceManager.warn('trace.options.emptyCategory', 'No options found for category: {}', [page]);
			transitioning = false;
			return;
		}

		hideAllSprites(settingsSprites);
		hideSubGroups();
		buildSettingsView(optionsArray, title, rpcTitle);
		for (s in settingsSprites)
		{
			if (s == null) continue;
			s.alpha = 0;
			s.visible = true;
		}
		setSubGroupsVisible(true);

		currentMode = MODE_SETTINGS;
		currentSettingsPage = page;

		tweenSpriteSlideOut(categorySprites, -FlxG.width, TRANSITION_DURATION, FlxEase.cubeIn, function() {
			hideAllSprites(categorySprites);
		});

		setSubGroupsVisible(true);
		tweenSpriteSlideIn(settingsSprites, FlxG.width, TRANSITION_DURATION, FlxEase.backOut, function() {
			if (setDescBox != null) setDescBox.alpha = 0.6;
			transitioning = false;
		}, 0.1);

		#if (TOUCH_CONTROLS || desktop)
		removeVirtualPad();
		addVirtualPad(LEFT_FULL, A_B_C);
		#end
	}

	/** Switch to category view: settings slides right, category slides in. */
	function switchToCategory()
	{
		if (transitioning) return;
		transitioning = true;

		tweenSpriteSlideOut(settingsSprites, FlxG.width, TRANSITION_DURATION, FlxEase.cubeIn, function() {
			destroySettingsSprites();
		});

		bg.color = 0xff17719b;

		showAllSprites(categorySprites);
		catGrid.x = 0;
		for (i in 0...catGrpOptions.length)
		{
			var item = catGrpOptions.members[i];
			if (item == null) continue;
			item.x = 150;
			item.y = baseY + i * itemSpacing + scrollOffset;
		}
		var selItem = catGrpOptions.members[curSelected];
		if (selItem != null && selItem.visible)
		{
			catSelectorLeft.x = selItem.x - 63;
			catSelectorLeft.y = selItem.y;
			catSelectorRight.x = selItem.x + selItem.width + 15;
			catSelectorRight.y = selItem.y;
		}
		tweenSpriteSlideIn(categorySprites, -FlxG.width, TRANSITION_DURATION, FlxEase.backOut, function() {
			transitioning = false;
			currentMode = MODE_CATEGORY;
		}, 0.1);

		#if (TOUCH_CONTROLS || desktop)
		removeVirtualPad();
		addVirtualPad(UP_DOWN, A_B_C);
		#end
	}

	/** Tween enter sprites. */
	function tweenEnterSprites(fn:FlxSprite->Void)
	{
		var sprites = (currentMode == MODE_CATEGORY) ? categorySprites : settingsSprites;
		if (sprites == null) return;
		for (s in sprites)
		{
			if (s != null) fn(s);
		}
	}

	/** Slide sprites out by offsetX. */
	function tweenSpriteSlideOut(sprites:Array<FlxSprite>, offsetX:Float,
			duration:Float, ease:Float->Float, ?onComplete:Void->Void)
	{
		var completed:Int = 0;
		var total:Int = 0;
		for (s in sprites)
		{
			if (s == null) continue;
			total++;
			FlxTween.tween(s, {x: s.x + offsetX, alpha: 0}, duration, {
				ease: ease,
				onComplete: function(_) {
					completed++;
					if (completed >= total && onComplete != null) onComplete();
				}
			});
		}
		if (total == 0 && onComplete != null) onComplete();
	}

	/** Slide sprites in from offsetX. */
	function tweenSpriteSlideIn(sprites:Array<FlxSprite>, fromOffsetX:Float,
			duration:Float, ease:Float->Float, ?onComplete:Void->Void, startDelay:Float = 0)
	{
		var completed:Int = 0;
		var total:Int = 0;
		for (s in sprites)
		{
			if (s == null) continue;
			total++;
				var targetX = s.x;
			s.x = targetX + fromOffsetX;
			s.alpha = 0;
			FlxTween.tween(s, {x: targetX, alpha: 1}, duration, {
				ease: ease,
				startDelay: startDelay,
				onComplete: function(_) {
					completed++;
					if (completed >= total && onComplete != null) onComplete();
				}
			});
		}
		if (total == 0 && onComplete != null) onComplete();
	}

	/** Hide all sprites in array. */
	function hideAllSprites(sprites:Array<FlxSprite>)
	{
		if (sprites == null) return;
		for (s in sprites)
			if (s != null) s.visible = false;
	}

	/** Show all sprites in array. */
	function showAllSprites(sprites:Array<FlxSprite>)
	{
		if (sprites == null) return;
		for (s in sprites)
			if (s != null) s.visible = true;
	}

	/** Set settings sub-group visibility. */
	function setSubGroupsVisible(visible:Bool)
	{
		if (setGrpOptions != null) setGrpOptions.visible = visible;
		if (setGrpTexts != null) setGrpTexts.visible = visible;
		if (setCheckboxGroup != null) setCheckboxGroup.visible = visible;
	}

	/** Hide settings sub-groups. */
	function hideSubGroups() { setSubGroupsVisible(false); }

	// ═══════════════════════════════════════════════════════════════════════════
	//  Callbacks
	// ═══════════════════════════════════════════════════════════════════════════

	// ── Graphics ──

	function onChangeSeparateUpdateDraw()
	{
		if (FlxG.game != null)
			FlxG.game.separateUpdateDraw = ClientPrefs.data.separateUpdateDraw;
	}

	function onChangeAntiAliasing()
	{
		forEachOfType(FlxSprite, function(s:FlxSprite) {
			if (!(s is FlxText))
				s.antialiasing = ClientPrefs.data.globalAntialiasing;
		});
	}

	function onChangeFramerate()
	{
		FlxG.updateFramerate = ClientPrefs.data.framerate;
		if (!ClientPrefs.data.separateUpdateDraw)
		{
			FlxG.drawFramerate = ClientPrefs.data.framerate;
			ClientPrefs.data.drawFramerate = ClientPrefs.data.framerate;
		}
	}

	function onChangeDrawFramerate()
	{
		FlxG.drawFramerate = ClientPrefs.data.drawFramerate;
		if (!ClientPrefs.data.separateUpdateDraw)
		{
			FlxG.updateFramerate = ClientPrefs.data.drawFramerate;
			ClientPrefs.data.framerate = ClientPrefs.data.drawFramerate;
		}
	}

	#if desktop
	function onChangeWindowMode()
	{
		var mode:String = ClientPrefs.data.windowedmode;

		try {
			var window = Lib.application.window;
			switch(mode)
			{
				case 'windowed':
					FlxG.fullscreen = false;
					Lib.application.window.fullscreen = false;
					Lib.application.window.borderless = false;
				case 'fullscreen':
					FlxG.fullscreen = true;
					Lib.application.window.fullscreen = true;
					Lib.application.window.borderless = false;

				case 'borderless':
				{
					// 使用 SDL3 borderless desktop fullscreen：单次原生切换，避免手动 resize 的多次黑屏。
					// 不额外操作 FlxG.fullscreen / window.borderless，减少重复切换和样式抖动。
					window.fullscreen = true;
				}

			}

		} catch(e:Dynamic) {
			TraceManager.error('trace.options.windowModeFailed', 'Failed to change window mode: {}', [e]);
		}
	}

	function onChangeRunInBackground()
	{
		FlxG.autoPause = ClientPrefs.data.runInBackground ? false : ClientPrefs.data.autoPause;
		Main.setupBackgroundDim();
	}

	function onChangeBackgroundDim()
	{
		if (!ClientPrefs.data.backgroundDim)
		{
			if (Main.originalVolume >= 0)
			{
				FlxG.sound.volume = Main.originalVolume;
				Main.originalVolume = -1;
			}
		}
		Main.setupBackgroundDim();
	}
	#end

	// ── Visuals ──

	function onChangeFPSCounter()
	{
		if (Main.fpsVar != null) {
			Main.fpsVar.visible = ClientPrefs.data.showFPS && !Main.useOldFPS;
			Main.oldFpsVar.visible = ClientPrefs.data.showFPS && Main.useOldFPS;
		}
	}

	function onChangePauseMusic()
	{
		// nothing needed
	}

	// ── Gameplay ──

	function onChangeGameplayHitsoundVolume()
	{
		onChangeHitsound();
	}

	// ── LeatherEngine 移植: 击打音效 / 判定手感 ──

	function onChangeHitsound()
	{
		var hs:String = ClientPrefs.data.hitsound;
		if (hs == null || hs.length == 0 || hs.toLowerCase() == 'none' || ClientPrefs.data.hitsoundVolume <= 0) return;

		try
		{
			var loaded:Sound = Paths.sound('hitsounds/' + hs);
			if (loaded != null)
				FlxG.sound.play(loaded, ClientPrefs.data.hitsoundVolume);
		}
		catch (e:Dynamic)
		{
			// 自定义音效文件缺失时回退到默认 hitsound
			try { FlxG.sound.play(Paths.sound('hitsound'), ClientPrefs.data.hitsoundVolume); } catch (_:Dynamic) {}
		}
	}

	function onChangeMarvelousRatings()
	{
		// 只需要保存; ratingsData 会在下次进入 PlayState 时按此开关重建
		ClientPrefs.saveSettings();
	}

	function onChangeJudgementPreset()
	{
		var preset:String = ClientPrefs.data.judgementPreset;
		if (preset == null || preset.length == 0 || preset == 'Custom') return;

		var timings:Array<Int> = backend.Ratings.returnPreset(preset);
		if (timings == null || timings.length < 4) return;

		ClientPrefs.data.judgementTimings = timings.copy();
		backend.Ratings.syncWindows();

		// 刷新所有选项显示 (窗口值会随预设改变)
		if (setOptionsArray != null)
			for (opt in setOptionsArray) settingsUpdateText(opt);

		ClientPrefs.saveSettings();
	}

	function onChangeMarvelousWindow()
	{
		ClientPrefs.data.judgementTimings[0] = ClientPrefs.data.marvelousWindow;
		backend.Ratings.syncWindows();
		ClientPrefs.data.judgementPreset = 'Custom';
		refreshJudgementPresetText();
	}

	function onChangeSickWindow()
	{
		ClientPrefs.data.judgementTimings[1] = ClientPrefs.data.sickWindow;
		backend.Ratings.syncWindows();
		ClientPrefs.data.judgementPreset = 'Custom';
		refreshJudgementPresetText();
	}

	function onChangeGoodWindow()
	{
		ClientPrefs.data.judgementTimings[2] = ClientPrefs.data.goodWindow;
		backend.Ratings.syncWindows();
		ClientPrefs.data.judgementPreset = 'Custom';
		refreshJudgementPresetText();
	}

	function onChangeBadWindow()
	{
		ClientPrefs.data.judgementTimings[3] = ClientPrefs.data.badWindow;
		backend.Ratings.syncWindows();
		ClientPrefs.data.judgementPreset = 'Custom';
		refreshJudgementPresetText();
	}
	/*

	function onChangeTailWindowMult()
	{
		var m:Float = ClientPrefs.data.tailWindowMult;
		if (Math.isNaN(m) || m <= 0)
			ClientPrefs.data.tailWindowMult = 2.0;
		else if (m > 8)
			ClientPrefs.data.tailWindowMult = 8;
		ClientPrefs.saveSettings();
	}
*/
	/** 刷新"判定预设"选项的显示文本 (改为 Custom 后立即更新) */
	function refreshJudgementPresetText()
	{
		if (setOptionsArray == null) return;
		for (opt in setOptionsArray)
			if (opt.variable == 'judgementPreset') settingsUpdateText(opt);
	}

	// ── Extra ──

	function onChangeLanguage()
	{
		#if (TOUCH_CONTROLS || desktop)
		removeVirtualPad();
		#end
		Language.load();
		rebuildCurrentPage();
		updateCategoryTexts();
	}

	function onChangeTraceConsole()
	{
		#if (desktop && cpp && windows)
		mohong.TraceManager.enableConsoleOutput(false);
		mohong.TraceConsole.stop();

		if (mohong.Windows.hasConsole())
			mohong.Windows.freeConsole();
		else
		{
			if (mohong.Windows.allocConsole())
			{
				mohong.Windows.enableAnsiColors();
				mohong.TraceManager.enableConsoleOutput(true);
				mohong.TraceConsole.start();
			}
		}
		#end
	}

	function onChangeTraceConsoleLevel()
	{
		#if (desktop && cpp && windows)
		if (!mohong.Windows.hasConsole()) return;
		var level:String = ClientPrefs.data.traceConsoleLevel;
		if (level != null && level.length > 0)
			mohong.TraceManager.applyConsoleLevel(level);
		#end
	}

	function onChangeTouchSwipe()
	{
		syncDragToWheel();
	}

	/** 「清除图片缓存」动作按钮: 释放所有未被引用的缓存图片并弹窗反馈。 */
	function onClearImageCache()
	{
		var result = Paths.clearImageCache();
		var msg:String;
		if (result.count <= 0)
		{
			msg = Language.get('option.clearImageCache.none', 'No unused cached images to release.');
		}
		else
		{
			var mbStr:String = Std.string(Math.round(result.bytes / 1048576 * 10) / 10);
			msg = Language.get('option.clearImageCache.released', 'Released {n} graphics (~{mb} MB).')
				.replace('{n}', Std.string(result.count))
				.replace('{mb}', mbStr);
		}
		backend.Dialog.show(Language.get('option.clearImageCache.doneTitle', 'Image Cache'), msg, 'Info');
	}

	function syncDragToWheel()
	{
		#if !FLX_UNIT_TEST
		if (FlxG.mouse != null)
			FlxG.mouse.dragToWheelEnabled = ClientPrefs.data.touchSwipeEnabled;
		#end
	}

	// ── Helpers ──

	/** Rebuild current page (e.g. after language switch). */
	function rebuildCurrentPage()
	{
		OptionLoader.reloadAll();

		if (currentMode == MODE_CATEGORY)
		{
			updateCategoryTexts();
		}
		else
		{
			switchToSettings(currentSettingsPage);
		}
	}

	function updateCategoryTexts()
	{
		refreshCategoryLists();
		for (i in 0...catGrpOptions.length)
		{
			var item = catGrpOptions.members[i];
			if (item != null && i < optionTexts.length)
			{
				item.text = optionTexts[i];
				item.setFormat(Paths.optionsfont(), 50, FlxColor.WHITE, LEFT,
					FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
				item.borderSize = 2.5;
			}
		}
	}

	// ═══════════════════════════════════════════════════════════════
	//  SubState return recovery
	// ═══════════════════════════════════════════════════════════════
	override function closeSubState()
	{
		super.closeSubState();
		ClientPrefs.saveSettings();

		if (optionPopupOpen)
		{
			// Closing the dropdown/slider popup should stay in the settings page,
			// not bounce back to the category view.
			optionPopupOpen = false;
			transitioning = false;
			#if (TOUCH_CONTROLS || desktop)
			addVirtualPad(LEFT_FULL, A_B_C);
			addPadCamera();
			#end
			return;
		}

		OptionLoader.reloadAll();

		transitioning = false;
		currentMode = MODE_CATEGORY;
		destroySettingsSprites();

		bg.color = 0xff17719b;
		FlxTween.tween(bg, {alpha: 1}, 0.3, {ease: FlxEase.quadOut});

		showAllSprites(categorySprites);
		for (s in categorySprites)
		{
			if (s == null) continue;
			s.alpha = 1;
		}
		changeCategorySelection(0, false);

		#if (TOUCH_CONTROLS || desktop)
		addVirtualPad(UP_DOWN, A_B_C);
		#end
	}

	override function destroy()
	{
		super.destroy();
	}
}
	
