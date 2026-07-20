// ============================================================
// Car Crash Script — SeiunEngine 适配版
// 原版 (hxc) 作者: CamlikesKirby & piggyfriend1792
// 让角色在击中音符时像赛车一样朝对应方向飞出去，
// 撞到"墙"时会播放 crash 音效、震屏并复位。
// ============================================================

import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;

// ═══════════════════════════════════════════════════════════════
//  选项（存 FlxG.save.data）
// ═══════════════════════════════════════════════════════════════

var chaos:Bool = false;         // true = 不取消旧 tween，越打越乱
var boyfriendCar:Bool = true;   // BF 是否参与飞车
var dadCar:Bool = false;        // Dad 是否参与飞车
var focusLikePsych:Bool = false;// 镜头聚焦模式

// ═══════════════════════════════════════════════════════════════
//  内部状态
// ═══════════════════════════════════════════════════════════════

var boyfriendStartX:Float;
var boyfriendStartY:Float;
var boyfriendMaxX:Float;
var boyfriendMaxY:Float;

var dadStartX:Float;
var dadStartY:Float;
var dadMaxX:Float;
var dadMaxY:Float;

var movementBoy:FlxTween = null;
var movementDad:FlxTween = null;

var onFourthBeat:Bool = false;
var currentFocus:Int = 1;

// 防止复位期间重复触发撞墙
var _boyRespawning:Bool = false;
var _dadRespawning:Bool = false;

// ═══════════════════════════════════════════════════════════════
//  初始化
// ═══════════════════════════════════════════════════════════════

function onCreatePost() {
    boyfriendStartX = boyfriend.x;
    boyfriendStartY = boyfriend.y;
    boyfriendMaxX  = boyfriendStartX + 5000;
    boyfriendMaxY  = boyfriendStartY + 5000;

    dadStartX = dad.x;
    dadStartY = dad.y;
    dadMaxX  = dadStartX + 5000;
    dadMaxY  = dadStartY + 5000;

    loadOptions();
}

function onStartCountdown() {
    currentFocus = 1;
    return Function_Continue;
}

// ═══════════════════════════════════════════════════════════════
//  撞墙处理 — 音效 + 震屏 + 平滑复位
// ═══════════════════════════════════════════════════════════════

function _crashBoyfriend() {
    if (_boyRespawning) return;
    _boyRespawning = true;

    if (movementBoy != null) {
        movementBoy.cancel();
        movementBoy = null;
    }

    FlxG.sound.play(Paths.sound('carCrash'), 1);
    FlxG.camera.shake(0.05, 0.5);

    FlxTween.tween(boyfriend, {x: boyfriendStartX, y: boyfriendStartY}, 1.5, {
        ease: FlxEase.expoOut,
        onComplete: function(tween:FlxTween) { _boyRespawning = false; }
    });
}

function _crashDad() {
    if (_dadRespawning) return;
    _dadRespawning = true;

    if (movementDad != null) {
        movementDad.cancel();
        movementDad = null;
    }

    FlxG.sound.play(Paths.sound('carCrash'), 1);
    FlxG.camera.shake(0.05, 0.5);

    FlxTween.tween(dad, {x: dadStartX, y: dadStartY}, 1.5, {
        ease: FlxEase.expoOut,
        onComplete: function(tween:FlxTween) { _dadRespawning = false; }
    });
}

// ═══════════════════════════════════════════════════════════════
//  音符击中 → 朝对应方向弹射（2.5 秒长距飞行）
// ═══════════════════════════════════════════════════════════════

function goodNoteHit(note) {
    if (!boyfriendCar) return;
    if (note.isSustainNote) return;

    // 取消旧飞行（chaos 模式不取消，越堆越疯）
    if (movementBoy != null && !chaos) {
        movementBoy.cancel();
        movementBoy = null;
    }
    _boyRespawning = false;

    switch (note.noteData) {
        case 0: // ← Left
            movementBoy = FlxTween.tween(boyfriend, {x: -1 * boyfriendMaxX}, 2.5,
                {ease: FlxEase.expoIn, onComplete: function(t) { _crashBoyfriend(); }});
        case 1: // ↓ Down
            movementBoy = FlxTween.tween(boyfriend, {y: boyfriendMaxY}, 2.5,
                {ease: FlxEase.expoIn, onComplete: function(t) { _crashBoyfriend(); }});
        case 2: // ↑ Up
            movementBoy = FlxTween.tween(boyfriend, {y: -1 * boyfriendMaxY}, 2.5,
                {ease: FlxEase.expoIn, onComplete: function(t) { _crashBoyfriend(); }});
        case 3: // → Right
            movementBoy = FlxTween.tween(boyfriend, {x: boyfriendMaxX}, 2.5,
                {ease: FlxEase.expoIn, onComplete: function(t) { _crashBoyfriend(); }});
    }

    if (currentFocus == 0 && (onFourthBeat || !focusLikePsych)) {
        camFollow.set(boyfriend.x, boyfriend.y);
    }
}

function opponentNoteHit(note) {
    if (!dadCar) return;
    if (note.isSustainNote) return;

    if (movementDad != null && !chaos) {
        movementDad.cancel();
        movementDad = null;
    }
    _dadRespawning = false;

    switch (note.noteData) {
        case 0:
            movementDad = FlxTween.tween(dad, {x: -1 * dadMaxX}, 2.5,
                {ease: FlxEase.expoIn, onComplete: function(t) { _crashDad(); }});
        case 1:
            movementDad = FlxTween.tween(dad, {y: dadMaxY}, 2.5,
                {ease: FlxEase.expoIn, onComplete: function(t) { _crashDad(); }});
        case 2:
            movementDad = FlxTween.tween(dad, {y: -1 * dadMaxY}, 2.5,
                {ease: FlxEase.expoIn, onComplete: function(t) { _crashDad(); }});
        case 3:
            movementDad = FlxTween.tween(dad, {x: dadMaxX}, 2.5,
                {ease: FlxEase.expoIn, onComplete: function(t) { _crashDad(); }});
    }

    if (currentFocus == 1 && (onFourthBeat || !focusLikePsych)) {
        camFollow.set(dad.x, dad.y);
    }
}

// ═══════════════════════════════════════════════════════════════
//  onUpdate 后备检测（防止 onComplete 因某些原因没触发）
// ═══════════════════════════════════════════════════════════════

function onUpdate(elapsed:Float) {
    if (startedCountdown == false) return;

    if (boyfriendCar && !_boyRespawning) {
        var bf = boyfriend;
        if (bf.x >= boyfriendMaxX || bf.x <= -boyfriendMaxX
            || bf.y >= boyfriendMaxY || bf.y <= -boyfriendMaxY) {
            _crashBoyfriend();
        }
    }

    if (dadCar && !_dadRespawning) {
        var d = dad;
        if (d.x >= dadMaxX || d.x <= -dadMaxX
            || d.y >= dadMaxY || d.y <= -dadMaxY) {
            _crashDad();
        }
    }
}

// ═══════════════════════════════════════════════════════════════
//  节拍
// ═══════════════════════════════════════════════════════════════

function onBeatHit() {
    onFourthBeat = (curBeat % 4 == 0);
}

// ═══════════════════════════════════════════════════════════════
//  暂停时取消所有飞行 tween
// ═══════════════════════════════════════════════════════════════

function onPause() {
    if (movementBoy != null) { movementBoy.cancel(); movementBoy = null; }
    if (movementDad != null) { movementDad.cancel(); movementDad = null; }
    return Function_Continue;
}

// ═══════════════════════════════════════════════════════════════
//  事件 — 追踪 FocusCamera 切换
// ═══════════════════════════════════════════════════════════════

function onEvent(eventName:String, value1:String, value2:String) {
    if (eventName != 'FocusCamera') return;

    var charId:Int = Std.parseInt(value1);
    if (Math.isNaN(charId)) {
        if (value1 == 'bf' || value1 == 'boyfriend')       currentFocus = 0;
        else if (value1 == 'dad' || value1 == 'opponent')  currentFocus = 1;
        else if (value1 == 'gf' || value1 == 'girlfriend') currentFocus = 2;
    } else {
        currentFocus = charId;
    }
}

// ═══════════════════════════════════════════════════════════════
//  选项持久化
// ═══════════════════════════════════════════════════════════════

function loadOptions() {
    var d = FlxG.save.data;
    if (d.car_chaos == null)          d.car_chaos = false;
    if (d.car_boyfriendCar == null)   d.car_boyfriendCar = true;
    if (d.car_dadCar == null)         d.car_dadCar = false;
    if (d.car_focusLikePsych == null) d.car_focusLikePsych = false;

    chaos          = d.car_chaos;
    boyfriendCar   = d.car_boyfriendCar;
    dadCar         = d.car_dadCar;
    focusLikePsych = d.car_focusLikePsych;
}

function saveOptions() {
    var d = FlxG.save.data;
    d.car_chaos          = chaos;
    d.car_boyfriendCar   = boyfriendCar;
    d.car_dadCar         = dadCar;
    d.car_focusLikePsych = focusLikePsych;
    FlxG.save.flush();
}

function setChaos(v:Bool)            { chaos = v; saveOptions(); }
function setBoyfriendCar(v:Bool)     { boyfriendCar = v; saveOptions(); }
function setDadCar(v:Bool)           { dadCar = v; saveOptions(); }
function setFocusLikePsych(v:Bool)   { focusLikePsych = v; saveOptions(); }

function toggleChaos()               { setChaos(!chaos); }
function toggleBoyfriendCar()        { setBoyfriendCar(!boyfriendCar); }
function toggleDadCar()              { setDadCar(!dadCar); }
function toggleFocusLikePsych()      { setFocusLikePsych(!focusLikePsych); }
