SeiunEngine Lua 示例目录
SeiunEngine Lua Example Folder
==============================

这个目录有两个用途：
This folder has two purposes:

1. Legacy 路径：lua/<StateName>/ 下的 .lua 会被对应状态加载
   （例如 lua/PlayState/ 里的脚本会在 PlayState 运行时加载，
    等价于 data/states/PlayState/ 目录，但优先级更低）。
   Legacy path: .lua files under lua/<StateName>/ are loaded by that state
   (e.g. lua/PlayState/ scripts run while PlayState is active; equivalent to
   data/states/PlayState/ but with lower priority).

2. require / import 模块存放处：
   - lib/utils.lua 是本示例的模块文件；
   - 脚本里用 require("lib.utils")（带缓存，只执行一次）
     或 import("lib/utils.lua")（每次重新执行）加载它。
   require / import modules:
   - lib/utils.lua is the example module file;
   - scripts load it via require("lib.utils") (cached, runs once)
     or import("lib/utils.lua") (re-executed every time).

详细说明见 Modding.md 的 "Lua require()" 与 "Lua import()" 章节。
See Modding.md -> "Lua require()" and "Lua import()" for details.
