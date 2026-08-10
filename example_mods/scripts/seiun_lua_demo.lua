-- SeiunEngine Lua 示例脚本
-- 位置：example_mods/scripts/seiun_lua_demo.lua
-- English: SeiunEngine example script
-- Location: example_mods/scripts/seiun_lua_demo.lua
--
-- scripts/ 下的 Lua 会在 PlayState 加载，所有歌曲都会运行。
-- 本脚本只做演示，不影响玩法：
--   - onCreate 演示 require / import
--   - 按 F5 打开/关闭 CustomSubstate（并演示 insertToCustomSubstate）
--   - 按 F6 跳转到示例自定义 state（data/states/SeiunLuaDemoState.lua）
-- Lua scripts under scripts/ run on every song while PlayState is active.
-- This script only demonstrates features and does not affect gameplay:
--   - onCreate demonstrates require / import
--   - Press F5 to open/close a CustomSubstate (also demos insertToCustomSubstate)
--   - Press F6 to switch to the example custom state
--     (data/states/SeiunLuaDemoState.lua)

function onCreate()
	-- 1) require：带缓存，模块只执行一次
	--    English: require — cached, the module runs only once
	local utils = require("lib.utils")
	debugPrint("require: utils.double(21) = " .. utils.double(21))      -- 42
	debugPrint("require: utils.greet('neko') = " .. utils.greet("neko"))

	-- 2) import：每次重新执行（include 语义），计数器会递增
	--    English: import — re-executed every time (include), counter increments
	local u2 = import("lib/utils.lua")
	debugPrint("import #1: counter = " .. u2.bump())   -- 1
	local u3 = import("lib.utils")
	debugPrint("import #2: counter = " .. u3.bump())   -- 2（没有缓存）

	-- 3) state 信息工具
	--    English: state info helper
	debugPrint("current state = " .. getStateName())

	makeLuaText("demoHint",
		"Seiun Lua Demo: F5 = CustomSubstate, F6 = Switch to ModState", 1100, 90, 690)
	setTextSize("demoHint", 16)
	addLuaText("demoHint")
end

function onUpdate(elapsed)
	-- F5：开关 CustomSubstate；F6：切换到自定义 state
	-- English: F5 toggles CustomSubstate; F6 switches to the custom state
	if keyboardJustPressed("F5") then
		if getSubStateName() == "CustomSubstate" then
			closeCustomSubstate()
		else
			openCustomSubstate("seiunDemo")
		end
	end

	if keyboardJustPressed("F6") then
		switchToModState("SeiunLuaDemoState", { from = "PlayState" })
	end
end

-- CustomSubstate 事件：打开时创建内容，并用 insertToCustomSubstate
-- 把 PlayState 里已创建的对象移进 CustomSubstate
-- English: CustomSubstate events — create content on open, then use
-- insertToCustomSubstate to move objects created in PlayState into it
function onCustomSubstateCreate(name)
	debugPrint("CustomSubstate opened: " .. name)
	makeLuaText("csTitle", "Custom Substate: " .. name, 800, 240, 280)
	setTextSize("csTitle", 48)
	setTextAlignment("csTitle", "center")
	addLuaText("csTitle")

	makeLuaText("csHint", "Press F5 to close", 400, 440, 380)
	addLuaText("csHint")

	-- 把上面两个文本从 PlayState 移进 CustomSubstate
	insertToCustomSubstate("csTitle", 0)
	insertToCustomSubstate("csHint", 1)
end

function onCustomSubstateUpdate(name, elapsed)
	-- 这里可以做每帧逻辑，例如：
	-- setProperty("csTitle.x", getProperty("csTitle.x") + 1)
	-- English: per-frame logic goes here, e.g.
	-- setProperty("csTitle.x", getProperty("csTitle.x") + 1)
end

function onCustomSubstateDestroy(name)
	debugPrint("CustomSubstate closed: " .. name)
end
