-- SeiunEngine 示例：Lua 自定义 substate（ModSubState）
-- 位置：example_mods/data/states/SeiunLuaDemoSubState.lua
-- English: SeiunEngine example — Lua custom substate (ModSubState)
-- Location: example_mods/data/states/SeiunLuaDemoSubState.lua
--
-- 打开方式：脚本里调用 openModSubState("SeiunLuaDemoSubState", data)
-- 关闭方式：closeModSubState()
-- How to open: call openModSubState("SeiunLuaDemoSubState", data) from any script
-- How to close: closeModSubState()

function onCreatePost()
	debugPrint("SeiunLuaDemoSubState: onCreatePost")
	debugPrint("SeiunLuaDemoSubState: data.from = " .. (data ~= nil and tostring(data.from) or "nil"))

	makeLuaText("subTitle", "Mod SubState Demo", 700, 290, 250)
	setTextSize("subTitle", 40)
	setTextAlignment("subTitle", "center")
	addLuaText("subTitle")

	makeLuaText("subHint", "Press BACKSPACE to close", 500, 390, 330)
	addLuaText("subHint")
end

function onUpdate(elapsed)
	if keyboardJustPressed("BACKSPACE") then
		closeModSubState()
	end
end
