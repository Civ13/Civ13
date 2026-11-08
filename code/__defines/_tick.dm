/// Tick limit while running normally
#define TICK_BYOND_RESERVE 2
#define TICK_LIMIT_RUNNING 90
/// Tick limit used to resume things in stoplag
#define TICK_LIMIT_TO_RUN 85
/// Tick limit for MC while running
#define TICK_LIMIT_MC 70
/// Tick limit while initializing
#define TICK_LIMIT_MC_INIT_DEFAULT (100 - TICK_BYOND_RESERVE)

/// for general usage of tick_usage
#define TICK_USAGE world.tick_usage
/// to be used where the result isn't checked
#define TICK_USAGE_REAL world.tick_usage

/// Sleeps via stoplag() when tick_usage is above the limit and returns TRUE if it slept.
/// Unlike /tg/ and CM, callers here rely on this sleeping, so it is not a pure check.
#define TICK_CHECK ( world.tick_usage > TICK_LIMIT_RUNNING ? stoplag() : 0 )
/// Runs stoplag once if tick_usage is above the limit. (Wrapping TICK_CHECK
/// here used to sleep twice per yield, because TICK_CHECK already sleeps.)
#define CHECK_TICK ( world.tick_usage > TICK_LIMIT_RUNNING ? stoplag() : 0 )

/// Returns true if tick usage is above 95, for high priority usage
#define TICK_CHECK_HIGH_PRIORITY ( TICK_USAGE > 95 )
/// runs stoplag if tick_usage is above 95, for high priority usage
#define CHECK_TICK_HIGH_PRIORITY ( TICK_CHECK_HIGH_PRIORITY? stoplag() : 0 )