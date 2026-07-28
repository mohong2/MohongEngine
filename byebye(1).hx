/**
 * ive been doing ts for like, 2-3 hours js for this fucking thang? hell nah
 * - Ina The Cat
**/

import openfl.system.Capabilities;
import sys.io.Process;

var canFall:Bool = false;
var fell:Bool = false;
var leaving:Bool = false;

var uDed:Bool = false;
var lastTime:Float = 0;

function create() {
    // introLength = 0;

    if (window.maximized || window.fullscreen) return;

    FlxG.resizeWindow(1280, 720);
    window.move(
        Std.int(Capabilities.screenResolutionX - window.width) / 2,
        Std.int(Capabilities.screenResolutionY - window.height) / 2
    );
}

var velY:Float = 0;
var gravity:Float = 800;

function update(elapsed:Float) {
    if (leaving){
        window.x -= 1;

        if (window.y >= Capabilities.screenResolutionY - window.height)
        	velY = -350;

        if (window.x <= -window.width)
            Sys.exit(0);
    }

    if (canFall){
    	velY += gravity * elapsed;

    	window.y += velY * elapsed * 1.5;

	    if (window.y >= Capabilities.screenResolutionY - window.height){
	    	window.y = Capabilities.screenResolutionY - window.height;
	    	velY = 0;

            if (fell) return;

            justFell();
	    }
    }
}

function onGameOver(e) {
    e.cancel();

    if (uDed) return;

    uDed = true;

    for (i in 0...strumLines.members.length)
        strumLines.members[i].notes.forEach((e:Note) -> deleteNote(e))

    FlxTimer().start(0.5, () -> 
        for (i in 0...strumLines.members.length)
            strumLines.members[i].notes.forEach((e:Note) -> deleteNote(e))
    , 0);

    FlxG.sound?.music?.volume = 0;
    inst?.volume = 0;
    for (e in strumLines)
        if (e.vocals != null)
            e.vocals.volume = 0;

    bye();
}

function justFell() {
    fell = true;

    FlxTimer().start(0.5, () -> {
        leaving = true;
        windowsNotification('The gameplay is ass', 'so ass than the window started leaving');
    });
}

function bye() {
    if (window.fullscreen)
        window.fullscreen = false;

    if (window.maximized)
        window.maximized = false;

    FlxTween.tween(window, {width: 1280 / 2, height: 720 / 2}, 0.35, {ease: FlxEase.sineOut, onUpdate: () ->
        window.move(
            Std.int(Capabilities.screenResolutionX - window.width) / 2,
            Std.int(Capabilities.screenResolutionY - window.height) / 2
        )
    , onComplete: () -> canFall = true});

    window.resizable = false;
}

function windowsNotification(title:String, desc:String) {
	#if windows
	final powershellCommand = "powershell -Command \"& {$ErrorActionPreference = 'Stop';"
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