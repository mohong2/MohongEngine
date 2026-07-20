package editors.content;

import Song;
import Song.SwagSong;
import Section.SwagSection;
import haxe.Json;
import flixel.util.FlxSort;
import mohong.TraceManager;

class CneExport
{
	public static final CNE_CHART_VERSION:String = "1.6.0";

	// ========================================================================
	// PSYCH -> CNE
	// ========================================================================

	public static function psychToCne(song:SwagSong):String
	{
		var cne:Dynamic = buildCneChart(song);
		return Json.stringify(cne, "\t");
	}

	static function buildCneChart(song:SwagSong):Dynamic
	{
		var bpm:Float = song.bpm;
		var speed:Float = song.speed > 0 ? song.speed : 1.0;
		var outStage:String = song.stage != null ? song.stage : "stage";

		// Collect note types
		var noteTypeMap:Map<String, Int> = new Map<String, Int>();
		noteTypeMap.set("", 0);
		var noteTypes:Array<String> = [];
		var nextTypeId:Int = 1;

		function getNoteTypeId(name:String):Int
		{
			if (name == null || name == "") return 0;
			if (noteTypeMap.exists(name)) return noteTypeMap.get(name);
			noteTypeMap.set(name, nextTypeId);
			noteTypes.push(name);
			return nextTypeId++;
		}

		// Build strumLines note arrays
		var playerNotes:Array<Dynamic> = [];
		var opponentNotes:Array<Dynamic> = [];
		var gfNotes:Array<Dynamic> = [];
		var hasGfNotes:Bool = false;

		var curTime:Float = 0;
		var curBpm:Float = bpm;
		var curCrochet:Float = (60 / curBpm) * 1000;
		var beatsPerMeasure:Float = 4;

		if (song.notes != null)
		{
			for (section in song.notes)
			{
				if (section == null)
				{
					curTime += curCrochet * beatsPerMeasure;
					continue;
				}

				if (section.sectionBeats > 0)
					beatsPerMeasure = section.sectionBeats;

				if (section.changeBPM && section.bpm > 0)
				{
					curBpm = section.bpm;
					curCrochet = (60 / curBpm) * 1000;
				}

				if (section.sectionNotes != null)
				{
					for (note in section.sectionNotes)
					{
						var strumTime:Float = note[0];
						var rawData:Int = Std.int(note[1]);
						if (rawData < 0) continue;

						var data:Int = rawData % 4;
						var gottaHitNote:Bool = (rawData < 4);

						var sLen:Float = (note.length > 2 && note[2] != null) ? note[2] : 0;
						var noteTypeName:String = (note.length > 3 && note[3] != null) ? Std.string(note[3]) : "";
						var noteTypeId:Int = getNoteTypeId(noteTypeName);

						var cneNote:Dynamic = {
							time: strumTime,
							id: data,
							type: noteTypeId,
							sLen: sLen
						};

						if (section.gfSection == true && gottaHitNote == section.mustHitSection)
						{
							gfNotes.push(cneNote);
							hasGfNotes = true;
						}
						else if (gottaHitNote)
							playerNotes.push(cneNote);
						else
							opponentNotes.push(cneNote);
					}
				}

				curTime += curCrochet * beatsPerMeasure;
			}
		}

		function sortFn(a:Dynamic, b:Dynamic):Int
		{
			return FlxSort.byValues(FlxSort.ASCENDING, a.time, b.time);
		}
		playerNotes.sort(sortFn);
		opponentNotes.sort(sortFn);
		gfNotes.sort(sortFn);

		// Build strumLines
		var strumLines:Array<Dynamic> = [];

		var p2:String = song.player2 != null ? song.player2 : "dad";
		var p1:String = song.player1 != null ? song.player1 : "bf";
		var gfName:String = song.gfVersion != null ? song.gfVersion : "gf";

		strumLines.push({
			characters: [p2],
			type: 0,
			position: (p2.toLowerCase().startsWith("gf")) ? "girlfriend" : "dad",
			notes: opponentNotes,
			visible: true
		});

		strumLines.push({
			characters: [p1],
			type: 1,
			position: "boyfriend",
			notes: playerNotes,
			visible: true
		});

		if (hasGfNotes || (gfName != "none" && gfName != ""))
		{
			strumLines.push({
				characters: [gfName],
				type: 2,
				position: "girlfriend",
				notes: gfNotes,
				visible: hasGfNotes
			});
		}

		// Build events
		var cneEvents:Array<Dynamic> = [];
		if (song.events != null)
		{
			for (event in song.events)
			{
				if (event == null) continue;
				var t:Float = event[0];
				var subEvents:Array<Dynamic> = event[1];
				if (subEvents == null) continue;

				for (sub in subEvents)
				{
					var evtName:String = sub[0];
					var evtParams:Array<Dynamic> = [];

					switch (evtName)
					{
						case "Change Scroll Speed":
							evtParams.push(false);
							evtParams.push(Std.parseFloat(Std.string(sub[1])));
							evtParams.push(0);
							evtName = "Scroll Speed Change";

						case "Add Camera Zoom":
							evtParams.push(Std.parseFloat(Std.string(sub[1])));
							evtParams.push(Std.parseFloat(Std.string(sub[2])));

						case "Play Animation":
							evtParams.push(0);
							evtParams.push(sub[1]);

						default:
							evtParams.push(sub[1]);
							evtParams.push(sub[2]);
					}

					cneEvents.push({
						name: evtName,
						time: t,
						params: evtParams
					});
				}
			}
		}

		cneEvents.sort(function(a:Dynamic, b:Dynamic):Int {
			return FlxSort.byValues(FlxSort.ASCENDING, a.time, b.time);
		});

		// Build meta
		var meta:Dynamic = {
			name: song.song,
			bpm: bpm,
			needsVoices: song.needsVoices != false,
			beatsPerMeasure: 4,
			stepsPerBeat: 4,
			icon: "face",
			color: [255, 255, 255],
			difficulties: [],
			variants: [],
			coopAllowed: false,
			opponentModeAllowed: false,
			instSuffix: "",
			vocalsSuffix: ""
		};

		// Final chart object
		var chart:Dynamic = {
			codenameChart: true,
			chartVersion: CNE_CHART_VERSION,
			strumLines: strumLines,
			events: cneEvents,
			meta: meta,
			scrollSpeed: speed,
			stage: outStage,
			noteTypes: noteTypes
		};

		return chart;
	}

	// ========================================================================
	// CNE -> PSYCH
	// ========================================================================

	public static function cneToPsych(jsonStr:String):SwagSong
	{
		var data:Dynamic = Json.parse(jsonStr);
		return buildPsychSong(data);
	}

	public static function isCneFormat(jsonStr:String):Bool
	{
		try
		{
			var data:Dynamic = Json.parse(jsonStr);
			return (data.codenameChart == true || data.codenameChart == "true")
				&& data.strumLines != null;
		}
		catch (e:Dynamic) { return false; }
	}

	public static function isCneFormatObj(data:Dynamic):Bool
	{
		return (data.codenameChart == true || data.codenameChart == "true")
			&& data.strumLines != null;
	}

	static function buildPsychSong(data:Dynamic):SwagSong
	{
		var meta:Dynamic = data.meta;
		var songName:String = (meta != null && meta.name != null) ? meta.name : "Unknown";
		var bpm:Float = (meta != null && meta.bpm != null) ? meta.bpm : 150;
		var needsVoices:Bool = (meta != null) ? (meta.needsVoices != false) : true;
		var scrollSpeed:Float = (data.scrollSpeed != null) ? data.scrollSpeed : 1.0;
		var outStage:String = (data.stage != null) ? data.stage : "stage";

		var player1:String = "bf";
		var player2:String = "dad";
		var gfVersion:String = "gf";

		// Extract characters from strumLines
		var strumLines:Array<Dynamic> = data.strumLines;
		if (strumLines != null)
		{
			for (line in strumLines)
			{
				var lineType:Int = line.type;
				var chars:Array<Dynamic> = line.characters;
				if (chars != null && chars.length > 0)
				{
					switch (lineType)
					{
						case 1: player1 = chars[0];
						case 0: player2 = chars[0];
						case 2: gfVersion = chars[0];
					}
				}
			}
		}

		// Collect notes from strumLines
		var playerNotes:Array<Dynamic> = [];
		var opponentNotes:Array<Dynamic> = [];
		var gfNotes:Array<Dynamic> = [];
		var noteTypes:Array<String> = data.noteTypes;
		if (noteTypes == null) noteTypes = [];

		function mapNote(lineType:Int, note:Dynamic):Dynamic
		{
			var typeName:String = "";
			var noteTypeIdx:Int = Std.int(note.type);
			if (noteTypeIdx > 0 && noteTypeIdx - 1 < noteTypes.length)
				typeName = noteTypes[noteTypeIdx - 1];

			return {
				time: note.time,
				id: note.id,
				sLen: note.sLen != null ? note.sLen : 0,
				typeName: typeName,
				lineType: lineType
			};
		}

		if (strumLines != null)
		{
			for (line in strumLines)
			{
				var lineType:Int = line.type;
				var notes:Array<Dynamic> = line.notes;
				if (notes == null) continue;

				for (note in notes)
				{
					var mapped = mapNote(lineType, note);
					switch (lineType)
					{
						case 1: playerNotes.push(mapped);
						case 0: opponentNotes.push(mapped);
						case 2: gfNotes.push(mapped);
					}
				}
			}
		}

		function sortFn(a:Dynamic, b:Dynamic):Int
		{
			return FlxSort.byValues(FlxSort.ASCENDING, a.time, b.time);
		}

		var allNotes:Array<Dynamic> = playerNotes.concat(opponentNotes).concat(gfNotes);
		allNotes.sort(sortFn);

		var lastNoteTime:Float = 0;
		if (allNotes.length > 0)
			lastNoteTime = allNotes[allNotes.length - 1].time;

		// Build sections
		var sections:Array<SwagSection> = [];
		var curTime:Float = 0;
		var curBpm:Float = bpm;

		// Extract BPM and focus events
		var bpmChanges:Array<Dynamic> = [];
		var focusChanges:Array<Dynamic> = [];
		if (data.events != null)
		{
			for (event in cast(data.events, Array<Dynamic>))
			{
				if (event.name == "BPM Change")
					bpmChanges.push(event);
				else if (event.name == "Camera Movement")
					focusChanges.push(event);
			}
		}
		bpmChanges.sort(sortFn);
		focusChanges.sort(sortFn);

		var lastMustHit:Bool = true;
		var focusIdx:Int = 0;
		var secIdx:Int = 0;
		var bpmChangeIdx:Int = 0;
		var beatsPerMeasure:Float = 4;

		gfNotes.sort(sortFn);
		playerNotes.sort(sortFn);
		opponentNotes.sort(sortFn);

		var gfIdx:Int = 0;
		var pIdx:Int = 0;
		var oIdx:Int = 0;

		while (curTime <= lastNoteTime + 1)
		{
			// Apply BPM changes at section start
			while (bpmChangeIdx < bpmChanges.length && bpmChanges[bpmChangeIdx].time <= curTime)
			{
				var evt = bpmChanges[bpmChangeIdx];
				if (evt.params != null && evt.params.length > 0)
					curBpm = evt.params[0];
				bpmChangeIdx++;
			}

			// Apply focus changes
			while (focusIdx < focusChanges.length && focusChanges[focusIdx].time <= curTime)
			{
				var evt = focusChanges[focusIdx];
				if (evt.params != null && evt.params.length > 0)
					lastMustHit = (evt.params[0] == 1);
				focusIdx++;
			}

			var curCrochet:Float = (60 / curBpm) * 1000;
			var sectionEnd:Float = curTime + curCrochet * beatsPerMeasure;
			var sectionNotes:Array<Dynamic> = [];
			var hasGfInSection:Bool = false;

			// Add GF notes
			while (gfIdx < gfNotes.length && gfNotes[gfIdx].time < sectionEnd)
			{
				var n = gfNotes[gfIdx];
				sectionNotes.push([n.time, n.id + (lastMustHit ? 0 : 4), n.sLen, n.typeName]);
				hasGfInSection = true;
				gfIdx++;
			}

			// Add player notes
			while (pIdx < playerNotes.length && playerNotes[pIdx].time < sectionEnd)
			{
				var n = playerNotes[pIdx];
				sectionNotes.push([n.time, n.id + (lastMustHit ? 0 : 4), n.sLen, n.typeName]);
				pIdx++;
			}

			// Add opponent notes
			while (oIdx < opponentNotes.length && opponentNotes[oIdx].time < sectionEnd)
			{
				var n = opponentNotes[oIdx];
				sectionNotes.push([n.time, n.id + (lastMustHit ? 4 : 0), n.sLen, n.typeName]);
				oIdx++;
			}

			sectionNotes.sort(function(a:Array<Dynamic>, b:Array<Dynamic>):Int {
				return FlxSort.byValues(FlxSort.ASCENDING, a[0], b[0]);
			});

			var sec:SwagSection = {
				sectionNotes: sectionNotes,
				sectionBeats: beatsPerMeasure,
				mustHitSection: lastMustHit,
				gfSection: hasGfInSection,
				altAnim: false,
				changeBPM: false,
				bpm: curBpm
			};

			sec.changeBPM = (secIdx == 0 || sections[sections.length - 1].bpm != curBpm);
			sections.push(sec);

			curTime = sectionEnd;
			secIdx++;
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
				bpm: bpm
			});
		}

		// Convert CNE events to Psych format
		var psychEvents:Array<Dynamic> = [];
		if (data.events != null)
		{
			var sortedEvents:Array<Dynamic> = cast data.events;
			sortedEvents.sort(function(a:Dynamic, b:Dynamic):Int {
				return FlxSort.byValues(FlxSort.ASCENDING, a.time, b.time);
			});

			var i:Int = 0;
			while (i < sortedEvents.length)
			{
				var t:Float = sortedEvents[i].time;
				var subEvents:Array<Dynamic> = [];

				while (i < sortedEvents.length && sortedEvents[i].time == t)
				{
					var event = sortedEvents[i];
					var ename:String = event.name;
					var eparams:Array<Dynamic> = event.params != null ? event.params : [];

					switch (ename)
					{
						case "Scroll Speed Change":
							subEvents.push(["Change Scroll Speed",
								eparams.length > 1 ? Std.string(eparams[1]) : "1",
								eparams.length > 2 ? Std.string(eparams[2]) : "0"]);

						case "Add Camera Zoom":
							subEvents.push(["Add Camera Zoom",
								eparams.length > 0 ? Std.string(eparams[0]) : "0.015",
								eparams.length > 1 ? Std.string(eparams[1]) : "0.03"]);

						case "Play Animation":
							subEvents.push(["Play Animation",
								eparams.length > 1 ? Std.string(eparams[1]) : "",
								"bf"]);

						case "Camera Movement", "BPM Change":
							// Handled by sections above

						default:
							var v1:String = eparams.length > 0 ? Std.string(eparams[0]) : "";
							var v2:String = eparams.length > 1 ? Std.string(eparams[1]) : "";
							subEvents.push([ename, v1, v2]);
					}
					i++;
				}

				if (subEvents.length > 0)
					psychEvents.push([t, subEvents]);
			}
		}

		// Build result
		var result:SwagSong = {
			song: songName,
			notes: sections,
			events: psychEvents,
			bpm: bpm,
			needsVoices: needsVoices,
			speed: scrollSpeed,
			offset: 0,
			player1: player1,
			player2: player2,
			gfVersion: gfVersion,
			stage: outStage,
			format: "psych_v1",
			validScore: true
		};

		return result;
	}
}
