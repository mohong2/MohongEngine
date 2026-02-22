package states;


import flixel.effects.FlxFlicker;
import flixel.addons.transition.FlxTransitionableState;

class FlashingState extends ScriptState
{
	public static var leftState:Bool = false;
	public static var instance:FlashingState;
	var warnText:FlxText;
	override function create()
	{
		instance = this;
		super.create();

		var bg:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		add(bg);


		warnText = new FlxText(0, 100, FlxG.width,
		"嘿，看这,这个Mod可能有亿点点闪光特效，眼睛瞎了别找作者\n
		按空格键当做没看到这条警告，别怪我没提醒你，瞎了概不负责\n
		Hey, watch out!\n
		This Mod contains some flashing lights!\n
		Press ENTER to disable them now or go to Options Menu.\n
		Press ESCAPE to ignore this message.\n
		You've been warned!",
		32);
		warnText.setFormat(32, FlxColor.WHITE, CENTER);
		warnText.font = Paths.languageFont(); 
		warnText.screenCenter(Y);
		add(warnText);
		#if android
		addVirtualPad(NONE, A_B);
		#end
}

	override function update(elapsed:Float)
	{
		if(!leftState) {
			var back:Bool = controls.BACK;
			if (controls.ACCEPT || back) {
				leftState = true;
				FlxTransitionableState.skipNextTransIn = true;
				FlxTransitionableState.skipNextTransOut = true;
				if(!back) {
					ClientPrefs.data.flashing = false;
					ClientPrefs.saveSettings();
					FlxG.sound.play(Paths.sound('confirmMenu'));
					FlxFlicker.flicker(warnText, 1, 0.1, false, true, function(flk:FlxFlicker) {
						new FlxTimer().start(0.5, function (tmr:FlxTimer) {
							MusicBeatState.switchState(new TitleState());
						});
					});
				} else {
					FlxG.sound.play(Paths.sound('cancelMenu'));
					FlxTween.tween(warnText, {alpha: 0}, 1, {
						onComplete: function (twn:FlxTween) {
							MusicBeatState.switchState(new TitleState());
						}
					});
				}
			}
		}
		super.update(elapsed);
	}
	override function destroy() {
		instance = null;
		super.destroy();
	}
}
