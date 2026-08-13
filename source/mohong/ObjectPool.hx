package mohong;

/**
 * Plain generic pool, no engine deps. Used by Note (Note.fromPool /
 * note.releaseToPool). Reset/reclaim is the caller's job (onRelease).
 */
class ObjectPool<T>
{
	/** Cap; 0 = unlimited. Overflowing returns are dropped. */
	public var maxCapacity(default, null):Int;

	/** Factory for fresh instances. */
	var _factory:Void->T;

	/** Called on release to reset the object. */
	var _onRelease:T->Void;

	/** Optional borrow hook. */
	var _onBorrow:T->Void;

	/** Idle stack. */
	var _available:Array<T>;

	/** Total created. */
	public var totalCreated(default, null):Int = 0;

	/** Total borrowed. */
	public var totalBorrowed(default, null):Int = 0;

	/** Total returned. */
	public var totalReturned(default, null):Int = 0;

	/** Returns dropped when full. */
	public var droppedOnReturn(default, null):Int = 0;

	public function new(factory:Void->T, ?onRelease:T->Void, ?onBorrow:T->Void, maxCapacity:Int = 0)
	{
		_factory = factory;
		_onRelease = onRelease;
		_onBorrow = onBorrow;
		this.maxCapacity = maxCapacity;
		_available = [];
	}

	/**
	 * Borrow: reuse an idle instance or make a new one.
	 */
	public function borrow():T
	{
		totalBorrowed++;

		var obj:T;
		if (_available.length > 0)
			obj = _available.pop();
		else
		{
			obj = _factory();
			totalCreated++;
		}

		if (_onBorrow != null)
			_onBorrow(obj);

		return obj;
	}

	/**
	 * Return: reset then push; drop if full.
	 */
	public function release(obj:T):Void
	{
		if (obj == null)
			return;

		totalReturned++;

		if (_onRelease != null)
			_onRelease(obj);

		if (maxCapacity > 0 && _available.length >= maxCapacity)
		{
			droppedOnReturn++;
			return;
		}

		_available.push(obj);
	}

	/** Idle count. */
	public var availableCount(get, never):Int;

	function get_availableCount():Int
	{
		return _available.length;
	}

	/** Outstanding borrows. */
	public var borrowedCount(get, never):Int;

	function get_borrowedCount():Int
	{
		return totalBorrowed - totalReturned;
	}

	/**
	 * Drop idle instances (optional destroy hook).
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

	/** One-line summary. */
	public function getDiagnostics():String
	{
		return 'Pool[created=${totalCreated} idle=${availableCount}'
			+ ' borrowed=${borrowedCount}'
			+ ' totalBorrow=${totalBorrowed} totalReturn=${totalReturned}'
			+ ' dropped=${droppedOnReturn}]';
	}
}
