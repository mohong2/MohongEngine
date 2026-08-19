package states;
#if mobile
import lime.utils.Assets as LimeAssets;
import openfl.utils.Assets as OpenFLAssets;
import flixel.addons.util.FlxAsyncLoop;
import openfl.utils.ByteArray;
import haxe.io.Path;
#if sys
import sys.io.File;
import sys.FileSystem;
#end

using StringTools;
#end

import mohong.TraceManager;
#if VIDEOS_ALLOWED
import backend.VideoPreloader;
#end
#if MODS_ALLOWED
import states.ModState;
#end
import flixel.input.gamepad.FlxGamepad;
#if cpp
import Discord.DiscordClient;
import sys.thread.Thread;
#end

import flixel.FlxState;
import flixel.input.keyboard.FlxKey;
import flixel.addons.display.FlxGridOverlay;
import flixel.addons.transition.FlxTransitionSprite.GraphicTransTileDiamond;
import flixel.addons.transition.FlxTransitionableState;
import flixel.addons.transition.TransitionData;
import haxe.Json;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
#if MODS_ALLOWED
import sys.FileSystem;
import sys.io.File;
#end
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.frames.FlxFrame;
import flixel.group.FlxGroup;
import flixel.math.FlxRect;
import flixel.system.FlxSound;
import flixel.system.ui.FlxSoundTray;
import lime.app.Application;
import openfl.Assets;

using StringTools;

typedef TitleData =
{
	titlex:Float,
	titley:Float,
	startx:Float,
	starty:Float,
	gfx:Float,
	gfy:Float,
	backgroundSprite:String,
	bpm:Int
}

class TitleState extends MusicBeatState
{
	public static var instance:TitleState;
	public static var muteKeys:Array<FlxKey> = [FlxKey.ZERO];
	public static var volumeDownKeys:Array<FlxKey> = [FlxKey.NUMPADMINUS, FlxKey.MINUS];
	public static var volumeUpKeys:Array<FlxKey> = [FlxKey.NUMPADPLUS, FlxKey.PLUS];

	public static var initialized:Bool = false;

	#if mobile
	// CopyState related fields
	public static var locatedFiles:Array<String> = [];
	public static var maxLoopTimes:Int = 0;
	public static final IGNORE_FOLDER_FILE_NAME:String = "ignore.txt";
	public static final EXTRACTION_ASSET_ROOTS:Array<String> = ['assets', 'mods'];

	public var copyLoadingImage:FlxSprite;
	public var copyBottomBG:FlxSprite;
	public var copyLoadedText:FlxText;
	public var copyLoop:FlxAsyncLoop;

	var copyLoopTimes:Int = 0;
	var copyFailedFiles:Array<String> = [];
	var copyFailedFilesStack:Array<String> = [];
	var copyCanUpdate:Bool = true;
	var isCopying:Bool = false;
	var copyCompleted:Bool = false;

	#if android
	var extractionDone:Bool = false;
	var extractionResult:Dynamic = null;
	#end

	private static final textFilesExtensions:Array<String> = ['ini', 'txt', 'xml', 'hxs', 'hx', 'lua', 'json', 'frag', 'vert'];
	#end

	var blackScreen:FlxSprite;
	var credGroup:FlxGroup;
	var credTextShit:Alphabet;
	var textGroup:FlxGroup;
	var ngSpr:FlxSprite;

	var titleTextColors:Array<FlxColor> = [0xFF33FFFF, 0xFF3333CC];
	var titleTextAlphas:Array<Float> = [1, .64];

	var curWacky:Array<String> = [];

	var wackyImage:FlxSprite;

	#if TITLE_SCREEN_EASTER_EGG
	var easterEggKeys:Array<String> = [
		'SHADOW', 'RIVER', 'SHUBS', 'BBPANZU'
	];
	var allowedKeys:String = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
	var easterEggKeysBuffer:String = '';
	#end

	var mustUpdate:Bool = false;
	var _redirectChecked:Bool = false;

	var titleJSON:TitleData;

	public static var updateVersion:String = '';

	override public function create():Void
	{
		instance = this;

		#if VIDEOS_ALLOWED
		// Retry/warm LibVLC once the game loop is definitely running.
		VideoPreloader.warmup();
		#end

		#if MODS_ALLOWED
		// Load persisted mod selection FIRST so window title & state replacements
		// are active before any state transition occurs.
		MainMenuState.loadActiveMod();
		Paths.currentModDirectory = MainMenuState.selectedModFolder;

		// ── Purge ALL cached assets from the previous session/mod ──
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();

		// ── Rebuild global mod list BEFORE applyModPackConfig ──
		// so that HScript.reloadGlobalScripts() (called inside applyModPackConfig)
		// picks up scripts from runsGlobally mods.
		Paths.pushGlobalMods();

		// ── Apply new mod's pack.json config ──
		ModState.applyModPackConfig(MainMenuState.selectedModFolder);
		#if HSCRIPT_ALLOWED
		HScript.loadModBootScript();
		#end
		#else
		// Non-MODS_ALLOWED: still clear caches so we don't hold stale data
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();
		#end

		#if android
		FlxG.android.preventDefaultKeys = [BACK];
		#end

		FlxG.game.focusLostFramerate = 60;
		FlxG.sound.muteKeys = muteKeys;
		FlxG.sound.volumeDownKeys = volumeDownKeys;
		FlxG.sound.volumeUpKeys = volumeUpKeys;
		FlxG.keys.preventDefaultKeys = [TAB];

		PlayerSettings.init();

		curWacky = FlxG.random.getObject(getIntroTextShit());

		swagShader = new ColorSwap();

		// Load preferences BEFORE super.create() so MusicBeatState → Language.load()
		// picks up the user's saved language preference.
		FlxG.save.bind('funkin', 'ninjamuffin99');
		ClientPrefs.loadPrefs();

		super.create();

		#if LUA_ALLOWED
		initLuaScripts();
		setOnLuas('controls', controls);
		setOnLuas('state', this);
		callOnLuas('onCreatePost', []);
		#end

		#if (CHECK_FOR_UPDATES && ONLINE_ALLOWED)
		if(ClientPrefs.data.checkForUpdates && !closedState) {
			TraceManager.info('trace.title.checkUpdate', 'checking for update');
			#if desktop
			var http = new haxe.Http("https://raw.githubusercontent.com/mohong2/FNF-SeiunEngine/main/gitVersion.txt");
			#else
			var http = new haxe.Http("https://github.com/mohong2/FNF-SeiunEngine/blob/main/gitVersionAndroid.txt");
			#end
			http.onData = function (data:String)
			{
				updateVersion = data.split('\n')[0].trim();
				var curVersion:String = MainMenuState.psychEngineVersion.trim();
				TraceManager.info('trace.title.versionCheck', 'version online: {}, your version: {}', [updateVersion, curVersion]);
				if(updateVersion != curVersion) {
					TraceManager.warn('trace.title.versionMismatch', 'versions arent matching!');
					mustUpdate = true;
				}
			}

			http.onError = function (error) {
				TraceManager.error('trace.title.updateCheckError', 'error: {}', [error]);
			}

			http.request();
		}
		#end

		Highscore.load();

		titleJSON = Json.parse(Paths.getTextFromFile('images/gfDanceTitle.json'));

		#if TITLE_SCREEN_EASTER_EGG
		if (FlxG.save.data.psychDevsEasterEgg == null) FlxG.save.data.psychDevsEasterEgg = '';
		switch(FlxG.save.data.psychDevsEasterEgg.toUpperCase())
		{
			case 'SHADOW':
				titleJSON.gfx += 210;
				titleJSON.gfy += 40;
			case 'RIVER':
				titleJSON.gfx += 100;
				titleJSON.gfy += 20;
			case 'SHUBS':
				titleJSON.gfx += 160;
				titleJSON.gfy -= 10;
			case 'BBPANZU':
				titleJSON.gfx += 45;
				titleJSON.gfy += 100;
		}
		#end

		if(!initialized)
		{
			if(FlxG.save.data != null && FlxG.save.data.fullscreen)
			{
				FlxG.fullscreen = FlxG.save.data.fullscreen;
			}
			persistentUpdate = true;
			persistentDraw = true;
		}

		if (FlxG.save.data.weekCompleted != null)
		{
			StoryMenuState.weekCompleted = FlxG.save.data.weekCompleted;
		}

		FlxG.mouse.visible = false;

		#if mobile
		// Check if auto-extract is enabled in settings
		if (ClientPrefs.data.autoExtractAssets)
		{
			locatedFiles = [];
			maxLoopTimes = 0;
			#if android
			// Android: 原生 countMissingAssets() 是同步 JNI 全量扫 APK, 在低端
			// 设备上会让首帧前卡死甚至 ANR (表现为"第一次能进, 第二次进不去")。
			// 这里改成只读 .extract_version 版本标记快速判断; 真正需要补文件时
			// 才进复制界面, 而实际复制由 extension-androidtools 在后台线程完成。
			if (androidExtractionUpToDate())
				continueNormalFlow();
			else
				initCopyState(false);
			#else
			checkExistingFiles();

			if (maxLoopTimes > 0)
			{
				// Need to copy files, show copy UI
				initCopyState();
			}
			else
			{
				// No files to copy, continue normal flow
				continueNormalFlow();
			}
			#end
		}
		else
		{
			// Auto-extract disabled, skip straight to normal flow
			continueNormalFlow();
		}
		#else
		continueNormalFlow();
		#end
	}

		#if mobile
	/** @param showNotice Android 快速校验路径不弹"缺文件"对话框, 避免每次启动骚扰。 */
	function initCopyState(?showNotice:Bool = true):Void
	{
		isCopying = true;
		copyLoadedText = null;
		copyLoop = null;
		copyLoopTimes = 0;
		copyFailedFiles = [];
		copyFailedFilesStack = [];
		copyCanUpdate = true;
		copyCompleted = false;
		#if android
		extractionDone = false;
		extractionResult = null;
		#end

		if (showNotice)
		{
			SUtil.showPopUp(
				Language.get("TitleState.extractNotice", "Seems like you have some missing files that are necessary to run the game\nPress OK to begin the copy process"),
				Language.get("TitleState.extractTitle", "Notice!"));
		}

		add(new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, 0xffcaff4d));

		copyLoadingImage = new FlxSprite(0, 0, Paths.image('funkay'));
		copyLoadingImage.setGraphicSize(0, FlxG.height);
		copyLoadingImage.updateHitbox();
		copyLoadingImage.screenCenter();
		add(copyLoadingImage);

		copyBottomBG = new FlxSprite(0, FlxG.height - 26).makeGraphic(FlxG.width, 26, 0xFF000000);
		copyBottomBG.alpha = 0.6;
		add(copyBottomBG);

		copyLoadedText = new FlxText(copyBottomBG.x, copyBottomBG.y + 4, FlxG.width, '', 16);
		copyLoadedText.setFormat(Paths.languageFont(), 16, FlxColor.WHITE, CENTER);
		add(copyLoadedText);

		#if android
		// Streamed natively from the APK on a background thread (no OOM, atomic
		// writes, resume after crashes, progress via listener).
		startNativeExtraction();
		#else
		var ticks:Int = 15;
		if (maxLoopTimes <= 15)
			ticks = 1;

		copyLoop = new FlxAsyncLoop(maxLoopTimes, copyAsset, ticks);
		add(copyLoop);
		copyLoop.start();
		#end
	}

	#if android
	function startNativeExtraction():Void
	{
		var listener = new android.Tools.ExtractionListener();
		listener.progressHandler = function(file:String, done:Int, total:Int)
		{
			if (copyLoadedText != null)
				copyLoadedText.text = (total > 0) ? '$done/$total' : 'Completed!';
		};
		listener.completeHandler = function(resultJson:String)
		{
			extractionResult = null;
			try
			{
				if (resultJson != null && resultJson.length > 0)
					extractionResult = Json.parse(resultJson);
			}
			catch (e:Dynamic) {}
			extractionDone = true;
		};

		android.Tools.extractAssets(EXTRACTION_ASSET_ROOTS, SUtil.getStorageDirectory(), listener);
	}

	function handleNativeExtractionFinished():Void
	{
		copyCanUpdate = false;

		if (extractionResult != null)
		{
			var failures:Array<Dynamic> = Reflect.field(extractionResult, 'failures');
			if (failures != null)
			{
				for (f in failures)
				{
					var file:String = Reflect.field(f, 'file');
					var error:String = Reflect.field(f, 'error');
					copyFailedFiles.push('$file ($error)');
					copyFailedFilesStack.push('$file -> $error');
				}
			}
		}

		if (copyFailedFiles.length > 0)
		{
			SUtil.showPopUp(copyFailedFiles.join('\n'), 'Failed To Copy ${copyFailedFiles.length} File.');
			if (!FileSystem.exists('logs'))
				FileSystem.createDirectory('logs');
			File.saveContent('logs/' + Date.now().toString().replace(' ', '-').replace(':', "'") + '-CopyState' + '.txt', copyFailedFilesStack.join('\n'));
		}
		copyCompleted = true;
		FlxG.sound.play(Paths.sound('confirmMenu'));

		// Copy completed, proceed with normal flow
		isCopying = false;
		continueNormalFlow();
	}
	#end

	#if android
	/**
		快速判断上一次启动是否已经完整解压过当前版本资源。
		原生 .extract_version 内容为 "versionCode|versionName"; 标记存在且
		版本名匹配就直接放行, 不再同步遍历整个 APK (解决部分设备第二次
		启动时 countMissingAssets() 阻塞造成 ANR/黑屏的问题)。
	**/
	function androidExtractionUpToDate():Bool
	{
		try
		{
			var root:String = SUtil.getStorageDirectory();
			var marker:String = root + '.extract_version';
			if (!FileSystem.exists(marker))
				return false;
			// 至少确认关键资源目录已落盘, 防止用户手动删除 assets/ 后
			// 仅凭标记误判为"已就绪"。
			if (!FileSystem.exists(root + 'assets') || !FileSystem.isDirectory(root + 'assets'))
				return false;
			var stored:String = File.getContent(marker).trim();
			var version:String = null;
			try
			{
				var meta:Dynamic = Application.current.meta;
				if (meta != null)
					version = meta.get('version');
			}
			catch (e:Dynamic) {}
			if (version == null || version.length == 0)
				version = MainMenuState.psychEngineVersion;
			if (version == null || version.length == 0)
				return false;
			return stored == version || stored.indexOf('|' + version) >= 0;
		}
		catch (e:Dynamic)
		{
			return false;
		}
	}
	#end

	function checkExistingFiles():Void
	{
		#if android
		// Native scan: enumerates the real APK assets and stats the filesystem
		// directly — no OpenFL asset-cache dependency, no per-file Haxe overhead,
		// consistent behavior across every Android version.
		maxLoopTimes = android.Tools.countMissingAssets(EXTRACTION_ASSET_ROOTS, SUtil.getStorageDirectory());
		#else
		locatedFiles = OpenFLAssets.list();

		// Normalize paths: strip library prefixes (e.g. "extension-androidtools:assets/..." -> "assets/...")
		var normalized:Array<String> = [];
		for (file in locatedFiles)
		{
			var idx = file.indexOf(':');
			var cleanPath = (idx >= 0) ? file.substr(idx + 1) : file;
			if (cleanPath.startsWith('assets/') || cleanPath.startsWith('mods/'))
			{
				if (!normalized.contains(cleanPath))
					normalized.push(cleanPath);
			}
		}
		locatedFiles = normalized;

		var filesToRemove:Array<String> = [];

		for (file in locatedFiles)
		{
			// Skip embedded assets (they don't need filesystem extraction)
			if (file.startsWith("assets/embed/"))
			{
				filesToRemove.push(file);
				continue;
			}

			// Check if file already exists on filesystem, or if an ignore marker exists
			var ignoreFile = Path.join([Path.directory(file), IGNORE_FOLDER_FILE_NAME]);
			if (FileSystem.exists(file) || OpenFLAssets.exists(ignoreFile))
			{
				filesToRemove.push(file);
			}
		}

		for (file in filesToRemove)
			locatedFiles.remove(file);

		maxLoopTimes = locatedFiles.length;
		#end
	}

	function copyAsset():Void
	{
		if (copyLoopTimes >= locatedFiles.length) return;
		var file = locatedFiles[copyLoopTimes];
		copyLoopTimes++;
		if (file.startsWith("assets/embed/"))
		{
			return;
		}
		if (!FileSystem.exists(file))
		{
			var directory = Path.directory(file);
			if (!FileSystem.exists(directory))
				SUtil.mkDirs(directory);
			try
			{
				var resolved = getCopyFile(file);
				if (OpenFLAssets.exists(resolved))
				{
					if (textFilesExtensions.contains(Path.extension(file)))
						createContentFromInternal(file);
					else
						File.saveBytes(file, getFileBytes(resolved));
				}
				else
				{
					copyFailedFiles.push(file + " (File Doesn't Exist)");
					copyFailedFilesStack.push('Asset $file does not exist.');
				}
			}
			catch (e:haxe.Exception)
			{
				copyFailedFiles.push('$file (${e.message})');
				copyFailedFilesStack.push('$file (${e.stack})');
			}
		}
	}

	function createContentFromInternal(file:String):Void
	{
		var fileName = Path.withoutDirectory(file);
		var directory = Path.directory(file);
		try
		{
			var fileData:String = OpenFLAssets.getText(getCopyFile(file));
			if (fileData == null)
				fileData = '';
			if (!FileSystem.exists(directory))
				SUtil.mkDirs(directory);
			File.saveContent(Path.join([directory, fileName]), fileData);
		}
		catch (e:haxe.Exception)
		{
			copyFailedFiles.push('${getCopyFile(file)} (${e.message})');
			copyFailedFilesStack.push('${getCopyFile(file)} (${e.stack})');
		}
	}

	function getFileBytes(file:String):ByteArray
	{
		switch (Path.extension(file).toLowerCase())
		{
			case 'otf' | 'ttf':
				return ByteArray.fromFile(file);
			default:
				try
				{
					return OpenFLAssets.getBytes(file);
				}
				catch (e:Dynamic)
				{
					try
					{
						return LimeAssets.getBytes(file);
					}
					catch (e2:Dynamic)
					{
						var libraryPath = getCopyFile(file);
						return OpenFLAssets.getBytes(libraryPath);
					}
				}
		}
	}

	static function getCopyFile(file:String):String
	{
		if(OpenFLAssets.exists(file)) return file;

		@:privateAccess
		for(library in LimeAssets.libraries.keys()){
			if(OpenFLAssets.exists('$library:$file') && library != 'default')
				return '$library:$file';
		}

		if(LimeAssets.exists(file))
			return file;

		return file;
	}
	#end

	function continueNormalFlow():Void
	{
		#if FREEPLAY
		MusicBeatState.switchState(new FreeplayState());
		#elseif CHARTING
		if(ClientPrefs.data.newchartingstate)
			MusicBeatState.loadAndSwitchState(new editors.NewChartingState());
		else
			MusicBeatState.loadAndSwitchState(new editors.ChartingState());
		#else
		if(FlxG.save.data.flashing == null && !FlashingState.leftState) {
			#if MODS_ALLOWED
			var skipFlashing:Bool = false;
			if (MainMenuState.selectedModFolder != null && MainMenuState.selectedModFolder.length > 0) {
				var modCfg = backend.ModConfig.load(MainMenuState.selectedModFolder);
				skipFlashing = modCfg.disableWarningScreen;
			}
			if (skipFlashing) {
				FlxG.save.data.flashing = true;
				FlxG.save.flush();
			} else {
				FlxTransitionableState.skipNextTransIn = true;
				FlxTransitionableState.skipNextTransOut = true;
				MusicBeatState.switchState(new FlashingState());
			}
			#else
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
			MusicBeatState.switchState(new FlashingState());
			#end
		} else {
			#if desktop
			if (!DiscordClient.isInitialized)
			{
				DiscordClient.initialize();
				Application.current.onExit.add (function (exitCode) {
					DiscordClient.shutdown();
				});
			}
			#end

			if (initialized)
				startIntro();
			else
			{
				new FlxTimer().start(1, function(tmr:FlxTimer)
				{
					startIntro();
				});
			}
		}
		#end
	}

	var logoBl:FlxSprite;
	var gfDance:FlxSprite;
	var danceLeft:Bool = false;
	var titleText:FlxSprite;
	var swagShader:ColorSwap = null;

	function startIntro()
	{
		#if HSCRIPT_ALLOWED
		callOnHscript('onStartIntro', []);
		#end
		if (!initialized)
		{
			if(FlxG.sound.music == null) {
				FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
			}
		}

		Conductor.changeBPM(titleJSON.bpm);
		persistentUpdate = true;

		var bg:FlxSprite = new FlxSprite();

		if (titleJSON.backgroundSprite != null && titleJSON.backgroundSprite.length > 0 && titleJSON.backgroundSprite != "none"){
			bg.loadGraphic(Paths.image(titleJSON.backgroundSprite));
		}else{
			bg.makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		}

		add(bg);

		logoBl = new FlxSprite(titleJSON.titlex, titleJSON.titley);
		logoBl.frames = Paths.getSparrowAtlas('logoBumpin');

		logoBl.antialiasing = ClientPrefs.data.globalAntialiasing;
		logoBl.animation.addByPrefix('bump', 'logo bumpin', 24, false);
		logoBl.animation.play('bump');
		logoBl.updateHitbox();


		swagShader = new ColorSwap();
		gfDance = new FlxSprite(titleJSON.gfx, titleJSON.gfy);

		var easterEgg:String = FlxG.save.data.psychDevsEasterEgg;
		if(easterEgg == null) easterEgg = '';

		switch(easterEgg.toUpperCase())
		{
			#if TITLE_SCREEN_EASTER_EGG
			case 'SHADOW':
				gfDance.frames = Paths.getSparrowAtlas('ShadowBump');
				gfDance.animation.addByPrefix('danceLeft', 'Shadow Title Bump', 24);
				gfDance.animation.addByPrefix('danceRight', 'Shadow Title Bump', 24);
			case 'RIVER':
				gfDance.frames = Paths.getSparrowAtlas('RiverBump');
				gfDance.animation.addByIndices('danceLeft', 'River Title Bump', [15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29], "", 24, false);
				gfDance.animation.addByIndices('danceRight', 'River Title Bump', [29, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14], "", 24, false);
			case 'SHUBS':
				gfDance.frames = Paths.getSparrowAtlas('ShubBump');
				gfDance.animation.addByPrefix('danceLeft', 'Shub Title Bump', 24, false);
				gfDance.animation.addByPrefix('danceRight', 'Shub Title Bump', 24, false);
			case 'BBPANZU':
				gfDance.frames = Paths.getSparrowAtlas('BBBump');
				gfDance.animation.addByIndices('danceLeft', 'BB Title Bump', [14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27], "", 24, false);
				gfDance.animation.addByIndices('danceRight', 'BB Title Bump', [27, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13], "", 24, false);
			#end

			default:
				gfDance.frames = Paths.getSparrowAtlas('gfDanceTitle');
				gfDance.animation.addByIndices('danceLeft', 'gfDance', [30, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14], "", 24, false);
				gfDance.animation.addByIndices('danceRight', 'gfDance', [15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29], "", 24, false);
		}
		gfDance.antialiasing = ClientPrefs.data.globalAntialiasing;

		add(gfDance);
		gfDance.shader = swagShader.shader;
		add(logoBl);
		logoBl.shader = swagShader.shader;

		titleText = new FlxSprite(titleJSON.startx, titleJSON.starty);
		#if (desktop && MODS_ALLOWED)
		var path = "mods/" + Paths.currentModDirectory + "/images/titleEnter.png";
		if (!FileSystem.exists(path)){
			path = "mods/images/titleEnter.png";
		}
		if (!FileSystem.exists(path)){
			path = "assets/images/titleEnter.png";
		}
		titleText.frames = FlxAtlasFrames.fromSparrow(BitmapData.fromFile(path),File.getContent(StringTools.replace(path,".png",".xml")));
		#else

		titleText.frames = Paths.getSparrowAtlas('titleEnter');
		#end
		var animFrames:Array<FlxFrame> = [];
		@:privateAccess {
			titleText.animation.findByPrefix(animFrames, "ENTER IDLE");
			titleText.animation.findByPrefix(animFrames, "ENTER FREEZE");
		}

		if (animFrames.length > 0) {
			newTitle = true;

			titleText.animation.addByPrefix('idle', "ENTER IDLE", 24);
			titleText.animation.addByPrefix('press', ClientPrefs.data.flashing ? "ENTER PRESSED" : "ENTER FREEZE", 24);
		}
		else {
			newTitle = false;

			titleText.animation.addByPrefix('idle', "Press Enter to Begin", 24);
			titleText.animation.addByPrefix('press', "ENTER PRESSED", 24);
		}

		titleText.antialiasing = ClientPrefs.data.globalAntialiasing;
		titleText.animation.play('idle');
		titleText.updateHitbox();
		add(titleText);

		var logo:FlxSprite = new FlxSprite().loadGraphic(Paths.image('logo'));
		logo.screenCenter();
		logo.antialiasing = ClientPrefs.data.globalAntialiasing;

		credGroup = new FlxGroup();
		add(credGroup);
		textGroup = new FlxGroup();

		blackScreen = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		credGroup.add(blackScreen);

		credTextShit = new Alphabet(0, 0, "", true);
		credTextShit.screenCenter();

		credTextShit.visible = false;

		ngSpr = new FlxSprite(0, FlxG.height * 0.52).loadGraphic(Paths.image('newgrounds_logo'));
		add(ngSpr);
		ngSpr.visible = false;
		ngSpr.setGraphicSize(Std.int(ngSpr.width * 0.8));
		ngSpr.updateHitbox();
		ngSpr.screenCenter(X);
		ngSpr.antialiasing = ClientPrefs.data.globalAntialiasing;

		FlxTween.tween(credTextShit, {y: credTextShit.y + 20}, 2.9, {ease: FlxEase.quadInOut, type: PINGPONG});
		
		if (initialized)
			skipIntro();
		else
			initialized = true;
	}
	function getIntroTextShit():Array<Array<String>>
	{
		var fullText:String = Assets.getText(Paths.txt('introText'));

		var firstArray:Array<String> = fullText.split('\n');
		var swagGoodArray:Array<Array<String>> = [];

		for (i in firstArray)
		{
			swagGoodArray.push(i.split('--'));
		}

		return swagGoodArray;
	}

	var transitioning:Bool = false;
	private static var playJingle:Bool = false;

	var newTitle:Bool = false;
	var titleTimer:Float = 0;

	override function update(elapsed:Float)
	{
		#if MODS_ALLOWED
		// On the first update frame, check if TitleState should be replaced
		// by the active mod's stateRedirects.
		if (!_redirectChecked) {
			_redirectChecked = true;
			if (ModState.stateReplacements.exists("TitleState")) {
				MusicBeatState.switchState(new ModState(ModState.stateReplacements["TitleState"]));
				return;
			}
		}
		#end

		#if LUA_ALLOWED
		callOnLuas('onUpdate', [elapsed]);
		#end
		#if HSCRIPT_ALLOWED
		callOnHscript('onUpdate', [elapsed]);
		#end

		#if mobile
		if (isCopying)
		{
			#if android
			if (extractionDone && copyCanUpdate)
			{
				handleNativeExtractionFinished();
				return;
			}
			#else
			if (copyLoop != null)
			{
				if (copyLoop.finished && copyCanUpdate)
				{
					if (copyFailedFiles.length > 0)
					{
						SUtil.showPopUp(copyFailedFiles.join('\n'), 'Failed To Copy ${copyFailedFiles.length} File.');
						if (!FileSystem.exists('logs'))
							FileSystem.createDirectory('logs');
						File.saveContent('logs/' + Date.now().toString().replace(' ', '-').replace(':', "'") + '-CopyState' + '.txt', copyFailedFilesStack.join('\n'));
					}
					copyCanUpdate = false;
					copyCompleted = true;
					FlxG.sound.play(Paths.sound('confirmMenu'));

					// Copy completed, proceed with normal flow
					isCopying = false;
					continueNormalFlow();
					return;
				}

				if (maxLoopTimes == 0)
					copyLoadedText.text = "Completed!";
				else
					copyLoadedText.text = '$copyLoopTimes/$maxLoopTimes';
			}
			#end
			#if LUA_ALLOWED
			callOnLuas('onUpdatePost', [elapsed]);
			#end
			#if HSCRIPT_ALLOWED
			callOnHscript('onUpdatePost', [elapsed]);
			#end
			super.update(elapsed);
			return;
		}
		#end

		if (FlxG.sound.music != null)
			Conductor.songPosition = FlxG.sound.music.time;

		var pressedEnter:Bool = FlxG.keys.justPressed.ENTER || controls.ACCEPT || FlxG.mouse.justPressed;

		#if mobile
		for (touch in FlxG.touches.list)
		{
			if (touch.justPressed)
			{
				pressedEnter = true;
			}
		}
		#end

		var gamepad:FlxGamepad = FlxG.gamepads.lastActive;

		if (gamepad != null)
		{
			if (gamepad.justPressed.START)
				pressedEnter = true;

			#if switch
			if (gamepad.justPressed.B)
				pressedEnter = true;
			#end
		}

		if (newTitle) {
			titleTimer += CoolUtil.boundTo(elapsed, 0, 1);
			if (titleTimer > 2) titleTimer -= 2;
		}

		if (initialized && !transitioning && skippedIntro)
		{
			if (newTitle && !pressedEnter)
			{
				var timer:Float = titleTimer;
				if (timer >= 1)
					timer = (-timer) + 2;

				timer = FlxEase.quadInOut(timer);

				titleText.color = FlxColor.interpolate(titleTextColors[0], titleTextColors[1], timer);
				titleText.alpha = FlxMath.lerp(titleTextAlphas[0], titleTextAlphas[1], timer);
			}

			if(pressedEnter)
			{
				titleText.color = FlxColor.WHITE;
				titleText.alpha = 1;

				if(titleText != null) titleText.animation.play('press');

				FlxG.camera.flash(ClientPrefs.data.flashing ? FlxColor.WHITE : 0x4CFFFFFF, 1);
				FlxG.sound.play(Paths.sound('confirmMenu'), 0.7);

				transitioning = true;

				new FlxTimer().start(1, function(tmr:FlxTimer)
				{
					if (mustUpdate) {
						MusicBeatState.switchState(new OutdatedState());
					} else {
						MusicBeatState.switchState(new MainMenuState());
					}
					closedState = true;
				});
			}
			#if TITLE_SCREEN_EASTER_EGG
			else if (FlxG.keys.firstJustPressed() != FlxKey.NONE)
			{
				var keyPressed:FlxKey = FlxG.keys.firstJustPressed();
				var keyName:String = Std.string(keyPressed);
				if(allowedKeys.contains(keyName)) {
					easterEggKeysBuffer += keyName;
					if(easterEggKeysBuffer.length >= 32) easterEggKeysBuffer = easterEggKeysBuffer.substring(1);

					for (wordRaw in easterEggKeys)
					{
						var word:String = wordRaw.toUpperCase();
						if (easterEggKeysBuffer.contains(word))
						{
							if (FlxG.save.data.psychDevsEasterEgg == word)
								FlxG.save.data.psychDevsEasterEgg = '';
							else
								FlxG.save.data.psychDevsEasterEgg = word;
							FlxG.save.flush();

							FlxG.sound.play(Paths.sound('ToggleJingle'));

							var black:FlxSprite = new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
							black.alpha = 0;
							add(black);

							FlxTween.tween(black, {alpha: 1}, 1, {onComplete:
								function(twn:FlxTween) {
									FlxTransitionableState.skipNextTransIn = true;
									FlxTransitionableState.skipNextTransOut = true;
									MusicBeatState.switchState(new TitleState());
								}
							});
							FlxG.sound.music.fadeOut();
							if(FreeplayState.vocals != null)
							{
								FreeplayState.vocals.fadeOut();
							}
							closedState = true;
							transitioning = true;
							playJingle = true;
							easterEggKeysBuffer = '';
							break;
						}
					}
				}
			}
			#end
		}

		if (initialized && pressedEnter && !skippedIntro)
		{
			skipIntro();
		}

		if(swagShader != null)
		{
			if(controls.UI_LEFT) swagShader.hue -= elapsed * 0.1;
			if(controls.UI_RIGHT) swagShader.hue += elapsed * 0.1;
		}

		#if LUA_ALLOWED
		callOnLuas('onUpdatePost', [elapsed]);
		#end
		#if HSCRIPT_ALLOWED
		callOnHscript('onUpdatePost', [elapsed]);
		#end
		super.update(elapsed);
	}

	function createCoolText(textArray:Array<String>, ?offset:Float = 0)
	{
		for (i in 0...textArray.length)
		{
			var money:Alphabet = new Alphabet(0, 0, textArray[i], true);
			money.screenCenter(X);
			money.y += (i * 60) + 200 + offset;
			if(credGroup != null && textGroup != null) {
				credGroup.add(money);
				textGroup.add(money);
			}
		}
	}

	function addMoreText(text:String, ?offset:Float = 0)
	{
		if(textGroup != null && credGroup != null) {
			var coolText:Alphabet = new Alphabet(0, 0, text, true);
			coolText.screenCenter(X);
			coolText.y += (textGroup.length * 60) + 200 + offset;
			credGroup.add(coolText);
			textGroup.add(coolText);
		}
	}

	function deleteCoolText()
	{
		while (textGroup.members.length > 0)
		{
			credGroup.remove(textGroup.members[0], true);
			textGroup.remove(textGroup.members[0], true);
		}
	}

	private var sickBeats:Int = 0;
	public static var closedState:Bool = false;
	override function beatHit()
	{
		super.beatHit();
		#if HSCRIPT_ALLOWED
		callOnHscript('onBeatHit', []);
		#end

		if(logoBl != null)
			logoBl.animation.play('bump', true);

		if(gfDance != null) {
			danceLeft = !danceLeft;
			if (danceLeft)
				gfDance.animation.play('danceRight');
			else
				gfDance.animation.play('danceLeft');
		}

		if(!closedState) {
			sickBeats++;
			switch (sickBeats)
			{
				case 1:
					FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
					FlxG.sound.music.fadeIn(4, 0, 0.7);
				case 2:
					#if PSYCH_WATERMARKS
					createCoolText(['Seiun Engine by'], 15);
					#else
					createCoolText(['ninjamuffin99', 'phantomArcade', 'kawaisprite', 'evilsk8er']);
					#end
				case 4:
					#if PSYCH_WATERMARKS
					addMoreText('Mo_hong', 15);
					addMoreText('Psych Engine by ', 15);
					addMoreText('Shadow Mario', 15);
					addMoreText('RiverOaken', 15);
					addMoreText('shubs', 15);
					#else
					addMoreText('present');
					#end
				case 5:
					deleteCoolText();
				case 6:
					#if PSYCH_WATERMARKS
					createCoolText(['Not associated', 'with'], -40);
					#else
					createCoolText(['In association', 'with'], -40);
					#end
				case 8:
					addMoreText('newgrounds', -40);
					ngSpr.visible = true;
				case 9:
					deleteCoolText();
					ngSpr.visible = false;
				case 10:
					createCoolText([curWacky[0]]);
				case 12:
					addMoreText(curWacky[1]);
				case 13:
					deleteCoolText();
				case 14:
					addMoreText('Friday');
				case 15:
					addMoreText('Night');
				case 16:
					addMoreText('Funkin');
				case 17:
					skipIntro();
			}
		}
	}

	var skippedIntro:Bool = false;
	var increaseVolume:Bool = false;
	function skipIntro():Void
	{
		#if HSCRIPT_ALLOWED
		callOnHscript('onSkipIntro', []);
		#end
		if (!skippedIntro)
		{
			if (playJingle)
			{
				var easteregg:String = FlxG.save.data.psychDevsEasterEgg;
				if (easteregg == null) easteregg = '';
				easteregg = easteregg.toUpperCase();

				var sound:FlxSound = null;
				switch(easteregg)
				{
					case 'RIVER':
						sound = FlxG.sound.play(Paths.sound('JingleRiver'));
					case 'SHUBS':
						sound = FlxG.sound.play(Paths.sound('JingleShubs'));
					case 'SHADOW':
						FlxG.sound.play(Paths.sound('JingleShadow'));
					case 'BBPANZU':
						sound = FlxG.sound.play(Paths.sound('JingleBB'));

					default:
						remove(ngSpr);
						remove(credGroup);
						FlxG.camera.flash(FlxColor.WHITE, 2);
						skippedIntro = true;
						playJingle = false;

						FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
						FlxG.sound.music.fadeIn(4, 0, 0.7);
						return;
				}

				transitioning = true;
				if(easteregg == 'SHADOW')
				{
					new FlxTimer().start(3.2, function(tmr:FlxTimer)
					{
						remove(ngSpr);
						remove(credGroup);
						FlxG.camera.flash(FlxColor.WHITE, 0.6);
						transitioning = false;
					});
				}
				else
				{
					remove(ngSpr);
					remove(credGroup);
					FlxG.camera.flash(FlxColor.WHITE, 3);
					sound.onComplete = function() {
						FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
						FlxG.sound.music.fadeIn(4, 0, 0.7);
						transitioning = false;
					};
				}
				playJingle = false;
			}
			else
			{
				remove(ngSpr);
				remove(credGroup);
				FlxG.camera.flash(FlxColor.WHITE, 4);

				var easteregg:String = FlxG.save.data.psychDevsEasterEgg;
				if (easteregg == null) easteregg = '';
				easteregg = easteregg.toUpperCase();
				#if TITLE_SCREEN_EASTER_EGG
				if(easteregg == 'SHADOW')
				{
					FlxG.sound.music.fadeOut();
					if(FreeplayState.vocals != null)
					{
						FreeplayState.vocals.fadeOut();
					}
				}
				#end
			}
			skippedIntro = true;
		}
	}
	override function destroy()
	{
		instance = null;
		super.destroy();
	}
}
