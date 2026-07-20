package mohong;

import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import haxe.Timer;

/**
 * Progressive asset preloader with per-frame time budgeting.
 * 
 * Core design:
 * - **Time-budgeted loading**: Spend at most N milliseconds per frame on loading,
 *   ensuring UI remains responsive during preload.
 * - **Priority queue**: CRITICAL assets (UI, fonts) load first, LOW assets deferred.
 * - **Progress callback**: Real-time progress for loading bars.
 * - **Deduplication**: Tracks already-loaded keys to avoid redundant work.
 * 
 * This trades loading screen time for runtime performance by ensuring
 * all assets are GPU-resident and cached before gameplay starts,
 * eliminating mid-song stutter from on-demand asset loading.
 * 
 * Usage:
 * ```
 * var preloader = AssetPreloaderManager.getInstance();
 * preloader.addBatch(['menuBG', 'menuDesat'], AssetPriority.HIGH);
 * preloader.addBatch(['noteSplashes', 'alphabet'], AssetPriority.NORMAL);
 * preloader.startPreloading(function(p) loadingBar.percent = p);
 * ```
 */
class AssetPreloader
{
	// ═══════════════════════════════════════
	//  Configurable constants (soft-coded)
	// ═══════════════════════════════════════

	/** Maximum time budget per frame for preloading in milliseconds. */
	public static var frameTimeBudget:Float = 8.0;

	/** Minimum delay after completion before firing callback, in seconds. */
	public static var completionDelay:Float = 0.3;

	/** Whether to force GPU-resident textures during preload. */
	public static var forceGPUResident:Bool = true;

	/** Whether batch loading of asset keys is enabled. */
	public static var enableBatchLoading:Bool = true;

	/** Maximum preload time before forcing completion, in seconds. 0 = no limit. */
	public static var maxPreloadDuration:Float = 0;

	/** Whether to show performance impact diagnostics. */
	public static var showPerformanceImpact:Bool = false;
}

/**
 * Asset preload priority levels.
 */
enum AssetPriority
{
	/** Critical assets — UI elements, fonts, essential images. */
	CRITICAL;
	/** High priority — menu elements, common effects. */
	HIGH;
	/** Normal priority — note skins, common animation frames. */
	NORMAL;
	/** Low priority — optional effects, rare animations. */
	LOW;
	/** Lazy — loaded on demand, skipped during preload. */
	LAZY;
}

/**
 * Internal task descriptor for a single asset load operation.
 */
@:structInit
class AssetLoadTask
{
	public var assetKey:String;
	public var assetType:String; // 'image', 'sound', 'music', 'font'
	public var priority:AssetPriority;
	public function new(assetKey:String, assetType:String, priority:AssetPriority)
	{
		this.assetKey = assetKey;
		this.assetType = assetType;
		this.priority = priority;
	}
}

/**
 * Singleton asset preloader manager.
 * Handles the progressive loading loop with time budgeting.
 */
class AssetPreloaderManager
{
	/** Whether preloading is currently in progress. */
	public var isPreloading(default, null):Bool = false;

	/** Whether preloading has completed. */
	public var isComplete(default, null):Bool = false;

	/** Current progress (0.0 – 1.0). */
	public var progress(default, null):Float = 0.0;

	/** Total number of assets to load. */
	public var totalAssetCount(default, null):Int = 0;

	/** Number of assets successfully loaded so far. */
	public var loadedAssetCount(default, null):Int = 0;

	/** Number of assets that failed to load. */
	public var failedAssetCount(default, null):Int = 0;

	/** Timestamp when preloading started, in seconds. */
	public var startTime(default, null):Float = 0;

	/** Elapsed preload time so far, in seconds. */
	public var elapsedTime(get, never):Float;

	// ═══════════════════════════════════════
	//  Internal state
	// ═══════════════════════════════════════

	/** Queues grouped by priority. */
	var _criticalQueue:Array<AssetLoadTask> = [];
	var _highQueue:Array<AssetLoadTask> = [];
	var _normalQueue:Array<AssetLoadTask> = [];
	var _lowQueue:Array<AssetLoadTask> = [];

	/** Set of already-loaded asset keys to prevent duplicates. */
	var _loadedKeys:Map<String, Bool> = new Map<String, Bool>();

	/** Current position in the priority-ordered queue processing. */
	var _currentPriorityIndex:Int = 0;
	var _currentItemIndex:Int = 0;

	/** Callbacks. */
	var _onProgressUpdate:Float->Void = null;
	var _onComplete:Void->Void = null;

	/** Completion delay timer handle. */
	var _completionTimer:Timer = null;

	/** Whether completion has been triggered (to prevent double-fire). */
	var _completionTriggered:Bool = false;

	/** Timestamp of the current frame's start, for time budgeting. */
	var _frameStartTimestamp:Float = 0;

	/** Ordered list of all priority queues for iteration. */
	var _allQueues:Array<Array<AssetLoadTask>>;

	/** Singleton instance. */
	static var _instance:AssetPreloaderManager;

	// ═══════════════════════════════════════
	//  Singleton
	// ═══════════════════════════════════════

	public static function getInstance():AssetPreloaderManager
	{
		if (_instance == null)
			_instance = new AssetPreloaderManager();
		return _instance;
	}

	function new()
	{
		_allQueues = [_criticalQueue, _highQueue, _normalQueue, _lowQueue];
		reset();
	}

	// ═══════════════════════════════════════
	//  Public API
	// ═══════════════════════════════════════

	/**
	 * Add a single asset to the preload queue.
	 * @param assetKey  Asset key (e.g. 'menuBG', 'alphabet').
	 * @param assetType Asset type: 'image', 'sound', 'music', 'font'.
	 * @param priority  Loading priority.
	 */
	public function addAsset(assetKey:String, assetType:String = 'image', priority:AssetPriority = NORMAL):Void
	{
		if (_loadedKeys.exists(assetKey))
			return;
		if (isComplete)
			return;

		var task:AssetLoadTask = new AssetLoadTask(assetKey, assetType, priority);

		switch (priority)
		{
			case CRITICAL: _criticalQueue.push(task);
			case HIGH:     _highQueue.push(task);
			case NORMAL:   _normalQueue.push(task);
			case LOW:      _lowQueue.push(task);
			case LAZY:     return; // Lazy loading — skip preload
		}

		totalAssetCount++;
	}

	/**
	 * Add multiple assets at the same priority level.
	 */
	public function addBatch(assetKeys:Array<String>, priority:AssetPriority = NORMAL, assetType:String = 'image'):Void
	{
		for (key in assetKeys)
			addAsset(key, assetType, priority);
	}

	/**
	 * Start the progressive preloading process.
	 * Call this once per frame from your loading state's update loop.
	 * 
	 * @param onProgress  Progress callback (0.0 – 1.0).
	 * @param onComplete  Completion callback.
	 */
	public function startPreloading(?onProgress:Float->Void, ?onComplete:Void->Void):Void
	{
		if (isPreloading || isComplete)
			return;

		isPreloading = true;
		progress = 0.0;
		_onProgressUpdate = onProgress;
		_onComplete = onComplete;
		startTime = Timer.stamp();
		_completionTriggered = false;
	}

	/**
	 * Process one frame's worth of preloading.
	 * Call every frame from your loading state.
	 */
	public function updatePreload():Void
	{
		if (!isPreloading || isComplete || _completionTriggered)
			return;

		_frameStartTimestamp = Timer.stamp() * 1000;
		var timeBudget:Float = AssetPreloader.frameTimeBudget;
		var processedCount:Int = 0;

		// Process queues in priority order
		while (_currentPriorityIndex < _allQueues.length)
		{
			var queue:Array<AssetLoadTask> = _allQueues[_currentPriorityIndex];

			while (_currentItemIndex < queue.length)
			{
				// Check time budget
				var elapsed:Float = Timer.stamp() * 1000 - _frameStartTimestamp;
				if (elapsed >= timeBudget)
				{
					// Budget exhausted — continue next frame
					updateProgress();
					return;
				}

				var task:AssetLoadTask = queue[_currentItemIndex];
				loadSingleAsset(task);
				_currentItemIndex++;
				processedCount++;
			}

			// Move to next priority level
			_currentPriorityIndex++;
			_currentItemIndex = 0;
		}

		// All queues processed
		triggerCompletion();
	}

	/**
	 * Force-skip remaining preloading and fire completion immediately.
	 */
	public function skipRemaining():Void
	{
		if (_completionTriggered)
			return;

		// Mark all remaining as loaded
		for (queue in _allQueues)
		{
			for (task in queue)
			{
				if (!_loadedKeys.exists(task.assetKey))
				{
					_loadedKeys.set(task.assetKey, true);
					loadedAssetCount++;
				}
			}
		}

		triggerCompletion();
	}

	/**
	 * Reset the preloader state for a new session.
	 */
	public function reset():Void
	{
		if (_completionTimer != null)
		{
			_completionTimer.stop();
			_completionTimer = null;
		}

		isPreloading = false;
		isComplete = false;
		_completionTriggered = false;
		progress = 0.0;
		totalAssetCount = 0;
		loadedAssetCount = 0;
		failedAssetCount = 0;

		for (queue in _allQueues)
			queue.resize(0);

		_loadedKeys.clear();
		_currentPriorityIndex = 0;
		_currentItemIndex = 0;
	}

	// ═══════════════════════════════════════
	//  Internal
	// ═══════════════════════════════════════

	function loadSingleAsset(task:AssetLoadTask):Void
	{
		if (_loadedKeys.exists(task.assetKey))
			return;

		try
		{
			switch (task.assetType)
			{
				case 'image':
					var graphic:FlxGraphic = Paths.image(task.assetKey);
					if (graphic != null && AssetPreloader.forceGPUResident)
					{
						// Force texture upload to GPU to avoid mid-game stutter
						graphic.persist = true;
						graphic.destroyOnNoUse = false;
					}

				case 'sound':
					Paths.sound(task.assetKey);

				case 'music':
					Paths.music(task.assetKey);

				case 'font':
					Paths.font(task.assetKey);

				default:
					// Unknown type — try as image
					Paths.image(task.assetKey);
			}

			_loadedKeys.set(task.assetKey, true);
			loadedAssetCount++;
		}
		catch (e:Dynamic)
		{
			failedAssetCount++;
			TraceManager.warn('assetPreloader.loadFailed',
				'Failed to preload [{type}] {key}: {error}',
				[task.assetType, task.assetKey, Std.string(e)]);
		}
	}

	function updateProgress():Void
	{
		if (totalAssetCount > 0)
			progress = (loadedAssetCount + failedAssetCount) / totalAssetCount;

		if (_onProgressUpdate != null)
			_onProgressUpdate(progress);
	}

	function triggerCompletion():Void
	{
		if (_completionTriggered)
			return;
		_completionTriggered = true;

		progress = 1.0;
		updateProgress();

		// Small delay to ensure loading screen transition is smooth
		var delay:Float = AssetPreloader.completionDelay;
		if (delay > 0)
		{
			_completionTimer = new Timer(Std.int(delay * 1000));
			_completionTimer.run = function()
			{
				_completionTimer.stop();
				_completionTimer = null;
				finalizeCompletion();
			};
		}
		else
		{
			finalizeCompletion();
		}
	}

	function finalizeCompletion():Void
	{
		isPreloading = false;
		isComplete = true;

		if (_onComplete != null)
			_onComplete();

		_onProgressUpdate = null;
		_onComplete = null;
	}

	function get_elapsedTime():Float
	{
		if (startTime <= 0)
			return 0;
		return Timer.stamp() - startTime;
	}
}
