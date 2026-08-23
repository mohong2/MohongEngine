# SeiunEngine 更新日志 · Changelog

> 完整记录 2026年6月19日 至 8月23日 的所有改进、修复与突破
> A comprehensive record of every improvement, fix, and breakthrough from June 19 to August 23, 2026.

---

## 中文版

---

### 2026年6月19日

- 修复进入 Senpai 歌曲时前段 Note 消失的问题。
- 修复部分安卓设备在回放历史界面与游戏结束界面闪退的故障。
- 完全重构 Replay（回放）系统。
- 更新 Lua 库版本。
- 重构暂停界面，增加轻微 3D 视觉效果。
- 新增 Trace 控制台功能。
- 新增设置备份与恢复机制。

---

### 2026年7月18日（阶段性大更新）

#### 脚本与模组系统

- HScript 脚本已完善至可独立编写模组的程度，支持自定义图标等资源。
- Lua 兼容性进一步加强，API 处于早期阶段，允许修改（sub）state（未全覆盖测试，可能影响部分模组）。
- 提供两套 FPS 显示方案，可在模组配置中切换。
- 健康条（Health Bar）不再使用映射方式，改用 073 Bar.hx 原生创建，彻底修复显示异常。
- Lua 与 HScript 均可修改（sub）state（早期阶段）。

#### 编辑器与谱面

- 谱面编辑器支持导入/导出 Codename Engine（CNE）格式，保存功能整合为单一 Prompt 窗口。
- 修复编辑器内 Prompt 窗口在手机端缺少关闭按钮（X）的问题。
- 修复新版谱面编辑器中 Note 跑到对方判定区的问题。
- 修复旧版谱面编辑器中“保存并试玩”会强制写入谱面的问题（改为仅试玩不保存）。
- 重构新旧两个 ChartingState 的未保存警告逻辑，统一为退出/重载/试玩/预览前均弹窗确认，不再自动保存。
- 新增“谱面自动保存”设置（默认关闭），开启后定时自动备份。
- 修复谱面 0.6.3 转换时的兼容性问题（7.20 另有专项修复）。

#### 性能与渲染

- 优化大批量 Note（数万至数十万）的帧率与内存占用（图集帧缓存，提升加载速度）。
- 进一步优化同场景下大量 Note 的加载效率（缓存帧扫描结果，避免重复开销）。
- 清理 Note 构造时的自指环隐患（prevNote 不再自指）。
- 底层渲染微优化。
- 删除多线程更新（因 BUG 过多）。
- 修复 Note 从超慢速变超快速时长条异常变长的问题。

#### 界面与交互

- 重写设置界面（简化为单个类），支持模组通过 JSON + HScript + Lua 自定义菜单及动画。
- 重构模组加载流程：FreePlay 不再一股脑显示所有模组歌曲，改为 Tab 切换；主页面增加模组切换子状态（独立于 FreePlay）。
- 将 Combo 等图像生成优化，降低内存占用，避免粪谱卡顿。
- 暂停界面保留旧版（OldPauseSubState），可选用。
- 移植 PsychCamera 等 0.7.3 / 1.0.4 特有类。
- 修复 mustHitSection 影响玩家动作播放的问题。
- 修复练习模式准确率显示错误（仅为显示问题）。
- 修复 Replay 未记录手机端虚拟控件输入的问题。
- 修复只有一个模组时无法打开菜单的漏洞。

#### 兼容性与其他

- MusicBeat（sub）State 在电脑端增加手机虚拟按键空实现，便于 PC 支持触屏。
- 修复新版 Replay 记录缺失手机控件数据的问题。
- 修复安卓设备相关兼容性问题。

---

### 2026年7月19日

- 修复 Sparrow XML 帧中 rotated="true" 未正确应用角度旋转的问题。
- 增加全局模组列表选项。
- 安卓设置支持用户自定义文件存放类型，适配高版本 Android 的 data 目录限制。
- 修复人物无法正常翻转的问题。
- 优化歌曲进入速度。
- 代码清理（含移除冗余日志、恢复 CO 兼容性等）。

---

### 2026年7月20日

- 修复谱面 0.6.3 转换问题（独立修复）。

---

### 2026年7月21日

- 移除安卓激进优化设置。
- 修复所有场景均会加载 stage 图片的冗余问题。
- 修复兼容模式下 timeBar 的 cameras 为 null 导致崩溃的问题。

---

### 2026年7月31日（大量修复与改进）

#### 脚本与判定

- 修复 Botplay 下命中 Hurt / ignoreNote 音符无法触发 Lua / HScript 事件的问题。
- 修复未选择模组却错误加载其他模组 Main.hx 的渗透问题。
- 修复 pack.json 缺少 restart 字段导致崩溃的问题。
- 修复倒计时未结束歌曲提前开始的问题。
- 修复倒计时期间 Note 判定 ms 异常（现与正曲一致）。
- 新增“忽略循环报错脚本”设置（默认开启），并配套“脚本报错上限”（默认 50 次），持续报错的脚本将静默停用，避免刷屏。
- HScript 默认走错误上限逻辑，不再首次报错就弹窗关闭。

#### 编辑器与谱面

- 修复 MasterEditorMenu 选择模组后首次进入编辑器仍加载原版资源的问题。
- 彻底统一新旧编辑器的保存警告逻辑，不再自动保存。
- 新增“谱面自动保存”选项（默认关闭）。

#### 性能与 UI

- 再度优化大批量 Note 加载速度（缓存帧扫描、单次纹理加载）。
- KeyboardDisplay 全面软编码化（支持自定义键大小、间距、字体、颜色、透明度等），并提供 fullyCustom 开关及按压/释放/更新钩子。
- 游戏结束结算界面（Results）与回放历史界面（ScoreHistory）UI 现代化，采用弹性进场动画、鼠标悬停反馈、动态排版，修复文字重叠、截断等问题。
- 暂停界面提高透明度（黑底、亚克力、玻璃卡片均更透），参数可调。
- 优化回放系统（Replay）。

---

### 2026年8月18日

- 进一步优化 Note 性能：针对极限谱面（数十万级 Note）做了额外的加载与渲染加速，帧率更稳定。
- 修复 Vs slice 模组谱面转换时导致的崩溃问题：解决了该模组特定谱面在转换过程中因数据解析异常引发的程序崩溃。
- 修复若干已知问题：包括社区反馈的特定模组兼容性、偶发闪退及界面显示异常。
- 底层升级 SDL3：将原 SDL2 渲染后端迁移至 SDL3，提升跨平台图形性能及输入响应，为后续功能预留接口。
- 修复 Windows 图标错误：解决了因 Lime 构建图标注入错误导致的 Windows 可执行文件图标显示异常的问题。
- 补充制作人员名单：在相关界面中补全了参与本项目开发的贡献者信息。

---

### 2026年8月19日

- 修复 Replay 无法正常播放的问题，具体原因如下：
  1. ScoreHistorySubstate.playReplay() 直接调用 Song.loadFromJson() 时，未像 Freeplay 那样先切换至歌曲所属模组目录，导致 Paths.modsJson() 无法定位模组谱面，回退读取 assets/data/ 目录。
  2. 同步增强了 Replay 判定精度。
- 彻底移除了 GPUTextureManager 及“GPU纹理池化”设置，修复开启该选项后大图或全屏区域出现黑块的问题。
- 补全新版 Adobe Animate（spritemap1）角色支持。
- 修复 FlxAnimate 角色动画播放异常的问题。
- 修复 Lua playAnim 接口在特定场景下无法正确触发角色动画的问题。
- 修复 StageData 兼容性问题，解决部分模组舞台加载失败或显示错乱的现象。
- 修复相机缩放（camera zoom）相关逻辑，确保缩放行为与预期一致。
- 修复 healthBar.scale 读取异常，解决健康条在部分模组中缩放比例不正确的问题。

---

### 2026年8月20日 — SeiunEngine 0.7.3 兼容性全量修复

#### 新增 0.7.3 兼容层

- 新增 backend.Mods 兼容类（source/backend/Mods.hx），提供 0.7.3 模组 HScript 依赖的 Mods API：currentModDirectory、getGlobalMods、pushGlobalMods、getModDirectories、mergeAllTextsNamed、directoriesWithFile、getPack、parseList、updateModList、loadTopMod，全部委托给 Seiun 已有的 Paths 与 CoolUtil，避免重复维护。
- 修复 Lua 脚本 onCreate 期间无法被其他脚本回调注册的问题（source/script/lua/FunkinLua.hx）：现在 call('onCreate') 之前会把当前 Lua 脚本临时加入 PlayState.instance.luaArray，onCreate 结束后再移除。该修复解决了 Pause.lua 的 onCreate 调用 parseJson 时为 nil 的根因，同时修复了 jsonReader.hx 的 createGlobalCallback 注册不到当前脚本的问题。

#### 暂停菜单 / CustomSubstate

- CustomSubstate 的 Lua 全局改为安全值（source/script/lua/FunkinLua.hx）：Lua 侧 customSubstate 不再直接存放 CustomSubstate 实例，改为子状态名字符串（如 "NEW_pause_menu"）；HScript 侧仍保留真实 CustomSubstate 实例。消除了 "Convert: Haxe value ... not supported" 报错。

#### 版本 / 变量兼容

- version 全局跟随兼容模式（source/script/lua/FunkinLua.hx、source/script/hscript/HScript.hx）：version 现在等于 CompatEngine.current()，0.6.3 / 0.7.3 / 1.0.4 模式会返回对应版本号。
- opponentVocals 重命名（source/states/PlayState.hx、source/editors/ChartingState.hx）：原 vocalsOpponent 全部重命名为 0.7.3 的 opponentVocals。
- 新增 0.7.3 属性：PlayState.inst 指向 FlxG.sound.music 的 instrumental 别名；PlayState.stageUI 支持 stage json 的 stageUI 字段；PlayState.iconsAnimations 默认 true，供 iconShake 等脚本读取；StageData.StageFile 增加可选 stageUI 字段。
- noteSkinPostfix / splashSkinPostfix（source/script/lua/FunkinLua.hx）不再硬编码为空，改为读取 Note.getNoteSkinPostfix() 和 NoteSplash.getSplashSkinPostfix()。

#### 缺失回调补全

- 成就系统完整兼容（source/Achievements.hx）：保留旧版 Seiun 成就 API（achievementsStuff、achievementsMap、henchmenDeath、loadAchievements、unlockAchievement、isAchievementUnlocked、getAchievementIndex、AchievementObject、AttachedAchievement）；移植 0.7.3 成就系统（Achievement typedef、achievements、variables、achievementsUnlocked、getScore、setScore、addScore、unlock、isUnlocked、startPopup、createAchievement、reloadList、loadAchievementJson）；新增 Lua 回调（getAchievementScore、setAchievementScore、addAchievementScore、unlockAchievement、isAchievementUnlocked、achievementExists）。
- Discord 兼容别名（source/Discord.hx）：新增 clientID、_defaultID 静态变量；source/script/lua/FunkinLua.hx 新增 Lua 回调（changeDiscordPresence、changeDiscordClientID）。

#### 调用顺序修复

- PlayState 的 onCreatePost 顺序对齐 0.7.3（source/states/PlayState.hx）：Lua onCreatePost 在 super.create() 之前调用一次；HScript onCreatePost 由 super.create() 内部调用一次；删除原先重复的 callOnScripts('onCreatePost')，避免 HScript 执行两次。

#### 哨兵值兼容

- Function_Stop 等常量改为 0.7.3 字符串哨兵（source/script/lua/FunkinLua.hx、source/psychlua/LuaUtils.hx、source/editors/EditorLua.hx）：Function_Stop、Function_Continue、Function_StopLua、Function_StopHScript、Function_StopAll 全部改为 "##PSYCHLUA_*" 字符串，与 0.7.3 / 1.0.4 一致。

#### 控制器 / 输入兼容

- keyboardJustPressed 键盘 + 手柄回退（source/script/lua/FunkinLua.hx）：ENTER、SPACE、Z 键盘没按时回退到 Controls.ACCEPT；ESCAPE、BACKSPACE 回退到 Controls.BACK；W、UP、S、DOWN、A、LEFT、D、RIGHT 回退到 UI_*_P。keyboardPressed、keyboardReleased 也补了对应的按住/松开回退。
- keyJustPressed / keyPressed / keyReleased 补 default（source/script/lua/FunkinLua.hx）：未匹配的名字会走 controls.justPressed / pressed / justReleased，与 0.7.3 ExtraFunctions 行为一致。

#### 版本显示调整

- 主菜单 PE 版本显示（source/states/MainMenuState.hx）：显示 "Psych Engine v0.6.3+0.7.3+1.0.4 (Active: 当前兼容版本)"，所有版本文字改为右对齐，贴住屏幕右边缘，避免长文本溢出。
- 游戏内左下角 PE 版本显示（source/states/PlayState.hx）：左下角版本文字中的 PE 版本改为 CompatEngine.current()，跟随当前激活的兼容模式显示。

---

### 2026年8月21日

- 修复 Replay 若干遗留问题（回放难度锁定、回放数据完整性等）。
- 移除 OSU 尾判设置选项（gameplay 选项、ClientPrefs 与回放/判定相关代码一并清理）。

---

### 2026年8月22日（UI 架构统一重构 + 设置弹窗）

#### 通用 UI 基础（新增 source/backend/UIScreen.hx）

- 新增 UIScreen 工具类，统一各现代界面的玻璃/亚克力 UI 实现：
  - createScreenCamera()：创建独立的静态屏幕空间相机，子状态 UI 不再受 PlayState / Freeplay 相机滚动、缩放与 follow 影响，鼠标命中检测与界面位置稳定。
  - applyBlur() / clearBlur()：对底层游戏/菜单相机施加/移除真实 OpenFL 高斯模糊，受 ClientPrefs.data.shaders 开关控制。
  - makeGlassCard()：统一样式的半透明圆角玻璃卡片（微 1px 白描边、可自定义填充色）。
- 原各子状态手动创建的相机（Results / ScoreHistory / Pause / 设置弹窗）全部迁移到 UIScreen.createScreenCamera()。

#### 暂停界面（source/substates/PauseSubState.hx）

- 改用独立屏幕空间相机 + 背景高斯模糊（半径 8），暂停时背景更柔和。
- 修复 slideGroup 透视效果下鼠标命中偏移：命中检测现在考虑 scale / origin 变换（之前只补偿 x/y 偏移，缩放后按钮点击区域错位）。
- 微调 3D 视差参数（偏移 16/10 → 12/8，缩放系数 0.008 → 0.005）。
- 恢复暂停（resume）与 destroy 时还原背景相机滤镜，避免模糊残留。

#### 设置界面（source/options/OptionsState.hx、新增 source/options/OptionPopupSubState.hx）

- 新增模态弹窗 OptionPopupSubState：
  - 字符串选项：回车/点击打开下拉列表，方向键或鼠标悬停移动高亮，回车/点击确认，ESC/返回取消。
  - 数值选项：回车/点击打开滑条（Slider），左右键或鼠标拖动改变临时值，回车确认，ESC/返回取消。
  - 弹窗是真正的 FlxSubState，打开期间父设置视图暂停，鼠标与键盘输入不再互相争抢；带首帧输入跳过保护（避免打开弹窗的同一帧回车/点击立即确认或取消）。
  - 玻璃卡片面板 + 弹性进出动画，点击面板外区域可直接取消。
- 类别预览模式（updateCategoryPreview）暂时禁用并保留接口，等后续重新启用。
- 鼠标悬停/滚轮逻辑改为仅在未使用键盘时生效（keyboardUsed 判定），修复键鼠混用时选择冲突。

#### 结算界面（source/substates/PlayStateResultsSubstate.hx）

- 新增顶部“英雄卡”（Hero Card）：分数、准确率、评级、最大连击以大字号分区展示，带错峰上浮动画。
- 结算期间冻结底层 PlayState 更新（persistentUpdate = false）并施加背景模糊（半径 10），阻止结算时游戏相机继续平移/缩放；关闭时完整恢复。
- 命中条形图支持 Marvelous 评级：开启 magnificent/marvelousRatings 时 Marvelous 作为独立统计组显示（颜色金色、列在最前），Sick/Good/Bad/Shit/Miss 分布条按实际数量动态布局（行数 > 5 时自动压缩行高与间距）。
- 鼠标命中检测改用 getScreenBounds（考虑缩放与原点），悬停/点击热区不再错位。
- 面板统一改用 UIScreen.makeGlassCard；评分图标移至英雄卡右侧垂直居中。

#### 回放历史界面（source/substates/ScoreHistorySubstate.hx）

- 列表行重设计：行高 40 → 58，每行新增副文本（SubText）、判定图标与悬停行背景，悬停即选中，鼠标操作更直观。
- 双击行播放回放（400ms 内第二次点击同一行）；无回放数据时抖动详情卡提示。
- 删除改为两次 RESET 确认（2.5 秒内第二次按下 RESET 才执行删除，ESC / 超时取消），新增 deleteConfirm 多语言文案。
- 界面整体使用独立屏幕相机 + 背景模糊（半径 9），开启 shaders 时背景透明度自动降至 0.68。
- 修复删除条目后列表与选中状态刷新。

#### Trace 系统（source/mohong/TraceConsole.hx、source/mohong/TraceManager.hx）

- TraceManager 控制台输出改为默认关闭：Windows 上 Trace Console 为显式开关（启动时不再静默向终端刷屏），其他桌面 sys 目标保留原有 stdout 行为。
- 新增控制台可用性检测（setConsoleAvailable / isConsoleAvailable，Windows 经 Windows.hasConsole 探测），无输出目标时跳过格式化开销。
- 新增控制台突发限流（consoleRateLimit 默认 200 条 / consoleRateWindow 0.1 秒），超出部分仍记录环形缓冲但不再刷屏；已有 TraceConsole 监听器时不再重复输出。
- Main.hx / TitleState.hx：Windows 桌面在偏好加载完成后应用 Trace Console 开关（TraceManager.syncWithPrefs）。

#### 谱面与 Note（source/Note.hx、source/states/PlayState.hx）

- 0.6.3 自定义 Note 兼容：EventNote / PreloadedChartNote 新增 noteSplashTexture / noteSplashHue / noteSplashSat / noteSplashBrt 字段，Lua 可对单音符设置自定义溅射皮肤与颜色；仅在 Lua 显式设置时覆盖（null 表示未设置），未设置时保持 noteType setter 算出的轨道色溅射，避免普通 Note 被覆盖成全零颜色。写入顺序放在 noteType setter 之后，避免 setter 覆盖自定义溅射颜色。
- 修复 isGFSide 判定：旧版谱面（isNewVer = false）中 GF 场景音符的 isGF 计算错误（gfSec && rawData < noteAmmo 在 playOpponent 反转后判断失误），改为 isGFSide = gfSec && (gottaHitNote == mustHit)。
- 修复 0.7.3 / 1.0.4 兼容模式血条图标层级：073/104 的 Bar 是 FlxSpriteGroup，部分角色切换后图标会被血条背景盖住；新增 forceHealthIconsAboveBar()，在构建与角色切换（boyfriendName / dadName 变化）时把图标移到 healthBar 之后，确保图标始终在血条上层。

#### HScript 与其他

- Config.hx：导入白名单格式简化（去掉 #if !DOCUMENTATION 与 MODCHARTING_FEATURES 条件包裹），统一列出允许 import 的包前缀。
- 多语言：ScoreHistorySubstate 新增 deleteConfirm 文案，instructions 更新为“上/下/悬停选择、ENTER/双击播放、RESET×2 删除”。

---

### 2026年8月23日

- 修复安卓 Pad-Custom 按键自定义拖拽粘手/脱不掉的问题：将全局单点拖动状态重构为按触点（touch point）独立跟踪，支持多指同时拖动多个按键；只有发起拖动的触点释放才结束拖动，其他触点不再抢占。
- 修复拖动时按键可被拖出屏幕外导致丢失的问题：拖动与读取旧存档位置时均限制在屏幕范围内。
- 修复切换控件模式/Reset/退出时未清理拖动状态的问题，并增加异常触点/失效拖动残留的自动清理。
- AndroidControls 读取/写入自定义按钮位置时增加空值与长度兼容，避免旧存档或按钮数量变化导致异常；切换控件时清理残留的 virtualPad/hitbox 引用。

---

### 鸣谢

感谢所有参与测试的人员，你们的宝贵反馈是推动引擎不断完善的重要力量。

---

---

## English Version

---

### June 19, 2026

- Fixed the issue where notes disappeared during the first section of the Senpai song.
- Fixed a crash on some Android devices when entering the Replay History or Game Over screens.
- Completely rewrote the Replay system.
- Updated Lua library to a newer version.
- Redesigned the Pause menu with a subtle 3D effect.
- Added a Trace console for debugging.
- Introduced settings backup and restore functionality.

---

### July 18, 2026 — Major Milestone Update

#### Scripting & Mod System

- HScript is now mature enough for building full-fledged mods, supporting custom icons and assets.
- Lua compatibility has been further improved (API still early-stage); both Lua and HScript can now modify (sub)states (not fully tested, may affect some mods).
- Added two FPS display options, configurable per mod.
- Health bar no longer uses mapping; now built natively with 073 Bar.hx, completely fixing display glitches.
- Lua and HScript both allow modifying (sub)state (early stage).

#### Editor & Charting

- Chart editor now supports importing/exporting Codename Engine (CNE) format, with save actions consolidated into a single Prompt window.
- Fixed missing close button (X) on Prompt windows for mobile devices.
- Fixed notes appearing on the opponent's side in the new chart editor.
- Fixed "Save and Playtest" in the old chart editor forcibly writing to disk (now it only playtests, no auto-save).
- Unified unsaved warning logic across both chart editors — now prompts before exit, reload, playtest, or preview; no more sneaky auto-saves.
- Added a "Chart Autosave" setting (off by default). When enabled, it creates timed backups.
- Fixed chart conversion issues specific to 0.6.3 format (separate fix on July 20).

#### Performance & Rendering

- Optimized frame rate and memory usage for charts with tens of thousands of notes (using atlas frame caching and faster loading).
- Further improved loading speed for massive note counts (cached frame scan results, single texture load per note).
- Fixed a self-referencing ring hazard in Note constructor (prevNote no longer points to itself).
- Minor rendering optimizations across the board.
- Removed multi-threading update due to persistent bugs.
- Fixed unusually long sustain notes when speed transitions from extremely slow to extremely fast.

#### UI & Interaction

- Rewrote the Settings menu (simplified to a single class), now allows mods to customize menus and animations via JSON + HScript + Lua.
- Overhauled mod loading: FreePlay now shows mods as tabs instead of dumping all songs; added a dedicated mod-switching substate (independent from FreePlay).
- Optimized combo sprite generation to reduce memory usage, preventing lag on messy charts.
- Kept the old Pause menu (OldPauseSubState) as an option.
- Backported PsychCamera and other classes from 0.7.3/1.0.4.
- Fixed mustHitSection blocking player character animations.
- Fixed practice mode accuracy display (display-only issue, no cheating).
- Fixed Replay not recording virtual controls on mobile, resulting in empty replays.
- Fixed menu not opening when only one mod is present.

#### Compatibility & Misc

- Added empty implementations of mobile virtual keys to MusicBeat(sub)State on PC builds, making PC support touchscreen-friendly.
- Fixed various Android-specific compatibility issues.

---

### July 19, 2026

- Fixed rotated="true" not correctly applying frame rotation in Sparrow XML animations.
- Added a global mod list option.
- Android: allowed users to choose custom file storage locations, adapting to Android's data directory restrictions on newer versions.
- Fixed character flipping not working correctly.
- Improved song loading speed.
- Code cleanup (removed HIM-related leftovers, restored CO compatibility, etc.).

---

### July 20, 2026

- Fixed chart conversion issues specific to 0.6.3 format (separate fix).

---

### July 21, 2026

- Removed the "Aggressive Android Optimization" setting.
- Fixed stage images being loaded in every scene unnecessarily.
- Fixed a crash when timeBar.cameras became null in compatibility mode.

---

### July 31, 2026 — Bulk Fixes & Enhancements

#### Scripting & Judgment

- Fixed Botplay not triggering Lua/HScript events for Hurt/ignoreNote hits.
- Fixed mod Main.hx leaking into other mods when no mod was explicitly selected.
- Fixed crash when pack.json lacked the restart field.
- Fixed songs starting before the countdown finished.
- Fixed note judgment ms being off during countdown (now consistent with normal play).
- Added "Ignore looping error scripts" setting (on by default) with a "Script error limit" (default 50). Scripts that repeatedly error will be silently disabled to prevent spam.
- HScript now follows the same error limit logic instead of showing a popup on first error.

#### Editor & Charting

- Fixed MasterEditorMenu loading vanilla resources instead of the selected mod's when first entering an editor.
- Unified unsaved warning logic across all editors (no more auto-saves).
- Added "Chart Autosave" toggle (off by default).

#### Performance & UI

- Even faster loading for massive note counts (cached frame scans, single texture load).
- KeyboardDisplay fully soft-coded: customizable key size, spacing, font, colors, transparency, etc., plus a fullyCustom mode with press/release/update hooks.
- Modernized Results and ScoreHistory screens with elastic (backOut) entrance animations, hover effects, and dynamic text layout — fixed overlapping and clipping issues.
- Pause menu now has higher transparency (black overlay, acrylic layer, glass cards are more see-through), with adjustable constants (BG_ALPHA, OVERLAY_ALPHA, etc.).
- Replay system further optimized.

---

### August 18, 2026

- Further note performance improvements: extra loading and rendering acceleration for extreme charts (hundreds of thousands of notes).
- Fixed a crash during chart conversion for the Vs Slice mod: resolves data parsing errors that caused program termination.
- Fixed various reported issues: mod compatibility, occasional crashes, and UI display glitches.
- Underlying upgrade to SDL3: migrated the render backend from SDL2 to SDL3, enhancing cross-platform graphics performance and input response, laying groundwork for future features.
- Fixed Windows icon error: resolved an issue where the Lime build process incorrectly injected the icon, causing display issues for the Windows executable.
- Added credits: supplementary contributor information has been added to the relevant in-game screens.

---

### August 19, 2026

- Fixed Replay playback failure. The specific causes are as follows:
  1. ScoreHistorySubstate.playReplay() invoked Song.loadFromJson() directly without switching to the mod directory of the song (unlike Freeplay), causing Paths.modsJson() to fail locating the mod chart and falling back to assets/data/.
  2. Replay judgment accuracy has been enhanced.
- Completely removed GPUTextureManager and the "GPU texture pooling" setting, fixing the issue where large images or full-screen areas would display as black blocks when the option was enabled.
- Added support for the new Adobe Animate (spritemap1) character format.
- Fixed FlxAnimate character animation playback issues.
- Fixed Lua playAnim interface failing to trigger character animations correctly in certain scenarios.
- Fixed StageData compatibility issues that caused mod stage loading failures or display errors.
- Fixed camera zoom logic to ensure scaling behavior matches expectations.
- Fixed healthBar.scale reading errors, resolving incorrect health bar scaling in certain mods.

---

### August 20, 2026 — SeiunEngine 0.7.3 Full Compatibility Patch

#### New 0.7.3 Compatibility Layer

- Added backend.Mods compatibility class (source/backend/Mods.hx), providing 0.7.3 mod HScript-dependent Mods APIs: currentModDirectory, getGlobalMods, pushGlobalMods, getModDirectories, mergeAllTextsNamed, directoriesWithFile, getPack, parseList, updateModList, loadTopMod. All delegated to Seiun's existing Paths and CoolUtil to avoid duplicate maintenance.
- Fixed Lua script onCreate being unable to register callbacks from other scripts (source/script/lua/FunkinLua.hx): the current Lua script is now temporarily added to PlayState.instance.luaArray before call('onCreate'), and removed after onCreate completes. This fixes the root cause of Pause.lua's parseJson returning nil during onCreate, and also fixes jsonReader.hx's createGlobalCallback failing to register with the current script.

#### Pause Menu / CustomSubstate

- CustomSubstate Lua global changed to safe value (source/script/lua/FunkinLua.hx): customSubstate on the Lua side no longer stores CustomSubstate instances directly; it now stores the substate name as a string (e.g., "NEW_pause_menu"). HScript side retains the actual CustomSubstate instance. Eliminates "Convert: Haxe value ... not supported" errors.

#### Version / Variable Compatibility

- version global now follows compatibility mode (source/script/lua/FunkinLua.hx, source/script/hscript/HScript.hx): version now equals CompatEngine.current() — 0.6.3 / 0.7.3 / 1.0.4 modes return the corresponding version string.
- opponentVocals renamed (source/states/PlayState.hx, source/editors/ChartingState.hx): all vocalsOpponent references renamed to opponentVocals to match 0.7.3.
- Added 0.7.3 properties: PlayState.inst as an instrumental alias pointing to FlxG.sound.music; PlayState.stageUI supporting the stageUI field from stage json; PlayState.iconsAnimations defaults to true for scripts like iconShake to read; StageData.StageFile now has an optional stageUI field.
- noteSkinPostfix / splashSkinPostfix (source/script/lua/FunkinLua.hx) no longer hardcoded to empty strings; now read from Note.getNoteSkinPostfix() and NoteSplash.getSplashSkinPostfix().

#### Missing Callback Completions

- Achievements system fully compatible (source/Achievements.hx): retained legacy Seiun achievement APIs (achievementsStuff, achievementsMap, henchmenDeath, loadAchievements, unlockAchievement, isAchievementUnlocked, getAchievementIndex, AchievementObject, AttachedAchievement); ported 0.7.3 achievement system (Achievement typedef, achievements, variables, achievementsUnlocked, getScore, setScore, addScore, unlock, isUnlocked, startPopup, createAchievement, reloadList, loadAchievementJson); added Lua callbacks (getAchievementScore, setAchievementScore, addAchievementScore, unlockAchievement, isAchievementUnlocked, achievementExists).
- Discord compatibility aliases (source/Discord.hx): added clientID and _defaultID static variables; source/script/lua/FunkinLua.hx added Lua callbacks (changeDiscordPresence, changeDiscordClientID).

#### Call Order Fixes

- PlayState onCreatePost order aligned with 0.7.3 (source/states/PlayState.hx): Lua onCreatePost called once before super.create(); HScript onCreatePost called once from within super.create(); removed the duplicate callOnScripts('onCreatePost') to prevent HScript from executing twice.

#### Sentinel Value Compatibility

- Function_Stop constants changed to 0.7.3 string sentinels (source/script/lua/FunkinLua.hx, source/psychlua/LuaUtils.hx, source/editors/EditorLua.hx): Function_Stop, Function_Continue, Function_StopLua, Function_StopHScript, Function_StopAll all changed to "##PSYCHLUA_*" strings, consistent with 0.7.3 / 1.0.4.

#### Controller / Input Compatibility

- keyboardJustPressed keyboard + gamepad fallback (source/script/lua/FunkinLua.hx): ENTER, SPACE, Z fall back to Controls.ACCEPT when keyboard not pressed; ESCAPE, BACKSPACE fall back to Controls.BACK; W, UP, S, DOWN, A, LEFT, D, RIGHT fall back to UI_*_P. keyboardPressed and keyboardReleased also have corresponding hold/release fallbacks.
- keyJustPressed / keyPressed / keyReleased default fallback (source/script/lua/FunkinLua.hx): unmatched names now fall through to controls.justPressed / pressed / justReleased, matching 0.7.3 ExtraFunctions behavior.

#### Version Display Adjustments

- Main menu PE version display (source/states/MainMenuState.hx): displays "Psych Engine v0.6.3+0.7.3+1.0.4 (Active: current compatibility version)"; all version text right-aligned against the screen edge to prevent overflow.
- In-game bottom-left PE version display (source/states/PlayState.hx): PE version in bottom-left corner changed to CompatEngine.current(), following the currently active compatibility mode.

---

### August 21, 2026

- Fixed several remaining issues with Replay (replay difficulty lock, replay data integrity, etc.).
- Removed the OSU tail judgment setting option (gameplay options, ClientPrefs and related replay/judgment code cleaned up).

---

### August 22, 2026 — Unified UI Architecture + Settings Popups

#### Shared UI Foundation (new source/backend/UIScreen.hx)

- Added UIScreen helper class unifying glass/acrylic UI across modern screens:
  - createScreenCamera(): creates a dedicated static screen-space camera, so substate UI is no longer shifted by PlayState/Freeplay camera scroll, zoom and follow; mouse hit testing stays accurate.
  - applyBlur() / clearBlur(): applies/removes a real OpenFL Gaussian-style blur on the underlying game/menu camera, gated by ClientPrefs.data.shaders.
  - makeGlassCard(): unified semi-transparent rounded glass card (subtle 1px white border, customizable fill).
- All hand-rolled cameras previously created by Results / ScoreHistory / Pause / settings popup now migrated to UIScreen.createScreenCamera().

#### Pause Menu (source/substates/PauseSubState.hx)

- Dedicated static screen-space camera + background Gaussian blur (radius 8) for a softer paused backdrop.
- Fixed mouse hit offset under the slideGroup perspective effect: hit testing now accounts for scale/origin transforms (previously only x/y offsets were compensated, so scaled button hitboxes were misaligned).
- Tuned 3D parallax parameters (offset 16/10 → 12/8, scale factor 0.008 → 0.005).
- Backdrop camera filters are restored on resume and destroy to avoid leftover blur.

#### Settings Menu (source/options/OptionsState.hx, new source/options/OptionPopupSubState.hx)

- New modal OptionPopupSubState:
  - String options: Enter/click opens a dropdown list; arrows or mouse hover move the highlight; Enter/click confirms; ESC/Back cancels.
  - Numeric options: Enter/click opens a slider; arrows or mouse drag change a temporary value; Enter confirms; ESC/Back cancels.
  - The popup is a real FlxSubState, so the parent settings view is paused while it is open — mouse and keyboard no longer fight; first-frame input skip prevents the triggering Enter/click from immediately confirming or cancelling.
  - Glass card panel with springy entrance animations; clicking outside the panel cancels.
- Category preview mode (updateCategoryPreview) temporarily disabled, interface kept for later re-enable.
- Mouse hover/wheel logic now only applies when no keyboard input is used (keyboardUsed check), fixing conflicts under mixed input.

#### Results Screen (source/substates/PlayStateResultsSubstate.hx)

- New top "Hero Card": score, accuracy, grade and max combo shown in large type with staggered lift-in animations.
- While results are open the underlying PlayState update is frozen (persistentUpdate = false) and a blur (radius 10) is applied, stopping the game camera from panning/zooming behind the UI; fully restored on close.
- Hit bar chart now supports Marvelous ratings: when enabled, Marvelous is its own gold-colored bucket at the front; Sick/Good/Bad/Shit/Miss bars lay out dynamically (row height/spacing auto-compresses when more than 5 rows).
- Mouse hit testing now uses getScreenBounds (honors scale/origin) so hover/click hotzones stay accurate.
- Panels switched to UIScreen.makeGlassCard; the grade icon moved to the hero card, vertically centered on the right.

#### Score History Screen (source/substates/ScoreHistorySubstate.hx)

- List rows redesigned: row height 40 → 58, each row now has subtitle text, a judgment icon and a hover row background; hovering selects the row.
- Double-click a row to play its replay (second click on the same row within 400ms); the detail card shakes if no replay data exists.
- Deletion now requires two RESET presses (second press within 2.5s actually deletes; ESC/timeout cancels), with a new deleteConfirm localization string.
- The whole screen uses a dedicated static camera + backdrop blur (radius 9); backdrop alpha auto-drops to 0.68 when shaders are enabled.
- Fixed list/selection state refresh after deleting an entry.

#### Trace System (source/mohong/TraceConsole.hx, source/mohong/TraceManager.hx)

- Console output is now off by default: on Windows the Trace Console is an explicit opt-in (no more silent console flooding when launched from a terminal); other desktop sys targets keep the historic stdout logging.
- Added console availability detection (setConsoleAvailable / isConsoleAvailable; Windows probes via Windows.hasConsole) to skip formatting when no output target is attached.
- Added console burst rate limiting (consoleRateLimit default 200 lines per consoleRateWindow 0.1s); excess lines stay in the ring buffer but are not flushed; output is not duplicated when a TraceConsole listener is live.
- Main.hx / TitleState.hx: Windows desktop applies the Trace Console preference after prefs are loaded (TraceManager.syncWithPrefs).

#### Charting & Notes (source/Note.hx, source/states/PlayState.hx)

- 0.6.3 custom note compatibility: EventNote / PreloadedChartNote gained noteSplashTexture / noteSplashHue / noteSplashSat / noteSplashBrt so Lua can set per-note splash skins and colors; only explicit Lua writes override (null = unset), otherwise the noteType setter's lane-color splash is kept — normal notes are no longer overridden to all-zero colors. Written after the noteType setter so the setter cannot stomp custom splashes.
- Fixed isGFSide detection: on old-format charts (isNewVer = false) isGF for GF-section notes was computed wrong (gfSec && rawData < noteAmmo broke after playOpponent reversal); now uses isGFSide = gfSec && (gottaHitNote == mustHit).
- Fixed health icon layering under the 0.7.3/1.0.4 compatibility Bar (a FlxSpriteGroup): custom icons could be covered by the bar background after character swaps. Added forceHealthIconsAboveBar(), re-inserting the icons right after healthBar on build and on boyfriendName/dadName changes.

#### HScript & Misc

- Config.hx: import whitelist simplified (dropped the #if !DOCUMENTATION and MODCHARTING_FEATURES conditional wrappers), allowed import packages listed uniformly.
- Localization: ScoreHistorySubstate gained deleteConfirm, and instructions updated to "UP/DOWN/HOVER: Select | ENTER/DOUBLE CLICK: Play | RESET x2: Delete | ESC: Back".

---

### August 23, 2026

- Fixed Android Pad-Custom key dragging getting stuck to a finger / unable to drop: rewrote the global single-button drag state into per-touch tracking (`Map<touch ID, FlxButton>`), so multiple buttons can be dragged simultaneously with multiple fingers, and a drag only ends when the touch that started it is released.
- Fixed buttons being draggable off screen: drag and saved-position loading are now clamped to the visible screen bounds.
- Fixed drag state not being cleared when switching control modes, Reset, or exiting; added stale-touch cleanup and safer handling of old/incomplete saved button arrays.
- Cleaned up leftover virtual pad / hitbox references when switching controls.

---

### Acknowledgments

A huge thank you to all testers — your feedback has been invaluable in shaping SeiunEngine into what it is today.

---

*本日志覆盖 SeiunEngine 自 6.19 至 8.23 全部主要变动。*
*This changelog covers all significant changes from June 19 to August 23, 2026.*
