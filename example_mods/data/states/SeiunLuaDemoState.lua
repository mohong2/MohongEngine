-- SeiunEngine 示例：Lua 自定义 state（ModState）
-- 位置：example_mods/data/states/SeiunLuaDemoState.lua
-- English: SeiunEngine example — Lua custom state (ModState)
-- Location: example_mods/data/states/SeiunLuaDemoState.lua
--
-- 进入方式：脚本里调用 switchToModState("SeiunLuaDemoState")
--           （例如 example_mods/scripts/seiun_lua_demo.lua 里按 F6）
-- 加载规则：MusicBeatState 会从 data/states/<name>.lua、
--           data/states/<name>/ 目录、lua/<name>/ 目录加载脚本。
-- How to enter: call switchToModState("SeiunLuaDemoState") from any script
-- (e.g. press F6 in example_mods/scripts/seiun_lua_demo.lua).
-- Loading: MusicBeatState loads scripts from data/states/<name>.lua,
-- the data/states/<name>/ folder, and the lua/<name>/ folder.

function onCreate()
	debugPrint("SeiunLuaDemoState: onCreate, current state = " .. getStateName())
	debugPrint("SeiunLuaDemoState: data = " .. (data ~= nil and tostring(data.from) or "nil"))

	makeLuaText("stateTitle", "Seiun Lua Demo State", 800, 240, 220)
	setTextSize("stateTitle", 44)
	setTextAlignment("stateTitle", "center")
	addLuaText("stateTitle")

	makeLuaText("stateHint", "Press ESC to go back to Main Menu", 600, 340, 320)
	addLuaText("stateHint")

	-- 也可以打开 ModSubState 演示（按 ENTER）
	makeLuaText("subHint", "Press ENTER to open a ModSubState", 600, 340, 360)
	addLuaText("subHint")
end

function onUpdate(elapsed)
	if keyboardJustPressed("ESCAPE") then
		switchToState("MainMenuState")
	end

	if keyboardJustPressed("ENTER") then
		openModSubState("SeiunLuaDemoSubState", { from = "SeiunLuaDemoState" })
	end
end
