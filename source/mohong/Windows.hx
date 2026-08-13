package mohong;

/**
 * 弹窗类型（Windows TaskDialog/MessageBox 使用）。
 * 注意：backend.Dialog 在非 Windows 平台自己定义了等价的 DialogType。
 */
enum abstract DialogType(Int) {
	var Info = 0;
	var Warning = 1;
	var Error = 2;
}

/**
 * 原生 Windows 窗口辅助（mohong 重写版）。
 *
 * 解决什么问题：
 *   深色模式、控制台分配/释放/写入、原生对话框这几件"只有 Windows 能做的事"。
 *   旧实现功能可用但注释与结构散乱；重写保持功能完全等价，只重整隔离结构。
 *
 * 挂在哪个真实调用点：
 *   - Main.hx: enableDarkMode()（desktop 启动时）；
 *   - TraceManager/TraceConsole: enableAnsiColors()/writeConsole()（日志输出）；
 *   - OptionsState: hasConsole()/allocConsole()/freeConsole()（Trace Console 开关）；
 *   - OptionLoader: hasConsole()（选项当前值显示）；
 *   - backend.Dialog / UnsavedChangesTracker: showDialog()/showYesNoMessageBox()。
 *
 * 怎么验证它真的在工作：
 *   - Windows 实机：深色标题栏、Trace Console 开关、崩溃对话框行为与重写前一致；
 *   - 非 Windows 平台：全部函数为无害空实现（返回 false），编译通过且不执行任何 Win32 调用。
 *
 * 平台纪律：所有 Win32 实现都在 `#if (cpp && windows)` 内；
 * 类本身在全平台存在，因为 Main.hx 的 `#if desktop` 分支在 mac/linux 也会引用它。
 */

#if (cpp && windows)
@:headerCode('
#ifndef NOMINMAX
#define NOMINMAX
#endif
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#undef ERROR
#undef FALSE
#undef TRUE
#undef NO_ERROR
#undef DELETE
')
#end
class Windows
{
	/**
	 * 把当前窗口标题栏切换为深色（DWM 属性 19/20）。
	 * 非 Windows 平台：空实现。
	 */
	public static function enableDarkMode():Void
	{
		#if (cpp && windows)
		untyped __cpp__('
		{
			HMODULE dwmapi = LoadLibraryA("dwmapi.dll");
			if (dwmapi)
			{
				typedef HRESULT (WINAPI *DwmSetWindowAttributeFunc)(HWND, DWORD, LPCVOID, DWORD);
				DwmSetWindowAttributeFunc DwmSetWindowAttribute = (DwmSetWindowAttributeFunc)GetProcAddress(dwmapi, "DwmSetWindowAttribute");
				if (DwmSetWindowAttribute)
				{
					HWND hwnd = GetActiveWindow();
					if (hwnd)
					{
						BOOL useDarkMode = 1;
						DwmSetWindowAttribute(hwnd, 20, &useDarkMode, sizeof(useDarkMode));
						DwmSetWindowAttribute(hwnd, 19, &useDarkMode, sizeof(useDarkMode));
					}
				}
				FreeLibrary(dwmapi);
			}
		}
		');
		#end
	}

	/**
	 * 为 GUI 进程分配一个控制台窗口。成功返回 true。
	 * 非 Windows 平台：恒 false。
	 */
	public static function allocConsole():Bool
	{
		#if (cpp && windows)
		return untyped __cpp__('AllocConsole() != 0');
		#else
		return false;
		#end
	}

	/**
	 * 释放当前控制台窗口。成功返回 true。
	 * 非 Windows 平台：恒 false。
	 */
	public static function freeConsole():Bool
	{
		#if (cpp && windows)
		return untyped __cpp__('FreeConsole() != 0');
		#else
		return false;
		#end
	}

	/**
	 * 以 UTF-8 文本写入控制台（WriteConsoleW，避免 stdout 重定向死锁）。
	 * 非 Windows 平台：空实现。
	 */
	public static function writeConsole(text:String):Void
	{
		#if (cpp && windows)
		untyped __cpp__('
		{
			HANDLE hOut = GetStdHandle(STD_OUTPUT_HANDLE);
			if (hOut != INVALID_HANDLE_VALUE)
			{
				int wlen = MultiByteToWideChar(CP_UTF8, 0, {0}.c_str(), -1, NULL, 0);
				if (wlen > 0)
				{
					wchar_t* wbuf = (wchar_t*)alloca(wlen * sizeof(wchar_t));
					MultiByteToWideChar(CP_UTF8, 0, {0}.c_str(), -1, wbuf, wlen);
					DWORD written = 0;
					WriteConsoleW(hOut, wbuf, wlen - 1, &written, NULL);
				}
			}
		}
		', text);
		#end
	}

	/**
	 * 当前进程是否有控制台窗口。
	 * 非 Windows 平台：恒 false。
	 */
	public static function hasConsole():Bool
	{
		#if (cpp && windows)
		return untyped __cpp__('GetConsoleWindow() != NULL');
		#else
		return false;
		#end
	}

	/**
	 * 释放再重新分配控制台。成功返回 true。
	 * 非 Windows 平台：恒 false。
	 */
	public static function reopenConsole():Bool
	{
		#if (cpp && windows)
		freeConsole();
		return allocConsole();
		#else
		return false;
		#end
	}

	/**
	 * 启用控制台 ANSI 转义（ENABLE_VIRTUAL_TERMINAL_PROCESSING）。
	 * 非 Windows 平台：空实现。
	 */
	public static function enableAnsiColors():Void
	{
		#if (cpp && windows)
		untyped __cpp__('
		{
			HANDLE hOut = GetStdHandle(STD_OUTPUT_HANDLE);
			if (hOut != INVALID_HANDLE_VALUE)
			{
				DWORD dwMode = 0;
				if (GetConsoleMode(hOut, &dwMode))
				{
					dwMode |= 0x0004; // ENABLE_VIRTUAL_TERMINAL_PROCESSING
					SetConsoleMode(hOut, dwMode);
				}
			}
		}
		');
		#end
	}

	/**
	 * 显示原生 OK 对话框（优先 TaskDialog，回退 MessageBoxW）。
	 * 非 Windows 平台：空实现。
	 */
	public static function showDialog(title:String, message:String, type:DialogType):Void
	{
		#if (cpp && windows)
		untyped __cpp__('
		{
			HWND hwnd = GetActiveWindow();

			const char* titleStr = {0}.c_str();
			const char* msgStr = {1}.c_str();
			int iconType = {2};

			int tLen = MultiByteToWideChar(CP_UTF8, 0, titleStr, -1, NULL, 0);
			int mLen = MultiByteToWideChar(CP_UTF8, 0, msgStr, -1, NULL, 0);

			WCHAR* tW = (WCHAR*)alloca(tLen * sizeof(WCHAR));
			WCHAR* mW = (WCHAR*)alloca(mLen * sizeof(WCHAR));

			MultiByteToWideChar(CP_UTF8, 0, titleStr, -1, tW, tLen);
			MultiByteToWideChar(CP_UTF8, 0, msgStr, -1, mW, mLen);

			// TD_*_ICON values: Info=-3, Warning=-1, Error=-2
			PCWSTR tdIcons[3] = {
				(PCWSTR)(ULONG_PTR)(WORD)(-3),
				(PCWSTR)(ULONG_PTR)(WORD)(-1),
				(PCWSTR)(ULONG_PTR)(WORD)(-2)
			};

			// MB_ICON* values
			UINT mbIcons[3] = {
				MB_ICONINFORMATION,
				MB_ICONWARNING,
				MB_ICONERROR
			};

			PCWSTR icon = (iconType >= 0 && iconType < 3) ? tdIcons[iconType] : NULL;
			UINT mbFlags = MB_OK | ((iconType >= 0 && iconType < 3) ? mbIcons[iconType] : 0);

			HMODULE comctl32 = LoadLibraryA("comctl32.dll");
			if (comctl32)
			{
				typedef HRESULT (WINAPI *TaskDialogFunc)(HWND, HINSTANCE, PCWSTR, PCWSTR, PCWSTR, int, PCWSTR, int*);
				TaskDialogFunc pTaskDialog = (TaskDialogFunc)GetProcAddress(comctl32, "TaskDialog");
				if (pTaskDialog)
				{
					int btn = 0;
					pTaskDialog(hwnd, NULL, tW, mW, NULL, 1, icon, &btn);
					FreeLibrary(comctl32);
					return;
				}
				FreeLibrary(comctl32);
			}

			MessageBoxW(hwnd, mW, tW, mbFlags);
		}
		', title, message, type);
		#end
	}

	/**
	 * 显示原生 Yes/No 对话框，用户点"是"返回 true。
	 * 非 Windows 平台：恒 true（等同"放行"），调用方负责平台分支。
	 *
	 * Note: 用临时变量而不是 `return __cpp__(...)`，因为 MSVC 不支持 GCC 语句表达式。
	 */
	public static function showYesNoMessageBox(title:String, message:String):Bool
	{
		#if (cpp && windows)
		var result:Bool = false;
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

			int mbResult = MessageBoxW(hwnd, mW, tW, MB_YESNO | MB_ICONWARNING | MB_DEFBUTTON2);
			{2} = (mbResult == IDYES);
		}
		', title, message, result);
		return result;
		#else
		return true;
		#end
	}
}
