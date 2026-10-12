// Concurrent public callers exercise real pending request ownership. Generated only.
/proc/probe_wait_idle(obj/map_metadata/M)
	var/deadline = world.time + 100000
	while(M.vars["season_busy"])
		if(world.time > deadline)
			world.log << "ASSERTION: season worker never drained"
			del(world)
			return FALSE
		sleep(1)
	return TRUE
/proc/probe_requests()
	var/failures = 0
	var/list/results = list()
	// Natural requests are separate transitions even when submitted while busy.
	var/start_clock = clock
	var/start_season = map.season
	spawn(0) map.seasons(FALSE, FALSE)
	sleep(1)
	if(!map.vars["season_busy"]) failures++
	for(var/i in 1 to 3)
		spawn(0) map.seasons(FALSE, FALSE)
	sleep(1)
	probe_wait_idle(map)
	if(clock != start_clock + 4 || map.season != start_season) failures++
	results["queued_natural_clock_delta"] = clock - start_clock
	// Two pending forced requests collapse to the last requested decay policy.
	start_clock = clock
	spawn(0) map.seasons(FALSE, FALSE)
	sleep(1)
	if(!map.vars["season_busy"]) failures++
	spawn(0) map.seasons(FALSE, TRUE, TRUE)
	spawn(0) map.seasons(FALSE, TRUE, FALSE)
	sleep(1)
	probe_wait_idle(map)
	if(clock != start_clock + 1) failures++
	results["latest_forced_clock_delta"] = clock - start_clock
	// Exact default and explicit decay flags under disabled natural seasons.
	config.seasons_on = FALSE
	start_clock = clock
	start_season = map.season
	map.seasons(FALSE, FALSE)
	probe_wait_idle(map)
	if(clock != start_clock || map.season != start_season) failures++
	map.seasons(FALSE, TRUE)
	probe_wait_idle(map)
	if(clock != start_clock || map.season == start_season) failures++
	map.seasons(FALSE, TRUE, TRUE)
	probe_wait_idle(map)
	if(clock != start_clock + 1) failures++
	map.seasons(FALSE, TRUE, FALSE)
	probe_wait_idle(map)
	if(clock != start_clock + 1) failures++
	config.seasons_on = TRUE
	results["disabled_and_admin_flags"] = failures
	// Every call above was looping=FALSE; no recurring chain may be armed.
	if(map.vars["season_loop_scheduled"]) failures++
	results["looping_false_scheduled"] = map.vars["season_loop_scheduled"]
	// Replacement invalidates an in-progress owner's continuation after its yield.
	var/obj/map_metadata/retired = map
	spawn(0) retired.seasons(FALSE, FALSE)
	sleep(1)
	if(!retired.vars["season_busy"]) failures++
	map = new(locate(1,1,1))
	retired.Destroy()
	probe_wait_idle(retired)
	start_clock = clock
	sleep(250)
	if(clock != start_clock || retired.vars["season_busy"]) failures++
	results["map_replacement_clock_stable"] = clock == start_clock
	var/list/checkpoints = probe_checkpoint_requests()
	failures += checkpoints["failures"]
	results["checkpoints"] = checkpoints
	results["failures"] = failures
	return results
var/atom/probe_current_candidate
var/replacement_x
var/replacement_y
var/replacement_z
/turf/unrelated
var/checkpoint_mode
var/checkpoint_seen = 0
var/probe_in_delayed = FALSE
var/list/timer_arms = list()
var/list/timer_fires = list()
/proc/probe_checkpoint(obj/map_metadata/M, epoch, work, discovery)
	if(checkpoint_mode == "destroy" && discovery && work >= 4096)
		checkpoint_mode = null
		checkpoint_seen++
		M.Destroy()
		return
	var/trigger = (checkpoint_mode == "discovery" && discovery && work >= 4096) || (checkpoint_mode == "mutation" && !discovery && work >= 256) || (checkpoint_mode == "delayed" && probe_in_delayed && !discovery && work >= 1)
	if(!trigger) return
	checkpoint_mode = null
	checkpoint_seen++
	M.seasons(FALSE, TRUE, FALSE)
/proc/probe_after_pause(obj/map_metadata/M, epoch, discovery)
	if(checkpoint_mode != "replacement" || discovery || !isturf(probe_current_candidate)) return
	checkpoint_mode = null
	checkpoint_seen++
	replacement_x = probe_current_candidate.x
	replacement_y = probe_current_candidate.y
	replacement_z = probe_current_candidate.z
	new /turf/unrelated(probe_current_candidate)
/proc/probe_delayed_call(obj/map_metadata/M, kind, epoch)
	probe_in_delayed = TRUE
	call(M, kind)(epoch)
	probe_in_delayed = FALSE
/proc/probe_timer_armed(obj/map_metadata/M, delay)
	timer_arms += list(list("owner"="\ref[M]", "time"=world.time, "original_delay"=delay))
/proc/probe_timer_fired(obj/map_metadata/M)
	if(M != map || M.vars["season_retired"]) return
	timer_fires += list(list("owner"="\ref[M]", "time"=world.time))
/proc/probe_checkpoint_requests()
	var/failures = 0
	var/list/checkpoints = list()
	for(var/stage in list("discovery", "mutation", "delayed"))
		map = new(locate(1,1,1))
		map.season = stage == "delayed" ? "WINTER" : "FALL"
		checkpoint_mode = stage
		checkpoint_seen = 0
		var/start_clock = clock
		map.seasons(FALSE, FALSE)
		probe_wait_idle(map)
		sleep(250)
		probe_wait_idle(map)
		if(checkpoint_seen != 1 || clock != start_clock + 1) failures++
		var/stable_rng = rng_index
		sleep(250)
		if(rng_index != stable_rng) failures++
		checkpoints[stage] = list("triggered"=checkpoint_seen, "clock_delta"=clock-start_clock, "stale_callbacks_stopped"=rng_index == stable_rng)
		checkpoint_mode = null
	// Replace the exact current candidate after its real mutation pause.
	map = new(locate(1,1,1))
	map.season = "FALL"
	checkpoint_mode = "replacement"
	checkpoint_seen = 0
	map.seasons(FALSE, FALSE)
	probe_wait_idle(map)
	if(checkpoint_seen != 1 || !istype(locate(replacement_x,replacement_y,replacement_z), /turf/unrelated)) failures++
	checkpoints["retargeted_subtype_preserved"] = checkpoint_seen == 1 && istype(locate(replacement_x,replacement_y,replacement_z), /turf/unrelated)
	// Destroy invalidates the same global owner without requiring map replacement.
	map = new(locate(1,1,1))
	checkpoint_mode = "destroy"
	checkpoint_seen = 0
	var/obj/map_metadata/destroyed_owner = map
	map.seasons(FALSE, FALSE)
	probe_wait_idle(map)
	if(checkpoint_seen != 1 || map != destroyed_owner || !map.vars["season_retired"]) failures++
	var/destroy_clock = clock
	sleep(250)
	if(clock != destroy_clock || map.vars["season_busy"]) failures++
	checkpoints["destroy_cancelled_without_replacement"] = clock == destroy_clock && map == destroyed_owner
	checkpoint_mode = null
	// Exercise the actual extracted Asia post-terrain hook at z=1.
	map = new /obj/map_metadata/nomads/asia(locate(1,1,1))
	map.season = "SPRING"
	new /turf/floor/beach/water/flooded(locate(1,1,1))
	map.seasons(FALSE, FALSE)
	probe_wait_idle(map)
	if(!istype(locate(1,1,1), /turf/floor/dirt/flooded)) failures++
	map.season = "FALL"
	map.seasons(FALSE, FALSE)
	probe_wait_idle(map)
	if(!istype(locate(1,1,1), /turf/floor/beach/water/flooded)) failures++
	// Disabled base transitions still invoke Asia's original flood completion work.
	config.seasons_on = FALSE
	var/asia_clock = clock
	map.season = "SUMMER"
	new /turf/floor/beach/water/flooded(locate(1,1,1))
	map.seasons(FALSE, FALSE)
	probe_wait_idle(map)
	if(!istype(locate(1,1,1), /turf/floor/dirt/flooded) || clock != asia_clock) failures++
	map.season = "WINTER"
	map.seasons(FALSE, FALSE)
	probe_wait_idle(map)
	if(!istype(locate(1,1,1), /turf/floor/beach/water/flooded) || clock != asia_clock) failures++
	config.seasons_on = TRUE
	checkpoints["asia_flood_hook"] = failures
	// Actual inherited constructors must share a single bootstrap timer.
	for(var/map_type in list(/obj/map_metadata/nomads, /obj/map_metadata/nomads/continental))
		config.seasons_on = FALSE
		timer_arms.Cut()
		timer_fires.Cut()
		map = new map_type(locate(1,1,1))
		if(timer_arms.len != 1 || !map.vars["season_loop_scheduled"]) failures++
		map.season_schedule_loop()
		map.seasons(TRUE, FALSE)
		if(timer_arms.len != 1) failures++
		sleep(212)
		if(timer_fires.len != 1 || timer_arms.len != 2) failures++
		checkpoints["bootstrap:[map_type]"] = list("arms"=timer_arms.len, "fires"=timer_fires.len)
		map.Destroy()
	config.seasons_on = TRUE
	// Disabled natural transitions isolate exact recurring timer ownership/cadence.
	map = new(locate(1,1,1))
	config.seasons_on = FALSE
	timer_arms.Cut()
	timer_fires.Cut()
	var/start_time = world.time
	var/start_clock = clock
	map.seasons(TRUE, FALSE)
	map.seasons(TRUE, FALSE)
	if(timer_arms.len != 1 || !map.vars["season_loop_scheduled"]) failures++
	else
		var/list/armed = timer_arms[1]
		if(armed["time"] != start_time || armed["original_delay"] != 18000) failures++
	sleep(212)
	if(timer_fires.len != 1 || timer_arms.len != 2 || clock != start_clock) failures++
	else
		var/list/armed = timer_arms[1]
		var/list/fired = timer_fires[1]
		if(abs((fired["time"] - armed["time"]) - 210) > world.tick_lag + 0.1) failures++
	checkpoints["timer_arms"] = timer_arms.Copy()
	checkpoints["timer_fires"] = timer_fires.Copy()
	// Cancel the recurring chain by replacing its owner; no production restart.
	map = new(locate(1,1,1))
	config.seasons_on = TRUE
	checkpoints["failures"] = failures
	return checkpoints
