--[[
Mohong Engine 新版
如果 luattf == "English TTF" then -- 原生中文字体不支持

end

如果 luattf == "Chinese TTF" then -- 中文字体，支持中文显示，可用作双语显示

end
--]]

-- Lua 相关功能

function onCreate()
	-- 当Lua文件启动时触发，此时部分变量尚未创建
end

function onCreatePost()
	-- "create"阶段结束时触发
end

function onDestroy()
	-- Lua文件结束时触发（歌曲淡出完成后）
end


-- 游戏玩法/歌曲交互
function onBeatHit()
	-- 每小节触发4次（按节拍）
end

function onStepHit()
	-- 每小节触发16次（按步进）
end

function onUpdate(elapsed)
	-- "update"阶段开始时触发，部分变量尚未更新
end

function onUpdatePost(elapsed)
	-- "update"阶段结束时触发
end

function onStartCountdown()
	-- 倒计时开始时触发
	-- 如需阻止倒计时（用于触发对话等），可返回 Function_Stop
	-- 可通过 startCountdown() 重新触发倒计时
	return Function_Continue;
end

function onCountdownTick(counter)
	-- counter = 0 -> "三"
	-- counter = 1 -> "二"
	-- counter = 2 -> "一"
	-- counter = 3 -> "开始!"
	-- counter = 4 -> 无显示，但触发时机与 onSongStart 相同
end

function onSongStart()
	-- 乐器音轨和人声开始播放，songPosition = 0
end

function onEndSong()
	-- 歌曲结束/开始过渡时触发（解锁成就时会延迟）
	-- 返回 Function_Stop 可阻止歌曲结束（用于播放过场动画等）
	return Function_Continue;
end


-- 子状态交互
function onPause()
	-- 非过场动画时按下暂停键触发
	-- 返回 Function_Stop 可阻止玩家暂停游戏
	return Function_Continue;
end

function onResume()
	-- 从暂停状态恢复后触发（注意：不一定来自暂停界面）
end

function onGameOver()
	-- 角色死亡！生命值≤0时每帧触发
	-- 返回 Function_Stop 可阻止进入游戏结束画面
	return Function_Continue;
end

function onGameOverConfirm(retry)
	-- 游戏结束界面按 Enter/Esc 时触发
	-- 按 Esc 时 retry 值为 false
end


-- 对话系统（对话结束后会再次调用 startCountdown）
function onNextDialogue(line)
	-- 下一条对话开始时触发，对话行号从1开始
end

function onSkipDialogue(line)
	-- 跳过未播放完的对话时触发，对话行号从1开始
end


-- 音符命中/失误
function goodNoteHit(id, direction, noteType, isSustainNote)
	-- 玩家命中音符后触发（在命中计算完成后）
	-- id: 音符成员ID，可获取任意属性 例: "getPropertyFromGroup('notes', id, 'strumTime')"
	-- direction: 0 = 左, 1 = 下, 2 = 上, 3 = 右
	-- noteType: 音符类型标签
	-- isSustainNote: 是否为长按音符
end

function opponentNoteHit(id, direction, noteType, isSustainNote)
	-- 与 goodNoteHit 相同，但用于对手音符命中
end

function noteMissPress(direction)
	-- 按键失误计算后触发（空按未命中音符）
end

function noteMiss(id, direction, noteType, isSustainNote)
	-- 音符失误计算后触发（音符移出屏幕未命中）
end


-- 其他功能钩子
function onRecalculateRating()
	-- 如需自定义评分计算可返回 Function_Stop
	-- 使用 setRatingPercent() 设置评分百分比，setRatingString() 设置评分名称
	-- 注意：此函数在计算前调用！
	return Function_Continue;
end

function onMoveCamera(focus)
	if focus == 'boyfriend' then
		-- 镜头聚焦到男朋友时触发
	elseif focus == 'dad' then
		-- 镜头聚焦到老爸时触发
	end
end


-- 事件音符钩子
function onEvent(name, value1, value2)
	-- 事件音符触发时调用
	-- 注意：triggerEvent() 不会触发此函数！
	-- 调试用: print('事件触发: ', name, value1, value2);
end

function eventEarlyTrigger(name)
	--[[
	这里是 "Kill Henchmen" 事件的Lua版提前触发示例（原版为Haxe）:

	if name == 'Kill Henchmen'
		return 280;

	此代码使"消灭小弟"事件提前280毫秒触发，实现音效与歌曲完美同步
	]]--
	
	-- 在此下方编写自定义逻辑，新返回值将覆盖引擎原值
end


-- 缓动/计时器钩子
function onTweenCompleted(tag)
	-- 缓动动画完成时触发，tag为动画标识
end

function onTimerCompleted(tag, loops, loopsLeft)
	-- 计时器循环完成时触发
	-- tag: 计时器标识
	-- loops: 设定的总循环次数
	-- loopsLeft: 剩余循环次数
end

function onCheckForAchievement(name)
	-- 成就检测处理
	
	-- 示例:
--[[
  if name == 'sick-full-combo' and getProperty('bads') == 0 and getProperty('goods') == 0 and getProperty('shits') == 0 and getProperty('endingSong') then
    return Function_Continue
  end
  if name == 'bad-health-finish' and getProperty('health') < 0.01 and getProperty('endingSong') then
    return Function_Continue
  end
  if name == 'halfway' and getSongPosition >  getPropertyFromClass('flixel.FlxG','sound.music.length')/2 then
    return Function_Continue
  end
]]--
end