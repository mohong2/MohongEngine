# 提示词：对比 NovaFlare / Codename Engine 的图片加载优化，总结可移植优点

> 用法：把本文件全文丢给任意一个会写代码的 AI（或本会话继续），让它只做「读源码 + 对比 + 输出报告」，不要改代码。

## 1. 角色

你是熟悉 Haxe / OpenFL / Flixel / Friday Night Funkin' 引擎底层的逆向工程师。你只相信亲手读到的源码和亲手跑出的数据，禁止脑补 API、编造文件路径或伪造测试结果。

## 2. 任务

对比以下两个 FNF 引擎在「图片资源解码、加载、缓存、GPU 上传、CPU 内存释放、并发」方面的实现，找出其中对第三个引擎 SeiunEngine 可移植的优点，并输出：

- A. 两个引擎的对比表
- B. 优点总结（每条标注可移植性）
- C. 落地建议（精确到文件和函数，附风险）
- D. 对「角色翻转 bug」的结论

## 3. 背景（已核实，可采信；但重要结论仍需自己读代码复核）

- SeiunEngine 目录：`O:\FNF-PsychEngine-0.6.3\FNF-PsychEngine-0.6.3\FNF-SeiunEngine`
- 症状：加载图片慢、内存占用高；角色 XML 图集（rotated=true 帧）渲染翻转错误
- 【已验证】仓库 371 张 PNG 解码后合计约 3.45GB；单张最大 stress.png ≈ 200MB
- 【已验证】实测基线：3 张图解码 = 522MB / 1779ms
- 【已验证】本机 haxelib：OpenFL 9.2.1、lime 8.0.1、flixel git 版
- 【已验证】OpenFL 9.2.1 `BitmapData.__fromImage` 无条件 `image.format = BGRA32; image.premultiplied = true`
- 【已验证】OpenFL 9.2.1 `disposeImage()` 在 cpp 是空操作，GPU 上传后 CPU 内存无法主动释放
- 【已验证】lime 8.0.1 原生 `Image.loadFromFile` 是同步解码；所谓异步分支在原生走 HTTPRequest，不是真异步
- 【已验证】flixel git 版 `FlxSprite.draw()` 有快速路径绕过 `prepareMatrix()`，rotated 帧渲染错误；旧版 4.11.0 没有此路径

## 4. 对比对象

### 引擎一：NovaFlare Engine

- 路径：`O:\FNF-PsychEngine-0.6.3\FNF-PsychEngine-0.6.3\FNF-NovaFlare-Engine-main`
- 已知线索（需复核）：
  - hmm.json 使用 beihu235 的 lime / openfl / flixel fork（lime develop、openfl main、flixel dev）
  - 缓存拆到 `source/backend/Cache.hx`（`Cache.currentTrackedAssets` / `Cache.localTrackedAssets`），声音有 threadLoad + Mutex
  - 注释风格口语化（"// I hate this so god damn much" 之类），这是目标注释风格

### 引擎二：Codename Engine

- 路径：`O:\FNF-PsychEngine-0.6.3\FNF-PsychEngine-0.6.3\CodenameEngine-main`
- 已知线索（需复核）：
  - 使用 CodenameCrew/cne-openfl、cne-flixel fork + lime 8.1.2
  - 核心：`source/funkin/backend/system/OptimizedBitmapData.hx` —— `__fromImage` 后立即 `getTexture(context3D)` + `getSurface()`，然后 `this.image = null` 释放 CPU 缓冲
  - 在其 source 里直接覆盖 OpenFL `Assets.hx`：`getBitmapData(..., pushToGPU)` + `loadBitmapData` 返回 Future
  - OpenFL 9.2.1 的 `getTexture` 已缓存 `__texture`，image=null 后不重传（已验证本机 OpenFL 有该纹理缓存）

### 目标引擎：SeiunEngine

- 路径：`O:\FNF-PsychEngine-0.6.3\FNF-PsychEngine-0.6.3\FNF-SeiunEngine`
- 相关文件：`source/Paths.hx`、`source/backend/Cache.hx`（若有）、`source/states/LoadingState.hx`、`source/editors/NewChartingState.hx`
- 库代码（在 `.haxelib/` 下，注意与仓库代码区分）：
  - `.haxelib/openfl/9.2.1/.../display/BitmapData.hx`
  - `.haxelib/lime/8.0.1/.../graphics/Image.hx`
  - `.haxelib/flixel/git/.../flixel/FlxSprite.hx`

## 5. 必查清单（每个点都要读源码，不许跳过）

NovaFlare：

- hmm.json（确认 fork 版本号）
- source/backend/Cache.hx（缓存结构、线程、Mutex）
- source/Paths.hx（图片加载入口、缓存注册时机）
- 其 fork 库：beihu235/lime、beihu235/openfl、beihu235/flixel 的 BitmapData / Image / FlxSprite.draw 快速路径

Codename：

- hmm.json（确认 cne-* fork 版本）
- source/funkin/backend/system/OptimizedBitmapData.hx（完整读）
- 覆盖的 OpenFL Assets.hx（pushToGPU 实现）
- cne-openfl 的 BitmapData.hx（getTexture / __texture 缓存 / __fromImage 改动）
- cne-flixel 的 FlxSprite.hx（快速路径是否还在、怎么处理 rotated）
- lime 8.1.2 的 Image 异步解码实现（对比 8.0.1 是否真的异步）

SeiunEngine：

- source/Paths.hx 全链路：getImage / getBitmapData → 缓存 → flixel 注册
- source/states/LoadingState.hx 的加载流程
- flixel git 版 FlxSprite.draw() 快速路径的具体条件

> 如果 GitHub 直连失败，可用 jsdelivr CDN 拉 fork 源码，例如：
> `https://cdn.jsdelivr.net/gh/CodenameCrew/cne-flixel/flixel/FlxSprite.hx`（已验证可用）

## 6. 输出格式

### A. 对比表

至少包含列：解码入口 / 缓存结构 / CPU 缓冲生命周期 / GPU 纹理复用 / 并发策略 / 关键库版本差异 / 注释与代码组织风格

### B. 优点总结

每条格式：

- 优点名称
- 它在原引擎怎么实现的（附文件:行号）
- 【可移植】/【需改造】/【不适用】+ 理由
- 如果移植，预计对 SeiunEngine 的收益（内存/速度）

### C. 落地建议（到 SeiunEngine）

- 精确到 `文件:函数`
- 明确改动落在仓库代码还是 `.haxelib` 库代码
- 每个建议附风险：例如哪些路径需要 readback（pixels / framePixels / FlxTilemap / FlxBitmapText），哪些图能走 GPU-only；线程安全边界；版本升级影响

### D. 翻转 bug 结论

- 确认 flixel 快速路径的修复方案（例如条件里加 `_frame.angle == ANGLE_0 && !_frame.flipX && !_frame.flipY` 是否足够）
- 对比 cne-flixel / beihu235-flixel 是怎么处理 rotated 帧的

## 7. 硬性约束

1. 只读分析 + 输出报告；未经明确要求不许改动任何文件
2. 一切结论标依据：【已验证】/【推断】/【猜测】
3. `.haxelib` 共享库与引擎仓库代码必须分清，别把库代码当仓库代码
4. 不许建议无清单删除；删除建议必须附精确路径 + 影响
5. 如果要写代码示例，注释风格要像真人程序员（可以口语化），不要「AI 味」的官腔注释
