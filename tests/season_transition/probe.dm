var/list/area_list = list()
var/obj/map_metadata/map
var/datum/probe_config/config = new
var/list/events = list()
var/list/rng = list()
var/list/operation_trace = list()
var/rng_index = 0
var/probe_helper_peak_slots = 0
var/positive_pause_calls = 0
/atom
	var/gcDestroyed = FALSE
var/clock = 0
var/peak_gap_ticks = 0
var/peak_gap_ds = 0
var/heartbeat_running = TRUE
var/heartbeat_ready = FALSE
var/measure_gap = FALSE
/datum/probe_config
	var/seasons_on = TRUE
/area
	var/climate = "temperate"
/turf
	var/initial_type
	proc/ChangeTurf(next_type)
		probe_operation("change_turf", src, "[next_type]")
		return new next_type(src)
	proc/update_icon()
		probe_operation("update_icon", src, "")
		return
/obj/map_metadata
	var/probe_phase_pending = 0
	var/season = "FALL"
	New()
		..()
		map = src
	proc/change_weather_somehow()
		events += "weather_somehow:[season]"
	proc/change_weather(value)
		events += "weather:[season]:[value]"
/obj/structure/sink
	var/dry = FALSE
	proc/update_icon()
		probe_operation("update_icon", src, "")
		return
/obj/structure/wild/tree/live_tree
	proc/change_season()
		events += "tree:[map.season]"
/obj
	proc/Destroy()
		return
	proc/persistence_runtime_var(var_name)
		return FALSE
/obj/inert
/mob/inert
/proc/season_decay_requested(force, advance_decay)
	return isnull(advance_decay) ? !force : advance_decay
/proc/record_abandonment_season_change(advance_decay)
	if(advance_decay) clock++
/proc/to_chat(target, message)
	events += "announce:[map.season]"
/proc/probe_prob(threshold)
	rng_index++
	rng += threshold
	var/result = ((rng_index * 37) % 100) < threshold
	probe_operation("prob", probe_current_candidate, "[threshold]:[result]")
	return result
/proc/probe_operation(kind, atom/A, detail)
#if OPTRACE
	operation_trace += "[kind]:[A ? A.x : 0],[A ? A.y : 0],[A ? A.z : 0]:[A ? A.type : null]:[detail]"
#endif
/proc/probe_wait_settled(obj/map_metadata/M)
	var/deadline = world.time + 100000
#if CANDIDATE
	while(M.probe_phase_pending || M.vars["season_busy"] || (islist(M.vars["season_queue"]) && length(M.vars["season_queue"])))
#else
	// Historical baseline has no worker/queue fields; its delayed callbacks are counted.
	while(M.probe_phase_pending)
#endif
		if(world.time > deadline)
			world.log << "ASSERTION: pending season phases never drained"
			del(world)
			return FALSE
		sleep(1)
	if(M.probe_phase_pending < 0)
		world.log << "ASSERTION: pending season phase accounting underflow"
		del(world)
		return FALSE
	return TRUE
/proc/get_turf(atom/A)
	while(A && !isturf(A)) A = A.loc
	return A
/proc/get_area(atom/A)
	while(A && !isarea(A)) A = A.loc
	return A
/proc/safepick(list/L)
	return L && L.len ? L[1] : null
/proc/qdel(atom/A)
	del(A)
/proc/probe_pause(delay)
	if(delay > 0) positive_pause_calls++
	sleep(delay)
/proc/heartbeat()
	var/last = world.time
	var/last_wall = world.timeofday
	heartbeat_ready = TRUE
	while(heartbeat_running)
		sleep(1)
		if(measure_gap) peak_gap_ticks = max(peak_gap_ticks, world.time - last)
		last = world.time
		var/wall_now = world.timeofday
		if(measure_gap) peak_gap_ds = max(peak_gap_ds, (wall_now - last_wall + 864000) % 864000)
		last_wall = wall_now
/proc/snapshot()
	var/list/types = list()
	for(var/turf/T in world) types += "[T.x],[T.y],[T.z]:[T.type]"
	return md5(jointext(types, ";"))
/world
	maxx = WIDTH
	maxy = HEIGHT
	maxz = 1
	fps = 50
	turf = /turf/floor/dirt
/world/OpenPort(port)
	if(port == "none") return ..()
	return FALSE
/world/Error(exception/E)
	world.log << "runtime error: [E]"
	return ..()
/world/New()
	..()
	world.OpenPort("none")
	if(world.port || world.OpenPort(49199))
		world.log << "PORT_OPEN"
		del(world)
		return
	map = new(locate(1,1,1))
	var/list/areas = list(new /area/caribbean/nomads/forest, new /area/caribbean/nomads/forest/Jungle, new /area/caribbean/nomads/forest/savanna, new /area/caribbean/nomads/desert, new /area/caribbean/nomads/snow, new /area/caribbean/roofed, new /area/caribbean/nomads/semiarid)
	var/list/climates = list("temperate", "jungle", "savanna", "desert", "tundra", "temperate", "semiarid")
	area_list = areas.Copy()
	for(var/i in 1 to areas.len)
		var/area/A = areas[i]
		A.climate = climates[i]
	var/list/types = list(/turf/floor/dirt, /turf/floor/grass, /turf/floor/dirt/burned, /turf/floor/dirt/jungledirt, /turf/floor/dirt/dry_lava, /turf/floor/dirt/flooded, /turf/floor/dirt/ploughed/flooded, /turf/floor/beach/drywater, /turf/floor/beach/drywater2, /turf/floor/dirt/underground, /turf/floor/dirt/dust, /turf/floor/winter/grass, /turf/floor/dirt/winter)
	for(var/turf/T in world)
		var/area/target_area = areas[1 + ((T.x + T.y) % areas.len)]
		target_area.contents += T
		var/type = types[1 + ((T.x * 7 + T.y) % types.len)]
		new type(T)
	var/list/owned = list()
	var/list/locations = list()
	for(var/i in 1 to 20000)
		var/obj/inert/O = new(locate(1 + i % WIDTH, 1 + i % HEIGHT, 1))
		owned += O
		locations += get_turf(O)
	for(var/i in 1 to 80)
		var/mob/inert/M = new(locate(1 + i % WIDTH, 1 + i % HEIGHT, 1))
		owned += M
		locations += get_turf(M)
	new /obj/structure/wild/tree/live_tree(locate(2,2,1))
	new /obj/structure/sink/well(locate(3,3,1))
	new /obj/structure/window/barrier/snowwall(locate(4,4,1))
	new /obj/covers/snow_wall(locate(5,5,1))
	new /obj/item/weapon/snowwall(locate(6,6,1))
	spawn(0) heartbeat()
	var/list/samples = list()
	for(var/cycle in 1 to 4)
		while(!heartbeat_ready) sleep(1)
		sleep(1)
		measure_gap = TRUE
		var/start = world.time
		map.seasons(FALSE, FALSE)
#if CANDIDATE
		probe_wait_idle(map)
#endif
		var/work_ticks = world.time - start
		// Wait for every scheduled callback plus queued/active phase, including nested effects.
		probe_wait_settled(map)
		var/all_phase_ticks = world.time - start
		measure_gap = FALSE
		samples += list(list("cycle"=cycle, "season"=map.season, "elapsed_ticks"=work_ticks, "all_phase_completion_ticks"=all_phase_ticks, "terrain_md5"=snapshot(), "rng_calls"=rng_index, "clock"=clock))
	var/identity_failures = 0
	for(var/i in 1 to owned.len)
		var/atom/movable/A = owned[i]
		var/turf/expected = locations[i]
		if(!A || !get_turf(A) || get_turf(A) != expected) identity_failures++
	var/parity_clock = clock
	var/list/parity_events = events.Copy()
	var/list/parity_rng = rng.Copy()
	var/list/parity_operations = operation_trace.Copy()
	var/list/requests = list()
#if REQUESTCHECK
	requests = probe_requests()
#endif
	heartbeat_running = FALSE
	text2file(json_encode(list("cycles"=4, "clock"=parity_clock, "requests"=requests, "distractors"=owned.len, "identity_failures"=identity_failures, "samples"=samples, "events"=parity_events, "rng_thresholds"=parity_rng, "operation_trace"=parity_operations, "peak_gap_ticks"=peak_gap_ticks, "peak_gap_ds"=peak_gap_ds, "peak_helper_slots"=probe_helper_peak_slots, "positive_pause_calls"=positive_pause_calls)), "result.json")
	del(world)










