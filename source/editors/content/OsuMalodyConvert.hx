package editors.content;

import Song;
import Song.SwagSong;
import Section.SwagSection;
import haxe.Json;
import haxe.zip.Entry;
import haxe.zip.Reader;
import haxe.zip.Uncompress;
import flixel.util.FlxSort;
#if sys
import sys.io.File;
import sys.FileSystem;
#end
import mohong.TraceManager;

/**
 * osu!mania (.osu) / Malody (.mc) <-> Psych Engine chart converters.
 *
 * Format references used during development:
 *  - osu:      https://osu.ppy.sh/wiki/en/Client/File_formats/osu_(file_format)
 *  - Malody:   JSON based; beat = [measure-beat index, snap index, snap size]
 *              time(ms) = (beat[0] + beat[1]/beat[2]) * 60000 / bpm
 *              (cross-verified against Quaver, rconv, fxTap-Adapter and malody2osu)
 *
 * Characters are defaulted to bf / dad / gf as requested.
 * Note side mapping:
 *  - 4K charts  -> all notes on player (BF) lanes 0-3
 *  - 8K charts  -> columns 0-3 on BF, columns 4-7 on DAD
 *  - 5K/6K/7K   -> columns proportionally squeezed into BF lanes
 *  - >8K        -> first half into BF lanes, second half into DAD lanes
 */
class OsuMalodyConvert
{
	// ========================================================================
	//  CONFIGURABLE MAPPING MODES
	// ========================================================================

	/** Smart mapping: 4K -> BF, 8K -> split BF/DAD, others -> proportional. */
	public static final MAP_AUTO:Int = 0;
	/** Force every column onto the 4 player (BF) lanes. */
	public static final MAP_4K:Int = 1;
	/** Force a split layout: first half BF, second half DAD. */
	public static final MAP_8K:Int = 2;
	/** Compress into an arbitrary player key count (1-18). */
	public static final MAP_CUSTOM:Int = 3;

	// ========================================================================
	//  DETECTION
	// ========================================================================

	public static function isOsuFile(data:String):Bool
	{
		return stripBom(data).indexOf('osu file format v') == 0;
	}

	public static function isMalodyFile(data:String):Bool
	{
		var t:String = stripBom(data);
		if (t.indexOf('"meta"') == -1) return false;
		try
		{
			var obj:Dynamic = Json.parse(t);
			return Reflect.hasField(obj, 'meta') && Reflect.hasField(obj, 'note');
		}
		catch (e:Dynamic) return false;
	}

	/** True for zip chart packages: osu! sets (.osz) and Malody packs (.mcz). */
	public static function isPackageFile(path:String):Bool
	{
		var lower:String = path.toLowerCase();
		return lower.endsWith('.osz') || lower.endsWith('.mcz');
	}

	// ========================================================================
	//  SHARED HELPERS
	// ========================================================================

	static function stripBom(s:String):String
	{
		if (s != null && s.length > 0 && s.charCodeAt(0) == 0xFEFF) return s.substr(1);
		return s;
	}

	static function makeNote(time:Float, lane:Int, sus:Float):Dynamic
	{
		return {time: time, lane: lane, sus: sus};
	}

	static function makeBpmChange(time:Float, bpm:Float):Dynamic
	{
		return {time: time, bpm: bpm};
	}

	static function sortByTime(a:Dynamic, b:Dynamic):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, a.time, b.time);
	}

	/**
	 * Resolves an external key-column into { mania, lane } for the engine's
	 * multi-K system (0..K-1 = player keys, K..2K-1 = opponent).
	 * mode: MAP_AUTO = keep the original key count (engine supports 1-18K),
	 *       MAP_4K = compress into 4 player keys,
	 *       MAP_8K = 4 player keys + opponent split (classic FNF style),
	 *       MAP_CUSTOM = compress into `customKeys` player keys.
	 */
	static function importColumnToLane(column:Int, keys:Int, mode:Int = 0, ?customKeys:Int = 0):Dynamic
	{
		switch (mode)
		{
			case MAP_4K:
				return {mania: 3, lane: Std.int(Math.max(0, Math.min(3, Std.int(column * 4 / keys))))};

			case MAP_8K:
				var half:Int = Std.int(Math.ceil(keys / 2));
				if (column < half)
					return {mania: 3, lane: Std.int(Math.max(0, Math.min(3, Std.int(column * 4 / half))))};
				return {mania: 3, lane: Std.int(Math.max(4, Math.min(7, 4 + Std.int((column - half) * 4 / (keys - half)))))};

			case MAP_CUSTOM:
				var ck:Int = (customKeys > 0) ? Std.int(Math.max(1, Math.min(18, customKeys))) : keys;
				return {mania: ck - 1, lane: Std.int(Math.max(0, Math.min(ck - 1, Std.int(column * ck / keys))))};

			default: // MAP_AUTO: keep the original key count (1-18K)
				var kk:Int = Std.int(Math.max(1, Math.min(18, keys)));
				var lane:Int = (keys > 18) ? Std.int(column * 18 / keys) : column;
				return {mania: kk - 1, lane: Std.int(Math.max(0, Math.min(kk - 1, lane)))};
		}
	}

	/**
	 * Builds Psych sections from a flat note list + BPM change list.
	 * Section boundaries land exactly on every 4th beat AND every BPM change,
	 * so timing stays accurate even with mid-measure tempo changes.
	 */
	static function buildSections(flatNotes:Array<Dynamic>, bpmChanges:Array<Dynamic>, baseBpm:Float):Array<SwagSection>
	{
		flatNotes.sort(sortByTime);
		bpmChanges.sort(sortByTime);

		var lastNoteTime:Float = 0;
		if (flatNotes.length > 0) lastNoteTime = flatNotes[flatNotes.length - 1].time;

		var sections:Array<SwagSection> = [];
		var curTime:Float = 0;
		var curBpm:Float = (baseBpm > 0) ? baseBpm : 120;
		var bpmIdx:Int = 0;
		var noteIdx:Int = 0;
		var changeBpm:Bool = false;
		var guard:Int = 0;

		while (curTime <= lastNoteTime + 1 && guard < 100000)
		{
			guard++;

			// consume any BPM changes that take effect at this boundary
			while (bpmIdx < bpmChanges.length && bpmChanges[bpmIdx].time <= curTime + 0.001)
			{
				var nb:Float = bpmChanges[bpmIdx].bpm;
				if (nb > 0) curBpm = nb;
				changeBpm = true;
				bpmIdx++;
			}

			var beatLen:Float = 60000 / curBpm;
			var nextBoundary:Float = curTime + beatLen * 4;
			var sectionEnd:Float = nextBoundary;
			if (bpmIdx < bpmChanges.length && bpmChanges[bpmIdx].time < nextBoundary - 0.001)
				sectionEnd = bpmChanges[bpmIdx].time;

			var sectionBeats:Float = (sectionEnd - curTime) / beatLen;
			if (sectionBeats <= 0.001) sectionBeats = 0.001;

			var secNotes:Array<Dynamic> = [];
			while (noteIdx < flatNotes.length && flatNotes[noteIdx].time < sectionEnd - 0.001)
			{
				var n:Dynamic = flatNotes[noteIdx];
				var sus:Float = (n.sus != null && n.sus > 0) ? n.sus : 0;
				secNotes.push([n.time, n.lane, sus, '']);
				noteIdx++;
			}

			sections.push({
				sectionNotes: secNotes,
				sectionBeats: sectionBeats,
				mustHitSection: true,
				gfSection: false,
				altAnim: false,
				changeBPM: changeBpm,
				bpm: curBpm
			});
			changeBpm = false;
			curTime = sectionEnd;
		}

		if (sections.length == 0)
		{
			sections.push({
				sectionNotes: [],
				sectionBeats: 4,
				mustHitSection: true,
				gfSection: false,
				altAnim: false,
				changeBPM: false,
				bpm: curBpm
			});
		}

		return sections;
	}

	static function buildPsychEvents(svPoints:Array<Dynamic>):Array<Dynamic>
	{
		var events:Array<Dynamic> = [];
		svPoints.sort(sortByTime);
		var i:Int = 0;
		while (i < svPoints.length)
		{
			var t:Float = svPoints[i].time;
			var subs:Array<Dynamic> = [];
			while (i < svPoints.length && Math.abs(svPoints[i].time - t) < 0.01)
			{
				subs.push(['Change Scroll Speed', Std.string(svPoints[i].mult), '0']);
				i++;
			}
			events.push([t, subs]);
		}
		return events;
	}

	static function makePsychSong(songName:String, sections:Array<SwagSection>, bpm:Float, events:Array<Dynamic>, speed:Float, ?difficultyName:String = null, ?mania:Null<Int> = null, ?creator:String = null, ?artist:String = null, ?source:String = null, ?tags:String = null):SwagSong
	{
		var result:SwagSong = {
			song: songName,
			notes: sections,
			events: events,
			bpm: (bpm > 0) ? bpm : 120,
			needsVoices: false,
			speed: (speed > 0) ? speed : 1,
			offset: 0,
			player1: 'bf',
			player2: 'dad',
			gfVersion: 'gf',
			stage: 'stage',
			format: 'psych_v1_convert',
			difficultyName: difficultyName,
			mania: (mania != null) ? EKData.clampMania(mania) : null,
			validScore: true
		};
		if (creator != null && StringTools.trim(creator).length > 0) result.chartCreator = StringTools.trim(creator);
		if (artist != null && StringTools.trim(artist).length > 0) result.chartArtist = StringTools.trim(artist);
		if (source != null && StringTools.trim(source).length > 0) result.chartSource = StringTools.trim(source);
		if (tags != null && StringTools.trim(tags).length > 0) result.chartTags = StringTools.trim(tags);
		return result;
	}

	/**
	 * Walks a Psych song and collects flat notes, BPM changes and scroll speed
	 * events with absolute times (ms), plus metadata for the exporters.
	 */
	static function collectExportData(song:SwagSong):Dynamic
	{
		var notes:Array<Dynamic> = [];
		var bpmChanges:Array<Dynamic> = [];
		var svEvents:Array<Dynamic> = [];

		var curTime:Float = 0;
		var curBpm:Float = (song.bpm > 0) ? song.bpm : 120;
		var hasOpponent:Bool = false;
		var baseKeys:Int = 4;
		if (song.mania != null && song.mania >= 0)
			baseKeys = EKData.clampMania(song.mania) + 1;
		if (baseKeys < 1) baseKeys = 1;
		var inferredMaxLane:Int = -1; // mania 缺失时的兜底推断

		var sections:Array<SwagSection> = song.notes;
		if (sections != null)
		{
			for (sec in sections)
			{
				if (sec == null) continue;

				var secBpm:Float = (sec.bpm != null && sec.bpm > 0) ? sec.bpm : curBpm;
				if (secBpm != curBpm)
				{
					bpmChanges.push(makeBpmChange(curTime, secBpm));
					curBpm = secBpm;
				}

				if (sec.sectionNotes != null)
				{
					for (note in sec.sectionNotes)
					{
						if (note == null || note.length < 2) continue;
						var rawData:Int = Std.int(note[1]);
						if (rawData < 0) continue; // legacy event notes
						var lane:Int = rawData;
						if (lane >= baseKeys * 2) lane = lane % baseKeys; // corrupt lane: fold back
						if (song.mania == null && lane > inferredMaxLane) inferredMaxLane = lane;
						var sus:Float = (note.length > 2 && note[2] != null) ? note[2] : 0;

						// Girlfriend notes have no home in osu!/Malody; skip them.
						if (sec.gfSection == true && lane < baseKeys) continue;

						if (lane >= baseKeys) hasOpponent = true;
						notes.push(makeNote(note[0], lane, sus));
					}
				}

				var secBeats:Float = (sec.sectionBeats > 0) ? sec.sectionBeats : 4;
				curTime += secBeats * (60000 / curBpm);
			}
		}

		if (song.events != null)
		{
			for (ev in song.events)
			{
				if (ev == null || ev.length < 2) continue;
				var t:Float = ev[0];
				var subs:Array<Dynamic> = ev[1];
				if (subs == null) continue;
				for (sub in subs)
				{
					if (sub == null || sub.length < 1) continue;
					if (Std.string(sub[0]) == 'Change Scroll Speed' && sub.length > 1)
					{
						var mult:Float = Std.parseFloat(Std.string(sub[1]));
						if (Math.isNaN(mult) || mult <= 0) mult = 1;
						svEvents.push({time: t, mult: mult});
					}
				}
			}
		}

		notes.sort(sortByTime);
		svEvents.sort(sortByTime);

		// 兜底: mania 字段缺失时按轨道分布推断 (0-3 玩家 / 4+ 对手 = 4K; 否则 K = maxLane+1)
		if (song.mania == null && inferredMaxLane >= 0)
		{
			if (inferredMaxLane >= 4) baseKeys = 4;
			else baseKeys = inferredMaxLane + 1;
		}

		var speed:Float = (song.speed > 0) ? song.speed : 1;
		return {
			notes: notes,
			bpmChanges: bpmChanges,
			svEvents: svEvents,
			speed: speed,
			songName: (song.song != null && song.song.length > 0) ? song.song : 'Unknown',
			hasOpponent: hasOpponent,
			baseKeys: baseKeys
		};
	}

	// ========================================================================
	//  OSU IMPORT
	// ========================================================================

	public static function osuToPsych(data:String, ?mode:Int = 0, ?customKeys:Int = 0):SwagSong
	{
		var text:String = stripBom(data).split('\r').join('');
		var lines:Array<String> = text.split('\n');

		var section:String = '';
		var general:Map<String, String> = new Map<String, String>();
		var metadata:Map<String, String> = new Map<String, String>();
		var difficulty:Map<String, String> = new Map<String, String>();
		var timingPoints:Array<Array<String>> = [];
		var hitObjects:Array<Array<String>> = [];

		for (raw in lines)
		{
			var line:String = StringTools.trim(raw);
			if (line.length == 0 || line.startsWith('//')) continue;
			if (line.startsWith('[') && line.endsWith(']'))
			{
				section = line.substr(1, line.length - 2);
				continue;
			}

			switch (section)
			{
				case 'General' | 'Metadata' | 'Difficulty':
					var idx:Int = line.indexOf(':');
					if (idx < 0) continue;
					var key:String = line.substr(0, idx).trim();
					var value:String = line.substr(idx + 1).trim();
					switch (section)
					{
						case 'General': general.set(key, value);
						case 'Metadata': metadata.set(key, value);
						case 'Difficulty': difficulty.set(key, value);
					}

				case 'TimingPoints':
					timingPoints.push(line.split(','));

				case 'HitObjects':
					hitObjects.push(line.split(','));
			}
		}

		var mode:Int = general.exists('Mode') ? Std.parseInt(general.get('Mode')) : 3;
		if (mode != 3)
			throw 'This .osu file is osu! mode $mode, only osu!mania (Mode 3) charts are supported.';

		var keysRaw:Null<Int> = difficulty.exists('CircleSize') ? Std.parseInt(difficulty.get('CircleSize')) : 4;
		var keys:Int = (keysRaw != null && keysRaw > 0) ? keysRaw : 4;

		var title:String = metadata.get('TitleUnicode');
		if (title == null || title.length == 0) title = metadata.get('Title');
		if (title == null || title.length == 0) title = 'Unknown Song';
		var diffName:String = metadata.get('Version');
		if (diffName == null) diffName = '';
		diffName = StringTools.trim(diffName);
		if (diffName.length == 0) diffName = null;

		var creator:String = metadata.get('Creator');
		if (creator != null) creator = StringTools.trim(creator);
		if (creator != null && creator.length == 0) creator = null;
		var artist:String = metadata.get('ArtistUnicode');
		if (artist == null || StringTools.trim(artist).length == 0) artist = metadata.get('Artist');
		if (artist != null) artist = StringTools.trim(artist);
		if (artist != null && artist.length == 0) artist = null;
		var source:String = metadata.get('Source');
		if (source != null) source = StringTools.trim(source);
		if (source != null && source.length == 0) source = null;
		var tags:String = metadata.get('Tags');
		if (tags != null) tags = StringTools.trim(tags);
		if (tags != null && tags.length == 0) tags = null;

		var targetMania:Int = importColumnToLane(0, keys, mode, customKeys).mania;

		// ---- timing points ----
		timingPoints.sort(function(a:Array<String>, b:Array<String>):Int
		{
			return FlxSort.byValues(FlxSort.ASCENDING, Std.parseFloat(a[0]), Std.parseFloat(b[0]));
		});

		var bpmChanges:Array<Dynamic> = [];
		var svPoints:Array<Dynamic> = [];
		for (tp in timingPoints)
		{
			if (tp.length < 2) continue;
			var t:Float = Std.parseFloat(tp[0]);
			var beatLength:Float = Std.parseFloat(tp[1]);
			if (Math.isNaN(t) || Math.isNaN(beatLength)) continue;

			var uninherited:Int = tp.length > 6 ? Std.parseInt(tp[6]) : 1;
			if (uninherited == 1)
			{
				if (beatLength > 0) bpmChanges.push(makeBpmChange(t, 60000 / beatLength));
			}
			else
			{
				if (beatLength < 0) svPoints.push({time: t, mult: -100 / beatLength});
			}
		}

		var baseBpm:Float = 120;
		if (bpmChanges.length > 0) baseBpm = bpmChanges[0].bpm;

		// ---- hit objects ----
		var flatNotes:Array<Dynamic> = [];
		for (ho in hitObjects)
		{
			if (ho.length < 5) continue;
			var time:Float = Std.parseFloat(ho[2]);
			var type:Null<Int> = Std.parseInt(ho[3]);
			var x:Null<Int> = Std.parseInt(ho[0]);
			if (Math.isNaN(time) || type == null || x == null) continue;
			if ((type & 8) != 0) continue; // spinner

			var column:Int = Std.int(Math.floor(x * keys / 512));
			column = Std.int(Math.max(0, Math.min(keys - 1, column)));

			var sus:Float = 0;
			if ((type & 128) != 0 && ho.length > 5)
			{
				var params:Array<String> = ho[5].split(':');
				var endTime:Float = Std.parseFloat(params[0]);
				if (!Math.isNaN(endTime)) sus = endTime - time;
				if (sus < 0) sus = 0;
			}
			else if ((type & 1) == 0 && (type & 2) == 0 && (type & 4) == 0)
			{
				continue; // unknown object type, skip
			}

			flatNotes.push(makeNote(time, importColumnToLane(column, keys, mode, customKeys).lane, sus));
		}

		var events:Array<Dynamic> = buildPsychEvents(svPoints);
		var sections:Array<SwagSection> = buildSections(flatNotes, bpmChanges, baseBpm);
		return makePsychSong(title, sections, baseBpm, events, 1, diffName, targetMania, creator, artist, source, tags);
	}

	// ========================================================================
	//  OSU EXPORT
	// ========================================================================

	public static function psychToOsu(song:SwagSong, ?keyMode:Int = 0, ?audioRef:String = null, ?backgroundRef:String = null):String
	{
		var data:Dynamic = collectExportData(song);
		var baseKeys:Int = data.baseKeys;
		var keys:Int = exportKeys(data.hasOpponent, keyMode, baseKeys);
		var songName:String = sanitizeLine(Paths.formatToSongPath(Std.string(data.songName)));
		var audioFile:String = (audioRef != null && audioRef.length > 0) ? sanitizeLine(audioRef) : songName + '.ogg';

		var sb:StringBuf = new StringBuf();
		sb.add('osu file format v14\n\n');

		sb.add('[General]\n');
		sb.add('AudioFilename: ' + audioFile + '\n');
		sb.add('AudioLeadIn: 0\n');
		sb.add('PreviewTime: -1\n');
		sb.add('Countdown: 0\n');
		sb.add('SampleSet: Soft\n');
		sb.add('StackLeniency: 0.7\n');
		sb.add('Mode: 3\n');
		sb.add('LetterboxInBreaks: 0\n');
		sb.add('SpecialStyle: 0\n');
		sb.add('WidescreenStoryboard: 0\n\n');

		sb.add('[Editor]\n');
		sb.add('DistanceSpacing: 1.2\n');
		sb.add('BeatDivisor: 4\n');
		sb.add('GridSize: 8\n');
		sb.add('TimelineZoom: 2.4\n\n');

		var title:String = sanitizeLine(Std.string(data.songName));
		var artist:String = (song.chartArtist != null && StringTools.trim(song.chartArtist).length > 0)
			? sanitizeLine(song.chartArtist) : "Friday Night Funkin'";
		var creator:String = (song.chartCreator != null && StringTools.trim(song.chartCreator).length > 0)
			? sanitizeLine(song.chartCreator) : 'SeiunEngine Chart Editor';
		var source:String = (song.chartSource != null && StringTools.trim(song.chartSource).length > 0)
			? sanitizeLine(song.chartSource) : "Friday Night Funkin'";
		var tags:String = (song.chartTags != null && StringTools.trim(song.chartTags).length > 0)
			? sanitizeLine(song.chartTags) : 'SeiunEngine FNF PsychEngine';
		sb.add('[Metadata]\n');
		sb.add('Title:' + title + '\n');
		sb.add('TitleUnicode:' + title + '\n');
		sb.add('Artist:' + artist + '\n');
		sb.add('ArtistUnicode:' + artist + '\n');
		sb.add('Creator:' + creator + '\n');
		var diffName:String = (song.difficultyName != null && StringTools.trim(song.difficultyName).length > 0) ? sanitizeLine(song.difficultyName) : 'FNF';
		sb.add('Version:' + diffName + '\n');
		sb.add('Source:' + source + '\n');
		sb.add('Tags:' + tags + '\n');
		sb.add('BeatmapID:0\n');
		sb.add('BeatmapSetID:-1\n\n');

		sb.add('[Difficulty]\n');
		sb.add('HPDrainRate:8\n');
		sb.add('CircleSize:' + keys + '\n');
		sb.add('OverallDifficulty:8\n');
		sb.add('ApproachRate:5\n');
		sb.add('SliderMultiplier:1.4\n');
		sb.add('SliderTickRate:1\n\n');

		sb.add('[Events]\n');
		sb.add('//Background and Video events\n');
		if (backgroundRef != null && backgroundRef.length > 0)
			sb.add('0,0,"' + backgroundRef.split('\\').join('/').split('/').pop() + '",0,0\n');
		sb.add('\n');

		sb.add('[TimingPoints]\n');
		var baseBpm:Float = (song.bpm > 0) ? song.bpm : 120;
		sb.add('0,' + Std.string(60000 / baseBpm) + ',4,1,0,100,1,0\n');

		var bpmChanges:Array<Dynamic> = data.bpmChanges;
		for (bc in bpmChanges)
		{
			var t:Float = Math.max(0, bc.time);
			if (t < 0.01 && Math.abs(bc.bpm - baseBpm) < 0.01) continue; // already written
			sb.add(Std.int(Math.round(t)) + ',' + Std.string(60000 / bc.bpm) + ',4,1,0,100,1,0\n');
		}

		var speed:Float = data.speed;
		if (speed != 1)
			sb.add('0,-' + Std.string(100 / speed) + ',4,1,0,100,0,0\n');
		var svEvents:Array<Dynamic> = cast data.svEvents;
		for (sv in svEvents)
		{
			var t:Float = Math.max(0, sv.time);
			sb.add(Std.int(Math.round(t)) + ',-' + Std.string(100 / sv.mult) + ',4,1,0,100,0,0\n');
		}

		sb.add('\n[HitObjects]\n');
		var notes:Array<Dynamic> = cast data.notes;
		for (n in notes)
		{
			var lane:Int = Std.int(Math.max(0, n.lane));
			var column:Int = exportColumn(lane, baseKeys, keys);
			var x:Int = Std.int(512 * (2 * column + 1) / (2 * keys));
			var time:Int = Std.int(Math.round(n.time));
			var sus:Float = (n.sus != null && n.sus > 0) ? n.sus : 0;

			if (sus > 0)
			{
				var endTime:Int = Std.int(Math.round(n.time + sus));
				sb.add(x + ',192,' + time + ',128,0,' + endTime + ':0:0:0:0:\n');
			}
			else
				sb.add(x + ',192,' + time + ',1,0,0:0:0:0:\n');
		}

		return sb.toString();
	}

	// ========================================================================
	//  MALODY IMPORT
	// ========================================================================

	public static function malodyToPsych(data:String, ?mode:Int = 0, ?customKeys:Int = 0):SwagSong
	{
		var obj:Dynamic = Json.parse(stripBom(data));
		var meta:Dynamic = obj.meta;
		if (meta == null || obj.time == null || obj.note == null)
			throw 'Not a valid Malody (.mc) chart file.';

		var mode:Int = (meta.mode != null) ? Std.int(meta.mode) : 0;
		if (mode != 0)
			throw 'Only Malody Key mode charts (mode 0) are supported, this chart uses mode $mode.';

		var keysRaw:Null<Int> = 4;
		if (meta.mode_ext != null && meta.mode_ext.column != null)
			keysRaw = Std.int(meta.mode_ext.column);
		var keys:Int = (keysRaw != null && keysRaw > 0) ? keysRaw : 4;

		var title:String = (meta.song != null && meta.song.title != null) ? Std.string(meta.song.title) : 'Unknown Song';
		var diffName:String = (meta.version != null) ? StringTools.trim(Std.string(meta.version)) : '';
		if (diffName.length == 0) diffName = null;

		var creator:String = (meta.creator != null) ? StringTools.trim(Std.string(meta.creator)) : null;
		if (creator != null && creator.length == 0) creator = null;
		var artist:String = (meta.song != null && meta.song.artist != null) ? StringTools.trim(Std.string(meta.song.artist)) : null;
		if (artist != null && artist.length == 0) artist = null;
		var source:String = (meta.song != null && meta.song.source != null) ? StringTools.trim(Std.string(meta.song.source)) : null;
		if (source != null && source.length == 0) source = null;
		var tags:String = (meta.song != null && meta.song.tags != null) ? StringTools.trim(Std.string(meta.song.tags)) : null;
		if (tags != null && tags.length == 0) tags = null;

		var targetMania:Int = importColumnToLane(0, keys, mode, customKeys).mania;

		// ---- BPM timeline (in absolute beat space) ----
		var timeArr:Array<Dynamic> = cast obj.time;
		var segments:Array<Dynamic> = [];
		for (t in timeArr)
		{
			if (t == null || t.beat == null || t.bpm == null) continue;
			var bpm:Float = Std.parseFloat(Std.string(t.bpm));
			if (Math.isNaN(bpm) || bpm <= 0) continue;
			segments.push({beat: beatValue(t.beat), bpm: bpm});
		}
		segments.sort(function(a:Dynamic, b:Dynamic):Int
		{
			return FlxSort.byValues(FlxSort.ASCENDING, a.beat, b.beat);
		});

		// dedupe same-beat entries, last one wins
		var uniqueSegments:Array<Dynamic> = [];
		for (seg in segments)
		{
			if (uniqueSegments.length > 0 && uniqueSegments[uniqueSegments.length - 1].beat == seg.beat)
				uniqueSegments[uniqueSegments.length - 1] = seg;
			else
				uniqueSegments.push(seg);
		}
		segments = uniqueSegments;
		if (segments.length == 0)
			throw 'Malody chart has no BPM data (time array).';

		// ---- song cue offset ----
		var offset:Float = 0;
		var cueBeat:Float = 0;
		var notesArr:Array<Dynamic> = cast obj.note;
		for (n in notesArr)
		{
			if (n == null) continue;
			if (n.type != null && Std.int(n.type) == 1)
			{
				if (n.offset != null) offset = Std.parseFloat(Std.string(n.offset));
				if (n.beat != null) cueBeat = beatValue(n.beat);
				break;
			}
		}
		if (Math.isNaN(offset)) offset = 0;
		var cueMs:Float = beatToMs(cueBeat, segments);

		function chartMs(beatVal:Float):Float
		{
			return beatToMs(beatVal, segments) - cueMs - offset;
		}

		// ---- BPM changes ----
		var bpmChanges:Array<Dynamic> = [];
		for (seg in segments)
			bpmChanges.push(makeBpmChange(chartMs(seg.beat), seg.bpm));
		var baseBpm:Float = segments[0].bpm;

		// ---- scroll speed effects ----
		var svPoints:Array<Dynamic> = [];
		if (obj.effect != null)
		{
			var effectArr:Array<Dynamic> = cast obj.effect;
			for (e in effectArr)
			{
				if (e == null || e.beat == null || e.scroll == null) continue;
				var scroll:Float = Std.parseFloat(Std.string(e.scroll));
				if (Math.isNaN(scroll) || scroll <= 0) continue;
				svPoints.push({time: chartMs(beatValue(e.beat)), mult: scroll});
			}
		}
		var events:Array<Dynamic> = buildPsychEvents(svPoints);

		// ---- notes ----
		var flatNotes:Array<Dynamic> = [];
		for (n in notesArr)
		{
			if (n == null || n.beat == null) continue;
			if (n.type != null && Std.int(n.type) == 1) continue; // song cue
			if (!Reflect.hasField(n, 'column')) continue;

			var column:Int = Std.int(n.column);
			var startMs:Float = chartMs(beatValue(n.beat));
			if (Math.isNaN(startMs) || startMs == Math.POSITIVE_INFINITY) continue; // malformed note: skip
			var sus:Float = 0;
			if (n.endbeat != null)
			{
				var endMs:Float = chartMs(beatValue(n.endbeat));
				sus = endMs - startMs;
				if (sus < 0) sus = 0;
			}
			flatNotes.push(makeNote(startMs, importColumnToLane(column, keys, mode, customKeys).lane, sus));
		}

		var sections:Array<SwagSection> = buildSections(flatNotes, bpmChanges, baseBpm);
		return makePsychSong(title, sections, baseBpm, events, 1, diffName, targetMania, creator, artist, source, tags);
	}

	static function beatValue(beat:Array<Int>):Float
	{
		if (beat == null || beat.length < 3) return 0;
		var div:Int = beat[2];
		if (div <= 0) div = 1;
		return beat[0] + beat[1] / div;
	}

	static function beatToMs(beatVal:Float, segments:Array<Dynamic>):Float
	{
		if (segments.length == 0) return 0;
		if (beatVal <= segments[0].beat) return 0;

		var prevBeat:Float = segments[0].beat;
		var prevMs:Float = 0;
		for (i in 1...segments.length)
		{
			var bpm:Float = segments[i - 1].bpm;
			if (beatVal <= segments[i].beat)
				return prevMs + (beatVal - prevBeat) * 60000 / bpm;
			prevMs += (segments[i].beat - prevBeat) * 60000 / bpm;
			prevBeat = segments[i].beat;
		}
		return prevMs + (beatVal - prevBeat) * 60000 / segments[segments.length - 1].bpm;
	}

	// ========================================================================
	//  MALODY EXPORT
	// ========================================================================

	public static function psychToMalody(song:SwagSong, ?keyMode:Int = 0, ?audioRef:String = null, ?backgroundRef:String = null):String
	{
		var data:Dynamic = collectExportData(song);
		var baseKeys:Int = data.baseKeys;
		var keys:Int = exportKeys(data.hasOpponent, keyMode, baseKeys);
		var songName:String = Std.string(data.songName);
		var audioFile:String = (audioRef != null && audioRef.length > 0)
			? audioRef.split('\\').join('/').split('/').pop()
			: Paths.formatToSongPath(songName) + '.ogg';

		var baseBpm:Float = (song.bpm > 0) ? song.bpm : 120;

		// ---- build ms -> absolute beat timeline ----
		var timeline:Array<Dynamic> = [{time: 0, beat: 0, bpm: baseBpm}];
		var bpmChanges:Array<Dynamic> = data.bpmChanges;
		bpmChanges.sort(sortByTime);
		for (bc in bpmChanges)
		{
			if (bc.time <= 0.001) continue; // base bpm already on the timeline
			var prev:Dynamic = timeline[timeline.length - 1];
			var beat:Float = prev.beat + (bc.time - prev.time) * prev.bpm / 60000;
			timeline.push({time: bc.time, beat: beat, bpm: bc.bpm});
		}

		function msToBeat(ms:Float):Float
		{
			if (ms <= 0) return 0;
			var prev:Dynamic = timeline[0];
			for (i in 1...timeline.length)
			{
				if (ms <= timeline[i].time)
					return prev.beat + (ms - prev.time) * prev.bpm / 60000;
				prev = timeline[i];
			}
			return prev.beat + (ms - prev.time) * prev.bpm / 60000;
		}

		// ---- malody time array ----
		var timeEntries:Array<Dynamic> = [{beat: [0, 0, 1], bpm: baseBpm}];
		for (i in 1...timeline.length)
		{
			var t:Dynamic = timeline[i];
			timeEntries.push({beat: toMalodyBeat(t.beat, 4), bpm: t.bpm});
		}

		// ---- malody effect (SV) array ----
		var effectEntries:Array<Dynamic> = [];
		var svEvents:Array<Dynamic> = cast data.svEvents;
		for (sv in svEvents)
		{
			var beatF:Float = msToBeat(sv.time);
			effectEntries.push({beat: toMalodyBeat(beatF, 4), scroll: sv.mult});
		}

		// ---- malody note array ----
		var noteEntries:Array<Dynamic> = [];
		var notes:Array<Dynamic> = cast data.notes;
		for (n in notes)
		{
			var lane:Int = Std.int(Math.max(0, n.lane));
			var column:Int = exportColumn(lane, baseKeys, keys);
			var startBeat:Array<Int> = toMalodyBeat(msToBeat(n.time), 192);
			var sus:Float = (n.sus != null && n.sus > 0) ? n.sus : 0;
			if (sus > 0)
			{
				var endBeat:Array<Int> = toMalodyBeat(msToBeat(n.time + sus), 192);
				noteEntries.push({beat: startBeat, endbeat: endBeat, column: column});
			}
			else
				noteEntries.push({beat: startBeat, column: column});
		}

		// song cue (type 1)
		noteEntries.push({
			beat: [0, 0, 1],
			sound: audioFile,
			vol: 100,
			offset: 0,
			type: 1
		});

		var creator:String = (song.chartCreator != null && StringTools.trim(song.chartCreator).length > 0)
			? StringTools.trim(song.chartCreator) : 'SeiunEngine Chart Editor';
		var artist:String = (song.chartArtist != null && StringTools.trim(song.chartArtist).length > 0)
			? StringTools.trim(song.chartArtist) : "Friday Night Funkin'";
		var source:String = (song.chartSource != null && StringTools.trim(song.chartSource).length > 0)
			? StringTools.trim(song.chartSource) : '';
		var tags:String = (song.chartTags != null && StringTools.trim(song.chartTags).length > 0)
			? StringTools.trim(song.chartTags) : '';
		// Malody has no standard Source/Tags fields, but we store them as extra
		// song metadata so osu! -> Malody -> osu! round-trips keep them.
		var songMeta:Dynamic = {
			title: songName,
			artist: artist,
			id: 0
		};
		if (source.length > 0) songMeta.source = source;
		if (tags.length > 0) songMeta.tags = tags;

		var chart:Dynamic = {
			meta: {
				'$ver': 1,
				creator: creator,
				background: (backgroundRef != null && backgroundRef.length > 0) ? backgroundRef.split('\\').join('/').split('/').pop() : '',
				version: (song.difficultyName != null && StringTools.trim(song.difficultyName).length > 0) ? song.difficultyName : 'FNF',
				preview: 0,
				id: 0,
				mode: 0,
				time: Std.int(Date.now().getTime() / 1000),
				song: songMeta,
				mode_ext: {
					column: keys,
					bar_begin: 0
				}
			},
			time: timeEntries,
			effect: effectEntries,
			note: noteEntries
		};

		return Json.stringify(chart);
	}

	/**
	 * Quantizes a float beat to Malody's [index, snapIndex, snapSize] form.
	 */
	static function toMalodyBeat(beatF:Float, snap:Int):Array<Int>
	{
		if (beatF < 0) beatF = 0;
		var whole:Int = Std.int(Math.floor(beatF));
		var frac:Float = beatF - whole;
		var snapIdx:Int = Std.int(Math.round(frac * snap));
		if (snapIdx >= snap)
		{
			snapIdx = 0;
			whole++;
		}
		return [whole, snapIdx, snap];
	}

	static function sanitizeLine(s:String):String
	{
		if (s == null) return 'Unknown';
		return s.split('\r').join('').split('\n').join(' ');
	}

	/**
	 * Decides how many keys the exported chart uses.
	 * keyMode: 0 = auto (4K without opponent notes, else 8K), 4/8 = forced.
	 */
	/**
	 * Decides the exported key count. Auto: use the chart's own key count
	 * (mania + 1), doubled when opponent notes exist and 2K fits in 18 keys.
	 */
	static function exportKeys(hasOpponent:Bool, keyMode:Int, base:Int):Int
	{
		switch (keyMode)
		{
			case 4: return 4;
			case 8: return 8;
			default: return (hasOpponent && base * 2 <= 18) ? base * 2 : base;
		}
	}

	/**
	 * Maps an FNF lane to an external column.
	 * Player lanes are 0..base-1, opponent lanes base..2*base-1. When the
	 * export keeps 2K, opponent lanes stay in the second half; otherwise
	 * (forced 4K/8K or 2K overflow) everything folds via `lane % keys`.
	 */
	static function exportColumn(lane:Int, base:Int, keys:Int):Int
	{
		if (lane < base && keys >= base)
			return lane;
		return lane % keys;
	}

	// ========================================================================
	//  PACKAGE (OSZ / MCZ) SUPPORT
	// ========================================================================

	/**
	 * Reads every file inside an .osz / .mcz zip. Returns entries as
	 * { fileName:String (basename only), entry:haxe.zip.Entry }.
	 */
	public static function readPackageEntries(path:String):Array<Dynamic>
	{
		#if sys
		var entries:Array<Dynamic> = [];
		var input:haxe.io.Input = File.read(path, true);
		try
		{
			var zipList:haxe.ds.List<haxe.zip.Entry> = haxe.zip.Reader.readZip(input);
			for (ze in zipList)
			{
				if (ze == null || ze.fileName == null) continue;
				var name:String = ze.fileName;
				var slash:Int = name.lastIndexOf('/');
				if (slash >= 0) name = name.substr(slash + 1);
				if (name.length == 0) continue;
				entries.push({fileName: name, entry: ze});
			}
		}
		catch (e:Dynamic)
		{
			input.close();
			throw 'Failed to read chart package: $e';
		}
		input.close();
		return entries;
		#else
		return [];
		#end
	}

	/**
	 * Lists all .osu / .mc difficulties inside a package, with a human
	 * readable label, decompressed content and the referenced audio name.
	 * format: 0 = osu, 1 = malody.
	 */
	public static function packageChartList(entries:Array<Dynamic>):Array<Dynamic>
	{
		var charts:Array<Dynamic> = [];
		for (e in entries)
		{
			var lower:String = e.fileName.toLowerCase();
			if (!lower.endsWith('.osu') && !lower.endsWith('.mc')) continue;

			var text:String = haxe.zip.Reader.unzip(e.entry).toString();
			var isOsu:Bool = lower.endsWith('.osu');
			var brief:Dynamic = isOsu ? osuMetaBrief(text) : mcMetaBrief(text);
			charts.push({
				format: isOsu ? 0 : 1,
				label: brief.title + ' [' + brief.version + ']' + (isOsu ? ' (osu!)' : ' (Malody)'),
				content: text,
				audioName: brief.audio,
				title: brief.title,
				version: brief.version
			});
		}
		return charts;
	}

	/**
	 * Reads the audio file referenced by the chart from inside the package.
	 * Returns { data:Bytes, name:String } using the REAL zip entry name
	 * (so the extension is correct even when the chart reference mismatches),
	 * or null when no audio can be found.
	 */
	public static function findPackageAudio(entries:Array<Dynamic>, audioName:String):Dynamic
	{
		var candidates:Array<Dynamic> = [];
		for (e in entries)
		{
			var lower:String = e.fileName.toLowerCase();
			if (lower.endsWith('.ogg') || lower.endsWith('.mp3') || lower.endsWith('.wav')
				|| lower.endsWith('.m4a') || lower.endsWith('.flac') || lower.endsWith('.aac'))
				candidates.push(e);
		}

		if (audioName != null && audioName.length > 0)
		{
			var target:String = audioName.split('\\').join('/');
			var slash:Int = target.lastIndexOf('/');
			if (slash >= 0) target = target.substr(slash + 1);
			target = target.split('"').join('').toLowerCase();
			for (c in candidates)
				if (c.fileName.toLowerCase() == target)
					return {data: haxe.zip.Reader.unzip(c.entry), name: c.fileName};
		}

		if (candidates.length == 1)
			return {data: haxe.zip.Reader.unzip(candidates[0].entry), name: candidates[0].fileName};
		return null;
	}

	/**
	 * Locates the audio file next to a standalone .osu / .mc chart
	 * (case-insensitive). Returns its full path or null.
	 */
	public static function findAdjacentAudio(chartPath:String, audioName:String):String
	{
		if (audioName == null || audioName.length == 0 || chartPath == null) return null;

		return findAdjacentFile(chartPath, audioName);
	}

	/** Generic case-insensitive lookup for a file next to a chart. */
	public static function findAdjacentFile(chartPath:String, fileName:String):String
	{
		if (fileName == null || fileName.length == 0 || chartPath == null) return null;

		#if sys
		var dir:String = '';
		var slash:Int = chartPath.lastIndexOf('/');
		if (slash >= 0) dir = chartPath.substr(0, slash);

		var name:String = fileName.split('\\').join('/');
		var nslash:Int = name.lastIndexOf('/');
		if (nslash >= 0) name = name.substr(nslash + 1);
		name = name.split('"').join('');
		if (name.length == 0) return null;

		var direct:String = (dir.length > 0 ? dir + '/' : '') + name;
		if (FileSystem.exists(direct)) return direct;

		if (dir.length > 0 && FileSystem.exists(dir))
		{
			var lower:String = name.toLowerCase();
			for (f in FileSystem.readDirectory(dir))
				if (f.toLowerCase() == lower)
					return dir + '/' + f;
		}
		return null;
		#else
		return null;
		#end
	}

	/** Background image name referenced by an osu chart ([Events] background). */
	public static function osuBackgroundName(text:String):String
	{
		var inEvents:Bool = false;
		for (raw in text.split('\n'))
		{
			var line:String = StringTools.trim(raw);
			if (line.startsWith('[') && line.endsWith(']'))
			{
				inEvents = (line == '[Events]');
				continue;
			}
			if (!inEvents || line.length == 0 || line.startsWith('//')) continue;
			var parts:Array<String> = line.split(',');
			if (parts.length < 3) continue;
			var type:String = StringTools.trim(parts[0]);
			if (type != '0' && type != 'Background' && type != 'Video') continue;
			if (type == 'Video') continue;
			var bg:String = StringTools.trim(parts[2]).split('"').join('');
			if (bg.length > 0) return bg;
		}
		return '';
	}

	/** Background image name referenced by a Malody chart (meta.background). */
	public static function malodyBackgroundName(text:String):String
	{
		try
		{
			var obj:Dynamic = Json.parse(stripBom(text));
			if (obj.meta != null && obj.meta.background != null)
			{
				var bg:String = StringTools.trim(Std.string(obj.meta.background));
				return (bg.length > 0) ? bg : '';
			}
		}
		catch (e:Dynamic) {}
		return '';
	}

	/**
	 * Reads the background image referenced by the chart from inside a package.
	 * Returns { data:Bytes, name:String } or null.
	 */
	public static function findPackageBackground(entries:Array<Dynamic>, bgName:String):Dynamic
	{
		if (bgName == null || bgName.length == 0) return null;
		var target:String = bgName.split('\\').join('/');
		var slash:Int = target.lastIndexOf('/');
		if (slash >= 0) target = target.substr(slash + 1);
		target = target.split('"').join('').toLowerCase();
		if (target.length == 0) return null;

		for (e in entries)
		{
			if (e.fileName.toLowerCase() == target)
				return {data: haxe.zip.Reader.unzip(e.entry), name: e.fileName};
		}
		return null;
	}

	/**
	 * Makes a package entry name safe for common zip consumers while
	 * preserving non-ASCII (UTF-8) characters. Only characters that are
	 * illegal in file paths or commonly break osu!/Malody are replaced.
	 */
	public static function sanitizePackageFileName(name:String):String
	{
		if (name == null) return '';
		var out:StringBuf = new StringBuf();
		for (i in 0...name.length)
		{
			var ch:String = name.charAt(i);
			var code:Int = name.charCodeAt(i);
			if (code < 32 || ch == '\\' || ch == '/' || ch == ':' || ch == '*' || ch == '?' || ch == '"' || ch == '<' || ch == '>' || ch == '|')
				out.add('_');
			else
				out.add(ch);
		}
		var result:String = StringTools.trim(out.toString());
		if (result.length == 0 || result == '.' || result == '..') return 'unnamed';
		return result;
	}

	static function writeZipDate(out:haxe.io.Output, date:Date):Void
	{
		var hour:Int = date.getHours();
		var min:Int = date.getMinutes();
		var sec:Int = date.getSeconds() >> 1;
		out.writeUInt16((hour << 11) | (min << 5) | sec);

		var year:Int = date.getFullYear() - 1980;
		var month:Int = date.getMonth() + 1;
		var day:Int = date.getDate();
		out.writeUInt16((year << 9) | (month << 5) | day);
	}

	/**
	 * Packs files into a zip archive (.osz / .mcz).
	 *
	 * This is a custom STORED zip writer. Haxe's own haxe.zip.Writer writes
	 * filename lengths as String.length (UTF-16 characters) instead of UTF-8
	 * bytes, which corrupts archives containing non-ASCII filenames. We write
	 * the local headers, central directory and EOCD manually and set the UTF-8
	 * flag so osu!/Malody can open packages with Chinese/Japanese names.
	 *
	 * entries: Array<{ fileName:String, data:haxe.io.Bytes }>.
	 */
	public static function packZip(entries:Array<Dynamic>, outPath:String):Bool
	{
		#if sys
		var output:haxe.io.Output = null;
		try
		{
			// sanitize + dedupe (same audio/background appears once per chart)
			var clean:Array<Dynamic> = [];
			var seen:Map<String, Bool> = new Map<String, Bool>();
			for (e in entries)
			{
				if (e == null || e.fileName == null || e.data == null) continue;
				var name:String = sanitizePackageFileName(e.fileName);
				if (name.length == 0) continue;
				if (seen.exists(name)) continue;
				seen.set(name, true);
				clean.push({fileName: name, data: e.data});
			}
			if (clean.length == 0) return false;

			output = File.write(outPath, true);

			// ---- local file headers + file data ----
			var central:Array<Dynamic> = [];
			var offset:Int = 0;
			for (e in clean)
			{
				var nameBytes:haxe.io.Bytes = haxe.io.Bytes.ofString(e.fileName);
				var data:haxe.io.Bytes = e.data;
				var crc:Int = haxe.crypto.Crc32.make(data);
				central.push({
					nameBytes: nameBytes,
					dataSize: data.length,
					crc: crc,
					offset: offset
				});

				output.writeInt32(0x04034B50); // local file header signature
				output.writeUInt16(20);         // version needed
				output.writeUInt16(0x0800);     // UTF-8 filename flag
				output.writeUInt16(0);          // method: stored
				writeZipDate(output, Date.now());
				output.writeInt32(crc);
				output.writeInt32(data.length); // compressed size
				output.writeInt32(data.length); // uncompressed size
				output.writeUInt16(nameBytes.length);
				output.writeUInt16(0);          // extra field length
				output.write(nameBytes);
				output.write(data);

				offset += 30 + nameBytes.length + data.length;
			}

			// ---- central directory ----
			var cdStart:Int = offset;
			var cdSize:Int = 0;
			for (c in central)
			{
				output.writeInt32(0x02014B50); // central directory header
				output.writeUInt16(20);         // version made by
				output.writeUInt16(20);         // version needed
				output.writeUInt16(0x0800);     // UTF-8 filename flag
				output.writeUInt16(0);          // method: stored
				writeZipDate(output, Date.now());
				output.writeInt32(c.crc);
				output.writeInt32(c.dataSize);
				output.writeInt32(c.dataSize);
				output.writeUInt16(c.nameBytes.length);
				output.writeUInt16(0);          // extra field length
				output.writeUInt16(0);          // comment length
				output.writeUInt16(0);          // disk number start
				output.writeUInt16(0);          // internal attributes
				output.writeInt32(0);           // external attributes
				output.writeInt32(c.offset);    // local header offset
				output.write(c.nameBytes);
				cdSize += 46 + c.nameBytes.length;
			}

			// ---- end of central directory ----
			output.writeInt32(0x06054B50);
			output.writeUInt16(0);
			output.writeUInt16(0);
			output.writeUInt16(central.length);
			output.writeUInt16(central.length);
			output.writeInt32(cdSize);
			output.writeInt32(cdStart);
			output.writeUInt16(0);
			output.close();
			output = null;

			// Post-write validation: refuse to leave a corrupt package behind.
			if (!validateZipArchive(outPath))
			{
				if (FileSystem.exists(outPath)) FileSystem.deleteFile(outPath);
				return false;
			}
			return FileSystem.exists(outPath);
		}
		catch (e:Dynamic)
		{
			if (output != null)
			{
				try { output.close(); } catch (_:Dynamic) {}
			}
			if (FileSystem.exists(outPath))
			{
				try { FileSystem.deleteFile(outPath); } catch (_:Dynamic) {}
			}
			return false;
		}
		#else
		return false;
		#end
	}

	/**
	 * Reads a freshly written package back with the standard Haxe zip reader
	 * to verify structure, per-entry CRC and central directory offsets before
	 * returning success.
	 */
	static function validateZipArchive(path:String):Bool
	{
		#if sys
		var input:sys.io.FileInput = null;
		var end:sys.io.FileInput = null;
		var cd:sys.io.FileInput = null;
		try
		{
			input = File.read(path, true);
			var list:haxe.ds.List<haxe.zip.Entry> = haxe.zip.Reader.readZip(input);
			input.close();
			input = null;
			var count:Int = 0;
			for (e in list)
			{
				if (e == null || e.fileName == null) continue;
				var data:haxe.io.Bytes = haxe.zip.Reader.unzip(e);
				if (data == null) return false;
				if (e.crc32 != null && haxe.crypto.Crc32.make(data) != e.crc32) return false;
				count++;
			}
			if (count == 0) return false;

			// Central directory sanity check: EOCD must point back to a valid
			// central directory whose end lines up with the EOCD record.
			var fileSize:Int = Std.int(FileSystem.stat(path).size);
			if (fileSize < 22) return false;

			end = File.read(path, true);
			end.seek(fileSize - 22, sys.io.FileSeek.SeekBegin);
			var eocd:Int = end.readInt32();
			if (eocd != 0x06054B50)
			{
				end.close();
				end = null;
				return false;
			}
			end.readUInt16(); // disk number
			end.readUInt16(); // disk with CD
			end.readUInt16(); // entries on this disk
			end.readUInt16(); // total entries
			var cdSize:Int = end.readInt32();
			var cdOffset:Int = end.readInt32();
			var commentLen:Int = end.readUInt16();
			end.close();
			end = null;

			if (commentLen != 0 || cdOffset + cdSize != fileSize - 22) return false;

			cd = File.read(path, true);
			cd.seek(cdOffset, sys.io.FileSeek.SeekBegin);
			var cdSig:Int = cd.readInt32();
			cd.close();
			cd = null;
			return cdSig == 0x02014B50;
		}
		catch (e:Dynamic)
		{
			if (input != null) { try { input.close(); } catch (_:Dynamic) {} }
			if (end != null) { try { end.close(); } catch (_:Dynamic) {} }
			if (cd != null) { try { cd.close(); } catch (_:Dynamic) {} }
			return false;
		}
		#else
		return false;
		#end
	}

	/** Extracts the audio file name referenced by a standalone chart. */
	public static function chartAudioName(text:String, format:Int):String
	{
		if (format == 0) return osuMetaBrief(text).audio;
		return mcMetaBrief(text).audio;
	}

	/** Song title referenced by a standalone chart. */
	public static function chartTitle(text:String, format:Int):String
	{
		if (format == 0) return osuMetaBrief(text).title;
		return mcMetaBrief(text).title;
	}

	/** Difficulty name referenced by a standalone chart. */
	public static function chartDifficultyName(text:String, format:Int):String
	{
		if (format == 0) return osuMetaBrief(text).version;
		return mcMetaBrief(text).version;
	}

	/** Key count of an osu!mania chart (CircleSize). 0 when unavailable. */
	public static function osuKeyCount(text:String):Int
	{
		var inDiff:Bool = false;
		for (raw in text.split('\n'))
		{
			var line:String = StringTools.trim(raw);
			if (line.startsWith('[') && line.endsWith(']'))
			{
				inDiff = (line == '[Difficulty]');
				continue;
			}
			if (!inDiff) continue;
			var idx:Int = line.indexOf(':');
			if (idx < 0) continue;
			if (StringTools.trim(line.substr(0, idx)) != 'CircleSize') continue;
			var keys:Null<Int> = Std.parseInt(StringTools.trim(line.substr(idx + 1)));
			return (keys != null && keys > 0) ? keys : 0;
		}
		return 0;
	}

	/** Key count of a Malody chart (meta.mode_ext.column). 0 when unavailable. */
	public static function malodyKeyCount(text:String):Int
	{
		try
		{
			var obj:Dynamic = Json.parse(stripBom(text));
			if (obj.meta != null && obj.meta.mode_ext != null && obj.meta.mode_ext.column != null)
			{
				var keys:Null<Int> = Std.parseInt(Std.string(obj.meta.mode_ext.column));
				return (keys != null && keys > 0) ? keys : 0;
			}
		}
		catch (e:Dynamic) {}
		return 0;
	}

	static function osuMetaBrief(text:String):Dynamic
	{
		var title:String = 'Unknown';
		var version:String = 'Normal';
		var audio:String = '';
		var inGen:Bool = false;
		var inMeta:Bool = false;
		for (raw in text.split('\n'))
		{
			var line:String = StringTools.trim(raw);
			if (line.startsWith('[') && line.endsWith(']'))
			{
				inGen = (line == '[General]');
				inMeta = (line == '[Metadata]');
				continue;
			}
			var idx:Int = line.indexOf(':');
			if (idx < 0) continue;
			var key:String = line.substr(0, idx).trim();
			var value:String = line.substr(idx + 1).trim();
			if (inMeta && key == 'Title' && title == 'Unknown') title = value;
			if (inMeta && key == 'TitleUnicode' && value.length > 0) title = value;
			if (inMeta && key == 'Version' && StringTools.trim(value).length > 0) version = value;
			if (inGen && key == 'AudioFilename' && value.length > 0) audio = value;
		}
		return {title: title, version: version, audio: audio};
	}

	static function mcMetaBrief(text:String):Dynamic
	{
		try
		{
			var obj:Dynamic = Json.parse(stripBom(text));
			var meta:Dynamic = obj.meta;
			var title:String = (meta != null && meta.song != null && meta.song.title != null)
				? Std.string(meta.song.title) : 'Unknown';
			var version:String = (meta != null && meta.version != null) ? StringTools.trim(Std.string(meta.version)) : '';
			if (version.length == 0) version = 'Normal';
			var audio:String = '';
			var notes:Array<Dynamic> = cast obj.note;
			if (notes != null)
			{
				for (n in notes)
				{
					if (n != null && n.type != null && Std.int(n.type) == 1 && n.sound != null)
					{
						audio = Std.string(n.sound);
						break;
					}
				}
			}
			return {title: title, version: version, audio: audio};
		}
		catch (e:Dynamic) return {title: 'Unknown', version: 'Normal', audio: ''};
	}

	// ========================================================================
	//  EXPORT AUDIO (copy the instrumental next to the exported chart)
	// ========================================================================

	/**
	 * Locates the instrumental audio of a song on disk (mods first, then
	 * assets). Returns { path:String, ext:String } or null when there is no
	 * music file (e.g. RAM-only import).
	 */
	public static function findInstAudioFile(songName:String):Dynamic
	{
		if (songName == null || songName.length == 0) return null;
		#if sys
		var formatted:String = Paths.formatToSongPath(songName);
		var exts:Array<String> = ['ogg', 'mp3', 'wav', 'm4a'];

		for (ext in exts)
		{
			var file:String = Paths.modFolders('songs/' + formatted + '/Inst.' + ext);
			if (FileSystem.exists(file)) return {path: file, ext: ext};
		}
		for (ext in exts)
		{
			var file:String = Paths.getPreloadPath('songs/' + formatted + '/Inst.' + ext);
			if (FileSystem.exists(file)) return {path: file, ext: ext};
		}
		return null;
		#else
		return null;
		#end
	}

	/**
	 * Copies the instrumental next to the just-exported chart so osu!/Malody
	 * can find it. chartPath is the saved .osu/.mc path, srcAudioPath the
	 * source file, audioName the file name the chart references.
	 */
	public static function exportAudioAlongside(chartPath:String, srcAudioPath:String, audioName:String):Bool
	{
		if (srcAudioPath == null || audioName == null || audioName.length == 0) return false;

		#if sys
		var safeName:String = audioName.split('\\').join('/');
		var slash:Int = safeName.lastIndexOf('/');
		if (slash >= 0) safeName = safeName.substr(slash + 1);
		if (safeName.length == 0) return false;

		var dir:String = '';
		var cslash:Int = chartPath.lastIndexOf('/');
		if (cslash >= 0) dir = chartPath.substr(0, cslash);

		var target:String = (dir.length > 0 ? dir + '/' : '') + safeName;
		try
		{
			if (!FileSystem.exists(srcAudioPath)) return false;
			if (srcAudioPath == target || FileSystem.exists(target)) return true;
			File.copy(srcAudioPath, target);
			return FileSystem.exists(target);
		}
		catch (e:Dynamic) return false;
		#else
		return false;
		#end
	}

	/** Writes raw audio bytes next to the exported chart. */
	public static function writeAudioAlongside(chartPath:String, audioBytes:haxe.io.Bytes, audioName:String):Bool
	{
		if (audioBytes == null || audioBytes.length == 0 || audioName == null || audioName.length == 0) return false;

		#if sys
		var safeName:String = audioName.split('\\').join('/');
		var slash:Int = safeName.lastIndexOf('/');
		if (slash >= 0) safeName = safeName.substr(slash + 1);
		if (safeName.length == 0) return false;

		var dir:String = '';
		var cslash:Int = chartPath.lastIndexOf('/');
		if (cslash >= 0) dir = chartPath.substr(0, cslash);
		var target:String = (dir.length > 0 ? dir + '/' : '') + safeName;

		try
		{
			File.saveBytes(target, audioBytes);
			return FileSystem.exists(target);
		}
		catch (e:Dynamic) return false;
		#else
		return false;
		#end
	}

	/**
	 * Decodes any audio bytes lime can read (ogg/mp3/wav...) into a 16-bit PCM
	 * WAV file. Malody doesn't reliably play MP3, so this is used when the only
	 * instrumental on disk is an MP3. Returns null on failure.
	 */
	public static function audioBytesToWav(audioBytes:haxe.io.Bytes):haxe.io.Bytes
	{
		#if sys
		try
		{
			if (audioBytes == null || audioBytes.length == 0) return null;
			var limeBytes:lime.utils.Bytes = lime.utils.Bytes.ofData(audioBytes.getData());
			var buffer:lime.media.AudioBuffer = lime.media.AudioBuffer.fromBytes(limeBytes);
			if (buffer == null || buffer.data == null)
			{
				// lime can't decode MP3 on Windows/Android — use the native dr_mp3 decoder
				#if cpp
				return DrMp3Tools.decodeBytesToWav(audioBytes);
				#else
				return null;
				#end
			}

			var sampleRate:Int = buffer.sampleRate > 0 ? buffer.sampleRate : 44100;
			var channels:Int = buffer.channels > 0 ? buffer.channels : 2;
			var view:lime.utils.UInt8Array = buffer.data;
			var bytes:haxe.io.Bytes = view.buffer;
			var byteOffset:Int = view.byteOffset;
			var byteLength:Int = view.byteLength;

			var out:haxe.io.BytesBuffer = new haxe.io.BytesBuffer();
			out.addString('RIFF');
			var dataSize:Int = 0;

			if (buffer.bitsPerSample == 16)
			{
				var samples:Int = Std.int(byteLength / 2);
				dataSize = samples * 2;
				writeWavHeader(out, dataSize, sampleRate, channels);
				var intData:lime.utils.Int16Array = lime.utils.Int16Array.fromBytes(bytes, byteOffset, samples);
				for (i in 0...samples)
					writeLE16(out, intData[i]);
			}
			else
			{
				// lime native decoders deliver Float32 samples
				var samples:Int = Std.int(byteLength / 4);
				dataSize = samples * 2;
				writeWavHeader(out, dataSize, sampleRate, channels);
				var floatData:lime.utils.Float32Array = lime.utils.Float32Array.fromBytes(bytes, byteOffset, samples);
				for (i in 0...samples)
				{
					var v:Float = floatData[i];
					if (Math.isNaN(v)) v = 0;
					if (v > 1) v = 1;
					else if (v < -1) v = -1;
					writeLE16(out, Std.int(v * 32767));
				}
			}
			return out.getBytes();
		}
		catch (e:Dynamic) return null;
		#else
		return null;
		#end
	}

	static function writeWavHeader(buf:haxe.io.BytesBuffer, dataSize:Int, sampleRate:Int, channels:Int):Void
	{
		buf.addString('WAVE');
		buf.addString('fmt ');
		writeLE32(buf, 16);
		writeLE16(buf, 1); // PCM
		writeLE16(buf, channels);
		writeLE32(buf, sampleRate);
		writeLE32(buf, sampleRate * channels * 2);
		writeLE16(buf, channels * 2);
		writeLE16(buf, 16);
		buf.addString('data');
		writeLE32(buf, dataSize);
	}

	static function writeLE16(buf:haxe.io.BytesBuffer, v:Int):Void
	{
		buf.addByte(v & 0xFF);
		buf.addByte((v >> 8) & 0xFF);
	}

	static function writeLE32(buf:haxe.io.BytesBuffer, v:Int):Void
	{
		buf.addByte(v & 0xFF);
		buf.addByte((v >> 8) & 0xFF);
		buf.addByte((v >> 16) & 0xFF);
		buf.addByte((v >>> 24) & 0xFF);
	}
}
