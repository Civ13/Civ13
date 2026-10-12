#define TRUE 1
#define FALSE 0
#define SECONDS * 10
#define GAME_STATE_PREGAME 1
#define GAME_STATE_SETTING_UP 2
#define GAME_STATE_PLAYING 3
#define GAME_STATE_FINISHED 4
#define TimeOfGame world.time
var/checks = 0
var/list/faults = list()
var/setup_calls = 0
var/list/visits = list()
var/list/chemical_reactions_list = list("reaction")
var/list/chemical_reagents_list = list("reagent")
var/datum/process_slots/processes = new
/datum/process_slots
	var/process/chemistry/chemistry
/proc/check(condition, code)
	checks++
	if (!condition && !(code in faults))
		faults += code
		world.log << "FAIL [code]"
/proc/log_debug(message)
	return
/proc/message_admins(message)
	return
/proc/isDeleted(datum/D)
	return !D
/process
	var/processScheduler/main
	var/name = "fixture"
	var/schedule_interval = 50
	var/start_delay = 0
	var/priority = PROCESS_PRIORITY_MEDIUM
	var/list/fires_at_gamestates = list(1,2,3,4)
	var/disabled = FALSE
	var/paused = FALSE
	var/paused_nonvital = FALSE
	var/always_runs = FALSE
	var/hang_warning_time = 300
	var/hang_alert_time = 600
	var/hang_restart_time = 900
	var/last_fire_as_member = 0
	var/run_start = 0
	var/times_killed = 0
	var/ticks = 0
	var/last_task = ""
	var/current
	var/list/current_list
	var/run_time_tick_usage = 0
	var/run_time_tick_usage_allowance = 100
	var/run_failures = 0
	var/status
	var/previousStatus
	var/idle = FALSE
	var/running = FALSE
	var/queued = FALSE
	var/hung = FALSE
	var/killed = FALSE
/process/New(processScheduler/S)
	main = S
/process/proc/setup()
	setup_calls++
/process/proc/catchBadType(value)
	CRASH("unexpected holder")
/process/proc/onKill()
	return
/process/proc/copyStateFrom(process/target)
	return
/process/chemistry
	var/list/active_holders
	var/list/chemical_reactions
	var/list/chemical_reagents
/process/sentinel/setup()
	setup_calls++
	name = "sentinel"
	priority = PROCESS_PRIORITY_HIGH
/processScheduler
	var/list/processes = list()
	var/list/idle = list()
	var/list/running = list()
	var/list/queued = list()
	var/list/nameToProcessMap = list()
	var/list/priorityToProcessMap = list()
	var/list/last_queued = list()
	var/list/last_start = list()
	var/list/last_run_time = list()
	var/list/last_twenty_run_times = list()
	var/list/highest_run_time = list()
	var/list/priority_ordered_processes = list()
	var/list/last_priority_ordered_processes
	var/next_get_priority_ordered_processes = 0
/processScheduler/proc/hasProcess(processName)
	return !!nameToProcessMap[processName]
/datum/reagents
	var/id
	var/remaining = 2
/datum/reagents/New(value)
	id = value
/datum/reagents/proc/process_reactions()
	visits += id
	remaining--
	return remaining > 0
/proc/owners_absent(processScheduler/S, process/P)
	var/list/owners = list(S.processes,S.idle,S.running,S.queued,S.nameToProcessMap,S.priority_ordered_processes,S.last_queued,S.last_start,S.last_run_time,S.last_twenty_run_times,S.highest_run_time)
	if (S.last_priority_ordered_processes)
		owners += list(S.last_priority_ordered_processes)
	for (var/list/L in owners)
		if (P in L)
			return FALSE
		for (var/key in L)
			if (L[key] == P)
				return FALSE
	for (var/key in S.priorityToProcessMap)
		if (P in S.priorityToProcessMap[key])
			return FALSE
	return processes.chemistry != P
/proc/test_replacement(state)
	var/processScheduler/S = new
	var/process/chemistry/P = new(S)
	S.addProcess(P)
	var/process/sentinel/A = new(S)
	var/process/sentinel/B = new(S)
	S.addProcess(A)
	S.addProcess(B)
	S.priority_ordered_processes = list(A,P,B)
	var/initial_setup_calls = setup_calls
	var/list/holders = list(new /datum/reagents(1),new /datum/reagents(2),new /datum/reagents(3))
	P.active_holders = holders
	P.priority = PROCESS_PRIORITY_HIGH
	P.start_delay = 17
	P.disabled = TRUE
	P.paused = TRUE
	P.paused_nonvital = TRUE
	P.always_runs = TRUE
	P.hang_warning_time = 21
	P.hang_alert_time = 22
	P.hang_restart_time = 23
	P.last_fire_as_member = 7
	P.fires_at_gamestates = list(GAME_STATE_PLAYING,GAME_STATE_FINISHED)
	for (var/cycle = 1 to 12)
		if (state == "queued")
			S.setQueuedProcessState(P)
		else if (state == "running")
			P.running()
			S.setRunningProcessState(P)
		else
			S.setIdleProcessState(P)
		S.last_queued[P] = 123
		S.last_twenty_run_times[P] = list(2,3)
		S.get_priority_ordered_processes()
		var/process/chemistry/old = P
		var/old_ref = "\ref[old]"
		var/list/history = S.last_twenty_run_times[old]
		P = new /process/chemistry(S)
		P._copyStateFrom(old)
		S.replaceProcess(old,P)
		check(owners_absent(S,old), "owners")
		check(P.idle && !P.running && !P.queued && S.idle.len == 3 && !S.running.len && !S.queued.len, "state")
		check(S.processes.len == 3 && S.last_queued.len == 3 && S.priorityToProcessMap["2"]:len == 3, "owners")
		check(S.priority_ordered_processes[1] == A && S.priority_ordered_processes[2] == P && S.priority_ordered_processes[3] == B, "order")
		var/list/ordered = S.get_priority_ordered_processes()
		check(!(old in ordered) && (P in ordered), "owners")
		check(S.calculate_run_time_allowance(PROCESS_PRIORITY_HIGH) == (25 / 3), "priority")
		check(P.priority == PROCESS_PRIORITY_HIGH && P.start_delay == 17 && P.disabled && P.paused && P.paused_nonvital && P.always_runs && P.hang_warning_time == 21 && P.hang_alert_time == 22 && P.hang_restart_time == 23 && P.last_fire_as_member == 7 && P.fires_at_gamestates.len == 2 && P.fires_at_gamestates[1] == GAME_STATE_PLAYING, "config")
		check(P.active_holders == holders && P.chemical_reactions == chemical_reactions_list && P.chemical_reagents == chemical_reagents_list && processes.chemistry == P, "chemistry")
		check(S.last_twenty_run_times[P] == history && history.len >= 2, "history")
		old.kill()
		check(!locate(old_ref), "retirement")
		check(S.processes.len == 3 && S.last_queued.len == 3 && S.priorityToProcessMap["2"]:len == 3, "owners")
	check(setup_calls == initial_setup_calls, "setup")
	// A budget-yielded chemistry pass owns a remaining snapshot distinct from live membership.
	P.active_holders = holders
	P.current_list = holders.Copy()
	P.run_time_tick_usage = world.tick_usage
	P.run_time_tick_usage_allowance = -1
	visits = list()
	P.fire()
	check(visits.len == 1 && P.current_list.len == 2 && holders.len == 3, "budget")
	var/process/chemistry/old = P
	var/list/pending = old.current_list
	S.restartProcess("chemistry")
	P = processes.chemistry
	check(P.current_list == pending && pending.len == 2, "snapshot")
	check(P.active_holders == holders && holders.len == 3, "chemistry")
	if (P.current_list && P.active_holders)
		P.run_time_tick_usage = world.tick_usage
		P.run_time_tick_usage_allowance = 100
		P.fire()
		check(visits.len == 3 && visits[1] == 1 && visits[2] == 2 && visits[3] == 3, "snapshot")
	check(setup_calls == initial_setup_calls, "setup")
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/world/New()
	OpenPort("none")
	spawn(1)
		check(!world.port && !OpenPort(0), "port")
		for (var/state in list("completed","queued","running"))
			test_replacement(state)
		text2file(json_encode(list("checks"=checks,"faults"=faults,"replacements"=39)),"native-result.json")
		world.log << "DONE [checks] checks [faults.len] fault categories"
		del(world)
/world/Error(exception/E)
	world.log << "RUNTIME [E]"
	return
