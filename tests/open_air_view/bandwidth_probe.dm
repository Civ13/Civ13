// Real-client network check for upper levels. Test-only: bandwidth_check.py
// appends it to a temporary copy of civ13.dme, starts the daemon behind a
// byte-counting loopback proxy and connects one Dream Seeker client. The probe
// stands the client's body on open Gaia ground, then on a floor strip one and
// two levels up, standing still and walking for a fixed time in each stage, and
// once more looking up. The runner counts the bytes the server sent during each
// measure_* phase; the probe adds the server's own map send cost.
// With `-params headless=1` no client is awaited (staging rehearsal only).
var/global/datum/open_air_bandwidth_probe/open_air_bandwidth_probe = new

#define OAB_SETTLE 80
#define OAB_MEASURE 200
#define OAB_STRIP 7

/datum/open_air_bandwidth_probe
	var/list/checks = list()
	var/list/metrics = list()
	var/list/stages = list()
	var/phase = "startup"
	var/started_tod = 0
	var/headless = FALSE
	var/client/C
	var/mob/living/human/H
	var/turf/centre
	var/walk_dir = EAST

/mob/living/human/open_air_bandwidth_actor/ssd_check()
	return FALSE

/datum/open_air_bandwidth_probe/New()
	if(!all_species || !all_species.len)
		makeDatumRefLists()
	if(!config)
		load_configuration()
		initialize_chemical_reagents()
		initialize_chemical_reactions()
	if(config)
		config.webhook_can_fire = FALSE
		config.ToRban = FALSE
	started_tod = world.timeofday
	spawn(10)
		drive()

/datum/open_air_bandwidth_probe/proc/mark(name)
	phase = name
	world.log << "OPENAIRBANDWIDTH [name]"
	fdel("phase.json")
	text2file(json_encode(list("phase" = name, "world_time" = world.time, "wall_ds" = world.timeofday - started_tod)), "phase.json")

/datum/open_air_bandwidth_probe/proc/pass(name, list/details = null)
	checks += list(list("check" = name, "passed" = TRUE, "details" = details))

/datum/open_air_bandwidth_probe/proc/require(condition, message)
	if(!condition)
		throw EXCEPTION(message)

/datum/open_air_bandwidth_probe/proc/wait_for(proc_name, deadline_ds, message)
	var/until = world.time + deadline_ds
	while(!call(src, proc_name)())
		if(world.time > until)
			throw EXCEPTION(message)
		sleep(5)

/datum/open_air_bandwidth_probe/proc/game_playing()
	return ticker && ticker.current_state == GAME_STATE_PLAYING

/datum/open_air_bandwidth_probe/proc/scheduler_ready()
	return ticker && processScheduler && processes && ticker.current_state >= GAME_STATE_PREGAME

/datum/open_air_bandwidth_probe/proc/lighting_settled()
	return created_lighting_corners_and_overlays && !processes.time_of_day_change.updating_lighting

/datum/open_air_bandwidth_probe/proc/client_connected()
	return clients.len > 0

/datum/open_air_bandwidth_probe/proc/open_tile(turf/T)
	if(!T || T.density || T.opacity || !istype(T, /turf/floor) || istype(T, /turf/floor/beach/water) || los_turf_roofed(T))
		return FALSE
	for(var/atom/movable/A in T)
		if(A.opacity || A.density)
			return FALSE
	return TRUE

// Open ground with open air above, a walkable row east and west of it, and
// woods within sight (trees are most of what Gaia shows below).
/datum/open_air_bandwidth_probe/proc/find_centre()
	for(var/attempt in 1 to 8000)
		if(attempt % 50 == 0)
			sleep(world.tick_lag)
		var/turf/T = locate(rand(40, world.maxx - 40), rand(40, world.maxy - 40), multiz_top_z())
		if(!open_tile(T))
			continue
		var/up = multiz_level_above(T.z)
		if(!up || !istype(locate(T.x, T.y, up), /turf/sky/building))
			continue
		var/good = TRUE
		for(var/dx in -OAB_STRIP to OAB_STRIP)
			if(!open_tile(locate(T.x + dx, T.y, T.z)))
				good = FALSE
				break
		if(!good)
			continue
		var/trees = 0
		for(var/obj/structure/wild/W in range(8, T))
			trees++
		if(trees >= 8 || attempt > 6000)
			metrics["trees_near_centre"] = trees
			return T
	return null

/datum/open_air_bandwidth_probe/proc/floor_strip(z, y)
	for(var/turf/sky/building/T in block(locate(centre.x - OAB_STRIP, y, z), locate(centre.x + OAB_STRIP, y, z)))
		new /obj/covers/wood(T)

/datum/open_air_bandwidth_probe/proc/take_body(turf/where)
	if(headless)
		H = new /mob/living/human/open_air_bandwidth_actor(where)
		sleep(10)
	else
		mark("waiting_for_client")
		wait_for("client_connected", 18000, "No client connected within 30 minutes")
		C = clients[1]
		sleep(100)
		H = new /mob/living/human(where)
		H.ckey = C.ckey
		sleep(50)
		C = H.client
		require(C && C.mob == H, "The client did not take the staged body")
		metrics["client"] = list("byond_version" = C.byond_version, "byond_build" = C.byond_build, "view" = "[C.view]")
	H.sleeping = 0
	H.resting = FALSE
	H.update_canmove()
	spawn(0)
		while(H && !QDELETED(H))
			H.bodytemperature = H.species.body_temperature
			H.nutrition = 400
			sleep(10)

/datum/open_air_bandwidth_probe/proc/rescan()
	if(C)
		C.open_air_view_scanned_at = 0
		C.open_air_view_scan()
	else
		open_air_view_link_around(H.z, H.x, H.y, 12, 9)

// One tile along the row, turning at the strip's ends.
/datum/open_air_bandwidth_probe/proc/walk_step()
	if(H.x + walk_dir > centre.x + OAB_STRIP || H.x + walk_dir < centre.x - OAB_STRIP)
		walk_dir = walk_dir == EAST ? WEST : EAST
	var/turf/next = locate(H.x + (walk_dir == EAST ? 1 : -1), H.y, H.z)
	H.dir = walk_dir
	if(!H.Move(next, walk_dir))
		H.forceMove(next)

/datum/open_air_bandwidth_probe/var/list/built = list()

// direct: the turf below straight in the open-air cell's vis_contents.
// copy: a nullspace object wearing a copy of the turf below's appearance only.
// copy_movables: that copy, holding what stands on the turf below.
/datum/open_air_bandwidth_probe/proc/build_views(mode, z)
	clear_views()
	for(var/turf/sky/building/T in block(locate(centre.x - OAB_STRIP - 14, centre.y - 11, z), locate(centre.x + OAB_STRIP + 14, centre.y + 11, z)))
		if(T.open_air_view_floored())
			continue
		var/turf/below = locate(T.x, T.y, centre.z)
		if(mode == "direct")
			T.vis_contents += below
		else
			var/obj/effect/V = new
			V.loc = null
			V.appearance = below.appearance
			V.plane = FLOOR_PLANE
			V.layer = 1.95
			V.color = list(0.6,0,0, 0,0.6,0, 0,0,0.64, 0.015,0.025,0.05)
			V.appearance_flags = KEEP_TOGETHER
			V.mouse_opacity = 0
			if(mode == "copy_movables")
				for(var/atom/movable/A in below)
					if(A.vis_flags & VIS_HIDE)
						continue
					V.vis_contents += A
			T.vis_contents += V
			built += V
		T.icon = null
		built += T

/datum/open_air_bandwidth_probe/proc/clear_views()
	for(var/thing in built)
		if(isturf(thing))
			var/turf/T = thing
			T.vis_contents.Cut()
			T.icon = initial(T.icon)
		else
			var/obj/effect/V = thing
			V.vis_contents.Cut()
			qdel(V)
	built.Cut()

/datum/open_air_bandwidth_probe/proc/count_views(z)
	var/n = 0
	for(var/turf/sky/building/T in range(12, locate(H.x, H.y, z)))
		if(T.open_air_view)
			n++
	return n

// Settles, then measures for a fixed time. The runner counts the bytes sent
// while the phase is measure_[name].
/datum/open_air_bandwidth_probe/proc/stage(name, walking)
	mark("settle_[name]")
	sleep(OAB_SETTLE)
	var/start = world.time
	var/cpu = 0
	var/map_cpu = 0
	var/samples = 0
	var/steps = 0
	mark("measure_[name]")
	while(world.time < start + OAB_MEASURE)
		if(walking)
			walk_step()
			steps++
		cpu += world.cpu
		map_cpu += world.map_cpu
		samples++
		sleep(walking ? 3 : 5)
	stages[name] = list("seconds" = (world.time - start) / 10, "steps" = steps, "z" = H.z,
		"cpu" = round(cpu / max(1, samples), 0.1), "map_cpu" = round(map_cpu / max(1, samples), 0.1),
		"views_near" = H.z > centre.z ? count_views(H.z) : 0)
	mark("done_[name]")

/datum/open_air_bandwidth_probe/proc/drive()
	var/failure = null
	var/failed_phase = null
	headless = world.params["headless"] ? TRUE : FALSE
	try
		mark("startup")
		wait_for("scheduler_ready", 9000, "Scheduler/ticker never became ready")
		ticker.admin_started = TRUE
		if(ticker.pregame_timeleft > 1)
			ticker.pregame_timeleft = 1
		wait_for("game_playing", 3000, "Round did not reach PLAYING")
		wait_for("lighting_settled", 6000, "Lighting never settled")
		metrics["map"] = list("id" = map.ID, "maxx" = world.maxx, "maxy" = world.maxy, "maxz" = world.maxz, "byond_build" = world.byond_build, "tested_commit" = world.params["tested_commit"], "headless" = headless, "daylight_on_client" = daylight_on_client(), "time_of_day" = time_of_day)
		mark("scene")
		while(world.maxz < building_base_maxz() + 2 && world.maxz < building_base_maxz() + BUILDING_EXTRA_LEVELS)
			require(building_allocate_level(world.maxz + 1), "Could not add an open-air level")
		centre = find_centre()
		require(centre, "No open ground with open air above found")
		metrics["centre"] = "[centre.x],[centre.y],[centre.z]"
		var/up = multiz_level_above(centre.z)
		var/up2 = multiz_level_above(up)
		require(up && up2, "Two open-air levels are needed")
		metrics["levels"] = list("surface" = centre.z, "up" = up, "up2" = up2)
		// A walkway one level up over the centre row, and one two levels up
		// four rows north, so the walkway below has open air over it.
		floor_strip(up, centre.y)
		floor_strip(up2, centre.y + 4)
		take_body(centre)
		pass("body_ready")

		stage("ground_still", FALSE)
		stage("ground_walk", TRUE)

		H.forceMove(locate(centre.x, centre.y, up))
		rescan()
		stage("up1_still", FALSE)
		stage("up1_walk", TRUE)

		// The same, with nothing shown through open air (the sky sprite only).
		var/process/P = processScheduler.getProcess("open air view")
		require(P, "No open air view process")
		P.disable()
		for(var/turf/sky/building/T in world)
			if(T.open_air_view)
				T.open_air_view_clear()
		H.forceMove(locate(centre.x, centre.y, up))
		stage("up1_still_no_view", FALSE)
		stage("up1_walk_no_view", TRUE)
		// Other ways of showing the level below, built by hand around the
		// walkway with the scan paused, to see which part costs the bytes.
		if(world.params["experiments"])
			for(var/mode in list("direct", "copy", "copy_movables"))
				build_views(mode, up)
				H.forceMove(locate(centre.x, centre.y, up))
				stage("up1_still_[mode]", FALSE)
				stage("up1_walk_[mode]", TRUE)
				clear_views()
		P.enable()

		H.forceMove(locate(centre.x, centre.y + 4, up2))
		rescan()
		stage("up2_still", FALSE)
		stage("up2_walk", TRUE)

		// Look up from the first walkway to the open air of the level above.
		H.forceMove(locate(centre.x, centre.y, up))
		sleep(10)
		var/list/why = list()
		require(H.look_up_target(why), "Cannot look up from the walkway: [why.len ? why[1] : "?"]")
		if(C)
			require(H.start_looking_up(), "Look Up did not start")
			rescan()
		stage("up1_look_up", FALSE)
		if(C)
			H.stop_looking_up()
		pass("stages_measured", list("stages" = stages.len))
	catch(var/exception/e)
		failure = "[e.name]"
		failed_phase = phase
	mark("finished")
	var/list/result = list("passed" = isnull(failure), "failure" = failure, "failed_phase" = failed_phase, "checks" = checks, "metrics" = metrics, "stages" = stages, "wall_ds" = world.timeofday - started_tod)
	fdel("result.json")
	text2file(json_encode(result), "result.json")
	world.log << (failure ? "FAIL: open air bandwidth probe: [failure]" : "PASS: open air bandwidth probe")
	sleep(20)
	del(world)

#undef OAB_SETTLE
#undef OAB_MEASURE
#undef OAB_STRIP
