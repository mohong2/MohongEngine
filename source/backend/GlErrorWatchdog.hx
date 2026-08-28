package backend;

import flixel.FlxG;
import lime.graphics.opengl.GL;
import openfl.events.Event;
import mohong.TraceManager;

/**
 * GlErrorWatchdog - polls glGetError() on render frames (Event.RENDER runs on
 * the main thread with a valid GL context, so it never races the update timer)
 * and logs any error into the TraceManager ring buffer. Renderer faults then
 * show up in the crash report's "Recent Game Log" instead of dying silently.
 */
class GlErrorWatchdog
{
	public static var enabled:Bool = true;
	public static var pollInterval:Float = 0.5;
	public static var maxErrorsPerPoll:Int = 8;
	/** Repeat errors of the same kind are only logged once per this many seconds. */
	public static var repeatLogCooldown:Float = 10;

	public static var errorCount:Int = 0;
	public static var lastErrorCode:Int = 0;
	public static var lastName:String = '';
	public static var lastErrorAt:Float = 0;

	static var installed:Bool = false;
	static var nextPollAt:Float = 0;
	static var lastLoggedCode:Int = -1;
	static var lastLoggedAt:Float = 0;

	/** Idempotent: hook the stage render event; safe to call at any time. */
	public static function install():Void
	{
		if (installed) return;
		installed = true;

		try
		{
			var stage = FlxG.stage;
			if (stage == null) return;
			stage.addEventListener(Event.RENDER, onStageRender);
		}
		catch (e:Dynamic) {}
	}

	static function onStageRender(_):Void
	{
		if (!enabled) return;

		var now:Float = haxe.Timer.stamp();
		if (now < nextPollAt) return;
		nextPollAt = now + pollInterval;

		pollNow(true);
	}

	/** Immediate poll (e.g. from the crash handler, main thread). Returns the latest error code. */
	public static function pollNow(logIt:Bool = true):Int
	{
		try
		{
			var ctx = FlxG.stage != null ? FlxG.stage.context3D : null;
			if (ctx == null) return lastErrorCode;
			if (GL.context == null) return lastErrorCode;

			var found:Int = 0;
			while (found < maxErrorsPerPoll)
			{
				var code:Int = GL.getError();
				if (code == GL.NO_ERROR) break;

				found++;
				errorCount++;
				lastErrorCode = code;
				lastName = errorName(code);
				lastErrorAt = haxe.Timer.stamp();

				if (logIt)
					logError(code);
			}
		}
		catch (e:Dynamic)
		{
			// never re-throw from the watchdog
		}
		return lastErrorCode;
	}

	static function logError(code:Int):Void
	{
		var now:Float = haxe.Timer.stamp();
		if (code == lastLoggedCode && now - lastLoggedAt < repeatLogCooldown)
			return; // quiet repeats of the same error

		lastLoggedCode = code;
		lastLoggedAt = now;

		TraceManager.error('trace.gl.error',
			'GL error #{}: {} (0x{})', [errorCount, lastName, StringTools.hex(code)]);
		if (code == GL.OUT_OF_MEMORY || code == GL.CONTEXT_LOST_WEBGL)
			TraceManager.error('trace.gl.fatal',
				'GL fatal condition: {} — renderer device may be lost/reset', [lastName]);
	}

	/** One-line summary used by SystemDiag and the heartbeat. */
	public static function snapshot():String
	{
		if (errorCount == 0)
			return 'none (errors polled: 0)';

		var time = '?';
		if (lastErrorAt > 0)
		{
			var d:Date = Date.fromTime(lastErrorAt * 1000);
			time = Std.string(d.getHours()) + ':' + Std.string(d.getMinutes()) + ':' + Std.string(d.getSeconds());
		}
		return 'last=' + lastName + ' (0x' + StringTools.hex(lastErrorCode) + ')'
			+ ' count=' + Std.string(errorCount)
			+ ' at=' + time;
	}

	static function errorName(code:Int):String
	{
		return switch (code)
		{
			case 0: 'GL_NO_ERROR';
			case 0x0500: 'GL_INVALID_ENUM';
			case 0x0501: 'GL_INVALID_VALUE';
			case 0x0502: 'GL_INVALID_OPERATION';
			case 0x0505: 'GL_OUT_OF_MEMORY';
			case 0x0506: 'GL_INVALID_FRAMEBUFFER_OPERATION';
			case 0x9242: 'GL_CONTEXT_LOST_WEBGL';
			default: StringTools.hex(code);
		}
	}
}
