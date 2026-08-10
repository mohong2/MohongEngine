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
