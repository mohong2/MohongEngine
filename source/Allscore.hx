package;

import haxe.Json;
import haxe.io.Bytes;
#if sys
import sys.io.File;
import sys.FileSystem;
#end
import flixel.FlxG;
import flixel.util.FlxSave;

using StringTools;

class Allscore
{
	public static var entries:Map<String, Array<ScoreEntry>> = new Map();

	private static inline var SCORE_DIR:String = "./.scores/";

	public static function load():Void
	{
		entries = new Map();

		#if sys
		if (!FileSystem.exists(SCORE_DIR))
		{
			FileSystem.createDirectory(SCORE_DIR);
		}
		else
		{
			var files = FileSystem.readDirectory(SCORE_DIR);
			for (file in files)
			{
				if (!StringTools.endsWith(file, ".json")) continue;

				var filePath = SCORE_DIR + file;
				try
				{
					var entry = readEntryFromJson(filePath);
					if (entry != null)
					{
						var key = Highscore.formatSong(entry.songName, entry.difficulty);
						if (!entries.exists(key)) entries.set(key, []);
						entries.get(key).push(entry);
					}
				}
				catch (e:Dynamic)
				{
					CoolUtil.traceMsg('trace.errScoreRead', 'Error reading score file {}: {}', [filePath, e]);
				}
			}
		}
		#end

		for (key => list in entries)
		{
			list.sort((a, b) -> Reflect.compare(b.date, a.date));
		}
	}

	public static function addEntry(songName:String, difficulty:Int,
		rating:Float = -1, ratingFC:String = "", ratingName:String = "", score:Int = 0,
		marvelouses:Int = -1, sicks:Int = -1, goods:Int = -1, bads:Int = -1, shits:Int = -1,
		misses:Int = -1, maxCombo:Int = -1,
		replayData:Array<Dynamic> = null,
		details:Array<Dynamic> = null,
		?date:String,
		?songSpeed:Float = 1, ?playbackRate:Float = 1, ?songSpeedType:String = "multiplicative"):Void
	{
		#if sys
		var key:String = Highscore.formatSong(songName, difficulty);

		var safeName = Paths.formatToSongPath(songName);
		var timestamp = Date.now().getTime();
		var random = Std.random(10000);

		// 统一文件名：歌曲_难度_时间戳_随机数.json
		var fileName = '${safeName}_${difficulty}_${timestamp}_${random}.json';
		var filePath = SCORE_DIR + fileName;

		var entry:ScoreEntry = {
			songName: songName,
			difficulty: difficulty,
			date: date != null ? date : Date.now().toString(),
			ratingPercent: rating,
			ratingFC: ratingFC,
			ratingName: ratingName,
			score: score,
			marvelouses: marvelouses,
			sicks: sicks,
			goods: goods,
			bads: bads,
			shits: shits,
			misses: misses,
			maxCombo: maxCombo,
			replayData: replayData,
			details: details,
			songSpeed: songSpeed,
			playbackRate: playbackRate,
			songSpeedType: songSpeedType,
			filePath: filePath
		};

		// 单个 JSON 文件保存所有数据（分数 + 详情 + replay）
		writeEntryToJson(entry, filePath);

		if (!entries.exists(key)) entries.set(key, []);
		var list:Array<ScoreEntry> = entries.get(key);
		list.unshift(entry);

		CoolUtil.traceMsg('trace.addedEntry', 'Added entry for {} [{}] -> {}', [songName, difficulty, filePath]);
		#end
	}

	public static function getHistory(songName:String, difficulty:Int):Array<ScoreEntry>
	{
		load();

		var key:String = Highscore.formatSong(songName, difficulty);
		if (!entries.exists(key)) return [];

		// 所有数据已从 JSON 完全加载，无需额外加载 replay 文件
		var list = entries.get(key).copy();
		return list;
	}

	public static function deleteEntry(songName:String, difficulty:Int, index:Int):Void
	{
		#if sys
		var key:String = Highscore.formatSong(songName, difficulty);
		if (!entries.exists(key)) return;

		var list = entries.get(key);
		if (index < 0 || index >= list.length) return;

		var entry = list[index];

		// 删除唯一的 JSON 文件
		if (entry.filePath != null && entry.filePath != "" && FileSystem.exists(entry.filePath))
		{
			try
			{
				FileSystem.deleteFile(entry.filePath);
				CoolUtil.traceMsg('trace.deletedScore', 'Deleted score file: {}', [entry.filePath]);
			}
			catch (e:Dynamic)
			{
				CoolUtil.traceMsg('trace.failDeleteScore', 'Failed to delete file: {}', [e]);
			}
		}

		list.splice(index, 1);
		if (list.length == 0) entries.remove(key);
		#end
	}

	// ---- 简单 XOR 加密(非密码学安全,防随手查看) ----
	// 使用 Bytes 读写避免 null byte 截断问题
	private static inline var XOR_KEY:Int = 0x7A;

	private static function xorBytes(input:Bytes):Bytes
	{
		var out = Bytes.alloc(input.length);
		for (i in 0...input.length)
		{
			out.set(i, input.get(i) ^ ((XOR_KEY + i) & 0xFF));
		}
		return out;
	}

	private static function writeEntryToJson(entry:ScoreEntry, filePath:String):Void
	{
		#if sys
		if (!FileSystem.exists(SCORE_DIR))
			FileSystem.createDirectory(SCORE_DIR);

		var jsonObj:Dynamic = {
			songName: entry.songName,
			difficulty: entry.difficulty,
			date: entry.date,
			score: entry.score,
			ratingPercent: entry.ratingPercent,
			ratingName: entry.ratingName,
			ratingFC: entry.ratingFC,
			marvelouses: entry.marvelouses,
			sicks: entry.sicks,
			goods: entry.goods,
			bads: entry.bads,
			shits: entry.shits,
			misses: entry.misses,
			maxCombo: entry.maxCombo,
			songSpeed: entry.songSpeed,
			playbackRate: entry.playbackRate,
			songSpeedType: entry.songSpeedType,
			details: entry.details,
			replayData: entry.replayData
		};

		var json:String = Json.stringify(jsonObj, "\t");
		var srcBytes:Bytes = Bytes.ofString(json, UTF8);
		var encBytes:Bytes = xorBytes(srcBytes);
		File.saveBytes(filePath, encBytes);
		#end
	}

	private static function readEntryFromJson(filePath:String):ScoreEntry
	{
		#if sys
		var encBytes:Bytes = File.getBytes(filePath);
		var decBytes:Bytes = xorBytes(encBytes);
		var content:String = decBytes.getString(0, decBytes.length, UTF8);
		var data:Dynamic = Json.parse(content);

		var entry:ScoreEntry = {
			songName: data.songName,
			difficulty: data.difficulty,
			date: data.date,
			ratingPercent: data.ratingPercent,
			ratingFC: data.ratingFC,
			ratingName: data.ratingName,
			score: data.score,
			marvelouses: data.marvelouses,
			sicks: data.sicks,
			goods: data.goods,
			bads: data.bads,
			shits: data.shits,
			misses: data.misses,
			maxCombo: data.maxCombo,
			replayData: data.replayData,
			details: data.details,
			songSpeed: data.songSpeed,
			playbackRate: data.playbackRate,
			songSpeedType: data.songSpeedType,
			filePath: filePath
		};

		return entry;
		#else
		return null;
		#end
	}

	/**
	 * 检查 ScoreEntry 是否包含实际的 replay 数据。
	 * 新格式: replayData 为 FrameSave 数组 (Array<Dynamic>)，检查是否有非空帧。
	 */
	public static function hasReplayData(entry:ScoreEntry):Bool
	{
		if (entry.replayData == null) return false;
		if (entry.replayData.length == 0) return false;

		for (frame in entry.replayData)
		{
			if (frame == null) continue;
			// 检查是否有按键事件 (pressKey 或 releaseKey 非空)
			var pressKey:Array<Dynamic> = frame.pressKey;
			var releaseKey:Array<Dynamic> = frame.releaseKey;
			if ((pressKey != null && pressKey.length > 0) || (releaseKey != null && releaseKey.length > 0))
				return true;
		}
		return false;
	}
}

/** 统一 ScoreEntry typedef，移除废弃字段，新增 filePath */
typedef ScoreEntry = {
	var songName:String;
	var difficulty:Int;
	var date:String;
	var score:Int;
	var ratingPercent:Float;
	var ratingName:String;
	var ratingFC:String;
	@:optional var marvelouses:Int;
	var sicks:Int;
	var goods:Int;
	var bads:Int;
	var shits:Int;
	var misses:Int;
	var maxCombo:Int;
	@:optional var replayData:Array<Dynamic>;
	@:optional var details:Array<Dynamic>;
	var songSpeed:Float;
	var playbackRate:Float;
	var songSpeedType:String;
	@:optional var filePath:String;
}
