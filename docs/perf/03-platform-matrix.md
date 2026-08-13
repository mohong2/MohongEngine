# Platform verification matrix

Scope: 3 desktop (Windows / macOS / Linux) + 2 mobile (Android / iOS).
HTML5 and Switch are out of scope.

Legend: ✅ verified / ⚠️ compile-only (env limited) / ❌ not verified (env missing) / ➖ n/a

## Change × platform

| Change (commit) | Windows | macOS | Linux | Android | iOS |
|---|---|---|---|---|---|
| framerate wiring (21e8a5e) | ✅ real FPS | ⚠️ | ⚠️ | ⚠️ | ⚠️ |
| release defines (47aeca6) | ✅ | ⚠️ | ⚠️ | ⚠️ | ⚠️ |
| remove System.gc (0e608b1) | ✅ | ⚠️ | ⚠️ | ⚠️ | ⚠️ |
| Trace family (50e34ea) | ✅ | ⚠️ | ⚠️ | ⚠️ | ⚠️ |
| MemoryMonitor (0afc7b4) | ✅ | ⚠️ | ⚠️ | ⚠️ | ⚠️ |
| Windows.hx (96b4182) | ✅ | ➖ no-op | ➖ no-op | ➖ no-op | ➖ no-op |
| RenderOptimizer (8824279/11efdda) | ✅ | ⚠️ | ⚠️ | ⚠️ | ⚠️ |
| GPUTextureManager (057bf47) | ✅ | ⚠️ | ⚠️ | ⚠️ | ⚠️ |
| ObjectPool+Note (cbc28ae/6f6994a) | ✅ | ⚠️ | ⚠️ | ⚠️ | ⚠️ |
| delete AssetPreloader (8c9bb46) | ✅ | ⚠️ | ⚠️ | ⚠️ | ⚠️ |
| PerfTest (32189a1/…) | ✅ | ⚠️ | ⚠️ | ⚠️ | ⚠️ |
| cacheOnGPU cleanup (363d58a) | ✅ | ⚠️ | ⚠️ | ⚠️ | ⚠️ |

## Environment notes

- Windows: Haxe 4.2.5 / MSVC, real machine, verified with a mod in play.
- Android: SDK at android-sdk-windows, JAVA_HOME = Android Studio jbr (JDK 17).
  Gradle 6.7.1 is picky about JDK version; compile result pending.
- macOS / Linux: Windows host, no cross toolchain. Code avoids bare
  platform-specific calls (conditional-compile review); build must run on
  those targets or CI.
- iOS: cpp code paths only; needs a Mac + Xcode to build.

(rows get filled with measured results as each target is run)
