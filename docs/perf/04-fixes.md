# 修复清单（交付物 2/3：优先级、风险、mod API 影响、平台范围）

> 顺序即实施顺序（低风险高收益先行）。commit 见 git log（HEAD: c208bfc）。

| # | 修复 | commit | 优先级 | 风险 | 触及 mod API | 影响平台 |
|---|---|---|---|---|---|---|
| 1 | release 移除 HXCPP_CHECK_POINTER/STACK_LINE | 47aeca6 | 高 | 极低（debug 行为中性） | 否 | cpp 全平台 |
| 2 | Main.hx 帧率接线 ClientPrefs（+移动端刷新率封顶） | 21e8a5e | 高 | 低 | 否（存档字段未动） | 全平台 |
| 3 | Paths.clearUnusedMemory 移除 System.gc() | 0e608b1 | 高 | 低 | 否 | cpp 全平台 |
| 4 | Trace 四件套重写（翻译门控 + 平台输出分支 + TraceConsole 零格式化开销） | 50e34ea | 高 | 低（API 全兼容，300+ 调用点未动） | 否 | 全平台 |
| 5 | MemoryMonitor 重写（平台内存分支 + 帧时间分位 + CSV 导出 + 真实销毁计数） | 0afc7b4 | 高 | 低（监控侧，不碰回收） | 否 | 全平台 |
| 6 | Windows.hx 等价重写 | 96b4182 | 中 | 低（Win32 实现未变） | 否 | Windows |
| 7 | RenderOptimizer 重写 + preDraw/postDraw 真实接线 + renderQualityLevel 观测强度化 | 8824279/11efdda | 中 | 低（纯观测） | 否 | 全平台 |
| 8 | GPUTextureManager 重写 + Paths 加载/销毁双接线 | 057bf47 | 中 | 低（纯记账） | 否 | 全平台 |
| 9 | ObjectPool 重写 + Note 池化（fromPool/releaseToPool，歌曲间复用） | cbc28ae/6f6994a | 中 | 中（Note 状态面大；已审计 setupNoteData 的复用预留 + 状态清零 + 拒绝已 destroy 实例；实机 20 次重试验证） | 否（歌曲间复用窗口，歌中对象身份不变） | 全平台 |
| 10 | AssetPreloader 删除（LoadingState 已在真实工作） | 8c9bb46 | 中 | 低（零调用点） | 否 | 全平台 |
| 11 | PerfTest 验收驱动（--perf-test，仅 sys 激活） | 32189a1/c208bfc | 中 | 低（无参数零开销） | 否 | sys |
| 12 | 假开关清理：cacheOnGPU/preloadAssets 字段移除（访问器读老存档键保留 mod 兼容）、forceGPUUploadOnLoad 删除、allowGraphicAutoFree 注释对齐现实 | 363d58a | 中 | 低 | 兼容访问器保留 | 全平台 |
| 13 | 库 vendor：flixel-local/flixel-ui-local/openfl-local + hmm.json dev 引用 + README 清单 | 已提交 | 中 | 中（构建链路切换；dev 链接 + 全量重编译验证通过） | 否 | 全平台 |

## 每个修复的具体改动（diff 摘要）

1. **Project.xml**：删除两行 `haxedef ... if="release"`，替换为说明注释。
2. **Main.hx setupGame**：构造 FlxGame 前读 `ClientPrefs.data.framerate/drawFramerate`；
   `#if (mobile || switch)` 按 `displayMode.refreshRate` 封顶两项；<30 时回退 60。
3. **Paths.hx**：`clearUnusedMemory` 内删除 `System.gc();` 行与 `import openfl.system.System;`。
4. **mohong/Trace\*.hx**：见 docs/perf/02-mohong-rewrite.md。
5. **MemoryMonitor.hx**：同上。
6. **Windows.hx**：同上。
7. **RenderOptimizer.hx + Main.hx + ClientPrefs.hx**：`FlxG.signals.preDraw/postDraw.add(...)`；
   ClientPrefs 仅保留 optimizationEnabled/renderQualityLevel 接线。
8. **GPUTextureManager.hx + Paths.hx**：cacheBitmap → trackGraphic；
   purgeGraphicFromCaches → untrackGraphic。
9. **ObjectPool.hx + Note.hx + PlayState.hx**：Note.fromPool/releaseToPool/reinitForPool/initNote；
   PlayState.generateSong 借出、PlayState.destroy 遍历 unspawnNotes 归还一次 + notes.clear()。
10. **删除 source/mohong/AssetPreloader.hx**。
11. **新增 source/mohong/PerfTest.hx**；Main.setupGame `PerfTest.init()`；PlayState.endSong 钩子。
12. **ClientPrefs.hx**：data 类删两字段，静态访问器改读 `FlxG.save.data`（Reflect 守卫）；
    **Paths.hx** 删 forceGPUUploadOnLoad 与 RectangleTexture import；修正 allowGraphicAutoFree 注释。
13. **flixel-local/ flixel-ui-local/ openfl-local/ hmm.json README.md**：见 README "Vendored libraries"。

## 故意不动的（理由）

- **PlayState.destroy 已有清理**：lua/hscript stop、hxvlc disposeAll、数组清空——不重复造轮子。
- **渲染后端 / 跨线程渲染 / Stage3D**：铁律禁止；RenderThread.hx 与 GPUTextureManager 头注释已有实测结论。
- **GC 策略**：不关 GC、不手动 System.gc；只移除强制调用。
- **Note 池化的歌曲内复用**：歌曲中命中即销毁的 note 不入池（mod 引用身份安全）。
- **allowGraphicAutoFree 未开启**：destroyOnNoUse=true 会摧毁"缓存但暂无引用"的贴图与 FlxBar 前景贴图，得不偿失（注释已对齐现实）。
- **HTML5 整体可构建性**：README 声明 "No HTML5 build"；编译验证止步于 mod 系统既有未 guard 的 sys 导入（ModsMenuState→ModInstaller→Main 链），属既有缺口，不是本次改动引入。
