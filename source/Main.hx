package;


import flixel.graphics.FlxGraphic;
 
import flixel.FlxGame;
import flixel.FlxG;
import flixel.FlxState;
import openfl.Assets;
import openfl.Lib;
import openfl.display.FPS;
import openfl.display.OldFPS;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.display.StageScaleMode;

//crash handler stuff
#if CRASH_HANDLER
import lime.app.Application;
import openfl.events.UncaughtErrorEvent;
import haxe.CallStack;
import haxe.io.Path;
#if cpp
import Discord.DiscordClient;
#end
import sys.FileSystem;
import sys.io.File;
import sys.io.Process;
#end
import mohong.Windows;
import mohong.TraceManager;
import mohong.TraceConsole;
import backend.Dialog;
import states.CrashCatcherState;

using StringTools;

class Main extends Sprite
{
	public static var initialWindowX:Int;
	public static var initialWindowY:Int;
	var gameWidth:Int = 1280; // Width of the game in pixels (might be less / more in actual pixels depending on your zoom).
	var gameHeight:Int = 720; 
	// Height of the game in pixels (might be less / more in actual pixels depending on your zoom).
	var initialState:Class<FlxState> = TitleState; // The FlxState the game starts with.
	#if !android
	var zoom:Float = 1; // If -1, zoom is automatically calculated to fit the window dimensions.
	#else
	var zoom:Float = 1;
	#end
	var framerate:Int = 60; // How many frames per second the game should run at.
	var skipSplash:Bool = true; // Whether to skip the flixel splash screen that appears in release mode.
	var startFullscreen:Bool = false; // Whether to start the game in fullscreen on desktop targets
	public static var fpsVar:FPS;
	public static var oldFpsVar:OldFPS;
	public static var useOldFPS:Bool = false;
	public static var useOldPause:Null<Bool> = null;
	public static var originalVolume:Float = -1;
	static var backgroundDimInitialized:Bool = false;
	// You can pretty much ignore everything from here on - your code should go in your states.

	public static function main():Void
	{
		Lib.current.addChild(new Main());
		#if desktop
		applyWindowMode();
		Windows.enableDarkMode();
		#end
	}  
		#if desktop
		private static function applyWindowMode():Void
		{
			var mode = ClientPrefs.data.windowedmode;
			var window = Lib.application.window;
			
			switch(mode) {
				case 'borderless':
					window.fullscreen = false;
					window.borderless = true;
					window.width = Lib.current.stage.stageWidth;
					window.height = Lib.current.stage.stageHeight;
					window.x = 0;
					window.y = 0;
				case 'fullscreen':
					window.fullscreen = true;
				default:
					FlxG.fullscreen = false;
					Lib.application.window.fullscreen = false;
					Lib.application.window.borderless = false;
			}
		}
		#end

	public function new()
	{
		#if android
		SUtil.doPermissionsShit();
		#end
		Sys.setCwd(SUtil.getStorageDirectory());
		
		super();
		

		#if HSCRIPT_ALLOWED
        HScript.initialize();
        HScript.loadModBootScript();
        #end

        // 初始化 TraceManager（尽早拦截所有 trace() 调用）
        TraceManager.init();
        TraceManager.info('trace.systemInit', 'TraceManager initialized successfully.');

        // Windows 桌面启动 TraceConsole 交互式面板
        #if (desktop && !android)
        TraceConsole.start();
        #end

		if (stage != null)
		{
			init();
		}
		else
		{
			addEventListener(Event.ADDED_TO_STAGE, init);
		}
	}

	private function init(?E:Event):Void
	{
		if (hasEventListener(Event.ADDED_TO_STAGE))
		{
			removeEventListener(Event.ADDED_TO_STAGE, init);
		}

		setupGame();
	}

	private function setupGame():Void
	{
		var stageWidth:Int = Lib.current.stage.stageWidth;
		var stageHeight:Int = Lib.current.stage.stageHeight;

		if (zoom == -1)
		{
			var ratioX:Float = stageWidth / gameWidth;
			var ratioY:Float = stageHeight / gameHeight;
			zoom = Math.min(ratioX, ratioY);
			gameWidth = Math.ceil(stageWidth / zoom);
			gameHeight = Math.ceil(stageHeight / zoom);
		}
		ClientPrefs.loadDefaultKeys();

		addChild(new FlxGame(gameWidth, gameHeight, initialState, zoom, framerate, framerate, skipSplash, startFullscreen));

		// Sync separateUpdateDraw (property setter handles timer + FlxG sync)
		if (FlxG.game != null)
			FlxG.game.separateUpdateDraw = ClientPrefs.data.separateUpdateDraw;

		// Ensure draw wrapper is null (threaded rendering removed)
		if (FlxG.game != null)
			FlxG.game.drawWrapper = null;

		#if CRASH_HANDLER
		// Wire the timer crash callback so separate-update-mode errors are
		// handled gracefully with the original stack trace preserved.
		if (FlxG.game != null)
		{
			FlxG.game.onTimerCrashCallback = function(msg:String, stack:String)
			{
				var path:String;
				var dateNow:String = Date.now().toString();
				dateNow = dateNow.replace(" ", "_");
				dateNow = dateNow.replace(":", "'");
				path = "./crash/" + "MohonghEngine_" + dateNow + ".txt";

				var fullMsg:String = stack + "\nUncaught Error: " + msg + "\nPlease report this error to the GitHub page: https://github.com/mohong2/MohongEngine\n\n> Crash Handler written by: sqirra-rng ";

				if (!sys.FileSystem.exists("./crash/"))
					sys.FileSystem.createDirectory("./crash/");
				sys.io.File.saveContent(path, fullMsg + "\n");

				Sys.println(fullMsg);
				Sys.println("Crash dump saved in " + haxe.io.Path.normalize(path));

				// Store crash info for the in-game crash catcher
				states.CrashCatcherState.lastCrashMessage = msg;
				states.CrashCatcherState.lastCrashStack = stack;
				states.CrashCatcherState.lastCrashPath = path;
				states.CrashCatcherState.crashCount++;

				// Show a native dialog first
				var dialogTitle:String = Language.get("CrashCatcher.dialog.title", "Game Crashed!");
				var githubUrl:String = Language.get("CrashCatcher.reportURL", "https://github.com/mohong2/MohongEngine/issues");
				var dialogMsg:String = Language.get("CrashCatcher.dialog.message",
					"The game has encountered an error and needs to recover.\n\nError: {error}\n\nCrash dump saved to: {path}\n\nPlease report this on GitHub:\n{url}\n\nClick OK to enter recovery screen.");
				dialogMsg = dialogMsg.replace("{error}", msg);
				dialogMsg = dialogMsg.replace("{path}", path);
				dialogMsg = dialogMsg.replace("{url}", githubUrl);
				backend.Dialog.show(dialogTitle, dialogMsg, 'Error');

				// Queue the state switch (FlxG.switchState sets _requestedState;
				// FlxGame.timerCrashRecovery will complete it via switchState())
				try
				{
					if (FlxG.game != null && !Std.isOfType(FlxG.state, states.CrashCatcherState))
					{
						FlxG.switchState(new states.CrashCatcherState());
					}
				}
				catch (ex:Dynamic)
				{
					// Fallback: show another dialog and exit
					var fallbackTitle:String = Language.get("CrashCatcher.dialog.fallbackTitle", "Fatal Error");
					var fallbackMsg:String = Language.get("CrashCatcher.dialog.fallbackMessage", "Could not enter recovery mode.\nThe game will now close.");
					backend.Dialog.show(fallbackTitle, fallbackMsg, 'Error');
					#if cpp
					DiscordClient.shutdown();
					#end
					Sys.exit(1);
				}
			};
		}
		#end

		// ── Window icon from active mod's pack.json ──
		// Uses ModConfig.setWindowIcon() which supports multi‑resolution icons
		// (16×16 … 64×64) and handles scaling.  Can also be called later at
		// runtime when the user switches mods (see ModState.applyModPackConfig).
		#if (desktop && MODS_ALLOWED)
		setModWindowIcon();
		#end

		// [TEST] Sync drag-to-wheel setting from ClientPrefs to FlxMouse at startup
		initDragToWheel();

		fpsVar = new FPS(10, 3, 0xFFFFFF);
		oldFpsVar = new OldFPS(10, 3, 0xFFFFFF);
		addChild(fpsVar);
		addChild(oldFpsVar);

		Lib.current.stage.align = "tl";
		Lib.current.stage.scaleMode = StageScaleMode.NO_SCALE;
		if(fpsVar != null) {
			fpsVar.visible = ClientPrefs.data.showFPS && !useOldFPS;
			oldFpsVar.visible = ClientPrefs.data.showFPS && useOldFPS;
		}

		// 每帧通过 hscript 触发 onFrameUpdate 事件，供脚本自定义更新
		#if HSCRIPT_ALLOWED
		addEventListener(Event.ENTER_FRAME, function(_) {
			HScript.callOnGlobalScript("onFrameUpdate", []);
		});
		#end
		#if html5
		FlxG.autoPause = false;
		FlxG.mouse.visible = false;
		#else
		FlxG.mouse.visible = true;
		#end
		
		#if CRASH_HANDLER
		Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onCrash);
		#end

		setupBackgroundDim();

		// ── Window close interceptor (X button) ──
		setupWindowCloseHandler();
	}

	/**
	 * Intercept the window close button (X) to warn about unsaved editor changes.
	 * 拦截窗口关闭按钮（X），在有未保存的编辑器更改时发出警告。
	 *
	 * Uses Lime's onClose event + cancel() mechanism.
	 * NativeWindow dispatches onClose, then checks onClose.canceled — if true,
	 * the native WM_CLOSE is blocked.
	 */
	static function setupWindowCloseHandler():Void
	{
		#if desktop
		var window = Lib.application.window;
		if (window == null) return;

		window.onClose.add(function()
		{
			if (backend.UnsavedChangesTracker.hasUnsavedChanges)
			{
				if (!backend.UnsavedChangesTracker.onWindowQuit())
				{
					// User cancelled — cancel the close event
					window.onClose.cancel();
				}
			}
		});
		#end
	}

	/** [TEST] Initialize FlxMouse drag-to-wheel from saved setting. */
	static function initDragToWheel():Void
	{
		#if !FLX_UNIT_TEST
		if (FlxG.mouse != null)
		{
			FlxG.mouse.dragToWheelEnabled = ClientPrefs.data.touchSwipeEnabled;
		}
		#end
	}

	public static function setupBackgroundDim():Void
	{
		#if desktop
		if (!backgroundDimInitialized)
		{
			backgroundDimInitialized = true;
			var stage = Lib.current.stage;
			if (stage != null)
			{
				stage.addEventListener(Event.DEACTIVATE, onStageDeactivate);
				stage.addEventListener(Event.ACTIVATE, onStageActivate);
			}
		}
		#end
	}

	#if desktop
	static function onStageDeactivate(_):Void
	{
		if (ClientPrefs.data.backgroundDim)
		{
			if (originalVolume < 0)
				originalVolume = FlxG.sound.volume;
			FlxG.sound.volume = 0.2;
		}
	}

	static function onStageActivate(_):Void
	{
		if (ClientPrefs.data.backgroundDim)
		{
			if (originalVolume >= 0)
			{
				FlxG.sound.volume = originalVolume;
				originalVolume = -1;
			}
		}
	}
	#end

	// Code was entirely made by sqirra-rng for their fnf engine named "Izzy Engine", big props to them!!!
	// very cool person for real they don't get enough credit for their work
	#if CRASH_HANDLER
	function onCrash(e:UncaughtErrorEvent):Void
	{
		var errMsg:String = "";
		var stackLines:String = "";
		var path:String;
		var callStack:Array<StackItem> = CallStack.exceptionStack(true);
		var dateNow:String = Date.now().toString();

		dateNow = dateNow.replace(" ", "_");
		dateNow = dateNow.replace(":", "'");

		path = "./crash/" + "MohonghEngine_" + dateNow + ".txt";

		for (stackItem in callStack)
		{
			switch (stackItem)
			{
				case FilePos(s, file, line, column):
					stackLines += file + " (line " + line + ")\n";
				default:
					Sys.println(stackItem);
			}
		}

		var fullMsg:String = stackLines + "\nUncaught Error: " + e.error + "\nPlease report this error to the GitHub page: https://github.com/mohong2/MohongEngine\n\n> Crash Handler written by: sqirra-rng ";

		if (!FileSystem.exists("./crash/"))
			FileSystem.createDirectory("./crash/");

		File.saveContent(path, fullMsg + "\n");

		Sys.println(fullMsg);
		Sys.println("Crash dump saved in " + Path.normalize(path));

		// Store crash info for the in-game crash catcher
		CrashCatcherState.lastCrashMessage = Std.string(e.error);
		CrashCatcherState.lastCrashStack = stackLines;
		CrashCatcherState.lastCrashPath = path;
		CrashCatcherState.crashCount++;

		// Show a native dialog first to notify the user before entering recovery UI
		var dialogTitle:String = Language.get("CrashCatcher.dialog.title", "Game Crashed!");
		var githubUrl:String = Language.get("CrashCatcher.reportURL", "https://github.com/mohong2/MohongEngine/issues");
		var dialogMsg:String = Language.get("CrashCatcher.dialog.message",
			"The game has encountered an error and needs to recover.\n\nError: {error}\n\nCrash dump saved to: {path}\n\nPlease report this on GitHub:\n{url}\n\nClick OK to enter recovery screen.");
		dialogMsg = dialogMsg.replace("{error}", Std.string(e.error));
		dialogMsg = dialogMsg.replace("{path}", path);
		dialogMsg = dialogMsg.replace("{url}", githubUrl);
		backend.Dialog.show(dialogTitle, dialogMsg, 'Error');

		// Try to switch to the crash catcher state via FlxG (queued, safe)
		var switched:Bool = false;
		try {
			if (FlxG.game != null && !Std.isOfType(FlxG.state, CrashCatcherState))
			{
				e.preventDefault();
				FlxG.switchState(new CrashCatcherState());
				switched = true;
			}
		} catch(ex:Dynamic) {
			// FlxG not available — will fall through to native dialog
		}

		if (!switched)
		{
			// Fallback: show another native dialog and exit
			var fallbackTitle:String = Language.get("CrashCatcher.dialog.fallbackTitle", "Fatal Error");
			var fallbackMsg:String = Language.get("CrashCatcher.dialog.fallbackMessage", "Could not enter recovery mode.\nThe game will now close.");
			backend.Dialog.show(fallbackTitle, fallbackMsg, 'Error');
			#if cpp
			DiscordClient.shutdown();
			#end
			Sys.exit(1);
		}
	}
	#end

	#if (desktop && MODS_ALLOWED)
	/** Set window icon from the active mod's pack.json using ModConfig. */
	static function setModWindowIcon():Void
	{
		try
		{
			var activeModPath:String = 'activeMod.txt';
			if (!sys.FileSystem.exists(activeModPath)) return;
			var modFolder:String = sys.io.File.getContent(activeModPath).trim();
			if (modFolder.length == 0) return;

			backend.ModConfig.setWindowIcon(modFolder);
		}
		catch (e:Dynamic)
		{
			// Silently fail – icon is cosmetic, not critical
		}
	}
	#end
}
