// SeiunEngine native crash hooks - included via @:cppInclude from NativeCrash.hx
// Windows: SetUnhandledExceptionFilter; POSIX: sigaction for the fatal signals.
// All observers only: they write a log and then let the process crash as before.

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#if defined(_WIN32)
#  ifndef WIN32_LEAN_AND_MEAN
#    define WIN32_LEAN_AND_MEAN
#  endif
#  ifndef NOMINMAX
#    define NOMINMAX
#  endif
#  include <windows.h>
#else
#  include <signal.h>
#  include <sys/stat.h>
#  include <sys/types.h>
#  include <fcntl.h>
#  include <unistd.h>
#  if !defined(__ANDROID__)
#    include <execinfo.h>
#  endif
#endif

#if !defined(_WIN32)
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

#if defined(_WIN32)
static volatile LONG seiun_crash_written = 0;

static const char* seiun_exception_name(unsigned long code)
{
	switch (code)
	{
		case 0xC0000005UL: return "ACCESS_VIOLATION";
		case 0xC0000006UL: return "IN_PAGE_ERROR";
		case 0xC000000DUL: return "ILLEGAL_INSTRUCTION";
		case 0xC0000094UL: return "INTEGER_DIVIDE_BY_ZERO";
		case 0xC0000095UL: return "INTEGER_OVERFLOW";
		case 0xC00000FDUl: return "STACK_OVERFLOW";
		case 0xC0000409UL: return "STACK_BUFFER_OVERRUN";
		case 0x80000003UL: return "BREAKPOINT";
		case 0xC0000135UL: return "DLL_NOT_FOUND";
		default: return "UNKNOWN";
	}
}

static LONG WINAPI seiun_seh_handler(EXCEPTION_POINTERS* info)
{
	if (InterlockedCompareExchange(&seiun_crash_written, 1, 0) != 0)
		return EXCEPTION_CONTINUE_SEARCH;

	if (info == NULL || info->ExceptionRecord == NULL)
		return EXCEPTION_CONTINUE_SEARCH;

	EXCEPTION_RECORD* er = info->ExceptionRecord;
	char body[4096];
	int len = 0;
	len += snprintf(body + len, sizeof(body) - len, "Native crash (Windows Structured Exception Handling)\n");
	len += snprintf(body + len, sizeof(body) - len, "Exception code: 0x%08lX (%s)\n",
		(unsigned long)er->ExceptionCode, seiun_exception_name(er->ExceptionCode));
	len += snprintf(body + len, sizeof(body) - len, "Exception flags: 0x%08lX\n", (unsigned long)er->ExceptionFlags);
	len += snprintf(body + len, sizeof(body) - len, "Exception address (faulting instruction pointer): 0x%p\n",
		(void*)er->ExceptionAddress);
	HMODULE mod = NULL;
	char modName[300] = "?";
	if (GetModuleHandleExA(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
		(LPCSTR)er->ExceptionAddress, &mod))
	{
		GetModuleFileNameA(mod, modName, sizeof(modName));
	}
	len += snprintf(body + len, sizeof(body) - len, "Faulting module: %s\n", modName);
	len += snprintf(body + len, sizeof(body) - len, "Exception parameters: %lu\n", (unsigned long)er->NumberParameters);
	for (DWORD i = 0; i < er->NumberParameters && i < 2; i++)
	{
		len += snprintf(body + len, sizeof(body) - len, "  param[%lu]: 0x%p (ACCESS_VIOLATION: 0=read,1=write,8=exec / faulting address)\n",
			(unsigned long)i, (void*)er->ExceptionInformation[i]);
	}
	if (info->ContextRecord != NULL)
	{
		CONTEXT* c = info->ContextRecord;
#if defined(_M_X64) || defined(__x86_64__)
		len += snprintf(body + len, sizeof(body) - len, "Registers (x64):\n");
		len += snprintf(body + len, sizeof(body) - len, "  RIP=0x%016llX RSP=0x%016llX RBP=0x%016llX\n",
			(unsigned long long)c->Rip, (unsigned long long)c->Rsp, (unsigned long long)c->Rbp);
		len += snprintf(body + len, sizeof(body) - len, "  RAX=0x%016llX RBX=0x%016llX RCX=0x%016llX RDX=0x%016llX\n",
			(unsigned long long)c->Rax, (unsigned long long)c->Rbx, (unsigned long long)c->Rcx, (unsigned long long)c->Rdx);
		len += snprintf(body + len, sizeof(body) - len, "  RSI=0x%016llX RDI=0x%016llX R8=0x%016llX  R9=0x%016llX\n",
			(unsigned long long)c->Rsi, (unsigned long long)c->Rdi, (unsigned long long)c->R8, (unsigned long long)c->R9);
		len += snprintf(body + len, sizeof(body) - len, "  R10=0x%016llX R11=0x%016llX R12=0x%016llX R13=0x%016llX\n",
			(unsigned long long)c->R10, (unsigned long long)c->R11, (unsigned long long)c->R12, (unsigned long long)c->R13);
		len += snprintf(body + len, sizeof(body) - len, "  R14=0x%016llX R15=0x%016llX\n",
			(unsigned long long)c->R14, (unsigned long long)c->R15);
#elif defined(_M_IX86) || defined(__i386__)
		len += snprintf(body + len, sizeof(body) - len, "Registers (x86):\n");
		len += snprintf(body + len, sizeof(body) - len, "  EIP=0x%08X ESP=0x%08X EBP=0x%08X\n",
			(unsigned int)c->Eip, (unsigned int)c->Esp, (unsigned int)c->Ebp);
		len += snprintf(body + len, sizeof(body) - len, "  EAX=0x%08X EBX=0x%08X ECX=0x%08X EDX=0x%08X\n",
			(unsigned int)c->Eax, (unsigned int)c->Ebx, (unsigned int)c->Ecx, (unsigned int)c->Edx);
		len += snprintf(body + len, sizeof(body) - len, "  ESI=0x%08X EDI=0x%08X\n",
			(unsigned int)c->Esi, (unsigned int)c->Edi);
#elif defined(_M_ARM64)
		len += snprintf(body + len, sizeof(body) - len, "Registers (ARM64):\n");
		len += snprintf(body + len, sizeof(body) - len, "  PC=0x%016llX SP=0x%016llX\n",
			(unsigned long long)c->Pc, (unsigned long long)c->Sp);
#endif
	}
	char path[512];
	seiun_crash_path(path, sizeof(path));
	FILE* f = fopen(path, "w");
	if (f != NULL)
	{
		fprintf(f, "SeiunEngine native crash recorded (%s)\n", path);
		fputs(body, f);
		fclose(f);
	}
	return EXCEPTION_CONTINUE_SEARCH;
}

#else
static volatile sig_atomic_t seiun_crash_written = 0;

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
	len += snprintf(body + len, sizeof(body) - len, "Native crash (POSIX signal)\n");
	len += snprintf(body + len, sizeof(body) - len, "Signal: %d - %s, si_code=%d\n", sig, seiun_signal_name(sig), si ? si->si_code : 0);
	len += snprintf(body + len, sizeof(body) - len, "Fault address (si_addr, memory pointer): 0x%p\n", si ? si->si_addr : (void*)0);
#if !defined(__ANDROID__)
	len += snprintf(body + len, sizeof(body) - len, "Backtrace:\n");
#endif
	char path[512];
	seiun_crash_path(path, sizeof(path));
	int fd = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0644);
	if (fd >= 0)
	{
		const char* head = "SeiunEngine native crash recorded\n";
		write(fd, head, strlen(head));
		write(fd, body, (size_t)len);
#if !defined(__ANDROID__)
		void* bt[64];
		int n = backtrace(bt, 64);
		backtrace_symbols_fd(bt, n, fd);
#endif
		close(fd);
	}
	signal(sig, SIG_DFL);
	raise(sig);
}

#endif

static void seiun_install_native_crash_hooks()
{
#if defined(_WIN32)
	SetUnhandledExceptionFilter(seiun_seh_handler);
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
