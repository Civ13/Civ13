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
/processScheduler/proc/processFinished(process/P)
	return
/processScheduler/proc/maximum_cadence()
	var/value = 0
	for (var/key in cadences)
		value = max(value, cadences[key])
	return value
/process
	var/processScheduler/main
	var/ticks = 0
	var/current
	var/list/current_list
	var/run_time_tick_usage = 0
	var/run_time_tick_usage_allowance = -1
	var/schedule_interval = 4
	var/runtime_history_reset_at = 0
	var/run_start = 0
	var/priority = 3
	var/running_hooks = 0
	var/started_hooks = 0
	var/onstart_hooks = 0
/process/proc/running()
	running_hooks++
/process/proc/idle()
	return
/process/proc/onFinish()
	return
/process/budget_probe/proc/fire()
	for (current in current_list)
		PROCESS_LIST_CHECK
		PROCESS_TICK_CHECK
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
	// Use the actual production macros with a deterministic negative allowance:
	// removing the final entry must not leave an empty snapshot for the next run.
	var/process/budget_probe/B = new
	B.main = S
	B.current_list = list("only")
	var/fire_result = B.fire()
	check(fire_result == PROCESS_TICK_CHECK_RETURNED_EARLY && !B.current_list.len, "actual final-entry tick check returns early")
	B.finished(fire_result)
	check(isnull(B.current_list) && isnull(B.current), "final-entry budget return releases exhausted snapshot")
	B.current_list = list("first", "pending")
	fire_result = B.fire()
	B.finished(fire_result)
	check(fire_result == PROCESS_TICK_CHECK_RETURNED_EARLY && B.current_list.len == 1 && B.current_list[1] == "pending", "nonempty budget snapshot remains resumable")
	var/list/live_list = list("one", "two")
	B.priority = PROCESS_PRIORITY_VERY_HIGH
	B.current_list = live_list
	fire_result = B.fire()
	B.finished(fire_result)
	check(isnull(B.current_list) && live_list.len == 2 && live_list[1] == "one" && live_list[2] == "two", "VERY_HIGH completion preserves aliased live list")
	world.log << "METRICS repeated_cadence_max=[repeated_max] restart_cadence_max=[restart_max] watchdog_cadence_max=[watchdog_max] denial_pending_callbacks=[denial_sleepers] instrumented_peak_callbacks=[sleepers_peak]"
	text2file(json_encode(list("checks" = checks, "failures" = failures, "repeated_cadence_max" = repeated_max, "restart_cadence_max" = restart_max, "watchdog_cadence_max" = watchdog_max, "denial_pending_callbacks" = denial_sleepers, "instrumented_peak_callbacks" = sleepers_peak)), "native-result.json")
	world.log << "DONE [checks] checks [failures] failures"
	del(world)
