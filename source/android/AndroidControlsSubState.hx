package android;

 
 
import flixel.FlxSubState;
import flixel.addons.transition.FlxTransitionableState;
import flixel.graphics.frames.FlxAtlasFrames;
 
import flixel.input.touch.FlxTouch;
 
 
import flixel.util.FlxSave;
import android.flixel.FlxButton;
import android.flixel.FlxHitbox;
import android.flixel.FlxVirtualPad;
import openfl.utils.Assets;

class AndroidControlsSubState extends FlxSubState
{
	private final controlsItems:Array<String> = ['Pad-Right', 'Pad-Left', 'Pad-Custom', 'Hitbox', 'Keyboard'];

	private var virtualPad:FlxVirtualPad;
	private var hitbox:FlxHitbox;
	private var upPosition:FlxText;
	private var downPosition:FlxText;
	private var leftPosition:FlxText;
	private var rightPosition:FlxText;
	private var exPosition:FlxText;
	private var grpControls:FlxText;
	private var funitext:FlxText;
	private var leftArrow:FlxSprite;
	private var rightArrow:FlxSprite;
	private var curSelected:Int = 0;
	private var dragMap:Map<Int, FlxButton> = new Map();
	#if desktop
	private static inline var MOUSE_DRAG_ID:Int = -999;
	#end
	private var resetButton:FlxButton;

	override function create()
	{
		for (i in 0...controlsItems.length)
			if (controlsItems[i] == AndroidControls.mode)
				curSelected = i;

		var bg:FlxSprite = new FlxSprite(0,
			0).makeGraphic(FlxG.width, FlxG.height, FlxColor.fromRGB(FlxG.random.int(0, 255), FlxG.random.int(0, 255), FlxG.random.int(0, 255)));
		bg.scrollFactor.set();
		bg.alpha = 0.4;
		add(bg);

		var exitButton:FlxButton = new FlxButton(FlxG.width - 200, 50, 'Exit', function()
		{
			AndroidControls.mode = controlsItems[Math.floor(curSelected)];

			if (controlsItems[Math.floor(curSelected)] == 'Pad-Custom')
				AndroidControls.customVirtualPad = virtualPad;

			clearDragState();
			FlxTransitionableState.skipNextTransOut = true;
			FlxG.resetState();
		});
		exitButton.setGraphicSize(Std.int(exitButton.width) * 3);
		exitButton.label.setFormat("VCR OSD Mono", 21, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, true);
		exitButton.color = FlxColor.LIME;
		add(exitButton);

		resetButton = new FlxButton(exitButton.x, exitButton.y + 100, 'Reset', function()
		{
			if (controlsItems[Math.floor(curSelected)] == 'Pad-Custom' && resetButton.visible)
			{
				clearDragState();
				AndroidControls.customVirtualPad = new FlxVirtualPad(RIGHT_FULL, NONE, ClientPrefs.data.mobileCEx);
				reloadAndroidControls('Pad-Custom');
			}
		});
		resetButton.setGraphicSize(Std.int(resetButton.width) * 3);
		resetButton.label.setFormat("VCR OSD Mono", 21, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, true);
		resetButton.color = FlxColor.RED;
		resetButton.visible = false;
		add(resetButton);

		funitext = new FlxText(0, 0, 0, 'No Mobile Controls!', 32);
		funitext.setFormat("VCR OSD Mono", 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, true);
		funitext.borderSize = 3;
		funitext.borderQuality = 1;
		funitext.screenCenter();
		funitext.visible = false;
		add(funitext);

		grpControls = new FlxText(0, 100, 0, '', 32);
		grpControls.setFormat("VCR OSD Mono", 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, true);
		grpControls.borderSize = 3;
		grpControls.borderQuality = 1;
		grpControls.screenCenter(X);
		add(grpControls);

		leftArrow = new FlxSprite(grpControls.x - 60, grpControls.y - 25);
		leftArrow.frames = Paths.getSparrowAtlas('campaign_menu_UI_assets');
		leftArrow.animation.addByPrefix('idle', 'arrow left');
		leftArrow.animation.play('idle');
		add(leftArrow);

		rightArrow = new FlxSprite(grpControls.x + grpControls.width + 10, grpControls.y - 25);
		rightArrow.frames = Paths.getSparrowAtlas('campaign_menu_UI_assets');
		rightArrow.animation.addByPrefix('idle', 'arrow right');
		rightArrow.animation.play('idle');
		add(rightArrow);

		rightPosition = new FlxText(10, FlxG.height - 24, 0, '', 16);
		rightPosition.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, true);
		rightPosition.borderSize = 3;
		rightPosition.borderQuality = 1;
		add(rightPosition);

		leftPosition = new FlxText(10, FlxG.height - 44, 0, '', 16);
		leftPosition.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, true);
		leftPosition.borderSize = 3;
		leftPosition.borderQuality = 1;
		add(leftPosition);

		downPosition = new FlxText(10, FlxG.height - 64, 0, '', 16);
		downPosition.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, true);
		downPosition.borderSize = 3;
		downPosition.borderQuality = 1;
		add(downPosition);

		upPosition = new FlxText(10, FlxG.height - 84, 0, '', 16);
		upPosition.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, true);
		upPosition.borderSize = 3;
		upPosition.borderQuality = 1;
		add(upPosition);

		exPosition = new FlxText(10, FlxG.height - 104, 0, '', 16);
		exPosition.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, true);
		exPosition.borderSize = 3;
		exPosition.borderQuality = 1;
		add(exPosition);

		changeSelection();

		super.create();
	}

override function update(elapsed:Float)
{
    super.update(elapsed);

    for (touch in FlxG.touches.list)
    {
        if (touch.overlaps(leftArrow) && touch.justPressed)
            changeSelection(-1);
        else if (touch.overlaps(rightArrow) && touch.justPressed)
            changeSelection(1);

        handlePadCustomDrag(touch, touch.x, touch.y, touch.touchPointID);
    }

    // 桌面端触屏支持: 鼠标也当作触摸处理
    #if desktop
    if (FlxG.mouse != null)
    {
        if (FlxG.mouse.overlaps(leftArrow) && FlxG.mouse.justPressed)
            changeSelection(-1);
        else if (FlxG.mouse.overlaps(rightArrow) && FlxG.mouse.justPressed)
            changeSelection(1);

        handlePadCustomDrag(FlxG.mouse, FlxG.mouse.x, FlxG.mouse.y, MOUSE_DRAG_ID);
    }
    #end

    cleanupDragMap();

    if (virtualPad != null && controlsItems[Math.floor(curSelected)] == 'Pad-Custom')
    {
        if (virtualPad.buttonUp != null)
            upPosition.text = 'Button Up X:' + virtualPad.buttonUp.x + ' Y:' + virtualPad.buttonUp.y;

        if (virtualPad.buttonDown != null)
            downPosition.text = 'Button Down X:' + virtualPad.buttonDown.x + ' Y:' + virtualPad.buttonDown.y;

        if (virtualPad.buttonLeft != null)
            leftPosition.text = 'Button Left X:' + virtualPad.buttonLeft.x + ' Y:' + virtualPad.buttonLeft.y;

        if (virtualPad.buttonRight != null)
            rightPosition.text = 'Button Right X:' + virtualPad.buttonRight.x + ' Y:' + virtualPad.buttonRight.y;

        if (virtualPad.buttonEx != null)
            exPosition.text = 'Button Extra X:' + virtualPad.buttonEx.x + ' Y:' + virtualPad.buttonEx.y;
    }
}

	/** Pad-Custom 模式下按触点（触摸/鼠标）拖动按钮，每个触点独立跟踪一个按键。 */
	private function handlePadCustomDrag(input:Dynamic, px:Float, py:Float, inputId:Int):Void
	{
		if (controlsItems[Math.floor(curSelected)] != 'Pad-Custom' || virtualPad == null)
			return;

		// 发起拖动的触点释放时，只结束该触点自己的拖动，避免其他指头误伤。
		if (input.justReleased)
		{
			dragMap.remove(inputId);
			return;
		}

		var draggedButton:FlxButton = dragMap.get(inputId);
		if (draggedButton != null)
		{
			moveButton(px, py, draggedButton);
			snapDragButton(draggedButton);
			return;
		}

		// 当前触点没有在拖，尝试拾起一个按键（支持多指同时拖多个按键）。
		var pickedUp:Bool = false;
		virtualPad.forEachAlive((button:FlxButton) ->
		{
			if (!pickedUp && button.justPressed && !isButtonDragged(button))
			{
				dragMap.set(inputId, button);
				moveButton(px, py, button);
				snapDragButton(button);
				pickedUp = true;
			}
		});
	}

	/** 让被拖动的按钮吸附到其他按钮旁边, 方便对齐。 */
	private function snapDragButton(dragButton:FlxButton):Void
	{
		if (dragButton == null || virtualPad == null)
			return;

		virtualPad.forEachAlive((button:FlxButton) ->
		{
			if (button != dragButton && !isButtonDragged(button))
			{
				var snapDistance = 15;

				if (Math.abs(dragButton.y - button.y) < snapDistance)
				{
					dragButton.y = button.y;
				}

				if (Math.abs(dragButton.x - button.x) < snapDistance)
				{
					dragButton.x = button.x;
				}

				if (Math.abs(dragButton.x - (button.x - dragButton.width - 5)) < snapDistance)
				{
					dragButton.x = button.x - dragButton.width - 5;
				}
				if (Math.abs(dragButton.x - (button.x + button.width + 5)) < snapDistance)
				{
					dragButton.x = button.x + button.width + 5;
				}
				if (Math.abs(dragButton.y - (button.y - dragButton.height - 5)) < snapDistance)
				{
					dragButton.y = button.y - dragButton.height - 5;
				}
				if (Math.abs(dragButton.y - (button.y + button.height + 5)) < snapDistance)
				{
					dragButton.y = button.y + button.height + 5;
				}
			}
		});

		clampButton(dragButton);
	}

	/** 该按键是否已被其他触点拖动。 */
	private function isButtonDragged(button:FlxButton):Bool
	{
		for (id in dragMap.keys())
			if (dragMap.get(id) == button)
				return true;
		return false;
	}

	/** 清理失效触点/切换模式时残留的拖动状态。 */
	private function clearDragState():Void
	{
		dragMap = new Map();
	}

	/** 清理已不在当前触点列表里的拖动记录（例如焦点丢失/异常取消）。 */
	private function cleanupDragMap():Void
	{
		var activeIds:Array<Int> = [];
		for (touch in FlxG.touches.list)
			activeIds.push(touch.touchPointID);

		#if desktop
		if (FlxG.mouse != null && FlxG.mouse.pressed)
			activeIds.push(MOUSE_DRAG_ID);
		#end

		var staleIds:Array<Int> = [];
		for (id in dragMap.keys())
			if (activeIds.indexOf(id) == -1)
				staleIds.push(id);

		for (id in staleIds)
			dragMap.remove(id);
	}

	/** 把按键限制在屏幕范围内，避免拖出屏幕后找不到。 */
	private function clampButton(button:FlxButton):Void
	{
		if (button == null)
			return;

		var maxX:Float = FlxG.width - button.width;
		var maxY:Float = FlxG.height - button.height;
		if (maxX < 0) maxX = 0;
		if (maxY < 0) maxY = 0;

		if (button.x < 0)
			button.x = 0;
		else if (button.x > maxX)
			button.x = maxX;

		if (button.y < 0)
			button.y = 0;
		else if (button.y > maxY)
			button.y = maxY;
	}

	private function changeSelection(change:Int = 0):Void
	{
		curSelected += change;

		if (curSelected < 0)
			curSelected = controlsItems.length - 1;
		else if (curSelected >= controlsItems.length)
			curSelected = 0;

		grpControls.text = controlsItems[Math.floor(curSelected)];
		grpControls.screenCenter(X);

		leftArrow.x = grpControls.x - 60;
		rightArrow.x = grpControls.x + grpControls.width + 10;

		var daChoice:String = controlsItems[Math.floor(curSelected)];

		reloadAndroidControls(daChoice);

		funitext.visible = daChoice == 'Keyboard';
		resetButton.visible = daChoice == 'Pad-Custom';
		upPosition.visible = daChoice == 'Pad-Custom';
		downPosition.visible = daChoice == 'Pad-Custom';
		leftPosition.visible = daChoice == 'Pad-Custom';
		rightPosition.visible = daChoice == 'Pad-Custom';
		exPosition.visible = daChoice == 'Pad-Custom';
	}

	private function moveButton(px:Float, py:Float, button:FlxButton):Void
	{
		button.x = px - Std.int(button.width / 2);
		button.y = py - Std.int(button.height / 2);
		clampButton(button);
	}

	private function reloadAndroidControls(daChoice:String):Void
	{
		clearDragState();

		switch (daChoice)
		{
			case 'Pad-Right':
				removeControls();
				virtualPad = new FlxVirtualPad(RIGHT_FULL, NONE, ClientPrefs.data.mobileCEx);
				add(virtualPad);
			case 'Pad-Left':
				removeControls();
				virtualPad = new FlxVirtualPad(LEFT_FULL, NONE, ClientPrefs.data.mobileCEx);
				add(virtualPad);
			case 'Pad-Custom':
				removeControls();
				virtualPad = AndroidControls.customVirtualPad;
				add(virtualPad);
			case 'Hitbox':
				removeControls();
				hitbox = new FlxHitbox(4, Std.int(FlxG.width / 4), FlxG.height, [0xFF00FF, 0x00FFFF, 0x00FF00, 0xFF0000]);
				add(hitbox);
			default:
				removeControls();
		}

		if (virtualPad != null)
			virtualPad.visible = (daChoice != 'Hitbox' && daChoice != 'Keyboard');

		if (hitbox != null)
			hitbox.visible = (daChoice == 'Hitbox');
	}

	private function removeControls():Void
	{
		if (virtualPad != null)
		{
			remove(virtualPad);
			virtualPad = null;
		}

		if (hitbox != null)
		{
			remove(hitbox);
			hitbox = null;
		}
	}
}
