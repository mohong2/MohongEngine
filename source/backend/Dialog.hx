package backend;

import haxe.CallStack;
import haxe.Exception;

#if (cpp && !android)
import mohong.Windows;
import mohong.Windows.DialogType;
#elseif android
import android.Tools as AndroidTools;
#end

#if !(cpp && !android)
enum abstract DialogType(Int) {
    var Info = 0;
    var Warning = 1;
    var Error = 2;
}
#end

/**
 * Cross-platform dialog base class.
 * 跨平台弹窗基类。
 *
 * Example / 示例:
 * ```
 * Dialog.show("Title", "Message");
 * Dialog.show("Title", "Message", DialogType.Warning);
 * Dialog.showYesNo("Confirm", "Are you sure?", function() trace("Yes"), function() trace("No"));
 * ```
 */
class Dialog
{
    /**
     * Show a simple OK dialog.
     * 显示简单的确定弹窗。
     * @param title Dialog title / 弹窗标题
     * @param message Dialog content / 弹窗内容
     * @param type Dialog type (Info/Warning/Error, Windows only) / 弹窗类型（仅Windows有效）
     */
    public static function show(title:String, message:String, type:String = 'Info'):Void
    {
        #if (cpp && !android)
        var dialogType:DialogType = DialogType.Info;
        switch(type) {
            case 'Info':
                dialogType = DialogType.Info;
            case 'Warning':
                dialogType = DialogType.Warning;
            case 'Error':
                dialogType = DialogType.Error;
        }

        Windows.showDialog(title, message, dialogType);
        #elseif android
        AndroidTools.showNativeAlertDialog(title, message, {name: "OK", func: null}, null, null, false);
        #else
        lime.app.Application.current.window.alert(message, title);
        #end
    }

    /**
     * Show a Yes/No confirmation dialog.
     * 显示是/否确认弹窗。
     * @param title Dialog title / 弹窗标题
     * @param message Dialog content / 弹窗内容
     * @param onYes Callback when Yes is clicked / 点击"是"时的回调
     * @param onNo Callback when No is clicked / 点击"否"时的回调
     */
    public static function showYesNo(title:String, message:String, onYes:Void->Void, onNo:Void->Void):Void
    {
        #if (cpp && !android)
        // Windows uses TaskDialog/MessageBox - we need a custom approach
        showYesNoWindows(title, message, onYes, onNo);
        #elseif android
        AndroidTools.showNativeAlertDialog(title, message,
            {name: "Yes", func: onYes},
            {name: "No", func: onNo}, null, false);
        #else
        // Fallback using native confirm
        #if js
        if (js.html.Window.confirm('$title\n\n$message')) onYes(); else onNo();
        #else
        lime.app.Application.current.window.alert(message + "\n\n(Yes/No not supported, using OK)", title);
        onYes();
        #end
        #end
    }

    /**
     * Show a dialog with custom buttons.
     * 显示带自定义按钮的弹窗。
     * @param title Dialog title / 弹窗标题
     * @param message Dialog content / 弹窗内容
     * @param buttons Array of button names and callbacks / 按钮名称和回调数组
     */
    public static function showCustom(title:String, message:String, buttons:Array<{name:String, callback:Void->Void}>):Void
    {
        #if android
        var pos:{name:String, func:Void->Void} = null;
        var neg:{name:String, func:Void->Void} = null;
        var neu:{name:String, func:Void->Void} = null;
        
        for (b in buttons)
        {
            if (pos == null) pos = {name: b.name, func: b.callback};
            else if (neg == null) neg = {name: b.name, func: b.callback};
            else if (neu == null) neu = {name: b.name, func: b.callback};
            else break;
        }
        AndroidTools.showNativeAlertDialog(title, message, pos, neg, neu, true);
        #elseif (cpp && !android)
        showCustomWindows(title, message, buttons);
        #else
        var msg = '$title\n\n$message\n\n';
        for (i in 0...buttons.length)
        {
            msg += '${i+1}. ${buttons[i].name}\n';
        }
        lime.app.Application.current.window.alert(msg, title);
        if (buttons.length > 0 && buttons[0].callback != null) buttons[0].callback();
        #end
    }

    // -------------------------------------------------------------------------
    // Windows-specific implementations
    // -------------------------------------------------------------------------
    #if (cpp && !android)
    private static function showYesNoWindows(title:String, message:String, onYes:Void->Void, onNo:Void->Void):Void
    {
        untyped __cpp__('
        {
            HWND hwnd = GetActiveWindow();
            
            const char* titleStr = {0}.c_str();
            const char* msgStr = {1}.c_str();
            
            int tLen = MultiByteToWideChar(CP_UTF8, 0, titleStr, -1, NULL, 0);
            int mLen = MultiByteToWideChar(CP_UTF8, 0, msgStr, -1, NULL, 0);
            
            WCHAR* tW = (WCHAR*)alloca(tLen * sizeof(WCHAR));
            WCHAR* mW = (WCHAR*)alloca(mLen * sizeof(WCHAR));
            
            MultiByteToWideChar(CP_UTF8, 0, titleStr, -1, tW, tLen);
            MultiByteToWideChar(CP_UTF8, 0, msgStr, -1, mW, mLen);
            
            int result = MessageBoxW(hwnd, mW, tW, MB_YESNO | MB_ICONQUESTION);
            
            if (result == IDYES)
            {
                {2}();
            }
            else
            {
                {3}();
            }
        }
        ', title, message, onYes, onNo);
    }

    private static function showCustomWindows(title:String, message:String, buttons:Array<{name:String, callback:Void->Void}>):Void
    {
        // For Windows, fallback to MessageBox with OK button only for custom dialogs
        // TaskDialog with custom buttons is more complex
        show(title, message, 'Info');
        if (buttons.length > 0 && buttons[0].callback != null) buttons[0].callback();
    }
    #end
}