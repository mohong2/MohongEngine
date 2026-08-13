package mohong;

import flixel.FlxG;
import flixel.util.FlxTimer;
import states.PlayState;
import states.FreeplayState;
import states.TitleState;
import backend.MusicBeatState;

#if sys
import sys.FileSystem;
#end

/**
 * Unattended perf runner. CLI: --perf-test song|menu [N] [noseek].
 * sys platforms only; no-op without the flag. Botplays the first chart
 * found under mods, retries it, dumps CSV + summary, then exits.
 */
class PerfTest
{
	public static var enabled:Bool = false;
	public static var mode:String = 'song';
	public static var maxRetries:Int = 20;
	public static var retriesDone:Int = 0;
	public static var roundTrips:Int = 0;
	/** noseek: full play; seeking makes the spawn catch-up destroy overdue notes. */
	public static var noSeek:Bool = false;

	static var startTime:Float = 0;
	static var snapshots:Array<String> = [];
	static var seekDone:Bool = false;
	static var finishing:Bool = false;

	public static function init():Void
	{
		#if sys
		var args:Array<String> = Sys.args();
		var idx:Int = args.indexOf('--perf-test');
		if (idx < 0) return;
		enabled = true;
		if (idx + 1 < args.length)
			mode = args[idx + 1];
		// optional 3rd arg = retry count (default 20)
		if (idx + 2 < args.length)
		{
			var n:Null<Int> = Std.parseInt(args[idx + 2]);
			if (n != null && n > 0) maxRetries = n;
		}
		if (args.indexOf('noseek') >= 0) noSeek = true;
		#else
		return;
		#end

		MemoryMonitor.monitoringEnabled = true;
		MemoryMonitor.frameTimeTrackingEnabled = true;
		RenderOptimizer.optimizationEnabled = true;
		ClientPrefs.data.gameplaySettings.set('botplay', true);
		ClientPrefs.data.autoPause = false;
		// unattended: hide the debug-build debugger UI
		// (stray clicks on its button crashed runs)
		FlxG.debugger.visible = false;

		startTime = haxe.Timer.stamp();
		FlxG.signals.postStateSwitch.add(onPostStateSwitch);

		TraceManager.info('perfTest.init', 'PerfTest armed: mode={} retries={}', [mode, maxRetries]);

		new FlxTimer().start(0.8, function(_)
		{
			if (mode == 'menu')
				MusicBeatState.switchState(new FreeplayState());
			else
				startSong();
		});
	}

	static function onPostStateSwitch():Void
	{
		if (!enabled || mode != 'menu')
			return;

		roundTrips++;
		snapshot('menu #' + roundTrips);
		if (roundTrips >= maxRetries)
		{
			finish();
			return;
		}

		var isTitle:Bool = (FlxG.state != null && Std.isOfType(FlxG.state, TitleState));
		new FlxTimer().start(0.4, function(_)
		{
			if (isTitle)
				MusicBeatState.switchState(new FreeplayState());
			else
				MusicBeatState.switchState(new TitleState());
		});
	}

	/**
	 * Find the first chart under mods and start it.
	 * (assets/data is empty; charts come from mods.)
	 */
	static function startSong():Void
	{
		var found:FoundChart = findFirstChart();
		if (found == null)
		{
			TraceManager.error('perfTest.noChart', 'No playable chart found under mods/<mod>/data - aborting.');
			finish();
			return;
		}

		Paths.currentModDirectory = found.mod;
		PlayState.SONG = Song.loadFromJson(found.chartFile, found.song);
		if (PlayState.SONG == null)
		{
			TraceManager.error('perfTest.loadFail', 'Failed to load chart {}/{}', [found.mod, found.song]);
			finish();
			return;
		}
		PlayState.isStoryMode = false;
		PlayState.storyDifficulty = found.diffIdx;
		PlayState.replayMode = false;
		TraceManager.info('perfTest.song', 'PerfTest song: {} (mod {}, diffIdx {})', [found.song, found.mod, found.diffIdx]);
		LoadingState.loadAndSwitchState(new PlayState());
		seekDone = false;
		startSeekWatcher();
	}

	/**
	 * Seek to the last 8s so each retry is ~15s.
	 * Driven by stage ENTER_FRAME (same hook as MemoryMonitor),
	 * so state switches cannot stop it. Seeks once after the countdown.
	 */
	static var seekWatcher:openfl.events.Event->Void = null;
	static var seekWatcherAccum:Float = 0;

	static function startSeekWatcher():Void
	{
		if (!enabled || mode != 'song')
			return;

		if (seekWatcher == null)
		{
			seekWatcher = function(_:openfl.events.Event)
			{
				if (finishing)
					return;

				seekWatcherAccum += FlxG.elapsed;
				if (seekWatcherAccum < 0.5)
					return;
				seekWatcherAccum = 0;

				var ps:PlayState = PlayState.instance;
				var canSeek:Bool = false;
				@:privateAccess canSeek = (ps != null && ps.startedCountdown && ps.generatedMusic);
				#if sys
				if (!seekDone)
				{
					try {
						if (!FileSystem.exists('perf')) FileSystem.createDirectory('perf');
						var fo:sys.io.FileOutput = sys.io.File.append('perf/progress.txt', false);
						fo.writeString('[seek] tick ps=' + (ps != null) + ' canSeek=' + canSeek + ' len=' + (ps != null ? Math.round(ps.songLength) : -1) + ' pos=' + Math.round(Conductor.songPosition) + '\n');
						fo.close();
					} catch (e:Dynamic) {}
				}
				#end
				if (!seekDone && canSeek && !noSeek)
				{
					// songLength can be 0 (streamed music length unknown at startSong)
					// fall back: music.length, then last note time
					var len:Float = ps.songLength;
					if (len <= 10000 && FlxG.sound.music != null)
						len = FlxG.sound.music.length;
					if (len <= 10000)
						len = ps.lastChartNoteTime + 4000;

					if (len > 10000)
					{
						var to:Float = len - 8000;
						try {
							if (FlxG.sound.music != null) FlxG.sound.music.time = to;
							if (ps.vocals != null) ps.vocals.time = to;
						} catch (e:Dynamic) {}
						Conductor.songPosition = to;
						TraceManager.info('perfTest.seek', 'Seeked to {}ms (songLength {}ms, chart {}ms)', [Math.round(to), Math.round(ps.songLength), Math.round(ps.lastChartNoteTime)]);
					}
					else
					{
						TraceManager.info('perfTest.seek', 'Cannot determine song length - playing full song');
					}
					seekDone = true;
				}
			};
			openfl.Lib.current.stage.addEventListener(openfl.events.Event.ENTER_FRAME, seekWatcher);
		}
		seekWatcherAccum = 0;
	}

	/**
	 * Called from PlayState.endSong: snapshot + retry.
	 */
	public static function onSongComplete():Void
	{
		if (!enabled || mode != 'song')
			return;

		retriesDone++;
		snapshot('songEnd #' + retriesDone);

		if (retriesDone >= maxRetries)
		{
			finish();
			return;
		}

		new FlxTimer().start(0.5, function(_)
		{
			seekDone = false;
			MusicBeatState.switchState(new PlayState());
			startSeekWatcher();
		});
	}

	static function snapshot(label:String):Void
	{
		var f:MemoryMonitor.FrameStats = MemoryMonitor.getFrameStats();
		var r:RenderOptimizer.RenderStats = RenderOptimizer.getStats();
		var line:String = '$label | mem=${Std.int(MemoryMonitor.currentMemoryUsage / 1024 / 1024)}MB '
			+ 'peak=${Std.int(MemoryMonitor.peakMemoryUsage / 1024 / 1024)}MB '
			+ 'cached=${MemoryMonitor.cachedGraphicCount} living=${MemoryMonitor.livingGraphicCount} '
			+ 'frameMs p50=${Math.round(f.p50)} p95=${Math.round(f.p95)} p99=${Math.round(f.p99)} '
			+ 'renderMs p50=${Math.round(r.p50Ms)} p95=${Math.round(r.p95Ms)} '
			+ 'sprites=${r.visibleSprites} | ${Note.pool != null ? Note.pool.getDiagnostics() : 'pool=none'}';
		snapshots.push(line);
		TraceManager.info('perfTest.snapshot', '{}', [line]);
		#if sys
		// live progress file (no need to wait for finish)
		try {
			if (!FileSystem.exists('perf')) FileSystem.createDirectory('perf');
			var fo:sys.io.FileOutput = sys.io.File.append('perf/progress.txt', false);
			fo.writeString(line + '\n');
			fo.close();
		} catch (e:Dynamic) {}
		#end
	}

	static function finish():Void
	{
		finishing = true;
		var csv:String = MemoryMonitor.exportStats('perf/perftest_' + mode + '.csv');
		var summary:String = 'elapsed=' + Math.round(haxe.Timer.stamp() - startTime) + 's\n' + snapshots.join('\n');
		#if sys
		try {
			if (!FileSystem.exists('perf')) FileSystem.createDirectory('perf');
			sys.io.File.saveContent('perf/perftest_' + mode + '_summary.txt', summary + '\n\ncsv=' + (csv != null ? csv : 'null'));
		} catch (e:Dynamic) {}
		TraceManager.info('perfTest.done', 'PerfTest finished. csv={}', [csv]);
		new FlxTimer().start(0.3, function(_) { Sys.exit(0); });
		#else
		TraceManager.info('perfTest.done', 'PerfTest finished.');
		#end
	}

	#if sys
	static function findFirstChart():FoundChart
	{
		var modsDir:String = Paths.mods();
		if (!FileSystem.exists(modsDir) || !FileSystem.isDirectory(modsDir)) return null;

		var mods:Array<String> = FileSystem.readDirectory(modsDir);
		for (mod in mods)
		{
			if (mod == '.' || mod == '..') continue;
			var dataDir:String = modsDir + mod + '/data/';
			if (!FileSystem.exists(dataDir) || !FileSystem.isDirectory(dataDir)) continue;

			var songFolders:Array<String> = FileSystem.readDirectory(dataDir);
			for (sf in songFolders)
			{
				var sfDir:String = dataDir + sf + '/';
				if (!FileSystem.isDirectory(sfDir)) continue;

				var files:Array<String> = FileSystem.readDirectory(sfDir);
				for (f in files)
				{
					if (!f.endsWith('.json')) continue;
					var base:String = f.substr(0, f.length - 5); // strip .json

					// map <song>-<diff> back to a difficulty index
					var diffIdx:Int = 0;
					var dashIdx:Int = base.lastIndexOf('-');
					if (dashIdx > 0)
					{
						var diffName:String = base.substr(dashIdx + 1);
						for (i in 0...CoolUtil.difficulties.length)
						{
							if (CoolUtil.difficulties[i].toLowerCase() == diffName.toLowerCase())
							{
								diffIdx = i;
								break;
							}
						}
					}

					return {mod: mod, song: sf, chartFile: base, diffIdx: diffIdx};
				}
			}
		}
		return null;
	}
	#end
}

/** Found-chart result. */
typedef FoundChart = {
	mod:String,
	song:String,
	chartFile:String,
	diffIdx:Int
}
