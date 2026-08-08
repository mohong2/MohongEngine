# SeiunEngine（中文）

基于 Psych Engine 0.6.3 的 Friday Night Funkin' 引擎，为 Mandela Funkin Night 模组构建。

**[English](./README.md)**

## 支持的平台

- Windows
- macOS
- Linux
- Android
- iOS —— 能编，但没测过，能不能跑不知道

没有 HTML5 构建。

## 构建

需要 Haxe 4.2.5。

```sh
haxelib setup .haxelib
haxe -cp ./setup -main Main --interp
lime build windows
```

其他平台：`lime build mac`、`lime build linux`、`lime build android`、`lime build ios -arm64`。

也可以直接在 GitHub Actions 的 Build workflow 手动触发，选平台，跑完下载产物。

## 依赖

见 `hmm.json`。其中四个是我自己的 fork：

- flixel
- hxvlc
- extension-androidtools
- linc_luajit-rewriten

## Mod

把 mod 放进 `mods/`，参见 `Modding.md`。

## 制作人员

- **mo_hong** — 修改与中文翻译
- **Li.tmc** — 引擎图标
- **Psych Engine 团队**（Shadow Mario、RiverOaken、Yoshubs）— 基础引擎
- **Codename Engine 团队**（[CodenameCrew](https://github.com/CodenameCrew)）— 本引擎的 mod 系统参考了 Codename Engine 的 mod 格式（`pack.json`、`stateReplacements`/`substateReplacements`、谱面导入导出）。SeiunEngine **不是** Codename Engine 的分支，本仓库**不包含** Codename Engine 的任何源代码。Codename Engine 自身的条款请参阅 [Codename Engine 仓库](https://github.com/CodenameCrew/CodenameEngine)。
- 特别鸣谢：bbpanzu、shubs、SqirraRNG、KadeDev、iFlicky、PolybiusProxy、Keoiki、Smokey、Nebula the Zorua

## License

见 LICENSE（Psych Engine 的开源许可）。
