#define TRUE 1
#define FALSE 0
#define TimeOfGame world.timeofday
#define PROCESS_PRIORITY_VERY_HIGH 1
#define PROCESS_PRIORITY_IRRELEVANT 6
var/failures = 0
var/checks = 0
var/sleepers_pending = 0
var/sleepers_peak = 0
var/datum/process_group/processes = new
/datum/process_group
/processScheduler
	var/list/processes = list()
	var/list/priority_ordered_processes = list()
	var/list/last_twenty_run_times = list()
	var/list/highest_run_time = list()
	var/list/last_run_time = list()
	var/list/run_token
	var/isRunning = FALSE
	var/scheduler_sleep_interval = 1
	var/last_process = -1
	var/list/cadences = list()
/processScheduler/proc/updateStartDelays()
	return
/processScheduler/proc/checkRunningProcesses()
	var/key = "[world.time]"
	cadences[key]++
/processScheduler/proc/queueProcesses()
	return
/processScheduler/proc/runQueuedProcesses()
	return
/processScheduler/proc/processStarted(process/P)
	P.started_hooks++
/processScheduler/proc/maximum_cadence()
	var/value = 0
	for (var/key in cadences)
		value = max(value, cadences[key])
	return value
/process
	var/processScheduler/main
	var/schedule_interval = 4
	var/runtime_history_reset_at = 0
	var/run_start = 0
	var/priority = 3
	var/running_hooks = 0
	var/started_hooks = 0
	var/onstart_hooks = 0
/process/proc/running()
	running_hooks++
/process/proc/onStart()
	onstart_hooks++
/proc/check(condition, label)
	checks++
	if (!condition)
		failures++
		world.log << "FAIL [label]"
/world
	fps = 10
/world/OpenPort(port)
	if (port == "none") return ..()
	return FALSE
/world/Error(exception/E)
	world.log << "RUNTIME [E]"
	failures++
/world/New()
	OpenPort("none")
	spawn(0)
		run_tests()
/proc/run_tests()
	check(!world.port && !world.OpenPort(12345), "isolated closed port")
	var/processScheduler/S = new
	S.start()
	S.start()
	sleep(5)
	var/repeated_max = S.maximum_cadence()
	check(S.cadences.len >= 4 && repeated_max == 1, "repeated start has one scheduler cadence")
	S.stop()
	sleep(2)
	var/stopped_count = S.cadences.len
	sleep(2)
	check(S.cadences.len == stopped_count, "stopped scheduler remains stopped")
	S.cadences = list()
	S.start()
	sleep(1)
	S.stop()
	S.start()
	sleep(5)
	var/restart_max = S.maximum_cadence()
	check(restart_max == 1, "stop restart cancels previous sleeping chain")
	S.cadences = list()
	S.start()
	sleep(5)
	var/watchdog_max = S.maximum_cadence()
	check(watchdog_max == 1, "watchdog start replaces active scheduler chain")
	S.stop()
	sleep(2)
	check(!S.isRunning, "scheduler stop state")
	var/process/P = new
	P.main = S
	S.last_twenty_run_times[P] = list(20)
	S.highest_run_time[P] = 20
	check(!P.may_run(10), "expensive process initially deferred")
	sleep(2)
	for (var/i in 1 to 1000)
		P.may_run(10)
	var/denial_sleepers = sleepers_pending
	check(denial_sleepers <= 1, "repeated denial creates no callback backlog")
	sleep(3)
	check(P.may_run(10), "denials do not postpone original expiry")
	var/list/history = S.last_twenty_run_times[P]
	check(!history.len, "expired history clears only on admission query")
	sleep(5)
	check(!sleepers_pending, "instrumented old callbacks have all completed")
	P.runtime_history_reset_at = 0
	S.last_twenty_run_times[P] = list(20)
	check(!P.may_run(10), "new expensive history can defer again")
	// Actual successful admission may bypass may_run (first queued process).
	P.started()
	S.recordRunTime(P, 20)
	sleep(5)
	P.may_run(10)
	history = S.last_twenty_run_times[P]
	check(history.len == 2 && history[history.len] == 20, "successful bypass run history survives old deadline")
	check(P.running_hooks == 1 && P.started_hooks == 1 && P.onstart_hooks == 1 && P.run_start, "started hooks and timing preserved")
	S.last_twenty_run_times[P] = list()
	for (var/i in 1 to 50)
		S.recordRunTime(P, i)
	history = S.last_twenty_run_times[P]
	check(history.len == 20 && history[1] == 31 && history[20] == 50, "runtime history remains bounded")
	world.log << "METRICS repeated_cadence_max=[repeated_max] restart_cadence_max=[restart_max] watchdog_cadence_max=[watchdog_max] denial_pending_callbacks=[denial_sleepers] instrumented_peak_callbacks=[sleepers_peak]"
	text2file(json_encode(list("checks" = checks, "failures" = failures, "repeated_cadence_max" = repeated_max, "restart_cadence_max" = restart_max, "watchdog_cadence_max" = watchdog_max, "denial_pending_callbacks" = denial_sleepers, "instrumented_peak_callbacks" = sleepers_peak)), "native-result.json")
	world.log << "DONE [checks] checks [failures] failures"
	del(world)
