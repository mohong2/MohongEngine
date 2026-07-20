package backend;

#if cpp
import mohong.Windows;
#end
import flixel.FlxG;
import Language;

/**
 * Central tracker for editor unsaved changes.
 * Used by Main.hx window.onClose to warn before closing,
 * and by editor states to prompt before exiting or playtesting.
 *
 * 编辑器未保存更改的中央跟踪器。
 * Main.hx 的 window.onClose 用它来关闭前警告，
 * 编辑器状态用它来在退出或测试前弹窗。
 */
class UnsavedChangesTracker
{
    /**
     * Whether any editor currently has unsaved changes.
     * Set to true when changes are made, false after save/discard.
     * 是否有编辑器含有未保存的更改。
     */
    static var _hasUnsavedChanges:Bool = false;
    public static var hasUnsavedChanges(get, set):Bool;
    static function get_hasUnsavedChanges():Bool return _hasUnsavedChanges;
    static function set_hasUnsavedChanges(v:Bool):Bool
    {
        if (_hasUnsavedChanges == v) return v;
        _hasUnsavedChanges = v;
        updateWindowTitle();
        return _hasUnsavedChanges;
    }

    /** Update the window title to show unsaved indicator. */
    static function updateWindowTitle():Void
    {
        #if desktop
        var window = lime.app.Application.current.window;
        if (window == null) return;

        if (originalTitle == null || originalTitle.length == 0)
            originalTitle = window.title;

        var baseTitle:String = originalTitle;
        // Try to strip existing * marker
        if (baseTitle.endsWith(' *'))
            baseTitle = baseTitle.substr(0, baseTitle.length - 2);

        window.title = _hasUnsavedChanges ? '$baseTitle *' : baseTitle;
        #end
    }

    /** Original window title before any modifications. */
    static var originalTitle:String = '';

    /**
     * Reference to the currently active editor state that has unsaved changes.
     * Used to call appropriate save/exit methods.
     * 当前有未保存更改的编辑器状态引用。
     */
    public static var currentEditorState:MusicBeatState = null;

    /**
     * Called by Main.setupWindowCloseHandler() when user clicks X.
     * Returns true if the application should close, false to cancel.
     * 当用户点击X时由 Main 调用。
     * 返回true表示应关闭应用，false取消关闭。
     */
    public static function onWindowQuit():Bool
    {
        if (!hasUnsavedChanges)
            return true; // Allow close

        // Build editor-specific title & message via Language.get()
        var editorKey:String = "Editor";
        if (currentEditorState != null)
        {
            var className:String = Type.getClassName(Type.getClass(currentEditorState));
            editorKey = switch (className)
            {
                case 'editors.NewChartingState': "ChartingStateNew";
                case 'editors.ChartingState': "ChartingState";
                case 'editors.CharacterEditorState': "CharacterEditorState";
                case 'editors.BackgroundEditorState': "BackgroundEditorState";
                case 'editors.WeekEditorState' | 'editors.WeekEditorFreeplayState': "WeekEditorState";
                case 'editors.DialogueEditorState': "DialogueEditorState";
                case 'editors.DialogueCharacterEditorState': "DialogueCharacterEditorState";
                case 'editors.CreditsEditorState': "CreditsEditorState";
                case 'editors.MenuCharacterEditorState': "MenuCharacterEditorState";
                default: "Editor";
            }
        }

        var title:String = Language.get('UnsavedChangesTracker.title',
            'Unsaved Changes');
        var message:String = Language.get('UnsavedChangesTracker.message',
            'You have unsaved changes.\n\nAre you sure you want to quit?\nAll unsaved changes will be lost.');

        // If we know which editor, use the editor-specific key
        var editorTitleKey = 'UnsavedChangesTracker.title.$editorKey';
        var editorMsgKey = 'UnsavedChangesTracker.message.$editorKey';
        if (Language.has(editorTitleKey))
            title = Language.get(editorTitleKey);
        if (Language.has(editorMsgKey))
            message = Language.get(editorMsgKey);

        // Use native Windows dialog (synchronous)
        var confirmed:Bool;
        #if (cpp && !android)
        confirmed = mohong.Windows.showYesNoMessageBox(title, message);
        #else
        confirmed = true;
        #end
        if (confirmed)
        {
            hasUnsavedChanges = false; // Reset so next call allows quit
            return true;
        }
        return false;
    }

    /**
     * Helper for editors: show an exit confirmation substate.
     * 编辑器退出确认弹窗辅助方法。
     */
    public static function createExitPrompt(customMessage:String = null):editors.content.Prompt
    {
        var message:String = customMessage != null
            ? customMessage
            : "There's unsaved progress,\nare you sure you want to exit?";
        return new editors.content.Prompt(message, function()
        {
            hasUnsavedChanges = false;
            FlxG.mouse.visible = false;
            flixel.FlxG.sound.playMusic(Paths.music('freakyMenu'));
        }, 'Exit');
    }
}
