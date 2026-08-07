package backend;

/*
 * Cross-platform wrapper for the Android floating keyboard button
 * (SeiunOverlay Java extension, registered in Project.xml).
 *
 * On Android this talks to org.haxe.extension.SeiunOverlay over JNI. The
 * overlay is a single draggable keyboard button using
 * WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY (the modern Android
 * 8.0+/API 26+ rounded overlay window class) with a TYPE_PHONE fallback
 * for API 21-25. Tapping it toggles the system soft keyboard.
 *
 * On every other platform every call is a harmless no-op so mods can use
 * this API unconditionally.
 */
#if android
import lime.system.JNI;
#end

class SeiunOverlay
{
	/** Show the floating keyboard button (if overlay permission is granted). */
	public static function show():Void
	{
		#if android
		show_jni();
		#end
	}

	/** Show the floating button at an absolute position (px). */
	public static function showAt(x:Int, y:Int):Void
	{
		#if android
		showAt_jni(x, y);
		#end
	}

	/** Hide the floating button. */
	public static function hide():Void
	{
		#if android
		hide_jni();
		#end
	}

	public static function isShowing():Bool
	{
		#if android
		return isShowing_jni();
		#else
		return false;
		#end
	}

	/** Toggle the system soft keyboard (used by the floating button). */
	public static function toggleKeyboard():Void
	{
		#if android
		toggleKeyboard_jni();
		#end
	}

	public static function showKeyboard():Void
	{
		#if android
		showKeyboard_jni();
		#end
	}

	public static function dismissKeyboard():Void
	{
		#if android
		dismissKeyboard_jni();
		#end
	}

	/** Whether "Display over other apps" (SYSTEM_ALERT_WINDOW) is granted. */
	public static function isOverlayPermissionGranted():Bool
	{
		#if android
		return isOverlayPermissionGranted_jni();
		#else
		return true;
		#end
	}

	/** Open the system settings page where the user can grant the permission. */
	public static function requestOverlayPermission():Void
	{
		#if android
		requestOverlayPermission_jni();
		#end
	}

	/** Auto-show the button on game start. Defaults to true. */
	public static function setAutoShow(value:Bool):Void
	{
		#if android
		setAutoShow_jni(value);
		#end
	}

	public static function getAutoShow():Bool
	{
		#if android
		return getAutoShow_jni();
		#else
		return false;
		#end
	}

	/** Master switch for the overlay (persisted). */
	public static function setEnabled(value:Bool):Void
	{
		#if android
		setEnabled_jni(value);
		#end
	}

	public static function getEnabled():Bool
	{
		#if android
		return getEnabled_jni();
		#else
		return false;
		#end
	}

	/** Copy text into the system clipboard. Returns true on success. */
	public static function setClipboardText(text:String):Bool
	{
		#if android
		return setClipboardText_jni(text);
		#elseif desktop
		try
		{
			openfl.desktop.Clipboard.generalClipboard.setData(
				openfl.desktop.ClipboardFormats.TEXT_FORMAT, text);
			return true;
		}
		catch (e:Dynamic)
		{
			return false;
		}
		#else
		return false;
		#end
	}

	/** Show automatically at startup when enabled + permission granted. */
	public static function maybeAutoShow():Void
	{
		#if android
		maybeAutoShow_jni();
		#end
	}

	#if android
	@:noCompletion
	private static var show_jni:Dynamic = JNI.createStaticMethod('org/haxe/extension/SeiunOverlay', 'show', '()V');

	@:noCompletion
	private static var showAt_jni:Dynamic = JNI.createStaticMethod('org/haxe/extension/SeiunOverlay', 'showAt', '(II)V');

	@:noCompletion
	private static var hide_jni:Dynamic = JNI.createStaticMethod('org/haxe/extension/SeiunOverlay', 'hide', '()V');

	@:noCompletion
	private static var isShowing_jni:Dynamic = JNI.createStaticMethod('org/haxe/extension/SeiunOverlay', 'isShowing', '()Z');

	@:noCompletion
	private static var toggleKeyboard_jni:Dynamic = JNI.createStaticMethod('org/haxe/extension/SeiunOverlay', 'toggleKeyboard', '()V');

	@:noCompletion
	private static var showKeyboard_jni:Dynamic = JNI.createStaticMethod('org/haxe/extension/SeiunOverlay', 'showKeyboard', '()V');

	@:noCompletion
	private static var dismissKeyboard_jni:Dynamic = JNI.createStaticMethod('org/haxe/extension/SeiunOverlay', 'dismissKeyboard', '()V');

	@:noCompletion
	private static var isOverlayPermissionGranted_jni:Dynamic = JNI.createStaticMethod('org/haxe/extension/SeiunOverlay', 'isOverlayPermissionGranted', '()Z');

	@:noCompletion
	private static var requestOverlayPermission_jni:Dynamic = JNI.createStaticMethod('org/haxe/extension/SeiunOverlay', 'requestOverlayPermission', '()V');

	@:noCompletion
	private static var setAutoShow_jni:Dynamic = JNI.createStaticMethod('org/haxe/extension/SeiunOverlay', 'setAutoShow', '(Z)V');

	@:noCompletion
	private static var getAutoShow_jni:Dynamic = JNI.createStaticMethod('org/haxe/extension/SeiunOverlay', 'getAutoShow', '()Z');

	@:noCompletion
	private static var setEnabled_jni:Dynamic = JNI.createStaticMethod('org/haxe/extension/SeiunOverlay', 'setEnabled', '(Z)V');

	@:noCompletion
	private static var getEnabled_jni:Dynamic = JNI.createStaticMethod('org/haxe/extension/SeiunOverlay', 'getEnabled', '()Z');

	@:noCompletion
	private static var setClipboardText_jni:Dynamic = JNI.createStaticMethod('org/haxe/extension/SeiunOverlay', 'setClipboardText', '(Ljava/lang/String;)Z');

	@:noCompletion
	private static var maybeAutoShow_jni:Dynamic = JNI.createStaticMethod('org/haxe/extension/SeiunOverlay', 'maybeAutoShow', '()V');
	#end
}
