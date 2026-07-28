/**
 * Window Byebye Script — SeiunEngine 适配版
 * 原版作者: Ina The Cat
 *
 * 当游戏结束时，取消标准 Game Over，删除所有音符，让窗口缩小、掉落、
 * 然后滑出屏幕并退出。
 */

import sys.io.Process;

var canFall:Bool = false;
var fell:Bool = false;
var leaving:Bool = false;
var uDed:Bool = false;
var velY:Float = 0;
var gravity:Float = 800;
var screenW:Float = 0;
var screenH:Float = 0;

function onCreatePost() {
    var w = Application.current.window;
    if (w.maximized || w.fullscreen) return;

    FlxG.resizeWindow(1280, 720);
    screenW = w.display.bounds.width;
    screenH = w.display.bounds.height;
    w.move(
        Std.int((screenW - w.width) / 2),
        Std.int((screenH - w.height) / 2)
    );
}

function onUpdate(elapsed:Float) {
    if (!canFall && !leaving) return;

    var w = Application.current.window;

    if (leaving) {
        w.x -= 1;
        if (w.y >= screenH - w.height)
            velY = -350;
        if (w.x <= -w.width)
            Sys.exit(0);
    }

    if (canFall) {
        velY += gravity * elapsed;
        w.y += velY * elapsed * 1.5;

        if (w.y >= screenH - w.height) {
            w.y = screenH - w.height;
            velY = 0;

            if (fell) return;
            justFell();
        }
    }
}

function onGameOver() {
    if (uDed) return Function_Continue;
    uDed = true;

    notes.forEachAlive(function(note) note.kill());
    for (n in unspawnNotes) {
        if (n != null && n.exists) n.kill();
    }

    FlxTween.num(0, 1, 0.5, {onComplete: function(_) {
        notes.forEachAlive(function(note) note.kill());
    }});

    FlxG.sound.music.volume = 0;
    if (vocals != null) vocals.volume = 0;

    bye();
    return Function_Stop;
}

function justFell() {
    fell = true;
    FlxTween.num(0, 1, 0.5, {onComplete: function(_) {
        leaving = true;
        windowsNotification('The gameplay is ass', 'so ass than the window started leaving');
    }});
}

function bye() {
    var w = Application.current.window;
    if (w == null) { canFall = true; return; }

    if (w.fullscreen) w.fullscreen = false;
    if (w.maximized) w.maximized = false;

    var halfW:Float = 1280 / 2;
    var halfH:Float = 720 / 2;
    w.resize(Std.int(halfW), Std.int(halfH));
    w.move(
        Std.int((screenW - halfW) / 2),
        Std.int((screenH - halfH) / 2)
    );
    w.resizable = false;

    FlxTween.num(0, 1, 0.35, {onComplete: function(_) {
        canFall = true;
    }});
}

function windowsNotification(title:String, desc:String) {
    #if windows
    var powershellCommand = "powershell -Command \"& {$ErrorActionPreference = 'Stop';"
        + "$title = '"
        + desc
        + "';"
        + "[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null;"
        + "$template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText01);"
        + "$toastXml = [xml] $template.GetXml();"
        + "$toastXml.GetElementsByTagName('text').AppendChild($toastXml.CreateTextNode($title)) > $null;"
        + "$xml = New-Object Windows.Data.Xml.Dom.XmlDocument;"
        + "$xml.LoadXml($toastXml.OuterXml);"
        + "$toast = [Windows.UI.Notifications.ToastNotification]::new($xml);"
        + "$toast.Tag = 'Test1';"
        + "$toast.Group = 'Test2';"
        + "$notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('"
        + title
        + "');"
        + "$notifier.Show($toast);}\"";

    if (title != null && title != "" && desc != null && desc != "")
        new Process(powershellCommand);
    #end
}
