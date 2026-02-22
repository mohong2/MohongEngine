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
	private var buttonBinded:Bool = false;
	private var bindButton:FlxButton;
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

        if (controlsItems[Math.floor(curSelected)] == 'Pad-Custom')
        {
            if (buttonBinded)
            {
                if (touch.justReleased)
                {
                    bindButton = null;
                    buttonBinded = false;
                }
                else
                    moveButton(touch, bindButton);
            }
            else
            {
                virtualPad.forEachAlive((button:FlxButton) ->
                {
                    if (button.justPressed)
                        moveButton(touch, button);
                });
            }
            virtualPad.forEachAlive((button:FlxButton) ->
            {
                if (button != bindButton && buttonBinded)
                {
                    var snapDistance = 15; 
                    
                    if (Math.abs(bindButton.y - button.y) < snapDistance)
                    {
                        bindButton.y = button.y;
                    }

                    if (Math.abs(bindButton.x - button.x) < snapDistance)
                    {
                        bindButton.x = button.x;
                    }

                    if (Math.abs(bindButton.x - (button.x - bindButton.width - 5)) < snapDistance)
                    {
                        bindButton.x = button.x - bindButton.width - 5;
                    }
                    if (Math.abs(bindButton.x - (button.x + button.width + 5)) < snapDistance)
                    {
                        bindButton.x = button.x + button.width + 5;
                    }
                    if (Math.abs(bindButton.y - (button.y - bindButton.height - 5)) < snapDistance)
                    {
                        bindButton.y = button.y - bindButton.height - 5;
                    }
                    if (Math.abs(bindButton.y - (button.y + button.height + 5)) < snapDistance)
                    {
                        bindButton.y = button.y + button.height + 5;
                    }
                }
            });
        }
    }

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

	private function moveButton(touch:FlxTouch, button:FlxButton):Void
	{
		bindButton = button;
		bindButton.x = touch.x - Std.int(bindButton.width / 2);
		bindButton.y = touch.y - Std.int(bindButton.height / 2);

		if (!buttonBinded)
			buttonBinded = true;
	}

	private function reloadAndroidControls(daChoice:String):Void
	{
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
			remove(virtualPad);

		if (hitbox != null)
			remove(hitbox);
	}
}
