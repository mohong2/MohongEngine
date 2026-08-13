# SeiunEngine

A Friday Night Funkin' engine, forked from Psych Engine 0.6.3. Built for the Mandela Funkin Night mod.

**Note:** This project uses AI-assisted tools in its development.

**中文版：[ZHREADME.md](./ZHREADME.md)**

## Supported platforms

- Windows
- macOS
- Linux
- Android
- iOS — builds, but untested. No idea if it actually runs.

No HTML5 build.

## Building

You need Haxe 4.2.5.

```sh
haxelib setup .haxelib
haxe -cp ./setup -main Main --interp
lime build windows
```

Other targets: `lime build mac`, `lime build linux`, `lime build android`, `lime build ios -arm64`.

You can also build via the Build workflow on GitHub Actions (manual trigger, pick a platform, download the artifact).

## Dependencies

See `hmm.json`. Four of them are forks of mine:

- flixel
- hxvlc
- extension-androidtools
- linc_luajit-rewriten

### Vendored libraries (git-tracked, engine patches applied)

`flixel-local/`, `flixel-ui-local/`, `openfl-local/` are full in-repo copies of the
libraries the engine patches. `hmm.json` references them with `"type": "dev"`
(`haxelib dev <name> ./<name>-local`) instead of `"type": "git"` on purpose:
`haxelib git` shells out to `git clone`, which requires the local directory to be
a git repository — and a nested `.git` would stop this repository from tracking
the files. `dev` achieves the same goal (self-contained, git-tracked, recreated by
`install.bat`) and is supported by `setup/Main.hx`.

| vendored dir | base | engine patches applied |
|---|---|---|
| `flixel-local/` | mohong2/flixel @ master (4.11.0) | `flixel/system/FlxSound.hx`, `flixel/animation/FlxAnimationController.hx`, `flixel/system/ui/FlxSoundTray.hx` |
| `flixel-ui-local/` | flixel-ui 2.4.0 | `flixel/addons/ui/FlxInputText.hx`, `flixel/addons/ui/FlxUIInputText.hx` |
| `openfl-local/` | openfl 9.2.1 | `openfl/display/FPS.hx`, plus engine-added `openfl/display/OldFPS.hx` |

### Classpath overrides that stay in `source/` (no lib change)

- `source/lime/_internal/backend/native/NativeAudioSource.hx` — patches lime 8.0.1's
  native audio backend. Lime stays a plain haxelib in `hmm.json` because its
  cross-platform binary set is ~285 MB and vendoring it into git is not viable;
  the override itself is tracked here in `source/`.
- `source/flixel/addons/display/FlxRuntimeShader.hx` — engine-added class (not
  present in flixel 4.11 / flixel-addons 2.11).

`source/` is ahead of every haxelib in classpath order, so these overrides win
regardless of the linked library version.

### Re-installing after dependency changes

```bat
install.bat
:: or manually: haxelib setup .haxelib && haxe -cp ./setup -main Main --interp
```

## Mods

Drop mods into `mods/`. See `Modding.md`.

## Credits

- **mo_hong** — modifications and Chinese translation
- **Li.tmc** — engine icon
- **Psych Engine team** (Shadow Mario, RiverOaken, Yoshubs) — base engine
- **Codename Engine team** ([CodenameCrew](https://github.com/CodenameCrew)) — this engine's mod system follows Codename Engine's mod format (`pack.json`, `stateReplacements`/`substateReplacements`, chart import/export). SeiunEngine is **not** a fork of Codename Engine and contains **no Codename Engine source code**. Please refer to the [Codename Engine repository](https://github.com/CodenameCrew/CodenameEngine) for their own terms.
- Special thanks: bbpanzu, shubs, SqirraRNG, KadeDev, iFlicky, PolybiusProxy, Keoiki, Smokey, Nebula the Zorua

## License

See LICENSE (Psych Engine's open source license).
