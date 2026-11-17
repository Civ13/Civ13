// Real-client check for what a moving craft leaves behind (2026-11-17 live
// report: a black patch the shape of a ship's deck stayed behind her).
// `-params mode=ship` sails a roofed sea hull with an upper deck at slow
// ahead (her pixel-offset sailing, watched by the client); the default flies
// a crewed airship.
// Test-only: client_check.py appends it to a temporary copy of civ13.dme,
// starts the daemon and connects one Dream Seeker client. The probe lays a
// deck on the open air over open sea with the production airship code (a
// wide bow and a narrow stern, gas cells and a helm), puts the client's body
// on her deck at Midday and asks the runner for a picture of the client
// window as she flies north, after each few hops and after a wait.
// With `-params headless=1` no client is awaited: a rehearsal of the staging.
var/global/datum/air_client_probe/air_client_probe = new

/mob/living/human/air_client_actor/ssd_check()
	return FALSE

/datum/air_client_probe
	var/list/checks = list()
	var/list/metrics = list()
	var/list/clips = list()
	var/phase = "startup"
	var/started_tod = 0
	var/headless = FALSE
	var/client/C
	var/mob/living/human/H
	var/turf/centre
	var/sky_z = 0
	var/obj/structure/airship_helm/helm
	var/obj/structure/hull_tiller/tiller
	var/mode = "air"

/datum/air_client_probe/New()
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

/datum/air_client_probe/proc/mark(name)
	phase = name
	world.log << "AIRCLIENT [name]"
	fdel("phase.json")
	text2file(json_encode(list("phase" = name, "world_time" = world.time, "wall_ds" = world.timeofday - started_tod)), "phase.json")

/datum/air_client_probe/proc/pass(name, list/details = null)
	checks += list(list("check" = name, "passed" = TRUE, "details" = details))

/datum/air_client_probe/proc/require(condition, message)
	if(!condition)
		throw EXCEPTION(message)

/datum/air_client_probe/proc/wait_for(proc_name, deadline_ds, message)
	var/until = world.time + deadline_ds
	while(!call(src, proc_name)())
		if(world.time > until)
			throw EXCEPTION(message)
		sleep(5)

/datum/air_client_probe/proc/game_playing()
	return ticker && ticker.current_state == GAME_STATE_PLAYING

/datum/air_client_probe/proc/scheduler_ready()
	return ticker && processScheduler && processes && ticker.current_state >= GAME_STATE_PREGAME

/datum/air_client_probe/proc/sky_ready()
	return building_standing_present()

/datum/air_client_probe/proc/lighting_settled()
	return created_lighting_corners_and_overlays && !processes.time_of_day_change.updating_lighting

/datum/air_client_probe/proc/client_connected()
	return clients.len > 0

// Asks the runner for a picture of the client window (the still taken at the
// start of a short clip) and waits for the clip to end.
/datum/air_client_probe/proc/shot(name)
	mark("clip_[name]")
	if(headless)
		return
	fdel("clip-request.txt")
	text2file("[name] 3", "clip-request.txt")
	var/until = world.time + 300
	while(!fexists("clips/[name].started"))
		require(world.time < until, "The runner never started clip [name]")
		sleep(1)
	fdel("clip-request.txt")
	until = world.time + 600
	while(!fexists("clips/[name].done"))
		require(world.time < until, "The runner never finished clip [name]")
		sleep(5)
	clips += name

/datum/air_client_probe/proc/set_daylight(name)
	spawn(0)
		update_lighting(name, null, FALSE)
	sleep(10)
	wait_for("lighting_settled", 6000, "Lighting never settled on [name]")
	sleep(20)

/datum/air_client_probe/proc/at(dx, dy, level = 0)
	return locate(centre.x + dx, centre.y + dy, level || sky_z)

// A patch of deep sea on the surface with clear open air above it.
/datum/air_client_probe/proc/stage_sea()
	var/z = 0
	for(var/level = 1 to world.maxz)
		var/up = multiz_level_above(level)
		if(up && istype(locate(1, 1, up), /turf/sky))
			z = level
			sky_z = up
			break
	require(z && sky_z, "No ground with open air above")
	centre = locate(round(world.maxx / 2), round(world.maxy / 2), z)
	for(var/dx = -24 to 24)
		for(var/dy = -24 to 24)
			for(var/level in list(z, sky_z))
				var/turf/T = locate(centre.x + dx, centre.y + dy, level)
				if(!T)
					continue
				for(var/atom/movable/A in T)
					if(istype(A, /atom/movable/lighting_overlay) || istype(A, /atom/movable/lighting_fullbright))
						continue
					if(A.density || ismob(A) || isobj(A))
						A.loc = null
				if(level == z && T.type != /turf/floor/beach/water/deep/saltwater)
					T.ChangeTurf(/turf/floor/beach/water/deep/saltwater)
				if(level == sky_z && T.type != /turf/sky/building)
					T.ChangeTurf(/turf/sky/building)
	// As a world restore leaves them: open-air cells under her made anew
	// (registered, with a lighting overlay) without the woken cell's corners.
	if(world.params["restored"])
		for(var/dx = -1 to 5)
			for(var/dy = -1 to 6)
				var/turf/T = locate(centre.x + dx, centre.y + dy, sky_z)
				T.ChangeTurf(/turf/sky/building)
	sleep(20)
	metrics["restored"] = world.params["restored"] ? TRUE : FALSE
	metrics["centre"] = "[centre.x],[centre.y],[centre.z] under [sky_z]"

// Deck: 5 wide for rows 2-5 and 3 wide for the stern rows 0-1, bow north.
/datum/air_client_probe/proc/build_airship()
	var/obj/structure/multiz/ladder/placed/top = new(at(-1, 0))
	for(var/dx = 0 to 4)
		for(var/dy = 0 to 5)
			if(dy < 2 && (dx == 0 || dx == 4))
				continue
			new /obj/covers/airship_deck(at(dx, dy))
	sleep(10)
	for(var/dx in list(1, 3))
		for(var/dy in list(3, 4))
			new /obj/structure/airship_gas_cell(at(dx, dy))
	helm = new(at(2, 4))
	var/refusal = helm.commission("Probe", NORTH)
	require(isnull(refusal) && helm.craft, "Airship not commissioned: [refusal]")
	top.loc = null
	pass("airship_built", list("tiles" = helm.craft.body.tile_count()))

/datum/air_client_probe/proc/take_body(level = 0)
	if(headless)
		H = new /mob/living/human/air_client_actor(at(2, 2, level))
		sleep(10)
	else
		mark("waiting_for_client")
		wait_for("client_connected", 18000, "No client connected within 30 minutes")
		C = clients[1]
		sleep(100)
		H = new /mob/living/human(at(2, 2, level))
		H.ckey = C.ckey
		sleep(50)
		C = H.client
		require(C && C.mob == H, "The client did not take the staged body")
		metrics["client"] = list("byond_version" = C.byond_version, "byond_build" = C.byond_build, "view" = "[C.view]")
	H.sleeping = 0
	H.resting = FALSE
	H.update_canmove()
	H.a_intent = I_HELP
	spawn(0)
		while(H && !QDELETED(H))
			H.bodytemperature = H.species.body_temperature
			H.nutrition = 400
			H.water = 400
			sleep(10)

// The open-air cells she has just left: their view of the sea below.
/datum/air_client_probe/proc/wake_left(list/before)
	var/list/rows = list()
	for(var/turf/sky/building/T in before)
		if(locate(/obj/covers) in T)
			continue
		rows += "[T.x],[T.y] view=[T.open_air_view ? 1 : 0] icon=[T.icon] lit=[T.lighting_overlay ? T.lighting_overlay.luminosity : "none"] corners=[!!T.corner_ne + !!T.corner_se + !!T.corner_sw + !!T.corner_nw]"
	return rows

/datum/air_client_probe/proc/hops(n)
	var/datum/craft/K = helm.craft
	var/list/before = K.body.cells()
	for(var/i = 1 to n)
		require(K.sail_hop(), "Hop refused: [K.last_refusal]")
		sleep(10)
	return before

/datum/air_client_probe/proc/fly()
	var/datum/craft/K = helm.craft
	K.set_anchor(FALSE)
	K.speed = VESSEL_SPEED_SLOW
	K.stop_sailing() // The probe steps her itself.
	shot("1-built")
	var/list/left = hops(4)
	shot("2-after-4-hops")
	var/list/now = wake_left(left)
	sleep(80)
	shot("3-after-wait")
	var/list/later = wake_left(left)
	left = hops(4)
	shot("4-after-8-hops")
	sleep(80)
	shot("5-final")
	pass("flown", list("left_at_once" = now, "left_after_wait" = later, "left_final" = wake_left(left), "body" = "[H.x],[H.y],[H.z]"))

/datum/air_client_probe/proc/drive()
	var/failure = null
	var/failed_phase = null
	headless = world.params["headless"] ? TRUE : FALSE
	if(world.params["mode"] == "ship")
		mode = "ship"
	try
		mark("startup")
		wait_for("scheduler_ready", 9000, "Scheduler/ticker never became ready")
		ticker.admin_started = TRUE
		if(ticker.pregame_timeleft > 1)
			ticker.pregame_timeleft = 1
		wait_for("game_playing", 3000, "Round did not reach PLAYING")
		wait_for("sky_ready", 3000, "No building level")
		if(processes.weather)
			processes.weather.disable()
		metrics["map"] = list("id" = map.ID, "byond_version" = world.byond_version, "byond_build" = world.byond_build, "tested_commit" = world.params["tested_commit"], "headless" = headless, "client_tint" = daylight_on_client())
		mark("daylight")
		set_daylight("Midday")
		mark("sea")
		stage_sea()
		if(mode == "ship")
			build_ship()
			take_body(centre.z)
			sleep(50)
			mark("sailing")
			sail()
		else
			build_airship()
			take_body()
			sleep(50)
			mark("flight")
			fly()
	catch(var/exception/e)
		failure = "[e.name]"
		failed_phase = phase
	mark("finished")
	var/list/result = list("passed" = isnull(failure), "failure" = failure, "failed_phase" = failed_phase, "checks" = checks, "metrics" = metrics, "clips" = clips, "wall_ds" = world.timeofday - started_tod)
	fdel("result.json")
	text2file(json_encode(result), "result.json")
	world.log << (failure ? "FAIL: air client probe: [failure]" : "PASS: air client probe")
	sleep(20)
	del(world)

// A sea hull of the same shape: a 5 x 4 bow roofed over (a floor above it, a
// ladder up), a 3 x 2 open stern with her tiller. Bow north.
/datum/air_client_probe/proc/build_ship()
	for(var/dx = 0 to 4)
		for(var/dy = 0 to 5)
			if(dy < 2 && (dx == 0 || dx == 4))
				continue
			var/obj/covers/repairedfloor/ship/P = new(at(dx, dy, centre.z))
			P.updateturf()
	new /obj/structure/roof_support(at(2, 4, centre.z))
	var/roofs = 0
	for(var/dx = 0 to 4)
		for(var/dy = 3 to 5)
			if(building_construct_roof(at(dx, dy, centre.z), /obj/roof/wood, null))
				roofs++
	var/obj/structure/multiz/ladder/up/foot = new(at(1, 3, centre.z))
	var/obj/structure/multiz/ladder/head = new(at(1, 3))
	foot.find_target()
	head.find_target()
	tiller = new(at(2, 1, centre.z))
	var/refusal = tiller.commission("Probe", NORTH)
	require(isnull(refusal) && tiller.craft, "Hull not commissioned: [refusal]")
	pass("ship_built", list("tiles" = tiller.craft.body.tile_count(), "roofs" = roofs, "upper" = tiller.craft.body:upper_tile_count()))

/datum/air_client_probe/proc/sea_left(list/before)
	var/list/rows = list()
	for(var/turf/T in before)
		if(locate(/obj/covers) in T)
			continue
		var/area/A = T.loc
		rows += "[T.x],[T.y],[T.z] [A.type] wl=[T.water_level] lit=[T.lighting_overlay ? T.lighting_overlay.luminosity : "none"] a20=[T.lighting_overlay && islist(T.lighting_overlay.color) ? T.lighting_overlay.color[20] : "-"] wc=[T.window_coeff]"
	return rows

/datum/air_client_probe/proc/sail()
	var/datum/craft/K = tiller.craft
	var/list/left = K.body.cells()
	var/turf/from = get_turf(tiller)
	K.set_anchor(FALSE)
	K.set_speed(VESSEL_SPEED_SLOW)
	shot("1-built")
	sleep(330)
	shot("2-sailing")
	sleep(330)
	shot("3-sailing-more")
	K.set_speed(VESSEL_SPEED_STOP)
	sleep(50)
	shot("4-stopped")
	// Up the ladder to her upper deck.
	var/turf/up = null
	for(var/turf/T in K.body.cells())
		var/obj/structure/multiz/ladder/up/L = locate() in T
		if(L && L.target)
			up = get_turf(L.target)
	if(up)
		H.forceMove(up)
		sleep(30)
	shot("5-upper-deck")
	var/turf/now = get_turf(tiller)
	pass("flown", list("from" = "[from.x],[from.y]", "to" = "[now.x],[now.y]", "left" = sea_left(left), "upper" = !!up))
