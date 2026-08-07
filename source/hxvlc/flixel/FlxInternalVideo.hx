package hxvlc.flixel;

#if flixel
import flixel.FlxG;

import haxe.io.Bytes;
import haxe.io.Path;

import hxvlc.externs.Types;
import hxvlc.openfl.Video;
import hxvlc.util.Location;
import hxvlc.util.Util;
import hxvlc.util.macros.DefineMacro;

import openfl.utils.Assets;

import sys.FileSystem;

using StringTools;

/**
 * A wrapper class for displaying video files in HaxeFlixel using the `Video` class.
 */
class FlxInternalVideo extends Video
{
	/** The volume adjustment. */
	public var volumeAdjust(default, set):Float = 1.0;

	// ------------------------------------------------------------------
	// SeiunEngine: global instance tracking + cleanup safety net.
	//
	// Mods frequently create video objects through Lua/HScript and never
	// dispose them (e.g. `new MP4Handler()` + `playVideo()` with no
	// onDestroy hook). Every such instance keeps a libVLC media player
	// decoding frames (forceRendering), so one leaked video per level
	// entry quickly tanks the framerate.
	//
	// We register every FlxInternalVideo on construction and remove it on
	// dispose. `disposeAll()` is called by PlayState.destroy() as a safety
	// net so no video survives a level switch.
	// ------------------------------------------------------------------

	static var _instances:Array<FlxInternalVideo> = [];

	@:noCompletion private var _disposed:Bool = false;

	/** Dispose every still-alive video instance (idempotent). */
	public static function disposeAll():Void
	{
		if (_instances.length == 0)
			return;

		var copy:Array<FlxInternalVideo> = _instances.copy();
		for (video in copy)
		{
			if (video != null)
			{
				try
				{
					video.dispose();
				}
				catch (e:Dynamic)
				{
					// Never let a leaked video take down the level switch.
				}
			}
		}
	}

	/** Number of live (not yet disposed) video instances - for diagnostics. */
	public static function getLiveCount():Int
	{
		return _instances.length;
	}

	@:noCompletion
	private var resumeOnFocus:Bool = false;

	@:inheritDoc(hxvlc.openfl.Video.new)
	public function new(smoothing:Bool = true):Void
	{
		super(smoothing);

		_disposed = false;
		_instances.push(this);

		onOpening.add(function():Void
		{
			role = LibVLC_Role_Game;
		});
	}

	@:inheritDoc(hxvlc.openfl.Video.load)
	public override function load(location:Location, ?options:Array<String>):Bool
	{
		if (location != null && !(location is Int) && !(location is Bytes) && (location is String))
		{
			final location:String = cast(location, String);

			if (!Video.URL_VERIFICATION_REGEX.match(location))
			{
				final absolutePath:String = FileSystem.absolutePath(location);

				if (FileSystem.exists(absolutePath))
					return loadInternal(absolutePath, options);
				else if (Assets.exists(location))
				{
					final assetPath:Null<String> = Assets.getPath(location);

					if (assetPath != null)
					{
						if (FileSystem.exists(assetPath) && Path.isAbsolute(assetPath))
							return loadInternal(assetPath, options);
						else if (FileSystem.exists(assetPath) && !Path.isAbsolute(assetPath))
							return loadInternal(FileSystem.absolutePath(assetPath), options);
						else if (!Path.isAbsolute(assetPath))
						{
							try
							{
								final assetBytes:Bytes = Assets.getBytes(location);

								if (assetBytes != null)
									return loadInternal(assetBytes, options);
							}
							catch (e:Dynamic)
							{
								FlxG.log.error('Error loading asset bytes from location "$location": $e');

								return false;
							}
						}
					}

					return false;
				}
				else
				{
					FlxG.log.warn('Unable to find the video file at location "$location".');

					return false;
				}
			}
		}

		return loadInternal(location, options);
	}

	@:inheritDoc(hxvlc.openfl.Video.addSlave)
	public override function addSlave(type:Int, location:String, select:Bool):Bool
	{
		if (!Video.URL_VERIFICATION_REGEX.match(location))
		{
			final absolutePath:String = FileSystem.absolutePath(location);

			if (FileSystem.exists(absolutePath))
				return super.addSlave(type, Util.convertAbsToURL(absolutePath), select);
			else if (Assets.exists(location))
			{
				final assetPath:Null<String> = Assets.getPath(location);

				if (assetPath != null)
				{
					if (FileSystem.exists(assetPath) && Path.isAbsolute(assetPath))
						return super.addSlave(type, Util.convertAbsToURL(assetPath), select);
					else if (FileSystem.exists(assetPath) && !Path.isAbsolute(assetPath))
						return super.addSlave(type, FileSystem.absolutePath(assetPath), select);
				}

				return false;
			}
		}

		return super.addSlave(type, location, select);
	}

	@:inheritDoc(hxvlc.openfl.Video.dispose)
	public override function dispose():Void
	{
		if (_disposed)
			return;
		_disposed = true;

		_instances.remove(this);

		if (FlxG.signals.focusGained.has(onFocusGained))
			FlxG.signals.focusGained.remove(onFocusGained);

		if (FlxG.signals.focusLost.has(onFocusLost))
			FlxG.signals.focusLost.remove(onFocusLost);

		#if (FLX_SOUND_SYSTEM && flixel >= version("5.9.0"))
		if (FlxG.sound.onVolumeChange.has(onVolumeChange))
			FlxG.sound.onVolumeChange.remove(onVolumeChange);
		#elseif (FLX_SOUND_SYSTEM && flixel < version("5.9.0"))
		if (FlxG.signals.postUpdate.has(onVolumeUpdate))
			FlxG.signals.postUpdate.remove(onVolumeUpdate);
		#end

		super.dispose();
	}

	@:noCompletion
	private function loadInternal(location:Location, ?options:Array<String>):Bool
	{
		final loaded:Bool = super.load(location, options);

		if (loaded)
		{
			if (!FlxG.signals.focusGained.has(onFocusGained))
				FlxG.signals.focusGained.add(onFocusGained);

			if (!FlxG.signals.focusLost.has(onFocusLost))
				FlxG.signals.focusLost.add(onFocusLost);

			#if (FLX_SOUND_SYSTEM && flixel >= version("5.9.0"))
			if (!FlxG.sound.onVolumeChange.has(onVolumeChange))
				FlxG.sound.onVolumeChange.add(onVolumeChange);
			#elseif (FLX_SOUND_SYSTEM && flixel < version("5.9.0"))
			if (!FlxG.signals.postUpdate.has(onVolumeUpdate))
				FlxG.signals.postUpdate.add(onVolumeUpdate);
			#end

			onVolumeChange(#if FLX_SOUND_SYSTEM (FlxG.sound.muted ? 0 : 1) * FlxG.sound.volume #else 1 #end);
		}

		return loaded;
	}

	@:noCompletion
	private function onFocusGained():Void
	{
		#if !mobile
		if (!FlxG.autoPause)
			return;
		#end

		if (resumeOnFocus)
		{
			resumeOnFocus = false;

			resume();
		}
	}

	@:noCompletion
	private function onFocusLost():Void
	{
		#if !mobile
		if (!FlxG.autoPause)
			return;
		#end

		resumeOnFocus = isPlaying;

		pause();
	}

	#if (FLX_SOUND_SYSTEM && flixel < version("5.9.0"))
	@:noCompletion
	private function onVolumeUpdate():Void
	{
		onVolumeChange(#if FLX_SOUND_SYSTEM (FlxG.sound.muted ? 0 : 1) * FlxG.sound.volume #else 1 #end);
	}
	#end

	@:noCompletion
	private function onVolumeChange(vol:Float):Void
	{
		final currentVolume:Int = Math.floor((vol * DefineMacro.getFloat('HXVLC_FLIXEL_VOLUME_MULTIPLIER', 125)) * volumeAdjust);

		if (volume != currentVolume)
			volume = currentVolume;
	}

	@:noCompletion
	private function set_volumeAdjust(value:Float):Float
	{
		onVolumeChange(#if FLX_SOUND_SYSTEM (FlxG.sound.muted ? 0 : 1) * FlxG.sound.volume #else 1 #end);

		return volumeAdjust = value;
	}
}
#end
