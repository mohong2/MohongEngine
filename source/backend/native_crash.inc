// SeiunEngine native crash hooks - included via @:cppInclude from NativeCrash.hx
// Windows: SetUnhandledExceptionFilter (SEH) + SIGABRT + LuaJIT panic hooks;
// POSIX: sigaction for the fatal signals.
// All observers only: they write a log (+ one-shot pending marker), show a
// best-effort OS popup, and then let the process die as before.
//
// Why more than SetUnhandledExceptionFilter is needed on Windows:
//  - fast-fail/abort() terminations (CRT asserts, pure virtual calls, LuaJIT's
//    default panic) bypass the unhandled exception filter entirely, so those
//    crashes used to leave no log at all. signal(SIGABRT) sees them.
//  - an unprotected error inside the Lua VM would print "PANIC: ..." and die
//    without any engine context. lua_atpanic() intercepts it, logging the Lua
//    error message and a backtrace before aborting.
//  - the SEH path records no call stack by itself. dbghelp (StackWalk64 +
//    SymFromAddr, loaded dynamically at crash time) prints one; with the build
//    PDB next to the exe the frames resolve to real function names/lines.

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <signal.h>
#include <stdarg.h>

#if defined(_WIN32)
#  ifndef WIN32_LEAN_AND_MEAN
#    define WIN32_LEAN_AND_MEAN
#  endif
#  ifndef NOMINMAX
#    define NOMINMAX
#  endif
#  include <windows.h>
#  include <dbghelp.h>
#else
#  include <sys/stat.h>
#  include <sys/types.h>
#  include <fcntl.h>
#  include <unistd.h>
#  if defined(__APPLE__)
#    include <TargetConditionals.h>
#  endif
#  if !defined(__ANDROID__)
#    include <execinfo.h>
#  endif
#endif

#if defined(_WIN32)
static const char* seiun_exception_name(unsigned long code)
{
	switch (code)
	{
		case 0xC0000005UL: return "ACCESS_VIOLATION";
		case 0xC0000006UL: return "IN_PAGE_ERROR";
		case 0xC000000DUL: return "ILLEGAL_INSTRUCTION";
		case 0xC0000094UL: return "INTEGER_DIVIDE_BY_ZERO";
		case 0xC0000095UL: return "INTEGER_OVERFLOW";
		case 0xC00000FDUL: return "STACK_OVERFLOW";
		case 0xC0000409UL: return "STACK_BUFFER_OVERRUN";
		case 0x80000003UL: return "BREAKPOINT";
		case 0xC0000135UL: return "DLL_NOT_FOUND";
		default: return "UNKNOWN";
	}
}
#else
static const char* seiun_signal_name(int sig)
{
	switch (sig)
	{
		case SIGSEGV: return "SIGSEGV (segmentation fault / access violation)";
		case SIGABRT: return "SIGABRT (abort, e.g. LuaJIT panic / assert)";
		case SIGBUS: return "SIGBUS (bus error / misaligned access)";
		case SIGFPE: return "SIGFPE (arithmetic / floating point error)";
		case SIGILL: return "SIGILL (illegal instruction)";
		default: return "SIGNAL";
	}
}
#endif

static void seiun_crash_path(char* path, size_t n)
{
	time_t t = time(NULL);
	struct tm tmv;
#if defined(_WIN32)
	localtime_s(&tmv, &t);
	CreateDirectoryA("crash", NULL);
#else
	localtime_r(&t, &tmv);
	mkdir("crash", 0755);
#endif
	snprintf(path, n, "crash/native_crash_%04d%02d%02d_%02d%02d%02d.txt",
		tmv.tm_year + 1900, tmv.tm_mon + 1, tmv.tm_mday, tmv.tm_hour, tmv.tm_min, tmv.tm_sec);
}

// ── shared output helpers ────────────────────────────────────────────────────

// Single crash buffer + single crash path; only one handler ever runs (the
// first to win the crash flag). The path is computed once so multi-phase
// writes (basic info first, enhanced log after) land on the same file.
static char seiun_body[16384];
static char seiun_path[512];

#if defined(_WIN32)
static volatile LONG seiun_crash_written = 0;
#else
static volatile sig_atomic_t seiun_crash_written = 0;
#endif

static const char* seiun_crash_file(void)
{
	if (seiun_path[0] == 0)
		seiun_crash_path(seiun_path, sizeof(seiun_path));
	return seiun_path;
}

// vsnprintf-based append that never lets the running length pass the buffer.
static void seiun_append(char* buf, size_t cap, int* len, const char* fmt, ...)
{
	if (*len < 0 || (size_t)*len >= cap)
		return;
	va_list ap;
	va_start(ap, fmt);
	int l = vsnprintf(buf + *len, cap - (size_t)*len, fmt, ap);
	va_end(ap);
	if (l < 0)
		return;
	if ((size_t)*len + (size_t)l >= cap)
	{
		*len = (int)cap - 1;
		return;
	}
	*len += l;
}

static void seiun_mark_crash_pending(void);

static void seiun_write_crash_file(const char* body)
{
	FILE* f = fopen(seiun_crash_file(), "w");
	if (f != NULL)
	{
		fprintf(f, "SeiunEngine native crash recorded (%s)\n", seiun_path);
		fputs(body, f);
		fclose(f);
	}
	seiun_mark_crash_pending();
}

// A one-shot marker for the Haxe layer: the native handler cannot safely run
// FlxG / CrashCatcherState itself, so the next launch consumes this file and
// shows the existing crash-catcher recovery screen (a graceful "rollback").
static void seiun_mark_crash_pending(void)
{
	FILE* f = fopen("crash/native_crash.pending", "w");
	if (f != NULL)
	{
		if (seiun_path[0] != 0)
			fputs(seiun_path, f);
		fputc('\n', f);
		fclose(f);
	}
}

// Best-effort OS popup. The process is already fatally broken, so failure is
// intentionally silent; after the popup the original crash path continues.
static void seiun_native_crash_popup(const char* path)
{
#if defined(_WIN32)
	char msg[1024];
	snprintf(msg, sizeof(msg),
		"A native crash has been recorded by SeiunEngine.\r\n\r\nLog: %s\r\n\r\nThe game will now exit.", path);
	MessageBoxA(NULL, msg, "SeiunEngine native crash", MB_OK | MB_ICONERROR | MB_TOPMOST);
#elif defined(__APPLE__) && defined(TARGET_OS_IPHONE) && !TARGET_OS_IPHONE
	char text[1024];
	snprintf(text, sizeof(text),
		"A native crash has been recorded by SeiunEngine.\n\nLog: %s\n\nThe game will now exit.", path);
	char script[2048];
	snprintf(script, sizeof(script),
		"display alert \"SeiunEngine native crash\" message \"%s\" as critical", text);
	pid_t pid = fork();
	if (pid == 0)
	{
		execl("/usr/bin/osascript", "osascript", "-e", script, (char*)NULL);
		_exit(127);
	}
#elif defined(__linux__) && !defined(__ANDROID__)
	char text[1024];
	snprintf(text, sizeof(text),
		"A native crash has been recorded by SeiunEngine.\n\nLog: %s\n\nThe game will now exit.", path);
	char zenityText[1024];
	snprintf(zenityText, sizeof(zenityText), "--text=%s", text);
	char xmessageText[1024];
	snprintf(xmessageText, sizeof(xmessageText), "SeiunEngine native crash\n\n%s", text);
	pid_t pid = fork();
	if (pid == 0)
	{
		execlp("zenity", "zenity", "--error", "--title=SeiunEngine native crash", zenityText, (char*)NULL);
		execlp("kdialog", "kdialog", "--error", text, (char*)NULL);
		execlp("xmessage", "xmessage", "-center", xmessageText, (char*)NULL);
		_exit(127);
	}
#else
	(void)path;
#endif
}

// ── dbghelp (loaded lazily at crash time, never linked) ──────────────────────

#if defined(_WIN32)
typedef BOOL (WINAPI *SeiunStackWalk64Fn)(DWORD, HANDLE, HANDLE, LPSTACKFRAME64, PVOID,
	PREAD_PROCESS_MEMORY_ROUTINE64, PFUNCTION_TABLE_ACCESS_ROUTINE64,
	PGET_MODULE_BASE_ROUTINE64, PTRANSLATE_ADDRESS_ROUTINE64);
typedef PVOID (WINAPI *SeiunSymFunctionTableAccess64Fn)(HANDLE, DWORD64);
typedef DWORD64 (WINAPI *SeiunSymGetModuleBase64Fn)(HANDLE, DWORD64);
typedef BOOL (WINAPI *SeiunSymInitializeFn)(HANDLE, const char*, BOOL);
typedef BOOL (WINAPI *SeiunSymFromAddrFn)(HANDLE, DWORD64, PDWORD64, PSYMBOL_INFO);
typedef BOOL (WINAPI *SeiunSymGetLineFromAddr64Fn)(HANDLE, DWORD64, PDWORD, PIMAGEHLP_LINE64);
typedef DWORD (WINAPI *SeiunSymSetOptionsFn)(DWORD);
typedef unsigned short (WINAPI *SeiunCaptureStackBackTraceFn)(unsigned long, unsigned long, void**, unsigned long*);

static struct
{
	HMODULE lib;
	SeiunStackWalk64Fn stackWalk64;
	SeiunSymFunctionTableAccess64Fn funcTableAccess64;
	SeiunSymGetModuleBase64Fn getModuleBase64;
	SeiunSymFromAddrFn symFromAddr;
	SeiunSymGetLineFromAddr64Fn symGetLineFromAddr64;
	SeiunCaptureStackBackTraceFn captureBacktrace;
	int ready; // StackWalk64/SymFromAddr usable (SymInitialize succeeded)
} seiun_dbghelp;

static void seiun_dbghelp_init(void)
{
	if (seiun_dbghelp.lib != NULL)
		return;
	HMODULE lib = LoadLibraryA("dbghelp.dll");
	if (lib == NULL)
		return;
	SeiunSymInitializeFn symInit = (SeiunSymInitializeFn)GetProcAddress(lib, "SymInitialize");
	SeiunStackWalk64Fn walk = (SeiunStackWalk64Fn)GetProcAddress(lib, "StackWalk64");
	SeiunSymFunctionTableAccess64Fn fta = (SeiunSymFunctionTableAccess64Fn)GetProcAddress(lib, "SymFunctionTableAccess64");
	SeiunSymGetModuleBase64Fn gmb = (SeiunSymGetModuleBase64Fn)GetProcAddress(lib, "SymGetModuleBase64");
	if (symInit == NULL || walk == NULL || fta == NULL || gmb == NULL)
		return;
	seiun_dbghelp.lib = lib;
	seiun_dbghelp.stackWalk64 = walk;
	seiun_dbghelp.funcTableAccess64 = fta;
	seiun_dbghelp.getModuleBase64 = gmb;
	seiun_dbghelp.symFromAddr = (SeiunSymFromAddrFn)GetProcAddress(lib, "SymFromAddr");
	seiun_dbghelp.symGetLineFromAddr64 = (SeiunSymGetLineFromAddr64Fn)GetProcAddress(lib, "SymGetLineFromAddr64");
	{
		HMODULE ntdll = GetModuleHandleA("ntdll.dll");
		if (ntdll != NULL)
			seiun_dbghelp.captureBacktrace = (SeiunCaptureStackBackTraceFn)GetProcAddress(ntdll, "RtlCaptureStackBackTrace");
	}
	{
		SeiunSymSetOptionsFn setOpts = (SeiunSymSetOptionsFn)GetProcAddress(lib, "SymSetOptions");
		// UNDNAME | DEFERRED_LOADS | LOAD_LINES | NO_PROMPTS (no symbol-server dialogs)
		if (setOpts != NULL)
			setOpts(0x00000002 | 0x00000004 | 0x00000010 | 0x00080000);
	}
	// Invade loads the module list for the current process; with the build PDB
	// next to the exe, SymFromAddr then resolves real function names.
	if (symInit(GetCurrentProcess(), NULL, TRUE))
		seiun_dbghelp.ready = 1;
}

// Module name + base for an arbitrary address; outName "?" when unmapped.
static ULONG_PTR seiun_module_for_address(ULONG_PTR addr, char* outName, size_t outCap)
{
	outName[0] = '?';
	outName[1] = 0;
	if (addr == 0)
		return 0;
	HMODULE mod = NULL;
	if (!GetModuleHandleExA(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
		(LPCSTR)addr, &mod))
		return 0;
	char path[1024];
	path[0] = 0;
	if (GetModuleFileNameA(mod, path, (DWORD)sizeof(path)))
	{
		const char* name = path;
		for (const char* p = path; *p; ++p)
			if (*p == '\\' || *p == '/')
				name = p + 1;
		strncpy(outName, name, outCap - 1);
		outName[outCap - 1] = 0;
	}
	return (ULONG_PTR)mod;
}

// "<module>+0xRVA  <symbol>+0xdisp [file:line]" for one address.
static void seiun_annotate_address(char* dst, size_t cap, DWORD64 pc)
{
	char modName[128];
	ULONG_PTR base = seiun_module_for_address((ULONG_PTR)pc, modName, sizeof(modName));
	if (base != 0)
		snprintf(dst, cap, "%s+0x%llX", modName, (unsigned long long)(pc - (DWORD64)base));
	else
		snprintf(dst, cap, "0x%llX (unmapped)", (unsigned long long)pc);
	if (seiun_dbghelp.ready && seiun_dbghelp.symFromAddr != NULL)
	{
		char symBuf[sizeof(SYMBOL_INFO) + 384];
		memset(symBuf, 0, sizeof(symBuf));
		SYMBOL_INFO* si = (SYMBOL_INFO*)symBuf;
		si->SizeOfStruct = sizeof(SYMBOL_INFO);
		si->MaxNameLen = 383;
		DWORD64 disp = 0;
		if (seiun_dbghelp.symFromAddr(GetCurrentProcess(), pc, &disp, si))
		{
			size_t used = strlen(dst);
			snprintf(dst + used, cap - used, " <%s>+0x%llX", si->Name, (unsigned long long)disp);
			if (seiun_dbghelp.symGetLineFromAddr64 != NULL)
			{
				IMAGEHLP_LINE64 line;
				memset(&line, 0, sizeof(line));
				line.SizeOfStruct = sizeof(IMAGEHLP_LINE64);
				DWORD disp32 = 0;
				if (seiun_dbghelp.symGetLineFromAddr64(GetCurrentProcess(), pc, &disp32, &line) && line.FileName != NULL)
				{
					const char* fn = line.FileName;
					size_t flen = strlen(fn);
					if (flen > 60)
						fn = fn + (flen - 60);
					size_t used2 = strlen(dst);
					snprintf(dst + used2, cap - used2, " [%s:%lu]", fn, (unsigned long)line.LineNumber);
				}
			}
		}
	}
}

// Proper unwind from the faulting context (x64 only; the build is x64).
static int seiun_write_stackwalk(char* out, size_t cap, CONTEXT* ctx)
{
#if defined(_M_X64) || defined(__x86_64__)
	if (!seiun_dbghelp.ready || ctx == NULL)
		return 0;
	STACKFRAME64 frame;
	memset(&frame, 0, sizeof(frame));
	frame.AddrPC.Offset = ctx->Rip;
	frame.AddrPC.Mode = AddrModeFlat;
	frame.AddrFrame.Offset = ctx->Rbp;
	frame.AddrFrame.Mode = AddrModeFlat;
	frame.AddrStack.Offset = ctx->Rsp;
	frame.AddrStack.Mode = AddrModeFlat;
	int len = 0;
	seiun_append(out, cap, &len, "Backtrace (StackWalk64):\n");
	DWORD64 prevPc = 0;
	for (int i = 0; i < 32; i++)
	{
		if (len >= (int)cap - 768)
			break;
		if (!seiun_dbghelp.stackWalk64(IMAGE_FILE_MACHINE_AMD64, GetCurrentProcess(), GetCurrentThread(),
			&frame, ctx, NULL, seiun_dbghelp.funcTableAccess64, seiun_dbghelp.getModuleBase64, NULL))
			break;
		if (frame.AddrPC.Offset == 0 || frame.AddrPC.Offset == prevPc)
			break;
		prevPc = frame.AddrPC.Offset;
		char line[640];
		seiun_annotate_address(line, sizeof(line), frame.AddrPC.Offset);
		seiun_append(out, cap, &len, "  #%02d %s\n", i, line);
	}
	return len;
#else
	(void)out; (void)cap; (void)ctx;
	return 0;
#endif
}

// Live-stack capture for the SIGABRT / LuaJIT panic paths (stack intact there).
static int seiun_write_live_backtrace(char* out, size_t cap)
{
	if (seiun_dbghelp.captureBacktrace == NULL)
		return 0;
	void* frames[64];
	unsigned short n = seiun_dbghelp.captureBacktrace(0, 64, frames, NULL);
	if (n == 0)
		return 0;
	int len = 0;
	seiun_append(out, cap, &len, "Backtrace (captured, outermost last):\n");
	for (unsigned short i = 0; i < n; i++)
	{
		if (len >= (int)cap - 768)
			break;
		char line[640];
		seiun_annotate_address(line, sizeof(line), (DWORD64)(ULONG_PTR)frames[i]);
		seiun_append(out, cap, &len, "  #%02d %s\n", i, line);
	}
	return len;
}

// Fallback when unwinding fails (e.g. through JIT code): scan the raw stack
// for values that look like return addresses into known modules.
static int seiun_write_stack_scan(char* out, size_t cap, ULONG_PTR rsp)
{
	int len = 0;
	seiun_append(out, cap, &len, "Stack scan near RSP (module hits only):\n");
	if (rsp == 0)
		return len;
	__try
	{
		for (int i = 0; i < 160; i++)
		{
			if (len >= (int)cap - 256)
				break;
			ULONG_PTR v = ((ULONG_PTR*)rsp)[i];
			char modName[128];
			ULONG_PTR base = seiun_module_for_address(v, modName, sizeof(modName));
			if (base != 0)
				seiun_append(out, cap, &len, "  rsp+0x%03X: %s+0x%llX\n",
					i * (int)sizeof(ULONG_PTR), modName, (unsigned long long)(v - (DWORD64)base));
		}
	}
	__except (EXCEPTION_EXECUTE_HANDLER) {}
	return len;
}
#endif // _WIN32

// ── Windows: unhandled exception filter ──────────────────────────────────────

#if defined(_WIN32)
static LONG WINAPI seiun_seh_handler(EXCEPTION_POINTERS* info)
{
	if (InterlockedCompareExchange(&seiun_crash_written, 1, 0) != 0)
		return EXCEPTION_CONTINUE_SEARCH;

	if (info == NULL || info->ExceptionRecord == NULL)
		return EXCEPTION_CONTINUE_SEARCH;

	char* body = seiun_body;
	size_t cap = sizeof(seiun_body);
	int len = 0;
	seiun_append(body, cap, &len, "Native crash (Windows Structured Exception Handling)\n");

	EXCEPTION_RECORD* er = info->ExceptionRecord;
	seiun_append(body, cap, &len, "Exception code: 0x%08lX (%s)\n",
		(unsigned long)er->ExceptionCode, seiun_exception_name(er->ExceptionCode));
	seiun_append(body, cap, &len, "Exception flags: 0x%08lX\n", (unsigned long)er->ExceptionFlags);
	seiun_append(body, cap, &len, "Exception address (faulting instruction pointer): 0x%p\n",
		(void*)er->ExceptionAddress);
	HMODULE mod = NULL;
	char modName[300] = "?";
	ULONG_PTR moduleBase = 0;
	if (GetModuleHandleExA(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
		(LPCSTR)er->ExceptionAddress, &mod))
	{
		moduleBase = (ULONG_PTR)mod;
		GetModuleFileNameA(mod, modName, sizeof(modName));
	}
	seiun_append(body, cap, &len, "Faulting module: %s\n", modName);
	if (moduleBase != 0)
	{
		seiun_append(body, cap, &len, "Module base: 0x%p\n", (void*)moduleBase);
		seiun_append(body, cap, &len, "Fault offset: 0x%016llX\n",
			(unsigned long long)((ULONG_PTR)er->ExceptionAddress - moduleBase));
	}
	seiun_append(body, cap, &len, "Exception parameters: %lu\n", (unsigned long)er->NumberParameters);
	for (DWORD i = 0; i < er->NumberParameters && i < 2; i++)
	{
		seiun_append(body, cap, &len, "  param[%lu]: 0x%p (ACCESS_VIOLATION: 0=read,1=write,8=exec / faulting address)\n",
			(unsigned long)i, (void*)er->ExceptionInformation[i]);
	}
	if (info->ContextRecord != NULL)
	{
		CONTEXT* c = info->ContextRecord;
#if defined(_M_X64) || defined(__x86_64__)
		seiun_append(body, cap, &len, "Registers (x64):\n");
		seiun_append(body, cap, &len, "  RIP=0x%016llX RSP=0x%016llX RBP=0x%016llX\n",
			(unsigned long long)c->Rip, (unsigned long long)c->Rsp, (unsigned long long)c->Rbp);
		seiun_append(body, cap, &len, "  RAX=0x%016llX RBX=0x%016llX RCX=0x%016llX RDX=0x%016llX\n",
			(unsigned long long)c->Rax, (unsigned long long)c->Rbx, (unsigned long long)c->Rcx, (unsigned long long)c->Rdx);
		seiun_append(body, cap, &len, "  RSI=0x%016llX RDI=0x%016llX R8=0x%016llX  R9=0x%016llX\n",
			(unsigned long long)c->Rsi, (unsigned long long)c->Rdi, (unsigned long long)c->R8, (unsigned long long)c->R9);
		seiun_append(body, cap, &len, "  R10=0x%016llX R11=0x%016llX R12=0x%016llX R13=0x%016llX\n",
			(unsigned long long)c->R10, (unsigned long long)c->R11, (unsigned long long)c->R12, (unsigned long long)c->R13);
		seiun_append(body, cap, &len, "  R14=0x%016llX R15=0x%016llX\n",
			(unsigned long long)c->R14, (unsigned long long)c->R15);
#elif defined(_M_IX86) || defined(__i386__)
		seiun_append(body, cap, &len, "Registers (x86):\n");
		seiun_append(body, cap, &len, "  EIP=0x%08X ESP=0x%08X EBP=0x%08X\n",
			(unsigned int)c->Eip, (unsigned int)c->Esp, (unsigned int)c->Ebp);
		seiun_append(body, cap, &len, "  EAX=0x%08X EBX=0x%08X ECX=0x%08X EDX=0x%08X\n",
			(unsigned int)c->Eax, (unsigned int)c->Ebx, (unsigned int)c->Ecx, (unsigned int)c->Edx);
		seiun_append(body, cap, &len, "  ESI=0x%08X EDI=0x%08X\n",
			(unsigned int)c->Esi, (unsigned int)c->Edi);
#elif defined(_M_ARM64)
		seiun_append(body, cap, &len, "Registers (ARM64):\n");
		seiun_append(body, cap, &len, "  PC=0x%016llX SP=0x%016llX\n",
			(unsigned long long)c->Pc, (unsigned long long)c->Sp);
#endif
	}

	// Phase 1 on disk: registers/exception info land even if dbghelp itself
	// dies inside a corrupted heap while resolving symbols below.
	seiun_write_crash_file(body);
	// Show the popup before the (less safe) symbol work, so the user at least
	// sees it even if dbghelp dies while resolving addresses.
	seiun_native_crash_popup(seiun_crash_file());

	// Phase 2: backtrace + stack scan appended, file overwritten in place.
	seiun_dbghelp_init();
	len += seiun_write_stackwalk(body + len, cap - (size_t)len, info->ContextRecord);
#if defined(_M_X64) || defined(__x86_64__)
	if (info->ContextRecord != NULL)
		len += seiun_write_stack_scan(body + len, cap - (size_t)len, (ULONG_PTR)info->ContextRecord->Rsp);
#endif
	seiun_write_crash_file(body);

	return EXCEPTION_CONTINUE_SEARCH;
}

// abort()/terminate path: CRT asserts, pure virtual calls, etc. These bypass
// SetUnhandledExceptionFilter, so they used to die without any log. Returning
// from the handler lets abort() proceed and terminate as before.
static void __cdecl seiun_sigabrt_handler(int sig)
{
	(void)sig;
	if (InterlockedCompareExchange(&seiun_crash_written, 1, 0) != 0)
		return; // already logged (e.g. by the LuaJIT panic handler)

	seiun_dbghelp_init();
	char* body = seiun_body;
	size_t cap = sizeof(seiun_body);
	int len = 0;
	seiun_append(body, cap, &len, "Native crash (abort()/terminate path - SIGABRT; CRT assert, pure virtual call, etc.)\n");
	len += seiun_write_live_backtrace(body + len, cap - (size_t)len);
	seiun_write_crash_file(body);
	seiun_native_crash_popup(seiun_crash_file());
}
#endif // _WIN32

// ── POSIX: fatal signal handler ──────────────────────────────────────────────

#if !defined(_WIN32)
static void seiun_posix_handler(int sig, siginfo_t* si, void* uctx)
{
	(void)uctx;
	if (seiun_crash_written != 0)
	{
		signal(sig, SIG_DFL);
		raise(sig);
		return;
	}
	seiun_crash_written = 1;

	char body[4096];
	int len = 0;
	seiun_append(body, sizeof(body), &len, "Native crash (POSIX signal)\n");
	seiun_append(body, sizeof(body), &len, "Signal: %d - %s, si_code=%d\n", sig, seiun_signal_name(sig), si ? si->si_code : 0);
	seiun_append(body, sizeof(body), &len, "Fault address (si_addr, memory pointer): 0x%p\n", si ? si->si_addr : (void*)0);
	seiun_write_crash_file(body);
	// Popup before backtrace: backtrace/execinfo can itself be fragile after a
	// memory corruption, but the marker/log is already on disk by now.
	seiun_native_crash_popup(seiun_crash_file());

#if !defined(__ANDROID__)
	int fd = open(seiun_crash_file(), O_WRONLY | O_CREAT | O_TRUNC, 0644);
	if (fd >= 0)
	{
		const char* head = "SeiunEngine native crash recorded\n";
		write(fd, head, strlen(head));
		write(fd, body, (size_t)len);
		void* bt[64];
		int n = backtrace(bt, 64);
		backtrace_symbols_fd(bt, n, fd);
		close(fd);
	}
#endif

	signal(sig, SIG_DFL);
	raise(sig);
}
#endif // !_WIN32

// ── LuaJIT panic hook (both platforms) ───────────────────────────────────────

// Minimal LuaJIT C API surface (statically linked into the exe; declared here
// to avoid a lua.hpp dependency in this TU - signatures match Lua 5.1).
struct lua_State;
#ifdef __cplusplus
extern "C" {
#endif
typedef int (*seiun_lua_CFunction)(lua_State*);
seiun_lua_CFunction lua_atpanic(lua_State* L, seiun_lua_CFunction panicf);
const char* lua_tolstring(lua_State* L, int idx, size_t* len);
#ifdef __cplusplus
}
#endif

// Called by LuaJIT when an unprotected error escapes to the C API boundary.
// Without this, LuaJIT prints "PANIC: unprotected error..." and terminates,
// leaving no engine-side log at all.
static int seiun_lua_panic_handler(lua_State* L)
{
	int logged = 0;
#if defined(_WIN32)
	logged = (InterlockedCompareExchange(&seiun_crash_written, 1, 0) == 0);
#else
	if (seiun_crash_written == 0)
	{
		seiun_crash_written = 1;
		logged = 1;
	}
#endif
	if (logged)
	{
		char* body = seiun_body;
		size_t cap = sizeof(seiun_body);
		int len = 0;
		seiun_append(body, cap, &len, "Native crash (LuaJIT panic: unprotected error in call to Lua API)\n");
		const char* msg = (L != NULL) ? lua_tolstring(L, -1, NULL) : NULL;
		seiun_append(body, cap, &len, "Lua error message: %s\n", (msg != NULL) ? msg : "(non-string error object)");
#if defined(_WIN32)
		seiun_dbghelp_init();
		// Phase 1: basic body + popup/marker before the (fragile) live backtrace.
		seiun_write_crash_file(body);
		seiun_native_crash_popup(seiun_crash_file());
		// Phase 2: overwrite with the backtrace appended.
		len += seiun_write_live_backtrace(body + len, cap - (size_t)len);
		seiun_write_crash_file(body);
#else
		{
			const char* path = seiun_crash_file();
			int fd = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0644);
			if (fd >= 0)
			{
				const char* head = "SeiunEngine native crash recorded (LuaJIT panic)\n";
				write(fd, head, strlen(head));
				write(fd, body, (size_t)len);
				close(fd);
			}
			seiun_mark_crash_pending();
			seiun_native_crash_popup(path);

			// Append the backtrace separately so a crash during backtrace still
			// leaves the message + marker + popup behind.
			int fd2 = open(path, O_WRONLY | O_APPEND, 0644);
			if (fd2 >= 0)
			{
#if !defined(__ANDROID__)
				void* bt[64];
				int n = backtrace(bt, 64);
				backtrace_symbols_fd(bt, n, fd2);
#endif
				close(fd2);
			}
		}
#endif
	}
	abort();
	return 0; // not reached
}

// Install the panic handler on one lua_State (called from Haxe after newstate).
void seiun_install_lua_panic(void* L)
{
	if (L != NULL)
		lua_atpanic((lua_State*)L, seiun_lua_panic_handler);
}

// ── installer ────────────────────────────────────────────────────────────────

static void seiun_install_native_crash_hooks()
{
#if defined(_WIN32)
	SetUnhandledExceptionFilter(seiun_seh_handler);
	// SIGABRT: the only signal UCRT abort() honors before terminating.
	signal(SIGABRT, seiun_sigabrt_handler);
#else
	struct sigaction sa;
	memset(&sa, 0, sizeof(sa));
	sa.sa_sigaction = seiun_posix_handler;
	sa.sa_flags = SA_SIGINFO | SA_RESETHAND;
	sigemptyset(&sa.sa_mask);
	sigaction(SIGSEGV, &sa, NULL);
	sigaction(SIGABRT, &sa, NULL);
	sigaction(SIGBUS, &sa, NULL);
	sigaction(SIGFPE, &sa, NULL);
	sigaction(SIGILL, &sa, NULL);
#endif
}
