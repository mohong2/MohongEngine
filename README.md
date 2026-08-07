<!--
  FNF SeiunEngine (Seiun Engine) — Full README
  English
-->

# 🎵 Friday Night Funkin' — Seiun Engine (SeiunEngine)

> **This is a fork!!** (Based on **Psych Engine 0.6.3**)
> This engine will stop receiving updates after the official release of the **Mandela Funkin Night** mod.

| Section | Link |
|---|---|
| Features | [§1](#1-features) |
| Installation | [§2](#2-installation) |
| Building | [§3](#3-building) |
| Modding | [§4](#4-modding) |
| Script API | [§5](#5-script-api) |
| Credits | [§6](#6-credits) |
| License | [§7](#7-license) |

---

## 0. Version Status

| Item | Value |
|---|---|
| Project | `SeiunEngine` |
| Executable | `SeiunEngine.exe` |
| **Engine version** | **`0.2.1`** (controlled by the `<app version>` field in `Project.xml`) |
| Psych base | `0.6.4` (hardcoded in source) |
| FNF game version | `0.2.7.1` (hardcoded in source) |
| Main class | `Main` |
| Package | `com.mohong.Seiunengine` |
| Tech stack | Haxe 4.2.5 / OpenFL / Lime / HaxeFlixel |
| Platforms | **Windows**, **Android**, **Web (HTML5)**, macOS/Linux, plus Switch support code |
| Default window | 1280 × 720, resizable, non-fullscreen, high-DPI aware |

> ⚠️ You **MUST** use [Haxe 4.2.5](https://haxe.org/download/). Don't use 4.1.5 — it lacks features needed here. (See `USE HAXE 4.2.5.txt`.)

---

## 1. Features

This engine is built on **Psych Engine 0.6.3**, with many enhancements/rewrites for modding and gameplay, plus partial **Psych 0.7.x / 1.0.x** interface compatibility. Highlights:

### 🎮 Gameplay
- **Replay fully rewritten** — new replay-recording system; fixes phone virtual-key replay data loss; paired with a replay-history UI (`ScoreHistorySubstate`)
- **Two pause screens** — a brand-new pause screen (3D / acrylic glass card, soft-coded transparency); the old one remains as `OldPauseSubState`
- **Modernized Results & replay-history UI** — elastic (bouncy) entrance animations, hover feedback, layout that sizes by rendered text width (long localized strings no longer overlap/collide)
- **Health bar** — built directly from the 073 `Bar.hx` class instead of mapping tricks

### 🛠️ Editors & Charts
- **Chart editors fully fixed** (new & old `ChartingState`): unified unsaved-changes warnings, no more silent auto-saving; new "Chart Autosave" setting (off by default)
- **CNE (Codename Engine) chart import** — one-click CNE chart import; saving merged into a single Prompt
- Fixed 0.6.3 chart conversion and note-position issues

### 📦 Mod System (fully rewritten)
- **FreePlay: press TAB to switch mods** — no longer dumps every mod's songs at once
- **Legacy mod-loading state retired** — mod switching now happens via a main-menu **mod SDK substate** (TAB), independent from FreePlay
- **Global mod list option**; per-mod **API version** `apiVersion` (`ENGINE_API_VERSION = 1`)
- Multi-resolution mod icons, `stateReplacements` / `substateReplacements`, custom window title & icon, Discord RPC

### 💻 Debug & Tools
- **Trace console** — captures all `trace()` output to a live console (localized static API: `info/warn/error/debug`)
- **Backup & restore** — encrypted `.SEB` files (XOR + SEB1 magic) for high-scores/all-scores/settings/week progress
- **Script error-loop guard** — "Ignore error-loop scripts" (default on) + "Script error limit" (default 50) stops spamming scripts

### 🎹 KeyboardDisplay
- Fully soft-coded (key size, spacing, font size, alpha, etc.; call `rebuild()` to apply)
- `fullyCustom` switch to fully replace the default keyboard, plus `onKeyboardPress/Release/Update` hooks and `getTotal()/incrementTotal()`

### 🎨 Graphics & Compatibility
- Ported **PsychCamera** and other 073/104 classes
- **Sparrow XML `rotated="true"`** frame-rotation fix
- Fixed timeBar `cameras == null` crash when compatibility mode is off; fake virtual keys added on desktop for phone-ported mods; Android file-location override

### 🚀 Performance
- Large-note (tens~hundreds of thousands) **atlas-frame caching** & much faster song-load
- combospr image optimization, render-pipeline tweaks, object pool, GPU texture management

### 🌐 Languages
- Simplified/Traditional Chinese + English (`assets/lang`, managed by `Language.hx`)
- New Lua global `luattf` (native Chinese font, bilingual display)

### 🧩 Script System Enhancements
- **HScript can now write full mods** (icons too); **Lua/HScript can modify (sub)states**
- Cross-language calls: `setOnScripts/setOnHScript/setOnLuas/callOnScripts/callOnLuas/callOnHScript`
- **HScript ↔ Lua bridge**: `LuaApi` (HScript can add/override/restore Lua globals)

> Detailed per-version changelog: `export/release/windows/bin/更新.txt`.

---

## 2. Installation

### Requirements
You **must** install [Haxe 4.2.5](https://haxe.org/download/). Don't use 4.1.5.

### Haxelib dependencies

| Library | Purpose | Version |
|---|---|---|
| **flixel** | HaxeFlixel core | **4.11.0** |
| **flixel-addons** | UI/transition addons | **2.11.0** |
| **flixel-ui** | Settings UI | **2.4.0** |
| **hscript-iris** | HScript scripting | **1.1.3** |
| **lime** | Low-level platform/render | **8.0.1** |
| **openfl** | Render framework | **9.2.1** |
| **tjson** | JSON parsing (build/data) | **1.4.0** |

### Optional libraries

| Library | When | Purpose |
|---|---|---|
| **linc_luajit** | Lua scripts (desktop/android) | LuaJIT (**Git** version: https://github.com/nebulazorua/linc_luajit) |
| **hxCodec** | desktop/android | MP4/video playback (Android **2.5.1**) |
| **faxe** | Switch | Switch audio |
| **extension-androidtools** | android | Android native tools/perms |
| **discord_rpc** | desktop | Discord Rich Presence |

### One-click install
`install.bat` in the repo root installs the base libs into the local `.haxelib`, Git-installs `hscript-improved` (Erizur), `linc_luajit` and `discord_rpc`, then `haxelib dev` into the local libs.

---

## 3. Building

Built with **Lime/OpenFL**. Build scripts live in `art\`.

### Windows (64/32-bit)
```bat
art\build_x64.bat                 :: 64-bit Release → export/release/windows/bin
art\build_x64-debug.bat           :: 64-bit Debug   → export/debug/windows/bin
art\build_x32.bat                 :: 32-bit Release → export/32bit/windows/bin
```

### HTML5
```bat
art\build_html.bat                :: Release → export/release/html5
art\build_html-debug.bat          :: Debug   → export/debug/html5
```

### Raw commands
```bat
lime build windows -release
lime build windows -debug
lime test html5 -release
lime build windows -32 -D 32bits
```

> Output directories are controlled by `BUILD_DIR` in `Project.xml`; Android builds are signed with the in-repo `key.keystore`.

---

## 4. Modding

This engine uses **POLYMOD** (Lars Doucet) as its mod backend.

### Folder structure
Drop a mod folder into `mods/` (see `example_mods/`):

```
MyMod/
├── pack.json              # mod metadata (required)
├── pack.png               # icon
├── characters/            # character JSON/images
├── custom_events/         # custom events
├── custom_notetypes/      # custom note types
├── hscripts/              # HScript (root = all states, subdirs = per-state)
│   ├── PlayState/  MainMenuState/  FreeplayState/  ...
├── scripts/               # Lua scripts (.lua all states, .hx PlayState only)
├── stages/                # stage scripts (.lua/.hx)
├── images/  music/  songs/  videos/  sounds/
├── weeks/                 # weeks
├── options/               # custom option JSON
└── shaders/               # shaders
```

### `pack.json` (key fields)
```jsonc
{
	"name": "Name", "author": "", "version": "1.0.0",
	"description": "Description",
	"zhdescription": "中文描述", "zhtdescription": "繁體中文描述",
	"apiVersion": 1,          // engine API version (current = 1; 0 = legacy/auto-compatible)
	"restart": false,         // requires a restart to load
	"runsGlobally": false,    // run as a global mod
	"dependencies": [],
	"color": [170, 0, 255],   // mod accent color [r,g,b]
	"useOldFPS": false,
	"iconPath": "pack.png", "iconPath64": "icon64", "iconPath32": "icon32", "iconPath24": "icon24", "iconPath16": "icon16",
	"windowTitle": "",
	"stateReplacements": {}, "substateReplacements": {},
	"discordRPC": "...", "discordLogoKey": "icon", "discordLogoText": "",
	"downloadLink": ""
}
```

### Mod options
Options live in `mods/<mod>/options/<CategoryID>.json` (or `.patch.json`, or a `<CategoryID>/` folder). Values go into `ClientPrefs.data.modSettings[<mod>][<var>]`; global `mods/options/` map to `modSettings['__GLOBAL__']`. Built-in categories: `graphics` / `visuals` / `gameplay` / `extra_settings` / `android_settings`.

---

## 5. Script API

This engine ships a full **Lua** and **HScript** scripting system. The complete reference is split into modules under [`docs/script-api/`](docs/script-api/). **Every Lua function is version-tagged** to show which Psych version it comes from (0.6.3 / 0.7.x / 1.0.x / engine-specific).

> All docs are self-contained bilingual **HTML** pages (EN + 中文), open them in any browser.

| Module | Description |
|---|---|
| [Script API Home](docs/script-api/index.html) | Version legend, module index, cross-version diff |
| [Lua · Quickstart](docs/script-api/lua-quickstart.html) | First script, file layout, lifecycle |
| [Lua · Hooks](docs/script-api/lua-hooks.html) | All event callbacks |
| [Lua · Functions I](docs/script-api/lua-functions-1.html) | Property / Tween / Sprite / Text / Script mgmt |
| [Lua · Functions II](docs/script-api/lua-functions-2.html) | Judgment / Input / Shader / Audio / Save / engine-new |
| [Lua · Globals](docs/script-api/lua-globals.html) | Directly usable variables |
| [HScript · Quickstart](docs/script-api/hscript-quickstart.html) | First HScript, environment, hooks |
| [HScript · Environment & API](docs/script-api/hscript-environment.html) | Global classes / shorthand / input |
| [HScript ↔ Lua Interop](docs/script-api/hscript-interop.html) | LuaApi bridge |
| [Modding Advanced](docs/script-api/modding-advanced.html) | Folders / pack.json / options |

> Built-in template scripts: `docs/TemplateScript.lua` (EN) and `docs/zh_TemplateScript.lua` (CN); full mod template: `docs/modTemplate.zip`.

---

## 6. Credits

### Seiun Engine
- **mo_hong** — modifications and Chinese translation
- **Li.tmc** — engine icon

### Psych Engine
- **Shadow Mario** — programmer
- **RiverOaken** — artist
- **Yoshubs** — assistant programmer

### Codename Engine
- **Codename Engine team** ([CodenameCrew](https://github.com/CodenameCrew)) — mod-state scripting & `pack.json` mod-API design that this engine's modding system is modeled after (CNE chart import/export and `stateReplacements`/`substateReplacements` compatibility). Seiun Engine is **not** a fork of Codename Engine; it is a Psych Engine fork implementing a CNE-compatible mod format. No Codename Engine source code is included in this repository.

### Special Thanks
- **bbpanzu** — former programmer
- **shubs** — new input system
- **SqirraRNG** — crash handler & chart editor waveform base
- **KadeDev** — chart editor fixes & PRs
- **iFlicky** — composer (Psync / Tea Time) & dialogue SFX
- **PolybiusProxy** — .MP4 video loading (hxCodec)
- **Keoiki** — note splash animations
- **Smokey** — sprite atlas support
- **Nebula the Zorua** — LUA JIT fork & partial Lua rewrites

---

## 7. License

This engine is based on **Psych Engine** and follows its open-source license (see `LICENSE`). Please comply with the license and attribution requirements when creating/distributing mods.

The modding-API design is inspired by **Codename Engine**; see the [Codename Engine repository](https://github.com/CodenameCrew/CodenameEngine) for its own terms ("What you can do or not do"). Codename Engine's source code is **not** distributed with this project.

---

*FNF SeiunEngine · Mohong Engine — a Chinese-first FNF engine fork.*
