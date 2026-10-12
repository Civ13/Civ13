#define SECONDS * 10
#define SECOND * 10
#define GAME_STATE_PLAYING 1
#define GAME_STATE_FINISHED 2
#define PROCESS_PRIORITY_HIGH 2
#define PROCESS_PRIORITY_VERY_HIGH 3
#define PROCESS_TICK_CHECK_RETURNED_EARLY 1234
#define PROCESS_TICK_CHECK if(world.tick_usage - run_time_tick_usage >= run_time_tick_usage_allowance) return PROCESS_TICK_CHECK_RETURNED_EARLY
var/list/lighting_update_overlays = list()
var/list/lighting_update_lights = list()
var/datum/registry/processes = new
var/beat_running = FALSE
var/beat_gap = 0
var/beat_count = 0
var/process/active_process
var/check_reentry = FALSE
/proc/check_batch()
	if(active_process.current_list)
		var/i = active_process.vars["batch_index"]-1
		if(active_process.current_list[i])
			CRASH("Consumed reference retained")
		if(check_reentry)
			check_reentry = FALSE
			if(active_process.fire() != PROCESS_TICK_CHECK_RETURNED_EARLY)
				CRASH("Reentry not rejected")
/proc/beat()
	var/last = world.time
	while(beat_running)
		beat_gap = max(beat_gap,world.time-last)
		beat_count++
		last = world.time
		sleep(world.tick_lag)
/datum/registry
	var/process/lighting_overlays/lighting_overlays
	var/process/lighting_sources/lighting_sources
/process
	var/name
	var/schedule_interval
	var/start_delay
	var/list/fires_at_gamestates
	var/priority
	var/always_runs
	var/current
	var/list/current_list
	var/run_time_tick_usage
	var/run_time_tick_usage_allowance = 10
/process/proc/setup()
/process/proc/fire()
/process/proc/reset_current_list()
/process/proc/copyStateFrom(process/target)
/process/proc/onKill()
/process/proc/catchBadType(datum/D)
	return
/proc/isDeleted(datum/D)
	return !D
/atom/movable/lighting_overlay
	var/needs_update = TRUE
	var/calls = 0
	var/completed_at = 0
/atom/movable/lighting_overlay/proc/update_overlay()
	check_batch()
	calls++
	completed_at = world.time
/datum/light_source
	var/needs_update = TRUE
	var/destroyed = FALSE
	var/force_update = TRUE
	var/vis_update = FALSE
	var/calls = 0
	var/completed_at = 0
/datum/light_source/proc/check()
	return TRUE
/datum/light_source/proc/remove_lum()
	return
/datum/light_source/proc/apply_lum()
	check_batch()
	calls++
	completed_at = world.time
/datum/light_source/proc/smart_vis_update()
	calls++
	completed_at = world.time
/world
	fps = 20
/world/Error(exception/E)
	world.log << "FAIL [E]"
	del(world)
/world/OpenPort(port)
	if(port != "none")
		return FALSE
	return ..()
/world/New()
	world.OpenPort("none")
	var/size = text2num(world.params["size"])
	beat_running = TRUE
	spawn(0)
		beat()
	for(var/kind in list("overlay", "source"))
		var/process/P = kind == "overlay" ? new /process/lighting_overlays : new /process/lighting_sources
		active_process = P
		for(var/round in 1 to 5)
			var/list/items = list()
			for(var/i in 1 to size)
				items += kind == "overlay" ? new /atom/movable/lighting_overlay : new /datum/light_source
			if(kind == "overlay")
				lighting_update_overlays = items.Copy()
			else
				lighting_update_lights = items.Copy()
			var/elapsed = 0
			var/peak = 0
			var/passes = 0
			var/start = world.time
			check_reentry = TRUE
			beat_gap = 0
			beat_count = 0
			while(lighting_update_overlays.len || lighting_update_lights.len || P.current_list)
				P.run_time_tick_usage = world.tick_usage
				var/before = world.tick_usage
				P.fire()
				var/used = world.tick_usage-before
				elapsed += used
				peak = max(peak,used)
				passes++
				if(passes>size+1)
					CRASH("Queue starved")
				sleep(world.tick_lag)
			for(var/datum/D in items)
				if(D.vars["calls"] != 1 || D.vars["needs_update"])
					CRASH("Missing or duplicate work")
			var/last_completed = start
			for(var/datum/D in items)
				if(D.vars["completed_at"] < last_completed)
					CRASH("FIFO fairness")
				last_completed = D.vars["completed_at"]
			text2file(json_encode(list("kind"=kind,"round"=round,"cpu_tick_percent_sum"=elapsed,"peak_tick_percent"=peak,"passes"=passes,"drain_ticks"=(world.time-start)/world.tick_lag,"max_lateness_ticks"=(last_completed-start)/world.tick_lag,"heartbeat_max_gap_ticks"=beat_gap/world.tick_lag,"heartbeat_count"=beat_count,"retained"=lighting_update_overlays.len+lighting_update_lights.len)),"results.jsonl")
			for(var/datum/D in items)
				del(D)
			sleep(2)
	world.log << "PASS"
	beat_running = FALSE
	del(world)
