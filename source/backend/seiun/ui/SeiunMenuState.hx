package backend.seiun.ui;

import backend.MusicBeatState;
import flixel.FlxG;

/**
 * Base class for Seiun Engine menu states.
 *
 * Drives a continuous, music-synced clock (`MenuFX.time` / `MenuFX.beat`)
 * that keeps every menu animation in phase, even across state switches.
 * Subclasses override `onMenuBeat()` to run beat-synced effects.
 */
class SeiunMenuState extends MusicBeatState
{
	var lastMenuBeat:Int = -1;

	override function create()
	{
		Conductor.changeBPM(MenuFX.bpm);
		MenuFX.baseZoom = FlxG.camera.zoom;
		super.create();
	}

	override function update(elapsed:Float)
	{
		MenuFX.time += elapsed;
		if (MenuFX.menuMusicActive && FlxG.sound.music != null && FlxG.sound.music.playing)
			Conductor.songPosition = FlxG.sound.music.time;

		super.update(elapsed);

		if (MenuFX.beat != lastMenuBeat)
		{
			lastMenuBeat = MenuFX.beat;
			onMenuBeat(MenuFX.beat);
		}
	}

	override function beatHit()
	{
		super.beatHit();
		MenuFX.beat = curBeat;
	}

	/** Called once per musical beat of the menu music. */
	function onMenuBeat(beat:Int):Void {}
}
