package backend;

import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import openfl.display.BitmapData;
import openfl.utils.Assets as OpenFlAssets;
import openfl.utils.AssetType;
import mohong.TraceManager;

#if sys
import sys.FileSystem;
import sys.io.File;
import sys.thread.Thread;
import sys.thread.Mutex;
#end


typedef GfxJob =
{
	cacheKey:String,   
	filePath:String,  
	enqueuedAt:Float   
}

typedef GfxWorkerResult =
{
	bmp:BitmapData,            
	packedXml:Null<String>,    
	filePath:String            
}

class AsyncGfxLoader
{
	public static inline var WORKERS:Int = 2;

	public static inline var ASYNC_TIMEOUT_MS:Float = 45000;

	public static var decodedOffThreadTotal:Int = 0;
	public static var failedOffThreadTotal:Int = 0;
	public static var decodeMsTotal:Float = 0;
	public static var lastBatchEnqueued:Int = 0;
	public static var lastBatchOffThread:Int = 0;
	public static var lastBatchCached:Int = 0;

	#if sys
	static var mutex:Mutex = new Mutex();
	static var queue:Array<GfxJob> = [];
	static var inflight:Map<String, Bool> = [];     
	static var ready:Map<String, BitmapData> = [];    
	static var callbacks:Map<String, Void->Void> = [];
	static var workersStarted:Bool = false;
	#end

	public static function available():Bool
	{
		#if sys
		return ClientPrefs.data.asyncImageLoading;
		#else
		return false;
		#end
	}

	#if sys
	public static function enqueue(cacheKey:String, filePath:String, onDone:Void->Void):Void
	{
		if (cacheKey == null || filePath == null)
			return;

		mutex.acquire();
		if (inflight.exists(cacheKey) || ready.exists(cacheKey))
		{
			if (onDone != null && !callbacks.exists(cacheKey))
				callbacks.set(cacheKey, onDone);
			mutex.release();
			return;
		}
		if (isCached(cacheKey))
		{
			mutex.release();
			lastBatchCached++;
			if (onDone != null) onDone();
			return;
		}

		queue.push({cacheKey: cacheKey, filePath: filePath, enqueuedAt: haxe.Timer.stamp()});
		inflight.set(cacheKey, true);
		callbacks.set(cacheKey, onDone);
		lastBatchEnqueued++;
		startWorkersOnce();
		mutex.release();
	}

	public static function drain():Void
	{
		var fired:Array<Void->Void> = [];

		mutex.acquire();

		var now = haxe.Timer.stamp();
		var keep:Array<GfxJob> = [];
		for (job in queue)
		{
			if ((now - job.enqueuedAt) * 1000 > ASYNC_TIMEOUT_MS)
			{
				inflight.remove(job.cacheKey);
				failedOffThreadTotal++;
				var cb = callbacks.get(job.cacheKey);
				callbacks.remove(job.cacheKey);
				if (cb != null) fired.push(cb);
				TraceManager.warn('trace.asyncGfx.timeout',
					'AsyncGfxLoader timeout for {}', [job.cacheKey]);
			}
			else keep.push(job);
		}
		queue = keep;

		var doneKeys:Array<String> = [];
		var doneRes:Array<GfxWorkerResult> = [];
		for (k => v in pendingResults)
		{
			doneKeys.push(k);
			doneRes.push(v);
		}
		pendingResults.clear();

		for (i in 0...doneKeys.length)
		{
			var key = doneKeys[i];
			var res = doneRes[i];
			var bmp = res != null ? res.bmp : null;

			if (res != null && res.packedXml != null && bmp != null)
				GfxRepack.registerPackedXml(key, res.packedXml, res.filePath, bmp.width, bmp.height);

			if (bmp != null && !isCached(key))
			{
				if (!materialize(key, bmp))
					ready.set(key, bmp); 
				decodedOffThreadTotal++;
				lastBatchOffThread++;
			}
			else if (bmp == null)
			{
				failedOffThreadTotal++;
			}
			inflight.remove(key);
			var cb = callbacks.get(key);
			callbacks.remove(key);
			if (cb != null) fired.push(cb);
		}

		mutex.release();

		for (cb in fired) cb();
	}

	public static function takeDecoded(cacheKey:String):Null<BitmapData>
	{
		#if sys
		mutex.acquire();
		var bmp = ready.get(cacheKey);
		if (bmp != null) ready.remove(cacheKey);
		mutex.release();
		return bmp;
		#else
		return null;
		#end
	}

	public static function beginBatch():Void
	{
		lastBatchEnqueued = 0;
		lastBatchOffThread = 0;
		lastBatchCached = 0;
	}


	public static function reset():Void
	{
		#if sys
		mutex.acquire();
		queue.resize(0);
		pendingResults.clear();
		inflight.clear();
		callbacks.clear();
		mutex.release();
		#end
	}

	static var pendingResults:Map<String, GfxWorkerResult> = [];

	static function startWorkersOnce():Void
	{
		if (workersStarted) return;
		workersStarted = true;
		for (i in 0...WORKERS)
		{
			Thread.create(function() {
				while (true)
				{
					var job:GfxJob = null;
					mutex.acquire();
					if (queue.length > 0)
						job = queue.shift();
					mutex.release();

					if (job == null)
					{
						Sys.sleep(0.004);
						continue;
					}

					var t0 = haxe.Timer.stamp();
					var bmp:BitmapData = null;
					try
					{
						bmp = BitmapData.fromBytes(File.getBytes(job.filePath));
					}
					catch (e:Dynamic)
					{
						TraceManager.warn('trace.asyncGfx.decodeFail',
							'AsyncGfxLoader decode failed for {}: {}', [job.filePath, e]);
						bmp = null;
					}
					decodeMsTotal += (haxe.Timer.stamp() - t0) * 1000;

					var packedXml:String = null;
					if (bmp != null)
					{
						var rep = GfxRepack.process(job.cacheKey, job.filePath, bmp);
						if (rep != null)
						{
							bmp = rep.bmp;
							packedXml = rep.xml;
							TraceManager.info('trace.gfx.repack',
								'GfxRepack {} : {} -> {} MB (-{}%) in {} ms',
								[job.cacheKey,
								 Std.string(Math.round(rep.oldBytes / 1048576 * 10) / 10),
								 Std.string(Math.round(rep.newBytes / 1048576 * 10) / 10),
								 Std.string(Math.round((1 - rep.newBytes / rep.oldBytes) * 1000) / 10),
								 Std.string(Math.round(rep.ms))]);
						}
					}

					mutex.acquire();
					pendingResults.set(job.cacheKey, {bmp: bmp, packedXml: packedXml, filePath: job.filePath});
					mutex.release();
				}
			});
		}
	}

	static function isCached(cacheKey:String):Bool
	{
		if (Paths.currentTrackedAssets.exists(cacheKey)) return true;
		if (GfxLru.has(cacheKey)) return true;
		return @:privateAccess FlxG.bitmap._cache.exists(cacheKey);
	}

	static function materialize(cacheKey:String, bmp:BitmapData):Bool
	{
		try
		{
			var graphic:FlxGraphic = FlxGraphic.fromBitmapData(bmp, false, cacheKey);
			graphic.persist = true;
			Paths.currentTrackedAssets.set(cacheKey, graphic);

			#if sys
			if (ClientPrefs.data.gfxCpuRelease)
			{
				var ctx = FlxG.stage != null ? FlxG.stage.context3D : null;
				if (ctx != null && graphic.bitmap != null && graphic.bitmap.readable)
				{
					graphic.bitmap.getTexture(ctx, true);
					bmp.disposeImage();
					GfxPolicy.registerPrefetchRelease(graphic);
				}
			}
			#end
			return true;
		}
		catch (e:Dynamic)
		{
			TraceManager.warn('trace.asyncGfx.materialize',
				'materialize failed for {}: {}', [cacheKey, e]);
			return false;
		}
	}

	public static function collectSongImages(song:Dynamic):Array<{cacheKey:String, filePath:String}>
	{
		var out:Array<{cacheKey:String, filePath:String}> = [];
		#if sys
		if (song == null) return out;

		var names:Array<String> = [];
		for (raw in [song.player2, song.player1, song.gfVersion])
		{
			var n:String = raw;
			if (n != null && n.length > 0 && names.indexOf(n) < 0)
				names.push(n);
		}

		var seenImages:Map<String, Bool> = [];
		for (name in names)
		{
			var img = charImageKey(name);
			if (img == null || seenImages.exists(img)) continue;
			seenImages.set(img, true);

			#if MODS_ALLOWED
			var modKey = Paths.modsImages(img);
			if (FileSystem.exists(modKey))
			{
				out.push({cacheKey: modKey, filePath: modKey});
				continue;
			}
			#end

			var assetId = Paths.getPath('images/' + img + '.png', IMAGE);
			var exists = false;
			try { exists = OpenFlAssets.exists(assetId); } catch (e:Dynamic) {}

			var fsPath = assetId;
			var ci = fsPath.indexOf(':');
			if (ci > 0) fsPath = fsPath.substr(ci + 1);

			#if sys
			if (!FileSystem.exists(fsPath)) exists = false;
			#end
			if (exists)
				out.push({cacheKey: assetId, filePath: fsPath});
		}
		#end
		return out;
	}

	static function charImageKey(charName:String):Null<String>
	{
		var characterPath:String = 'characters/' + charName + '.json';
		#if MODS_ALLOWED
		var path:String = Paths.modFolders(characterPath);
		if (!FileSystem.exists(path))
			path = Paths.getPreloadPath(characterPath);
		if (!FileSystem.exists(path))
			return null;
		var rawJson:String;
		try { rawJson = File.getContent(path); } catch (e:Dynamic) return null;
		#else
		var path:String = Paths.getPreloadPath(characterPath);
		var rawJson:String;
		try { rawJson = Assets.getText(path); } catch (e:Dynamic) return null;
		#end

		try
		{
			var json:{ image:Null<String> } = haxe.Json.parse(rawJson);
			if (json.image == null || json.image.length == 0) return null;
			return json.image;
		}
		catch (e:Dynamic)
		{
			return null;
		}
	}
	#end
}
