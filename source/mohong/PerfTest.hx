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
 * 性能验收自动化驱动（mohong 重写版的一部分——测量基建）。
 *
 * 解决什么问题：
 *   切歌 20 次 / 菜单往返的长时内存曲线需要无人值守驱动，
 *   否则"内存只涨不跌"无法复现、无法回归。
 *
 * 挂在哪个真实调用点：
 *   - Main.setupGame → PerfTest.init()（命令行参数解析与启动）；
 *   - PlayState.endSong → PerfTest.onSongComplete()（歌曲完成重试钩子）。
 *
 * 怎么验证它真的在工作：
 *   以 `--perf-test song` 启动后，游戏自动开 botplay 反复重试同一首歌，
 *   完成后 perf/perftest_song.csv + 摘要文件出现，进程自动退出。
 *
 * 用法（仅 sys 平台命令行参数生效；其他平台/无参数完全不激活）：
 *   SeiunEngine.exe --perf-test song   # 同一首歌 botplay 20 次重试
 *   SeiunEngine.exe --perf-test menu   # Title ↔ Freeplay 往返 20 次
 */
class PerfTest
{
	public static var enabled:Bool = false;
	public static var mode:String = 'song';
	public static var maxRetries:Int = 20;
	public static var retriesDone:Int = 0;
	public static var roundTrips:Int = 0;

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
		// 可选：第三个参数指定次数（默认 20）——短验证跑 3 次即可
		if (idx + 2 < args.length)
		{
			var n:Null<Int> = Std.parseInt(args[idx + 2]);
			if (n != null && n > 0) maxRetries = n;
		}
		#else
		return;
		#end

		MemoryMonitor.monitoringEnabled = true;
		MemoryMonitor.frameTimeTrackingEnabled = true;
		RenderOptimizer.optimizationEnabled = true;
		ClientPrefs.data.gameplaySettings.set('botplay', true);
		ClientPrefs.data.autoPause = false;
		// 无人值守运行：关掉 debug 构建的 flixel 调试器 UI，
		// 防止误点系统按钮触发 Window.setVisible 崩溃。
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
	 * 从已安装 mod 中找第一张谱面并启动。
	 * （本机 assets/data 为空，可玩谱面全部来自 mods/<mod>/data。）
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
	 * 快进到歌曲最后 8 秒：每轮重试约 15 秒完成，20 次长测不必等完整歌曲。
	 * 倒计时结束后执行一次 seek（music/vocals.time + Conductor.songPosition）。
	 */
	static function startSeekWatcher():Void
	{
		if (!enabled || mode != 'song')
			return;

		new FlxTimer().start(0.5, function(tmr:FlxTimer)
		{
			if (finishing)
			{
				tmr.cancel();
				return;
			}

			var ps:PlayState = PlayState.instance;
			var canSeek:Bool = false;
			@:privateAccess canSeek = (ps != null && ps.startedCountdown && ps.generatedMusic);
			if (!seekDone && canSeek)
			{
				var len:Float = ps.songLength;
				if (len > 10000)
				{
					var to:Float = len - 8000;
					try {
						if (FlxG.sound.music != null) FlxG.sound.music.time = to;
						if (ps.vocals != null) ps.vocals.time = to;
					} catch (e:Dynamic) {}
					Conductor.songPosition = to;
					TraceManager.info('perfTest.seek', 'Seeked to {}ms (songLength {}ms)', [Math.round(to), Math.round(len)]);
				}
				seekDone = true;
				tmr.cancel();
			}
		}, 0); // 0 loops = 每 0.5s 重复，直到 cancel
	}

	/**
	 * 歌曲完成钩子（PlayState.endSong 调用）：记录快照并重试。
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
					var base:String = f.substr(0, f.length - 5); // 去掉 .json

					// 从 <song>-<diff> 反推难度索引；匹配不到就当默认难度
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

/** 谱面定位结果。 */
typedef FoundChart = {
	mod:String,
	song:String,
	chartFile:String,
	diffIdx:Int
}
