# SeiunEngine 脚本系统文档

## 目录

1. [概述](#1-概述)
2. [系统架构](#2-系统架构)
3. [Lua 脚本系统](#3-lua-脚本系统)
4. [HScript 脚本系统](#4-hscript-脚本系统)
5. [ModState & ModSubState](#5-modstate--modsubstate)
6. [辅助类](#6-辅助类)
7. [Lua API（从 HScript 管理 Lua）](#7-lua-api从-hscript-管理-lua)
8. [脚本事件回调完整列表](#8-脚本事件回调完整列表)
9. [脚本加载路径](#9-脚本加载路径)
10. [常见用法示例](#10-常见用法示例)
11. [平台相关注意事项](#11-平台相关注意事项)
12. [故障排除](#12-故障排除)

---

## 1. 概述

SeiunEngine 使用**双引擎脚本架构**，同时支持 **Lua** 和 **HScript (Haxe Script)** 两种脚本语言。开发者可以选择任意一种语言编写 MOD 逻辑，两种语言之间可以互相调用。

- **Lua**: 使用 `llua` 绑定，完整的 Lua 5.x 解释器，适合动态脚本编写
- **HScript**: 使用 `crowplexus-hscript`，原生的 Haxe 脚本解释器，语法接近 Haxe

### 版本信息

| 组件              | 版本             |
| ----------------- | ---------------- |
| Lua 支持版本      | 0.63.1fix-2      |
| HScript 支持版本  | 0.2.0            |
| Psych Engine 版本 | 见 MainMenuState |

### 编译开关

两个系统均由编译标志控制：

```hxml
#if LUA_ALLOWED    // 启用 Lua 支持
#if HSCRIPT_ALLOWED // 启用 HScript 支持
```

---

## 2. 系统架构

### 核心文件结构

```
source/script/
├── hscript/                        # HScript 系统
│   ├── HScript.hx                  # 主要 HScript 引擎 (568 行)
│   ├── LuaApi.hx                   # 从 HScript 桥接 Lua 的 API (459 行)
│   └── import.hx                   # 导入辅助
├── lua/                            # Lua 脚本系统
│   ├── FunkinLua.hx                # 主要 Lua 引擎 (3839 行)
│   ├── DebugLuaText.hx             # 屏幕调试文本类
│   ├── ModchartSprite.hx           # 可脚本化 Sprite 类
│   ├── ModchartText.hx             # 可脚本化 Text 类
│   └── import.hx                   # 导入辅助
└── FunkinText.hx                   # FNF 风格文本组件
```

### 状态基类中的脚本管理

所有状态（State）和子状态（SubState）继承自 `MusicBeatState` 和 `MusicBeatSubstate`，基类中管理两个并行的脚本数组：

```haxe
// MusicBeatState / MusicBeatSubstate 中的字段
var luaArray:Array<FunkinLua>;     // Lua 脚本实例数组
var hscriptArray:Array<HScript>;   // HScript 实例数组
```

### 脚本初始化顺序

在 `create()` 方法中，脚本按以下顺序初始化：

```
MusicBeatState.create()
├── super.create()
├── initHScripts()          // 1. 加载 HScript 文件
├── setOnHscript(...)       // 2. 设置 HScript 变量
└── callOnHscript(          // 3. 触发 HScript 回调
      'onCreatePost', [])
```

对于 `ModState` 和 `ModSubState`，额外处理 Lua：

```
ModState.create()
├── super.create()          // 自动执行 initHScripts()
├── initLuaScripts()        // 额外：加载 Lua 文件
├── setOnLuas(...)          // 设置 Lua 变量
├── callOnLuas(             // 触发 Lua 回调
      'onCreatePost', [])
└── setOnHscript('data', this.data)
```

### 回调调用链

**MusicBeatState / MusicBeatSubstate 中的调用：**

```
MusicBeatState.callOnLuas(func, args)
└── 遍历 luaArray，依次调用每个脚本
    ├── Function_StopLua / Function_StopAll → 中断
    └── Function_Stop / Function_Continue → 继续

MusicBeatState.callOnHscript(func, args)
├── HScript.callOnGlobalScript()  // 全局脚本优先
└── 遍历 hscriptArray，依次调用
    └── Function_StopHScript → 中断
```

**PlayState 中的调用（重写版）：**

```
PlayState.callOnScripts(func, args)          ← PlayState 自带方法
├── callOnLuas(func, args)                   ← 重写自 MusicBeatState
│   └── Function_StopLua / Function_StopAll → 中断 Lua
├── 如果 Lua 返回 Function_Continue 或 null
│   └── callOnHScript(func, args)            ← PlayState 自带方法
│       └── Function_StopHScript → 中断 HScript
└── 返回最终结果
```

**返回值优先级规则：**
- Lua 返回 `Function_Continue` (0) → HScript 继续执行
- Lua 返回 `Function_Stop` (1) → 仅当前脚本停止，其余继续
- Lua 返回 `Function_StopLua` (2) → 停止所有 Lua，HScript 继续
- Lua 返回 `Function_StopHScript` (3) → Lua 继续，HScript 停止
- Lua 返回 `Function_StopAll` (4) → 停止所有脚本

> **重要**: PlayState 的 `callOnScripts` 默认会先调用 Lua，如果 Lua 返回 `Function_Continue` 则调用 HScript。但 `goodNoteHit` 等回调手动分别调用了 `callOnLuas` 和 `callOnHScript`，具有不同的参数签名——详见第 8 章。

---

## 3. Lua 脚本系统

### 3.1 FunkinLua 类

`FunkinLua` 是 Lua 脚本的核心引擎（位于 `source/script/lua/FunkinLua.hx`）。

**主要功能**:
- 创建和管理 Lua 解释器状态
- 注册 Lua 全局函数（223+ 个回调）
- 管理脚本的调用和变量设置
- 提供 Lua 与 Haxe 之间的双向桥接

### 3.2 Lua 脚本文件格式

Lua 脚本使用标准的 `.lua` 扩展名，遵循标准 Lua 5.x 语法。

**支持的函数返回值**:
```lua
Function_Continue    = 0  -- 继续执行（默认）
Function_Stop        = 1  -- 停止当前的执行流程
Function_StopLua     = 2  -- 停止所有 Lua 脚本
Function_StopHScript = 3  -- 停止 HScript（从 Lua 中使用无效）
Function_StopAll     = 4  -- 停止所有脚本
```

### 3.3 Lua 可用的预定义变量

#### 歌曲/周信息（PlayState 激活时可用）

| 变量名           | 类型   | 描述               |
| ---------------- | ------ | ------------------ |
| `curBpm`         | Float  | 当前 BPM           |
| `bpm`            | Float  | 歌曲 BPM           |
| `scrollSpeed`    | Float  | 滚动速度           |
| `crochet`        | Float  | 节拍长度（毫秒）   |
| `stepCrochet`    | Float  | 步进长度（毫秒）   |
| `songLength`     | Float  | 歌曲长度（毫秒）   |
| `songName`       | String | 歌曲名称           |
| `songPath`       | String | 格式化后的歌曲路径 |
| `curStage`       | String | 当前舞台名称       |
| `isStoryMode`    | Bool   | 是否为故事模式     |
| `difficulty`     | Int    | 难度索引           |
| `difficultyName` | String | 难度名称           |
| `difficultyPath` | String | 格式化后的难度路径 |
| `week`           | String | 周名称             |
| `weekRaw`        | Int    | 周索引             |
| `seenCutscene`   | Bool   | 是否已播放过场     |

#### 游戏玩法变量

| 变量名                 | 类型   | 描述                   |
| ---------------------- | ------ | ---------------------- |
| `score`                | Int    | 当前分数               |
| `misses`               | Int    | 失误次数               |
| `hits`                 | Int    | 命中次数               |
| `rating`               | Float  | 评分数值               |
| `ratingName`           | String | 评分名称               |
| `ratingFC`             | String | Full Combo 状态        |
| `inGameOver`           | Bool   | 是否处于游戏结束状态   |
| `mustHitSection`       | Bool   | 当前小节是否为玩家部分 |
| `altAnim`              | Bool   | 是否使用替代动画       |
| `gfSection`            | Bool   | 当前小节是否为 GF 部分 |
| `healthGainMult`       | Float  | 生命值增益倍数         |
| `healthLossMult`       | Float  | 生命值损失倍数         |
| `playbackRate`         | Float  | 播放速率               |
| `instakillOnMiss`      | Bool   | 失误即死模式           |
| `botPlay`              | Bool   | 自动游玩模式           |
| `practice`             | Bool   | 练习模式               |
| `combo`                | Int    | 当前连击数             |
| `curSection`           | Int    | 当前小节               |
| `curBeat`              | Int    | 当前节拍               |
| `curStep`              | Int    | 当前步进               |
| `curDecBeat`           | Float  | 当前小数节拍           |
| `curDecStep`           | Float  | 当前小数步进           |
| `hasVocals`            | Bool   | 是否有人声音轨         |
| `defaultBoyfriendX/Y`  | Float  | 角色默认 X/Y 位置      |
| `defaultOpponentX/Y`   | Float  | 对手默认 X/Y 位置      |
| `defaultGirlfriendX/Y` | Float  | GF 默认 X/Y 位置       |
| `boyfriendName`        | String | 玩家角色名称           |
| `dadName`              | String | 对手角色名称           |
| `gfName`               | String | GF 角色名称            |

#### 设置变量

| 变量名                | 类型   | 描述             |
| --------------------- | ------ | ---------------- |
| `downscroll`          | Bool   | 下落滚动模式     |
| `middlescroll`        | Bool   | 中间滚动模式     |
| `framerate`           | Int    | 帧率限制         |
| `ghostTapping`        | Bool   | 幽灵按键模式     |
| `hideHud`             | Bool   | 隐藏 HUD         |
| `timeBarType`         | String | 时间条类型       |
| `scoreZoom`           | Bool   | 评分缩放         |
| `cameraZoomOnBeat`    | Bool   | 拍子相机缩放     |
| `flashingLights`      | Bool   | 闪烁灯光效果     |
| `noteOffset`          | Int    | 音符偏移         |
| `healthBarAlpha`      | Float  | 血条透明度       |
| `noResetButton`       | Bool   | 禁用重置按钮     |
| `lowQuality`          | Bool   | 低质量模式       |
| `shadersEnabled`      | Bool   | 着色器启用       |
| `scriptName`          | String | 当前脚本名称     |
| `currentModDirectory` | String | 当前 Mod 目录    |
| `guitarHeroSustains`  | Bool   | 吉他英雄长按模式 |
| `noteSkin`            | String | 音符皮肤         |
| `splashSkin`          | String | 溅射皮肤         |
| `splashAlpha`         | Float  | 溅射透明度       |
| `luattf`              | String | Lua 文本字体设置 |

#### 其他变量

| 变量名                  | 类型   | 描述                |
| ----------------------- | ------ | ------------------- |
| `version`               | String | Psych Engine 版本号 |
| `buildTarget`           | String | 构建目标平台        |
| `language`              | String | 当前语言            |
| `luaVersion`            | String | Lua 版本号          |
| `hscriptVersion`        | String | HScript 版本号      |
| `screenWidth`           | Int    | 屏幕宽度            |
| `screenHeight`          | Int    | 屏幕高度            |
| `cameraX/Y`             | Float  | 相机位置            |
| `luaDebugMode`          | Bool   | Lua 调试模式        |
| `luaDeprecatedWarnings` | Bool   | 弃用警告            |
| `inChartEditor`         | Bool   | 是否在谱面编辑器中  |

### 3.4 Lua API 函数完整列表

#### 属性操作

| 函数                                                | 参数                                                               | 描述                           |
| --------------------------------------------------- | ------------------------------------------------------------------ | ------------------------------ |
| `getProperty(variable, allowMaps)`                  | `variable: String`, `allowMaps?: Bool`                             | 获取对象属性，支持点号链式访问 |
| `setProperty(variable, value, allowMaps)`           | `variable: String`, `value: Dynamic`, `allowMaps?: Bool`           | 设置对象属性                   |
| `getPropertyFromGroup(obj, index, variable)`        | `obj: String`, `index: Int`, `variable: Dynamic`                   | 从组中获取元素属性             |
| `setPropertyFromGroup(obj, index, variable, value)` | `obj: String`, `index: Int`, `variable: Dynamic`, `value: Dynamic` | 设置组中元素属性               |
| `getPropertyFromClass(className, variable)`         | `className: String`, `variable: String`                            | 获取类静态属性                 |
| `setPropertyFromClass(className, variable, value)`  | `className: String`, `variable: String`, `value: Dynamic`          | 设置类静态属性                 |
| `removeFromGroup(obj, index, dontDestroy)`          | `obj: String`, `index: Int`, `dontDestroy?: Bool`                  | 从组中移除元素                 |

#### 对象创建与操作

| 函数                                                                     | 参数                                                        | 描述                                   |
| ------------------------------------------------------------------------ | ----------------------------------------------------------- | -------------------------------------- |
| `makeLuaSprite(tag, image, x, y)`                                        | `tag: String`, `image: String`, `x: Float`, `y: Float`      | 创建 Sprite                            |
| `makeAnimatedLuaSprite(tag, image, x, y, gridX?, gridY?)`                | ...                                                         | 创建带动画的 Sprite                    |
| `addLuaSprite(tag, front)`                                               | `tag: String`, `front: Bool`                                | 添加 Sprite 到场景                     |
| `addInstance(objectName, inFront)`                                       | `objectName: String`, `inFront: Bool`                       | 添加实例引用到脚本上下文               |
| `instanceArg(instanceName, className)`                                   | `instanceName: String`, `className: String`                 | 创建类型化实例参数                     |
| `addAnimationByPrefix(obj, name, prefix, framerate, loop)`               | ...                                                         | 按前缀添加动画                         |
| `addAnimationByIndices(obj, name, prefix, indices, framerate, loop)`     | ...                                                         | 按索引添加动画                         |
| `addAnimationByAnimIndices(obj, name, prefix, indices, framerate, loop)` | ...                                                         | 另一种方式添加动画                     |
| `addAnimation(obj, name, frames, framerate, loop)`                       | ...                                                         | 通过帧索引数组添加动画                 |
| `addAnimationByIndicesLoop(obj, name, prefix, indices, framerate)`       | ...                                                         | 添加循环动画（按索引）                 |
| `addOffset(obj, anim, x, y)`                                             | `obj: String`, `anim: String`, `x: Float`, `y: Float`       | 添加动画偏移                           |
| `objectPlayAnimation(obj, name, forced, ?reverse, ?startFrame)`          | ...                                                         | 播放对象动画                           |
| `setObjectCamera(obj, camera)`                                           | `obj: String`, `camera: String`                             | 设置对象相机（'game', 'hud', 'other'） |
| `setObjectOrder(obj, order)`                                             | `obj: String`, `order: Int`                                 | 设置对象渲染顺序                       |
| `getObjectOrder(obj)`                                                    | `obj: String`                                               | 获取对象渲染顺序                       |
| `setScrollFactor(obj, x, y)`                                             | `obj: String`, `x: Float`, `y: Float`                       | 设置滚动因子                           |
| `loadGraphic(variable, image, gridX?, gridY?)`                           | ...                                                         | 加载图形                               |
| `loadFrames(variable, image, spriteType)`                                | ...                                                         | 加载帧动画                             |
| `makeGraphic(obj, width, height, color)`                                 | `obj: String`, `width: Int`, `height: Int`, `color: String` | 创建彩色矩形图形                       |
| `updateHitbox(obj)`                                                      | `obj: String`                                               | 更新对象碰撞箱                         |
| `updateHitboxFromGroup(group, index)`                                    | `group: String`, `index: Int`                               | 从组成员更新碰撞箱                     |
| `createInstance(variableToSave, className, args)`                        | ...                                                         | 动态创建类实例                         |
| `callMethod(func, args)`                                                 | ...                                                         | 调用 PlayState 方法                    |
| `callMethodFromClass(className, func, args)`                             | ...                                                         | 调用类的静态方法                       |
| `luaSpriteExists(tag)`                                                   | `tag: String`                                               | 检查 Sprite 是否存在                   |
| `luaTextExists(tag)`                                                     | `tag: String`                                               | 检查文本是否存在                       |
| `luaSoundExists(tag)`                                                    | `tag: String`                                               | 检查音效是否存在                       |
| `objectsOverlap(obj1, obj2)`                                             | `obj1: String`, `obj2: String`                              | 检查两个对象是否重叠                   |
| `getPixelColor(obj, x, y)`                                               | `obj: String`, `x: Int`, `y: Int`                           | 获取指定坐标像素颜色                   |
| `removeLuaSprite(tag, destroy)`                                          | `tag: String`, `destroy: Bool`                              | 移除 Sprite                            |
| `removeLuaText(tag, destroy)`                                            | `tag: String`, `destroy: Bool`                              | 移除文本                               |
| `scaleObject(obj, x, y, updateHitbox)`                                   | ...                                                         | 缩放对象                               |
| `setGraphicSize(obj, x, y, updateHitbox)`                                | ...                                                         | 设置图形大小                           |
| `screenCenter(obj, pos)`                                                 | `obj: String`, `pos: String`                                | 屏幕居中                               |
| `setBlendMode(obj, blend)`                                               | `obj: String`, `blend: String`                              | 设置混合模式                           |

#### 文本对象

| 函数                                     | 参数                          | 描述             |
| ---------------------------------------- | ----------------------------- | ---------------- |
| `makeLuaText(tag, text, width, x, y)`    | ...                           | 创建文本对象     |
| `addLuaText(tag)`                        | `tag: String`                 | 添加文本到场景   |
| `setTextString(tag, text)`               | ...                           | 设置文本内容     |
| `setTextSize(tag, size)`                 | ...                           | 设置文本大小     |
| `setTextWidth(tag, width)`               | ...                           | 设置文本宽度     |
| `setTextAlignment(tag, alignment)`       | ...                           | 设置文本对齐     |
| `setTextColor(tag, color)`               | ...                           | 设置文本颜色     |
| `setTextFont(tag, font)`                 | ...                           | 设置文本字体     |
| `setTextBorder(tag, size, color, style)` | ...                           | 设置文本边框     |
| `setTextItalic(tag, italic)`             | `tag: String`, `italic: Bool` | 设置文本斜体     |
| `setTextAutoSize(tag, value)`            | `tag: String`, `value: Bool`  | 设置文本自动大小 |
| `getTextString(tag)`                     | `tag: String`                 | 获取文本内容     |
| `getTextSize(tag)`                       | `tag: String`                 | 获取文本大小     |
| `getTextFont(tag)`                       | `tag: String`                 | 获取文本字体     |
| `getTextWidth(tag)`                      | `tag: String`                 | 获取文本宽度     |

#### 音视频

| 函数                                   | 参数 | 描述                           |
| -------------------------------------- | ---- | ------------------------------ |
| `playSound(sound, volume, tag)`        | ...  | 播放音效                       |
| `playMusic(sound, volume, loop)`       | ...  | 播放音乐                       |
| `stopSound(tag)`                       | ...  | 停止音效                       |
| `pauseSound(tag)`                      | ...  | 暂停音效                       |
| `resumeSound(tag)`                     | ...  | 恢复音效                       |
| `soundFadeIn(tag, duration, from, to)` | ...  | 音效淡入                       |
| `soundFadeOut(tag, duration, to)`      | ...  | 音效淡出                       |
| `soundFadeCancel(tag)`                 | ...  | 取消音效淡变                   |
| `getSoundVolume(tag)`                  | ...  | 获取音效音量                   |
| `setSoundVolume(tag, volume)`          | ...  | 设置音效音量                   |
| `getSoundTime(tag)`                    | ...  | 获取音效播放位置               |
| `setSoundTime(tag, value)`             | ...  | 设置音效播放位置               |
| `getSoundPitch(tag)`                   | ...  | 获取音高（需 `#if FLX_PITCH`） |
| `setSoundPitch(tag, value)`            | ...  | 设置音高（需 `#if FLX_PITCH`） |

#### 补间动画

| 函数                                                     | 参数 | 描述       |
| -------------------------------------------------------- | ---- | ---------- |
| `doTweenX(tag, vars, value, duration, ease)`             | ...  | X 轴补间   |
| `doTweenY(tag, vars, value, duration, ease)`             | ...  | Y 轴补间   |
| `doTweenAngle(tag, vars, value, duration, ease)`         | ...  | 角度补间   |
| `doTweenAlpha(tag, vars, value, duration, ease)`         | ...  | 透明度补间 |
| `doTweenZoom(tag, vars, value, duration, ease)`          | ...  | 缩放补间   |
| `doTweenColor(tag, vars, value, duration, ease)`         | ...  | 颜色补间   |
| `cancelTween(tag)`                                       | ...  | 取消补间   |
| `tweenCameraX/Y/Zoom/Angle/Alpha(value, duration, ease)` | ...  | 相机补间   |

#### 计时器

| 函数                         | 参数 | 描述               |
| ---------------------------- | ---- | ------------------ |
| `runTimer(tag, time, loops)` | ...  | 运行计时器         |
| `cancelTimer(tag)`           | ...  | 取消计时器         |
| `getTimer(tag)`              | ...  | 获取计时器剩余时间 |

#### 颜色工具

| 函数                          | 参数            | 描述                       |
| ----------------------------- | --------------- | -------------------------- |
| `getColorFromHex(color)`      | `color: String` | 从十六进制获取颜色值       |
| `getColorFromRGB(r, g, b, a)` | ...             | 从 RGB 获取颜色值          |
| `getColorFromName(color)`     | `color: String` | 从颜色名称获取（如 'RED'） |
| `getColorFromString(color)`   | `color: String` | 从字符串获取颜色           |
| `FlxColor(color)`             | `color: String` | FlxColor 别名函数          |

#### 音符补间（Strum Note Tweens）

| 函数                                                   | 参数                                                                          | 描述               |
| ------------------------------------------------------ | ----------------------------------------------------------------------------- | ------------------ |
| `noteTweenX(tag, note, value, duration, ease)`         | `tag: String`, `note: Int`, `value: Float`, `duration: Float`, `ease: String` | 音符轨道 X 补间    |
| `noteTweenY(tag, note, value, duration, ease)`         | ...                                                                           | 音符轨道 Y 补间    |
| `noteTweenAngle(tag, note, value, duration, ease)`     | ...                                                                           | 音符轨道角度补间   |
| `noteTweenDirection(tag, note, value, duration, ease)` | ...                                                                           | 音符轨道方向补间   |
| `noteTweenAlpha(tag, note, value, duration, ease)`     | ...                                                                           | 音符轨道透明度补间 |
| `cancelTween(tag)`                                     | ...                                                                           | 取消补间           |

#### 相机

| 函数                                                     | 参数             | 描述             |
| -------------------------------------------------------- | ---------------- | ---------------- |
| `cameraSetTarget(target)`                                | `target: String` | 设置相机聚焦目标 |
| `cameraShake(camera, intensity, duration)`               | ...              | 相机震动         |
| `cameraFlash(camera, color, duration, forced)`           | ...              | 相机闪白         |
| `cameraFade(camera, color, duration, forced)`            | ...              | 相机淡入/淡出    |
| `tweenCameraX/Y/Zoom/Angle/Alpha(value, duration, ease)` | ...              | 相机补间         |

#### 鼠标输入

| 函数                    | 参数             | 描述                 |
| ----------------------- | ---------------- | -------------------- |
| `mouseClicked(button)`  | `button: String` | 检查鼠标按键是否点击 |
| `mousePressed(button)`  | `button: String` | 检查鼠标按键是否按住 |
| `mouseReleased(button)` | `button: String` | 检查鼠标按键是否释放 |
| `getMouseX(camera)`     | `camera: String` | 获取鼠标 X 位置      |
| `getMouseY(camera)`     | `camera: String` | 获取鼠标 Y 位置      |

#### 角色操作

| 函数                             | 参数                           | 描述                 |
| -------------------------------- | ------------------------------ | -------------------- |
| `characterDance(character)`      | `character: String`            | 强制角色播放空闲舞蹈 |
| `addCharacterToList(name, type)` | `name: String`, `type: String` | 预加载角色到列表     |
| `getCharacterX(type)`            | `type: String`                 | 获取角色 X 位置      |
| `getCharacterY(type)`            | `type: String`                 | 获取角色 Y 位置      |
| `setCharacterX(type, value)`     | `type: String`, `value: Float` | 设置角色 X 位置      |
| `setCharacterY(type, value)`     | `type: String`, `value: Float` | 设置角色 Y 位置      |

#### 对话/视频

| 函数                                 | 参数                                     | 描述                 |
| ------------------------------------ | ---------------------------------------- | -------------------- |
| `startDialogue(dialogueFile, music)` | `dialogueFile: String`, `music?: String` | 从 JSON 文件启动对话 |
| `startVideo(videoFile)`              | `videoFile: String`                      | 播放视频             |
| `triggerEvent(name, arg1, arg2)`     | ...                                      | 触发自定义事件       |

#### 位置获取

| 函数                            | 参数               | 描述           |
| ------------------------------- | ------------------ | -------------- |
| `getMidpointX(variable)`        | `variable: String` | 获取对象中点 X |
| `getMidpointY(variable)`        | `variable: String` | 获取对象中点 Y |
| `getGraphicMidpointX(variable)` | `variable: String` | 获取图形中点 X |
| `getGraphicMidpointY(variable)` | `variable: String` | 获取图形中点 Y |
| `getScreenPositionX(variable)`  | `variable: String` | 获取屏幕位置 X |
| `getScreenPositionY(variable)`  | `variable: String` | 获取屏幕位置 Y |

#### Discord 集成

| 函数                                                                             | 参数 | 描述                                  |
| -------------------------------------------------------------------------------- | ---- | ------------------------------------- |
| `changePresence(details, state, smallImageKey, hasStartTimestamp, endTimestamp)` | ...  | 更改 Discord 状态（需 `#if desktop`） |

#### 工具函数

| 函数                                  | 参数                            | 描述                         |
| ------------------------------------- | ------------------------------- | ---------------------------- |
| `stringStartsWith(str, start)`        | `String, String`                | 检查字符串是否以指定文本开头 |
| `stringEndsWith(str, end)`            | `String, String`                | 检查字符串是否以指定文本结尾 |
| `stringSplit(str, split)`             | `String, String`                | 分割字符串                   |
| `stringTrim(str)`                     | `String`                        | 去除字符串首尾空白           |
| `directoryFileList(folder)`           | `folder: String`                | 列出目录文件列表             |
| `getRandomInt(min, max, exclude)`     | `Int, Int, String`              | 获取随机整数                 |
| `getRandomFloat(min, max, exclude)`   | `Float, Float, String`          | 获取随机浮点数               |
| `getRandomBool(chance)`               | `Float`                         | 获取随机布尔值               |
| `getModSetting(saveTag, modName)`     | ...                             | 获取 Mod 设置值              |
| `setTimeBarColors(leftHex, rightHex)` | ...                             | 设置时间条颜色               |
| `debugPrint(text, color)`             | `text: String`, `color: String` | 在屏幕上打印调试文本         |
| `close()`                             | -                               | 关闭当前 Lua 脚本            |

#### 已弃用 API

以下函数已弃用，请使用其替代函数：

| 已弃用                             | 替代                      |
| ---------------------------------- | ------------------------- |
| `objectPlayAnimation()`            | `playAnim()`              |
| `characterPlayAnim()`              | `playAnim()`              |
| `luaSpriteMakeGraphic()`           | `makeGraphic()`           |
| `luaSpriteAddAnimationByPrefix()`  | `addAnimationByPrefix()`  |
| `luaSpriteAddAnimationByIndices()` | `addAnimationByIndices()` |
| `luaSpritePlayAnimation()`         | `playAnim()`              |
| `setLuaSpriteCamera()`             | `setObjectCamera()`       |
| `setLuaSpriteScrollFactor()`       | `setScrollFactor()`       |
| `scaleLuaSprite()`                 | `scaleObject()`           |
| `getPropertyLuaSprite()`           | `getProperty()`           |
| `setPropertyLuaSprite()`           | `setProperty()`           |
| `musicFadeIn()`                    | `soundFadeIn()`           |
| `musicFadeOut()`                   | `soundFadeOut()`          |

#### 评分系统

| 函数                      | 参数            | 描述                   |
| ------------------------- | --------------- | ---------------------- |
| `addScore(value)`         | `value: Int`    | 增加分数               |
| `setScore(value)`         | `value: Int`    | 设置分数               |
| `getScore()`              | -               | 获取分数               |
| `addMisses(value)`        | `value: Int`    | 增加失误               |
| `setMisses(value)`        | `value: Int`    | 设置失误数             |
| `getMisses()`             | -               | 获取失误数             |
| `addHits(value)`          | `value: Int`    | 增加命中数             |
| `setHits(value)`          | `value: Int`    | 设置命中数             |
| `getHits()`               | -               | 获取命中数             |
| `setHealth(value)`        | `value: Float`  | 设置生命值             |
| `addHealth(value)`        | `value: Float`  | 增加生命值             |
| `getHealth()`             | -               | 获取生命值             |
| `setRatingPercent(value)` | `value: Float`  | 设置评分百分比         |
| `setRatingString(value)`  | `value: String` | 设置评分名称           |
| `setRatingName(value)`    | `value: String` | setRatingString 的别名 |
| `setRatingFC(value)`      | `value: String` | 设置 FC 状态           |

#### 歌曲控制

| 函数                            | 参数                   | 描述                |
| ------------------------------- | ---------------------- | ------------------- |
| `getSongPosition()`             | -                      | 获取歌曲播放位置    |
| `setSongPosition(value)`        | `value: Float`         | 设置歌曲播放位置    |
| `loadSong(name, difficultyNum)` | ...                    | 加载新歌曲          |
| `startCountdown()`              | -                      | 开始/重新开始倒计时 |
| `endSong()`                     | -                      | 结束当前歌曲        |
| `restartSong(skipTransition)`   | `skipTransition: Bool` | 重新开始歌曲        |
| `exitSong(skipTransition)`      | `skipTransition: Bool` | 退出到主菜单        |
| `triggerEvent(name, v1, v2)`    | ...                    | 触发事件            |

#### 脚本间通信

| 函数                                                                 | 参数                | 描述                          |
| -------------------------------------------------------------------- | ------------------- | ----------------------------- |
| `getRunningScripts()`                                                | -                   | 获取所有运行中的脚本列表      |
| `callOnScripts(funcName, args, ignoreStops, ignoreSelf, exclusions)` | ...                 | 调用所有脚本的回调            |
| `callScript(luaFile, funcName, args)`                                | ...                 | 调用指定脚本的函数            |
| `getGlobalFromScript(luaFile, global)`                               | ...                 | 获取指定脚本的全局变量        |
| `setGlobalFromScript(luaFile, global, val)`                          | ...                 | 设置指定脚本的全局变量        |
| `isRunning(luaFile)`                                                 | ...                 | 检查脚本是否在运行            |
| `addLuaScript(luaFile, ignoreAlreadyRunning)`                        | ...                 | 动态添加 Lua 脚本             |
| `removeLuaScript(luaFile)`                                           | ...                 | 动态移除 Lua 脚本             |
| `runHaxeCode(codeToRun)`                                             | `codeToRun: String` | 在 Lua 中执行 HScript 代码    |
| `addHaxeLibrary(libName, libPackage)`                                | ...                 | 导入 Haxe 类到 HScript 上下文 |
| `callOnLuas(func, args, ignoreStops, exclusions)`                    | ...                 | 调用所有 Lua 脚本             |
| `callOnHScript(func, args, ignoreStops, exclusions)`                 | ...                 | 调用所有 HScript              |
| `setOnLuas(varName, arg)`                                            | ...                 | 设置所有 Lua 脚本变量         |
| `setOnHScript(varName, arg)`                                         | ...                 | 设置所有 HScript 变量         |
| `setOnScripts(varName, arg)`                                         | ...                 | 设置所有脚本变量              |

#### 自定义子状态

| 函数                                  | 参数 | 描述             |
| ------------------------------------- | ---- | ---------------- |
| `openCustomSubstate(name, pauseGame)` | ...  | 打开自定义子状态 |
| `closeCustomSubstate()`               | -    | 关闭自定义子状态 |

#### 着色器

| 函数                                            | 参数 | 描述               |
| ----------------------------------------------- | ---- | ------------------ |
| `initLuaShader(name, glslVersion)`              | ...  | 初始化着色器       |
| `setSpriteShader(obj, shader)`                  | ...  | 设置 Sprite 着色器 |
| `removeSpriteShader(obj)`                       | ...  | 移除 Sprite 着色器 |
| `getShaderBool/Int/Float(obj, prop)`            | ...  | 获取着色器属性     |
| `setShaderBool/Int/Float(obj, prop, value)`     | ...  | 设置着色器属性     |
| `setShaderSampler2D(obj, prop, bitmapdataPath)` | ...  | 设置着色器纹理     |

#### 调试

| 函数                                             | 参数           | 描述              |
| ------------------------------------------------ | -------------- | ----------------- |
| `debugPrint(text)`                               | `text: String` | 调试打印          |
| `luaTrace(text, ignoreCheck, deprecated, color)` | ...            | Lua 跟踪输出      |
| `luaDeprecations(value)`                         | `value: Bool`  | 启用/禁用弃用警告 |

#### 键盘/手柄输入

| 函数                     | 参数           | 描述           |
| ------------------------ | -------------- | -------------- |
| `keyJustPressed(name)`   | `name: String` | 检测按键刚按下 |
| `keyPressed(name)`       | `name: String` | 检测按键按住   |
| `keyReleased(name)`      | `name: String` | 检测按键刚释放 |
| `isKeyPressed(name)`     | `name: String` | 通用按键检测   |
| `isGamepadPressed(name)` | ...            | 手柄按键检测   |

#### 文件与保存

| 函数                                        | 参数 | 描述             |
| ------------------------------------------- | ---- | ---------------- |
| `getTextFromFile(path, ignoreModFolders)`   | ...  | 读取文本文件     |
| `checkFileExists(path, ignoreModFolders)`   | ...  | 检查文件是否存在 |
| `saveFile(path, content, ignoreModFolders)` | ...  | 保存文件         |
| `deleteFile(path, ignoreModFolders)`        | ...  | 删除文件         |
| `initSaveData(name, ?folder)`               | ...  | 初始化存档       |
| `flushSaveData()`                           | -    | 刷新存档到磁盘   |
| `getDataFromSave(name, ?default)`           | ...  | 读取存档数据     |
| `setDataFromSave(name, value)`              | ...  | 写入存档数据     |

#### 杂项

| 函数                            | 参数          | 描述                |
| ------------------------------- | ------------- | ------------------- |
| `precacheImage(key)`            | `key: String` | 预缓存图像          |
| `precacheSound(key)`            | `key: String` | 预缓存音效          |
| `precacheMusic(key)`            | `key: String` | 预缓存音乐          |
| `loadLanguage(lang)`            | ...           | 加载语言包          |
| `getLanguage(key, defaultText)` | ...           | 获取语言文本        |
| `setVar(name, value)`           | ...           | 设置 PlayState 变量 |
| `getVar(name)`                  | ...           | 获取 PlayState 变量 |
| `songMusicTracks(...)`          | ...           | 获取音乐音轨        |

---

## 4. HScript 脚本系统

### 4.1 HScript 类

`HScript` 类（位于 `source/script/hscript/HScript.hx`）是 Haxe 脚本的核心引擎。

**支持的扩展名**: `.hx`, `.hscript`, `.hsc`, `.hxs`

### 4.2 默认变量绑定

HScript 脚本创建时会自动注入以下变量（来自 `HScript.getDefaultVariables()`）：

#### Haxe 标准库

```
Math, Std, StringTools, Sys, Type, Reflect,
Date, DateTools, Lambda, EReg, Xml, Json (haxe.Json)
```

#### Flixel 框架

```
FlxG, FlxMath, FlxSprite, FlxCamera,
FlxTimer, FlxTween, FlxEase,
FlxText, FlxSound, FlxGroup, FlxTypedGroup,
FlxSpriteGroup, FlxStringUtil, FlxSpriteUtil,
FlxAtlasFrames, FlxColor (CustomFlxColor)
```

#### 引擎类

```
Paths, Conductor, ClientPrefs,
Character, Alphabet, FunkinText
```

#### 状态类

```
MusicBeatState, MusicBeatSubstate,
ModState, ModSubState,
PlayState, FreeplayState, StoryMenuState,
TitleState, CreditsState, MainMenuState,
HScript
```

#### 着色器

```
ShaderFilter, ColorMatrixFilter
FlxRuntimeShader (非 Flash + sys 平台)
VideoSpriteManager
MP4Handler (hxCodec >= 3.0.0 或 2.5.1)
```

#### 脚本控制常量

```
Function_Stop       = 1  -- 停止当前执行
Function_Continue   = 0  -- 继续执行
Function_StopLua    = 2  -- 停止 Lua
Function_StopHScript = 3 -- 停止 HScript
Function_StopAll    = 4  -- 停止所有
```

#### 便捷函数

```haxe
add(obj:Dynamic)         // 添加到当前状态
insert(pos:Int, obj:Dynamic)  // 插入到指定位置
remove(obj:Dynamic, splice:Bool = false)  // 从状态移除
```

#### 版本与屏幕信息

```haxe
hscriptVersion   // "0.2.0"
version          // Psych Engine 版本
screenWidth      // FlxG.width
screenHeight     // FlxG.height
buildTarget      // "windows" / "linux" / "mac" / "browser" / "android"
language         // 当前语言
```

#### 输入函数

```haxe
keyJustPressed(name:String)           // 按键刚按下检测
keyPressed(name:String)               // 按键按住检测
keyReleased(name:String)              // 按键释放检测
// name 支持: 'left', 'down', 'up', 'right', 'accept', 'back', 'pause', 'reset', 'space'

keyboardJustPressed(name:String)      // 任意键盘按键刚按下
keyboardPressed(name:String)          // 任意键盘按键按住
keyboardReleased(name:String)         // 任意键盘按键释放

anyGamepadJustPressed(name:String)    // 任意手柄按键刚按下
anyGamepadPressed(name:String)        // 任意手柄按键按住
anyGamepadReleased(name:String)       // 任意手柄按键释放

gamepadAnalogX(id:Int, leftStick:Bool) // 手柄摇杆 X 轴
gamepadAnalogY(id:Int, leftStick:Bool) // 手柄摇杆 Y 轴
gamepadJustPressed(id:Int, name:String) // 指定手柄按键刚按下
gamepadPressed(id:Int, name:String)     // 指定手柄按键按住
gamepadReleased(id:Int, name:String)    // 指定手柄按键释放
```

#### 导入与桥接函数

```haxe
importScript(path:String)      // 导入其他 HScript 文件
runLuaCode(code:String)        // 执行 Lua 代码
FunkinLua                      // Lua 引擎类引用
LuaApi                         // Lua API 管理类
customSubstate                 // 当前自定义子状态
customSubstateName             // 自定义子状态名称
```

### 4.3 PlayState 特定绑定

当 `PlayState.instance` 可用时，HScript 自动绑定以下变量：

| 变量名             | 类型      | 描述               |
| ------------------ | --------- | ------------------ |
| `game`             | PlayState | PlayState 实例引用 |
| `curBpm`           | Float     | 当前 BPM           |
| `bpm`              | Float     | 歌曲 BPM           |
| `scrollSpeed`      | Float     | 滚动速度           |
| `crochet`          | Float     | 节拍长度           |
| `stepCrochet`      | Float     | 步进长度           |
| `songLength`       | Float     | 歌曲长度           |
| `songName`         | String    | 歌曲名称           |
| `songPath`         | String    | 歌曲路径           |
| `startedCountdown` | Bool      | 是否已开始倒计时   |
| `curStage`         | String    | 当前舞台           |
| `isStoryMode`      | Bool      | 故事模式           |
| `difficulty`       | Int       | 难度索引           |
| `difficultyName`   | String    | 难度名称           |
| `difficultyPath`   | String    | 难度路径           |
| `weekRaw`          | Int       | 周索引             |
| `week`             | String    | 周名称             |
| `seenCutscene`     | Bool      | 是否已看过过场     |
| `boyfriend`        | Character | 玩家角色           |
| `dad`              | Character | 对手角色           |
| `gf`               | Character | GF 角色            |
| `camGame`          | FlxCamera | 游戏相机           |
| `camHUD`           | FlxCamera | HUD 相机           |
| `camOther`         | FlxCamera | 其他相机           |
| `healthGainMult`   | Float     | 生命增益倍数       |
| `healthLossMult`   | Float     | 生命损失倍数       |
| `playbackRate`     | Float     | 播放速率           |
| `instakillOnMiss`  | Bool      | 失误即死           |
| `botPlay`          | Bool      | 自动游玩           |
| `practice`         | Bool      | 练习模式           |
| `luattf`           | String    | 字体设置           |

#### PlayState 变量管理

```haxe
setVar(name:String, value:Dynamic)      // 设置 PlayState 变量
getVar(name:String):Dynamic              // 获取 PlayState 变量
removeVar(name:String):Bool              // 移除 PlayState 变量
```

---

## 5. ModState & ModSubState

### 5.1 ModState

`ModState`（位于 `source/states/ModState.hx`）是一个同时支持 **Lua** 和 **HScript** 脚本的状态。它继承自 `MusicBeatState`，允许通过脚本文件定义完整的游戏状态。

**脚本文件位置**:
- HScript: `data/states/<Name>.hx` 或 `data/states/<Name>/`
- Lua: `data/states/<Name>.lua` 或 `data/states/<Name>/`

**使用方式**:
```haxe
FlxG.switchState(new ModState("MyState"));
// 可携带数据
FlxG.switchState(new ModState("MyState", {someData: 123}));
```

**工作原理**:
1. 构造函数接收状态名称和可选数据
2. 数据通过静态变量 `lastName` 和 `lastData` 跨状态切换保持
3. `super(scriptName)` 传递给 `MusicBeatState`，触发 `initHScripts()`
4. `create()` 中额外初始化 Lua 脚本（`initLuaScripts()`），设置 Lua 变量并触发回调

**Lua 变量绑定**（ModState.create 中自动设置）:
```lua
-- 在 Lua 脚本中可直接访问
data      -- 传递的数据
controls  -- 控制器对象
state     -- ModState 实例自身
```

**数据传递**:
```haxe
// 保存数据到静态变量（自动）
ModState.lastName = "MyState";
ModState.lastData = {playerName: "John"};

// 在 HScript 中访问
trace(data.playerName);  // "John"
```

### 5.2 ModSubState

`ModSubState`（位于 `source/substates/ModSubState.hx`）与 `ModState` 类似，同时支持 **Lua** 和 **HScript**，但是子状态版本，继承自 `MusicBeatSubstate`。

**脚本文件位置**:
- HScript: `data/states/<Name>.hx` 或 `data/states/<Name>/`
- Lua: `data/states/<Name>.lua` 或 `data/states/<Name>/`

**使用方式**:
```haxe
// 从任意状态或子状态打开
openSubState(new ModSubState("MySubState"));
openSubState(new ModSubState("MySubState", {someData: 456}));
```

**Lua 变量绑定**（ModSubState.create 中自动设置）:
```lua
data      -- 传递的数据
controls  -- 控制器对象
state     -- ModSubState 实例自身
```

**与 ModState 的区别**:
- 继承自 `MusicBeatSubstate` 而非 `MusicBeatState`
- 脚本搜索路径包含遗留的 `hscripts/substates/` 和 `lua/substates/` 目录
- 生命周期方法不同（`create()` 等）

### 5.3 生命周期

`ModState` / `ModSubState` 的 `create()` 流程：

```
ModState.create()
├── super.create()
│   ├── FlxG 配置
│   └── initHScripts()  ← 加载 data/states/<Name>.hx
│       └── HScript 构造函数自动调用 onCreate()
├── initLuaScripts()    ← 额外加载 Lua
├── setOnLuas('data', data)
├── setOnLuas('controls', controls)
├── setOnLuas('state', this)
├── callOnLuas('onCreatePost', [])
└── setOnHscript('data', data)
```

---

## 6. 辅助类

### 6.1 DebugLuaText

**文件**: `source/script/lua/DebugLuaText.hx`

用于在屏幕上显示调试文本的类，会自动淡出消失。

```haxe
class DebugLuaText extends FlxText
```

**特性**:
- 默认持续 6 秒后自动淡出
- 根据 `ClientPrefs.data.luattf` 选择字体
- 自动设置滚动因子为 0（固定在屏幕上）
- 使用 `parentGroup:FlxTypedGroup<DebugLuaText>` 管理多个文本

### 6.2 ModchartSprite

**文件**: `source/script/lua/ModchartSprite.hx`

用于 Lua 脚本创建的可扩展 Sprite 类。

```haxe
class ModchartSprite extends FlxSprite
```

**特性**:
- `wasAdded:Bool` — 标记是否已添加到场景
- `animOffsets:Map<String, Array<Float>>` — 动画偏移映射
- `playAnim(name, forced, reverse, startFrame)` — 播放动画并自动应用偏移
- `addOffset(name, x, y)` — 添加动画偏移
- 默认启用抗锯齿（根据 `ClientPrefs.data.globalAntialiasing`）

### 6.3 ModchartText

**文件**: `source/script/lua/ModchartText.hx`

用于 Lua 脚本创建的可缩放文本类。

```haxe
class ModchartText extends FlxText
```

**特性**:
- 默认相机为 `camHUD`
- 边框大小为 2（比普通文本更粗）
- 根据 `luattf` 设置选择字体（VCR 或系统字体）
- `wasAdded:Bool` — 标记是否已添加到场景
- 滚动因子固定为 0

### 6.4 FunkinText

**文件**: `source/script/FunkinText.hx`

通用的 FNF 风格文本组件，可在 HScript 中直接使用。

```haxe
class FunkinText extends FlxText
```

**构造函数**:
```haxe
new FunkinText(X:Float = 0, Y:Float = 0, FieldWidth:Float = 0,
               ?Text:String, Size:Int = 16, Border:Bool = true)
```

**特性**:
- 默认使用 `vcr.ttf` 字体
- 默认颜色为白色
- 可选黑色描边（`Border:Bool` 参数控制）

**HScript 中使用示例**:
```haxe
var myText = new FunkinText(100, 100, 400, "Hello World", 24, true);
add(myText);
```

---

## 7. Lua API（从 HScript 管理 Lua）

`LuaApi` 类（位于 `source/script/hscript/LuaApi.hx`）提供从 HScript 管理 Lua 函数的全局 API。

### 7.1 方法列表

| 方法                                                | 参数                          | 描述                                                |
| --------------------------------------------------- | ----------------------------- | --------------------------------------------------- |
| `addLuaFunction(name, func, overrideExisting)`      | `String, Function, Bool`      | 添加新的全局 Lua 函数                               |
| `overrideLuaFunction(name, wrapper)`                | `String, Function`            | 覆盖已有 Lua 函数（wrapper 接收原始函数为第一参数） |
| `restoreLuaFunction(name)`                          | `String`                      | 恢复原始函数                                        |
| `removeLuaFunction(name)`                           | `String`                      | 移除自定义函数                                      |
| `luaFunctionExists(name)`                           | `String`                      | 检查函数是否存在                                    |
| `getLuaFunction(name)`                              | `String`                      | 获取 Lua 函数引用                                   |
| `getCustomFunctions()`                              | -                             | 获取所有自定义函数名                                |
| `getOverriddenFunctions()`                          | -                             | 获取所有被覆盖的函数名                              |
| `getOriginalFunction(name)`                         | `String`                      | 获取被覆盖函数的原始版本                            |
| `batchOverrideLuaFunctions(overrides)`              | `Map<String, Function>`       | 批量覆盖                                            |
| `batchAddLuaFunctions(functions, overrideExisting)` | `Map<String, Function>, Bool` | 批量添加                                            |
| `restoreAllLuaFunctions()`                          | -                             | 恢复所有函数                                        |
| `clearAll()`                                        | -                             | 清除所有自定义函数并恢复原始                        |

### 7.2 HScript 中使用示例

```haxe
// 添加全局 Lua 函数
LuaApi.addLuaFunction("myFunc", function(x, y) {
    return x + y;
});

// 覆盖已有函数
LuaApi.overrideLuaFunction("getProperty", function(original, variable) {
    trace('Intercepted getProperty call: ' + variable);
    return original(variable);
});

// 恢复原始函数
LuaApi.restoreLuaFunction("getProperty");
```

---

## 8. 脚本事件回调完整列表

以下事件回调同时适用于 Lua 和 HScript（HScript 中函数名相同）：

### 创建/销毁

```lua
function onCreate()
    -- Lua 文件启动时触发（部分变量尚未创建）
end

function onCreatePost()
    -- "create" 阶段结束时触发
end

function onDestroy()
    -- Lua 文件结束时触发（歌曲淡出完成）
end
```

### 更新循环

```lua
function onUpdate(elapsed)
    -- "update" 阶段开始时触发
    -- elapsed: Float - 帧时间差
end

function onUpdatePost(elapsed)
    -- "update" 阶段结束时触发
end
```

### 节拍/步进

```lua
function onBeatHit()
    -- 每小节触发 4 次（每拍）
    -- 注意：在 ModState 中此函数可能不会触发
end

function onStepHit()
    -- 每小节触发 16 次（每步进）
end
```

### 倒计时

```lua
function onStartCountdown()
    -- 倒计时开始时触发
    -- 返回 Function_Stop 可阻止倒计时
    return Function_Continue;
end

function onCountdownTick(counter)
    -- counter = 0 -> "三" ("Three")
    -- counter = 1 -> "二" ("Two")
    -- counter = 2 -> "一" ("One")
    -- counter = 3 -> "开始!" ("Go!")
    -- counter = 4 -> 与 onSongStart 同时触发
end

function onSongStart()
    -- 乐器音轨和人声开始播放，songPosition = 0
end
```

### 歌曲结束

```lua
function onEndSong()
    -- 歌曲结束/开始过渡时触发
    -- 返回 Function_Stop 可阻止结束
    return Function_Continue;
end
```

### 暂停

```lua
function onPause()
    -- 按下暂停键时触发
    -- 返回 Function_Stop 可阻止暂停
    return Function_Continue;
end

function onResume()
    -- 从暂停恢复后触发
end
```

### 游戏结束

```lua
function onGameOver()
    -- 角色死亡时触发（生命值 <= 0 时每帧调用）
    -- 返回 Function_Stop 可阻止进入游戏结束画面
    return Function_Continue;
end

function onGameOverConfirm(retry)
    -- 游戏结束界面按 Enter/Esc 时触发
    -- retry: Bool - 按 Esc 时为 false
end
```

### 对话系统

```lua
function onNextDialogue(line)
    -- 下一条对话开始时触发
    -- line: Int - 对话行号（从 1 开始）
end

function onSkipDialogue(line)
    -- 跳过未播放完的对话时触发
end
```

### 音符命中/失误

**⚠️ 重要：Lua 与 HScript 的参数差异**

`goodNoteHit` 在 PlayState 中手动调用 Lua 和 HScript 时传递了**不同的参数**。`opponentNoteHit` 使用 `callOnScripts` 调用，参数一致。

```lua
-- Lua 版本
function goodNoteHit(id, direction, noteType, isSustainNote)
    -- 玩家命中音符后触发
    -- id: Int       - 音符在 'notes' 组中的索引（可通过 getPropertyFromGroup 获取更多属性）
    -- direction: Int - 0=左, 1=下, 2=上, 3=右
    -- noteType: String - 音符类型标签（如 'Hurt Note', 'Hey!' 等）
    -- isSustainNote: Bool - 是否为长按音符
end
```

```haxe
// HScript 版本 — 参数不同！
function goodNoteHit(note:Note) {
    // 直接接收 Note 对象引用
    // note.strumTime  - 音符节拍时间
    // note.noteData   - 轨道方向
    // note.noteType   - 音符类型
    // note.isSustainNote - 长按判断
    // note.mustPress  - 是否为玩家轨道
    // note.gfNote     - 是否为 GF 音符
    // 等等所有 Note 属性可直接访问
}
```

当使用 `callOnScripts('goodNoteHit', [id, direction, noteType, isSustainNote])` 时，Lua 和 HScript 均接收 **4 个参数**。

```lua
function opponentNoteHit(id, direction, noteType, isSustainNote)
    -- 对手命中音符时触发（参数同 goodNoteHit Lua 版本）
end
```

```lua
function noteMissPress(direction)
    -- 按键失误（空按）时触发
    -- direction: Int - 0=左, 1=下, 2=上, 3=右
end

function noteMiss(id, direction, noteType, isSustainNote)
    -- 音符离开屏幕未命中时触发
    -- 参数同 goodNoteHit
end
```

### 音符生成

```lua
function onSpawnNote(id, direction, noteType, isSustainNote)
    -- 音符被添加到活躍音符列表时触发
    -- id: Int - 音符在 'notes' 组中的索引
    -- direction: Int - 轨道方向
    -- noteType: String - 音符类型
    -- isSustainNote: Bool - 长按判断
end
```

### 键盘输入

```lua
function preKeyPress(key)
    -- 按键按下前触发（在命中检测之前）
    -- key: Int - 轨道索引 (0-7)
end

function onKeyPress(key)
    -- 按键按下后触发（在动画播放之后）
    -- key: Int - 轨道索引 (0-7)
end

function onKeyRelease(key)
    -- 按键释放时触发
    -- key: Int - 轨道索引
end

function onGhostTap(key)
    -- 幽灵按键（按下但无音符命中）时触发
    -- key: Int - 轨道索引
end
```

### 评分

```lua
function onUpdateScore(miss)
    -- 分数更新时触发（每次评分计算后）
    -- miss: Bool - 是否为失误（true = 失误，false = 命中）
end

function onRecalculateRating()
    -- 评分计算前触发
    -- 返回 Function_Stop 可使用自定义评分
    -- 使用 setRatingPercent() 和 setRatingString() 设置评分
    return Function_Continue;
end
```

### 相机

```lua
function onMoveCamera(focus)
    -- 相机聚焦变化时触发
    -- focus: String - 'boyfriend', 'dad' 或 'gf'
    if focus == 'boyfriend' then
        -- 聚焦到玩家
    elseif focus == 'dad' then
        -- 聚焦到对手
    elseif focus == 'gf' then
        -- 聚焦到 GF
    end
end
```

### 倒计时相关

```lua
function onCountdownStarted()
    -- 倒计时开始播放时触发（在 onStartCountdown 之后）
end
```

### 歌曲小节

```lua
function onSectionHit()
    -- 每小节切换时触发（在 onBeatHit 之后）
    -- 触发前自动设置以下变量：
    --   mustHitSection, altAnim, gfSection, curSection
end
```

### 事件

```lua
function onEvent(name, value1, value2)
    -- 事件音符触发时调用
    -- name: String   - 事件名称
    -- value1: String - 事件参数1
    -- value2: String - 事件参数2
    -- 注意：triggerEvent() 不会触发此函数！
end

function eventEarlyTrigger(name)
    -- 覆盖事件的提前触发时间（毫秒）
    -- 返回值将覆盖引擎的默认值
    -- 示例：if name == 'Kill Henchmen' then return 280; end
end
```

### 补间/计时器/音效

```lua
function onTweenCompleted(tag)
    -- 补间动画完成时触发
    -- tag: String - 补间标识（doTweenX 的第一个参数）
end

function onTimerCompleted(tag, loops, loopsLeft)
    -- 计时器循环完成时触发
    -- tag: String       - 计时器标识（runTimer 的第一个参数）
    -- loops: Int        - 设定的总循环次数
    -- loopsLeft: Int    - 剩余循环次数
end

function onSoundFinished(tag)
    -- 音效播放完成时触发（仅带 tag 参数播放的音效）
    -- tag: String - 音效标识（playSound 的 tag 参数）
end
```

### 成就

```lua
function onCheckForAchievement(name)
    -- 成就检测处理
    -- name: String - 成就名称
    -- 返回 Function_Continue 表示成就达成条件满足
end
```

---

## 9. 脚本加载路径

### 优先级顺序

脚本文件按以下优先级搜索：

```
1. MOD 当前目录: mods/<currentMod>/data/states/<Name>.lua/.hx
2. MOD 全局目录: mods/<globalMod>/data/states/<Name>.lua/.hx
3. MOD 根目录:    mods/data/states/<Name>.lua/.hx
4. 基础路径:      assets/data/states/<Name>.lua/.hx
```

### 加载流程

```
initLuaScripts() / initHScripts()
├── 1. 独立文件: data/states/<Name>.lua (或 .hx/.hscript)
├── 2. 目录:     data/states/<Name>/*.lua (或 *.hx)
└── 3. 遗留:     lua/<stateName>/*.lua (或 hscripts/<stateName>/*.hx)
```

对于 **SubState**：
```
initLuaScripts() / initHScripts()
├── 1. 独立文件: data/states/<Name>.lua (或 .hx/.hscript)
├── 2. 目录:     data/states/<Name>/*.lua (或 *.hx)
└── 3. 遗留:     lua/substates/<substateName>/*.lua
                 (或 hscripts/substates/<substateName>/*.hx)
```

### PlayState 额外加载路径（独立于基类）

在 `PlayState.create()` 中，除了基类的 `initHScripts()` 和 `initLuaScripts()`，还额外加载以下脚本：

**全局脚本（scripts/ 目录）：**
```
scripts/*.lua / scripts/*.hx
├── mods/<currentMod>/scripts/    (最高优先级)
├── mods/<globalMod>/scripts/
├── mods/scripts/
└── assets/scripts/               (最低优先级)
```

**舞台脚本（stages/ 目录）：**
```
stages/<curStage>.lua / stages/<curStage>.hx
├── mods/stages/<curStage>.lua/.hx   (优先)
└── assets/stages/<curStage>.lua/.hx (回退)
```

PlayState 的加载顺序：
```
PlayState.create()
├── super.create()
│   ├── MusicBeatState.initHScripts()   ← 加载 data/states/<Name>.hx
│   └── MusicBeatState.initLuaScripts() ← 加载 data/states/<Name>.lua (如果调用)
├── 额外加载：scripts/*.lua              ← PlayState 特有
├── 额外加载：stages/<curStage>.lua      ← PlayState 特有
├── 额外加载：scripts/*.hx               ← PlayState 特有
└── 额外加载：stages/<curStage>.hx       ← PlayState 特有
```

### 全局 HScript

从 `hscripts/` 目录加载的全局 HScript 文件会在所有状态之前执行：

```
hscripts/
├── mods/<currentMod>/hscripts/*.hx    (最高优先级)
├── mods/<globalMod>/hscripts/*.hx
├── mods/hscripts/*.hx
└── assets/hscripts/*.hx               (最低优先级)
```

---

## 10. 常见用法示例

### 10.1 创建一个自定义菜单状态

**HScript** (`data/states/MyMenu.hx`):
```haxe
function onCreate() {
    var bg = new FlxSprite().loadGraphic(Paths.image('menuBG'));
    bg.screenCenter();
    add(bg);

    var title = new FunkinText(0, 50, FlxG.width, "My Mod Menu", 32);
    title.screenCenter(X);
    add(title);

    FlxTween.tween(title, {y: title.y + 10}, 0.5, {
        type: PINGPONG,
        ease: FlxEase.quadInOut
    });
}

function onUpdate(elapsed) {
    if (keyJustPressed('accept')) {
        FlxG.switchState(new PlayState());
    }
    if (keyJustPressed('back')) {
        FlxG.switchState(new MainMenuState());
    }
}
```

**启动方式**:
```haxe
FlxG.switchState(new ModState("MyMenu"));
```

### 10.2 Lua 自定义谱面事件

**Lua** (`data/states/MySong.lua`):
```lua
function onCreate()
    -- 创建自定义元素
    makeLuaSprite('myBgEffect', 'myEffectImage', 0, 0);
    setScrollFactor('myBgEffect', 0.5, 0.5);
    addLuaSprite('myBgEffect', false);
end

function goodNoteHit(id, direction, noteType, isSustainNote)
    if noteType == 'Health Bonus' then
        setHealth(getHealth() + 0.1);
    end
end

function onEvent(name, value1, value2)
    if name == 'MyCustomEvent' then
        -- 执行自定义逻辑
        setProperty('boyfriend.color', getColorFromHex(value1));
        doTweenAlpha('fadeTween', 'boyfriend', 0.5, tonumber(value2), 'linear');
    end
end

function onBeatHit()
    if curBeat % 8 == 0 then
        -- 每 8 拍触发一次闪光效果
        cameraFlash('camGame', '0xFFFFFFFF', 0.5);
    end
end
```

### 10.3 HScript 中的跨脚本通信

```haxe
// 通过 LuaApi 向 Lua 添加函数
LuaApi.addLuaFunction("myHelper", function(value) {
    return "Processed: " + value;
});

// 直接执行 Lua 代码
runLuaCode("
    result = myHelper('test')
    debugPrint(result)
");

// 导入其他 HScript 文件
importScript('data/states/Utils');
```

### 10.4 使用 ModSubState 创建暂停菜单

**HScript** (`data/states/MyPause.hx`):
```haxe
function onCreate() {
    var bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
    bg.alpha = 0.5;
    add(bg);

    var pauseText = new FunkinText(0, 200, FlxG.width, "Custom Pause", 48);
    pauseText.screenCenter(X);
    add(pauseText);
}

function onUpdate(elapsed) {
    if (keyJustPressed('pause') || keyJustPressed('back')) {
        close();
    }
}
```

**启动方式**:
```haxe
openSubState(new ModSubState("MyPause"));
```

---

## 11. 平台相关注意事项

### 11.1 编译平台检测

脚本系统中多处使用平台编译条件，编写跨平台 MOD 时需注意：

| 宏                      | 适用平台                     | 脚本系统影响                                |
| ----------------------- | ---------------------------- | ------------------------------------------- |
| `#if cpp`               | Windows/Linux/Mac (C++ 目标) | Discord Rich Presence、部分视频播放         |
| `#if !flash`            | 非 Flash 平台                | `FlxRuntimeShader` 着色器支持               |
| `#if sys`               | 桌面平台 (Windows/Linux/Mac) | 文件 I/O（`sys.FileSystem`, `sys.io.File`） |
| `#if windows`           | Windows                      | `buildTarget = "windows"`                   |
| `#if linux`             | Linux                        | `buildTarget = "linux"`                     |
| `#if mac`               | macOS                        | `buildTarget = "mac"`                       |
| `#if html5` / `#if web` | 浏览器                       | `buildTarget = "browser"`                   |
| `#if android`           | Android                      | Android 控件、虚拟手柄、返回键处理          |

### 11.2 平台相关的 Lua API 限制

```
仅桌面平台 (sys):
├── getTextFromFile(), saveFile(), deleteFile(), checkFileExists()
├── initLuaShader(), setSpriteShader() (需要 !flash && sys)
├── runHaxeCode() (需要 HSCRIPT_ALLOWED)
└── addHaxeLibrary() (需要 HSCRIPT_ALLOWED)

仅非 Flash 平台 (!flash):
├── FlxRuntimeShader 相关函数
└── ShaderFilter, ColorMatrixFilter

Android 特有:
├── AndroidControls / FlxVirtualPad 自动处理
├── BACK 键映射到 PAUSE
└── 触摸输入处理
```

### 11.3 编译标志依赖

```
LUA_ALLOWED     → FunkinLua, ModchartSprite/Text, DebugLuaText
HSCRIPT_ALLOWED → HScript, LuaApi
MODS_ALLOWED    → Mod 文件系统加载（影响脚本搜索路径）
VIDEOS_ALLOWED  → MP4/FLV 视频播放（hxCodec）
```

### 11.4 PlayState 中的脚本系统细节

PlayState 重写了基类的脚本方法以实现更复杂的回调逻辑：

**`callOnScripts()`** — PlayState 独有的中枢方法：
```haxe
PlayState.callOnScripts(funcToCall, args, ignoreStops, exclusions, excludeValues)
├── 默认 excludeValues = [Function_Continue]
├── callOnLuas(funcToCall, args, ...)
│   ├── Function_StopLua → 中断 Lua（HScript 继续）
│   ├── Function_StopAll → 中断所有
│   └── Function_Continue → 继续
└── 如果 Lua 返回 null 或 excludeValues 中的值
    └── callOnHScript(funcToCall, args, ...)
        └── Function_StopHScript → 中断 HScript
```

**`callOnLuas()`** — 重写自 MusicBeatState：
- PlayState 版本在遍历过程中会**自动清理已关闭的脚本**
- 处理 `Function_StopLua` 和 `Function_StopAll`

**`callOnHScript()`** — PlayState 自有的方法（不是重写）：
- 仅在 `hscriptArray` 非空时执行
- 检查脚本是否含有目标函数（`script.exists()`）
- 处理 `Function_StopHScript` 和 `Function_StopAll`

**`setOnScripts()`** — 同时设置 Lua 和 HScript：
```haxe
PlayState.setOnScripts(variable, arg, exclusions)
├── setOnLuas(variable, arg, exclusions)
└── setOnHScript(variable, arg, exclusions)
```

### 11.5 HScript 错误处理

- 由 `ClientPrefs.data.hscriptErrorHandling` 控制
- 启用时：弹出错误对话框并显示在 `TraceManager` 日志中
- 禁用时：错误静默忽略，脚本自动关闭（`closed = true`）

---

## 12. 故障排除

### Lua 脚本不执行

1. 确认编译时启用了 `LUA_ALLOWED`
2. 检查脚本路径是否正确：
   - `data/states/<StateName>.lua` — 使用状态类名
   - 或 `data/states/<ModState名>.lua` — 使用 ModState 名称
3. 检查文件是否存在于正确的 MOD 目录中
4. 运行时可查看 `TraceManager` 日志中的错误信息

### HScript 不执行

1. 确认编译时启用了 `HSCRIPT_ALLOWED`
2. 检查文件扩展名（支持 `.hx`, `.hscript`, `.hsc`, `.hxs`）
3. 确认 `ClientPrefs.data.hscriptErrorHandling` 已启用以查看错误弹窗
4. 检查 `data/states/<Name>.hx` 路径是否正确

### 常见错误

| 问题                                 | 可能原因           | 解决方案                                |
| ------------------------------------ | ------------------ | --------------------------------------- |
| Lua 报 "attempt to call a nil value" | 函数未定义         | 检查函数名拼写                          |
| HScript 报 "Variable doesn't exist"  | 变量未绑定         | 检查 `setOnHscript` 是否已设置          |
| 脚本未自动加载                       | 文件名或路径不匹配 | 使用 `TraceManager` 检查实际加载路径    |
| 跨脚本通信失败                       | 脚本名不匹配       | 使用 `getRunningScripts()` 检查实际名称 |
| 补间/计时器未触发完成回调            | tag 冲突           | 确保每个补间/计时器使用唯一的 tag       |

---

> 本文档对应 MohongEngine 脚本系统版本 Lua 0.63.1fix-2 / HScript 0.2.0
