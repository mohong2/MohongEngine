# SeiunEngine 性能剖析报告 v1（before 基线）

> 生成环境：Windows 本机（Haxe 4.2.5 / Lime 8.0.1 / hxcpp 4.2.1），debug 构建 `SeiunEngine.exe` 实机启动验证通过（标题画面渲染正常，2495 种颜色/62.5% 非黑像素）。
> 所有结论附带 `文件:行号` 证据。影响平台按 `#if` 分支推断，实机验证平台见"验证"列。

## 0. 平台概览

| 平台 | 帧率上限 | 内存测量 | GC | 切歌清理路径 |
|---|---|---|---|---|
| Windows/macOS/Linux (cpp) | 被写死 60（见 P0-1） | System.totalMemory ✓ | 强制 System.gc()（P0-3） | clearStoredMemory+clearUnusedMemory |
| Android/iOS (cpp) | 同上 | ✓ | 同上 | 同上 |
| HTML5 | 同上 | **返回 0（瞎）** | 浏览器托管 | 同上（但无 System.gc） |
| Switch | 同上 | 0 | 无 | 同上 |

## P0 — 低风险高收益（先修）

### P0-1 帧率被写死 60，ClientPrefs.drawFramerate(默认144) 未接线
- 证据：`source/Main.hx:56` `var framerate:Int = 60;` → `Main.hx:177` `new FlxGame(..., framerate, framerate, ...)`；
  flixel `FlxGame.hx:343-344,386` 构造器把两者写入 `FlxG.updateFramerate/drawFramerate` 并设 `stage.frameRate = drawFramerate`。
  `ClientPrefs.hx:770-781`（loadDefaultKeys）之后虽然重设 FlxG.updateFramerate/drawFramerate，
  **但没有任何代码回头改 `stage.frameRate`** → 显示始终被 60Hz 锁死。
- 为什么：`stage.frameRate` 决定 Lime 的定时器/VSync 目标。GPU 闲、CPU 打不满却上不去帧率的一半原因在此。
- 影响平台：全平台（FlxGame 同一构造路径）。验证：Windows 实机 FPS 计数。
- 修法：Main.setupGame 在 `ClientPrefs.loadDefaultKeys()` 之后、构造 FlxGame 之前读取 ClientPrefs.data.framerate/drawFramerate 传入。

### P0-2 release 构建带调试 define（原生目标全平台）
- 证据：`Project.xml:196-197`：
  ```xml
  <haxedef name="HXCPP_CHECK_POINTER" if="release" />
  <haxedef name="HXCPP_STACK_LINE" if="release" />
  ```
- 为什么：hxcpp 的指针检查与栈行号跟踪是纯 debug 设施，进发布版让所有原生目标在每帧所有 C++ 调用上付出额外开销。
- 影响平台：cpp（Windows/macOS/Linux/Android/iOS）。验证：Windows release 编译 + 实机帧时间对比。
- 修法：改为 `if="debug"` 或直接删除（debug 构建 hxcpp 自带）。

### P0-3 切歌路径强制 System.gc() 造成卡顿
- 证据：`Paths.hx:164`（clearUnusedMemory 内 `System.gc()`）；调用点：
  `PlayState.hx:1666`（每首歌 create 末尾）、`StoryMenuState.hx:68`、`TitleState.hx:138+153`、
  `ModState.hx:129`、`ModsMenuState.hx:79`、`ModsMenuStateOld.hx:59`，以及 `Paths.hx:700`
  （image/cacheBitmap 内缓存达 maxCachedAssets 时**加载中途**同步触发）。
- 为什么：hxcpp 的 System.gc() 是同步全堆标记清扫，游戏加载完几百 MB 图/音频后一次 GC 可达数百 ms → 切歌黑屏顿挫。
- 影响平台：cpp 全平台（Windows/macOS/Linux/Android/iOS）。HTML5 无 System.gc，不受影响。
- 修法：从 clearUnusedMemory 移除 System.gc()（回收交给 hxcpp 默认增量行为）；不关 GC、不手动调 GC。

### P0-4 MemoryMonitor 非 cpp 平台内存监控是瞎的
- 证据：`MemoryMonitor.hx:64-71` `get_currentMemoryUsage()` 在 `#if cpp` 返回 `System.totalMemory`，其余返回 0。
  HTML5 全程报 0，切歌内存曲线无法观测 → 症状 6 无法验证也无法回归。
- 影响平台：HTML5 为主；任何非 cpp 目标。验证：HTML5 编译 + 浏览器 DevTools 对照。
- 修法：mohong 重写时做平台分支（见重写清单）。

## P1 — mohong 假组件（重写目标，见 docs/perf/02-mohong-rewrite.md）

现状速记（全部在 `source/mohong/`，10 个文件）：
- `RenderOptimizer`：计数器（estimatedDrawCalls/spritesRenderedThisFrame）**零调用点**；`PlayState.hx:69` 只有 import；`ClientPrefs.hx:794-796` 只设开关。onRenderStart/onRenderEnd 从未被渲染循环调用。
- `ObjectPool`：全项目零调用点（grep 仅命中自身与注释）。
- `AssetPreloader`/`AssetPreloaderManager`：零调用点；类注释宣称的用法不存在；`LoadingState` 真实加载走 lime 库级 Promise（其 NO_PRELOAD_ALL 分支已注释）。其 `forceGPUResident` 逻辑改 persist/destroyOnNoUse 是破坏引用计数语义的臆造。
- `GPUTextureManager`：`Paths.hx:31` 只 import 无调用；trackGraphic 零调用 → estimatedVRAMUsage 恒 0；`detectOrphanedTextures` 只查 null key 不查 zombie。
- `MemoryMonitor`：Main/Paths 已真实接线（每帧 onFrameStart + track/untrack），但非 cpp 内存为 0；`get_cachedGraphicCount` 每次调用 O(n) 遍历 FlxG.bitmap._cache 且分配数组。
- `TraceManager` 全家：全项目 314 处调用点，API 必须兼容；问题：每条 trace 都做 Language.get 翻译 + 建 TraceEntry；桌面端默认 consoleLevel=DEBUG 全量写控制台；HTML5 无 sys 分支 → 不落 js console。
- `Windows.hx`：功能基本齐全且已 `#if (cpp && windows)` 隔离；重写要求功能等价。

## P2 — 假开关（配置开关 + 零调用点）

- `ClientPrefs.cacheOnGPU` / `preloadAssets`：唯一 UI 在 `source/options/_backup/GraphicsSettingsSubState.hx`（备份目录，不在运行路径）；`PlayState.hx:6916` 中 cacheOnGPU 判断被注释。零真实逻辑。
- `Paths.forceGPUUploadOnLoad`（`Paths.hx:76`）：声明后零使用。
- `ClientPrefs.texturePooling/memoryOptimization`：只喂给 mohong 组件的 managementEnabled/optimizationEnabled 开关，组件本身无接线 → 开关无效果。
- 处置：要么接真实逻辑，要么从存档/UI 摘除并登记迁移说明（不能破坏存档兼容）。

## P3 — 内存只涨不跌的可疑点（待实机验证后修复）

- `Paths.hx:79-83`：`maxCachedAssets` 已按 mobile 分 200/300，但 `allowGraphicAutoFree=false` 未按平台区分，与注释（"移动端应开启自动释放"）不符。
- `TitleState.hx:137-153`：连续两次 `clearStoredMemory()+clearUnusedMemory()`，冗余。
- `Paths.image/cacheBitmap`（`Paths.hx:544-601,685-701`）缓存命中路径每帧 push localTrackedAssets 无去重。
- `Main.hx:291-292`：HTML5 `FlxG.autoPause=false` → 切后台继续全速跑，回前台音频/时间跳变（症状 5/6 相关）。
- FlxTween/FlxTimer/事件监听泄漏：菜单/子状态逐个过（MusicBeatState/MusicBeatSubstate destroy 链），未发现明显未注销监听，待长测数据说话。

## 基准方案（按平台）

| 平台 | 工具 | 场景 | 指标 |
|---|---|---|---|
| Windows | 游戏内采样器（MemoryMonitor 重写后导出 CSV）+ 任务管理器 | 标题画面 60s；同一首歌 botplay 20 次重试；菜单往返 20 次 | 帧时间 p50/p95、FPS、内存曲线、bitmap 缓存数、GC 次数 |
| Android | 游戏内采样器 + `adb shell dumpsys meminfo` | 同上 | 同上 + Java heap/native heap |
| HTML5 | 游戏内采样器（js console / 内存导出）+ Chrome DevTools Performance/Memory | 同上 | 同上（内存用 performance.memory，Chrome-only 注明） |
| macOS/Linux | 游戏内采样器 + Instruments(mac)/perf(linux) | 同上 | 同上 |
| Switch | 游戏内采样器 | 编译验证 + 行为等价 | 帧时间 |

> 每平台数据单独记录；未实机的平台标注"仅编译验证 + 环境缺失原因"。
