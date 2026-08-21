package;

import flixel.input.keyboard.FlxKey;
import flixel.input.FlxInput;
import flixel.FlxBasic;
import flixel.FlxG;
import haxe.Json;
import StringTools;
import states.PlayState;
import Conductor;
import CoolUtil;
import ClientPrefs;
import Paths;
#if sys
import sys.io.File;
import sys.FileSystem;
#end

typedef NoteJudgment = {
	var strumTime:Float;
	var noteData:Int;
	var hitDiff:Float;
	var rating:String;
	var isSustain:Bool;
}

typedef FrameSave = {
	var time:Float;
	var songSpeed:Float;
	var playbackRate:Float;
	var pressKey:Array<String>;
	var releaseKey:Array<String>;
	@:optional var noteJudgments:Array<NoteJudgment>;
}

typedef StateRecord = {
	var songName:String;
	var difficulty:Int;
	var playDate:String;
	var songLength:Float;
	var songSpeed:Float;
	var playbackRate:Float;
	var healthGain:Float;
	var healthLoss:Float;
	var cpuControlled:Bool;
	var practiceMode:Bool;
	var instakillOnMiss:Bool;
	var songScore:Int;
	var ratingPercent:Float;
	var ratingFC:String;
	var songHits:Int;
	var highestCombo:Int;
	var songMisses:Int;
	var sicks:Int;
	var goods:Int;
	var bads:Int;
	var shits:Int;
	var noteTime:Array<Float>;
	var noteMs:Array<Float>;
	var songSpeedType:String;
	var sickWindow:Int;
	var goodWindow:Int;
	var badWindow:Int;
	var safeFrames:Float;
	/** LeatherEngine 移植: 录制时的判定手感 (marvelous/sick/good/bad ms 窗口) */
	@:optional var judgementTimings:Array<Int>;
	/** LeatherEngine 移植: 录制时的判定类型 (预设名或 Custom) */
	@:optional var judgementPreset:String;
	@:optional var marvelousRatings:Bool;
	@:optional var marvelousWindow:Int;
	/** osu! 尾判: 录制时是否开启尾判 + 尾判窗口 (ms) */
	//@:optional var osuTailJudgement:Bool;
	/** osu! 尾判窗口倍率 (相对普通判定窗口, 默认 2.0) */
	//@:optional var tailWindowMult:Float;
	/** 联机回放标识: 该回放录制于联机对局 */
	@:optional var isOnline:Bool;
	/** 联机回放: 房间码 / 房间名 / 模式 (realtime/async) */
	@:optional var roomCode:String;
	@:optional var roomName:String;
	@:optional var onlineMode:String;
	/** 判定相关手感: 录制时的评级偏移 / 长条是否按单音符判定 */
	@:optional var ratingOffset:Int;
	@:optional var guitarHeroSustains:Bool;
	var replayVersion:Int;
	/** 多k: 录制时的键数 (mania+1, 用于回放校验) */
	@:optional var mania:Int;
}

class Replay extends FlxBasic
{
	/** 临时调试日志 (排查回放无法进入/播放问题, 排查后可删除) */
	public static function dbgLog(msg:String):Void
	{
		#if sys
		try
		{
			var path:String = 'replay_debug.log';
			var old:String = sys.FileSystem.exists(path) ? sys.io.File.getContent(path) : '';
			sys.io.File.saveContent(path, old + msg + '\n');
		}
		catch (e:Dynamic) {}
		#end
	}

	/** 帧数据 (录制时写入, 回放时读取) */
	private var frameData:Array<FrameSave> = [];

	/** 是否正在录制 */
	public var isRecording:Bool = true;

	/** 当前加载的回放文件路径 */
	public static var preparedPath:String;

	/** 当前按下的键 (回放时维护) */
	private var keysHeld:Map<FlxKey, Bool> = new Map<FlxKey, Bool>();

	/** FlxKey → 轨道索引 映射 */
	private var keyToLane:Map<FlxKey, Int> = null;

	/** 全部 FlxKey 值列表 (录制时直接遍历, 按下/释放才取键名, 无上限、无字符串分配) */
	private static var cachedKeyList:Array<FlxKey> = null;

	// ---- 回放时模拟的按键状态 (供脚本 keyJustPressed/keyPressed/keyJustReleased 查询, 还原 mod 自定义机制键) ----
	private var simPressed:Map<String, Bool> = new Map<String, Bool>();
	private var simJustPressed:Map<String, Bool> = new Map<String, Bool>();
	private var simJustReleased:Map<String, Bool> = new Map<String, Bool>();
	private var simKnownKeys:Map<String, Bool> = new Map<String, Bool>();

	/** 轨道数量 (4K = 4) */
	private var laneCount:Int = 0;

	/** 临时数组 (避免GC) */
	private var tmpPressLanes:Array<Int> = [];
	private var tmpReleaseLanes:Array<Int> = [];
	private var tmpHeldLanes:Array<Bool> = [];

	/** 每帧"补长条/空闲动画"用的空事件数组 (避免每帧 GC) */
	private var tmpEmptyPress:Array<Int> = [];
	private var tmpEmptyRelease:Array<Int> = [];

	// ---- 高精度判定回放 ----
	public var hasJudgments(default, null):Bool = false;
	private var judgmentMap:Map<String, NoteJudgment> = new Map<String, NoteJudgment>();
	public var replayVersion(default, null):Int = 1;

	// ---- 回放判定手感提示 (LeatherEngine 移植) ----
	/** 回放恢复的判定窗口与玩家当前设置不同时为 true */
	public var judgementRestoredDifferent:Bool = false;
	/** 回放实际使用的判定窗口描述, 例如 "25/50/70/100 (Marvelous)" */
	public var judgementRestoreInfo:String = '';

	// ---- 回放状态 ----
	private var globalTick:Int = 0;
	private var lastFrameCount:Int = 0;
	/** 回放时的当前帧时间 (用于 note 可击中判断) */
	public var replayTime:Float = 0;
	private var lastReplayTimeForResync:Float = Math.NaN;

	private var lastSongSpeed:Float = 1;
	private var lastPlaybackRate:Float = 1;

	// ---- 待写入的判定 (录制时跨帧累积) ----
	private var pendingJudgments:Array<NoteJudgment> = [];

	// 上一个写入帧的 songSpeed / playbackRate —— 用于只在变速时额外采样
	private var lastRecordedSongSpeed:Float = 1;
	private var lastRecordedPlaybackRate:Float = 1;

	public function new()
	{
		super();
	}

	/** 开始录制 (清空旧数据) */
	public function startRecording():Void
	{
		isRecording = true;
		frameData = [];
		keysHeld = new Map<FlxKey, Bool>();
		pendingJudgments = [];
		resetSimState();
		lastRecordedSongSpeed = PlayState.instance != null ? PlayState.instance.songSpeed : 1;
		lastRecordedPlaybackRate = PlayState.instance != null ? PlayState.instance.playbackRate : 1;
		lastFrameCount = 0;
		replayVersion = 1;
		replayTime = 0;
		lastReplayTimeForResync = Math.NaN;
	}

	/** 停止录制 */
	public function stopRecording():Void
	{
		isRecording = false;
	}

	/** 从外部帧数组 + 状态记录加载回放 */
	public function loadFromData(frames:Array<FrameSave>, ?stateRecord:StateRecord):Void
	{
		isRecording = false;
		frameData = normalizeFrames(frames);
		resetSimState();
		buildJudgmentMap();
		if (stateRecord != null) restoreState(stateRecord);
		ensureLaneMap();
	}

	/** 从文件加载回放 (宽容解析: 兼容 BOM/前后垃圾字节/多种帧字段名/缺字段帧) */
	public function loadFromFile(path:String):Void
	{
		#if sys
		Replay.dbgLog('[DEBUG-rpl] loadFromFile path=$path');
		isRecording = false;
		resetSimState();
		if (path == null || !FileSystem.exists(path))
		{
			Replay.dbgLog('[DEBUG-rpl] loadFromFile: file missing');
			CoolUtil.traceMsg('trace.errReplayLoad', 'Replay file not found: {}', [path]);
			frameData = [];
			return;
		}
		try
		{
			var json:Dynamic = parseReplayJson(File.getContent(path));
			if (json == null)
			{
				Replay.dbgLog('[DEBUG-rpl] loadFromFile: JSON unparseable');
				CoolUtil.traceMsg('trace.errReplayLoad', 'Failed to load replay: {}', ['invalid JSON']);
				frameData = [];
				return;
			}
			frameData = extractFrames(json);
			Replay.dbgLog('[DEBUG-rpl] loadFromFile parsed, frameData=' + frameData.length);
			if (json.stateRecord != null) restoreState(json.stateRecord);
			buildJudgmentMap();
			ensureLaneMap();
			lastFrameCount = 0;
			globalTick = 0;
			lastReplayTimeForResync = Math.NaN;
			Replay.dbgLog('[DEBUG-rpl] loadFromFile OK');
		}
		catch (e:Dynamic)
		{
			Replay.dbgLog('[DEBUG-rpl] loadFromFile EXCEPTION: ' + Std.string(e));
			CoolUtil.traceMsg('trace.errReplayLoad', 'Failed to load replay: {}', [e]);
			frameData = [];
		}
		#end
	}

	/** 清空回放模拟按键状态 (加载回放/开始录制时调用) */
	private function resetSimState():Void
	{
		simPressed.clear();
		simJustPressed.clear();
		simJustReleased.clear();
		simKnownKeys.clear();
	}

	// ======================== 回放模拟按键 (供脚本 API) ========================

	/** 回放中: 该键是否在录制数据中出现过 (决定脚本查询是否以模拟状态为准) */
	public function keyExists(keyName:String):Bool
	{
		return simKnownKeys.exists(normalizeKeyName(keyName));
	}

	/** 回放中: 该键本帧是否刚按下 (与 keyJustPressed('space') 等脚本 API 对应) */
	public function keyJustPressed(keyName:String):Bool
	{
		return simJustPressed.get(normalizeKeyName(keyName)) == true;
	}

	/** 回放中: 该键当前是否按住 */
	public function keyPressed(keyName:String):Bool
	{
		return simPressed.get(normalizeKeyName(keyName)) == true;
	}

	/** 回放中: 该键本帧是否刚释放 */
	public function keyJustReleased(keyName:String):Bool
	{
		return simJustReleased.get(normalizeKeyName(keyName)) == true;
	}

	static inline function normalizeKeyName(keyName:String):String
	{
		if (keyName == null) return '';
		return keyName.toUpperCase();
	}

	/** 构建判定映射 (用于精确回放) */
	private function buildJudgmentMap():Void
	{
		judgmentMap.clear();
		hasJudgments = false;
		for (frame in frameData)
		{
			if (frame == null || frame.noteJudgments == null) continue;
			for (j in frame.noteJudgments)
			{
				var key:String = '${j.strumTime}_${j.noteData}';
				if (!judgmentMap.exists(key)) judgmentMap.set(key, j);
			}
			hasJudgments = true;
		}
	}

	/** 获取指定 Note 的录制判定 (若存在) */
	public function getRecordedJudgment(strumTime:Float, noteData:Int):NoteJudgment
	{
		return judgmentMap.get('${strumTime}_${noteData}');
	}

	/** 从 StateRecord 恢复游戏设置 */
	private function restoreState(stateRecord:Dynamic):Void
	{
		var ps = PlayState.instance;
		if (ps == null) return;

		// 记录恢复前的判定手感, 用于"仅在不相同的时候提醒"
		var prevSick:Int = ClientPrefs.data.sickWindow;
		var prevGood:Int = ClientPrefs.data.goodWindow;
		var prevBad:Int = ClientPrefs.data.badWindow;
		var prevMarv:Int = ClientPrefs.data.marvelousWindow;
		var prevMarvOn:Bool = ClientPrefs.data.marvelousRatings;
		//var prevTailOn:Bool = ClientPrefs.data.osuTailJudgement;
		//var prevTailMult:Float = ClientPrefs.data.tailWindowMult;
		var prevRatingOffset:Int = ClientPrefs.data.ratingOffset;
		var prevGuitarHero:Bool = ClientPrefs.data.guitarHeroSustains;

		// 数值/布尔字段统一经容错转换 (兼容字符串/缺失/类型异常, 不同版本录的回放都能进)
		if (stateRecord.songSpeed != null) ps.songSpeed = toFloat(stateRecord.songSpeed, ps.songSpeed);
		if (stateRecord.playbackRate != null) ps.playbackRate = toFloat(stateRecord.playbackRate, ps.playbackRate);
		if (stateRecord.healthGain != null) ps.healthGain = toFloat(stateRecord.healthGain, ps.healthGain);
		if (stateRecord.healthLoss != null) ps.healthLoss = toFloat(stateRecord.healthLoss, ps.healthLoss);
		if (stateRecord.instakillOnMiss != null) ps.instakillOnMiss = toBool(stateRecord.instakillOnMiss);
		if (stateRecord.cpuControlled != null) ps.cpuControlled = toBool(stateRecord.cpuControlled);
		if (stateRecord.practiceMode != null) ps.practiceMode = toBool(stateRecord.practiceMode);
		if (stateRecord.songSpeedType != null) ps.songSpeedType = Std.string(stateRecord.songSpeedType);
		if (stateRecord.sickWindow != null) ClientPrefs.data.sickWindow = Std.int(toFloat(stateRecord.sickWindow, ClientPrefs.data.sickWindow));
		if (stateRecord.goodWindow != null) ClientPrefs.data.goodWindow = Std.int(toFloat(stateRecord.goodWindow, ClientPrefs.data.goodWindow));
		if (stateRecord.badWindow != null) ClientPrefs.data.badWindow = Std.int(toFloat(stateRecord.badWindow, ClientPrefs.data.badWindow));
		if (stateRecord.safeFrames != null) ClientPrefs.data.safeFrames = toFloat(stateRecord.safeFrames, ClientPrefs.data.safeFrames);
		// LeatherEngine 移植: 回放时恢复录制时的判定手感, 保证评分/评级完全一致
		// 清洗: 只接受合法数字数组, 长度不足/类型异常一律忽略, 不覆盖玩家当前设置
		if (stateRecord.judgementTimings != null && Std.isOfType(stateRecord.judgementTimings, Array))
		{
			var rawTimings:Array<Dynamic> = cast stateRecord.judgementTimings;
			var timings:Array<Int> = [];
			for (v in rawTimings)
			{
				var t:Float = toFloat(v, -1);
				if (t >= 0) timings.push(Std.int(t));
			}
			if (timings.length >= 4)
			{
				ClientPrefs.data.judgementTimings = timings;
				backend.Ratings.syncWindows();
			}
		}
		if (stateRecord.judgementPreset != null && Std.string(stateRecord.judgementPreset).length > 0)
			ClientPrefs.data.judgementPreset = Std.string(stateRecord.judgementPreset);
		else if (stateRecord.judgementTimings != null && Std.isOfType(stateRecord.judgementTimings, Array))
			ClientPrefs.data.judgementPreset = backend.Ratings.presetNameForTimings(ClientPrefs.data.judgementTimings);
		if (stateRecord.marvelousRatings != null) ClientPrefs.data.marvelousRatings = toBool(stateRecord.marvelousRatings);
		if (stateRecord.marvelousWindow != null) ClientPrefs.data.marvelousWindow = Std.int(toFloat(stateRecord.marvelousWindow, ClientPrefs.data.marvelousWindow));
		// osu! 尾判: 强制还原录制时的尾判开关与窗口, 保证尾判成绩可复现
		//if (stateRecord.osuTailJudgement != null)
		//	ClientPrefs.data.osuTailJudgement = toBool(stateRecord.osuTailJudgement);
		//else
			// 老版本回放没有尾判字段: 按关闭处理, 与录制时 (无尾判) 的行为一致
		//	ClientPrefs.data.osuTailJudgement = false;
		// 尾判窗口倍率: 还原录制时的倍率 (非法值回退默认 2.0)
		//if (stateRecord.tailWindowMult != null)
		//{
		//	var mult:Float = toFloat(stateRecord.tailWindowMult, 2.0);
		//	if (!Math.isNaN(mult) && mult > 0 && mult <= 8)
		//		ClientPrefs.data.tailWindowMult = mult;
		//	else
		//		ClientPrefs.data.tailWindowMult = 2.0;
		//}
		//else
		//	ClientPrefs.data.tailWindowMult = 2.0;
		// 判定相关手感补全: 评级偏移 / 长条单音符判定 (此前未强制还原)
		if (stateRecord.ratingOffset != null) ClientPrefs.data.ratingOffset = Std.int(toFloat(stateRecord.ratingOffset, ClientPrefs.data.ratingOffset));
		if (stateRecord.guitarHeroSustains != null)
		{
			ClientPrefs.data.guitarHeroSustains = toBool(stateRecord.guitarHeroSustains);
			if (ps != null) ps.guitarHeroSustains = ClientPrefs.data.guitarHeroSustains;
		}
		if (stateRecord.replayVersion != null) replayVersion = Std.int(toFloat(stateRecord.replayVersion, 1));

		// 判定手感变化检测: 只有在回放判定与当前设置不同时才提示
		judgementRestoredDifferent =
			(prevSick != ClientPrefs.data.sickWindow
			|| prevGood != ClientPrefs.data.goodWindow
			|| prevBad != ClientPrefs.data.badWindow
			|| prevMarv != ClientPrefs.data.marvelousWindow
			|| prevMarvOn != ClientPrefs.data.marvelousRatings
			//|| prevTailOn != ClientPrefs.data.osuTailJudgement
			//|| prevTailMult != ClientPrefs.data.tailWindowMult
			|| prevRatingOffset != ClientPrefs.data.ratingOffset
			|| prevGuitarHero != ClientPrefs.data.guitarHeroSustains);

		if (judgementRestoredDifferent)
		{
			var t:Array<Int> = ClientPrefs.data.judgementTimings;
			if (t != null && t.length >= 4)
				judgementRestoreInfo =
					ClientPrefs.data.judgementPreset + " (" + Std.string(t[0]) + "/" + Std.string(t[1]) + "/" + Std.string(t[2]) + "/" + Std.string(t[3]) + ")"
					+ (ClientPrefs.data.marvelousRatings ? " (Marvelous)" : "");
			else
				// 窗口数据缺失/异常: 只提示预设名, 避免数组越界
				judgementRestoreInfo = ClientPrefs.data.judgementPreset + " (unknown windows)"
					+ (ClientPrefs.data.marvelousRatings ? " (Marvelous)" : "");
			// osu! 尾判 / 评级偏移 / 长条单音符判定 的还原信息 (仅列出入)
			var extra:Array<String> = [];
			//if (prevTailOn != ClientPrefs.data.osuTailJudgement)
			//	extra.push("osu! Tail: " + (ClientPrefs.data.osuTailJudgement ? "ON" : "OFF"));
			//if (prevTailMult != ClientPrefs.data.tailWindowMult)
			//	extra.push("Tail Window: " + Std.string(ClientPrefs.data.tailWindowMult) + "x");
			if (prevRatingOffset != ClientPrefs.data.ratingOffset)
				extra.push("Rating Offset: " + Std.string(ClientPrefs.data.ratingOffset) + "ms");
			if (prevGuitarHero != ClientPrefs.data.guitarHeroSustains)
				extra.push("Sustains as One Note: " + (ClientPrefs.data.guitarHeroSustains ? "ON" : "OFF"));
			if (extra.length > 0)
				judgementRestoreInfo += "\n" + extra.join("\n");
			// 回放还原的窗口与玩家设置不同 → 判定类型标记为自定义
			ClientPrefs.data.judgementPreset = backend.Ratings.presetNameForTimings(ClientPrefs.data.judgementTimings);
		}
		else
			judgementRestoreInfo = '';
		// 多k: 回放键数与当前谱面不一致时警告 (轨道映射会错位)
		if (stateRecord.mania != null)
		{
			var replayMania:Int = Std.int(toFloat(stateRecord.mania, -1));
			if (replayMania >= 0 && replayMania != PlayState.mania)
				FlxG.log.warn('Replay was recorded on ${replayMania + 1}K but current chart is ${PlayState.mania + 1}K');
		}

		lastSongSpeed = ps.songSpeed;
		lastPlaybackRate = ps.playbackRate;
	}

	/** 获取当前 StateRecord */
	public function getStateRecord():StateRecord
	{
		var ps = PlayState.instance;
		if (ps == null) return null;

		return {
			songName: Paths.formatToSongPath(PlayState.SONG != null ? PlayState.SONG.song : ''),
			difficulty: PlayState.storyDifficulty,
			playDate: Date.now().toString(),
			songLength: ps.songLength,
			songSpeed: ps.songSpeed,
			playbackRate: ps.playbackRate,
			healthGain: ps.healthGain,
			healthLoss: ps.healthLoss,
			cpuControlled: ps.cpuControlled,
			practiceMode: ps.practiceMode,
			instakillOnMiss: ps.instakillOnMiss,
			songScore: ps.songScore,
			ratingPercent: ps.ratingPercent,
			ratingFC: ps.ratingFC,
			songHits: ps.songHits,
			highestCombo: ps.maxcombo,
			songMisses: ps.songMisses,
			sicks: ps.sicks,
			goods: ps.goods,
			bads: ps.bads,
			shits: ps.shits,
			noteTime: ps.NoteTime,
			noteMs: ps.NoteMs,
			songSpeedType: ps.songSpeedType,
			sickWindow: ClientPrefs.data.sickWindow,
			goodWindow: ClientPrefs.data.goodWindow,
			badWindow: ClientPrefs.data.badWindow,
			safeFrames: ClientPrefs.data.safeFrames,
			judgementTimings: ClientPrefs.data.judgementTimings != null ? ClientPrefs.data.judgementTimings.copy() : null,
			judgementPreset: ClientPrefs.data.judgementPreset,
			marvelousRatings: ClientPrefs.data.marvelousRatings,
			marvelousWindow: ClientPrefs.data.marvelousWindow,
			//osuTailJudgement: ClientPrefs.data.osuTailJudgement,
			//tailWindowMult: ClientPrefs.data.tailWindowMult,
			ratingOffset: ClientPrefs.data.ratingOffset,
			guitarHeroSustains: ClientPrefs.data.guitarHeroSustains,
			replayVersion: ClientPrefs.data.saveReplayData ? 2 : 1,
			mania: PlayState.mania,
			#if ONLINE_ALLOWED
			isOnline: PlayState.seiunOnline,
			roomCode: online.client.OnlineSession.roomCode,
			roomName: online.client.OnlineSession.roomName,
			onlineMode: online.client.OnlineSession.mode
			#end
		};
	}

	override public function destroy():Void
	{
		super.destroy();
	}

	// ======================== 录制 ========================

	/** 每帧更新: 检测按键变化并录制帧 */
	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if (!isRecording || PlayState.instance == null) return;

		// 不保存回放数据时, 录制产物不会被消费 (Allscore 只在 saveReplayData 时取帧),
		// 直接跳过整个录制管线, 避免狂按时每帧全键盘扫描造成掉帧。
		if (!ClientPrefs.data.saveReplayData)
		{
			_pendingPressKeys.resize(0);
			_pendingReleaseKeys.resize(0);
			return;
		}

		var ps = PlayState.instance;
		// 只在"按键事件 / 判定 / 变速或倍速变化"时才录帧；
		// 去掉了原先的强制 60fps 匀速采样，静默停顿帧不再重复写入，
		// 能显著减小回放文件的体积与内存占用（回放端靠 press/release 事件维持按键状态，无需空帧）。
		var hasChanges:Bool = false;
		if (FlxG.keys.justPressed.ANY || FlxG.keys.justReleased.ANY)
			hasChanges = true;
		if (_pendingPressKeys.length > 0 || _pendingReleaseKeys.length > 0)
			hasChanges = true;
		if (pendingJudgments.length > 0)
			hasChanges = true;
		if (lastRecordedSongSpeed != ps.songSpeed || lastRecordedPlaybackRate != ps.playbackRate)
			hasChanges = true;

		if (hasChanges)
		{
			var frame:FrameSave = captureFrame();
			if (ClientPrefs.data.saveReplayData && pendingJudgments.length > 0)
			{
				frame.noteJudgments = pendingJudgments.copy();
				pendingJudgments = [];
			}
			frameData.push(frame);
			lastRecordedSongSpeed = ps.songSpeed;
			lastRecordedPlaybackRate = ps.playbackRate;
		}
	}

	/** 记录 Note 判定 (高精度回放用) */
	public function recordJudgment(strumTime:Float, noteData:Int, hitDiff:Float, rating:String, isSustain:Bool):Void
	{
		if (!isRecording || !ClientPrefs.data.saveReplayData) return;
		pendingJudgments.push({
			strumTime: strumTime,
			noteData: noteData,
			hitDiff: hitDiff,
			rating: rating,
			isSustain: isSustain
		});
	}

	/** 捕获当前帧的按键状态 */
	private function captureFrame():FrameSave
	{
		ensureLaneMap();
		var pressKey:Array<String> = [];
		var releaseKey:Array<String> = [];

		// 直接遍历全部键 (无上限, 任意 mod 自定义键都会被录制还原):
		// 只做 checkStatus 查找, 按下/释放时才取键名字符串, 避免旧实现的
		// 200+ 键 x (toUpperCase + 多次 Map 查找) 字符串分配开销。
		if (cachedKeyList == null)
			cachedKeyList = [for (k in FlxKey.toStringMap.keys()) k];
		for (flxKey in cachedKeyList)
		{
			if (flxKey == FlxKey.ANY || flxKey == FlxKey.NONE) continue;
			if (FlxG.keys.checkStatus(flxKey, JUST_PRESSED))
				pressKey.push(FlxKey.toStringMap.get(flxKey));
			if (FlxG.keys.checkStatus(flxKey, JUST_RELEASED))
				releaseKey.push(FlxKey.toStringMap.get(flxKey));
		}

		// 合并由安卓控件直接通知的按键（不修改 FlxG.keys，避免 Controls 系统二次判定）
		for (keyName in _pendingPressKeys)
		{
			if (pressKey.indexOf(keyName) < 0)
				pressKey.push(keyName);
		}
		_pendingPressKeys.resize(0);
		for (keyName in _pendingReleaseKeys)
		{
			if (releaseKey.indexOf(keyName) < 0)
				releaseKey.push(keyName);
		}
		_pendingReleaseKeys.resize(0);

		var ps = PlayState.instance;
		return {
			time: Conductor.songPosition,
			songSpeed: ps != null ? ps.songSpeed : 1,
			playbackRate: ps != null ? ps.playbackRate : 1,
			pressKey: pressKey,
			releaseKey: releaseKey
		};
	}

	// ---- 安卓控件直接通知 Replay 的录制方法（不模拟键盘，避免 Controls 二次判定） ----
	private var _pendingPressKeys:Array<String> = [];
	private var _pendingReleaseKeys:Array<String> = [];

	/** 由安卓控件（Hitbox/VirtualPad）调用，记录按键按下 */
	public function recordPress(keyName:String):Void
	{
		if (!isRecording) return;
		if (_pendingPressKeys.indexOf(keyName) < 0)
			_pendingPressKeys.push(keyName);
	}

	/** 由安卓控件（Hitbox/VirtualPad）调用，记录按键释放 */
	public function recordRelease(keyName:String):Void
	{
		if (!isRecording) return;
		if (_pendingReleaseKeys.indexOf(keyName) < 0)
			_pendingReleaseKeys.push(keyName);
	}

	/**
	 * 静态通知方法：供 FlxHitbox / FlxVirtualPad 直接调用。
	 * 根据设置键值将按键名传给当前 Replay 实例录制。
	 */
	public static function notifyPress(keyName:String):Void
	{
		var ps = PlayState.instance;
		if (ps != null && ps.replayExam != null && ps.replayExam.isRecording)
			ps.replayExam.recordPress(keyName);
	}

	public static function notifyRelease(keyName:String):Void
	{
		var ps = PlayState.instance;
		if (ps != null && ps.replayExam != null && ps.replayExam.isRecording)
			ps.replayExam.recordRelease(keyName);
	}

	// ======================== 回放 ========================

	/** 回放主逻辑: 由 PlayState.update() 每帧调用 */
	public function replayUpdate(elapsed:Float):Void
	{
		if (isRecording || PlayState.instance == null) return;
		if (frameData.length == 0)
		{
			Replay.dbgLog('[DEBUG-rpl] replayUpdate: frameData empty, cannot play');
			return;
		}

		var ps = PlayState.instance;
		var targetSongPos:Float = Conductor.songPosition;
		ensureLaneMap();

		if (globalTick == 0)
			Replay.dbgLog('[DEBUG-rpl] replayUpdate start, frames=' + frameData.length + ' songPos=' + targetSongPos);

		// 每帧开始时清空"刚按下/刚释放"边缘状态 (按住状态保留到释放为止)
		simJustPressed.clear();
		simJustReleased.clear();

		while (lastFrameCount < frameData.length && frameData[lastFrameCount].time <= targetSongPos)
		{
			var frame = frameData[lastFrameCount];
			this.replayTime = frame.time;

			// 速率重同步
			if (!Math.isNaN(lastReplayTimeForResync))
			{
				if (Math.abs(frame.songSpeed - lastSongSpeed) > 0.1)
				{
					ps.songSpeed = frame.songSpeed;
					lastSongSpeed = frame.songSpeed;
				}
				if (Math.abs(frame.playbackRate - lastPlaybackRate) > 0.1)
				{
					ps.playbackRate = frame.playbackRate;
					lastPlaybackRate = frame.playbackRate;
				}
			}
			lastReplayTimeForResync = frame.time;

			// 解析按键 → 轨道
			tmpPressLanes.resize(0);
			tmpReleaseLanes.resize(0);

			for (keyName in frame.pressKey)
			{
				var flxKey:FlxKey = FlxKey.fromString(keyName);
				var lane:Null<Int> = keyToLane.get(flxKey);
				if (lane != null) tmpPressLanes.push(lane);
				keysHeld.set(flxKey, true);
				// 记录模拟按键状态 (供脚本 keyJustPressed/keyPressed 查询)
				var simName:String = normalizeKeyName(keyName);
				simPressed.set(simName, true);
				simJustPressed.set(simName, true);
				simKnownKeys.set(simName, true);
			}

			buildHeldLanes();

			for (keyName in frame.releaseKey)
			{
				var flxKey:FlxKey = FlxKey.fromString(keyName);
				var lane:Null<Int> = keyToLane.get(flxKey);
				if (lane != null) tmpReleaseLanes.push(lane);
				keysHeld.remove(flxKey);
				// 记录模拟按键状态 (供脚本 keyJustReleased 查询)
				var simName:String = normalizeKeyName(keyName);
				simPressed.remove(simName);
				simJustReleased.set(simName, true);
				simKnownKeys.set(simName, true);
			}

			// 通知 PlayState 处理按键
			ps.replayApplyInput(frame.time, tmpPressLanes, tmpReleaseLanes, tmpHeldLanes);

			lastFrameCount++;
			globalTick++;
			if (globalTick % 120 == 0)
				Replay.dbgLog('[DEBUG-rpl] replayUpdate progress lastFrameCount=' + lastFrameCount + '/' + frameData.length + ' songPos=' + targetSongPos);
		}

		// 关键：每帧都基于当前按键状态补一次"长条命中 / 空闲动画"。
		// 录制瘦身之后，两帧按键事件之间不再有空帧，若只在 while 里调用 replayApplyInput，
		// 长条 body 期间没有任何新事件时就不会再走长条判定 → 直接 miss；角色也不会回 idle。
		// 这里用空 press/release + 当前 held-lanes 补跑一次，逻辑幂等且安全。
		buildHeldLanes();
		ps.replayApplyInput(Conductor.songPosition, tmpEmptyPress, tmpEmptyRelease, tmpHeldLanes);
	}

	/** 根据当前 keysHeld 构建按住轨道数组 (写入 tmpHeldLanes) */
	private inline function buildHeldLanes():Void
	{
		tmpHeldLanes.resize(laneCount);
		for (i in 0...laneCount) tmpHeldLanes[i] = false;
		for (flxKey in keysHeld.keys())
		{
			var lane:Null<Int> = keyToLane.get(flxKey);
			if (lane != null && lane >= 0 && lane < laneCount)
				tmpHeldLanes[lane] = true;
		}
	}

	/** 构建 FlxKey → 轨道映射 */
	private function ensureLaneMap():Void
	{
		var ps = PlayState.instance;
		if (ps == null) return;
		if (keyToLane != null && laneCount > 0) return;
		if (keyToLane == null) keyToLane = new Map<FlxKey, Int>();
		laneCount = 0;

		var keysList:Array<Dynamic> = ps.keysArray;
		if (keysList == null || keysList.length <= 0) return;

		laneCount = keysList.length;
		for (lane in 0...keysList.length)
		{
			var keys:Array<FlxKey> = keysList[lane];
			if (keys != null)
			{
				for (key in keys)
				{
					if (key != FlxKey.NONE && !keyToLane.exists(key))
						keyToLane.set(key, lane);
				}
			}
		}
	}

	// ======================== I/O ========================

	/** 获取帧数据 (用于保存到 Allscore) */
	public function getFrameData():Array<FrameSave>
	{
		return frameData;
	}

	/** 保存回放到文件 */
	public static function saveToFile(frames:Array<FrameSave>, stateRecord:StateRecord, path:String):Void
	{
		#if sys
		var data:Dynamic = {
			stateRecord: stateRecord,
			frameRecord: frames
		};
		var json:String = Json.stringify(data, "\t");
		File.saveContent(path, json);
		#end
	}

	/** 从文件加载回放 (宽容解析, 与 loadFromFile 同一套容错) */
	public static function loadFromFileStatic(path:String):{frames:Array<FrameSave>, state:StateRecord}
	{
		#if sys
		try
		{
			var json:Dynamic = parseReplayJson(File.getContent(path));
			if (json == null) return {frames: [], state: null};
			return {
				frames: extractFrames(json),
				state: json.stateRecord
			};
		}
		catch (e:Dynamic)
		{
			return {frames: [], state: null};
		}
		#else
		return {frames: [], state: null};
		#end
	}

	// ======================== 容错解析 / 归一化 (兼容不同版本、不同来源的回放文件) ========================

	/** 宽容解析回放 JSON: 去 BOM、容忍前后垃圾字节/注释, 返回 null 表示无法解析 */
	private static function parseReplayJson(content:String):Dynamic
	{
		if (content == null) return null;
		if (content.length > 0 && content.charCodeAt(0) == 0xFEFF) content = content.substr(1);
		content = StringTools.trim(content);
		if (content.length == 0) return null;

		var json:Dynamic = null;
		try { json = Json.parse(content); } catch (e:Dynamic) { json = null; }
		if (json == null)
		{
			// 截取第一个 { 到最后一个 } 再试一次 (容忍前后垃圾内容)
			var start:Int = content.indexOf('{');
			var end:Int = content.lastIndexOf('}');
			if (start >= 0 && end > start)
			{
				try { json = Json.parse(content.substring(start, end + 1)); } catch (e:Dynamic) { json = null; }
			}
		}
		return json;
	}

	/** 从解析结果中取出帧数组 (兼容 frameRecord / frames / frameData / 顶层就是数组) */
	private static function extractFrames(json:Dynamic):Array<FrameSave>
	{
		var raw:Dynamic = null;
		if (json != null)
		{
			if (Reflect.hasField(json, 'frameRecord')) raw = json.frameRecord;
			else if (Reflect.hasField(json, 'frames')) raw = json.frames;
			else if (Reflect.hasField(json, 'frameData')) raw = json.frameData;
			else if (Std.isOfType(json, Array)) raw = json;
		}
		return normalizeFrames(raw);
	}

	/**
	 * 把任意来源的帧数据归一化为结构完整的 FrameSave 数组。
	 * 缺字段/字段类型不对的帧不会被丢弃, 而是补默认值, 尽量让回放能进得来、能播。
	 */
	private static function normalizeFrames(raw:Dynamic):Array<FrameSave>
	{
		var out:Array<FrameSave> = [];
		if (raw == null) return out;
		if (Std.isOfType(raw, Array))
		{
			var arr:Array<Dynamic> = cast raw;
			for (d in arr) normalizeFrame(d, out);
		}
		else if (Type.typeof(raw) == TObject)
		{
			// 整个对象可能是 {frames:[...]} / {frameRecord:[...]} 的包装
			var inner:Dynamic = null;
			if (Reflect.hasField(raw, 'frames')) inner = raw.frames;
			else if (Reflect.hasField(raw, 'frameRecord')) inner = raw.frameRecord;
			else if (Reflect.hasField(raw, 'frameData')) inner = raw.frameData;
			if (Std.isOfType(inner, Array))
			{
				var innerArr:Array<Dynamic> = cast inner;
				for (d in innerArr) normalizeFrame(d, out);
			}
			else
				normalizeFrame(inner, out);
		}
		return out;
	}

	/** 归一化单个帧 (非对象/损坏帧直接跳过) */
	private static function normalizeFrame(d:Dynamic, out:Array<FrameSave>):Void
	{
		if (d == null || Type.typeof(d) != TObject) return;

		var time:Float = toFloat(d.time, 0);
		// 没有时间戳的帧按上一帧顺序续排, 保证事件顺序不塌缩到 0ms
		if (time <= 0 && out.length > 0) time = out[out.length - 1].time + 1;
		var songSpeed:Float = toFloat(d.songSpeed, 1); if (songSpeed <= 0) songSpeed = 1;
		var playbackRate:Float = toFloat(d.playbackRate, 1); if (playbackRate <= 0) playbackRate = 1;

		out.push({
			time: time,
			songSpeed: songSpeed,
			playbackRate: playbackRate,
			pressKey: toKeyArray(d.pressKey),
			releaseKey: toKeyArray(d.releaseKey),
			noteJudgments: toJudgments(d.noteJudgments)
		});
	}

	/** 数值容错: 数字/数字字符串/布尔都接受, 解析失败返回默认值 */
	private static function toFloat(v:Dynamic, def:Float):Float
	{
		if (v == null) return def;
		var f:Float = Std.parseFloat(Std.string(v));
		return Math.isNaN(f) ? def : f;
	}

	/** 布尔容错: true/1/"true"/"1" 都算 true */
	private static function toBool(v:Dynamic):Bool
	{
		if (v == null) return false;
		if (v == true) return true;
		if (Std.isOfType(v, Int) || Std.isOfType(v, Float)) return (v != 0);
		return (Std.string(v).toLowerCase() == 'true' || Std.string(v).toLowerCase() == '1');
	}

	/** 按键数组容错: 数组原样保留, 单个键名/键码也接受 */
	private static function toKeyArray(v:Dynamic):Array<String>
	{
		if (v == null) return [];
		if (Std.isOfType(v, Array))
		{
			var out:Array<String> = [];
			var arr:Array<Dynamic> = cast v;
			for (k in arr) if (k != null) out.push(Std.string(k));
			return out;
		}
		return [Std.string(v)];
	}

	/** 判定数据容错: 只保留结构完整的判定, 其余忽略 */
	private static function toJudgments(v:Dynamic):Array<NoteJudgment>
	{
		if (v == null || !Std.isOfType(v, Array)) return null;
		var out:Array<NoteJudgment> = [];
		var arr:Array<Dynamic> = cast v;
		for (j in arr)
		{
			if (j == null || Type.typeof(j) != TObject) continue;
			out.push({
				strumTime: toFloat(j.strumTime, 0),
				noteData: Std.int(toFloat(j.noteData, 0)),
				hitDiff: toFloat(j.hitDiff, 0),
				rating: j.rating != null ? Std.string(j.rating) : 'sick',
				isSustain: toBool(j.isSustain)
			});
		}
		return out.length > 0 ? out : null;
	}

	/** 生成回放文件名 */
	public static function generateFileName(songName:String, difficulty:Int):String
	{
		var safeName:String = Paths.formatToSongPath(songName);
		var timestamp:Float = Date.now().getTime();
		var random:Int = Std.random(10000);
		return '${safeName}_${difficulty}_${timestamp}_${random}.rsd';
	}

	/** 将 FrameSave 数组转为 Dynamic (用于 Allscore 序列化) */
	public static function framesToDynamic(frames:Array<FrameSave>):Array<Dynamic>
	{
		var result:Array<Dynamic> = [];
		for (f in frames)
		{
			result.push({
				time: f.time,
				songSpeed: f.songSpeed,
				playbackRate: f.playbackRate,
				pressKey: f.pressKey,
				releaseKey: f.releaseKey,
				noteJudgments: f.noteJudgments
			});
		}
		return result;
	}

	/** 将 Dynamic 数组转回 FrameSave (从 Allscore 反序列化, 容错归一化) */
	public static function dynamicToFrames(data:Array<Dynamic>):Array<FrameSave>
	{
		return normalizeFrames(data);
	}
}
