#define TRUE 1
#define FALSE 0
var/list/living_mob_list = list()
var/failures = 0
/proc/check(condition, message)
	if(!condition)
		failures++
		world.log << "FAIL [message]"
/process
	var/ticks = 0
	var/current
	var/list/current_list
	var/processScheduler/main = new
	var/finish_seen = 0
	var/hook_remaining = 1
	var/disabled = FALSE
	var/paused = FALSE
	var/last_fire_as_member = 0
	var/run_time_tick_usage = 0
	var/run_time_tick_usage_allowance = -1
	var/list/visited = list()
	var/resets = 0
	var/priority = PROCESS_PRIORITY_HIGH
	var/always_runs = FALSE
	var/run_failures = 0
/process/proc/idle()
	return
/process/proc/started()
	return
/process/proc/may_fire()
	return TRUE
/process/proc/onFinish()
	check(current && current_list && current_list.len == hook_remaining, "finish hook observes run references")
	finish_seen++
/process/proc/fire()
	if(!current_list || !current_list.len)
		return TRUE
	current = current_list[1]
	visited += current
	current_list.Cut(1,2)
	hook_remaining = current_list.len
	if(current_list.len)
		return PROCESS_TICK_CHECK_RETURNED_EARLY
	return TRUE
/process/proc/reset_current_list()
	return
/process/proc/may_run(allowance)
	return FALSE
/proc/calculate_run_time_allowance(priority)
	return 10
/processScheduler
	var/list/processes = list()
	var/list/priority_ordered_processes = list()
	var/list/queued = list()
	var/isRunning = FALSE
	var/scheduler_sleep_interval = 0
	var/start_seen = 0
/processScheduler/proc/updateStartDelays()
	return
/processScheduler/proc/process()
	start_seen++
/processScheduler/proc/processFinished(process/P)
	check(P.current && P.current_list && P.current_list.len == P.hook_remaining, "scheduler hook observes run references")
/world/OpenPort(port)
	if(port == "none")
		return ..()
	return FALSE
/world/New()
	world.OpenPort("none")
	var/datum/member = new
	var/list/registry = list(member)
	var/process/P = new /process/mob
	P.current = member
	P.current_list = registry.Copy()
	P.finished()
	check(!P.current && !P.current_list, "copied snapshot and iterator released")
	check(P.ticks == 1 && P.finish_seen == 1, "completion accounting preserved")
	P.current = member
	P.current_list = registry
	P.finished()
	check(!P.current && !P.current_list, "aliased snapshot and iterator released")
	check(registry.len == 1 && registry[1] == member, "aliased registry membership preserved")

	P = new /process/mob
	var/datum/second = new
	var/datum/third = new
	registry = list(member, second, third)
	living_mob_list = registry
	P.reset_current_list()
	var/list/pending = list(P)
	P.main.relayProcess(P,pending)
	check(P.current_list && P.current_list.len == 2 && pending.len == 1 && P.resets == 1, "budgeted snapshot retained for next pass")
	if(P.current_list && P.current_list.len == 2)
		P.main.relayProcess(P,pending)
		check(P.current_list && P.current_list.len == 1 && pending.len == 1 && P.resets == 1, "second budgeted pass preserves remaining entry")
		P.main.relayProcess(P,pending)
		check(P.visited.len == 3 && P.visited[1] == member && P.visited[2] == second && P.visited[3] == third, "remaining snapshot entries execute once")
		check(!pending.len && P.ticks == 3 && P.finish_seen == 3, "relay finishes only after successful completion")
		check(P.resets == 1, "copied snapshot and iterator released")
		check(!P.current && !P.current_list, "copied snapshot and iterator released")
	check(registry.len == 3, "resumption preserves source registry")

	P = new /process/mob
	P.current_list = list(member, second)
	var/result = P.fire_as_member()
	check(result == PROCESS_TICK_CHECK_RETURNED_EARLY && P.current_list && P.current_list.len == 1, "member snapshot retained for next pass")
	if(P.current_list && P.current_list.len == 1)
		result = P.fire_as_member()
		check(result == TRUE && P.visited.len == 2 && P.visited[1] == member && P.visited[2] == second && P.ticks == 2, "member resumes pending work once")
		check(!P.current && !P.current_list, "copied snapshot and iterator released")
#if !defined(BASELINE_CONTROL) && !defined(UNCONDITIONAL_CLEAR_CONTROL) && !defined(RESET_REPOPULATION_CONTROL)
	// Fresh relay captures a real registry copy only immediately before work.
	P = new /process/mob
	living_mob_list = list(member,second,third)
	pending = list(P)
	P.main.relayProcess(P,pending)
	check(P.resets == 1 && P.current_list.len == 2, "fresh relay prepares registry snapshot lazily")
	P.main.relayProcess(P,pending)
	P.main.relayProcess(P,pending)
	check(P.visited.len == 3 && P.resets == 1 && !P.current_list && !P.current, "completed relay leaves no repopulated snapshot")
	var/datum/fourth = new
	living_mob_list = list(fourth)
	pending = list(P)
	P.main.relayProcess(P,pending)
	check(P.resets == 2 && P.visited.len == 4 && P.visited[4] == fourth && !P.current_list, "next fresh relay sees current registry membership")

	P = new /process/mob
	living_mob_list = list(member)
	P.fire_as_member()
	check(P.resets == 1 && P.visited.len == 1 && !P.current_list, "fresh member prepares and releases actual registry copy")

	var/processScheduler/S = new
	P = new /process/mob
	S.processes += P
	S.start()
	sleep(1)
	check(S.start_seen == 1 && P.resets == 0 && !P.current_list, "startup creates no idle registry snapshots")

	// First queued process yields; an irrelevant second process is deferred.
	var/process/first = new /process/mob
	first.current_list = list(member,second)
	var/process/deferred = new /process/mob
	deferred.priority = PROCESS_PRIORITY_IRRELEVANT
	deferred.current = member
	deferred.current_list = list(third)
	var/list/remaining = deferred.current_list
	S.queued = list(first,deferred)
	S.runQueuedProcesses()
	check(deferred.current_list == remaining && deferred.current_list.len == 1 && deferred.current_list[1] == third && deferred.resets == 0 && !deferred.visited.len && deferred.run_failures == 1, "deferred pass preserves unfinished snapshot")
#endif
	if(!failures)
		world.log << "PASS process snapshot ownership"
	shutdown()
