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
/proc/probe_request_assert(list/assertions, name, passed)
	assertions[name] = !!passed
	return passed ? 0 : 1
var/request_checkpoint_mode
var/list/request_checkpoint_results = list()
/proc/probe_requests()
	var/failures = 0
	var/list/results = list()
	var/list/assertions = list()
	// Submit public callers from the real worker checkpoint with its lock held.
	var/start_clock = clock
	var/start_season = map.season
	request_checkpoint_mode = "natural"
	request_checkpoint_results = list()
	map.seasons(FALSE, FALSE)
	probe_wait_idle(map)
	failures += probe_request_assert(assertions, "natural_checkpoint_reached", request_checkpoint_results["triggered"] == 1)
	failures += probe_request_assert(assertions, "natural_owner_busy", request_checkpoint_results["owner_busy"])
	failures += probe_request_assert(assertions, "natural_three_records_queued", request_checkpoint_results["queue_slots"] == 12)
	failures += probe_request_assert(assertions, "natural_four_clocks_and_cycle", clock == start_clock + 4 && map.season == start_season)
	results["natural_checkpoint"] = request_checkpoint_results
	results["queued_natural_clock_delta"] = clock - start_clock
	// Both forced public calls see the same lock; the second replaces the first.
	start_clock = clock
	request_checkpoint_mode = "forced"
	request_checkpoint_results = list()
	map.seasons(FALSE, FALSE)
	probe_wait_idle(map)
	failures += probe_request_assert(assertions, "forced_checkpoint_reached", request_checkpoint_results["triggered"] == 1)
	failures += probe_request_assert(assertions, "forced_owner_busy", request_checkpoint_results["owner_busy"])
	failures += probe_request_assert(assertions, "forced_latest_record_retained", request_checkpoint_results["latest_record"])
	failures += probe_request_assert(assertions, "forced_only_natural_clock", clock == start_clock + 1)
	results["forced_checkpoint"] = request_checkpoint_results
	results["latest_forced_clock_delta"] = clock - start_clock
	// Exact default and explicit decay flags under disabled natural seasons.
	config.seasons_on = FALSE
	start_clock = clock
	start_season = map.season
	map.seasons(FALSE, FALSE)
	probe_wait_idle(map)
	failures += probe_request_assert(assertions, "disabled_natural_preserves_clock_and_season", clock == start_clock && map.season == start_season)
	map.seasons(FALSE, TRUE)
	probe_wait_idle(map)
	failures += probe_request_assert(assertions, "forced_default_preserves_decay", clock == start_clock && map.season != start_season)
	map.seasons(FALSE, TRUE, TRUE)
	probe_wait_idle(map)
	failures += probe_request_assert(assertions, "forced_explicit_advances_decay", clock == start_clock + 1)
	map.seasons(FALSE, TRUE, FALSE)
	probe_wait_idle(map)
	failures += probe_request_assert(assertions, "forced_explicit_preserves_decay", clock == start_clock + 1)
	config.seasons_on = TRUE
	results["disabled_and_admin_flags"] = failures
	failures += probe_request_assert(assertions, "looping_false_has_no_timer", !map.vars["season_loop_scheduled"])
	results["looping_false_scheduled"] = map.vars["season_loop_scheduled"]
	// Replace the global owner from its actual active-worker checkpoint.
	var/obj/map_metadata/retired = map
	request_checkpoint_mode = "map_replace"
	request_checkpoint_results = list()
	retired.seasons(FALSE, FALSE)
	probe_wait_idle(retired)
	failures += probe_request_assert(assertions, "replacement_checkpoint_reached", request_checkpoint_results["triggered"] == 1)
	failures += probe_request_assert(assertions, "replacement_owner_busy", request_checkpoint_results["owner_busy"])
	failures += probe_request_assert(assertions, "replacement_owner_invalidated", map != retired && retired.vars["season_retired"])
	start_clock = clock
	probe_wait_settled(retired)
	failures += probe_request_assert(assertions, "replacement_clock_stable_and_worker_drained", clock == start_clock && !retired.vars["season_busy"])
	results["replacement_checkpoint"] = request_checkpoint_results
	results["map_replacement_clock_stable"] = clock == start_clock
	var/list/checkpoints = probe_checkpoint_requests()
	failures += checkpoints["failures"]
	results["checkpoints"] = checkpoints
	var/list/discovery = probe_discovery_sequences()
	failures += discovery["failures"]
	results["typed_discovery"] = discovery
	results["assertions"] = assertions
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
	if(request_checkpoint_mode && work >= 1)
		var/mode = request_checkpoint_mode
		request_checkpoint_mode = null
		request_checkpoint_results["triggered"] = 1
		request_checkpoint_results["owner_busy"] = M == map && M.vars["season_busy"] && M.season_worker_valid(epoch)
		if(mode == "natural")
			for(var/i in 1 to 3)
				M.seasons(FALSE, FALSE)
			request_checkpoint_results["queue_slots"] = M.season_queue.len
		else if(mode == "forced")
			M.seasons(FALSE, TRUE, TRUE)
			M.seasons(FALSE, TRUE, FALSE)
			request_checkpoint_results["latest_record"] = M.season_queue.len == 4 && M.season_queue[1] == "transition" && M.season_queue[2] == FALSE && M.season_queue[3] == TRUE && M.season_queue[4] == FALSE
		else if(mode == "map_replace")
			map = new(locate(1,1,1))
			M.Destroy()
		return
	if(checkpoint_mode == "typed_cancel" && discovery && work >= 64)
		checkpoint_mode = null
		checkpoint_seen++
		M.Destroy()
		return
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
		probe_wait_settled(map)
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
	probe_wait_settled(map)
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

// Compare actual ordered native references, not type counts or final terrain.
/proc/probe_generic_candidates(atom_type)
	var/list/result = list()
	for(var/atom/A in world)
		if(istype(A, atom_type) && !A.gcDestroyed)
			result += A
	return result
/proc/probe_same_candidates(list/expected, list/actual)
	if(!islist(actual) || expected.len != actual.len) return FALSE
	for(var/i in 1 to expected.len)
		if(expected[i] != actual[i]) return FALSE
	return TRUE
/proc/probe_discovery_sequences()
	var/failures = 0
	var/list/rows = list()
	map = new(locate(1,1,1))
	var/list/targets = list(/turf/floor/dirt/flooded, /turf/floor/dirt/ploughed/flooded, /turf/floor/beach/water/flooded, /turf/floor/dirt/burned, /turf/floor/grass, /obj/structure/sink, /obj/structure/wild/tree/live_tree, /obj/structure/window/barrier/snowwall, /obj/covers/snow_wall, /obj/item/weapon/snowwall)
	var/obj/inert/container = new(locate(1,1,1))
	var/list/nested = list()
	var/x = 1
	for(var/target in targets)
		if(ispath(target, /turf))
			new target(locate(x++,2,1))
		else
			nested += new target(container)
	// Exercise both fresh replacement membership and retired/deleted objects.
	var/turf/replaced = new /turf/floor/dirt/flooded(locate(12,2,1))
	new /turf/floor/grass(replaced)
	var/obj/retired = new /obj/item/weapon/snowwall(container)
	retired.gcDestroyed = TRUE
	var/obj/deleted = new /obj/covers/snow_wall(container)
	del(deleted)
	// /mob and /atom explicitly exercise the generic fallback too.
	targets += list(/mob, /atom)
	for(var/target in targets)
		var/list/expected = probe_generic_candidates(target)
		var/list/actual = map.season_world_candidates(target, map.season_epoch)
		var/equal = probe_same_candidates(expected, actual)
		if(!equal || !expected.len) failures++
		rows += list(list("target"="[target]", "expected"=expected.len, "actual"=islist(actual) ? actual.len : -1, "ordered_refs_equal"=equal))
		if(ispath(target, /obj))
			for(var/obj/O in nested)
				if(istype(O, target) && !(O in actual)) failures++
	// Cancellation must discard partially collected results in every branch.
	for(var/target in list(/turf, /obj, /atom))
		map = new(locate(1,1,1))
		checkpoint_mode = "typed_cancel"
		checkpoint_seen = 0
		var/list/cancelled = map.season_world_candidates(target, map.season_epoch)
		if(checkpoint_seen != 1 || !isnull(cancelled)) failures++
		if(!isnull(map.season_world_candidates(target, map.season_epoch))) failures++
	checkpoint_mode = null
	map = new(locate(1,1,1))
	// Area discovery must retain the original native turf sequence and filters.
	for(var/area/A in area_list)
		for(var/target in list(null, /turf, /turf/floor/grass, /turf/floor/dirt/flooded))
			var/list/expected = list()
			for(var/area/B in area_list)
				if(!istype(B, A.type)) continue
				for(var/turf/T in B.contents)
					if(!target || istype(T, target)) expected += T
			var/list/actual = get_area_turfs(A, null, target, map, map.season_epoch)
			if(!probe_same_candidates(expected, actual)) failures++
	// A broad query reaches a 64-turf checkpoint even in the smallest fixture.
	checkpoint_mode = "typed_cancel"
	checkpoint_seen = 0
	var/list/area_cancelled = get_area_turfs(/area, null, /turf, map, map.season_epoch)
	if(checkpoint_seen != 1 || !isnull(area_cancelled)) failures++
	if(!isnull(get_area_turfs(/area, null, /turf, map, map.season_epoch))) failures++
	checkpoint_mode = null
	map = new(locate(1,1,1))
	return list("failures"=failures, "sequences"=rows)
