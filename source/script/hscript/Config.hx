package script.hscript;

import crowplexus.iris.Iris;
import flixel.group.FlxGroup;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import flixel.util.FlxSave;
import states.LoadingState;
import states.TitleState;
import states.MainMenuState;
import options.OptionsState;
import WeekData;
import Language;

/**
 * HScript parser/interpreter configuration, modeled after Codename Engine's approach.
 *
 * Controls which packages scripts can access and which parser features are enabled.
 */
class Config
{
	/** Packages prefixes where `import` of custom classes is allowed. */
	public static final ALLOWED_CUSTOM_CLASSES:Array<String> = [
		#if !DOCUMENTATION
		"flixel",
		"openfl",
		"lime",
		"haxe",
		"script",
		"states",
		"substates",
		"backend",
		"options",
		"editors",
		"mohong",
		#if MODCHARTING_FEATURES
		"modchart",
		#end
		#end
	];

	/** Package prefixes where abstract types and enums are resolved. */
	public static final ALLOWED_ABSTRACT_AND_ENUM:Array<String> = [
		#if !DOCUMENTATION
		"flixel",
		"openfl",
		"lime",
		"haxe",
		"haxe.xml",
		"haxe.CallStack",
		"script",
		"states",
		"substates",
		"backend",
		#end
	];

	/** Specific module names that are disallowed for import. */
	public static final DISALLOW_CUSTOM_CLASSES:Array<String> = [
		// Add any problematic modules here
	];

	/** Specific module names disallowed for abstract/enum access. */
	public static final DISALLOW_ABSTRACT_AND_ENUM:Array<String> = [
		// Add any problematic modules here
	];

	/**
	 * Apply this configuration to the Iris blocklist so that
	 * disallowed imports are rejected at runtime.
	 */
	public static function applyBlocklist():Void {
		for (name in DISALLOW_CUSTOM_CLASSES) {
			if (!Iris.blocklistImports.contains(name))
				Iris.blocklistImports.push(name);
		}
	}

	/**
	 * Check whether a given package path is allowed for custom class import.
	 * Always returns true — no package restrictions.
	 */
	public static function isPackageAllowed(pack:String):Bool {
		return true;
	}

	/**
	 * Check whether a given package path is allowed for abstract/enum access.
	 */
	public static function isAbstractAllowed(pack:String):Bool {
		for (prefix in ALLOWED_ABSTRACT_AND_ENUM) {
			if (pack.startsWith(prefix)) return true;
		}
		return false;
	}
}
