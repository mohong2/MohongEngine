# Friday Night Funkin' - Seiun引擎 (SeiunEngine)

这是一个分支!!!!(基于Psych引擎 0.6.3)。本引擎将在 Mandela Funkin Night模组正式发布后停止更新!!!

> 📖 本文件为**中文精简版**。完整（纯英文）文档请查看 [**README.md**](README.md)。
> 📚 脚本 API 完整分类文档（中英双语的 HTML 页面）见 [**docs/script-api/index.html**](docs/script-api/index.html)，每个 Lua 函数均标注了 Psych 版本来源。

## 版本状态
- **引擎版本**：`0.2.1`（由 `Project.xml` 的 `<app version>` 控制）
- **Psych 兼容版本**：`0.6.4`（写死在源码）
- **FNF 游戏版本**：`0.2.7.1`（写死在源码）

## 安装指南
你必须安装 [Haxe 4.2.5](https://haxe.org/download/)，说真的，别再使用4.1.5了，它缺少一些功能。

Haxelib需要安装以下库：
* hxCodec - 任意版本（Android 必须用 2.5.1）
* linc_luajit - Git版本（https://github.com/nebulazorua/linc_luajit）
* flixel - 4.11.0
* flixel-addons - 2.11.0
* flixel-ui - 2.4.0
* hscript-iris - 1.1.3
* lime - 8.0.1
* openfl - 9.2.1
* tjson - 1.4.0（构建使用，我也不确定该用哪个版本）

## 构建
- `art\build_x64.bat` → Windows 64位 Release（`export/release/windows/bin`）
- `art\build_x64-debug.bat` → Windows 64位 Debug
- `art\build_html.bat` → HTML5 Release
- `art\build_x32.bat` → Windows 32位 Release

## 脚本 API 文档（Lua + HScript）
| 模块 | 链接 |
|---|---|
| 脚本 API 总览 | [docs/script-api/index.html](docs/script-api/index.html) |
| Lua 快速开始 | [docs/script-api/lua-quickstart.html](docs/script-api/lua-quickstart.html) |
| Lua 脚本钩子 | [docs/script-api/lua-hooks.html](docs/script-api/lua-hooks.html) |
| Lua 全局函数(上) | [docs/script-api/lua-functions-1.html](docs/script-api/lua-functions-1.html) |
| Lua 全局函数(下) | [docs/script-api/lua-functions-2.html](docs/script-api/lua-functions-2.html) |
| Lua 全局变量 | [docs/script-api/lua-globals.html](docs/script-api/lua-globals.html) |
| HScript 快速开始 | [docs/script-api/hscript-quickstart.html](docs/script-api/hscript-quickstart.html) |
| HScript 环境与 API | [docs/script-api/hscript-environment.html](docs/script-api/hscript-environment.html) |
| HScript 与 Lua 互操作 | [docs/script-api/hscript-interop.html](docs/script-api/hscript-interop.html) |
| 模组开发进阶 | [docs/script-api/modding-advanced.html](docs/script-api/modding-advanced.html) |

## Seiun引擎制作名单:
* mo_hong - 修改与中文翻译
* Li.tmc - 引擎图标 

## Psych引擎制作名单: 
* Shadow Mario - 程序员
* RiverOaken - 美术
* Yoshubs - 助理程序员

## Codename引擎致谢:
* Codename引擎团队（[CodenameCrew](https://github.com/CodenameCrew)） - 本引擎的 ModState 脚本化状态与 `pack.json` 模组 API（`stateReplacements`/`substateReplacements`、CNE 谱面导入导出）参考了 Codename Engine 的设计。Seiun引擎不是 Codename Engine 的分支，而是基于 Psych 引擎实现的 CNE 兼容格式；本仓库不包含 Codename Engine 的源代码。

### 特别鸣谢
* bbpanzu - 前程序员 
* shubs - 新输入系统
* SqirraRNG - 崩溃处理程序和图表编辑器波形基础代码
* KadeDev - 修复了图表编辑器等问题并提交PR
* iFlicky - Psync和Tea Time作曲者，兼对话音效制作
* PolybiusProxy - .MP4视频加载库(hxCodec)
* Keoiki - 音符飞溅动画
* Smokey - 精灵图集支持
* Nebula the Zorua - LUA JIT分支及部分Lua重写
