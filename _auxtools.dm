// 515 split call for external libraries into call_ext
#if DM_VERSION < 515
#define LIBCALL call
#else
#define LIBCALL call_ext
#endif
#define WEBCLIENT_PATCHES (world.system_type == MS_WINDOWS ? "webclient_patches.dll" : "libwebclient_patches.so")

// Taken from FarWeb

/proc/auxtools_stack_trace(msg)
	CRASH(msg)

/proc/enable_debugging(mode, port)
	CRASH("auxtools not loaded")

/world/New()
	var/debug_server = world.GetConfig("env", "AUXTOOLS_DEBUG_DLL")
	if (debug_server)
		LIBCALL(debug_server, "auxtools_init")()
		enable_debugging()
	. = ..()

/world/Del()
	if(fexists(WEBCLIENT_PATCHES))
		call(WEBCLIENT_PATCHES, "remove_webclient_patches")()
	var/debug_server = world.GetConfig("env", "AUXTOOLS_DEBUG_DLL")
	if (debug_server)
		LIBCALL(debug_server, "auxtools_shutdown")()
	. = ..()

/proc/auxtools_expr_stub()