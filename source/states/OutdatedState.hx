package states;

import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;

class OutdatedState extends MusicBeatState
{
	public static var leftState:Bool = false;

	var warnText:FlxText;

	override function create()
	{
		super.create();

		#if LUA_ALLOWED
		initLuaScripts();
		setOnLuas('controls', controls);
		setOnLuas('state', this);
		callOnLuas('onCreatePost', []);
		#end

		var bg:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		add(bg);

		var current:String = MainMenuState.seiunengineVersion;
		var latest:String = TitleState.updateVersion;
		var text:String = Language.get('OutdatedState.text',
			"You are running an outdated version of Seiun Engine ({current}).\nLatest version: {latest}\n\nPress ENTER / A to open the download page.\nPress ESCAPE / B to continue anyway.\n\nThank you for using the Engine!");
		text = StringTools.replace(text, "{current}", current);
		text = StringTools.replace(text, "{latest}", latest);

		warnText = new FlxText(0, 0, FlxG.width, text, 28);
		warnText.setFormat(Paths.languageFont(), 28, FlxColor.WHITE, CENTER);
		warnText.screenCenter(Y);
		add(warnText);

		addVirtualPad(LEFT_FULL, A_B);
	}

	override function update(elapsed:Float)
	{
		if(!leftState) {
			if (controls.ACCEPT) {
				leftState = true;
				CoolUtil.browserLoad("https://github.com/mohong2/FNF-SeiunEngine");
			}
			else if(controls.BACK) {
				leftState = true;
			}

			if(leftState)
			{
				FlxG.sound.play(Paths.sound('cancelMenu'));
				FlxTween.tween(warnText, {alpha: 0}, 1, {
					onComplete: function (twn:FlxTween) {
						MusicBeatState.switchState(new MainMenuState());
					}
				});
			}
		}
		#if HSCRIPT_ALLOWED
		callOnHscript('onUpdate', [elapsed]);
		#end
		super.update(elapsed);
		#if LUA_ALLOWED
		callOnLuas('onUpdatePost', [elapsed]);
		#end
		#if HSCRIPT_ALLOWED
		callOnHscript('onUpdatePost', [elapsed]);
		#end
	}
}
