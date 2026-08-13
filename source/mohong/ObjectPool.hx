package mohong;

/**
 * 泛型对象池（mohong 重写版）。
 *
 * 解决什么问题：
 *   高频创建/销毁对象的复用，削 GC 压力。旧实现存在但全项目零调用点。
 *
 * 挂在哪个真实调用点：
 *   Note 对象池——PlayState.generateSong 通过 Note.fromPool 借出，
 *   PlayState.destroy 通过 note.releaseToPool 归还。
 *
 * 怎么验证它真的在工作：
 *   池诊断计数随切歌增长；重复切歌时 MemoryMonitor 的内存曲线更平稳；
 *   池命中率 = 1 - totalCreated / totalBorrowed。
 *
 * 纯数据结构：零平台依赖、不依赖引擎类型、不做任何资源回收决策
 * （回收/重置由调用方通过 onRelease 回调完成）。
 */
class ObjectPool<T>
{
	/** 容量上限；0 = 不限。超限时归还的对象直接丢弃（交给 GC）。 */
	public var maxCapacity(default, null):Int;

	/** 工厂：池耗尽时创建新实例。 */
	var _factory:Void->T;

	/** 归还回调：清空对象状态（对象已由调用方处理完资源释放）。 */
	var _onRelease:T->Void;

	/** 借出回调（可选）。 */
	var _onBorrow:T->Void;

	/** 闲置实例栈。 */
	var _available:Array<T>;

	/** 累计创建数。 */
	public var totalCreated(default, null):Int = 0;

	/** 累计借出次数。 */
	public var totalBorrowed(default, null):Int = 0;

	/** 累计归还次数。 */
	public var totalReturned(default, null):Int = 0;

	/** 因容量满被丢弃的归还数。 */
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
	 * 借出一个对象：优先复用闲置实例，否则用工厂新建。
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
	 * 归还一个对象：先回调清空状态，再入池；容量满则丢弃。
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

	/** 当前闲置实例数。 */
	public var availableCount(get, never):Int;

	function get_availableCount():Int
	{
		return _available.length;
	}

	/** 当前借出未还数。 */
	public var borrowedCount(get, never):Int;

	function get_borrowedCount():Int
	{
		return totalBorrowed - totalReturned;
	}

	/**
	 * 清空闲置实例（可选销毁回调）。
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

	/** 诊断摘要（一行文本）。 */
	public function getDiagnostics():String
	{
		return 'Pool[created=${totalCreated} idle=${availableCount}'
			+ ' borrowed=${borrowedCount}'
			+ ' totalBorrow=${totalBorrowed} totalReturn=${totalReturned}'
			+ ' dropped=${droppedOnReturn}]';
	}
}
