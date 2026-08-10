Add .lua and hscript(only PlayState) scripts here!
Lua scripts in this folder will be loaded on all songs, no matter the difficulty, song name, week or anything.

If you've put it inside a modpack, as long as the modpack is loaded, the script will be running.

SeiunEngine Lua 示例：
  seiun_lua_demo.lua - 展示 require / import、CustomSubstate、
  switchToModState 等新增 API（F5 / F6 触发演示，不影响正常玩法）。
配套的模块文件在 ../lua/lib/utils.lua，自定义 state 示例在
../data/states/SeiunLuaDemoState.lua。

SeiunEngine Lua examples:
  seiun_lua_demo.lua - demos require / import, CustomSubstate,
  switchToModState and other new APIs (F5 / F6 trigger the demo, gameplay
  is unaffected). The module file lives in ../lua/lib/utils.lua and the
  custom state example in ../data/states/SeiunLuaDemoState.lua.
