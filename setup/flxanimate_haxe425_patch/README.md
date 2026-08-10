# flxanimate 4.0.0 — Haxe 4.2.5 compatibility patch

Psych Engine 1.0.4-era `flxanimate` 4.0.0 uses `??` (null-coalescing, Haxe 4.3+)
and `FlxPoint.negate()`, neither of which exists in SeiunEngine's pinned
toolchain (Haxe 4.2.5 + this repo's flixel fork).

`install_flxanimate.bat` installs `flxanimate 4.0.0` into the project-local
`.haxelib` and copies these three patched files over the library sources:

- `FlxElement.hx`        — replace `??` with explicit null checks
- `MacroAnimationData.hx`— replace `??` in the macro with a ternary
- `FlxAnimateFrames.hx`  — avoid `Null<FlxPoint>.negate()`

The patch is verified by `lime build windows -release` on 2026-08-10.
