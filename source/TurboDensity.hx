import haxe.Json;
import Note.PreloadedChartNote;

/**
 * Turbo 模式的高密度谱面分析结果。
 * 每个 zone 是 unspawnNotes 中一段连续的、不含长条的极高密度 tap 区间。
 * 区间内的原始 Note 不物化为 Sprite，改由数据级批量路径结算；
 * 视觉层使用密度分箱驱动的箭头流带。
 */
typedef TurboDensityZone = {
	var startIndex:Int;
	var endIndex:Int;
	var startTime:Float;
	var endTime:Float;
}

/** 真实谱面按轨抽出的视觉样本: 只保留真实存在的 lane/side。 */
typedef TurboSampleRef = {
	var time:Float;
	var lane:Int;
	var must:Bool;
}

/** 每 lane/side 的 10ms 密度分箱，供视觉流带预计算/增量维护。 */
typedef TurboDensityData = {
	var laneCount:Int;
	var binMs:Int;
	var binCount:Int;
	var counts:Array<Int>;
}

class TurboDensity
{
	public static inline final CACHE_VERSION:Int = 4;

	/**
	 * 100ms 分箱 + 滑窗聚合。
	 * aggregateNPS = 判定为“高密度聚合区”的每秒 Note 数阈值。
	 */
	public static function buildZones(unspawnNotes:Array<PreloadedChartNote>, aggregateNPS:Float = 4000, binMs:Int = 100, minZoneMs:Float = 500):Array<TurboDensityZone>
	{
		if (unspawnNotes == null || unspawnNotes.length == 0)
			return [];

		var lastTime:Float = unspawnNotes[unspawnNotes.length - 1].strumTime;
		if (lastTime < 0) lastTime = 0;
		var binCount:Int = Std.int(lastTime / binMs) + 2;
		var bins:Array<Int> = [for (i in 0...binCount) 0];
		var holdBins:Array<Bool> = [for (i in 0...binCount) false];

		for (pn in unspawnNotes)
		{
			var b:Int = Std.int(pn.strumTime / binMs);
			if (b < 0) b = 0;
			if (b >= binCount) b = binCount - 1;
			bins[b]++;
			if (pn.isSustainNote || pn.sustainLength > 0)
				holdBins[b] = true;
		}

		var thresholdPerBin:Int = Math.ceil(aggregateNPS * binMs / 1000.0);
		var agg:Array<Bool> = [for (i in 0...binCount) false];
		for (i in 0...binCount)
			agg[i] = (!holdBins[i] && bins[i] >= thresholdPerBin);

		var zones:Array<TurboDensityZone> = [];
		var i:Int = 0;
		while (i < binCount)
		{
			if (!agg[i]) { i++; continue; }
			var start:Int = i;
			while (i + 1 < binCount && agg[i + 1]) i++;
			var end:Int = i;
			var zStartTime:Float = start * binMs;
			var zEndTime:Float = (end + 1) * binMs;
			var startIndex:Int = lowerBound(unspawnNotes, zStartTime);
			var endIndex:Int = lowerBound(unspawnNotes, zEndTime);
			if (endIndex > startIndex && (zEndTime - zStartTime) >= minZoneMs)
				zones.push({
					startIndex: startIndex,
					endIndex: endIndex,
					startTime: zStartTime,
					endTime: zEndTime
				});
			i++;
		}
		return zones;
	}

	static function lowerBound(arr:Array<PreloadedChartNote>, time:Float):Int
	{
		var lo:Int = 0;
		var hi:Int = arr.length;
		while (lo < hi)
		{
			var mid:Int = (lo + hi) >>> 1;
			if (arr[mid].strumTime < time)
				lo = mid + 1;
			else
				hi = mid;
		}
		return lo;
	}

	/**
	 * 从真实谱面抽取“每轨每 intervalMs 一个”的视觉样本。
	 * 只抽实际存在的 Note, 因此空轨/单边谱面不会出现假满屏。
	 */
	public static function buildLaneSamples(unspawnNotes:Array<PreloadedChartNote>, intervalMs:Float = 40):Array<TurboSampleRef>
	{
		var out:Array<TurboSampleRef> = [];
		if (unspawnNotes == null || unspawnNotes.length == 0)
			return out;

		var lastByLane:Map<String, Float> = new Map();
		for (pn in unspawnNotes)
		{
			if (pn.isSustainNote || pn.sustainLength > 0)
				continue;
			var key:String = (pn.mustPress ? 'P' : 'O') + ':' + Std.string(pn.noteData);
			var lastTime:Null<Float> = lastByLane.get(key);
			if (lastTime == null || (pn.strumTime - lastTime) >= intervalMs)
			{
				out.push({
					time: pn.strumTime,
					lane: pn.noteData,
					must: pn.mustPress
				});
				lastByLane.set(key, pn.strumTime);
			}
		}
		return out;
	}

	/**
	 * H-Slice 风格鬼 Note 合并：同一 lane/side、同一 noteType、时间差 <= rangeMs 的
	 * 重复/重叠 tap 被折叠为一条，并把数量累加到 noteDensity。
	 * 只用于 Turbo 模式，关闭时保持原版谱面数据不变。
	 */
	public static function collapseGhostNotes(notes:Array<PreloadedChartNote>, laneCount:Int, rangeMs:Float = 1.0):Array<PreloadedChartNote>
	{
		if (notes == null || notes.length == 0)
			return notes != null ? notes : [];

		var out:Array<PreloadedChartNote> = [];
		var last:Array<PreloadedChartNote> = [for (i in 0...(laneCount * 2)) null];

		for (pn in notes)
		{
			// 长条/尾段不参与鬼 Note 合并，保留原语义。
			if (pn.isSustainNote || pn.sustainLength > 0)
			{
				out.push(pn);
				continue;
			}

			var lane:Int = Std.int(Math.abs(pn.noteData));
			if (lane < 0 || lane >= laneCount)
				lane = lane % laneCount;
			var side:Int = pn.mustPress ? 1 : 0;
			var idx:Int = side * laneCount + lane;

			var prev:PreloadedChartNote = last[idx];
			if (prev != null
				&& prev.noteType == pn.noteType
				&& prev.mustPress == pn.mustPress
				&& Math.abs(pn.strumTime - prev.strumTime) <= rangeMs)
			{
				prev.noteDensity += 1;
				continue;
			}

			out.push(pn);
			last[idx] = pn;
		}
		return out;
	}

	/**
	 * 预计算每 lane/side 的 10ms 密度分箱。
	 * 只统计 tap（与聚合区口径一致），sustain/hold 不参与视觉密度。
	 */
	public static function buildDensityBins(unspawnNotes:Array<PreloadedChartNote>, laneCount:Int, binMs:Int = 10):TurboDensityData
	{
		if (unspawnNotes == null || unspawnNotes.length == 0)
		{
			return {
				laneCount: laneCount,
				binMs: binMs,
				binCount: 0,
				counts: []
			};
		}

		var lastTime:Float = unspawnNotes[unspawnNotes.length - 1].strumTime;
		if (lastTime < 0) lastTime = 0;
		var binCount:Int = Std.int(lastTime / binMs) + 2;
		var sideCount:Int = 2;
		var total:Int = binCount * laneCount * sideCount;
		var counts:Array<Int> = [for (i in 0...total) 0];

		for (pn in unspawnNotes)
		{
			if (pn.isSustainNote || pn.sustainLength > 0)
				continue;
			var lane:Int = Std.int(Math.abs(pn.noteData));
			if (lane < 0 || lane >= laneCount)
				lane = lane % laneCount;
			var side:Int = pn.mustPress ? 1 : 0;
			var b:Int = Std.int(pn.strumTime / binMs);
			if (b < 0) b = 0;
			if (b >= binCount) b = binCount - 1;
			counts[(b * sideCount + side) * laneCount + lane]++;
		}

		return {
			laneCount: laneCount,
			binMs: binMs,
			binCount: binCount,
			counts: counts
		};
	}

	/** 查询某 [startTime, endTime) 窗内、某 side/lane 的 tap 数量。O(窗口内 bin 数)。 */
	public static function densityCount(data:TurboDensityData, startTime:Float, endTime:Float, side:Int, lane:Int):Int
	{
		if (data == null || data.counts == null || data.counts.length == 0)
			return 0;
		if (endTime <= startTime)
			return 0;
		var laneCount:Int = data.laneCount;
		if (laneCount <= 0)
			return 0;
		if (side < 0 || side > 1)
			side = 0;
		if (lane < 0 || lane >= laneCount)
			lane = lane % laneCount;

		var b0:Int = Std.int(startTime / data.binMs);
		var b1:Int = Std.int(endTime / data.binMs);
		if (b0 < 0) b0 = 0;
		if (b1 < 0) b1 = 0;
		if (b1 > data.binCount) b1 = data.binCount;
		if (b0 > data.binCount) b0 = data.binCount;
		if (b1 <= b0)
			return 0;

		var sum:Int = 0;
		var stride:Int = laneCount * 2;
		var baseLane:Int = (side * laneCount + lane);
		var total:Int = data.counts.length;
		for (b in b0...b1)
		{
			var idx:Int = b * stride + baseLane;
			if (idx >= total)
				break;
			sum += data.counts[idx];
		}
		return sum;
	}

	#if sys
	public static function saveCache(path:String, zones:Array<TurboDensityZone>, density:TurboDensityData, meta:Dynamic):Void
	{
		try
		{
			var dir:String = haxe.io.Path.directory(path);
			if (dir != null && dir.length > 0 && !sys.FileSystem.exists(dir))
				sys.FileSystem.createDirectory(dir);

			var buf:haxe.io.BytesBuffer = new haxe.io.BytesBuffer();
			buf.addString('TURB');
			buf.addInt32(CACHE_VERSION);
			var metaStr:String = Json.stringify(meta);
			var metaBytes:haxe.io.Bytes = haxe.io.Bytes.ofString(metaStr);
			buf.addInt32(metaBytes.length);
			buf.add(metaBytes);

			buf.addInt32(zones == null ? 0 : zones.length);
			if (zones != null)
				for (z in zones)
				{
					buf.addInt32(z.startIndex);
					buf.addInt32(z.endIndex);
					buf.addDouble(z.startTime);
					buf.addDouble(z.endTime);
				}

			var laneCount:Int = density != null ? density.laneCount : 0;
			var binMs:Int = density != null ? density.binMs : 0;
			var binCount:Int = density != null ? density.binCount : 0;
			buf.addInt32(laneCount);
			buf.addInt32(binMs);
			buf.addInt32(binCount);
			if (density != null && density.counts != null)
			{
				buf.addInt32(density.counts.length);
				for (c in density.counts)
					buf.addInt32(c);
			}
			else
				buf.addInt32(0);

			sys.io.File.saveBytes(path, buf.getBytes());
		}
		catch (e:Dynamic)
		{
			// 缓存失败不影响游戏运行
		}
	}

	public static function loadCache(path:String, expectedMeta:Dynamic):Null<{
		zones:Array<TurboDensityZone>,
		density:TurboDensityData
	}>
	{
		if (!sys.FileSystem.exists(path))
			return null;
		try
		{
			var bytes:haxe.io.Bytes = sys.io.File.getBytes(path);
			if (bytes == null || bytes.length < 8)
				return null;
			var pos:Int = 0;
			if (bytes.getString(pos, 4) != 'TURB')
				return null;
			pos += 4;
			var version:Int = bytes.getInt32(pos);
			pos += 4;
			if (version != CACHE_VERSION)
				return null;

			var metaLen:Int = bytes.getInt32(pos);
			pos += 4;
			var metaStr:String = bytes.getString(pos, metaLen);
			pos += metaLen;
			var parsedMeta:Dynamic = Json.parse(metaStr);
			if (!cacheMetaMatches(parsedMeta, expectedMeta))
				return null;

			var zones:Array<TurboDensityZone> = [];
			var zoneCount:Int = bytes.getInt32(pos);
			pos += 4;
			for (i in 0...zoneCount)
			{
				zones.push({
					startIndex: bytes.getInt32(pos),
					endIndex: bytes.getInt32(pos + 4),
					startTime: bytes.getDouble(pos + 8),
					endTime: bytes.getDouble(pos + 16)
				});
				pos += 24;
			}

			var laneCount:Int = bytes.getInt32(pos);
			pos += 4;
			var binMs:Int = bytes.getInt32(pos);
			pos += 4;
			var binCount:Int = bytes.getInt32(pos);
			pos += 4;
			var countLen:Int = bytes.getInt32(pos);
			pos += 4;
			var counts:Array<Int> = [for (i in 0...countLen) 0];
			for (i in 0...countLen)
			{
				counts[i] = bytes.getInt32(pos);
				pos += 4;
			}
			var density:TurboDensityData = {
				laneCount: laneCount,
				binMs: binMs,
				binCount: binCount,
				counts: counts
			};

			return { zones: zones, density: density };
		}
		catch (e:Dynamic)
		{
			return null;
		}
	}

	static function cacheMetaMatches(a:Dynamic, b:Dynamic):Bool
	{
		if (a == null || b == null) return false;
		return a.song == b.song
			&& a.mod == b.mod
			&& a.notes == b.notes
			&& a.lastTime == b.lastTime;
	}
	#end
}
