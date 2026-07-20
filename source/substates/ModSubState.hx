package substates;

import backend.MusicBeatSubstate;
import flixel.FlxSubState;
import mohong.TraceManager;

/**
 * Scriptable substate — loads an HScript/Lua file from `data/states/<name>`.
 *
 * Modeled after Codename Engine's ModSubState.
 */
class ModSubState extends MusicBeatSubstate
{
	public static var lastName:String = null;
	public static var lastData:Dynamic = null;
	public var data:Dynamic = null;

	public function new(_stateName:String, ?_data:Dynamic) {
		if (_stateName != null && _stateName != lastName) {
			lastName = _stateName;
			lastData = null;
		}
		if (_data != null) lastData = _data;
		this.data = lastData;
		super(lastName);
	}

	/**
	 * Check whether the active mod wants to replace an already-instantiated
	 * FlxSubState with a ModSubState.
	 */
	public static function resolveSubState(original:FlxSubState):FlxSubState {
		#if MODS_ALLOWED
		var reps = states.ModState.substateReplacements;
		if (reps == null || !reps.keys().hasNext()) return original;

		var cls = Type.getClassName(Type.getClass(original));
		var simple = cls.substr(cls.lastIndexOf('.') + 1);

		if (reps.exists(simple)) {
			TraceManager.info('trace.modSubState.replace', 'Replacing {} with ModSubState({})', [simple, reps[simple]]);
			return new ModSubState(reps[simple]);
		}
		#end
		return original;
	}

	override function create() {
		super.create();
		// MusicBeatSubstate.create() already handles initHScripts + initLuaScripts,
		// we only need to set the extra `data` variable.
		setOnHscript('data', this.data);
		setOnLuas('data', this.data);
	}
}
