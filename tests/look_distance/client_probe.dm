// Real-client check for Look into Distance and tree-top sight.
// Test-only: client_check.py appends it to a temporary copy of civ13.dme,
// starts the daemon and connects one Dream Seeker client. The probe stands the
// client's body on open midday ground, looks into the distance north and east,
// climbs a tree and looks again, and asks the runner for a screenshot of the
// client window at each stage. For every stage it records the client's view,
// camera offset and which tiles of the panned camera the line-of-sight
// presenter masked, so a black band in a screenshot can be told apart from a
// presenter mask. One stage repeats the tree look with the presenter off.
// With `-params headless=1` no client is awaited (staging rehearsal only).
var/global/datum/look_client_probe/look_client_probe = new

/datum/look_client_probe
	var/list/checks = list()
	var/list/metrics = list()
	var/list/stages = list()
	var/list/shots = list()
	var/phase = "startup"
	var/started_tod = 0
	var/headless = FALSE
	var/client/C
	var/mob/living/human/H
	var/turf/centre

/mob/living/human/look_client_actor/ssd_check()
	return FALSE

/datum/look_client_probe/New()
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

/datum/look_client_probe/proc/mark(name)
	phase = name
	world.log << "LOOKCLIENT [name]"
	fdel("phase.json")
	text2file(json_encode(list("phase" = name, "world_time" = world.time, "wall_ds" = world.timeofday - started_tod)), "phase.json")

/datum/look_client_probe/proc/pass(name, list/details = null)
	checks += list(list("check" = name, "passed" = TRUE, "details" = details))

/datum/look_client_probe/proc/require(condition, message)
	if(!condition)
		throw EXCEPTION(message)

/datum/look_client_probe/proc/wait_for(proc_name, deadline_ds, message)
	var/until = world.time + deadline_ds
	while(!call(src, proc_name)())
		if(world.time > until)
			throw EXCEPTION(message)
		sleep(5)

/datum/look_client_probe/proc/game_playing()
	return ticker && ticker.current_state == GAME_STATE_PLAYING

/datum/look_client_probe/proc/scheduler_ready()
	return ticker && processScheduler && processes && ticker.current_state >= GAME_STATE_PREGAME

/datum/look_client_probe/proc/lighting_settled()
	return created_lighting_corners_and_overlays && !processes.time_of_day_change.updating_lighting

/datum/look_client_probe/proc/client_connected()
	return clients.len > 0

/datum/look_client_probe/proc/shot(name)
	mark("shot_[name]")
	if(headless)
		return
	sleep(40)
	fdel("shot-request.txt")
	text2file(name, "shot-request.txt")
	var/until = world.time + 900
	while(!fexists("shots/[name].png"))
		require(world.time < until, "The runner never captured screenshot [name]")
		sleep(5)
	fdel("shot-request.txt")
	shots += name

/datum/look_client_probe/proc/set_daylight(name)
	spawn(0)
		update_lighting(name, null, FALSE)
	sleep(10)
	wait_for("lighting_settled", 6000, "Lighting never settled on [name]")
	sleep(20)

/datum/look_client_probe/proc/open_tile(turf/T)
	if(!T || T.density || T.opacity || !istype(T, /turf/floor) || istype(T, /turf/floor/beach/water) || los_turf_roofed(T))
		return FALSE
	var/area/home = T.loc
	if(!home || !home.dynamic_lighting)
		return FALSE
	for(var/atom/movable/A in T)
		if(A.opacity || A.density)
			return FALSE
	return TRUE

// Open outdoor ground with at least the view's width of open tiles around it,
// far enough from the map edge for a panned camera.
/datum/look_client_probe/proc/find_centre()
	// Prefer the level with hill heights, where terrain sight applies.
	var/z_pick = 0
	var/datum/terrain_heights/heights = map && map.terrain_height_file ? map.terrain_heights() : null
	if(heights)
		for(var/zt in 1 to world.maxz)
			if(heights.rows_by_z["[zt]"])
				z_pick = zt
				break
	metrics["height_z"] = z_pick
	for(var/attempt in 1 to 6000)
		if(attempt % 50 == 0)
			sleep(world.tick_lag)
		var/turf/T = locate(rand(40, world.maxx - 40), rand(40, world.maxy - 40), z_pick || rand(1, world.maxz))
		if(!open_tile(T))
			continue
		var/good = TRUE
		for(var/turf/U in range(2, T))
			if(!open_tile(U))
				good = FALSE
				break
		if(good)
			return T
	return null

/datum/look_client_probe/proc/take_body()
	if(headless)
		H = new /mob/living/human/look_client_actor(centre)
		sleep(10)
	else
		mark("waiting_for_client")
		wait_for("client_connected", 18000, "No client connected within 30 minutes")
		C = clients[1]
		sleep(100)
		H = new /mob/living/human(centre)
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

// What the camera covers and what the presenter masked, row by row along the
// look direction (rows ahead of the body are positive).
/datum/look_client_probe/proc/record(name, dir = NORTH)
	var/list/row = list("stage" = name, "dir" = dir2text(dir), "looking" = H.looking, "look_amount" = H.look_amount, "climbed" = !!H.climbed_tree)
	if(C)
		var/list/dims = getviewsize(C.view)
		row["view"] = "[C.view]"
		row["view_tiles"] = dims
		row["pixel_x"] = C.pixel_x
		row["pixel_y"] = C.pixel_y
		row["eye_is_body"] = C.eye == H
		var/datum/los_presenter/P = C.los_presenter
		row["presenter"] = P && !P.retired
		var/list/masked_by_row = list()
		var/list/turfs_by_row = list()
		var/half_x = round(dims[1] / 2) + 12
		var/half_y = round(dims[2] / 2) + 12
		for(var/dx = -half_x to half_x)
			for(var/dy = -half_y to half_y)
				var/turf/T = locate(H.x + dx, H.y + dy, H.z)
				if(!T)
					continue
				var/ahead = dir == NORTH ? dy : dx
				var/key = "[ahead]"
				turfs_by_row[key] = (turfs_by_row[key] || 0) + 1
				if(P && !P.retired && P.images[T])
					masked_by_row[key] = (masked_by_row[key] || 0) + 1
		row["masked_turfs_by_row_ahead"] = masked_by_row
		if(C.los_context)
			var/list/radii = C.los_context.viewport_radii()
			row["los_radii"] = radii
			var/list/terrain = los_terrain_for(H, radii ? max(radii[1], radii[2]) + 2 : 9)
			row["terrain_field"] = !!terrain
	stages += list(row)
	return row

/datum/look_client_probe/proc/look(dir)
	H.dir = dir
	sleep(5)
	H.look_into_distance(H, TRUE)
	sleep(20)
	require(headless || H.looking, "Look into Distance did not start facing [dir2text(dir)]")

/datum/look_client_probe/proc/unlook()
	H.look_into_distance(H, FALSE)
	sleep(20)

/datum/look_client_probe/proc/drive()
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
		if(processes.weather)
			processes.weather.disable()
		metrics["map"] = list("id" = map.ID, "maxx" = world.maxx, "maxy" = world.maxy, "byond_version" = world.byond_version, "byond_build" = world.byond_build, "tested_commit" = world.params["tested_commit"], "headless" = headless)
		mark("daylight")
		set_daylight("Midday")
		mark("scene")
		centre = find_centre()
		require(centre, "No open outdoor ground found")
		for(var/turf/U in range(1, centre))
			for(var/atom/movable/A in U)
				if(istype(A, /obj/structure) || istype(A, /mob/living/simple_animal))
					qdel(A)
		metrics["centre"] = "[centre.x],[centre.y],[centre.z]"
		take_body()
		H.dir = NORTH
		shot("1_standing")
		record("1_standing")
		look(NORTH)
		shot("2_look_north")
		record("2_look_north")
		unlook()
		look(EAST)
		shot("3_look_east")
		record("3_look_east", EAST)
		unlook()
		var/obj/structure/wild/tree/live_tree/W = new(centre)
		W.icon_state = "tree_1"
		sleep(10)
		require(tree_grown_enough(W), "Staged tree is too small to climb")
		require(H.finish_climb_tree(W), "Could not climb the staged tree")
		H.dir = NORTH
		shot("4_tree_top")
		record("4_tree_top")
		look(NORTH)
		shot("5_tree_look_north")
		record("5_tree_look_north")
		if(C)
			// Same look with the geometric presenter switched off: what is
			// left black then is not a presenter mask.
			C.los_enabled = FALSE
			C.reconcile_geometric_los()
			shot("6_tree_look_north_no_presenter")
			record("6_tree_look_north_no_presenter")
			C.los_enabled = TRUE
			C.reconcile_geometric_los()
		unlook()
		shot("7_final")
		record("7_final")
		pass("stages_recorded", list("count" = stages.len))
	catch(var/exception/e)
		failure = "[e.name]"
		failed_phase = phase
	mark("finished")
	var/list/result = list("passed" = isnull(failure), "failure" = failure, "failed_phase" = failed_phase, "checks" = checks, "metrics" = metrics, "stages" = stages, "shots" = shots, "wall_ds" = world.timeofday - started_tod)
	fdel("result.json")
	text2file(json_encode(result), "result.json")
	world.log << (failure ? "FAIL: look client probe: [failure]" : "PASS: look client probe")
	sleep(20)
	del(world)
