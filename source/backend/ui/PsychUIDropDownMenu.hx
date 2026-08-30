package backend.ui;

import backend.ui.PsychUIBox.UIStyleData;

/**
 * Modern drop-down menu. Standalone — does NOT extend PsychUIInputText.
 * Interaction model mirrors the original: mouse-down starts tracking,
 * mouse-up selects (only if not dragged too far).
 * Mouse-wheel is consumed while the panel is open.
 *
 * Optimised with object-pooling and a reveal animation (items scale-y 0→1).
 */
class PsychUIDropDownMenu extends FlxSpriteGroup
{
	public static final CLICK_EVENT = "dropdown_click";

	/** Tracks whether ANY PsychUIDropDownMenu panel is currently open. */
	public static var anyDropdownOpen:Bool = false;

	public var list(default, set):Array<String> = [];
	public var selectedIndex(default, set):Int = -1;
	public var selectedLabel(default, set):String = null;
	public var onSelect:Int->String->Void;
	public var broadcastDropDownEvent:Bool = true;

	/** Max visible items before panel is scrollable. 0 = show all. */
	public var maxItems:Int = 0;

	/** Duration (seconds) of the reveal animation. 0 = instant. */
	public var animDuration:Float = 0.15;

	// ── Visual ──
	var _bgOuter:FlxSprite;       // outer background (rounded)
	var _labelText:FlxText;
	var _panel:FlxSpriteGroup;
	/** Non-null while the open panel is temporarily attached to FlxG.state (topmost state/substate). */
	var _panelHost:flixel.FlxState = null;
	var _isOpen:Bool = false;
	var _items:Array<DropItem> = [];

	// ── Item pool ──
	var _itemPool:Array<DropItem> = [];
	var _pooledItemCount:Int = 0; // total items we have in the pool

	// ── Scroll / drag state ──
	var _curScroll:Int = 0;
	var _mouseDownInside:Bool = false;
	var _mouseDownTime:Float = 0;
	var _hasDragged:Bool = false;
	var _dragAccumulated:Float = 0;
	var _pressedItemIndex:Int = -1;
	var _lastMouseY:Float = 0;

	// ── Animation state ──
	var _animTimer:Float = 0;
	var _animating:Bool = false;
	var _animTotalItems:Int = 0;

	/** Corner radius. */
	public var borderRadius:Int = 6;

	/** Compatibility alias. */
	public var textObj(get, never):FlxText;
	function get_textObj():FlxText { return _labelText; }
	public var fieldWidth:Int = 0;

	// ── Styles ──
	public var normalStyle:UIStyleData = {
		bgColor: 0xFFAAAAAA, textColor: FlxColor.BLACK, bgAlpha: 1
	};
	public var hoverStyle:UIStyleData = {
		bgColor: FlxColor.WHITE, textColor: FlxColor.BLACK, bgAlpha: 1
	};

	var _arrowIcon:FlxSprite;
	var _arrowText:FlxText;
	var _arrowIconY:Float = 1; // base Y for arrow

	public function new(x:Float, y:Float, list:Array<String>, callback:Int->String->Void, ?width:Float = 100)
	{
		super(x, y);
		if (list == null) list = [];
		onSelect = callback;
		var iW:Int = Std.int(width);

		_bgOuter = PsychUIHelper.createRoundedRectSprite(iW, 22, borderRadius);
		_bgOuter.color = normalStyle.bgColor;
		_bgOuter.alpha = normalStyle.bgAlpha;
		add(_bgOuter);

		_arrowIcon = new FlxSprite(iW - 20, 1).makeGraphic(20, 20, FlxColor.TRANSPARENT);
		add(_arrowIcon);
		_arrowText = new FlxText(_arrowIcon.x, _arrowIcon.y + 3, 20, "▼", 10);
		_arrowText.alignment = CENTER;
		_arrowText.color = FlxColor.BLACK;
		add(_arrowText);

		_labelText = new FlxText(4, 2, iW - 26, '', 9);
		_labelText.font = 'assets/fonts/editors.ttf';
		_labelText.color = normalStyle.textColor;
		_labelText.borderSize = 2;
		add(_labelText);

		_panel = new FlxSpriteGroup();
		_panel.visible = false;
		add(_panel);

		// Bypass setters to avoid "Missing fields" errors during construction
		@:bypassAccessor this.list = list.copy();
		if (list.length > 0) @:bypassAccessor this.selectedIndex = 0;
	}

	/** Resize the trigger background to accommodate multi-line label text. */
	function _updateTriggerSize():Void
	{
		var minH:Int = 22;
		var th:Float = _labelText.height + 4; // 2px top + 2px bottom padding
		var h:Int = Std.int(Math.max(minH, th));
		var iW:Int = Std.int(_bgOuter.width);
		PsychUIHelper.makeRoundedRect(_bgOuter, iW, h, borderRadius);

		// Reposition arrow icon to vertical center
		var arrowCenter:Float = h / 2 - 10; // 10 = 20/2 (icon half-height)
		_arrowIcon.y = arrowCenter;
		_arrowText.y = arrowCenter + 3;
	}

	// ── Open / close ──
	public function open():Void
	{
		if (_isOpen || list.length == 0) return;
		_isOpen = true;
		anyDropdownOpen = true;
		_curScroll = 0;
		_resetDragState();
		_panel.visible = true;
		_layoutItems();
		_bringPanelToFront();

		// Start reveal animation
		_animTimer = 0;
		_animating = animDuration > 0;
		_animTotalItems = _items.length;
		_applyAnimProgress(0);
	}

	public function close():Void
	{
		if (!_isOpen) return;
		_isOpen = false;
		_animating = false;
		anyDropdownOpen = false;
		_panel.visible = false;
		for (item in _items) { item.active = false; item.visible = false; }
		_resetDragState();
		_returnPanelHome();
	}

	public function toggle():Void
	{
		if (_isOpen) close() else open();
	}

	// ── Z-order management ──────────────────────────────────────
	// While open, the panel is detached from this group and attached to the
	// currently-active state/substate (FlxG.state), so it always renders above
	// sibling controls - otherwise later-added UI would cover the option list.
	function _bringPanelToFront():Void
	{
		if (_panelHost != null || FlxG.state == null) return;

		// Attach to the TOPMOST state/substate: FlxG.state does not switch while a
		// substate (Prompt etc.) is open, so walk the subState chain - same as
		// PsychUIEventHandler.event(). Otherwise the panel lands on the parent state
		// and renders underneath the prompt (wrong layer).
		var host:flixel.FlxState = FlxG.state;
		while (host != null && host.subState != null) host = host.subState;
		if (host == null) return;

		// Preserve the panel's exact render position across re-parenting:
		// the world position and scrollFactor it had as a child of this group
		// produce the same camera-view position after re-adding, whatever the
		// camera scroll/zoom state. (The old "screenPos + scroll" reconstruction
		// assumed scrollFactor == 1 and shifted the panel by the camera scroll
		// for scrollFactor-0 UI on a scrolled/zoomed camera.)
		final worldX:Float = _panel.x;
		final worldY:Float = _panel.y;
		final sfX:Float = _panel.scrollFactor.x;
		final sfY:Float = _panel.scrollFactor.y;

		remove(_panel); // FlxSpriteGroup.remove undoes preAdd (shifts pos, clears cameras)
		_panelHost = host;
		_panelHost.add(_panel);
		_panel.setPosition(worldX, worldY);
		_panel.scrollFactor.set(sfX, sfY);
		_panel.cameras = cameras;
	}

	function _returnPanelHome():Void
	{
		if (_panelHost == null) return;
		_panelHost.remove(_panel);
		_panelHost = null;

		// Restore as dropdown child: FlxSpriteGroup.add's preAdd re-applies the
		// group's accumulated position offset, so reset to (0,0) and let add()
		// shift it back. (Setting (-x,-y) would zero out the whole parent chain
		// offset and make the next open() compute a top-left screen position.)
		_panel.alpha = 1;
		_panel.setPosition(0, 0);
		add(_panel);
	}

	function _resetDragState():Void
	{
		_mouseDownInside = false;
		_mouseDownTime = 0;
		_hasDragged = false;
		_dragAccumulated = 0;
		_pressedItemIndex = -1;
	}

	// ── Object-pool helpers ──
	function _getPoolItem():DropItem
	{
		if (_itemPool.length > 0) return _itemPool.pop();
		return null;
	}

	function _returnPoolItem(item:DropItem):Void
	{
		item.x = 0;
		item.y = 0;
		item.visible = false;
		item.active = false;
		item.pressed = false;
		item.isSelected = false;
		item.scale.set(1, 1);
		_panel.remove(item);
		_itemPool.push(item);
	}

	// ── Panel layout (object-pooled, no GC thrash) ──
	function _layoutItems():Void
	{
		// Return current items to pool
		for (item in _items)
			_returnPoolItem(item);
		_items = [];

		var iW:Int = Std.int(_bgOuter.width);
		var max:Int = (maxItems > 0) ? Std.int(Math.min(maxItems, list.length)) : list.length;
		var py:Float = _bgOuter.height;
		var shown:Int = 0;

		for (i => opt in list)
		{
			if (shown >= max) break;
			if (i < _curScroll) continue;

			var item = _getPoolItem();
			if (item == null)
			{
				item = new DropItem(0, py, iW, opt, borderRadius);
			}
			else
			{
				item.setup(0, py, iW, opt, borderRadius);
			}
			item.active = true;
			item.visible = true;
			item.isSelected = (i == selectedIndex);
			item.cameras = cameras;
			item.ID = i;
			item.alpha = 1;
			item.scale.set(1, 1);
			_panel.add(item);
			_items.push(item);
			py += item.height;
			shown++;
		}
	}

	function _applyAnimProgress(t:Float):Void
	{
		var ratio:Float = (animDuration <= 0) ? 1 : FlxMath.bound(t / animDuration, 0, 1);
		// Ease-out cubic for a smooth feel
		var eased:Float = 1 - Math.pow(1 - ratio, 3);
		for (i => item in _items)
		{
			var localRatio:Float = FlxMath.bound((eased * _animTotalItems - i) / (_animTotalItems - i + 1e-5), 0, 1);
			item.scale.y = localRatio;
			item.alpha = localRatio;
		}
	}

	// ── Setters ──
	function set_list(v:Array<String>):Array<String>
	{
		var prev = selectedLabel;
		list = v;
		if (_isOpen) _layoutItems();
		if (prev != null) selectedLabel = prev;
		return v;
	}

	function set_selectedIndex(v:Int):Int
	{
		selectedIndex = (v >= 0 && v < list.length) ? v : -1;
		@:bypassAccessor selectedLabel = (selectedIndex >= 0) ? list[selectedIndex] : null;
		_labelText.text = (selectedLabel != null) ? selectedLabel : '';
		_updateTriggerSize();
		for (i => item in _items) item.isSelected = (i == selectedIndex);
		return selectedIndex;
	}

	function set_selectedLabel(v:String):String
	{
		var id = list.indexOf(v);
		selectedIndex = (id >= 0) ? id : -1;
		return v;
	}

	// ── Interaction ──
	override function update(elapsed:Float)
	{
		super.update(elapsed);

		// While the open panel is hosted by the state, keep it glued to this
		// trigger: re-sync world position + scrollFactor every frame so camera
		// pan/zoom (e.g. the background editor's movable camera) can't detach it.
		if (_panelHost != null)
		{
			_panel.setPosition(x, y);
			_panel.scrollFactor.copyFrom(scrollFactor);
		}

		var over = PsychUIEventHandler.overlaps(_bgOuter, camera);
		_bgOuter.color = over ? hoverStyle.bgColor : normalStyle.bgColor;
		_bgOuter.alpha = over ? hoverStyle.bgAlpha : normalStyle.bgAlpha;
		_labelText.color = over ? hoverStyle.textColor : normalStyle.textColor;

		// ── Reveal animation tick ──
		if (_animating)
		{
			_animTimer += elapsed;
			if (_animTimer >= animDuration)
			{
				_animTimer = animDuration;
				_animating = false;
			}
			_applyAnimProgress(_animTimer);
		}

		// ── Mouse-wheel scrolling (only when panel is open, pooled — no GC) ──
		// maxItems == 0 means "show all": there is nothing to scroll, so the
		// wheel must be ignored entirely — scrolling used to hide top items and
		// shrink/mangle the expanded panel.
		if (_isOpen && maxItems > 0 && FlxG.mouse.wheel != 0)
		{
			var maxScroll:Int = Std.int(Math.max(0, list.length - Std.int(Math.min(maxItems, list.length))));
			var newScroll = Std.int(FlxMath.bound(_curScroll - Std.int(FlxG.mouse.wheel), 0, maxScroll));
			if (newScroll != _curScroll)
			{
				_curScroll = newScroll;
				_layoutItems();
				if (_animating)
				{
					_animTimer = 0;
					_applyAnimProgress(0);
				}
			}
			return;
		}

		// ── Mouse-down tracking ──
		if (FlxG.mouse.justPressed)
		{
			if (over) { toggle(); return; }

			if (_isOpen)
			{
				_pressedItemIndex = -1;
				for (i => item in _items)
				{
					if (item.visible && item.active && PsychUIEventHandler.overlaps(item.bg, camera))
					{
						_pressedItemIndex = i;
						item.pressed = true;
						break;
					}
				}

				if (_pressedItemIndex >= 0)
				{
					_mouseDownInside = true;
					_mouseDownTime = 0;
					_hasDragged = false;
					_dragAccumulated = 0;
					_lastMouseY = FlxG.mouse.getWorldPosition(camera).y;
				}
				else close();
			}
		}

		// ── Drag-to-scroll while held ──
		if (_mouseDownInside && FlxG.mouse.pressed)
		{
			_mouseDownTime += elapsed;
			var curY = FlxG.mouse.getWorldPosition(camera).y;
			var deltaY = curY - _lastMouseY;
			_dragAccumulated += deltaY;
			_lastMouseY = curY;

			if (Math.abs(_dragAccumulated) > 1)
				_hasDragged = true;

			var itemHeight:Float = (_items.length > 0) ? _items[0].height : 20;
			if (maxItems > 0 && Math.abs(_dragAccumulated) >= itemHeight * 0.5)
			{
				var scrollDelta = Std.int(_dragAccumulated / (itemHeight * 0.5));
				_dragAccumulated -= scrollDelta * (itemHeight * 0.5);
				var maxScroll:Int = Std.int(Math.max(0, list.length - 1));
				if (maxItems > 0) maxScroll = Std.int(Math.max(0, list.length - Std.int(Math.min(maxItems, list.length))));
				var newScroll = Std.int(FlxMath.bound(_curScroll - scrollDelta, 0, maxScroll));
				if (newScroll != _curScroll)
				{
					_curScroll = newScroll;
					_layoutItems();
				}
			}

			// Update pressed-highlight to hovered item (only every few frames to reduce overhead)
			if (Math.abs(deltaY) > 0.5)
			{
				if (_pressedItemIndex >= 0 && _pressedItemIndex < _items.length)
					_items[_pressedItemIndex].pressed = false;

				_pressedItemIndex = -1;
				for (i => item in _items)
				{
					if (item.visible && item.active && PsychUIEventHandler.overlaps(item.bg, camera))
					{
						_pressedItemIndex = i;
						item.pressed = true;
						break;
					}
				}
			}
		}

		// ── Mouse-up — select only if NOT dragged (or very short drag) ──
		if (_mouseDownInside && FlxG.mouse.justReleased)
		{
			if (_pressedItemIndex >= 0 && _pressedItemIndex < _items.length)
				_items[_pressedItemIndex].pressed = false;

			if (!_hasDragged || _mouseDownTime < 0.2)
			{
				if (_pressedItemIndex >= 0 && _pressedItemIndex < _items.length
					&& _items[_pressedItemIndex].visible && _items[_pressedItemIndex].active)
				{
					var item = _items[_pressedItemIndex];
					var opt = item.label;
					var actualIndex = list.indexOf(opt);
					if (actualIndex >= 0)
					{
						close();
						selectedIndex = actualIndex;
						if (onSelect != null) onSelect(actualIndex, opt);
						if (broadcastDropDownEvent) PsychUIEventHandler.event(CLICK_EVENT, this);
					}
				}
			}
			_resetDragState();
		}
	}

	override function destroy():Void
	{
		// Guard against double-destroy: BasePrompt destroys its members once
		// explicitly and again through the super() chain, so _items may
		// already be null (or the panel already gone) on the second pass.
		if (_items != null)
		{
			if (_panelHost == null && _panel != null)
			{
				for (item in _items) _panel.remove(item);
			}
			if (_itemPool != null)
			{
				for (item in _itemPool) item.kill();
			}
			_items = null;
			_itemPool = null;
		}
		// If the panel is still attached to FlxG.state, that state owns it now.
		// Hide it so an open dropdown being destroyed doesn't leave an orphaned
		// visible panel behind.
		if (_panelHost != null && _panel != null)
			_panel.visible = false;
		_panelHost = null;
		super.destroy();
	}
}

// ── Individual drop-down item ──────────────────────────────────
private class DropItem extends FlxSpriteGroup
{
	public var hoverStyle:UIStyleData = {
		bgColor: 0xFF0066FF, textColor: FlxColor.WHITE, bgAlpha: 1
	};
	public var normalStyle:UIStyleData = {
		bgColor: FlxColor.WHITE, textColor: FlxColor.BLACK, bgAlpha: 1
	};
	public var selectedStyle:UIStyleData = {
		bgColor: 0xFF003399, textColor: FlxColor.WHITE, bgAlpha: 1
	};
	public var pressedStyle:UIStyleData = {
		bgColor: 0xFF0044CC, textColor: FlxColor.WHITE, bgAlpha: 1
	};

	public var bg:FlxSprite;
	public var text:FlxText;
	public var label:String;
	public var onClick:Void->Void;
	public var isSelected(default, set):Bool = false;
	public var pressed:Bool = false;

	public function new(x:Float, y:Float, width:Int, label:String, radius:Int)
	{
		super(x, y);
		_createGFX(width, radius);
		// Don't call setup() here; just set label so the pooled path is unified
		this.label = label;
		text.text = label;
		text.fieldWidth = width - 8;
		var h:Int = Std.int(Math.max(text.height + 6, 22));
		bg.setGraphicSize(width, h);
		bg.updateHitbox();
		this.height = bg.height;
	}

	/** Re-initialise a pooled item without re-creating graphics. */
	public function setup(x:Float, y:Float, width:Int, label:String, radius:Int):Void
	{
		this.x = x;
		this.y = y;
		this.label = label;
		var iw:Int = width;
		// Set fieldWidth BEFORE setting text so wrapping is correct on first layout
		text.fieldWidth = iw - 8;
		text.text = label;
		pressed = false;
		isSelected = false;
		scale.set(1, 1);
		alpha = 1;
		visible = true;
		active = true;

		var h:Int = Std.int(Math.max(text.height + 6, 22));
		bg.setGraphicSize(iw, h);
		bg.updateHitbox();
		this.height = bg.height;
	}

	function _createGFX(width:Int, radius:Int):Void
	{
		bg = PsychUIHelper.createRoundedRectSprite(width, 22, radius);
		add(bg);

		this.label = '';
		text = new FlxText(4, 1, width - 8, '', 9);
		text.font = 'assets/fonts/editors.ttf';
		text.color = FlxColor.BLACK;
		text.borderSize = 2;
		add(text);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if (!visible || !active) return;

		var over = PsychUIEventHandler.overlaps(bg, camera);

		var style:UIStyleData;
		if (isSelected && !over)      style = selectedStyle;
		else if (pressed)             style = pressedStyle;
		else if (over)                style = hoverStyle;
		else                          style = normalStyle;

		bg.color = style.bgColor;
		bg.alpha = style.bgAlpha;
		text.color = style.textColor;

		text.x = bg.x + 4;
		text.y = bg.y + bg.height / 2 - text.height / 2;
	}

	function set_isSelected(v:Bool):Bool { isSelected = v; return v; }
}
