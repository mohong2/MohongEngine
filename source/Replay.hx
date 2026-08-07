package;

import flixel.input.keyboard.FlxKey;
import flixel.input.FlxInput;
import flixel.FlxBasic;
import flixel.FlxG;
import haxe.Json;
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
	var replayVersion:Int;
	/** 多k: 录制时的键数 (mania+1, 用于回放校验) */
	@:optional var mania:Int;
}

class Replay extends FlxBasic
{
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

	/** 轨道数量 (4K = 4) */
	private var laneCount:Int = 0;

	/** 临时数组 (避免GC) */
	private var tmpPressLanes:Array<Int> = [];
	private var tmpReleaseLanes:Array<Int> = [];
	private var tmpHeldLanes:Array<Bool> = [];

	/** 每帧"补长条/空闲动画"用的空事件数组 (避免每帧 GC) */
	private var tmpEmptyPress:Array<Int> = [];
	private var tmpEmptyRelease:Array<Int> = [];

	/** 缓存的按键名称列表 (所有 FlxKey 的字符串名) */
	private static var cachedKeyNames:Array<String> = null;

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
		frameData = frames != null ? frames.copy() : [];
		buildJudgmentMap();
		if (stateRecord != null) restoreState(stateRecord);
		ensureLaneMap();
	}

	/** 从文件加载回放 */
	public function loadFromFile(path:String):Void
	{
		#if sys
		isRecording = false;
		if (path == null || !FileSystem.exists(path))
		{
			CoolUtil.traceMsg('trace.errReplayLoad', 'Replay file not found: {}', [path]);
			frameData = [];
			return;
		}
		try
		{
			var content:String = File.getContent(path);
			var json:Dynamic = Json.parse(content);
			frameData = (json.frameRecord != null) ? json.frameRecord : [];
			if (json.stateRecord != null) restoreState(json.stateRecord);
			buildJudgmentMap();
			ensureLaneMap();
			lastFrameCount = 0;
			globalTick = 0;
			lastReplayTimeForResync = Math.NaN;
		}
		catch (e:Dynamic)
		{
			CoolUtil.traceMsg('trace.errReplayLoad', 'Failed to load replay: {}', [e]);
			frameData = [];
		}
		#end
	}

	/** 构建判定映射 (用于精确回放) */
	private function buildJudgmentMap():Void
	{
		judgmentMap.clear();
		hasJudgments = false;
		for (frame in frameData)
		{
			if (frame.noteJudgments == null) continue;
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

		if (stateRecord.songSpeed != null) ps.songSpeed = stateRecord.songSpeed;
		if (stateRecord.playbackRate != null) ps.playbackRate = stateRecord.playbackRate;
		if (stateRecord.healthGain != null) ps.healthGain = stateRecord.healthGain;
		if (stateRecord.healthLoss != null) ps.healthLoss = stateRecord.healthLoss;
		if (stateRecord.instakillOnMiss != null) ps.instakillOnMiss = stateRecord.instakillOnMiss;
		if (stateRecord.cpuControlled != null) ps.cpuControlled = stateRecord.cpuControlled;
		if (stateRecord.practiceMode != null) ps.practiceMode = stateRecord.practiceMode;
		if (stateRecord.songSpeedType != null) ps.songSpeedType = stateRecord.songSpeedType;
		if (stateRecord.sickWindow != null) ClientPrefs.data.sickWindow = stateRecord.sickWindow;
		if (stateRecord.goodWindow != null) ClientPrefs.data.goodWindow = stateRecord.goodWindow;
		if (stateRecord.badWindow != null) ClientPrefs.data.badWindow = stateRecord.badWindow;
		if (stateRecord.safeFrames != null) ClientPrefs.data.safeFrames = stateRecord.safeFrames;
		// LeatherEngine 移植: 回放时恢复录制时的判定手感, 保证评分/评级完全一致
		if (stateRecord.judgementTimings != null)
		{
			ClientPrefs.data.judgementTimings = stateRecord.judgementTimings;
			backend.Ratings.syncWindows();
		}
		if (stateRecord.judgementPreset != null && stateRecord.judgementPreset.length > 0)
			ClientPrefs.data.judgementPreset = stateRecord.judgementPreset;
		else if (stateRecord.judgementTimings != null)
			ClientPrefs.data.judgementPreset = backend.Ratings.presetNameForTimings(ClientPrefs.data.judgementTimings);
		if (stateRecord.marvelousRatings != null) ClientPrefs.data.marvelousRatings = stateRecord.marvelousRatings;
		if (stateRecord.marvelousWindow != null) ClientPrefs.data.marvelousWindow = stateRecord.marvelousWindow;
		if (stateRecord.replayVersion != null) replayVersion = stateRecord.replayVersion;

		// 判定手感变化检测: 只有在回放判定与当前设置不同时才提示
		judgementRestoredDifferent =
			(prevSick != ClientPrefs.data.sickWindow
			|| prevGood != ClientPrefs.data.goodWindow
			|| prevBad != ClientPrefs.data.badWindow
			|| prevMarv != ClientPrefs.data.marvelousWindow
			|| prevMarvOn != ClientPrefs.data.marvelousRatings);

		if (judgementRestoredDifferent)
		{
			var t:Array<Int> = ClientPrefs.data.judgementTimings;
			judgementRestoreInfo =
				ClientPrefs.data.judgementPreset + " (" + Std.string(t[0]) + "/" + Std.string(t[1]) + "/" + Std.string(t[2]) + "/" + Std.string(t[3]) + ")"
				+ (ClientPrefs.data.marvelousRatings ? " (Marvelous)" : "");
			// 回放还原的窗口与玩家设置不同 → 判定类型标记为自定义
			ClientPrefs.data.judgementPreset = backend.Ratings.presetNameForTimings(ClientPrefs.data.judgementTimings);
		}
		else
			judgementRestoreInfo = '';
		// 多k: 回放键数与当前谱面不一致时警告 (轨道映射会错位)
		if (stateRecord.mania != null && stateRecord.mania != PlayState.mania)
			FlxG.log.warn('Replay was recorded on ${stateRecord.mania + 1}K but current chart is ${PlayState.mania + 1}K');

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
			replayVersion: ClientPrefs.data.saveReplayData ? 2 : 1,
			mania: PlayState.mania
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

		if (cachedKeyNames == null)
			cachedKeyNames = [for (k in FlxKey.toStringMap.keys()) k];

		for (keyName in cachedKeyNames)
		{
			var key:FlxKey = FlxKey.toStringMap.get(keyName);
			if (key == FlxKey.ANY || key == FlxKey.NONE) continue;

			if (FlxG.keys.checkStatus(key, JUST_PRESSED))
				pressKey.push(keyName);
			if (FlxG.keys.checkStatus(key, JUST_RELEASED))
				releaseKey.push(keyName);
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
		if (frameData.length == 0) return;

		var ps = PlayState.instance;
		var targetSongPos:Float = Conductor.songPosition;
		ensureLaneMap();

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
			}

			buildHeldLanes();

			for (keyName in frame.releaseKey)
			{
				var flxKey:FlxKey = FlxKey.fromString(keyName);
				var lane:Null<Int> = keyToLane.get(flxKey);
				if (lane != null) tmpReleaseLanes.push(lane);
				keysHeld.remove(flxKey);
			}

			// 通知 PlayState 处理按键
			ps.replayApplyInput(frame.time, tmpPressLanes, tmpReleaseLanes, tmpHeldLanes);

			lastFrameCount++;
			globalTick++;
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

	/** 从文件加载回放 */
	public static function loadFromFileStatic(path:String):{frames:Array<FrameSave>, state:StateRecord}
	{
		#if sys
		try
		{
			var content:String = File.getContent(path);
			var json:Dynamic = Json.parse(content);
			return {
				frames: json.frameRecord != null ? json.frameRecord : [],
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

	/** 将 Dynamic 数组转回 FrameSave (从 Allscore 反序列化) */
	public static function dynamicToFrames(data:Array<Dynamic>):Array<FrameSave>
	{
		var result:Array<FrameSave> = [];
		if (data == null) return result;
		for (d in data)
		{
			result.push({
				time: d.time,
				songSpeed: d.songSpeed,
				playbackRate: d.playbackRate,
				pressKey: d.pressKey,
				releaseKey: d.releaseKey,
				noteJudgments: d.noteJudgments
			});
		}
		return result;
	}
}
