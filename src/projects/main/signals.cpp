//==============================================================================
//
//  OvenMediaEngine
//
//  Created by Hyunjun Jang
//  Copyright (c) 2019 AirenSoft. All rights reserved.
//
//==============================================================================
#include "./signals.h"

#include <base/ovlibrary/ovlibrary.h>
#include <config/config_manager.h>
#include <malloc.h>
#include <orchestrator/orchestrator.h>
#include <signal.h>
#include <sys/ucontext.h>
#include <sys/utsname.h>

#include <fstream>
#include <iostream>

#include "./main_private.h"
#include "./third_parties.h"
#include "main.h"

// 1 == true, 0 == false
volatile sig_atomic_t g_is_terminated;

#define SIGNAL_CASE(x) \
	case x:            \
		return #x;

namespace ov::sig
{
	namespace
	{
		// Occasionally, the memory can become corrupted and the version may not be displayed.
		// In such cases, it is stored in a separate variable for later reference.
		//
		// This variable contains strings in the format of "v0.1.2 (v0.1.2-xxx-yyyy) [debug]".
		char g_ome_version[1024];
		char g_dump_fallback_directory[PATH_MAX];

		// Configure for SIGRT* to use jemalloc
#ifdef OME_USE_JEMALLOC
		// SIGRTMIN+0: Show jemalloc stats
		int SIG_JEMALLOC_SHOW_STATS	  = (SIGRTMIN + 0);
		// SIGRTMIN+1: Trigger dump (This only works when `OME_USE_JEMALLOC_PROFILE` is defined)
		int SIG_JEMALLOC_TRIGGER_DUMP = (SIGRTMIN + 1);
#endif	// OME_USE_JEMALLOC

		using OV_SIG_ACTION = void (*)(int signum, siginfo_t *si, void *unused);

		// http://man7.org/linux/man-pages/man7/signal.7.html
		const char *GetSignalName(int signum)
		{
			switch (signum)
			{
				SIGNAL_CASE(SIGABRT);
				SIGNAL_CASE(SIGALRM);
				SIGNAL_CASE(SIGBUS);
				SIGNAL_CASE(SIGCHLD);
				SIGNAL_CASE(SIGCONT);
				SIGNAL_CASE(SIGFPE);
				SIGNAL_CASE(SIGHUP);
				SIGNAL_CASE(SIGILL);
				SIGNAL_CASE(SIGINT);
				SIGNAL_CASE(SIGKILL);
				SIGNAL_CASE(SIGPIPE);
				SIGNAL_CASE(SIGPROF);
				SIGNAL_CASE(SIGQUIT);
				SIGNAL_CASE(SIGSEGV);
				SIGNAL_CASE(SIGSTOP);
				SIGNAL_CASE(SIGSYS);
				SIGNAL_CASE(SIGTERM);
				SIGNAL_CASE(SIGTRAP);
				SIGNAL_CASE(SIGTSTP);
				SIGNAL_CASE(SIGTTIN);
				SIGNAL_CASE(SIGTTOU);
				SIGNAL_CASE(SIGURG);
				SIGNAL_CASE(SIGUSR1);
				SIGNAL_CASE(SIGUSR2);
				SIGNAL_CASE(SIGVTALRM);
				SIGNAL_CASE(SIGWINCH);
				SIGNAL_CASE(SIGXCPU);
				SIGNAL_CASE(SIGXFSZ);

#if IS_LINUX
				SIGNAL_CASE(SIGPOLL);
				SIGNAL_CASE(SIGPWR);
				SIGNAL_CASE(SIGSTKFLT);
#endif	// IS_LINUX

#if IS_MACOS
				// Apple OSX and iOS (Darwin)
				SIGNAL_CASE(SIGEMT);
				SIGNAL_CASE(SIGIO);
				SIGNAL_CASE(SIGINFO);
#endif	// IS_MACOS

				default:
					return "UNKNOWN";
			}
		}

		template <typename... SigNums>
		bool RegisterSignals(OV_SIG_ACTION action, int sig, SigNums... sigs)
		{
			struct sigaction sa{};

			sa.sa_flags = SA_SIGINFO;

			// sigemptyset is a macro on macOS, so :: breaks compilation
#if defined(__APPLE__)
			sigemptyset(&sa.sa_mask);
#else
			::sigemptyset(&sa.sa_mask);
#endif

			sa.sa_sigaction = action;

			return (::sigaction(sig, &sa, nullptr) == 0) &&
				   ((::sigaction(static_cast<int>(sigs), &sa, nullptr) == 0) && ...);
		}

		namespace handlers
		{
			// Handler for abort signals
			//
			// Intentional signals (ignore)
			//     SIGABRT, SIGSEGV, SIGBUS, SIGILL, SIGFPE,
			//     SIGSYS, SIGXCPU, SIGXFSZ, SIGPOLL
			void Abort(int signum, siginfo_t *si, void *context)
			{
				char time_buffer[30]{};
				String file_name(PATH_MAX);
				time_t t			   = ::time(nullptr);

				const auto pid		   = Platform::GetProcessId();
				const auto tid		   = Platform::GetThreadId();
				const auto thread_name = Platform::GetThreadName();

				utsname uts{};
				::uname(&uts);

				// Ensure that the version string is not corrupted.
				g_ome_version[OV_COUNTOF(g_ome_version) - 1] = '\0';
				logtc("OME %s received signal %d (%s), interrupt.", g_ome_version, signum, GetSignalName(signum));
				logtc("- PID: %lu, OS: %s %s - %s, %s", pid, uts.sysname, uts.machine, uts.release, uts.version);

				// Exclude AbortHandler() from the stack trace
				const auto stack_trace = StackTrace::GetStackTrace(1);
				logtc("- Stack trace\n%s", stack_trace.CStr());

				const auto registers = StackTrace::GetRegisters(reinterpret_cast<const ucontext_t *>(context));
				logtc("- Registers\n%s", registers.CStr());

				// Ensure that g_dump_path is not corrupted.
				g_dump_fallback_directory[OV_COUNTOF(g_dump_fallback_directory) - 1] = '\0';

				std::tm local_time{};
				::localtime_r(&t, &local_time);

				std::ofstream ostream;

				{
					const char *file_prefix = "dumps/";
					bool fallback			= false;

					::strftime(time_buffer, OV_COUNTOF(time_buffer), "crash_%Y%m%d.dump", &local_time);

					file_name = file_prefix;
					file_name.Append(time_buffer);

					if (::mkdir(file_prefix, 0755) != 0)
					{
						if (errno != EEXIST)
						{
							logtc("Could not create a directory for crash dump: %s, use the fallback directory instead: %s",
								  file_prefix,
								  g_dump_fallback_directory);

							fallback = true;
						}
					}

					if (fallback == false)
					{
						auto stream = std::ofstream(file_name, std::ofstream::app);

						if (stream.is_open())
						{
							ostream = std::move(stream);
						}
						else
						{
							logte("Could not open dump file to write: %s, use the fallback directory instead: %s",
								  file_name.CStr(),
								  g_dump_fallback_directory);

							fallback = true;
						}
					}

					if (fallback)
					{
						file_prefix = g_dump_fallback_directory;

						file_name	= file_prefix;
						file_name.Append(time_buffer);

						ostream = std::ofstream(file_name, std::ofstream::app);

						if (ostream.is_open() == false)
						{
							logte("Could not open dump file to write: %s", file_name.CStr());
						}
					}
				}

				if (ostream.is_open())
				{
					::strftime(time_buffer, OV_COUNTOF(time_buffer), "%Y-%m-%dT%H:%M:%S%z", &local_time);

					ostream << "***** Crash dump *****" << std::endl;
					ostream << "OvenMediaEngine " << g_ome_version << " received signal " << signum << " (" << GetSignalName(signum) << ")" << std::endl;
					ostream << "- OS: " << uts.sysname << " " << uts.machine << " - " << uts.release << ", " << uts.version << std::endl;
					ostream << "- Time: " << time_buffer << ", PID: " << pid << ", TID: " << tid << " (" << thread_name << ")" << std::endl;

					ostream << "- Stack trace" << std::endl;
					ostream << stack_trace << std::endl;

					ostream << "- Registers" << std::endl;
					ostream << registers << std::endl;

					std::ifstream istream("/proc/self/maps", std::ifstream::in);

					if (istream.is_open())
					{
						ostream << "- Module maps" << std::endl;
						ostream << istream.rdbuf();
					}
					else
					{
						ostream << "(Could not read module maps)" << std::endl;
					}

					// need not call fstream::close() explicitly to close the file
				}

				::exit(signum);
			}

			// WARNING: USE THIS SIGNAL FOR DEBUGGING PURPOSE ONLY
			void SigUsr1(int signum, siginfo_t *si, void *ctx)
			{
				logtc("Trim result: %d", ::malloc_trim(0));
			}

			void SigHup(int signum, siginfo_t *si, void *unused)
			{
				logti("Received SIGHUP signal. This signal is not implemented yet.");
				return;

				// logti("Trying to reload configuration...");

				// auto config_manager = cfg::ConfigManager::GetInstance();

				// try
				// {
				// 	config_manager->ReloadConfigs();
				// }
				// catch (const cfg::ConfigError &error)
				// {
				// 	logte("An error occurred while reload configuration: %s", error.What());
				// 	return;
				// }

				// logti("Trying to apply OriginMap to Orchestrator...");

				// std::vector<info::Host> host_info_list;
				// // Create info::Host
				// auto server_config = config_manager->GetServer();
				// auto hosts = server_config->GetVirtualHostList();
				// for (const auto &host : hosts)
				// {
				// 	host_info_list.emplace_back(info::Host(server_config->GetName(), server_config->GetID(), host));
				// }

				// if (ocst::Orchestrator::GetInstance()->UpdateVirtualHosts(host_info_list) == false)
				// {
				// 	logte("Could not reload OriginMap");
				// }
			}

			void SigTerm(int signum, siginfo_t *si, void *unused)
			{
				logtw("Caught terminate signal %d. OME is terminating...", signum);
				g_is_terminated = 1;
			}

			void SigInt(int signum, siginfo_t *si, void *unused)
			{
				static constexpr int TERMINATE_COUNT = 3;
				static int signal_count				 = 0;

				signal_count++;

				if (signal_count == TERMINATE_COUNT)
				{
					logtc("The termination request has been made %d times by signal %d. OME is forcibly terminated.", TERMINATE_COUNT, signum);
					::exit(1);
				}
				else
				{
					logtc("Caught terminate signal %d. Trying to terminating... (Repeat %d more times to forcibly terminate)", signum, (TERMINATE_COUNT - signal_count));
				}

				g_is_terminated = 1;
			}

#ifdef OME_USE_JEMALLOC
			void SigRt(int signum, siginfo_t *si, void *unused)
			{
				(void)si;
				(void)unused;

				if (signum == SIG_JEMALLOC_SHOW_STATS)
				{
					logtc("Jemalloc stats signal received.");
					JemallocShowStats();
				}
				else if (signum == SIG_JEMALLOC_TRIGGER_DUMP)
				{
					logtc("Jemalloc dump trigger signal received.");
					JemallocTriggerDump();
				}
			}
#endif	// OME_USE_JEMALLOC
		}  // namespace handlers

		bool InitializeInternal()
		{
			//	 1) SIGHUP		 2) SIGINT		 3) SIGQUIT		 4) SIGILL		 5) SIGTRAP
			//	 6) SIGABRT		 7) SIGBUS		 8) SIGFPE		 9) SIGKILL		10) SIGUSR1
			//	11) SIGSEGV		12) SIGUSR2		13) SIGPIPE		14) SIGALRM		15) SIGTERM
			//	16) SIGSTKFLT	17) SIGCHLD		18) SIGCONT		19) SIGSTOP		20) SIGTSTP
			//	21) SIGTTIN		22) SIGTTOU		23) SIGURG		24) SIGXCPU		25) SIGXFSZ
			//	26) SIGVTALRM	27) SIGPROF		28) SIGWINCH	29) SIGIO		30) SIGPWR
			//	31) SIGSYS		34) SIGRTMIN	35) SIGRTMIN+1	36) SIGRTMIN+2	37) SIGRTMIN+3
			//	38) SIGRTMIN+4	39) SIGRTMIN+5	40) SIGRTMIN+6	41) SIGRTMIN+7	42) SIGRTMIN+8
			//	43) SIGRTMIN+9	44) SIGRTMIN+10	45) SIGRTMIN+11	46) SIGRTMIN+12	47) SIGRTMIN+13
			//	48) SIGRTMIN+14	49) SIGRTMIN+15	50) SIGRTMAX-14	51) SIGRTMAX-13	52) SIGRTMAX-12
			//	53) SIGRTMAX-11	54) SIGRTMAX-10	55) SIGRTMAX-9	56) SIGRTMAX-8	57) SIGRTMAX-7
			//	58) SIGRTMAX-6	59) SIGRTMAX-5	60) SIGRTMAX-4	61) SIGRTMAX-3	62) SIGRTMAX-2
			//	63) SIGRTMAX-1	64) SIGRTMAX

			g_is_terminated = 0;

			::memset(g_ome_version, 0, sizeof(g_ome_version));
			::strncpy(g_ome_version, info::OmeVersion::GetInstance()->ToString().CStr(), OV_COUNTOF(g_ome_version) - 1);

			SetDumpFallbackPath(::ov_log_get_path());

#ifdef OME_USE_JEMALLOC
			bool use_jemalloc_signal = true;

			if (SIG_JEMALLOC_TRIGGER_DUMP >= SIGRTMAX)
			{
				logtc("Cannot initialize SIGRT handler for jemalloc: `SIGRTMAX` is too small.");
				use_jemalloc_signal = false;
			}
#endif	// OME_USE_JEMALLOC

			return RegisterSignals(
					   handlers::Abort,
					   // Core dumped signal
					   SIGABRT,	 // assert(), raise(), abort()
					   SIGSEGV,	 // illegal memory access
					   SIGBUS,	 // illegal memory access
					   SIGILL,	 // execute a malformed instruction.
					   SIGFPE,	 // divide by zero
					   SIGSYS,	 // bad system call
					   SIGXCPU,	 // cpu time limit exceeded
					   SIGXFSZ,	 // file size limit exceeded

					   // Terminated signal
					   SIGPIPE	// write on a pipe with no one to read it
#if IS_LINUX
					   ,
					   SIGPOLL	// pollable event

#endif	// IS_LINUX
					   ) &&
				   // WARNING: USE THIS SIGNAL FOR DEBUGGING PURPOSE ONLY
				   RegisterSignals(handlers::SigUsr1, SIGUSR1) &&
#ifdef OME_USE_JEMALLOC
				   (use_jemalloc_signal
						? RegisterSignals(handlers::SigRt, SIG_JEMALLOC_SHOW_STATS, SIG_JEMALLOC_TRIGGER_DUMP)
						: true) &&
#endif	// OME_USE_JEMALLOC
				   RegisterSignals(handlers::SigHup, SIGHUP) &&
				   RegisterSignals(handlers::SigTerm, SIGTERM) &&
				   RegisterSignals(handlers::SigInt, SIGINT);
		}

		void SetDumpFallbackPathInternal(const char *path)
		{
			static constexpr auto BUFFER_COUNT = OV_COUNTOF(g_dump_fallback_directory);

			::memset(g_dump_fallback_directory, 0, sizeof(g_dump_fallback_directory));
			::strncpy(g_dump_fallback_directory, path, BUFFER_COUNT - 1);

			if (g_dump_fallback_directory[0] != '\0')
			{
				::strncat(g_dump_fallback_directory, "/", BUFFER_COUNT - 1);
			}
			else
			{
				// No fallback path is set, so use the current directory
			}

			// To prevent overflow where memory is corrupt, add a null character explicitly to work as well as possible
			g_dump_fallback_directory[BUFFER_COUNT - 1] = '\0';
		}
	}  // namespace

	bool Initialize()
	{
		return InitializeInternal();
	}

	void SetDumpFallbackPath(const char *path)
	{
		SetDumpFallbackPathInternal(path);
	}
}  // namespace ov::sig
