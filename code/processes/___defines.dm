// Process status defines
#define PROCESS_STATUS_IDLE 1
#define PROCESS_STATUS_QUEUED 2
#define PROCESS_STATUS_RUNNING 3
#define PROCESS_STATUS_MAYBE_HUNG 4
#define PROCESS_STATUS_PROBABLY_HUNG 5
#define PROCESS_STATUS_HUNG 6

// Process time thresholds
#define PROCESS_DEFAULT_HANG_WARNING_TIME 	300 // 30 seconds
#define PROCESS_DEFAULT_HANG_ALERT_TIME 	600 // 60 seconds
#define PROCESS_DEFAULT_HANG_RESTART_TIME 	900 // 90 seconds
#define PROCESS_DEFAULT_SCHEDULE_INTERVAL 	50  // 50 ticks
#define PROCESS_DEFAULT_SLEEP_INTERVAL		8	// 2 ticks

// Process priorities
#define PROCESS_PRIORITY_VERY_HIGH 1
#define PROCESS_PRIORITY_HIGH 2
#define PROCESS_PRIORITY_MEDIUM 3
#define PROCESS_PRIORITY_LOW 4
#define PROCESS_PRIORITY_VERY_LOW 5

// PROCESS_PRIORITY_IRRELEVANT: we don't process or don't use loops, meaning PROCESS_TICK_CHECK never happens
#define PROCESS_PRIORITY_IRRELEVANT 6

// Used to indicate that the process was going for too long and had to return early
#define PROCESS_TICK_CHECK_RETURNED_EARLY 1234

// this uses world.timeofday because world.time doesn't work
// processes with priority VERY_HIGH use hacks here to run smoother (movement, throwing), similar to the old subsystems
// A reset during a yielding fire() (world load, process restart) nulls current_list mid-loop.
#define PROCESS_LIST_CHECK if (priority != PROCESS_PRIORITY_VERY_HIGH && islist(current_list)) current_list -= current
// Absolute tick ceiling for scheduled work: leave room for BYOND to send the map
// (world.map_cpu is the last tick's map-send cost) and for verbs, as CM-SS13 and
// /tg/ do. Running past ~100% of a tick is what shows up as time dilation.
#define PROCESS_TICK_CEILING max(40, min(80, 95 - world.map_cpu))
#define PROCESS_TICK_CHECK if (priority != PROCESS_PRIORITY_VERY_HIGH && (world.tick_usage - run_time_tick_usage >= run_time_tick_usage_allowance || world.tick_usage >= max(40, min(80, 95 - world.map_cpu)))) return PROCESS_TICK_CHECK_RETURNED_EARLY
#define PROCESS_USE_FASTEST_LIST(list) if (priority == PROCESS_PRIORITY_VERY_HIGH) { current_list = list; } else { current_list = null; current_list = list:Copy(); }
