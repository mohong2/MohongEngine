# mohong 目录重写说明

> 按铁律：每个组件"旧实现错在哪 / 新实现怎么设计 / 接在哪个真实调用点 / 怎么验证"。
> 每个组件单独 commit（见 git log，commit 信息一致）。
> 目录现状：10 个文件 → 重写 9 个 + 删除 1 个（AssetPreloader）+ 新增 1 个（PerfTest，测量基建）。

## 1. TraceLevel / TraceEntry（commit 50e34ea）

- **旧实现错在哪**：本身没错（纯枚举/纯 typedef），按"全部推倒重写"要求重写为等价实现，注释与语义对齐（DEBUG<INFO<WARN<ERROR 的顺序意义写明）。
- **新实现**：同形枚举与 typedef（字段与旧版完全一致，API 兼容）。
- **挂点**：被 TraceManager/TraceConsole 及全部 300+ 调用点使用。
- **验证**：编译通过 + 全部调用点行为不变（Windows 实机日志正常）。

## 2. TraceManager（commit 50eea）

- **旧实现错在哪**：
  1. 每条裸 `trace()` 都无差别做一次 `Language.get` 字典查找（自由文本日志也查）；
  2. 控制台写路径在非 sys 平台（HTML5）完全没有输出——浏览器端监控瞎；
  3. 日志系统与 TraceConsole 各写一套输出逻辑。
- **新实现**：
  - 翻译只在消息"像语言键"（含点、无空白、`Language.has` 命中）时进行；
  - 输出按平台分支：`#if (cpp && windows)` WriteConsoleW / `#elseif sys` Sys.println / `#elseif js` js console（debug/info/warn/error 对应 console 方法）；
  - 环形缓冲、Mutex 临界区、监听器逻辑保留并精简（API 全兼容：info/warn/error/debug、addListener/removeListener、getAll/getFiltered/getStats/exportToJson/saveToFile/clear/getCount、init/syncWithPrefs/enableConsoleOutput/applyConsoleLevel、MAX_ENTRIES/enabled/consoleOutput/consoleLevel）。
- **挂点**：Main.new 的 `init()`（拦截 haxe.Log.trace）+ 全项目 300+ 调用点。
- **验证**：Windows 实机控制台日志（带颜色/级别/模块）；HTML5 编译后浏览器 console 可见（编译验证 + DevTools 对照）；环形缓冲 5000 条封顶内存恒定。

## 3. TraceConsole（commit 50eea）

- **旧实现错在哪**：无论有没有控制台，每条日志都做时间/颜色/字符串拼接（纯浪费 CPU）。
- **新实现**：启动时探测输出目标（Windows `hasConsole()`，sys/js 恒有），无目标时监听回调直接返回——零格式化开销。start/stop/onTrace 语义不变。
- **挂点**：Main.new（desktop 启动）+ OptionsState 的 Trace Console 开关。
- **验证**：Windows 实机开/关 Trace Console，输出出现/消失；无控制台运行时 CPU 不再付格式化成本（perf CSV 佐证）。

## 4. MemoryMonitor（commit 0afc7b4）

- **旧实现错在哪**：非 cpp 平台内存恒 0（HTML5 监控瞎）；`disposedBitmapCount` 声明却从不递增；`cachedGraphicCount` 每次读取 O(n) 遍历 + 分配数组；无分位数统计，无法做 before/after 基准。
- **新实现**：
  - `currentMemoryUsage` 平台分支：cpp → `System.totalMemory` + `cpp.vm.Gc.memInfo64(MEM_INFO_CURRENT)`（GC 堆锯齿曲线）；js → `performance.memory.usedJSHeapSize`（Chrome/Edge，其余浏览器 0 并注明）；其他 → 0（文档化）；
  - 帧时间环形缓冲（4096 槽）+ `getFrameStats()` p50/p95/p99/max；
  - 内存采样历史（每 120 帧一条，封顶 10000）+ `exportStats()` CSV（sys 平台，显式调用才写盘）；
  - cachedGraphicCount 每 60 帧刷新缓存值；livingGraphicCount O(1) 维护；untrackGraphic 时 disposedBitmapCount 真实递增。
- **挂点**：Main ENTER_FRAME（onFrameStart，已有）+ Paths trackGraphic/untrackGraphic（已有）+ ClientPrefs.memoryOptimization 开关（已有）。
- **验证**：perf CSV 有真实内存曲线/帧时间分位；切歌 20 次后 cached/living 回落、disposed 递增；HTML5 Chrome 内存非 0。

## 5. Windows（commit 96b4182）

- **旧实现错在哪**：功能可用，但注释与实现散乱、结构不统一（本组件主要做"功能等价重写"）。
- **新实现**：全部 Win32 实现收进 `#if (cpp && windows)`（headerCode 同前），非 Windows 平台每函数显式无害返回；9 个函数签名与返回契约逐一保持（enableDarkMode/allocConsole/freeConsole/writeConsole/hasConsole/reopenConsole/enableAnsiColors/showDialog/showYesNoMessageBox + DialogType）。
- **挂点**：Main、TraceManager、TraceConsole、OptionsState、OptionLoader、backend.Dialog、UnsavedChangesTracker（全部已有 guard）。
- **验证**：Windows 实机深色模式/对话框/Trace Console 行为与重写前一致；mac/linux/html5 编译时全部跳过（编译验证）。

## 6. RenderOptimizer（commit 8824279 + 11efdda）

- **旧实现错在哪**：宣称 draw call 统计/atlas 批处理/自动剔除，但 `estimatedDrawCalls`/`spritesRenderedThisFrame` 零调用点；`onRenderStart/onRenderEnd` 从未被渲染循环调用；PlayState 只有空 import；sortByTexture/isSpriteOnScreen 等 helper 零调用——典型"配置开关+零调用点"假优化。
- **新实现**：诚实的渲染观测——
  - `onRenderStart/onRenderEnd` 挂 `FlxG.signals.preDraw/postDraw`（FlxGame.draw 真实渲染前后派发，flixel 公共 API，不改库）；
  - 渲染段耗时（preDraw→postDraw）环形缓冲 + p50/p95；
  - 可见精灵采样（每 30/60/120 帧一次，遍历 FlxG.state.members 统计 exists&&visible&&alpha>0 的 FlxSprite，不计子状态——文档化）；
  - 帧预算告警（超阈值 TraceManager 输出，每秒最多一条）；
  - `renderQualityLevel` 真实效果 = 采样频率 + 预算阈值（观测强度）。**不碰视觉质量**（此 fork 无 defaultAntialiasing；视觉由 lowQuality/globalAntialiasing 负责，已在 ClientPrefs 注释说明）。
  - 删除全部零调用点 helper（sortByTexture/isSpriteOnScreen/shouldRenderCamera 等）。
- **挂点**：Main.setupGame（信号接线）+ ClientPrefs.loadDefaultKeys（开关/级别）。
- **验证**：perf 快照里 visibleSprites 随场景变化（标题 vs 打歌）；渲染耗时 p50/p95 有数据；超预算告警在 Trace Console 出现。

## 7. GPUTextureManager（commit 057bf47）

- **旧实现错在哪**：Stage3D 时代遗留的"兼容别名"（trackTextureAllocation/safeDisposeTexture 等）零调用；真正的 `trackGraphic` 从没被加载路径调用，`estimatedVRAMUsage` 恒 0；detectOrphanedTextures 只查 null key 不查 zombie。
- **新实现**：纯记账器——`trackGraphic(key, graphic)` 按位图尺寸（w*h*4）入账；`untrackGraphic` 冲销；created/disposed 计数 + 峰值 + getDiagnostics/resetTracking。删除全部 Stage3D 别名。**不 dispose 任何贴图**（销毁全权交给 FlxG.bitmap 引用计数 + Paths 僵尸守卫）。
- **挂点**：Paths.cacheBitmap（每次真实加载）→ trackGraphic；Paths.purgeGraphicFromCaches（每次真实清理）→ untrackGraphic。与 useCount 生命周期同一条账。
- **验证**：加载大图后 VRAM 估算增加、切歌后回落；getDiagnostics 与 MemoryMonitor.cachedGraphicCount 趋势一致。

## 8. ObjectPool + Note 池化（commit cbc28ae）

- **旧实现错在哪**：泛型池实现存在但全项目零调用点。
- **新实现**：纯数据结构（零平台依赖、不依赖引擎类型）：borrow/release/clear + 计数诊断 + 容量上限。接线到 Note 热路径：
  - `PlayState.generateSong` 用 `Note.fromPool(...)` 借出（与原 `new Note` 共用同一份 `initNote` 构造逻辑，无逻辑漂移）；
  - `PlayState.destroy` 把 notes 组 + unspawnNotes 全部 `releaseToPool()`：清空全部 Note 级可变状态（extraData/tail/prev/next/rating/spawned/noteType…），定向释放渲染资源（`graphic=null` 触发 useCount--，与僵尸守卫同一本账），**不做完整 FlxSprite.destroy**（避免 scale/offset/origin 置空后被 updateHitbox 解引用崩溃），保留结构等 revive；
  - `reinitForPool`：revive → 清零 FlxSprite 可变状态（scale/flip/angle/alpha/blend/velocity…）→ 重跑 initNote；
  - 复用窗口只在歌曲之间（脚本已 stop），歌曲进行中的对象身份语义对 mod 不变。
- **挂点**：PlayState.generateSong / PlayState.destroy（真实热路径：高密度谱面数千 Note）。
- **验证**：perf 快照中 `Note.pool` 诊断（created/borrowed/returned）随重试增长且 created 不再增长；botplay 20 次重试无崩溃、判定计数正常、内存曲线平稳。

## 9. AssetPreloader（commit 8c9bb46，删除）

- **旧实现错在哪**：零调用点；类注释引用不存在的用法；`forceGPUResident` 改 persist/destroyOnNoUse 是破坏引用计数语义的臆造。
- **处置**：按铁律"要么接入 LoadingState 真实工作，要么直接删掉"——删除。LoadingState 的 lime 库级 Promise/MultiCallback 加载已在真实工作（每次切歌都走），不需要第二个并行的"逐资产预载器"。
- **验证**：删除后全项目编译通过；切歌加载行为不变（实机）。

## 10. PerfTest（commit 32189a1，新增）

- **用途**：验收驱动的测量基建（--perf-test song/menu，仅 sys 平台参数生效，无参数零开销）。
- **挂点**：Main.setupGame（init + postStateSwitch 监听）+ PlayState.endSong（重试钩子）。
- **验证**：自动 botplay 20 次重试后 perf/perftest_song.csv + 摘要落盘，进程退出。

## 库 override 与依赖声明

见 `README.md`（override 清单）与 hmm.json（库引用切换），详见库文件变更清单一节。
