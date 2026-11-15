// Real-client recording of vehicles rolling by pixels (vehicle_offset_ride.dm).
// Test-only: client_check.py appends it to a temporary copy of civ13.dme with
// the Gaia map, starts the daemon and connects one Dream Seeker client. The
// client's body is seated as the driver and the runner records the window:
//  1. a motorcycle rolling by pixels: second gear east, a turn north, then
//     out of gear so it coasts to a stop;
//  2. the same ride in whole tiles (pixel driving off), for comparison;
//  3. a motorboat (RHIB) on open sea, the same moves.
// Adapted from tests/ship_glide/client_probe.dm.
var/global/datum/vehicle_client_probe/vehicle_client_probe = new

/datum/vehicle_client_probe
	var/list/checks = list()
	var/list/metrics = list()
	var/list/clips = list()
	var/phase = "startup"
	var/started_tod = 0
	var/headless = FALSE
	var/client/C
	var/mob/living/human/H

/mob/living/human/vehicle_client_actor/ssd_check()
	return FALSE

/datum/vehicle_client_probe/New()
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

/datum/vehicle_client_probe/proc/mark(name)
	phase = name
	world.log << "VEHICLECLIENT [name]"
	fdel("phase.json")
	text2file(json_encode(list("phase" = name, "world_time" = world.time, "wall_ds" = world.timeofday - started_tod)), "phase.json")

/datum/vehicle_client_probe/proc/pass(name, list/details = null)
	checks += list(list("check" = name, "passed" = TRUE, "details" = details))

/datum/vehicle_client_probe/proc/require(condition, message)
	if(!condition)
		throw EXCEPTION(message)

/datum/vehicle_client_probe/proc/wait_for(proc_name, deadline_ds, message)
	var/until = world.time + deadline_ds
	while(!call(src, proc_name)())
		if(world.time > until)
			throw EXCEPTION(message)
		sleep(5)

/datum/vehicle_client_probe/proc/game_playing()
	return ticker && ticker.current_state == GAME_STATE_PLAYING

/datum/vehicle_client_probe/proc/scheduler_ready()
	return ticker && processScheduler && processes && ticker.current_state >= GAME_STATE_PREGAME

/datum/vehicle_client_probe/proc/lighting_settled()
	return created_lighting_corners_and_overlays && !processes.time_of_day_change.updating_lighting

/datum/vehicle_client_probe/proc/client_connected()
	return clients.len > 0

/datum/vehicle_client_probe/proc/start_clip(name, seconds)
	mark("clip_[name]")
	if(headless)
		return
	fdel("clip-request.txt")
	text2file("[name] [seconds]", "clip-request.txt")
	var/until = world.time + 300
	while(!fexists("clips/[name].started"))
		require(world.time < until, "The runner never started clip [name]")
		sleep(1)
	fdel("clip-request.txt")

/datum/vehicle_client_probe/proc/finish_clip(name)
	if(headless)
		return
	var/until = world.time + 1800
	while(!fexists("clips/[name].done"))
		require(world.time < until, "The runner never finished clip [name]")
		sleep(5)
	clips += name

/datum/vehicle_client_probe/proc/set_daylight(name)
	spawn(0)
		update_lighting(name, null, FALSE)
	sleep(10)
	wait_for("lighting_settled", 6000, "Lighting never settled on [name]")
	sleep(20)

// A patch of the surface around T turned to turf_type, cleared of everything but mobs and lighting.
/datum/vehicle_client_probe/proc/patch(turf/T, r, turf_type)
	for(var/turf/U in range(r, T))
		for(var/atom/movable/A in U)
			if(!istype(A, /atom/movable/lighting_overlay) && !ismob(A))
				qdel(A)
		U.ChangeTurf(turf_type)
		sleep(0)
	return T

/datum/vehicle_client_probe/proc/surface_z()
	return map.sea_layer_surface_z || 2

/datum/vehicle_client_probe/proc/take_body(turf/T)
	if(headless)
		H = new /mob/living/human/vehicle_client_actor(T)
		sleep(10)
	else
		mark("waiting_for_client")
		wait_for("client_connected", 18000, "No client connected within 30 minutes")
		C = clients[1]
		sleep(100)
		H = new /mob/living/human(T)
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

// Seats the body as the driver, as dragging yourself onto the vehicle does.
/datum/vehicle_client_probe/proc/mount(obj/structure/vehicle/V)
	H.forceMove(get_turf(V))
	H.settle_on_tile()
	H.put_in_active_hand(V.dwheel)
	H.driver = TRUE
	H.driver_vehicle = V
	V.driver = H
	V.buckle_mob(H)
	V.ontop += H
	V.update_overlay()
	V.update_icon()
	require(V.driver == H, "The body is not driving")

/datum/vehicle_client_probe/proc/dismount(obj/structure/vehicle/V)
	V.moving = FALSE
	V.axis.currentspeed = 0
	V.ontop -= H
	H.driver = FALSE
	V.unbuckle_mob()
	H.driver_vehicle = null
	V.driver = null
	if(H.l_hand == V.dwheel || H.r_hand == V.dwheel)
		H.remove_from_mob(V.dwheel)
		V.dwheel.forceMove(V)
	V.update_overlay()
	V.update_icon()

/datum/vehicle_client_probe/proc/gear(obj/structure/vehicle/V, n)
	V.axis.currentspeed = n
	if(n <= 0)
		V.moving = FALSE
		return
	var/spd = V.axis.get_speed()
	if(spd > 0)
		V.vehicle_m_delay = spd
	if(!V.moving)
		V.moving = TRUE
		V.startmovementloop()

/datum/vehicle_client_probe/proc/steer(obj/structure/vehicle/V, d)
	H.dir = d
	V.dir = d
	V.updatepassdir()

// East in second gear, a turn north, then out of gear.
/datum/vehicle_client_probe/proc/ride(obj/structure/vehicle/V, clip, list/track)
	var/turf/from = get_turf(V)
	start_clip(clip, 15)
	sleep(10)
	steer(V, EAST)
	gear(V, 1)
	sleep(15)
	gear(V, 2)
	for(var/i = 1 to 8)
		sleep(5)
		track += list(list("t" = world.time, "x" = V.x, "y" = V.y, "step_x" = V.step_x, "step_y" = V.step_y))
	steer(V, NORTH)
	for(var/i = 1 to 8)
		sleep(5)
		track += list(list("t" = world.time, "x" = V.x, "y" = V.y, "step_x" = V.step_x, "step_y" = V.step_y))
	gear(V, 0)
	for(var/i = 1 to 6)
		sleep(5)
		track += list(list("t" = world.time, "x" = V.x, "y" = V.y, "step_x" = V.step_x, "step_y" = V.step_y))
	sleep(30)
	finish_clip(clip)
	var/turf/now = get_turf(V)
	require(now != from, "[V] did not move")
	return list("from" = "[from.x],[from.y]", "to" = "[now.x],[now.y]", "step" = "[V.step_x],[V.step_y]", "track" = track)

/datum/vehicle_client_probe/proc/check_motorcycle()
	var/z = surface_z()
	var/turf/road = patch(locate(round(world.maxx / 3), round(world.maxy / 3), z), 16, /turf/floor/plating/road)
	var/obj/structure/vehicle/motorcycle/m125/full/M = new(locate(road.x - 8, road.y - 6, z))
	sleep(10)
	M.engine.on = TRUE
	M.running_sound()
	take_body(locate(road.x - 9, road.y - 6, z))
	sleep(30)
	mount(M)
	sleep(20)
	var/list/pixels = ride(M, "1-motorcycle-pixels", list())
	require(M.offset_mover && M.offset_mover.crossings > 0, "The motorcycle never rolled by pixels")
	pass("motorcycle_pixels", pixels)
	// The same ride in whole tiles, as before #5553.
	M.vehicle_offset_release()
	M.offset_drive = FALSE
	M.forceMove(locate(road.x - 8, road.y - 6, z))
	for(var/atom/movable/A in M.ontop)
		A.forceMove(M.loc)
	sleep(20)
	var/list/tiles = ride(M, "2-motorcycle-tiles", list())
	pass("motorcycle_tiles", tiles)
	dismount(M)

/datum/vehicle_client_probe/proc/open_sea(turf/T, r)
	if(!T || T.x <= r + 2 || T.y <= r + 2 || T.x >= world.maxx - r - 2 || T.y >= world.maxy - r - 2)
		return FALSE
	for(var/turf/U in range(r, T))
		if(!istype(U, /turf/floor/beach/water/deep/saltwater) || U.iscovered())
			return FALSE
	return TRUE

/datum/vehicle_client_probe/proc/find_sea()
	var/z = surface_z()
	var/work = 0
	for(var/x = 30, x <= world.maxx - 30, x += 15)
		for(var/y = 30, y <= world.maxy - 30, y += 15)
			if(++work % 200 == 0)
				sleep(world.tick_lag)
			var/turf/T = locate(x, y, z)
			if(istype(T, /turf/floor/beach/water/deep/saltwater) && open_sea(T, 16))
				metrics["sea"] = "natural"
				return T
	metrics["sea"] = "fixture"
	return patch(locate(round(world.maxx * 2 / 3), round(world.maxy * 2 / 3), z), 16, /turf/floor/beach/water/deep/saltwater)

/datum/vehicle_client_probe/proc/check_boat()
	var/turf/sea = find_sea()
	var/obj/structure/vehicle/boat/rhib/premade/B = new(locate(sea.x - 8, sea.y - 6, sea.z))
	sleep(20)
	B.engine.on = TRUE
	B.running_sound()
	H.forceMove(B.loc)
	sleep(20)
	mount(B)
	sleep(20)
	var/list/boat = ride(B, "3-boat-pixels", list())
	require(B.offset_mover && B.offset_mover.crossings > 0, "The boat never rolled by pixels")
	pass("boat_pixels", boat)
	dismount(B)

/datum/vehicle_client_probe/proc/drive()
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
		metrics["map"] = list("id" = map.ID, "byond_version" = world.byond_version, "byond_build" = world.byond_build, "tested_commit" = world.params["tested_commit"], "headless" = headless)
		mark("daylight")
		set_daylight("Midday")
		mark("motorcycle")
		check_motorcycle()
		mark("boat")
		check_boat()
	catch(var/exception/e)
		failure = "[e.name]"
		failed_phase = phase
	mark("finished")
	var/list/result = list("passed" = isnull(failure), "failure" = failure, "failed_phase" = failed_phase, "checks" = checks, "metrics" = metrics, "clips" = clips, "wall_ds" = world.timeofday - started_tod)
	fdel("result.json")
	text2file(json_encode(result), "result.json")
	world.log << (failure ? "FAIL: vehicle client probe: [failure]" : "PASS: vehicle client probe")
	sleep(20)
	del(world)

// A headless rehearsal has no client near the vehicles; count it as watched.
/datum/vehicle_offset/watched()
	if(vehicle_client_probe && vehicle_client_probe.headless)
		return TRUE
	return ..()
