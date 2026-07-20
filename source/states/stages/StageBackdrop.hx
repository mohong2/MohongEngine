package states.stages;

import flixel.FlxG;
import flixel.FlxBasic;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.group.FlxSpriteGroup;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.math.FlxPoint;
import flixel.math.FlxMath;
import flixel.system.FlxSound;
import flixel.text.FlxText;
import states.PlayState;

/**
 * Base class for stage background handlers.
 * Each built-in stage has its own subclass that manages background
 * sprites, per-frame updates, beat animations, and stage-specific events.
 *
 * All public fields that scripts (Lua/HScript) may reference continue
 * to live on PlayState; the stage handler receives a reference to set
 * them during create().
 */
class StageBackdrop
{
	/** Reference back to the owning PlayState. */
	public var playState(default, null):PlayState;

	/** Internal stage identifier, e.g. "stage", "philly", "tank". */
	public var stageName(default, null):String;

	public function new(playState:PlayState, stageName:String)
	{
		this.playState = playState;
		this.stageName = stageName;
	}

	// ---------------------------------------------------------------
	//  Lifecycle hooks
	// ---------------------------------------------------------------

	/** Create background sprites and add them to the PlayState. */
	public function create():Void {}

	/** Per-frame update (called from PlayState.update). */
	public function update(elapsed:Float):Void {}

	/** Per-beat animation update (called from PlayState.beatHit). */
	public function beatHit():Void {}

	/** Called when the song actually starts playing. */
	public function songStart():Void {}

	/** Called when a relevant event note fires. Return true if handled. */
	public function eventTrigger(eventName:String, value1:String, value2:String):Bool { return false; }

	/** Cleanup. */
	public function destroy():Void {}

	// ---------------------------------------------------------------
	//  Convenience helpers (delegate to PlayState)
	// ---------------------------------------------------------------

	/** Add a FlxBasic to the stage layer (behind GF). */
	public function addBehindGF(obj:FlxObject):Void
	{
		playState.insert(playState.members.indexOf(playState.gfGroup), obj);
	}

	/** Add behind Boyfriend. */
	public function addBehindBF(obj:FlxObject):Void
	{
		playState.insert(playState.members.indexOf(playState.boyfriendGroup), obj);
	}

	/** Add behind Dad. */
	public function addBehindDad(obj:FlxObject):Void
	{
		playState.insert(playState.members.indexOf(playState.dadGroup), obj);
	}

	/** Preload an asset during create(). */
	public function precache(key:String, type:String = 'image'):Void
	{
		playState.precacheList.set(key, type);
	}

	/** Shortcut to add a sprite directly. */
	public function add(obj:FlxBasic):Void
	{
		playState.add(obj);
	}

	/** Shortcut to insert at a specific index. */
	public function insert(pos:Int, obj:FlxBasic):Void
	{
		playState.insert(pos, obj);
	}

	/** Access to camGame. */
	public var camGame(get, never):FlxCamera;
	inline function get_camGame():FlxCamera return playState.camGame;

	/** Access to camHUD. */
	public var camHUD(get, never):FlxCamera;
	inline function get_camHUD():FlxCamera return playState.camHUD;

	/** Access to camOther. */
	public var camOther(get, never):FlxCamera;
	inline function get_camOther():FlxCamera return playState.camOther;
}
