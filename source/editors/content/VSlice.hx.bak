// VSlice.hx
package editors.content;

import Song;
import Section.SwagSection;
import backend.Difficulty;
import flixel.util.FlxSort;

// Chart Types
typedef VSliceChart =
{
	var scrollSpeed:Dynamic;      // Map<String, Float>
	var events:Array<VSliceEvent>;
	var notes:Dynamic;             // Map<String, Array<VSliceNote>>
	var generatedBy:String;
	var version:String;
}

typedef VSliceNote =
{
	var t:Float;                   // Strum time
	var d:Int;                     // Note data
	@:optional var l:Null<Float>;  // Sustain Length
	@:optional var k:String;       // Note type (k = kind)
}

typedef VSliceEvent =
{
	var t:Float;    // Strum time
	var e:String;   // Event name
	var v:Dynamic;  // Values
}

// Metadata Types
typedef VSliceMetadata = 
{
	var songName:String;
	var artist:String;
	var charter:String;
	var playData:VSlicePlayData;
	var timeFormat:String;
	var timeChanges:Array<VSliceTimeChange>;
	var generatedBy:String;
	var version:String;
}

typedef VSlicePlayData =
{
	var difficulties:Array<String>;
	var characters:VSliceCharacters;
	var noteStyle:String;
	var stage:String;
}

typedef VSliceCharacters =
{
	var player:String;
	var girlfriend:String;
	var opponent:String;
}

typedef VSliceTimeChange =
{
	var t:Float;     // Time in ms
	var bpm:Float;
	@:optional var n:Int;  // Beats per measure (time signature numerator)
	@:optional var d:Int;  // Steps per beat (time signature denominator)
}

// Package
typedef VSlicePackage =
{
	var chart:VSliceChart;
	var metadata:VSliceMetadata;
}

// Psych package for conversion
typedef PsychPackage = 
{
	var difficulties:Map<String, SwagSong>;
	var events:Song.SwagSong;
}

class VSlice
{
	public static final chartVersion = '2.0.0';
	public static final metadataVersion = '2.2.3';

	/**
	 * Converts V-Slice chart + metadata to Psych Engine chart format
	 */
	public static function convertToPsych(chart:VSliceChart, metadata:VSliceMetadata):PsychPackage
	{
		var songDifficulties:Map<String, SwagSong> = new Map<String, SwagSong>();
		
		// Sort time changes
		var timeChanges:Array<VSliceTimeChange> = cast metadata.timeChanges;
		timeChanges.sort(sortByTime);
		
		var songBpm:Float = timeChanges[0].bpm;
		timeChanges.shift(); // Remove first entry (it's the initial BPM)

		// Stage name conversion
		var stage:String = metadata.playData.stage;
		stage = convertStageName(stage);

		// Find last note time across all difficulties
		var lastNoteTime:Float = 0;
		var notesMap:Map<String, Array<VSliceNote>> = new Map<String, Array<VSliceNote>>();
		
		for (diff in metadata.playData.difficulties)
		{
			var diffNotes:Array<VSliceNote> = cast Reflect.field(chart.notes, diff);
			if(diffNotes == null) diffNotes = [];
			diffNotes.sort(sortByTime);
			notesMap.set(diff, diffNotes);

			if(diffNotes.length > 0)
			{
				var lastNote = diffNotes[diffNotes.length - 1];
				if(lastNote.t > lastNoteTime) lastNoteTime = lastNote.t;
			}
		}

		// Build section times with proper BPM change tracking
		var sectionTimes:Array<Float> = [];
		var sectionBeatsArr:Array<Float> = []; // beats per section
		var sectionBpms:Array<Float> = [];     // BPM per section
		var time:Float = 0;
		var bpm:Float = songBpm;
		var bpmChangeIndex:Int = 0;

		while(time < lastNoteTime + 1)
		{
			// Apply any BPM changes that occur AT or before this section start time
			while (bpmChangeIndex < timeChanges.length && time >= timeChanges[bpmChangeIndex].t)
			{
				bpm = timeChanges[bpmChangeIndex].bpm;
				bpmChangeIndex++;
			}

			// Use beats per measure from timeChange if available (default 4)
			var beatsPerMeasure:Float = 4;
			if (bpmChangeIndex > 0 && bpmChangeIndex <= timeChanges.length)
			{
				var prevChange = timeChanges[bpmChangeIndex - 1];
				if (prevChange.n != null) beatsPerMeasure = prevChange.n;
			}
			else if (timeChanges.length > 0 && timeChanges[0].n != null)
				beatsPerMeasure = timeChanges[0].n;

			var sectionTime:Float = Conductor.calculateCrochet(bpm) * beatsPerMeasure;

			sectionTimes.push(time);
			sectionBeatsArr.push(beatsPerMeasure);
			sectionBpms.push(bpm);
			time += sectionTime;
		}

		// Determine mustHit sections from FocusCamera events
		var sectionMustHits:Array<Bool> = [];
		var lastMustHit:Bool = false; // default to opponent focus

		if(chart.events != null)
		{
			var focusEvents = chart.events.filter(function(e) return e.e == 'FocusCamera');
			focusEvents.sort(sortByTime);

			var focusIdx:Int = 0;
			for (i in 0...sectionTimes.length)
			{
				var sectionStart = sectionTimes[i];
				var sectionEnd = (i + 1 < sectionTimes.length) ? sectionTimes[i + 1] : Math.POSITIVE_INFINITY;
				
				// Process FocusCamera events that fall within or at the start of this section
				while (focusIdx < focusEvents.length && focusEvents[focusIdx].t < sectionEnd)
				{
					if (focusEvents[focusIdx].t >= sectionStart || focusIdx == 0)
					{
						var event = focusEvents[focusIdx];
						var target:Int = 0;
						
						if (Std.isOfType(event.v, String))
							target = Std.parseInt(event.v);
						else if (Reflect.hasField(event.v, 'char'))
							target = Std.parseInt(Std.string(Reflect.field(event.v, 'char')));
						
						// In V-Slice: 0 = player focused, 1 = opponent focused
						// In Psych: mustHitSection = true means player focused
						lastMustHit = (target == 0);
					}
					focusIdx++;
				}
				sectionMustHits[i] = lastMustHit;
			}
		}
		
		// Fill remaining mustHit sections with the last known mustHit state
		while (sectionMustHits.length < sectionTimes.length)
			sectionMustHits.push(lastMustHit);

		// Create sections for each difficulty
		for (diff in metadata.playData.difficulties)
		{
			var notes:Array<VSliceNote> = notesMap.get(diff);
			if(notes == null) notes = [];
			notes.sort(sortByTime);

			var scrollSpeed:Float = 1.0;
			if(Reflect.hasField(chart.scrollSpeed, diff))
				scrollSpeed = Reflect.field(chart.scrollSpeed, diff);
			else if(Reflect.hasField(chart.scrollSpeed, 'default'))
				scrollSpeed = Reflect.field(chart.scrollSpeed, 'default');

			var sections:Array<SwagSection> = [];
			var currentBpm:Float = songBpm;
			var lastBpm:Float = songBpm;
			var bpmIdx:Int = 0;

			for (i in 0...sectionTimes.length)
			{
				// Apply BPM changes that occur at or before this section
				while (bpmIdx < timeChanges.length && sectionTimes[i] >= timeChanges[bpmIdx].t)
				{
					currentBpm = timeChanges[bpmIdx].bpm;
					bpmIdx++;
				}

				var sec:SwagSection = {
					sectionNotes: [],
					sectionBeats: sectionBeatsArr[i],
					mustHitSection: sectionMustHits[i],
					gfSection: false,
					altAnim: false
				};

				if(currentBpm != lastBpm || (i == 0))
				{
					sec.changeBPM = true;
					sec.bpm = currentBpm;
					lastBpm = currentBpm;
				}

				sections.push(sec);
			}

			// Assign notes to sections
			var noteIndex:Int = 0;
			for (i in 0...sections.length)
			{
				var secEndTime:Float = (i + 1 < sectionTimes.length) ? sectionTimes[i + 1] : Math.POSITIVE_INFINITY;
				
				while(noteIndex < notes.length && notes[noteIndex].t < secEndTime)
				{
					var vsNote = notes[noteIndex];
					
					// Convert note data for mustHitSection
					var noteData:Int = vsNote.d;
					var mustHit:Bool = sections[i].mustHitSection;
					
					// In V-Slice: 0-3 = left side, 4-7 = right side
					// In Psych: 0-3 = player, 4-7 = opponent
					// If mustHit: left side (0-3) is player, right side (4-7) is opponent
					// If !mustHit: left side is opponent, right side is player
					var psychNoteData:Int = vsNote.d % 4;
					var isLeftSide:Bool = (vsNote.d < 4);
					
					if(sections[i].mustHitSection)
					{
						// Player section: left = player(0-3), right = opponent(4-7)
						psychNoteData = isLeftSide ? psychNoteData : psychNoteData + 4;
					}
					else
					{
						// Opponent section: left = opponent(4-7), right = player(0-3)
						psychNoteData = isLeftSide ? psychNoteData + 4 : psychNoteData;
					}

					var psychNote:Array<Dynamic> = [vsNote.t, psychNoteData, vsNote.l != null ? vsNote.l : 0];
					if(vsNote.k != null && vsNote.k.length > 0 && vsNote.k != 'normal')
						psychNote.push(vsNote.k);

					sections[i].sectionNotes.push(psychNote);
					noteIndex++;
				}
			}

			var swagSong:SwagSong = {
				song: metadata.songName,
				notes: sections,
				events: [],
				bpm: songBpm,
				needsVoices: true,
				speed: scrollSpeed,
				offset: 0,
				player1: metadata.playData.characters.player,
				player2: metadata.playData.characters.opponent,
				gfVersion: metadata.playData.characters.girlfriend,
				stage: stage,
				format: 'psych_v1_convert',
				validScore: false
			};

			songDifficulties.set(diff, swagSong);
		}

		// Handle events
		var eventsSong:Song.SwagSong = null;
		if(chart.events != null && chart.events.length > 0)
		{
			var psychEvents:Array<Dynamic> = [];
			
			for (event in chart.events)
			{
				if(event.e == 'FocusCamera') continue; // Skip camera events

				var eventData:Array<Array<String>> = [[event.e, '', '']];
				
				// Convert event values
				if(event.v != null)
				{
					if(Std.isOfType(event.v, String))
					{
						eventData[0][1] = event.v;
					}
					else if(Std.isOfType(event.v, Array))
					{
						var arr:Array<Dynamic> = cast event.v;
						if(arr.length > 0) eventData[0][1] = Std.string(arr[0]);
						if(arr.length > 1) eventData[0][2] = Std.string(arr[1]);
					}
					else
					{
						// Object type
						var fields:Array<String> = Reflect.fields(event.v);
						if(fields.length > 0) eventData[0][1] = Std.string(Reflect.field(event.v, fields[0]));
						if(fields.length > 1) eventData[0][2] = Std.string(Reflect.field(event.v, fields[1]));
					}
				}

				psychEvents.push([event.t, eventData]);
			}
			
			psychEvents.sort(function(a, b) return FlxSort.byValues(FlxSort.ASCENDING, a[0], b[0]));
			
			eventsSong = {
				song: metadata.songName,
				notes: [],
				events: psychEvents,
				bpm: songBpm,
				needsVoices: true,
				speed: 1.0,
				offset: 0,
				player1: metadata.playData.characters.player,
				player2: metadata.playData.characters.opponent,
				gfVersion: metadata.playData.characters.girlfriend,
				stage: stage,
				format: 'psych_v1_convert',
				validScore: false
			};
		}

		return {
			difficulties: songDifficulties,
			events: eventsSong
		};
	}

	/**
	 * Converts a Psych event value string to a proper typed value
	 */
	static function parseEventValue(val:String):Dynamic
	{
		if (val == null || val == '') return null;
		// Try to parse as number
		var num:Null<Float> = Std.parseFloat(val);
		if (num != null && !Math.isNaN(num))
		{
			if (num == Std.int(num)) return Std.int(num);
			return num;
		}
		var lower = val.toLowerCase();
		if (lower == 'true') return true;
		if (lower == 'false') return false;
		return val;
	}

	/**
	 * Converts Psych Engine chart to V-Slice format
	 * @param songData The Psych Engine chart data
	 * @param difficultyName Optional difficulty name override (default: uses current difficulty)
	 */
	public static function export(songData:SwagSong, ?difficultyName:String = null):VSlicePackage
	{
		// Determine current difficulty name
		if (difficultyName == null)
		{
			var diffIdx:Int = PlayState.storyDifficulty;
			if (diffIdx >= 0 && diffIdx < Difficulty.list.length)
				difficultyName = Difficulty.list[diffIdx];
			else
				difficultyName = Difficulty.getDefault();
		}
		var diffKey:String = Paths.formatToSongPath(difficultyName);

		// Process events - convert Psych events to V-Slice format
		var events:Array<VSliceEvent> = [];
		var focusCameraEvents:Array<VSliceEvent> = [];
		
		if(songData.events != null && songData.events.length > 0)
		{
			for (event in songData.events)
			{
				var eventTime:Float = event[0];
				var subEvents:Array<Array<Dynamic>> = cast event[1];
				if(subEvents != null && subEvents.length > 0)
				{
					for (lilEvent in subEvents)
					{
						var eventName:String = lilEvent[0];
						var val1:Dynamic = parseEventValue(lilEvent[1]);
						var val2:Dynamic = parseEventValue(lilEvent[2]);

						switch(eventName)
						{
							case 'Add Camera Zoom':
								var camZoom:Float = (val1 is Float) ? val1 : 0.015;
								var uiZoom:Float = (val2 is Float) ? val2 : 0.03;
								events.push({
									t: eventTime,
									e: 'ZoomCamera',
									v: {
										ease: 'INSTANT',
										zoom: 1 + camZoom + uiZoom,
										duration: 0,
										mode: 'direct'
									}
								});
							case 'Play Animation':
								var target:String = Std.string(val2).toLowerCase();
								var vsTarget:String = switch(target) {
									case 'bf': 'boyfriend';
									case 'dad': 'opponent';
									default: 'girlfriend';
								};
								events.push({
									t: eventTime,
									e: 'PlayAnimation',
									v: {
										target: vsTarget,
										anim: Std.string(val1),
										force: true
									}
								});
							case 'Camera Follow Pos':
								events.push({
									t: eventTime,
									e: 'FocusCamera',
									v: {
										char: -1,
										ease: 'INSTANT',
										x: val1 != null ? Std.parseFloat(val1) : 0,
										y: val2 != null ? Std.parseFloat(val2) : 0
									}
								});
							case 'Change Scroll Speed':
								var multiplier:Float = (val1 is Float) ? val1 : 1.0;
								var duration:Float = (val2 is Float) ? val2 : 0;
								events.push({
									t: eventTime,
									e: 'ScrollSpeed',
									v: {
										ease: duration > 0 ? 'linear' : 'INSTANT',
										scroll: multiplier,
										duration: duration > 0 ? duration * 4 : 0,
										absolute: false
									}
								});
							case 'Set Property':
								// Store as generic event
								events.push({
									t: eventTime,
									e: eventName,
									v: {value1: lilEvent[1], value2: lilEvent[2]}
								});
							default:
								// Generic event fallback
								events.push({
									t: eventTime,
									e: eventName,
									v: {value1: lilEvent[1], value2: lilEvent[2]}
								});
						}
					}
				}
			}
		}

		// Process notes and time changes from sections
		var notes:Array<VSliceNote> = [];
		var timeChanges:Array<VSliceTimeChange> = [];
		
		var time:Float = 0;
		var bpm:Float = songData.bpm;
		timeChanges.push({t: 0, bpm: bpm});
		
		var lastMustHit:Bool = false;
		var firstSection:Bool = true;

		if(songData.notes != null)
		{
			for (section in songData.notes)
			{
				// Add FocusCamera events for mustHit changes
				if(firstSection || lastMustHit != section.mustHitSection)
				{
					focusCameraEvents.push({
						t: time,
						e: 'FocusCamera',
						v: {char: section.mustHitSection ? 0 : 1}
					});
					lastMustHit = section.mustHitSection;
					firstSection = false;
				}

				// Add notes
				if(section.sectionNotes != null)
				{
					for (note in section.sectionNotes)
					{
						var noteTime:Float = note[0];
						var noteData:Int = Std.int(note[1]);
						var susLength:Float = note[2] > 0 ? note[2] : 0;
						var noteType:String = (note.length > 3 && note[3] != null) ? Std.string(note[3]) : null;

						// Convert Psych note data to V-Slice note data
						// In Psych: 0-3 = left/player side, 4-7 = right/opponent side
						// But mustHitSection determines which side is player vs opponent
						// In V-Slice: 0-3 = left, 4-7 = right (independent of mustHit)
						var vsNoteData:Int;
						if (section.mustHitSection)
						{
							// Player section: 0-3 = player, 4-7 = opponent
							vsNoteData = noteData;
						}
						else
						{
							// Opponent section: 0-3 = opponent, 4-7 = player
							vsNoteData = (noteData < 4) ? noteData + 4 : noteData - 4;
						}

						var vsliceNote:VSliceNote = {
							t: noteTime,
							d: vsNoteData
						};
						
						if(susLength > 0)
							vsliceNote.l = susLength;
						if(noteType != null && noteType.length > 0 && noteType != '')
							vsliceNote.k = noteType;
						
						notes.push(vsliceNote);
					}
				}

				// BPM changes
				if(section.changeBPM && section.bpm != null)
				{
					bpm = section.bpm;
					timeChanges.push({t: time, bpm: bpm});
				}

				// Calculate section time
				var beat:Float = section.sectionBeats != 0 ? section.sectionBeats : 4;
				time += Conductor.calculateCrochet(bpm) * beat;
			}
		}

		// Combine events - FocusCamera first for proper section detection, then other events
		var allEvents:Array<VSliceEvent> = focusCameraEvents.concat(events);

		// Sort all events by time
		allEvents.sort(sortByTime);
		notes.sort(sortByTime);

		// Build scrollSpeed and notes maps (only for the current difficulty)
		var scrollSpeed:Dynamic = {};
		var notesMap:Dynamic = {};
		
		Reflect.setField(scrollSpeed, diffKey, songData.speed);
		Reflect.setField(notesMap, diffKey, notes);

		// Stage name conversion
		var stage:String = songData.stage != null ? songData.stage : 'stage';
		stage = convertStageNamePsychToVSlice(stage);

		var generatedBy:String = 'Psych Engine v0.6.3 - Chart Editor V-Slice Exporter';

		return {
			chart: {
				scrollSpeed: scrollSpeed,
				events: allEvents,
				notes: notesMap,
				generatedBy: generatedBy,
				version: chartVersion
			},
			metadata: {
				songName: songData.song,
				artist: Reflect.hasField(songData, 'artist') ? Reflect.field(songData, 'artist') : 'Unknown',
				charter: Reflect.hasField(songData, 'charter') ? Reflect.field(songData, 'charter') : 'Unknown',
				playData: {
					difficulties: [difficultyName],
					characters: {
						player: songData.player1 != null ? songData.player1 : 'bf',
						girlfriend: songData.gfVersion != null ? songData.gfVersion : 'gf',
						opponent: songData.player2 != null ? songData.player2 : 'dad'
					},
					noteStyle: !PlayState.isPixelStage ? 'funkin' : 'pixel',
					stage: stage
				},
				timeFormat: 'ms',
				timeChanges: timeChanges,
				generatedBy: generatedBy,
				version: metadataVersion
			}
		};
	}

	/**
	 * Converts V-Slice stage name to Psych stage name
	 */
	static function convertStageName(vsliceStage:String):String
	{
		return switch(vsliceStage)
		{
			case 'mainStage': 'stage';
			case 'spookyMansion': 'spooky';
			case 'phillyTrain': 'philly';
			case 'limoRide': 'limo';
			case 'mallXmas': 'mall';
			case 'schoolStage': 'school';
			case 'schoolEvilStage': 'schoolEvil';
			case 'tankmanBattlefield': 'tank';
			default: vsliceStage;
		}
	}

	/**
	 * Converts Psych stage name to V-Slice stage name
	 */
	static function convertStageNamePsychToVSlice(psychStage:String):String
	{
		return switch(psychStage)
		{
			case 'stage': 'mainStage';
			case 'spooky': 'spookyMansion';
			case 'philly': 'phillyTrain';
			case 'limo': 'limoRide';
			case 'mall': 'mallXmas';
			case 'school': 'schoolStage';
			case 'schoolEvil': 'schoolEvilStage';
			case 'tank': 'tankmanBattlefield';
			default: psychStage;
		}
	}

	/**
	 * Creates an empty SwagSection
	 */
	static function emptySection():SwagSection
	{
		return {
			sectionNotes: [],
			sectionBeats: 4.0,
			mustHitSection: true,
			gfSection: false,
			altAnim: false
		};
	}

	/**
	 * Sort by time for V-Slice objects
	 */
	public static function sortByTime(obj1:Dynamic, obj2:Dynamic):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, obj1.t, obj2.t);
	}
}