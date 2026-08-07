# SeiunEngine 多k (Extra Keys) 移植说明

基于 Psych Engine 0.6.3 第三方多k版本 (EK extra keys) 移植，并按要求：

- **Note 复用原版 4 个纹理** (left/down/up/right)，不新增多k图片资源。
- **Space 键使用 up 纹理**（`SPACE` strum 动作映射为 `UP`）。
- **颜色复用 0.6.3 ColorSwap 着色器**：以 4 个基底纹理色 + 目标色差值（色相偏移/饱和度/亮度）推导多k颜色。
- **谱面格式兼容 EK**：谱面 JSON 增加 `mania` 字段（0 基，3 = 4K，8 = 9K，17 = 18K），旧 4K 谱面无该字段时按 4K 处理。

## 支持的 K 值

- 游戏内支持 1K ~ 18K。
- 1K~9K 采用 EK 原版轨道布局/动作；**10K~18K 按 9K 循环**（第 10 轨起循环第 1~9 轨的材质与动作），符合"xxxxxxxxx xxxx（开始循环前面的材质）"的要求。
- 两个谱面编辑器均支持 1K~18K 编辑（切换键数后格子自动缩小/增宽），9K 以上自动循环材质。

## 谱面格式

```json
{
  "song": {
    "song": "example",
    "mania": 8,
    "notes": [
      {
        "mustHitSection": true,
        "sectionNotes": [
          [0, 4, 0, ""]
        ]
      }
    ],
    ...
  }
}
```

- `mania: 3` = 4K；`mania: 8` = 9K；`mania: 17` = 18K。
- 音符数据范围：玩家侧 `0 ~ mania`，对手侧 `mania+1 ~ mania*2+1`（与 0.6.3 的 4K/8K 规则一致，只是基数变成当前键数）。
- 4K 谱面在编辑器中导出时可选择**是否导出 `mania` 字段**（默认不导出，最大化兼容旧引擎）；非 4K 谱面导出时强制写入 `mania`（无法去掉）。

## Change Mania 事件

两个谱面编辑器的事件列表中均有 `Change Mania`：

```text
Value 1: 新的键数 (1-18, 例如 9 = 9K)
Value 2: 填 true 跳过 strum 淡出过渡
```

游戏内置过渡动画：旧 strum 淡出（0.3s）→ 按新键数重建 strum。已生成的 Note 保留生成时的 k 值快照继续渲染/判定，直到销毁；之后新生成的 Note 使用新 k 值。

### 编辑器中的分段网格（2026-08 改进）

- 两个谱面编辑器的网格现在**按 Step 精确切分**：Change Mania 事件落在哪一行，
  网格就在那一行从基准键数（如 4K 4+4 列）切换成新键数（如 9K 9+9 列）。
  事件前的内容显示 4K 网格、事件后的内容显示 9K 网格，**不再需要播放经过事件
  才切换，也不再把整个小节一刀切**。
- 每个网格段（含事件切分出来的段）有自己的列数与玩家/对手分隔线；段与段共用
  同一左起点，事件前的 4K Note 与事件后的 9K Note 各归各位。
- 上下滚动切节时，分段网格会按新的“上/中/下”三窗小节自动重建，不会停留在
  旧小节导致错位；主网格列数也随窗口小节重建，切到 9K 小节时网格立即是 9K 列数。
- 放 Note / 幽灵箭头的列范围按鼠标所在位置的生效键数限制：4K 段只能点到 0~7 列，
  9K 段才允许点到 0~17 列，不会在 4K 段点到 9K 列造成错位。
- 一个小节内可以放**多个** Change Mania 事件（如 4K→9K→5K），每个事件按实际
  时刻切分一段网格；同一步内的多个事件取最晚时刻，事件数组乱序也不影响结果。
- 分段网格始终渲染在音符/事件图标之下，不会遮挡或拦截点击。
- “多k工具”浮动窗口关闭时彻底移出状态，不会再被原位置的点击误触发。
- Note 的轨道解释按 **Note 自身时间点**的生效键数进行（事件前 4K 轨道 0~7，
  事件后 9K 轨道 0~17），不再跟随播放头的 k。
- 播放/滑动经过事件时，只有跨 k 导致格宽变化（如 10K+）才重建网格；
  4K↔9K 等格宽相同的切换不再整段重建，避免闪烁。

### 事件驱动的切 K 转换（2026-08 改进）

当 **Change Mania 事件被新增、删除、拖动或修改键数/时间**时，受影响区间的 Note
会按“多k工具”里选中的转换模式自动重编码：

- `顺序映射`：side（玩家/对手）保持，轨道号按新键数取模（4K→9K 时旧 0~3 轨
  保持原轨道，新增轨道留空）。
- `自动打乱` / `打乱+补双押`：仅在新键数更多时，对 (side, 旧键数, 时间) 组做
  确定性重排 / 单押补双押，与手动切 K 的算法一致。
- 键数输入框（Value 1）在输入结束后（焦点移开）才执行一次转换，避免逐字符
  中间状态（如 9 → 12 时不会先退化成 1K 再转 12K）。

### 游戏内 Note 解释（2026-08 改进）

实际游玩/试玩时，Note 同样按自身时间点的生效键数解释轨道（lane = data % 当前段键数，
side = data < 当前段键数）。无 Change Mania 事件的谱面行为与旧版完全一致。

### 已知限制

- 事件编辑触发的 Note 重编码是数据修改，**撤销（Ctrl+Z）不会还原被转换的 Note 数据**
  （事件对象本身会撤销，Note 轨道数据保持转换后的状态）。
- 用“键数步进器”切换基准 k 仍是整表转换，不会按 Change Mania 事件分段（该场景
  建议先删事件或用工具模式手动处理）。
- 补双押模式会新增 Note；反复在 9K↔4K 之间切换可能造成轨道坍缩（与手动切 K 行为一致）。

## Lua API

```lua
-- 当前键数 (1 基)
local k = getMania()

-- 修改指定 Note 的材质 (索引来自 notes 组)
setNoteTexture(noteIndex, "NOTE_assets")

-- 修改指定 Note 命中时的角色动作 (不传/空则按轨道默认)
setNoteCharAnim(noteIndex, "singLEFT")

-- 直接修改指定 Note 颜色 (hue 0~360, sat 0~100, brt 0~100)
setNoteColor(noteIndex, 60, 100, 100)

-- 切换当前谱面 K 值 (1~18), 第二个参数跳过过渡动画
setMania(9)
changeMania(9, true)

-- 回调: 切 K 后触发
function onChangeMania(newMania, oldMania)
    -- newMania / oldMania 为 0 基
end
```

## HScript API

```haxe
getMania();                       // 当前键数 (1 基)
setMania(9);                      // 切换 K 值
changeMania(9, true);             // 切换 K 值 (跳过过渡)
setNoteTexture(noteIndex, "NOTE_assets");
setNoteCharAnim(noteIndex, "singLEFT");
setNoteColor(noteIndex, 60, 100, 100);

// 或直接调用 PlayState 方法
PlayState.instance.changeMania(8, false);
PlayState.instance.setNoteTextureByIndex(0, "NOTE_assets");
PlayState.instance.setNoteCharAnimByIndex(0, "singLEFT");
PlayState.instance.setNoteColorByIndex(0, 60, 100, 100);
```

HScript 也支持 `function onChangeMania(newMania, oldMania) {}`。

## 输入说明 (2026-08 修复)

- **4K 谱面**沿用原版 Controls 动作系统（键盘/手柄/安卓按键完全不变）。
- **多k 谱面**所有轨道直接轮询各自的键位绑定（`note_nine1` 等），因此用户在
  “EK KEYS”里改绑的多k键位（包括数字小键盘键）会立即生效，不再受 4K 键位影响。
- 屏幕上的按键显示 (KeyboardDisplay) 会按当前谱面键数显示全部轨道。
- 安卓端多k谱面仍只使用 FlxHitbox，全部色块（含 0-3 轨）直接驱动按键。

## 编辑器键数切换

- 两个编辑器切换键数时都做了防抖（值未变化不重载），并去掉重复整表刷新，
  避免大谱面下每点一次步进器就整表重载造成的卡顿。
- 修复歌曲页键数步进器与"Player 下拉框"重叠的问题（旧版编辑器把步进器放在了
  角色下拉框的同一位置，导致界面重叠且 +/- 按钮被盖住、点不到更高键数）。
- 新编辑器键数步进器挪到独立一行，避免被标签页边缘裁切。
- 轨道箭头（strum）静态状态保持原版统一的灰箭头（不随轨道变色）。
- 切换键数带异常保护：即使某一步重建失败，也不会让编辑器停留在半重建状态。
- 切K流程已对照 EK 0.6.3 源码统一：reloadGridLayer 内同步 PlayState.mania 并重建
  strum 列，handler 只做 `_song.mania = 新值 + reloadGridLayer()` 一件事。
- **修复"切K后 UI 重复/小图标重叠"的根因**：旧实现把整个编辑器的 UI 构建
  （mainBox/infoBox/upperBox、全部标签页、角色头像、eventIcon、mustHitIndicator、
  selectionBox 等）误放进了 strum 重建函数，导致每次切K都把整套 UI 重新 add 一遍
  （成员数 28→43）。现在 UI 只在 create() 构建一次；切K仅重建网格/strum/音符并
  重排头部图标与分隔线。
- 旧版编辑器的键数步进器移到 (200,128)，不再与"加载自动保存"等按钮重叠。
- 两个编辑器 create() 与切K处理器都加了 TraceManager 日志（trace.editor.create /
  trace.editor.mania），用于排查"切K后是否重建了整个编辑器状态"。

## NotesSubState（选项 → Note 颜色）

- 9 个颜色轨道（A~I，对应 left/down/up/right/space/leftex1/downex1/upex1/rightex1）
  现在全部可以在原 UI（三枚 Note 轮播 + HSV 数值）中调整，UI 结构不变。
- 预览 Note 复用 4 个基底纹理，颜色用与游戏内一致的 ColorSwap（基底色差 + 用户偏移）
  推导，因此看到的颜色就是实际轨道颜色。
- 老存档 arrowHSV 只有 4 项时会在加载时自动补足到 9 项。

## 屏幕按键显示 (KeyboardDisplay)

- 底部 KPS / 总数两个统计条现在会横向拉伸覆盖整行键宽（按当前键数）。
- 按键行按当前 K 值自动计算宽度，超出屏幕时整体向左收并夹在屏幕内，不会卡出屏外。
- 顶部按键、按压高亮、键名 label 均按当前谱面键数生成。

## 轨道材质说明

- 4K→5K 等切换时，已有音符数据不会自动重映射：旧谱面 2/3 轨（up/right）在
  5K 下会落到 space/up 轨（两者都复用 up 纹理），这是"space 使用 up"的预期结果；
  通过轨道颜色（space=灰、up=绿）区分。如需自动重排旧音符，可再加"重映射音符"按钮。
- 多k颜色依赖 ColorSwap 着色器：请在设置中保持"Shaders/着色器"开启，
  否则空间/扩展轨只能显示基底纹理色。

## 软编码配置

`assets/data/extraKeys/extraKeys.json`（或 `mods/<mod>/data/extraKeys/extraKeys.json`）可覆盖布局数据：

```json
{
  "scales": [0.9, 0.85, 0.8, 0.7, 0.66, 0.6, 0.55, 0.5, 0.46, 0.39, 0.36, 0.32, 0.31, 0.31, 0.3, 0.26, 0.26, 0.22],
  "gridSizes": [40, 40, 40, 40, 40, 40, 40, 40, 40, 35, 30, 25, 25, 20, 20, 20, 20, 15],
  "noteColors": [
    [194, 75, 153], [0, 255, 255], [18, 250, 5], [246, 56, 62],
    [204, 204, 204], [255, 255, 0], [139, 74, 255], [255, 0, 0], [0, 51, 255]
  ]
}
```

支持覆盖：`scales` / `gridSizes` / `splashScales` / `pixelScales` / `lessX` / `separator` / `offsetX` / `restPosition` / `noteColors` / `baseNoteColors`。

## 颜色表（0.6.3 近似）

| 轨道 | 颜色 |
| --- | --- |
| left | rgb(194,75,153) |
| down | rgb(0,255,255) |
| up | rgb(18,250,5) |
| right | rgb(246,56,62) |
| space | rgb(204,204,204) |
| leftex1 | rgb(255,255,0) |
| downex1 | rgb(139,74,255) |
| upex1 | rgb(255,0,0) |
| rightex1 | rgb(0,51,255) |

## 安卓

- 当前谱面非 4K 时，**只允许 FlxHitbox**（Pad 模式会自动回退到 Hitbox）。
- Hitbox 色块颜色 = 对应轨道的 Note 颜色。
- 4K 以上轨道直接驱动 `keyPressed/keyReleased`，同时保留 Replay 录制。

## 键位设置

选项 → 控制器 → 键盘按键中新增 `EK KEYS` 分类（1K~18K），仅在键盘模式下显示。默认键位移植自 EK 0.6.3（已修正 17K 键位笔误）。
