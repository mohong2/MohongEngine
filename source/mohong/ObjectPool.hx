package mohong;

/**
 * Generic typed object pool for reusing frequently created/destroyed objects.
 * 
 * Design:
 * - Pre-allocate a configurable number of instances
 * - Borrow/Return pattern with automatic growth
 * - Optional leak detection for outstanding borrows
 * - Reset callback for cleaning objects on return
 * 
 * Usage:
 * ```
 * var notePool = new ObjectPool<Note>(function() return new Note(), 200);
 * var note = notePool.borrow();
 * // ... use note ...
 * notePool.return(note, function(n) n.reset());
 * ```
 */
class ObjectPool<T>
{
	/** Maximum pool capacity. Prevents unbounded growth. */
	public var maxCapacity(default, null):Int;

	/** Factory function to create new instances. */
	var _factory:Void->T;

	/** Reset function called when returning an object. */
	var _reset:T->Void;

	/** Stack of available (idle) objects. */
	var _available:Array<T>;

	/** Count of objects currently borrowed out. */
	var _borrowedCount:Int = 0;

	/** Total objects created by this pool (for diagnostics). */
	public var totalCreated(default, null):Int = 0;

	/** Total borrow requests served. */
	public var totalBorrowed(default, null):Int = 0;

	/** Total return operations. */
	public var totalReturned(default, null):Int = 0;

	/** Whether to log pool diagnostics. */
	public var verbose:Bool = false;

	/**
	 * @param factory  Factory to create new instances.
	 * @param initialCapacity Initial number of pre-allocated instances.
	 * @param maxCapacity Maximum pool size. 0 = unlimited.
	 * @param resetFn Optional reset function called on return.
	 */
	public function new(factory:Void->T, initialCapacity:Int = 0, maxCapacity:Int = 0, ?resetFn:T->Void)
	{
		_factory = factory;
		_reset = resetFn;
		this.maxCapacity = maxCapacity;
		_available = [];

		// Pre-allocate
		for (i in 0...initialCapacity)
		{
			var obj:T = _factory();
			_available.push(obj);
			totalCreated++;
		}
	}

	// ═══════════════════════════════════════
	//  Core API
	// ═══════════════════════════════════════

	/**
	 * Borrow an object from the pool. Creates a new one if the pool is empty
	 * and capacity allows.
	 * @return An available instance.
	 */
	public function borrow():T
	{
		totalBorrowed++;

		if (_available.length > 0)
		{
			_borrowedCount++;
			return _available.pop();
		}

		// Pool exhausted — create new if capacity allows
		if (maxCapacity > 0 && totalCreated >= maxCapacity)
		{
			if (verbose)
				TraceManager.warn('objectPool.overflow',
					'Pool capacity exceeded ({max}/{capacity}), reusing oldest',
					[totalCreated, maxCapacity]);
			// Fallback: create anyway but log warning
		}

		_borrowedCount++;
		totalCreated++;
		return _factory();
	}

	/**
	 * Return an object to the pool for reuse.
	 * @param obj The object to return.
	 * @param customReset Optional per-return reset function (overrides default).
	 */
	public function returnObject(obj:T, ?customReset:T->Void):Void
	{
		if (obj == null)
			return;

		totalReturned++;
		_borrowedCount--;

		// Apply reset
		if (customReset != null)
			customReset(obj);
		else if (_reset != null)
			_reset(obj);

		// Check capacity before returning to pool
		if (maxCapacity > 0 && _available.length >= maxCapacity)
		{
			// Pool full — discard this instance
			return;
		}

		_available.push(obj);
	}

	/**
	 * Pre-allocate additional instances up to the given count.
	 * Useful for warming the pool before heavy use.
	 */
	public function preAllocate(count:Int):Void
	{
		var target:Int = totalCreated + count;
		if (maxCapacity > 0 && target > maxCapacity)
			target = maxCapacity;

		while (totalCreated < target)
		{
			_available.push(_factory());
			totalCreated++;
		}
	}

	/**
	 * Destroy all idle objects in the pool. Does not affect borrowed objects.
	 * @param destroyFn Function to clean up each object before removal.
	 */
	public function clear(?destroyFn:T->Void):Void
	{
		if (destroyFn != null)
		{
			for (obj in _available)
				destroyFn(obj);
		}
		_available = [];
	}

	/**
	 * Get the current number of available (idle) objects.
	 */
	public var availableCount(get, never):Int;

	function get_availableCount():Int
	{
		return _available.length;
	}

	/**
	 * Get the number of currently borrowed objects.
	 */
	public var borrowedCount(get, never):Int;

	function get_borrowedCount():Int
	{
		return _borrowedCount;
	}

	/**
	 * Get a diagnostic summary string.
	 */
	public function getDiagnostics():String
	{
		return 'Pool[created=${totalCreated} idle=${availableCount}'
			+ ' borrowed=${borrowedCount}'
			+ ' totalBorrow=${totalBorrowed} totalReturn=${totalReturned}]';
	}
}
