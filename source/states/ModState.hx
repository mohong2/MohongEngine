package states;

import backend.MusicBeatState;
import backend.ModConfig;
import flixel.FlxG;
import flixel.FlxState;
import haxe.Json;
import lime.app.Application;
import mohong.TraceManager;

#if MODS_ALLOWED
import sys.FileSystem;
import sys.io.File;
#end

#if HSCRIPT_ALLOWED
import script.hscript.HScript;
#end

/**
 * Scriptable state — loads an HScript/Lua file from `data/states/<name>`.
 *
 * Also hosts the static state‑replacement system that lets mods redirect
 * built‑in states (e.g. `TitleState`) to a ModState backed by a script.
 *
 * Modeled after Codename Engine's ModState.
 */
class ModState extends MusicBeatState
{
	// ── Script info ──
	public static var lastName:String = null;
	public static var lastData:Dynamic = null;
	public var data:Dynamic = null;

	// ── State-replacement system ──
	/** Simple name of the original state this instance replaces (e.g. "TitleState"). */
	public static var replacingStateName:String = null;

	#if MODS_ALLOWED
	/** Maps original state name → script path (e.g. "TitleState" → "data/states/MyTitle"). */
	public static var stateReplacements:Map<String, String> = new Map<String, String>();
	public static var substateReplacements:Map<String, String> = new Map<String, String>();
	public static var modWindowTitle:String = null;

	/** Whether TitleState-level init has already run. */
	public static var titleStateInitDone:Bool = false;

	static var _originalTitle:String = null;

	/** Read mod config & populate replacements + window title + icon. */
	public static function applyModPackConfig(modFolder:String):Void {
		stateReplacements.clear();
		substateReplacements.clear();
		modWindowTitle = null;
		titleStateInitDone = false;
		replacingStateName = null;

		if (modFolder == null || modFolder.length == 0) {
			restoreWindowTitle();
			// NOTE: globalMods are intentionally NOT cleared here.
			// They are populated by Paths.pushGlobalMods() (called from TitleState /
			// MainMenuState) from modsList.txt and should persist so that global
			// mods (runsGlobally) remain active even when the user switches to
			// vanilla or a different mod.
			Paths.currentModDirectory = '';
			return;
		}

		var cfg:ModConfig = ModConfig.load(modFolder);
		if (cfg == null || (cfg.name.length == 0 && cfg.windowTitle.length == 0 && cfg.iconPath.length == 0
			&& !cfg.stateReplacements.keys().hasNext() && !cfg.substateReplacements.keys().hasNext())) {
			restoreWindowTitle(); return;
		}

		// ── Load dependencies first ──
		// If the mod lists other mods as dependencies, push them as global mods
		// so their scripts and assets are available before the main mod.
		if (cfg.dependencies != null && cfg.dependencies.length > 0) {
			for (dep in cfg.dependencies) {
				if (dep.length > 0 && dep != modFolder) {
					Paths.addGlobalMod(dep);
				}
			}
		}

		if (cfg.windowTitle.length > 0) { modWindowTitle = cfg.windowTitle; setWindowTitle(cfg.windowTitle); }
		else restoreWindowTitle();

		// ── Update the OS window icon in real time ──
		// Uses ModConfig.setWindowIcon() which picks the best‑fitting
		// resolution (64×64 → 32×32 → 24×24 → 16×16 → iconPath) and
		// scales down if needed.
		#if (desktop && MODS_ALLOWED)
		ModConfig.setWindowIcon(modFolder);
		#end

		// Store just the custom state name (no prefix).
		// initHScripts() in MusicBeatState will prepend "data/states/" automatically.
		for (orig => cust in cfg.stateReplacements)
			if (cust.length > 0) stateReplacements[orig] = cust;

		for (orig => cust in cfg.substateReplacements)
			if (cust.length > 0) substateReplacements[orig] = cust;

		// Reload global HScripts AFTER the new mod's config is applied,
		// so scripts can safely access the updated stateReplacements etc.
		#if HSCRIPT_ALLOWED
		HScript.reloadGlobalScripts();
		#end
	}

	/** Run TitleState-level init if TitleState is replaced. */
	public static function runTitleStateInit():Void {
		if (titleStateInitDone) return;
		titleStateInitDone = true;

		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();
		#if LUA_ALLOWED Paths.pushGlobalMods(); #end
		Paths.currentModDirectory = MainMenuState.selectedModFolder;

		PlayerSettings.init();
		FlxG.save.bind('funkin', 'ninjamuffin99');
		ClientPrefs.loadPrefs();
		Highscore.load();
	}

	/** Check whether current mod wants to replace an already-instantiated state. */
	public static function resolveState(original:FlxState):FlxState {
		if (stateReplacements == null || !stateReplacements.keys().hasNext()) return original;

		var cls = Type.getClassName(Type.getClass(original));
		var simple = cls.substr(cls.lastIndexOf('.') + 1);

		if (stateReplacements.exists(simple)) {
			if (simple == "TitleState") runTitleStateInit();

			replacingStateName = simple;
			TraceManager.info('trace.modState.replace', 'Replacing {} with ModState({})', [simple, stateReplacements[simple]]);
			return new ModState(stateReplacements[simple]);
		}
		replacingStateName = null;
		return original;
	}

	static function getDefaultTitle():String {
		var t = Application.current.meta.get('title');
		if (t != null && t.length > 0) return t;
		t = Application.current.meta.get('name');
		if (t != null && t.length > 0) return t;
		t = Application.current.meta.get('file');
		if (t != null && t.length > 0) return t;
		return "SeiunEngine";
	}

	public static function setWindowTitle(title:String):Void {
		if (_originalTitle == null) {
			_originalTitle = Application.current.window.title;
			if (_originalTitle == null || _originalTitle.length == 0) _originalTitle = getDefaultTitle();
		}
		Application.current.window.title = title;
	}

	public static function restoreWindowTitle():Void {
		if (_originalTitle == null) _originalTitle = getDefaultTitle();
		Application.current.window.title = _originalTitle;
	}

	// ── Window icon ──

	/**
	 * Load an icon from the mod's image assets (via Paths.image) and attempt
	 * to set it as the window icon.  The icon is scaled down to a reasonable
	 * size (max 64×64) if the source image is larger.
	 */
	public static function setWindowIcon(iconRelPath:String, modFolder:String):Void {
		// The icon path from pack.json is treated like a Psych Engine image key:
		// it's resolved relative to the mod's images/ folder (with .png appended).
		// E.g., "iconPath": "myModIcon" → mods/<mod>/images/myModIcon.png
		var fullPath:String = Paths.mods(modFolder + '/images/' + iconRelPath + '.png');
		var bmp:openfl.display.BitmapData = null;
		try {
			if (sys.FileSystem.exists(fullPath))
				bmp = openfl.display.BitmapData.fromFile(fullPath);
		} catch (e:Dynamic) {
			TraceManager.error('trace.modState.iconError', 'Failed to load icon: {}', [e]);
			return;
		}
		if (bmp == null) return;

		// Scale down if larger than 64×64 (window icon size limit)
		var maxSize:Int = 64;
		if (bmp.width > maxSize || bmp.height > maxSize) {
			var scale:Float = Math.min(maxSize / bmp.width, maxSize / bmp.height);
			var w:Int = Math.floor(bmp.width * scale);
			var h:Int = Math.floor(bmp.height * scale);
			var scaled:openfl.display.BitmapData = bmp.clone();
			// Simple resize via matrix
			var matrix:openfl.geom.Matrix = new openfl.geom.Matrix();
			matrix.scale(scale, scale);
			var resized:openfl.display.BitmapData = new openfl.display.BitmapData(w, h, true, 0);
			resized.draw(bmp, matrix, null, null, null, true);
			bmp = resized;
		}

		try {
			// Attempt to set icon via the OpenFL/Lime window API
			var win:Dynamic = Application.current.window;
			if (Reflect.hasField(win, "setIcon")) {
				win.setIcon(bmp);
			} else if (Reflect.hasField(win, "icon")) {
				Reflect.setProperty(win, "icon", bmp);
			}
		} catch (e:Dynamic) {
			TraceManager.error('trace.modState.iconSetError', 'Failed to set window icon: {}', [e]);
		}
	}

	/** Try to restore the original window icon (no‑op on most platforms). */
	public static function restoreWindowIcon():Void {
		// The original icon is embedded in the .exe at compile time and
		// cannot be retrieved at runtime.  On platforms where setIcon is
		// supported a null/empty call might reset it, but typically this
		// is a no‑op.
		try {
			var win:Dynamic = Application.current.window;
			if (Reflect.hasField(win, "setIcon")) {
				win.setIcon(null);
			}
		} catch (e:Dynamic) {}
	}
	#end

	// ── Constructor ──
	public function new(_stateName:String, ?_data:Dynamic) {
		if (_stateName != null && _stateName != lastName) {
			lastName = _stateName;
			lastData = null;
		}
		if (_data != null) lastData = _data;
		this.data = lastData;
		super(lastName);
	}

	// ── Lifecycle ──
	override function create() {
		// If replacingStateName wasn't set by resolveState() (e.g. this ModState
		// was created directly from a script like mTitleState.hx), auto-detect
		// it by looking up lastName in the stateReplacements values.
		if (replacingStateName == null && lastName != null) {
			for (orig => cust in stateReplacements) {
				if (cust == lastName) {
					replacingStateName = orig;
					break;
				}
			}
		}
		super.create();
		#if LUA_ALLOWED
		initLuaScripts();
		setOnLuas('data', this.data);
		setOnLuas('controls', controls);
		setOnLuas('state', this);
		callOnLuas('onCreatePost', []);
		#end
		#if HSCRIPT_ALLOWED
		setOnHscript('data', this.data);
		#end
	}

	override function update(elapsed:Float) {
		callOnLuas('onUpdate', [elapsed]);
		callOnHscript('onUpdate', [elapsed]);

		#if MODS_ALLOWED
		if (FlxG.keys.justPressed.TAB && replacingStateName == "MainMenuState") { openModSelect(); return; }
		if (controls.BACK && replacingStateName == "MainMenuState") {
			MusicBeatState.switchState(new TitleState()); return;
		}
		#end

		super.update(elapsed);
		callOnLuas('onUpdatePost', [elapsed]);
		callOnHscript('onUpdatePost', [elapsed]);
	}

	#if MODS_ALLOWED
	function openModSelect():Void {
		var modFolders:Array<String> = [''];
		var listPath = 'modsList.txt';
		if (FileSystem.exists(listPath))
			for (line in CoolUtil.coolTextFile(listPath)) {
				var p = line.split('|');
				if (p.length >= 1 && p[0].length > 0 && !Paths.ignoreModFolders.contains(p[0].toLowerCase()) && !modFolders.contains(p[0]))
					modFolders.push(p[0]);
			}
		for (f in Paths.getModDirectories())
			if (!Paths.ignoreModFolders.contains(f) && !modFolders.contains(f)) modFolders.push(f);
		modFolders.sort((a, b) -> a < b ? -1 : a > b ? 1 : 0);
		if (modFolders.indexOf('') < 0) modFolders.insert(0, '');

		var idx = 0;
		for (i in 0...modFolders.length) if (modFolders[i] == MainMenuState.selectedModFolder) { idx = i; break; }

		openSubState(new substates.ModSelectSubstate(modFolders, idx,
			function(n) { MainMenuState.applyModSelectionExternal(n, modFolders); },
			function() {}));
	}
	#end

	override function stepHit() { super.stepHit(); callOnLuas('onStepHit', [curStep]); }
	override function beatHit() { super.beatHit(); callOnLuas('onBeatHit', [curBeat]); }
	override function sectionHit() { super.sectionHit(); callOnLuas('onSectionHit', [curSection]); }
}