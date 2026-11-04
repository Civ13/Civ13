GLOBAL_VAR_INIT(total_runtimes, 0)
GLOBAL_VAR_INIT(total_runtimes_skipped, 0)

#ifdef USE_CUSTOM_ERROR_HANDLER
#define ERROR_USEFUL_LEN 2

#undef ERROR_USEFUL_LEN
#endif
