package backend;

import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import mohong.TraceManager;


typedef GfxLruLedgerDelta =
{
	var parked:Int;
	var bytes:Float;
	var hits:Int;
	var saved:Float;
}


typedef GfxLruEntry =
{
	var key:String;        
	var normKey:String;    
	var graphic:FlxGraphic;
	var bytes:Float;
	var hits:Int;
	var lastUse:Int;
	var pinned:Bool;
}


class GfxLru
{
	public static var enabled:Bool = true;

	public static var budgetBytes:Float = 1536 * 1048576;

	public static inline var HOT_HITS:Int = 2;

	public static var parkedTotal:Int = 0;
	public static var parkedBytesTotal:Float = 0;
	public static var hitTotal:Int = 0;
	public static var savedMsTotal:Float = 0;
	public static var evictTotal:Int = 0;

	static var entries:Map<String, GfxLruEntry> = [];
	static var totalBytes:Float = 0;
	static var tick:Int = 0;
	static var wasEnabled:Bool = true;

	static var wm:GfxLruLedgerDelta = {parked: 0, bytes: 0.0, hits: 0, saved: 0.0};

	public static function isEnabled():Bool
	{
		return enabled && ClientPrefs.data.gfxLruCache;
	}


	public static function park(g:FlxGraphic, ?fileKey:String, allowSmall:Bool = false):Bool
	{
		checkEnabledFlush();
		if (!isEnabled()) return false;
		if (g == null || g.key == null) return false;

		var key:String = fileKey != null && fileKey.length > 0 ? fileKey : g.key;
		if (key == null || key.length == 0) return false;

		var bmp = g.bitmap;
		if (bmp == null) return false;

		if (!allowSmall && bmp.width < GfxPolicy.minDimension && bmp.height < GfxPolicy.minDimension)
			return false;

		if (bmp.readable)
		{
			if (!GfxPolicy.tryRelease(key, g)) return false;
		}
		else if (!GfxPolicy.hasLiveTexture(bmp))
		{
			return false;
		}

		var bytes:Float = bmp.width * bmp.height * 4;
		if (bytes > budgetBytes) return false;

		var norm:String = normalizeKey(key);
		var existing = entries.get(norm);
		var prevHits:Int = 0;
		var prevPin:Bool = false;
		if (existing != null)
		{
			if (existing.graphic == g)
			{
				tick++;
				existing.lastUse = tick;
				return true;
			}
			prevHits = existing.hits;
			prevPin = existing.pinned;
			evictEntry(existing, 'replace'); 
		}

		tick++;
		var e:GfxLruEntry = {
			key: key,
			normKey: norm,
			graphic: g,
			bytes: bytes,
			hits: prevHits,
			lastUse: tick,
			pinned: prevPin
		};
		entries.set(norm, e);
		totalBytes += bytes;
		parkedTotal++;
		parkedBytesTotal += bytes;
		TraceManager.info('trace.gfx.lruPark',
			'GfxLru parked {}: ~{} MB', [key, mb(bytes)]);

		enforceBudget();
		return true;
	}

	public static function lookup(requestedKey:String):Null<FlxGraphic>
	{
		if (requestedKey == null || requestedKey.length == 0) return null;
		checkEnabledFlush();
		if (!isEnabled()) return null;

		var e = entries.get(normalizeKey(requestedKey));
		if (e == null) return null;
		if (!entryUsable(e))
		{
			evictEntry(e, 'dead');
			return null;
		}

		touch(e);
		hitTotal++;
		savedMsTotal += estimateSavedMs();

		revive(e.graphic, requestedKey);
		TraceManager.info('trace.gfx.lruHit',
			'GfxLru hit #{}: {} (~{} MB vram, zero decode)', [hitTotal, requestedKey, mb(e.bytes)]);
		return e.graphic;
	}

	public static function has(requestedKey:String):Bool
	{
		if (requestedKey == null || requestedKey.length == 0) return false;
		if (!isEnabled()) return false;
		var e = entries.get(normalizeKey(requestedKey));
		return e != null && entryUsable(e);
	}

	public static function pin(requestedKey:String):Void
	{
		var e = entries.get(normalizeKey(requestedKey != null ? requestedKey : ''));
		if (e != null) e.pinned = true;
	}

	public static function unpin(requestedKey:String):Void
	{
		var e = entries.get(normalizeKey(requestedKey != null ? requestedKey : ''));
		if (e != null) e.pinned = false;
	}

	public static function isParked(requestedKey:String):Bool
	{
		return requestedKey != null && entries.exists(normalizeKey(requestedKey));
	}

	public static function takeLedgerDelta():GfxLruLedgerDelta
	{
		var d:GfxLruLedgerDelta = {
			parked: parkedTotal - wm.parked,
			bytes: parkedBytesTotal - wm.bytes,
			hits: hitTotal - wm.hits,
			saved: savedMsTotal - wm.saved
		};
		wm.parked = parkedTotal;
		wm.bytes = parkedBytesTotal;
		wm.hits = hitTotal;
		wm.saved = savedMsTotal;
		return d;
	}

	public static function liveEntries():Int return Lambda.count(entries);
	public static function liveBytes():Float return totalBytes;
	public static function liveHotCount():Int
	{
		var n:Int = 0;
		for (e in entries) if (e.hits >= HOT_HITS) n++;
		return n;
	}
	public static function livePinnedCount():Int
	{
		var n:Int = 0;
		for (e in entries) if (e.pinned) n++;
		return n;
	}
	public static function budgetMb():Float return budgetBytes / 1048576;

	public static function estimateSavedMs():Float
	{
		if (AsyncGfxLoader.decodedOffThreadTotal > 0)
			return AsyncGfxLoader.decodeMsTotal / AsyncGfxLoader.decodedOffThreadTotal;
		return 300;
	}

	public static function onContextRestored():Void
	{
		if (Lambda.count(entries) == 0) return;
		var dead:Array<GfxLruEntry> = [];
		for (e in entries)
			if (!entryUsable(e)) dead.push(e);
		for (e in dead)
			evictEntry(e, 'context');
		if (dead.length > 0)
			TraceManager.warn('trace.gfx.lruContext',
				'GfxLru context-restored: evicted {} unusable parked graphics', [dead.length]);
	}

	public static function flushAll(reason:String):Void
	{
		var all:Array<GfxLruEntry> = [];
		for (e in entries) all.push(e);
		for (e in all) evictEntry(e, reason);
	}

	static function checkEnabledFlush():Void
	{
		var now = isEnabled();
		if (wasEnabled && !now && Lambda.count(entries) > 0)
			flushAll('setting-off');
		wasEnabled = now;
	}
	static function entryUsable(e:GfxLruEntry):Bool
	{
		var g = e.graphic;
		if (g == null || g.bitmap == null) return false;
		@:privateAccess
		if (g.frameCollections == null) return false; // 已被外部 destroy
		return g.bitmap.readable || GfxPolicy.hasLiveTexture(g.bitmap);
	}

	static inline function touch(e:GfxLruEntry):Void
	{
		tick++;
		e.lastUse = tick;
		e.hits++;
	}

	
	static function revive(g:FlxGraphic, requestedKey:String):Void
	{
		Paths.currentTrackedAssets.set(requestedKey, g);
		@:privateAccess
		{
			var existing = FlxG.bitmap._cache.get(requestedKey);
			if (existing == null || existing == g)
				FlxG.bitmap._cache.set(requestedKey, g);
		}
		Paths.trackLocalAsset(requestedKey);
	}

	static function enforceBudget():Void
	{
		var guard:Int = 0;
		while (totalBytes > budgetBytes && guard++ < 1024)
		{
			var v = pickVictim(false); 
			if (v == null) v = pickVictim(true); 
			if (v == null) break;
			evictEntry(v, 'budget');
		}
	}

	static function pickVictim(includeHot:Bool):GfxLruEntry
	{
		var best:GfxLruEntry = null;
		for (e in entries)
		{
			if (e.pinned) continue;
			if (!includeHot && e.hits >= HOT_HITS) continue;
			if (Paths.currentTrackedAssets.exists(e.key)) continue;
			if (best == null || e.lastUse < best.lastUse) best = e;
		}
		return best;
	}

	static function evictEntry(e:GfxLruEntry, reason:String):Void
	{
		if (e == null) return;
		entries.remove(e.normKey);
		totalBytes -= e.bytes;
		if (totalBytes < 0) totalBytes = 0;
		evictTotal++;
		if (e.key != null) backend.GfxRepack.forgetPair(e.key);
		if (e.graphic != null)
			e.graphic.destroy();
	}

	static function normalizeKey(key:String):String
	{
		var ci = key.indexOf(':');
		if (ci <= 0) return key;
		var prefix = key.substr(0, ci);
		var rest = key.substr(ci + 1);
		if (rest.startsWith('assets/')
			&& prefix.indexOf('/') < 0
			&& prefix.indexOf('\\') < 0
			&& prefix.indexOf(':') < 0)
			return rest;
		return key;
	}

	static inline function mb(v:Float):String
	{
		return Std.string(Math.round(v / 1048576 * 10) / 10);
	}
}
