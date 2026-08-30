package;

import haxe.Json;
import openfl.utils.Assets;
import Section;
import Note;
import mohong.TraceManager;

typedef SwagSong =
{
	var song:String;
	var notes:Array<SwagSection>;
	var events:Array<Dynamic>;
	var bpm:Float;
	var needsVoices:Bool;
	var speed:Float;
	var offset:Float;

	var player1:String;
	var player2:String;
	var gfVersion:String;
	var stage:String;
	var format:String;

	@:optional var gameOverChar:String;
	@:optional var gameOverSound:String;
	@:optional var gameOverLoop:String;
	@:optional var gameOverEnd:String;

	@:optional var disableNoteRGB:Bool;

	/** 多k: 谱面键数 (0 基: 3 = 4K, 8 = 9K)。旧 4K 谱面无此字段, 默认 3。 */
	@:optional var mania:Null<Int>;

	@:optional var arrowSkin:String;
	@:optional var splashSkin:String;
	@:optional var difficultyName:String; // original chart difficulty (osu Version / Malody meta.version)

	/** Original chart creator/mapper carried over on osu!/Malody import. */
	@:optional var chartCreator:String;
	/** Original music artist carried over on osu!/Malody import. */
	@:optional var chartArtist:String;
	/** Original source string carried over on osu!/Malody import. */
	@:optional var chartSource:String;
	/** Original tags string carried over on osu!/Malody import. */
	@:optional var chartTags:String;

	public var validScore:Null<Bool>;
}


class Song
{
	public var song:String = null;
	public var notes:Array<SwagSection>;
	public var events:Array<Dynamic>;
	public var bpm:Float;
	public var needsVoices:Bool = true;
	public var arrowSkin:String;

	public var splashSkin:String;
	public var gameOverChar:String;
	public var gameOverSound:String;
	public var gameOverLoop:String;
	public var gameOverEnd:String;
	public var disableNoteRGB:Bool = false;
	public var mania:Null<Int> = 3;
	public var speed:Float = 1;
	public var stage:String;
	public var player1:String = 'bf';
	public var player2:String = 'dad';
	public var gfVersion:String = 'gf';

	public var mapper:String = 'N/A';
	public var musican:String = 'N/A';

	static public var isNewVersion:Bool = false;

	private static function onLoadJson(songJson:Dynamic) // Convert old charts to newest format
	{
		if (songJson.mania == null)
			songJson.mania = Note.defaultMania;

		if (songJson.gfVersion == null)
		{
			songJson.gfVersion = songJson.player3;
			songJson.player3 = null;
		}

		if (songJson.events == null)
		{
			songJson.events = [];
			for (secNum in 0...songJson.notes.length)
			{
				var sec:SwagSection = songJson.notes[secNum];

				var i:Int = 0;
				var notes:Array<Dynamic> = sec.sectionNotes;
				var len:Int = notes.length;
				while (i < len)
				{
					var note:Array<Dynamic> = notes[i];
					if (note[1] < 0)
					{
						songJson.events.push([note[0], [[note[2], note[3], note[4]]]]);
						notes.remove(note);
						len = notes.length;
					}
					else
						i++;
				}
			}
		}
	}

	public function new(song, notes, bpm)
	{
		this.song = song;
		this.notes = notes;
		this.bpm = bpm;
	}

	public static var chartPath:String;
	public static var loadedSongName:String;

	// ── Turbo 模式谱面 DOM 释放守卫 ──
	// 记录最近一次"真实谱面"(非 events) loadFromJson 的重载参数与身份序号。
	// PlayState 在 Turbo 下释放 SONG 逐 note 数据前校验 token 匹配, 保证重开时
	// 一定能用同样的参数从磁盘无损重载; 编辑器/脚本直接赋值的 SONG 无 token, 自动跳过释放。
	public static var lastChartReloadJson:String;
	public static var lastChartReloadFolder:String;
	public static var lastChartToken:Int = 0;

	/** 与 StringTools.trim 完全等价的裁剪, 但两端无空白可裁时零复制返回原串。
	 *  百万 note 级谱面 JSON 有数百 MB, trim() 的无条件整串复制会把加载峰值内存翻倍。 */
	static function trimChartJson(s:String):String
	{
		if (s == null) return null;
		var len:Int = s.length;
		var start:Int = 0;
		while (start < len && isJsonSpace(s, start)) start++;
		var end:Int = len;
		while (end > start && isJsonSpace(s, end - 1)) end--;
		if (start == 0 && end == len) return s;
		if (start >= end) return '';
		return s.substr(start, end - start);
	}

	/** 与 StringTools.isSpace 相同的空白判定 (tab/LF/VT/FF/CR/space)。 */
	inline static function isJsonSpace(s:String, pos:Int):Bool
	{
		var c:Int = s.charCodeAt(pos);
		return (c > 8 && c < 14) || c == 32;
	}

	public static function loadFromJson(jsonInput:String, ?folder:String, ?convertTo:String = 'psych_v1'):SwagSong
	{
		var rawJson = null;
		
		var formattedFolder:String = Paths.formatToSongPath(folder);
		var formattedSong:String = Paths.formatToSongPath(jsonInput);
		#if MODS_ALLOWED
		var moddyFile:String = Paths.modsJson(formattedFolder + '/' + formattedSong);
		if(FileSystem.exists(moddyFile)) {
			rawJson = trimChartJson(File.getContent(moddyFile));
		}
		#end

		if(rawJson == null) {
			#if sys
			rawJson = trimChartJson(File.getContent(Paths.json(formattedFolder + '/' + formattedSong)));
			#else
			rawJson = trimChartJson(Assets.getText(Paths.json(formattedFolder + '/' + formattedSong)));
			#end
		}

		while (!rawJson.endsWith("}"))
		{
			rawJson = rawJson.substr(0, rawJson.length - 1);
			// LOL GOING THROUGH THE BULLSHIT TO CLEAN IDK WHATS STRANGE
		}

		// FIX THE CASTING ON WINDOWS/NATIVE
		// Windows???
		// trace(songData);

		// trace('LOADED FROM JSON: ' + songData.notes);
		/* 
			for (i in 0...songData.notes.length)
			{
				trace('LOADED FROM JSON: ' + songData.notes[i].sectionNotes);
				// songData.notes[i].sectionNotes = songData.notes[i].sectionNotes
			}

				daNotes = songData.notes;
				daSong = songData.song;
				daBpm = songData.bpm; */

		// convertTo 默认 'psych_v1' (老谱自动升级); 传空串 '' 可跳过归一化,
		// 保留磁盘上的原始 format 字段 (联机用区分"导入转换谱"与"原版谱")。
		var songJson:Dynamic = parseJSON(rawJson, jsonInput, convertTo);
		if(jsonInput != 'events') StageData.loadDirectory(songJson);
		onLoadJson(songJson);

		// 记录重载参数与身份 token (events.json 不覆盖, 供 Turbo 模式 DOM 释放守卫/重开重载使用)
		if (jsonInput != 'events')
		{
			lastChartReloadJson = jsonInput;
			lastChartReloadFolder = folder;
			++lastChartToken;
			Reflect.setField(songJson, '__seiunToken', lastChartToken);
		}
		return songJson;
	}

	static var _lastPath:String;

	public static function getChart(jsonInput:String, ?folder:String):SwagSong
	{
		if (folder == null)
			folder = jsonInput;
		var rawData:String = null;

		var formattedFolder:String = Paths.formatToSongPath(folder);
		var formattedSong:String = Paths.formatToSongPath(jsonInput);

		#if MODS_ALLOWED
		var moddyFile:String = Paths.modsJson(formattedFolder + '/' + formattedSong);
		if(FileSystem.exists(moddyFile))
			rawData = File.getContent(moddyFile);
		#end

		if(rawData == null)
		{
			_lastPath = Paths.json('$formattedFolder/$formattedSong');
			rawData = Assets.getText(_lastPath);
		}

		return rawData != null ? parseJSON(rawData, jsonInput) : null;
	}

	public static function parseJSON(rawData:String, ?nameForError:String = null, ?convertTo:String = 'psych_v1'):SwagSong
	{
		// Strip UTF-8 BOM: haxe.format.JsonParser rejects U+FEFF at position 0,
		// which crashes chart loading for files saved by Notepad/PowerShell etc.
		if (rawData != null && rawData.length > 0 && rawData.charCodeAt(0) == 0xFEFF)
			rawData = rawData.substr(1);

		// Detect CNE (Codename Engine) format
		if (rawData.indexOf('"codenameChart"') != -1)
		{
			try
			{
				var testData:Dynamic = Json.parse(rawData);
				if ((testData.codenameChart == true || testData.codenameChart == "true") && testData.strumLines != null)
				{
					CoolUtil.traceMsg('trace.convertingChart', 'converting CNE chart {} to psych_v1 format...', [nameForError]);
					return editors.content.CneExport.cneToPsych(rawData);
				}
			}
			catch(e:Dynamic) {}
		}

		var songJson:SwagSong = cast Json.parse(rawData);
		isNewVersion = true;
		if (Reflect.hasField(songJson, 'song'))
		{
			var subSong:SwagSong = Reflect.field(songJson, 'song');
			if (subSong != null && Type.typeof(subSong) == TObject)
			{
				songJson = subSong;
				if (songJson.format == null)
					isNewVersion = false; // it build with old
			}
		}

		if (convertTo != null && convertTo.length > 0)
		{
			var fmt:String = songJson.format;
			if (fmt == null) fmt = songJson.format = 'unknown';

			switch (convertTo)
			{
				case 'psych_v1':
					if (!fmt.startsWith('psych_v1'))
					{
						// 旧格式谱面 → 转换为 psych_v1 格式
						// (convert() 对于空的 sectionNotes 安全无副作用)
						trace('converting chart $nameForError with format $fmt to psych_v1 format...');
						songJson.format = 'psych_v1_convert';
						convert(songJson);
						isNewVersion = true; // 数据已转换
				}
			}
		}

		if (songJson.mania == null)
			songJson.mania = Note.defaultMania;

		// Normalize a whitespace-only difficulty name (e.g. imported charts
		// with an empty Version / meta.version) so it never leaks into exports.
		if (songJson.difficultyName != null)
		{
			var dn:String = Std.string(songJson.difficultyName);
			if (StringTools.trim(dn).length == 0)
				Reflect.deleteField(songJson, 'difficultyName');
		}

		return songJson;
	}

	public static function castVersion(songJson:SwagSong):SwagSong // Convert psych_v1 format to old format
	{
		// 多k: 键数由谱面 mania 决定，避免 9K/18K 谱面在旧引擎里按 4K 翻转错位。
		var mania:Int = (songJson != null && songJson.mania != null && songJson.mania >= 0 && songJson.mania < Note.ammo.length) ? Std.int(songJson.mania) : Note.defaultMania;
		var ammo:Int = Note.ammo[mania];

		for (i in 0...songJson.notes.length)
		{
			for (ii in 0...songJson.notes[i].sectionNotes.length)
			{
				var gottaHitNote:Bool = songJson.notes[i].mustHitSection;
				var noteData:Int = Std.int(songJson.notes[i].sectionNotes[ii][1]);
				if (noteData < 0) continue;
				if (!gottaHitNote)
				{
					if (noteData >= ammo)
					{
						noteData -= ammo;
					}
					else
					{
						noteData += ammo;
					}
					songJson.notes[i].sectionNotes[ii][1] = noteData;
				}
			}
		}
		isNewVersion = false;
		return songJson;
	}

	public static function convert(songJson:Dynamic):Void
	{
		if(songJson.gfVersion == null)
		{
			songJson.gfVersion = songJson.player3;
			if(Reflect.hasField(songJson, 'player3')) Reflect.deleteField(songJson, 'player3');
		}

		if(songJson.events == null)
		{
			songJson.events = [];
			for (secNum in 0...songJson.notes.length)
			{
				var sec:SwagSection = songJson.notes[secNum];

				var i:Int = 0;
				var notes:Array<Dynamic> = sec.sectionNotes;
				var len:Int = notes.length;
				while(i < len)
				{
					var note:Array<Dynamic> = notes[i];
					if(note[1] < 0)
					{
						songJson.events.push([note[0], [[note[2], note[3], note[4]]]]);
						notes.remove(note);
						len = notes.length;
					}
					else i++;
				}
			}
		}

		var sectionsData:Array<SwagSection> = songJson.notes;
		if(sectionsData == null) return;

		// 多k: 使用谱面自身键数（mania 0 基），而不是写死 4。
		// 没有 mania 字段的旧谱面按默认 4K 处理。
		var mania:Int = (songJson.mania != null && songJson.mania >= 0 && songJson.mania < Note.ammo.length) ? Std.int(songJson.mania) : Note.defaultMania;
		var ammo:Int = Note.ammo[mania];

		for (section in sectionsData)
		{
			var beats:Null<Float> = cast section.sectionBeats;
			if (beats == null || Math.isNaN(beats))
			{
				section.sectionBeats = 4;
				if(Reflect.hasField(section, 'lengthInSteps')) Reflect.deleteField(section, 'lengthInSteps');
			}

			for (note in section.sectionNotes)
			{
				var rawData:Int = Std.int(note[1]);
				if (rawData < 0) continue;
				var gottaHitNote:Bool = (rawData < ammo) ? section.mustHitSection : !section.mustHitSection;
				note[1] = (rawData % ammo) + (gottaHitNote ? 0 : ammo);

				// 旧格式 (0.1 – 0.3.2) 的数字 noteType 转换为字符串
				if(note.length > 3 && !Std.isOfType(note[3], String) && note[3] != null)
				{
					var typeIdx:Int = Std.int(note[3]);
					if(typeIdx >= 0 && typeIdx < Note.defaultNoteTypes.length)
						note[3] = Note.defaultNoteTypes[typeIdx];
					else
						note[3] = '';
				}
				else if(note.length <= 3)
				{
					// 兼容连 noteType 字段都没有的超旧谱面
					note.push('');
				}
			}
		}
	}


}
