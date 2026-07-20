package mohong;

enum abstract DialogType(Int) {
	var Info = 0;
	var Warning = 1;
	var Error = 2;
}

#if (cpp && !android)
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
	public static function enableDarkMode():Void
	{
		#if (cpp && !android)
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

	public static function allocConsole():Bool
	{
		#if (cpp && !android)
		return untyped __cpp__('AllocConsole() != 0');
		#else
		return false;
		#end
	}

	
	public static function freeConsole():Bool
	{
		#if (cpp && !android)
		return untyped __cpp__('FreeConsole() != 0');
		#else
		return false;
		#end
	}
	public static function writeConsole(text:String):Void
	{
		#if (cpp && !android)
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

	public static function hasConsole():Bool
	{
		#if (cpp && !android)
		return untyped __cpp__('GetConsoleWindow() != NULL');
		#else
		return false;
		#end
	}

	public static function reopenConsole():Bool
	{
		#if (cpp && !android)
		freeConsole();
		return allocConsole();
		#else
		return false;
		#end
	}

	public static function enableAnsiColors():Void
	{
		#if (cpp && !android)
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

	public static function showDialog(title:String, message:String, type:DialogType):Void
	{
		#if (cpp && !android)
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
	 * Show a Yes/No message box and return true if user clicked Yes.
	 * 显示是/否消息框，用户点击"是"返回 true。
	 *
	 * Note: Uses a temp variable instead of 'return __cpp__(...)' because
	 * MSVC does not support GCC statement-expressions.
	 */
	public static function showYesNoMessageBox(title:String, message:String):Bool
	{
		#if (cpp && !android)
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
