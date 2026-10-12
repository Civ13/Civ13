// Full production-source constructor benchmark, without connected clients or roundstart.
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/world/New()
	OpenPort("none")
	round_progressing = FALSE
	if (config)
		config.webhook_can_fire = FALSE
		config.ToRban = FALSE
		config.skip_persistence_saving = TRUE
	..()
	round_progressing = FALSE
	if (config)
		config.webhook_can_fire = FALSE
		config.ToRban = FALSE
		config.skip_persistence_saving = TRUE
/world/Error(exception/error)
	if (full_season_probe)
		full_season_probe.runtime_error = TRUE
	world.log << "FULL SEASON runtime error: [error]"
	text2file("FULL SEASON runtime error: [error]", "full-season-runtime-error.txt")
	return ..()
/world/Reboot(reason)
	throw EXCEPTION("Unexpected reboot in constructor benchmark: [reason]")

/mob/living/human/full_season_actor
	var/probe_lives = 0
	var/probe_last_life = 0
	var/probe_max_life_gap = 0
/mob/living/human/full_season_actor/ssd_check()
	return FALSE
/mob/living/human/full_season_actor/Life()
	if (probe_last_life)
		probe_max_life_gap = max(probe_max_life_gap, world.time - probe_last_life)
	probe_last_life = world.time
	probe_lives++
	return ..()

var/global/datum/full_season_constructor_probe/full_season_probe = new
/datum/full_season_constructor_probe
	var/runtime_error = FALSE
	var/setup_complete = FALSE
	var/active = TRUE
	var/phase = "startup"
	var/pending_phases = 0
	var/main_started = 0
	var/main_finished = 0
	var/main_started_tod = 0
	var/main_finished_tod = 0
	var/list/original_phase_delays = list()
	var/list/actors = list()
	var/list/items = list()
	var/list/heartbeat_rows = list()
	var/list/cycles = list()
	var/list/markers = list()
	var/population_constructed = FALSE
	var/moves = 0
	var/inventory_cycles = 0
	var/movement_done = TRUE
	var/movement_error = null
	var/movement_busy_count = 0
	var/list/movement_rows = list()
	var/completed = FALSE
/datum/full_season_constructor_probe/New()
	if (config)
		config.webhook_can_fire = FALSE
		config.ToRban = FALSE
		config.skip_persistence_saving = TRUE
	spawn(0)
		heartbeat()
	spawn(10)
		run_probe()
/datum/full_season_constructor_probe/proc/elapsed_tod(start)
	var/delta = world.timeofday - start
	if (delta < 0)
		delta += 864000
	return delta
/datum/full_season_constructor_probe/proc/mark(name)
	phase = name
	var/list/row = list("phase" = name, "world_time_ds" = world.time, "timeofday_ds" = world.timeofday)
	markers += list(row)
	fdel("phase.json")
	text2file(json_encode(row), "phase.json")
/datum/full_season_constructor_probe/proc/isolation()
	if (world.loop_checks != TRUE || world.port || world.OpenPort(0) || clients.len || config.webhook_can_fire || config.ToRban || !config.skip_persistence_saving || round_progressing)
		throw EXCEPTION("Full-source isolation invariant failed")
	if (!istype(map, /obj/map_metadata/nomads/persistence_beta) || world.maxx != 660 || world.maxy != 550 || world.maxz != 1)
		throw EXCEPTION("Expected actual largest seasonal map 660x550x1")
/datum/full_season_constructor_probe/proc/heartbeat()
	var/prior = world.timeofday
	while (active)
		sleep(1)
		var/gap = elapsed_tod(prior)
		prior = world.timeofday
		if (heartbeat_rows.len >= 12000)
			throw EXCEPTION("Finite heartbeat sample bound exceeded")
		heartbeat_rows += list(list("phase" = phase, "world_time_ds" = world.time, "awake_gap_ds" = gap, "tick_usage_percent" = world.tick_usage))
/datum/full_season_constructor_probe/proc/check_population()
	if (actors.len != 80 || items.len != 20000)
		throw EXCEPTION("Finite population count mismatch")
	for (var/i in 1 to actors.len)
		var/mob/living/human/full_season_actor/H = actors[i]
		if (!H || H.gcDestroyed || H.stat == DEAD || H.loc != locate(640 + ((i-1) % 10), 530 - round((i-1)/10), 1) || !H.probe_lives)
			throw EXCEPTION("Actor identity/location/service failed: [i]")
	for (var/i in 1 to items.len)
		var/obj/item/I = items[i]
		var/turf/expected = locate(620 + ((i-1) % 10), 510 - (round((i-1)/10) % 10), 1)
		if (!I || I.gcDestroyed || I.loc != expected)
			throw EXCEPTION("Item identity/location failed: [i]")
		if (!(i % 256))
			sleep(world.tick_lag)
/datum/full_season_constructor_probe/proc/check_movement_lane(var/mob/living/human/A, var/turf/T, var/turf/U)
	if (!A || A.loc != T || !istype(T, /turf/floor/plating) || !istype(U, /turf/floor/plating) || get_dist(T, U) != 1 || T.density || U.density)
		throw EXCEPTION("Native movement lane geometry invariant")
	for (var/turf/lane in list(T, U))
		for (var/atom/movable/obstacle in lane)
			if (obstacle != A && obstacle.density)
				throw EXCEPTION("Native movement lane occupied: [obstacle.type] at [lane.x],[lane.y]")
// One finite callback per transition, serviced by normal native scheduling.
/datum/full_season_constructor_probe/proc/exercise_during_season(cycle)
	var/obj/item/handled
	try
		var/wait_start = world.timeofday
		while (!map.season_busy)
			if (!active || elapsed_tod(wait_start) >= 300)
				throw EXCEPTION("Concurrent movement missed season busy window")
			sleep(1)
		var/mob/living/human/full_season_actor/A = actors[1]
		var/turf/T = locate(640, 530, 1)
		var/turf/U = locate(639, 530, 1)
		check_movement_lane(A, T, U)
		handled = new /obj/item(T)
		for (var/i in 1 to 20)
			if (!active || !A || A.gcDestroyed || A.stat == DEAD)
				throw EXCEPTION("Concurrent actor retired or dead")
			var/busy_before = map.season_busy
			if (!A.put_in_active_hand(handled) || handled.loc != A)
				throw EXCEPTION("Concurrent production pickup identity failed")
			A.drop_from_inventory(handled, T)
			if (handled.loc != T || A.get_active_hand() == handled)
				throw EXCEPTION("Concurrent production drop identity failed")
			A.last_movement = 0
			A.next_move = 0
			var/turf/destination = A.loc == T ? U : T
			step(A, get_dir(A.loc, destination))
			if (A.loc != destination)
				throw EXCEPTION("Concurrent production movement identity failed: cycle=[cycle], iteration=[i], at=[A.x],[A.y], target=[destination.x],[destination.y], density=[A.density], buckled=[A.buckled], drone=[A.using_drone], stat=[A.stat]")
			moves++
			inventory_cycles++
			var/busy_after = map.season_busy
			if (busy_before && busy_after)
				movement_busy_count++
			movement_rows += list(list("cycle" = cycle, "iteration" = i, "world_time_ds" = world.time, "busy_before" = busy_before, "busy_after" = busy_after, "actor_ref" = "\ref[A]", "item_ref" = "\ref[handled]", "destination_x" = destination.x, "destination_y" = destination.y, "item_on_drop_turf" = handled.loc == T))
			sleep(1)
		if (A.loc != T || handled.loc != T)
			throw EXCEPTION("Concurrent final identity/location failed")
	catch (var/exception/E)
		movement_error = "[E]"
	if (handled)
		qdel(handled)
	movement_done = TRUE
	return
/datum/full_season_constructor_probe/proc/registry_snapshot()
	for (var/i = 1, i <= grass_turf_list.len, i++)
		var/turf/floor/grass/G = grass_turf_list[i]
		if (!istype(G) || G.gcDestroyed || G.grass_registry_index != i || locate(G.x, G.y, G.z) != G)
			throw EXCEPTION("Production grass registry lifecycle invariant")
		if (!(i % 4096))
			sleep(world.tick_lag)
	for (var/i = 1, i <= water_turf_list.len, i++)
		var/turf/floor/beach/water/W = water_turf_list[i]
		if (!istype(W) || W.gcDestroyed || W.water_registry_index != i || locate(W.x, W.y, W.z) != W)
			throw EXCEPTION("Production water registry lifecycle invariant")
		if (!(i % 4096))
			sleep(world.tick_lag)
	return list("grass_entries" = grass_turf_list.len, "water_entries" = water_turf_list.len, "world_time_ds" = world.time)
/datum/full_season_constructor_probe/proc/run_probe()
	try
		var/startup_tod = world.timeofday
		while (!setup_complete || !map || !ticker || !processScheduler || !processes.mob || !processes.garbage || !processes.callproc)
			if (elapsed_tod(startup_tod) >= 3000)
				throw EXCEPTION("Full-source setup readiness deadline")
			sleep(1)
		isolation()
		// Freeze the pregame lobby; roundstart nature/mapgen is outside this constructor benchmark.
		config.seasons_on = FALSE
		mark("population")
		var/population_start = world.time
		var/population_start_tod = world.timeofday
		for (var/i in 1 to 80)
			var/turf/T = locate(640 + ((i-1) % 10), 530 - round((i-1)/10), 1)
			T = T.ChangeTurf(/turf/floor/plating)
			var/mob/living/human/full_season_actor/H = new(T)
			actors += H
			if (!(i % 8))
				sleep(world.tick_lag)
		var/mob/living/human/full_season_actor/A = actors[1]
		var/turf/T = A.loc
		var/turf/U = locate(T.x-1, T.y, 1)
		U = U.ChangeTurf(/turf/floor/plating)
		check_movement_lane(A, T, U)
		var/obj/item/handled = new(T)
		for (var/i in 1 to 20)
			if (!A.put_in_active_hand(handled) || handled.loc != A)
				throw EXCEPTION("Production pickup identity failed")
			A.drop_from_inventory(handled, T)
			if (handled.loc != T || A.get_active_hand() == handled)
				throw EXCEPTION("Production drop identity failed")
			inventory_cycles++
			A.last_movement = 0
			A.next_move = 0
			var/turf/destination = A.loc == T ? U : T
			step(A, get_dir(A.loc, destination))
			if (A.loc != destination)
				throw EXCEPTION("Production movement identity failed: iteration=[i], at=[A.x],[A.y], target=[destination.x],[destination.y], density=[A.density], buckled=[A.buckled], drone=[A.using_drone], stat=[A.stat]")
			moves++
			sleep(1)
		qdel(handled)
		// Actual map staging cells are deep water. Use real plating replacement
		// before constructing items so production sinking does not dispose the load.
		for (var/i in 1 to 100)
			var/turf/staging = locate(620 + ((i-1) % 10), 510 - (round((i-1)/10) % 10), 1)
			staging.ChangeTurf(/turf/floor/plating)
			if (!(i % 16))
				sleep(world.tick_lag)
		for (var/i in 1 to 20000)
			var/turf/IT = locate(620 + ((i-1) % 10), 510 - (round((i-1)/10) % 10), 1)
			var/obj/item/I = new(IT)
			items += I
			if (!(i % 256))
				sleep(world.tick_lag)
		population_constructed = TRUE
		var/list/population = list("world_ds" = world.time-population_start, "wall_ds" = elapsed_tod(population_start_tod), "items" = items.len, "humans" = actors.len)
		sleep(10)
		mark("validation_initial")
		check_population()
		var/list/initial_registries = registry_snapshot()
		season = "SUMMER"
		var/initial_epoch = map.season_epoch
		var/initial_clock = abandonment_season_changes
		for (var/cycle in 1 to 4)
			isolation()
			mark("season_[cycle]_main")
			var/begin = world.time
			var/begin_tod = world.timeofday
			main_started = 0
			main_finished = 0
			var/list/life_before = list()
			for (var/mob/living/human/full_season_actor/H in actors)
				life_before += H.probe_lives
			movement_done = FALSE
			movement_error = null
			movement_busy_count = 0
			spawn(0)
				exercise_during_season(cycle)
			map.seasons(FALSE, TRUE, TRUE)
			while (pending_phases || map.season_busy || map.season_queue.len || !movement_done)
				if (elapsed_tod(begin_tod) >= 9000)
					throw EXCEPTION("Season callback quiescence deadline")
				sleep(1)
			if (!main_finished || map.season_epoch != initial_epoch+cycle || abandonment_season_changes != initial_clock+cycle)
				throw EXCEPTION("Actual transition completion/decay invariant")
			if (movement_error || !movement_done || movement_busy_count < 1)
				throw EXCEPTION("Concurrent season movement completion failed: [movement_error]")
			var/list/life_advances = list()
			for (var/i in 1 to actors.len)
				var/mob/living/human/full_season_actor/H = actors[i]
				var/advance = H.probe_lives - life_before[i]
				if (advance < 1)
					throw EXCEPTION("Human Life failed to advance during cycle: [cycle]/[i]")
				life_advances += advance
			cycles += list(list("movement_busy_operations" = movement_busy_count, "movement_completed" = movement_done, "human_life_advances" = life_advances, "cycle" = cycle, "season" = season, "main_world_ds" = main_finished-main_started, "main_wall_ds" = (main_finished_tod-main_started_tod+864000)%864000, "all_phase_world_ds" = world.time-begin, "all_phase_wall_ds" = elapsed_tod(begin_tod), "epoch" = map.season_epoch, "decay" = abandonment_season_changes, "pending" = pending_phases))
			mark("validation_[cycle]")
			check_population()
			var/list/current_cycle = cycles[cycles.len]
			current_cycle["registries"] = registry_snapshot()
		mark("recovery")
		sleep(50)
		check_population()
		isolation()
		if (runtime_error || moves != 100 || inventory_cycles != 100 || !movement_done || movement_rows.len != 80 || cycles.len != 4 || season != "SUMMER" || original_phase_delays.len != 9)
			throw EXCEPTION("Constructor benchmark final invariant failed")
		var/list/services = list()
		var/dead_humans = 0
		for (var/mob/living/human/full_season_actor/H in actors)
			services += list(list("life_calls" = H.probe_lives, "maximum_life_gap_ds" = H.probe_max_life_gap, "stat" = H.stat))
			if (H.stat == DEAD)
				dead_humans++
		completed = TRUE
		active = FALSE
		text2file(json_encode(list("completed" = completed, "movement_rows" = movement_rows, "passed" = TRUE, "tested_commit" = world.params["tested_commit"], "byond_version" = world.byond_version, "byond_build" = world.byond_build, "map_id" = map.ID, "dimensions" = list(world.maxx, world.maxy, world.maxz), "population" = population, "initial_registries" = initial_registries, "cycles" = cycles, "markers" = markers, "heartbeats" = heartbeat_rows, "actor_service" = services, "dead_humans" = dead_humans, "original_phase_delays_ds" = original_phase_delays, "moves" = moves, "inventory_cycles" = inventory_cycles, "native_loop_checks" = world.loop_checks, "port" = world.port, "connected_clients" = clients.len, "scope" = "Full-source actual largest-map constructors and headless human Life; pregame, no connected-player or full-round acceptance")), "result.json")
	catch (var/exception/E)
		active = FALSE
		world.log << "FULL SEASON FAIL: [E] at [E.file]:[E.line]"
		text2file("FAIL: [E]", "result.txt")
	del(world)
	return
