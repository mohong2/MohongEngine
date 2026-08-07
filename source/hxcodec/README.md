# hxCodec Compatibility Layer (backed by hxvlc)

These files replace **hxCodec** with **hxvlc** while keeping the old hxCodec
API surface, so engine code and mods written for hxCodec keep working without
changes.

Reference: https://github.com/Psych-Plus-Team/FNF-PlusEngine/tree/main/source/objects/hxcodec

## Why

* hxCodec 2.5.1 ships a 2021-era libVLC that cannot load on modern Android
  (API 30+ `extractNativeLibs` / 16KB page alignment / missing ABIs), which is
  why raising `targetSdk`/`compileSdk` crashed the game.
* hxCodec 2.6+/3.x broke the API and its Android builds are broken.
* hxvlc ships fresh, 16KB-aligned libVLC binaries for all major Android ABIs and
  is actively maintained. Pinned version: **2.2.5** (see `hmm.json`).

## Class map

| Old hxCodec API | Compat class (this folder) | Backing library |
|---|---|---|
| `vlc.MP4Handler` (2.5.x) | `vlc/MP4Handler.hx` | hxvlc |
| `vlc.MP4Sprite` (2.5.x) | `vlc/MP4Sprite.hx` | hxvlc |
| `hxcodec.VideoHandler` (2.6.x) | `hxcodec/VideoHandler.hx` | hxvlc |
| `hxcodec.VideoSprite` (2.6.x) | `hxcodec/VideoSprite.hx` | hxvlc |
| `hxcodec.flixel.FlxVideo` (3.x) | `hxcodec/flixel/FlxVideo.hx` | hxvlc |
| `hxcodec.flixel.FlxVideoSprite` (3.x) | `hxcodec/flixel/FlxVideoSprite.hx` | hxvlc |

The files live at the exact package paths (`source/vlc`, `source/hxcodec`) so
Haxe resolves them exactly like the original hxCodec library did - no extra
classpath or defines are needed.

Engine entry points wired to these classes:

* `backend.VideoSpriteManager` -> `vlc.MP4Sprite`
* `states.PlayState.startVideo` -> `vlc.MP4Handler`
* `script.hscript.HScript` -> registers all six classes for mods

## hxvlc fork & installation

hxvlc **2.2.5** is installed from a local git fork at `hxvlc-local/`
(see `hxvlc-local/README-FORK.md` for the exact patches). It keeps the pinned
toolchain untouched: **Haxe 4.2.5 + hxcpp 4.2.1** (hxcpp 4.3.x is NOT required
and must stay 4.2.1 - newer hxcpp breaks Lua colors in this engine).

`hmm.json` references it as a git dependency:

```json
{ "name": "hxvlc", "type": "git", "url": "./hxvlc-local", "ref": "master" }
```

To (re)install: run `install.bat`, or:

```
haxelib remove hxvlc
haxelib git hxvlc ./hxvlc-local master
```

The build scripts (`art/*.bat`) set `HAXELIB_PATH` to the project-local
`.haxelib` so every build uses the fork. If you run `lime build` by hand, set
it too, otherwise haxelib may resolve hxvlc from the global repo.

## Notes

* All wrappers extend `hxvlc.flixel.FlxInternalVideo`, which resolves embedded
  OpenFL assets (Android APK assets) automatically - no manual copy to storage
  is needed.
* Playback is started with hxvlc's `play()` (libvlc_media_player_play).
  `resume()` only unpauses an already-playing player and must NOT be used to
  start a video - older wrappers did this and videos never started.
* Playback errors no longer `throw` (hxCodec 2.5.1 threw "VLC caught an error!"
  and crashed the game). They log, clean up and call `finishCallback`.
* If `hxvlc` is not linked (e.g. HTML5), these files compile to harmless dummy
  classes so the project still compiles.

## Cleanup checklist (already applied)

Stuff removed during the hxCodec -> hxvlc migration:

* `haxelib remove hxCodec` - old library is no longer referenced.
* Removed unused haxelib versions pulled in as hxvlc dependency noise:
  `lime 8.3.2`, `openfl 9.5.2`, `hxcpp 4.3.2`. Project pins stay:
  lime 8.0.1 / openfl 9.2.1 / hxcpp 4.2.1 / Haxe 4.2.5.
* Deleted the superseded compat experiment `bug/vlc/MP4Handler.hx` and the
  obsolete `setup/fix-hxcodec-linux-libs.sh` (hxCodec-specific).
* Removed temporary diagnostics (`bug/vlctest`, `bug/plusengine-hxcodec`,
  `export/debug` build artifacts).

To rebuild from a clean state: `install.bat` (installs from `hmm.json`),
then `art/build_x64.bat` (release) or `art/build_x64-debug.bat` (debug).
