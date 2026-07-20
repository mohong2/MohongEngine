package editors.content;

import flixel.FlxCamera;
import backend.ui.PsychUIButton;
import flixel.util.FlxDestroyUtil;

class ExitConfirmationPrompt extends Prompt
{
    public function new(?finishCallback:Void->Void)
    {
        super('There\'s unsaved progress,\nare you sure you want to exit?', function()
        {
            FlxG.mouse.visible = false;
            MusicBeatState.switchState(new editors.MasterEditorMenu());
            FlxG.sound.playMusic(Paths.music('freakyMenu'));
            if(finishCallback != null) finishCallback();
        }, 'Exit');
    }
}

class Prompt extends BasePrompt
{
    var yesFunction:Void->Void;
    var noFunction:Void->Void;
    var _yesTxt:String = 'OK';
    var _noTxt:String = 'Cancel';
    
    public function new(title:String, yesFunction:Void->Void, ?noFunction:Void->Void, ?_yesTxt:String, ?_noTxt:String)
    {
        if(_yesTxt != null) this._yesTxt = _yesTxt;
        if(_noTxt != null) this._noTxt = _noTxt;
        this.yesFunction = yesFunction;
        this.noFunction = noFunction;
        super(title, promptCreate);
    }

    function promptCreate(_)
    {
        var btnY = 390;
        var btn:PsychUIButton = new PsychUIButton(0, btnY, _yesTxt, function() {
            yesFunction();
            close();
        });
        btn.color = FlxColor.RED;
        //btn.label.color = FlxColor.WHITE;
        btn.screenCenter(X);
        btn.x -= 100;
        btn.cameras = cameras;
        add(btn);

        var btn:PsychUIButton = new PsychUIButton(0, btnY, _noTxt, close);
        btn.screenCenter(X);
        btn.x += 100;
        btn.cameras = cameras;
        add(btn);
    }

    override function close()
    {
        if(noFunction != null) noFunction();
        super.close();
    }
}

class BasePrompt extends MusicBeatSubstate
{
    var _sizeX:Float = 0;
    var _sizeY:Float = 0;
    var _title:String;

    public var onCreate:BasePrompt->Void;
    public var onUpdate:BasePrompt->Float->Void;
    
    /** If false, no close button is added. Default true (for mobile compatibility). */
    public var showCloseButton:Bool = true;
    
    public function new(?sizeX:Float = 420, ?sizeY:Float = 160, title:String, ?onCreate:BasePrompt->Void, ?onUpdate:BasePrompt->Float->Void)
    {
        this._sizeX = sizeX;
        this._sizeY = sizeY;
        if(Language.has(title))
        this._title = Language.get(title);
            else
        this._title = title;
        this.onCreate = onCreate;
        this.onUpdate = onUpdate;
        super();
    }

    public var bg:FlxSprite;
    public var titleText:FlxText;
    public var closeButton:PsychUIButton;
    
    /** Duration of the appear/disappear tween. */
    public var animDuration:Float = 0.15;
    
    override function create()
    {
        // Create a dedicated fixed camera so Prompt always draws correctly
        // regardless of the parent state's camera scrolling
        var promptCam = new FlxCamera();
        promptCam.bgColor.alpha = 0;
        FlxG.cameras.add(promptCam, false);
        cameras = [promptCam];

        bg = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
        bg.alpha = 0.8;
        bg.scale.set(_sizeX, _sizeY);
        bg.updateHitbox();
        bg.screenCenter();
        bg.cameras = cameras;
        add(bg);
        
        titleText = new FlxText(0, bg.y + 30, 400, _title, 16);
        titleText.font = 'assets/fonts/editors.ttf';
        titleText.screenCenter(X);
        titleText.alignment = CENTER;
        titleText.cameras = cameras;
        add(titleText);

        // Appear animation: scale from 0.92 + fade in
        bg.scale.set(_sizeX * 0.92, _sizeY * 0.92);
        bg.updateHitbox();
        bg.screenCenter();
        bg.alpha = 0;
        FlxTween.tween(bg, {alpha: 0.8}, animDuration, {ease: FlxEase.quadOut});
        FlxTween.tween(bg.scale, {x: _sizeX, y: _sizeY}, animDuration, {ease: FlxEase.backOut});
        
        titleText.alpha = 0;
        FlxTween.tween(titleText, {alpha: 1}, animDuration, {ease: FlxEase.quadOut, startDelay: 0.05});
        
        if(onCreate != null)
            onCreate(this);

        // Close button (X) — added AFTER onCreate so it draws on top of everything
        if (showCloseButton)
        {
            closeButton = new PsychUIButton(bg.x + bg.width - 30, bg.y + 2, 'X', function()
            {
                close();
            }, 24, 24, null, 12);
            closeButton.cameras = cameras;
            closeButton.normalStyle.bgColor = FlxColor.fromRGB(160, 35, 35);
            closeButton.normalStyle.textColor = FlxColor.WHITE;
            add(closeButton);
            closeButton.alpha = 0;
            FlxTween.tween(closeButton, {alpha: 1}, animDuration, {ease: FlxEase.quadOut, startDelay: 0.05});
        }

        super.create();
    }

    var _blockInput:Float = 0.1;
    override function update(elapsed:Float)
    {
        super.update(elapsed);

        _blockInput = Math.max(0, _blockInput - elapsed);
        if(_blockInput <= 0 && FlxG.keys.justPressed.ESCAPE)
        {
            close();
            return;
        }

        if(onUpdate != null)
            onUpdate(this, elapsed);
    }

    override function destroy()
    {
        for (member in members) FlxDestroyUtil.destroy(member);
        if(cameras != null && cameras.length > 0)
        {
            var cam = cameras[0];
            if(cam != null && cam != FlxG.camera)
            {
                FlxG.cameras.remove(cam, true);
                cam = FlxDestroyUtil.destroy(cam);
            }
        }
        super.destroy();
    }

    /** Fade-out then close. */
    override function close()
    {
        FlxTween.cancelTweensOf(bg, ['alpha', 'scale.x', 'scale.y']);
        FlxTween.cancelTweensOf(titleText, ['alpha']);
        FlxTween.tween(bg, {alpha: 0}, animDuration * 0.8, {ease: FlxEase.quadIn});
        var doClose = _finishClose;
        FlxTween.tween(bg.scale, {x: _sizeX * 0.92, y: _sizeY * 0.92}, animDuration * 0.8, {ease: FlxEase.quadIn,
            onComplete: function(_) doClose()
        });
        FlxTween.tween(titleText, {alpha: 0}, animDuration * 0.6, {ease: FlxEase.quadIn});
    }

    function _finishClose()
    {
        FlxG.state.closeSubState();
    }
}