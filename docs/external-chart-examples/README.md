# 外部谱面格式支持（osu!mania / Malody / OSZ / MCZ）

新谱面编辑器（New Chart Editor）可以打开和保存 osu!mania (`.osu`)、
Malody (`.mc`) 谱面，以及包含多个难度和音频的谱面包（`.osz` / `.mcz`）。

## 使用方法

1. 在主菜单进入 **Chart Editor → New Chart Editor**。
2. **打开**：文件菜单 → Open Chart...，选择 `.json` / `.osu` / `.mc` /
   `.osz` / `.mcz` 文件。
3. **保存**：文件菜单 → Save...，在弹出的格式列表中选择
   `osu!mania (.osu)` 或 `Malody (.mc)`，并可选择导出键数
   （自动 / 4K / 8K）。

## OSZ / MCZ 谱面包

- `.osz` 是 osu! 的谱面压缩包，`.mcz` 是 Malody 的谱面包，里面通常有
  多个难度文件 + 音频。
- 打开后如果包里有多个难度，会弹出难度选择列表（显示
  `标题 [难度名] (osu!)/(Malody)`）。
- 选中的谱面会被转换，包内的音频会一并导入。

## 音乐自动导入

打开外部谱面时会弹出导入选项：

- **导入音乐**：默认勾选。勾选后可以选择导入方式：
  - **导入到磁盘 (mods/songs/)**：把谱面引用的音频（包内音频或谱面同目录
    下的音频文件）复制到 `mods/songs/<歌曲名>/Inst.<扩展名>`。编辑器会
    优先从 `mods/` 读取 `Inst.ogg` / `Inst.mp3` / `Inst.wav`，导入后
    谱面编辑器立即有音乐可听，且重启后依然有效。
  - **仅加载到内存 (RAM)**：直接把音频解码进内存，不写任何文件。适合
    只试听/临时体验的场景。⚠ 会提示玩家：仅本次会话有效、重启后失效、
    大体积音频会占用运存。
- 如果找不到音频（包内或同目录都没有），会提示"未找到音乐文件，已跳过"，
  谱面仍然可以正常打开编辑。

## 键位映射设置（不再写死）

### 导入时

打开 `.osu` / `.mc` / `.osz` / `.mcz` 时，可以在导入选项里选择：

- **保留原键数 (Auto)**：直接写入谱面的 `mania` 字段，1K~18K 原样保留
  （引擎多 K 系统已支持 18K），全部为玩家轨道。
- **压缩为 4K**：所有列按比例压缩进玩家 4 轨。
- **4K + 对手分边**：前半列给玩家、后半列给对手（经典 FNF 双人布局）。
- **自定义键数**：输入 1-18，把谱面压缩到任意 K。

### 导出时

保存为 osu!/Malody 时可在保存弹窗里选择键数：

- **自动 (chart K)**：跟随谱面的 `mania`（K = mania + 1）；有对手音符且
  2K ≤ 18 时导出 2K（前 K 列玩家、后 K 列对手）。
- **4K / 8K**：强制导出指定键数，多余轨道折叠进目标列。

多 K 外观（轨道缩放、间距、颜色、键位字母等）可通过
`assets/data/extraKeys/extraKeys.json`（或 mods 同名文件）高度自定义。

## 独立转谱器（osu! <-> Malody）

主菜单 → **Chart Editor → Chart Converter (osu!/Malody)**，提供两个方向的一键转换：

- **osu! -> Malody**：选择 `.osz` / `.osu`，输出一组 `.mc` 谱面 + 音乐 + 背景图
- **Malody -> osu!**：选择 `.mcz` / `.mc`，输出 `.osu` 谱面 + 音乐 + 背景图

特点：

- 包内**多难度全部转换**（如 Dan Course 的 LN/Regular 两套难度分别输出）；
- 难度名、键数（K 数）、BPM、变速、长条完整保留；
- 每张谱面引用自己的音乐（如 `audio.mp3` / `ln_stellium.mp3`）和背景图
  （如 `Dan_Stellium.png`），文件自动复制到输出文件夹；
- **转换时强制键数与源谱面一致**（直接从源文件读取 CircleSize /
  `mode_ext.column` 写回），并带轨道推断兜底——7K 转出来必然是 7K
  （`mode_ext.column` / `CircleSize` 正确写入）。
- **自动保存**：选完输入文件后立即转换并保存到默认输出目录 `converted/`
  （可在输入框修改路径），状态栏显示保存位置；全程 try/catch，不会卡死。
- **自动打包**：osu! -> Malody 直接生成 **`.mcz`**（内含全部 .mc + 音乐 +
  背景图），Malody -> osu! 直接生成 **`.osz`**——包内文件用标准 zip 存储
  模式，osu!/Malody 打开即用。
- **全局偏移修正**：转谱器提供 `Global offset (ms)` 输入框（默认 0），
  正值 = 音符延后、负值 = 音符提前，用于修正个别播放器/设备的偏移校准。
  转换本身已实测时间轴对齐（亚毫秒级误差，来自 192 细分量化）。

## 其他转换规则

- 打开时角色默认填充为 `bf` / `gf` / `dad`，速度为 1，`needsVoices` 为 false。
- **难度名会完整保留**：导入时读取 osu 的 `Version` / Malody 的
  `meta.version` 存入谱面，导出时写回 osu 的 `Version:` / Malody 的
  `meta.version`，不再写死为 "FNF"（无难度名时才回退）。
- BPM 变化完整保留；osu! 的继承时间点（负拍长）和 Malody 的 `effect/scroll`
  会转换为 Psych 的 "Change Scroll Speed" 事件。
- 长条（hold）双向转换，Malody 使用 192 细分、osu!mania 使用 hold 对象。
- GF 专属音符在导出到 osu!/Malody 时会被跳过（这两种格式没有 GF 轨）。

## 导出自动附带音乐

保存为 `osu!mania (.osu)` 或 `Malody (.mc)` 时，引擎会自动把当前歌曲的
伴奏（`mods/songs/<歌曲>/Inst.ogg|mp3|wav|m4a`，找不到则回退
`assets/songs/`）复制到谱面保存位置旁边，并且谱面里引用的音频文件名
（osu 的 `AudioFilename` / Malody 的 `sound`）会使用真实扩展名——
所以导出的谱面在 osu!/Malody 里打开就有音乐，不需要手动找文件。

- **Malody 特殊处理**：Malody 对 MP3 支持不稳定，因此当伴奏只有 MP3
  （例如从 osu 谱面包导入的音频）时，导出 Malody 会自动把 MP3 解码成
  16-bit PCM **WAV** 放在谱面旁边（`<歌曲名>.wav`），谱面引用对应的 WAV，
  并在保存提示中注明"已从 mp3 转换为 WAV 供 Malody 使用"。osu! 原生支持
  MP3，导出 osu 时保持原格式不变。
- 即使之前只把音乐导入了内存（RAM），导出 Malody 时也会从内存字节直接
  转成 WAV 落盘。

- 复制成功：保存提示会追加"音频已复制到谱面旁: 文件名"。
- 磁盘上和内存里都找不到任何音乐时：会提示"谱面已导出但未附带音频"，
  此时需要在谱面旁手动放置对应文件名的音频。

## MP3 音乐支持（Windows / Android 全平台）

引擎音频管线（lime 8.0.1）原生只能解码 OGG/WAV，MP3 会无声。现在内置了
**dr_mp3 原生解码器**（[hxdr_mp3](https://github.com/swordcube/hxdr_mp3)，
纯 C、MIT 协议，Windows 和 Android 都能编译运行），实现全平台 MP3 支持：

- **播放**：`Paths.inst()` 遇到 `Inst.mp3` 会自动解码成 WAV 播放（每次会话
  只解一次，带缓存），编辑器试听和正式游玩都能出声。
- **导入**：从 osu 谱面包 / 文件导入 MP3 时，磁盘模式自动转成 `Inst.wav`
  落盘（lime 直接可播），RAM 模式先解成 WAV 字节再加载进内存。
- **导出 Malody**：MP3 伴奏自动解码为 16-bit PCM WAV 放在谱面旁边
  （Malody 官方只认 OGG/WAV，MP3 不识别）。
- **导出 osu**：osu! 原生支持 MP3，保持原格式。

> MP3 解码器已**直接并入引擎源码**（`source/editors/content/dr_mp3.h` +
> `DrMp3.hx` + `DrMp3Tools.hx`，dr_mp3 为公有领域/MIT-0 协议），无任何外部
> haxelib 依赖，`lime build` 开箱即用。

## 修复：音频比谱面短时末尾音符消失

引擎原本在音乐文件播完的瞬间就结算关卡。如果导入的谱面比音频长（例如
Malody 谱面在音乐淡出后还有尾段），音乐结束时剩下的音符永远不会生成，
表现为"1分40秒后音符突然消失"。现已修复：音乐结束后虚拟时间继续推进，
剩余音符照常生成、可击打，全部处理完才进入结算；正常谱面的结束体验不变。

## 修复：编辑器不再"按音乐长度删谱面段落"

旧版 `_cacheSections()` 在缓存段落时间线时，一旦累计时间超过音乐文件长度，
就会把**后面的段落连同音符一起 `pop()` 删除**——所以谱面比音频长时
（或取整漂移导致时间线虚增时），第 64/65 段之后的所有 Note 全部消失；
切换多 K 触发重新缓存时也会反复发生，属于不可逆的数据损坏。现已修复：

- 缓存时**绝不删除/篡改**谱面段落和音符时间；
- 时间线用精确拍数推进（行数取整只影响网格行，不再污染真实时间）；
- 只有谱面比音乐短时才会向后补空白段落；
- 自动保存改为直接落盘 `backups/autosave.json`（FlxG.save 对大 JSON 有
  截断风险），"Open Autosave" 可直接读取恢复。

## 测试文件

- `example.osu`：4K osu!mania 谱面，120 BPM → 240 BPM 变速 + 2 倍速 SV。
- `example.mc`：4K Malody 谱面，与 example.osu 时间线等价（BPM 变奏、
  变速效果均在相同位置）。
- `example-package.osz`：测试用谱面包，内含上面两个难度 + 一段 1 秒静音
  音频（真实 MP3，文件名 `example.mp3`），可直接测试"多难度选择 + 音乐导入"
  流程。

`example.osu` 与 `example.mc` 时间线完全对应（42 个音符、4 个长条逐毫秒
对齐）：打开任一文件再导出为另一种格式，可验证往返转换的一致性。
