// Real-client check for seeing down through open air. Test-only:
// client_check.py appends it to a temporary copy of civ13.dme, starts the
// daemon and connects one Dream Seeker client. The probe builds a small
// rooftop one level above open ground, stands the client's body on it with
// people, an animal and a crate on the ground below, and asks the runner for a
// screenshot at midday, at night and from a roof one more level up (with a
// floor patch on the level between, so two depths show at once).
// With `-params headless=1` no client is awaited (staging rehearsal only).
var/global/datum/open_air_client_probe/open_air_client_probe = new

/datum/open_air_client_probe
	var/list/checks = list()
	var/list/metrics = list()
	var/list/shots = list()
	var/phase = "startup"
	var/started_tod = 0
	var/headless = FALSE
	var/client/C
	var/mob/living/human/H
	var/turf/centre

/mob/living/human/open_air_client_actor/ssd_check()
	return FALSE

/datum/open_air_client_probe/New()
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

/datum/open_air_client_probe/proc/mark(name)
	phase = name
	world.log << "OPENAIRCLIENT [name]"
	fdel("phase.json")
	text2file(json_encode(list("phase" = name, "world_time" = world.time, "wall_ds" = world.timeofday - started_tod)), "phase.json")

/datum/open_air_client_probe/proc/pass(name, list/details = null)
	checks += list(list("check" = name, "passed" = TRUE, "details" = details))

/datum/open_air_client_probe/proc/require(condition, message)
	if(!condition)
		throw EXCEPTION(message)

/datum/open_air_client_probe/proc/wait_for(proc_name, deadline_ds, message)
	var/until = world.time + deadline_ds
	while(!call(src, proc_name)())
		if(world.time > until)
			throw EXCEPTION(message)
		sleep(5)

/datum/open_air_client_probe/proc/game_playing()
	return ticker && ticker.current_state == GAME_STATE_PLAYING

/datum/open_air_client_probe/proc/scheduler_ready()
	return ticker && processScheduler && processes && ticker.current_state >= GAME_STATE_PREGAME

/datum/open_air_client_probe/proc/lighting_settled()
	return created_lighting_corners_and_overlays && !processes.time_of_day_change.updating_lighting

/datum/open_air_client_probe/proc/client_connected()
	return clients.len > 0

/datum/open_air_client_probe/proc/shot(name)
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

/datum/open_air_client_probe/proc/set_daylight(name)
	spawn(0)
		update_lighting(name, null, FALSE)
	sleep(10)
	wait_for("lighting_settled", 6000, "Lighting never settled on [name]")
	// With daylight drawn on the client, its plane master takes the new light.
	for(var/client/K in clients)
		if(K.mob)
			K.mob.update_lighting_plane()
	metrics["time_of_day_[name]"] = time_of_day
	sleep(20)

/datum/open_air_client_probe/proc/open_tile(turf/T)
	if(!T || T.density || T.opacity || !istype(T, /turf/floor) || istype(T, /turf/floor/beach/water) || los_turf_roofed(T))
		return FALSE
	var/area/home = T.loc
	if(!home || !home.dynamic_lighting)
		return FALSE
	for(var/atom/movable/A in T)
		if(A.opacity || A.density)
			return FALSE
	return TRUE

// Open outdoor ground with open air above it, far from the map edge.
/datum/open_air_client_probe/proc/find_centre()
	for(var/attempt in 1 to 6000)
		if(attempt % 50 == 0)
			sleep(world.tick_lag)
		var/turf/T = locate(rand(40, world.maxx - 40), rand(40, world.maxy - 40), multiz_top_z())
		if(!open_tile(T))
			continue
		var/up = multiz_level_above(T.z)
		if(!up || !istype(locate(T.x, T.y, up), /turf/sky/building))
			continue
		var/good = TRUE
		for(var/turf/U in range(3, T))
			if(!open_tile(U))
				good = FALSE
				break
		if(good)
			return T
	return null

/datum/open_air_client_probe/proc/clear_around(turf/T, radius)
	for(var/turf/U in range(radius, T))
		for(var/atom/movable/A in U)
			if(istype(A, /obj/structure) || istype(A, /mob/living/simple_animal) || istype(A, /obj/covers))
				qdel(A)

/datum/open_air_client_probe/proc/floor_patch(z, x1, y1, x2, y2)
	for(var/turf/sky/building/T in block(locate(x1, y1, z), locate(x2, y2, z)))
		new /obj/covers/wood(T)

/datum/open_air_client_probe/proc/take_body(turf/where)
	if(headless)
		H = new /mob/living/human/open_air_client_actor(where)
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

// Links the cells around the body now when there is no client to scan.
/datum/open_air_client_probe/proc/link_now()
	if(C)
		C.open_air_view_scanned_at = 0
		C.open_air_view_scan()
	else
		open_air_view_link_around(H.z, H.x, H.y, 12, 9)

/datum/open_air_client_probe/proc/count_views(z)
	var/n = 0
	for(var/turf/sky/building/T in range(10, locate(H.x, H.y, z)))
		if(T.open_air_view)
			n++
	return n

/datum/open_air_client_probe/proc/drive()
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
		metrics["map"] = list("id" = map.ID, "maxx" = world.maxx, "maxy" = world.maxy, "maxz" = world.maxz, "byond_build" = world.byond_build, "tested_commit" = world.params["tested_commit"], "headless" = headless, "daylight_on_client" = daylight_on_client())
		mark("daylight")
		set_daylight("Midday")
		mark("scene")
		// Open-air levels are added when someone builds up; add one if none.
		if(!multiz_level_above(multiz_top_z()))
			require(building_allocate_level(world.maxz + 1), "Could not add an open-air level")
		metrics["maxz_after_add"] = world.maxz
		metrics["surface_z"] = multiz_top_z()
		centre = find_centre()
		require(centre, "No open outdoor ground with open air above found")
		metrics["centre"] = "[centre.x],[centre.y],[centre.z]"
		clear_around(centre, 4)
		var/up = multiz_level_above(centre.z)
		// A 3x3 rooftop one level up, west of the centre; the ground east of it
		// is seen through open air.
		floor_patch(up, centre.x - 6, centre.y - 1, centre.x - 4, centre.y + 1)
		var/turf/roof = locate(centre.x - 5, centre.y, up)
		// Who and what stands below.
		for(var/i in 0 to 2)
			var/mob/living/human/P = new(locate(centre.x + i, centre.y + 1 - i, centre.z))
			P.dir = SOUTH
		new /mob/living/simple_animal/deer(locate(centre.x + 2, centre.y + 2, centre.z))
		new /obj/structure/closet/crate(locate(centre.x - 1, centre.y - 2, centre.z))
		// A wooden floor on the ground, which must show over the ground turf.
		new /obj/covers/wood(locate(centre.x + 3, centre.y, centre.z))
		new /obj/covers/wood(locate(centre.x + 4, centre.y, centre.z))
		take_body(roof)
		H.dir = EAST
		link_now()
		sleep(20)
		var/views = count_views(up)
		require(views > 20, "Too few open-air cells were linked around the body ([views])")
		var/turf/sky/building/over = locate(centre.x, centre.y, up)
		require(over.open_air_view && over.open_air_view.shows == centre, "The cell over the centre does not show the ground")
		pass("cells_linked", list("views" = views))
		shot("1_roof_midday")
		mark("dark_night")
		set_daylight("Dark Night")
		shot("2_roof_night")
		set_daylight("Midday")
		// Two levels up, with a floor patch on the level between: ground two
		// levels down and the patch one level down show at once.
		var/up2 = multiz_level_above(up)
		if(!up2 && world.maxz < building_base_maxz() + BUILDING_EXTRA_LEVELS)
			building_allocate_level(world.maxz + 1)
			up2 = multiz_level_above(up)
		metrics["up2"] = up2
		if(up2)
			floor_patch(up2, centre.x - 6, centre.y - 1, centre.x - 4, centre.y + 1)
			floor_patch(up, centre.x + 1, centre.y - 4, centre.x + 3, centre.y - 3)
			H.forceMove(locate(centre.x - 5, centre.y, up2))
			H.dir = EAST
			link_now()
			sleep(20)
			var/turf/sky/building/high = locate(centre.x, centre.y, up2)
			require(high.open_air_view, "The cell two levels up shows nothing")
			var/turf/sky/building/mid = locate(centre.x, centre.y, up)
			require(mid.open_air_view && high.open_air_view.shows == mid && (mid.open_air_view in high.open_air_view.vis_contents), "The chain down from two levels up is broken")
			pass("two_levels_linked")
			var/turf/sky/building/patch_mid = locate(centre.x + 2, centre.y - 4, up)
			var/turf/sky/building/patch_top = locate(centre.x + 2, centre.y - 4, up2)
			var/list/found = list()
			for(var/atom/movable/A in patch_mid)
				found += "[A.type] inv=[A.invisibility] a=[A.alpha] icon=[A.icon] st=[A.icon_state] pl=[A.plane] ly=[A.layer] vf=[A.vis_flags]"
			metrics["patch_mid"] = list("type" = "[patch_mid.type]", "contents" = found, "own_view" = !!patch_mid.open_air_view, "vis" = length(patch_mid.vis_contents))
			metrics["patch_top"] = list("type" = "[patch_top.type]", "view" = !!patch_top.open_air_view, "shows" = patch_top.open_air_view ? "[patch_top.open_air_view.vis_contents.len] [(patch_top.open_air_view.shows == patch_mid)]" : null)
			shot("3_two_levels_up")
		mark("ground_view")
		H.forceMove(locate(centre.x - 3, centre.y, centre.z))
		sleep(10)
		shot("4_ground_level")
		// Look up from the ground beside the roof, with someone on the roof.
		mark("look_up")
		var/mob/living/human/R = new(locate(centre.x - 5, centre.y + 1, up))
		R.dir = SOUTH
		var/list/why = list()
		require(H.look_up_target(why) == locate(H.x, H.y, up), "Cannot look up from beside the roof: [why.len ? why[1] : "?"]")
		if(C)
			require(H.start_looking_up() && C.eye == locate(H.x, H.y, up), "Look Up did not move the eye")
			link_now()
			sleep(20)
			shot("5_look_up")
			H.forceMove(locate(H.x, H.y - 1, H.z))
			H.stop_looking_up()
			sleep(10)
			require(!H.looking_up_at && C.eye == H, "Look Up did not end")
		pass("look_up")
		pass("stages_recorded", list("shots" = shots.len))
	catch(var/exception/e)
		failure = "[e.name]"
		failed_phase = phase
	mark("finished")
	var/list/result = list("passed" = isnull(failure), "failure" = failure, "failed_phase" = failed_phase, "checks" = checks, "metrics" = metrics, "shots" = shots, "wall_ds" = world.timeofday - started_tod)
	fdel("result.json")
	text2file(json_encode(result), "result.json")
	world.log << (failure ? "FAIL: open air client probe: [failure]" : "PASS: open air client probe")
	sleep(20)
	del(world)
