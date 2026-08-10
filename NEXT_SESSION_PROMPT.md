# SeiunEngine 引擎交接提示词（下个对话直接用）

> 把下面整段内容粘给新会话。新会话必须先读仓库根目录的 AGENTS.md（角色/诚实/备份规则），
> 再按本文档的“重要技术事实”和“bug 清单”工作。所有结论必须标【已验证】/【推断】/【猜测】。

---

## 一、项目信息

- 引擎：FNF PsychEngine 0.6.3 分支深度改造的 **SeiunEngine**，带**多k（1K~18K）**支持。
- 路径：`O:\FNF-PsychEngine-0.6.3\FNF-PsychEngine-0.6.3\FNF-SeiunEngine`
- 构建：`lime build windows -release`（**构建前先关闭正在运行的 SeiunEngine.exe**，否则 lime.ndll 被占用会失败）。
- 工具链：Haxe 4.2.5（Project.xml 用 hxcpp 4.2.1 / lime 8.0.1）。
- 工作区有大量用户未提交改动：**只做增量修改，禁止 git checkout/reset/rm**，改前先 `git status`。
- 本地参考仓库：
  - 0.7.3：`O:\FNF-PsychEngine-0.6.3\FNF-PsychEngine-0.6.3\FNF-PsychEngine-0.7.3`
  - 1.0.4：`O:\FNF-PsychEngine-0.6.3\FNF-PsychEngine-0.6.3\FNF-PsychEngine-1.0.4`
  - EK 0.7.3（extra keys 多k）：`O:\FNF-PsychEngine-0.6.3\FNF-PsychEngine-0.6.3\FNF-PsychEngine-EK-0.7.3`
  - EK extra keys 0.6.3（归档多k版）：`O:\FNF-PsychEngine-0.6.3\FNF-PsychEngine-0.6.3\FNF-PsychEngine-EK-extra-keys-pe-0.6.3`

## 二、重要技术事实（先读代码确认，别凭记忆）

1. **两套 Note 图集差异**：
   - 0.6.3 flat `NOTE_assets`（`assets/shared/images/NOTE_assets.*`）：自带箭头颜色 + **frameX/frameY**，Note 定位代码（`followStrum` 的 +55、offsetX 等）按它校准。
   - 0.7.3 `noteSkins/NOTE_assets`（`assets/shared/images/noteSkins/NOTE_assets.*`）：**白底材质**、**无 frameX/frameY** → 必须靠 rgbShader（arrowRGB）染色，且用 0.6.3 定位会**位置偏移**。
2. `noteSkins/NOTE_assets` 每个方向的**滚动帧只有 1 帧**（`purple0000` 无 0001~0003）；**press/confirm 才有 4 帧动画**（`purple press/confirm 0000~0003`）。预览要动画必须用 press/confirm。
3. **多k 颜色模型**：`arrowHSV` 9 槽（A~I）；`arrowRGB/arrowRGBPixel` 已扩到 9 槽（space 默认镜像 UP 色板，见 ClientPrefs）。轨道→基底纹理用 `EKData.getBaseTexture(mania, lane)`；**SPACE→UP** 由 `EKData.letterBaseTexture['E'] => 2` 保证（只换材质，不用 SPACE 专属资源）。
4. **`colArray` 必须是 Note 实例字段**（0.6.3 模组用 Lua 反射读写 `note.colArray`，改 static 会让反射取到 null 直接崩）——**严禁改成 static**。
5. `ClientPrefs.data` / `defaultData` 是 `@:structInit` 类，`= {}` 就是带默认值的新实例（不是空对象）。
6. **DCE 陷阱**：`Type.resolveClass('options.xxx')` 字符串反射的类如果没有任何代码按类型引用，会被 Haxe DCE 裁掉 → 运行时 resolve 成 null → 回退 ModSubState → 黑屏退不出。**新 UI 类必须在 OptionsState 里硬编码 `new`**（例：`case 'notecolor_rgb': openSubState(new options.NotesSubStateNew());`）。
7. 改 `assets/preload/data/options/*.json`、`assets/lang/*/option.json` 后要重新构建才进包（`export/release/windows/bin/assets/...`）。
8. `Paths.atlasFramesCache` / `Note.noteAnimFrames` 在状态切换时清空（clearStoredMemory），换 mod 不会串图。
9. `OptionLoader.postProcessOptions` 有按 variable 的动态选项钩子；选项可用 `"compat": "0.7.3+"` 门控（只在 0.7.3/1.0.4 兼容模式显示）。

## 三、已实现的功能（修 bug 时别重做，但要回归验证）

1. **三引擎兼容设置**：`backend/CompatEngine.hx`（Auto/0.6.3/0.7.3/1.0.4），ClientPrefs `compatEngine` + 旧 `compatibility_mode` 兼容；PlayState 各分支、`goodNoteHitPre`/`opponentNoteHitPre`、Lua/HScript 全局 `compatEngine`。
2. **NoteSplash 池化修复**：动画逐组探测（maxAnims）、坏动画 0.5s/总存活 2s 超时回收、`textureLoaded` 补赋值、0.7.3 txt / 1.0.4 json 配置解析（动画前缀/fps/偏移）、配置缓存按谱面清理、预加载 alpha=0.000001、`spawnNoteSplash` 第五参 strum。
3. **rgbShader 系统**：`shaders/RGBPalette.hx`（RGBPalette / RGBShaderReference 懒挂载+fallbackShader+forceDisabled / GLSL）；Note、StrumNote 挂 rgbShader；`arrowRGB` 9 槽；`Note.initializeGlobalRGBShader` 按轨道取色（SPACE→UP）。
4. **0.7.3 材质兼容**：`Note.reloadNote` 检测 `noteSkins/*` → 自动用 rgbShader 染色（白底材质）；0.6.3 flat 继续 ColorSwap；`StrumNote.useRgbColor` 同理。
5. **皮肤切换**：`Note.getNoteSkinPostfix`/`defaultNoteSkin`（按 `noteStyle` 设置动态返回）、StrumNote.reloadNote 拼后缀（文件存在才换）；设置 → Visuals 的 **Note 皮肤**（0.7.3+ 门控）与**溅射皮肤**（全模式）下拉；皮肤预览（4 个 StrumNote 滑入/滑出 + 实时刷新）。
6. **旧版/新版 Note 设置**：`noteStyle`（Old=flat NOTE_assets / New=noteSkins/NOTE_assets），独立于兼容模式。
7. **两个 Note 颜色编辑器并存**：旧版 `options.NotesSubState`（HSV 多k，从 git 恢复）；新版 `options.NotesSubStateNew`（EK 0.7.3 RGB 色轮，9 槽三连轮播，press/confirm 动画，0.7.3 材质）。

## 四、当前 bug 清单（按严重程度排序，全部要修）

1. **溅射粒子一堆 bug（用户原话“更是一堆bug”）**：
   - 游戏中溅射**出现位置错误**（与 0.7.3 原版不一致）。
   - 溅射**不染色**（NoteSplash 仍走 colorSwap 的 hue/sat/brt，0.7.3 的 rgbShader/RGBPalette 染色没接入 NoteSplash）。
   - 溅射**皮肤更改后不生效/不像 0.7.3 那样生成**（后缀主路径已改，但需实测；要求设置更改后像原版一样立即生效）。
   - 历史问题：Silly BF V2 越玩越掉帧（原根因=溅射动画名不匹配永不 kill，已修，需回归确认）。
2. **游戏内 Note 位置错误**：noteStyle=New 或 0.7.3 自定义皮肤时箭头定位偏（0.7.3 图集无 frameX/frameY vs 0.6.3 定位校准），需要做位置兼容/校准。
3. **游戏内 Note 不染色**：0.7.3 白底材质已自动切 rgbShader（上一轮改的），**必须实测确认**；若仍不对，查 rgbShader 挂载时机、arrowRGB 色板、forceDisabled（SONG.disableNoteRGB）。
4. **设置更改要像 0.7.3 原版那样生成/生效**：Note 皮肤、溅射皮肤、Note 颜色等更改后应立即反映（预览 + 游戏内），现在仍有不一致。
5. **帧数蹦迪（FPS 周期波动）**：未根治。怀疑点：hxcpp GC（每颗 Note destroy 的垃圾）、`Paths.purgeUnusedGraphics()`（PlayState 每 900 帧）、谱面密度驱动的每帧开销。**需要先实测/记录波动周期再动手**，不要盲改。
6. **Note 皮肤预览（设置 → Visuals）**：选中才显示 + 切换实时更新材质（已修过：OptionsState 行号门控 + StrumNote.reloadNote 后缀），需回归确认。
7. **Note Colors (0.7.3)（NotesSubStateNew）**：黑屏退不出（DCE 已修）、9 槽轮播/动画/0.7.3 纹理（已改），需回归确认；**modeNotes（R/G/B 图标）等“其他选项”动画**用户点名说没有，检查是否还有静态无动画的地方。
8. **三引擎兼容未完全覆盖**：1.0.4 的加载顺序细节、`noteSplashData`（0.7.3+/1.0.4 的 Note 字段）shim 还没实现（之前约定后面做）、更多 0.7.3/1.0.4 API 差异待查。

## 五、修复原则与工作流

1. 先复现/读代码，再改；每个结论标【已验证】/【推断】/【猜测】；不编造文件路径、报错、测试数据。
2. **0.6.3 模组兼容优先**：colArray 实例字段、默认材质 flat NOTE_assets、模组反射接口不能断；旧版文件（NotesSubState 等）保留在 git HEAD 与 `source/options/_backup/`。
3. 删/覆盖前先备份或列清单；默认新建文件/打补丁。
4. 改完必须 `lime build windows -release` 编译通过，并让用户实测关键路径（进设置、进游戏、切皮肤/颜色/兼容模式）。
5. 构建前关闭 SeiunEngine.exe（进程名 SeiunEngine）。
6. 参考行为一律对照 0.7.3 原版源码（PlayState/NoteSplash/VisualsUISubState/NotesSubState），多k 部分参考 EK-0.7.3 与 EK-extra-keys-0.6.3。
