package;

import flixel.math.FlxRect;
import editors.ChartingState;

using StringTools;

typedef EventNote = {
    strumTime:Float,
    event:String,
    value1:String,
    value2:String
}

@:structInit class PreloadedChartNote {
    public var strumTime:Float = 0;
    public var noteData:Int = 0;
    public var mustPress:Bool = false;
    public var oppNote:Bool = false;
    public var noteType:String = '';
    public var animSuffix:String = '';
    public var gfNote:Bool = false;
    public var noAnimation:Bool = false;
    public var noMissAnimation:Bool = false;
    public var isSustainNote:Bool = false;
    public var isSustainEnd:Bool = false;
    public var sustainLength:Float = 0;
    public var parentST:Float = 0;
    public var parentSL:Float = 0;
    public var hitHealth:Float = 0.023;
    public var missHealth:Float = 0.0475;
    public var hitCausesMiss:Bool = false;
    public var ignoreNote:Bool = false;
    public var blockHit:Bool = false;
    public var multSpeed:Float = 1;
    public var multAlpha:Float = 1;
    public var noteDensity:Float = 1;
    public var lowPriority:Bool = false;
    public var noteskin:String = '';
    public var texture:String = '';
    public var wasHit:Bool = false;
    public var offsetX:Float = 0;
    public var offsetY:Float = 0;
    public var noteSplashDisabled:Bool = false;
    public var hitsoundDisabled:Bool = false;
}

/**
 * 用于旧格式谱面 (0.1 – 0.3.2) 的 noteType 数值 → 字符串 转换表。
 * 与 104 新版保持一致的默认列表，加载 ChartingState 前即可安全使用。
 */
final defaultNoteTypes:Array<String> = [
	'', //Always leave this one empty pls
	'Alt Animation',
	'Hey!',
	'Hurt Note',
	'GF Sing',
	'No Animation'
];

class Note extends FlxSprite {
    public var extraData:Map<String,Dynamic> = [];
    public var strumTime:Float = 0;
    public var mustPress:Bool = false;
    public var doOppStuff:Bool = false;
    public var noteData:Int = 0;
    public var canBeHit:Bool = false;
    public var tooLate:Bool = false;
    public var wasGoodHit:Bool = false;
    public var missed:Bool = false;
    public var ignoreNote:Bool = false;
    public var hitByOpponent:Bool = false;
    public var noteWasHit:Bool = false;
    public var prevNote:Note;
    public var nextNote:Note;

    public var wasHit:Bool = false;
    public var spawned:Bool = false;
    public var tail:Array<Note> = [];
    public var parent:Note;
    public var parentST:Float = 0;
    public var parentSL:Float = 0;
    public var blockHit:Bool = false;

    public var sustainLength:Float = 0;
    public var isSustainNote:Bool = false;
    public var isSustainEnd:Bool = false;
    public var canHold:Bool = false;
    public var noteType(default, set):String = null;

    public var eventName:String = '';
    public var eventLength:Int = 0;
    public var eventVal1:String = '';
    public var eventVal2:String = '';

    public var colorSwap:ColorSwap;
    public var inEditor:Bool = false;

    public var animSuffix:String = '';
    public var gfNote:Bool = false;
    public var earlyHitMult:Float = 0.5;
    public var lateHitMult:Float = 1;
    public var lowPriority:Bool = false;

    public var noteDensity:Float = 1;
    public static var swagWidth:Float = 160 * 0.7;

    private var colArray:Array<String> = ['purple', 'blue', 'green', 'red'];
    private var pixelInt:Array<Int> = [0, 1, 2, 3];

    public var noteSplashDisabled:Bool = false;
    public var noteSplashTexture:String = null;
    public var noteSplashHue:Float = 0;
    public var noteSplashSat:Float = 0;
    public var noteSplashBrt:Float = 0;

    public var offsetX:Float = 0;
    public var offsetY:Float = 0;
    public var offsetAngle:Float = 0;
    public var multAlpha:Float = 1;
    public var multSpeed(default, set):Float = 1;

    public var copyX:Bool = true;
    public var copyY:Bool = true;
    public var copyAngle:Bool = true;
    public var copyAlpha:Bool = true;
    public var copyScaleX:Bool = false;
    public var copyScaleY:Bool = false;

    public var hitHealth:Float = 0.023;
    public var missHealth:Float = 0.0475;
    public var rating:String = 'unknown';
    public var ratingMod:Float = 0;
    public var ratingDisabled:Bool = false;

    public var texture(default, set):String = null;

    public var noAnimation:Bool = false;
    public var noMissAnimation:Bool = false;
    public var hitCausesMiss:Bool = false;
    public var distance:Float = 2000;
    public var hitsoundDisabled:Bool = false;

    public var originalHeightForCalcs:Float = 6;

    private function set_multSpeed(value:Float):Float {
        if(!isSustainNote || isSustainEnd) {
            multSpeed = value;
            return value;
        }
        var ratio:Float = value / multSpeed;
        if(ratio != 1) {
            scale.y *= ratio;
            updateHitbox();
        }
        multSpeed = value;
        return value;
    }

    public function resizeByRatio(ratio:Float) {
        if(isSustainNote && !isSustainEnd && scale != null) {
            scale.y *= ratio;
            updateHitbox();
        }
    }

    /**
     * 根据当前 songSpeed 重新计算长条 body 的 scale.y，
     * 避免 `resizeByRatio` 乘法累积带来的浮点精度问题和极端值渲染异常。
     * @param newSongSpeed 当前新的 songSpeed 值（即 set_songSpeed 传入的 value）
     */
    public function recalcSustainScale(newSongSpeed:Float):Void {
        if(!isSustainNote || isSustainEnd || scale == null) return;
        if(PlayState.instance == null) return;

        var stepCrochet:Float = Conductor.stepCrochet;
        scale.y = (stepCrochet / 100) * 1.05 * newSongSpeed * multSpeed;
        if(PlayState.isPixelStage) {
            scale.y *= 1.19;
            scale.y *= (6 / frameHeight);
        }
        updateHitbox();
    }

    private function set_texture(value:String):String {
        if(texture != value) {
            reloadNote('', value);
        }
        texture = value;
        return value;
    }

    private function set_noteType(value:String):String {
		if (colorSwap == null) return value; // safety: colorSwap only created when noteData > -1
        if(noteData > -1 && noteData < ClientPrefs.data.arrowHSV.length) {
            colorSwap.hue = ClientPrefs.data.arrowHSV[noteData][0] / 360;
            colorSwap.saturation = ClientPrefs.data.arrowHSV[noteData][1] / 100;
            colorSwap.brightness = ClientPrefs.data.arrowHSV[noteData][2] / 100;
        }
        if(noteData > -1 && noteType != value) {
            switch(value) {
                case 'Hurt Note':
                    ignoreNote = mustPress;
                    reloadNote('HURT');
                    noteSplashTexture = 'HURTnoteSplashes';
                    colorSwap.hue = 0;
                    colorSwap.saturation = 0;
                    colorSwap.brightness = 0;
                    lowPriority = true;
                    if(isSustainNote) missHealth = 0.1;
                    else missHealth = 0.3;
                    hitCausesMiss = true;
                case 'Alt Animation':
                    animSuffix = '-alt';
                case 'No Animation':
                    noAnimation = true;
                    noMissAnimation = true;
                case 'GF Sing':
                    gfNote = true;
            }
            noteType = value;
        }
        noteSplashHue = colorSwap.hue;
        noteSplashSat = colorSwap.saturation;
        noteSplashBrt = colorSwap.brightness;
        return value;
    }

    public function new(?strumTime:Float = 0, ?noteData:Int = 0, ?prevNote:Note, ?sustainNote:Bool = false, ?inEditor:Bool = false, ?skipTexture:Bool = false) {
        super();
        if(prevNote == null) prevNote = this;
        this.prevNote = prevNote;
        isSustainNote = sustainNote;
        this.inEditor = inEditor;

        x += (ClientPrefs.data.middleScroll ? PlayState.STRUM_X_MIDDLESCROLL : PlayState.STRUM_X) + 50;
        y -= 2000;
        this.strumTime = strumTime;
        if(!inEditor) this.strumTime += ClientPrefs.data.noteOffset;
        this.noteData = noteData;

        if(noteData > -1) {
            if(!skipTexture) texture = '';
            colorSwap = new ColorSwap();
            shader = colorSwap.shader;
            x += swagWidth * noteData;
            if(!skipTexture && !isSustainNote && noteData > -1 && noteData < 4) {
                animation.play(colArray[noteData % 4] + 'Scroll');
            }
        }

        if(prevNote != null) prevNote.nextNote = this;

        if(isSustainNote && prevNote != null) {
            alpha = 0.6;
            multAlpha = 0.6;
            hitsoundDisabled = true;
            isSustainEnd = true;
            if(ClientPrefs.data.downScroll) flipY = true;

            offsetX += width / 2;
            copyAngle = false;
            animation.play(colArray[noteData % 4] + 'holdend');
            updateHitbox();
            offsetX -= width / 2;
            if(PlayState.isPixelStage) offsetX += 30;

            if(prevNote.isSustainNote) {
                isSustainEnd = false;
                prevNote.animation.play(colArray[prevNote.noteData % 4] + 'hold');
                prevNote.scale.y *= Conductor.stepCrochet / 100 * 1.05;
                if(PlayState.instance != null) prevNote.scale.y *= PlayState.instance.songSpeed;
                if(PlayState.isPixelStage) {
                    prevNote.scale.y *= 1.19;
                    prevNote.scale.y *= (6 / prevNote.frameHeight);
                }
                prevNote.updateHitbox();
            }
            if(PlayState.isPixelStage) {
                scale.y *= PlayState.daPixelZoom;
                updateHitbox();
            }
        } else if(!isSustainNote) {
            earlyHitMult = 1;
        }
        x += offsetX;
    }

    var lastNoteOffsetXForPixelAutoAdjusting:Float = 0;

    public function reloadNote(?prefix:String = '', ?texture:String = '', ?suffix:String = '') {
        if(prefix == null) prefix = '';
        if(texture == null) texture = '';
        if(suffix == null) suffix = '';

        var skin:String = texture;
        if(texture.length < 1) {
            skin = PlayState.SONG.arrowSkin;
            if(skin == null || skin.length < 1) skin = 'NOTE_assets';
        }

        var animName:String = (animation.curAnim != null) ? animation.curAnim.name : null;
        var arraySkin:Array<String> = skin.split('/');
        arraySkin[arraySkin.length-1] = prefix + arraySkin[arraySkin.length-1] + suffix;
        var lastScaleY:Float = scale.y;
        var blahblah:String = arraySkin.join('/');

        if(PlayState.isPixelStage) {
            if(isSustainNote) {
                loadGraphic(Paths.image('pixelUI/' + blahblah + 'ENDS'));
                width = width / 4;
                height = height / 2;
                originalHeightForCalcs = height;
                loadGraphic(Paths.image('pixelUI/' + blahblah + 'ENDS'), true, Math.floor(width), Math.floor(height));
            } else {
                loadGraphic(Paths.image('pixelUI/' + blahblah));
                width = width / 4;
                height = height / 5;
                loadGraphic(Paths.image('pixelUI/' + blahblah), true, Math.floor(width), Math.floor(height));
            }
            setGraphicSize(Std.int(width * PlayState.daPixelZoom));
            loadPixelNoteAnims();
            antialiasing = false;
            if(isSustainNote) {
                offsetX += lastNoteOffsetXForPixelAutoAdjusting;
                lastNoteOffsetXForPixelAutoAdjusting = (width - 7) * (PlayState.daPixelZoom / 2);
                offsetX -= lastNoteOffsetXForPixelAutoAdjusting;
            }
        } else {
            frames = Paths.getSparrowAtlas(blahblah);
            loadNoteAnims();
            antialiasing = ClientPrefs.data.globalAntialiasing;
        }
        if(isSustainNote) scale.y = lastScaleY;
        updateHitbox();
        if(animName != null) animation.play(animName, true);
        if(inEditor) {
            setGraphicSize(ChartingState.GRID_SIZE, ChartingState.GRID_SIZE);
            updateHitbox();
        }
    }

    function loadNoteAnims() {
        var safeNoteData:Int = (noteData >= 0 && noteData < 4) ? noteData : 0;
        animation.addByPrefix(colArray[safeNoteData] + 'Scroll', colArray[safeNoteData] + '0');
        if(isSustainNote) {
            animation.addByPrefix('purpleholdend', 'pruple end hold');
            animation.addByPrefix(colArray[safeNoteData] + 'holdend', colArray[safeNoteData] + ' hold end');
            animation.addByPrefix(colArray[safeNoteData] + 'hold', colArray[safeNoteData] + ' hold piece');
        }
        setGraphicSize(Std.int(width * 0.7));
        updateHitbox();
    }

    function loadPixelNoteAnims() {
        var safeNoteData:Int = (noteData >= 0 && noteData < 4) ? noteData : 0;
        if(isSustainNote) {
            animation.add(colArray[safeNoteData] + 'holdend', [pixelInt[safeNoteData] + 4]);
            animation.add(colArray[safeNoteData] + 'hold', [pixelInt[safeNoteData]]);
        } else {
            animation.add(colArray[safeNoteData] + 'Scroll', [pixelInt[safeNoteData] + 4]);
        }
    }

    public function setupNoteData(chartNoteData:PreloadedChartNote):Void {
        wasGoodHit = false;
        hitByOpponent = false;
        tooLate = false;
        canBeHit = false;

        strumTime = chartNoteData.strumTime;
        noteData = chartNoteData.noteData;
        isSustainNote = chartNoteData.isSustainNote;
        isSustainEnd = chartNoteData.isSustainEnd;

        multSpeed = chartNoteData.multSpeed;
        multAlpha = chartNoteData.multAlpha;
        noteDensity = chartNoteData.noteDensity;
        if(!inEditor) strumTime += ClientPrefs.data.noteOffset;

        active = true;
        offsetX = chartNoteData.offsetX;
        offsetY = chartNoteData.offsetY;
        offsetAngle = 0;
        copyX = true;
        copyY = true;
        copyAngle = true;
        copyAlpha = true;
        flipY = false;
        angle = 0;
        alpha = 1;
        clipRect = null;
        distance = 2000;
        earlyHitMult = 0.5;
        lateHitMult = 1;
        hitsoundDisabled = chartNoteData.hitsoundDisabled;
        lowPriority = false;
        blockHit = false;
        ignoreNote = false;
        hitCausesMiss = false;
        noAnimation = chartNoteData.noAnimation;
        noMissAnimation = chartNoteData.noMissAnimation;
        gfNote = false;
        animSuffix = '';

        x = (ClientPrefs.data.middleScroll ? PlayState.STRUM_X_MIDDLESCROLL : PlayState.STRUM_X) + 50 + Note.swagWidth * noteData;
        y = -2000;

        if(colorSwap == null) {
            colorSwap = new ColorSwap();
            shader = colorSwap.shader;
        }

        var ns:String = chartNoteData.noteskin;
        var tx:String = chartNoteData.texture;
        var targetTexture:String = '';
        if(ns.length > 0) targetTexture = ns;
        else if(tx.length > 0) targetTexture = tx;

        animation.curAnim = null;
        reloadNote('', targetTexture);
        this.texture = targetTexture;

        noteType = chartNoteData.noteType;
        animSuffix = chartNoteData.animSuffix;
        noAnimation = chartNoteData.noAnimation;
        noMissAnimation = chartNoteData.noMissAnimation;
        mustPress = chartNoteData.mustPress;
        doOppStuff = chartNoteData.oppNote;
        gfNote = chartNoteData.gfNote;
        lowPriority = chartNoteData.lowPriority;
        noteSplashDisabled = chartNoteData.noteSplashDisabled;

        if(isSustainNote) {
            parentST = chartNoteData.parentST;
            parentSL = chartNoteData.parentSL;
        }

        hitHealth = chartNoteData.hitHealth;
        missHealth = chartNoteData.missHealth;
        hitCausesMiss = chartNoteData.hitCausesMiss;
        ignoreNote = chartNoteData.ignoreNote;
        blockHit = chartNoteData.blockHit;

        var safeAnimData:Int = (noteData >= 0 && noteData < 4) ? noteData : 0;

        if(isSustainNote) {
            alpha = 0.6;
            multAlpha = 0.6;
            if(!chartNoteData.hitsoundDisabled) hitsoundDisabled = true;
            if(ClientPrefs.data.downScroll) flipY = true;
            offsetX += width / 2;
            copyAngle = false;

            var animToPlay:String = colArray[safeAnimData] + (chartNoteData.isSustainEnd ? 'holdend' : 'hold');
            animation.play(animToPlay);
            updateHitbox();
            offsetX -= width / 2;
            if(PlayState.isPixelStage) offsetX += 30;

            if(!chartNoteData.isSustainEnd) {
                if(PlayState.instance != null) {
                    var stepCrochet:Float = Conductor.stepCrochet;
                    var songSpeedVal:Float = PlayState.instance.songSpeed;
                    scale.y = (stepCrochet / 100) * 1.05 * songSpeedVal * multSpeed;
                    if(PlayState.isPixelStage) {
                        scale.y *= 1.19;
                        scale.y *= (6 / frameHeight);
                    }
                    updateHitbox();
                }
            } else {
                scale.y = 1;
                updateHitbox();
            }
        } else {
            earlyHitMult = 1;
            animation.play(colArray[safeAnimData] + 'Scroll');
            if(!copyAngle) copyAngle = true;
        }
         // Visibility (don't override alpha set above)

        if(PlayState.isPixelStage && isSustainNote) {
                scale.y *= PlayState.daPixelZoom;
                updateHitbox();
        }

        if(!mustPress) visible = ClientPrefs.data.opponentStrums;
        else if(!visible) visible = true;
    }

    inline public function followStrum(strum:StrumNote, songSpeed:Float):Void {
        distance = (0.45 * (Conductor.songPosition - strumTime) * songSpeed * multSpeed);
        if(!strum.downScroll) distance *= -1;

        if(copyAngle) angle = strum.direction - 90 + strum.angle + offsetAngle;
        if(copyAlpha) alpha = strum.alpha * multAlpha;

        if(copyX) x = strum.x + offsetX + Math.cos(strum.direction * Math.PI / 180) * distance;

        if(copyY) {
            y = strum.y + offsetY + Math.sin(strum.direction * Math.PI / 180) * distance;

            if(isSustainNote) {
                var fakeCrochet:Float = (60 / PlayState.SONG.bpm) * 1000;
                var isEnd:Bool = (animation.curAnim != null && (animation.curAnim.name.endsWith('end') || animation.curAnim.name.endsWith('holdend')));

                if(strum.downScroll) {
                    if(isEnd) {
                        y += 10.5 * (fakeCrochet / 400) * 1.5 * songSpeed + (46 * (songSpeed - 1));
                        y -= 46 * (1 - (fakeCrochet / 600)) * songSpeed;
                        if(PlayState.isPixelStage) {
                            y += 8 + (6 - originalHeightForCalcs) * PlayState.daPixelZoom;
                        } else {
                            y -= 19;
                        }
                    }
                    y += (Note.swagWidth / 2) - (60.5 * (songSpeed - 1));
                    y += 27.5 * ((PlayState.SONG.bpm / 100) - 1) * (songSpeed - 1);
                } else {
                    if(PlayState.isPixelStage)
                        y += PlayState.daPixelZoom * 9.5;
                    else
                        y += 55;
                }
            }
        }
    }

    public function clipToStrumNote(myStrum:StrumNote):Void {
        if(!isSustainNote || (!mustPress && ignoreNote) || (mustPress && !wasGoodHit && canBeHit)) return;

        final center:Float = myStrum.y + offsetY + swagWidth / 2;
        if(clipRect == null) clipRect = FlxRect.get(0, 0, frameWidth, frameHeight);
        final swagRect = clipRect;

        if(myStrum.downScroll) {
            if(y - offset.y * scale.y + height >= center) {
                swagRect.height = (center - y) / scale.y;
                swagRect.y = frameHeight - swagRect.height;
                swagRect.width = frameWidth;
            }
        } else {
            if(y + offset.y * scale.y <= center) {
                swagRect.y = (center - y) / scale.y;
                swagRect.height = (height / scale.y) - swagRect.y;
                swagRect.width = width / scale.x;
            }
        }

        @:bypassAccessor clipRect = swagRect;
        @:privateAccess if(frame != null && _frame != null)
            _frame = frame.clipTo(swagRect, _frame);
        dirty = true;
    }

    @:noCompletion
    override function set_clipRect(rect:FlxRect):FlxRect {
        @:bypassAccessor clipRect = rect;
        @:privateAccess if(frame != null) {
            if(rect != null && _frame != null)
                _frame = frame.clipTo(rect, _frame);
            else if(_frame != null)
                _frame = frame.copyTo(_frame);
            dirty = true;
        }
        return rect;
    }

    override function update(elapsed:Float) {
        super.update(elapsed);
        if(isSustainNote && animation.curAnim != null) {
            isSustainEnd = animation.curAnim.name.endsWith('end') || animation.curAnim.name.endsWith('holdend');
        }
        if(mustPress) {
            canBeHit = (strumTime > Conductor.songPosition - (Conductor.safeZoneOffset * lateHitMult)
                && strumTime < Conductor.songPosition + (Conductor.safeZoneOffset * earlyHitMult));
            if(strumTime < Conductor.songPosition - Conductor.safeZoneOffset && !wasGoodHit)
                tooLate = true;
        } else {
            canBeHit = false;
            if(strumTime < Conductor.songPosition + (Conductor.safeZoneOffset * earlyHitMult)) {
                if((isSustainNote && prevNote.wasGoodHit) || strumTime <= Conductor.songPosition)
                    wasGoodHit = true;
            }
        }
        if(tooLate && !inEditor && alpha > 0.3) alpha = 0.3;
    }
}