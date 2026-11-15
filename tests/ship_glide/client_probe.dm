// Real-client check for a built hull under way (2026-11-15 live report: the
// ship did not look like the smooth sailing prototype, and a log stack on her
// deck crept along on its own).
// Test-only: client_check.py appends it to a temporary copy of civ13.dme with
// the Gaia map, starts the daemon and connects one Dream Seeker client. The
// probe builds a small hull on open sea with the production craft code, puts
// the client's body aboard with a log stack and a crate, and asks the runner
// to record the client window while she:
//  1. sails at slow ahead (one tile every 15 seconds, drawn as one glide);
//  2. sails on while the log stack is shoved one tile across her deck;
//  3. lies at anchor on a voyage (the sea going by, voyage_sea.dm, when the
//     build under test has it).
// With `-params headless=1` no client is awaited: a rehearsal of the staging.
var/global/datum/ship_client_probe/ship_client_probe = new

/datum/ship_client_probe
	var/list/checks = list()
	var/list/metrics = list()
	var/list/clips = list()
	var/phase = "startup"
	var/started_tod = 0
	var/headless = FALSE
	var/client/C
	var/mob/living/human/H
	var/turf/centre
	var/obj/structure/hull_tiller/tiller
	var/obj/item/stack/material/wood/logs

/mob/living/human/ship_client_actor/ssd_check()
	return FALSE

/datum/ship_client_probe/New()
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

/datum/ship_client_probe/proc/mark(name)
	phase = name
	world.log << "SHIPCLIENT [name]"
	fdel("phase.json")
	text2file(json_encode(list("phase" = name, "world_time" = world.time, "wall_ds" = world.timeofday - started_tod)), "phase.json")

/datum/ship_client_probe/proc/pass(name, list/details = null)
	checks += list(list("check" = name, "passed" = TRUE, "details" = details))

/datum/ship_client_probe/proc/require(condition, message)
	if(!condition)
		throw EXCEPTION(message)

/datum/ship_client_probe/proc/wait_for(proc_name, deadline_ds, message)
	var/until = world.time + deadline_ds
	while(!call(src, proc_name)())
		if(world.time > until)
			throw EXCEPTION(message)
		sleep(5)

/datum/ship_client_probe/proc/game_playing()
	return ticker && ticker.current_state == GAME_STATE_PLAYING

/datum/ship_client_probe/proc/scheduler_ready()
	return ticker && processScheduler && processes && ticker.current_state >= GAME_STATE_PREGAME

/datum/ship_client_probe/proc/lighting_settled()
	return created_lighting_corners_and_overlays && !processes.time_of_day_change.updating_lighting

/datum/ship_client_probe/proc/client_connected()
	return clients.len > 0

// Asks the runner to record the client window for seconds, starting now, and
// returns at once: the probe acts while the clip runs. finish_clip() waits.
/datum/ship_client_probe/proc/start_clip(name, seconds)
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

/datum/ship_client_probe/proc/finish_clip(name)
	if(headless)
		return
	var/until = world.time + 1800
	while(!fexists("clips/[name].done"))
		require(world.time < until, "The runner never finished clip [name]")
		sleep(5)
	clips += name

/datum/ship_client_probe/proc/set_daylight(name)
	spawn(0)
		update_lighting(name, null, FALSE)
	sleep(10)
	wait_for("lighting_settled", 6000, "Lighting never settled on [name]")
	sleep(20)

/datum/ship_client_probe/proc/open_sea(turf/T, r)
	if(!T || T.x <= r + 2 || T.y <= r + 2 || T.x >= world.maxx - r - 2 || T.y >= world.maxy - r - 2)
		return FALSE
	for(var/turf/U in range(r, T))
		if(!istype(U, /turf/floor/beach/water/deep/saltwater) || U.iscovered())
			return FALSE
	return TRUE

// Open sea on the surface: a real one if Gaia has a clear stretch, else a
// patch of the surface turned to deep saltwater.
/datum/ship_client_probe/proc/find_sea()
	var/z = map.sea_layer_surface_z || 2
	var/work = 0
	for(var/x = 30, x <= world.maxx - 30, x += 15)
		for(var/y = 30, y <= world.maxy - 30, y += 15)
			if(++work % 200 == 0)
				sleep(world.tick_lag)
			var/turf/T = locate(x, y, z)
			if(istype(T, /turf/floor/beach/water/deep/saltwater) && open_sea(T, 22))
				metrics["sea"] = "natural"
				return T
	var/turf/mid = locate(round(world.maxx / 2), round(world.maxy / 2), z)
	for(var/turf/U in range(24, mid))
		for(var/atom/movable/A in U)
			if(!istype(A, /atom/movable/lighting_overlay) && !ismob(A))
				qdel(A)
		U.ChangeTurf(/turf/floor/beach/water/deep/saltwater)
	metrics["sea"] = "fixture"
	return locate(mid.x, mid.y, z)

/datum/ship_client_probe/proc/at(dx, dy)
	return locate(centre.x + dx, centre.y + dy, centre.z)

// A hull of 5 x 7 planks, bow north, tiller amidships aft, with a log stack
// and a crate on her deck.
/datum/ship_client_probe/proc/build_hull()
	for(var/dx = -2 to 2)
		for(var/dy = -3 to 3)
			var/obj/covers/repairedfloor/ship/P = new(at(dx, dy))
			P.updateturf()
	tiller = new(at(0, -2))
	var/refusal = tiller.commission("Probe", NORTH)
	require(isnull(refusal) && tiller.craft, "Hull not commissioned: [refusal]")
	logs = new(at(1, 1))
	logs.amount = 30
	logs.update_icon()
	new /obj/structure/closet/crate(at(-1, 2))
	var/datum/craft/K = tiller.craft
	pass("hull_built", list("tiles" = K.body.tile_count(), "glides" = K.glides(), "centre" = "[centre.x],[centre.y],[centre.z]"))

/datum/ship_client_probe/proc/take_body()
	if(headless)
		H = new /mob/living/human/ship_client_actor(at(-1, 0))
		sleep(10)
	else
		mark("waiting_for_client")
		wait_for("client_connected", 18000, "No client connected within 30 minutes")
		C = clients[1]
		sleep(100)
		H = new /mob/living/human(at(-1, 0))
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

/datum/ship_client_probe/proc/sail()
	var/datum/craft/K = tiller.craft
	var/turf/from = get_turf(tiller)
	K.set_anchor(FALSE)
	K.set_speed(VESSEL_SPEED_SLOW)
	return from

/datum/ship_client_probe/proc/check_sailing()
	var/turf/from = get_turf(tiller)
	start_clip("1-sailing", 32)
	sail()
	sleep(310)
	finish_clip("1-sailing")
	var/turf/now = get_turf(tiller)
	require(now.y >= from.y + 2, "She did not make two tiles in 31 seconds ([from.y] -> [now.y])")
	require(logs.loc == locate(tiller.x + 1, tiller.y + 3, tiller.z), "The log stack did not ride with her")
	pass("sails_slow_ahead", list("tiles" = now.y - from.y, "step_interval_ds" = tiller.craft.sail_interval(), "log_glide_size" = logs.glide_size))

/datum/ship_client_probe/proc/check_shove()
	start_clip("2-shove-logs", 14)
	sleep(30)
	var/held = logs.glide_size
	var/turf/T = get_step(logs, WEST)
	logs.Move(T, WEST)
	var/after = logs.glide_size
	require(logs.loc == T, "The log stack could not be shoved")
	sleep(110)
	finish_clip("2-shove-logs")
	pass("logs_shoved", list("glide_while_held" = held, "glide_for_the_shove" = after, "her_step_glide" = craft_glide_size(tiller.craft.sail_interval())))

/datum/ship_client_probe/proc/check_voyage()
	var/datum/craft/K = tiller.craft
	K.set_speed(VESSEL_SPEED_STOP)
	K.set_anchor(TRUE)
	sleep(20)
	tiller.voyage = list("id" = "probe", "kind" = "scout", "label" = "the probe sea", "ends" = world.time + 6000, "minute" = world.time + 600, "tile" = 600, "tiles" = 10, "events" = list())
	var/shown = hascall(tiller, "voyage_sea_show")
	if(shown)
		call(tiller, "voyage_sea_show")()
	start_clip("3-voyage", 10)
	sleep(100)
	finish_clip("3-voyage")
	if(hascall(tiller, "voyage_sea_stop"))
		call(tiller, "voyage_sea_stop")()
	tiller.voyage = null
	pass("voyage_at_anchor", list("sea_goes_by_in_this_build" = shown))

// Diagnosis: who glides? The same sailing seen from a camera fixed on a sea
// tile, then from a camera on her tiller, then from the body again, with the
// body's own movement state written down at each step.
/datum/ship_client_probe/proc/check_cameras()
	var/datum/craft/K = tiller.craft
	var/list/states = list()
	states["body"] = list("step_x" = H.step_x, "step_y" = H.step_y, "bound_x" = H.bound_x, "bound_width" = H.bound_width, "glide_size" = H.glide_size, "animate_movement" = H.animate_movement, "natively" = craft_glides_natively(H))
	K.set_anchor(FALSE)
	K.set_speed(VESSEL_SPEED_SLOW)
	if (!headless)
		C.eye = locate(tiller.x + 3, tiller.y + 2, tiller.z)
		C.perspective = EYE_PERSPECTIVE
	// Two plain markers on open water beside her, moved north by loc at her
	// pace: if they glide and her planks do not, the cause is in her step.
	var/obj/ship_glide_marker/slide = new(locate(tiller.x + 6, tiller.y, tiller.z), tiller, SLIDE_STEPS)
	var/obj/ship_glide_marker/forward = new(locate(tiller.x + 8, tiller.y, tiller.z), tiller, FORWARD_STEPS)
	start_clip("4-fixed-camera", 32)
	sleep(310)
	finish_clip("4-fixed-camera")
	states["markers"] = list("slide_y" = slide.y, "forward_y" = forward.y, "glide" = slide.glide_size, "deleted" = QDELETED(slide), "trace" = slide.trace)
	qdel(slide)
	qdel(forward)
	states["tiller_glide"] = tiller.glide_size
	if (!headless)
		C.eye = tiller
		C.perspective = EYE_PERSPECTIVE
	start_clip("5-camera-on-tiller", 32)
	sleep(310)
	finish_clip("5-camera-on-tiller")
	if (!headless)
		C.eye = H
		C.perspective = MOB_PERSPECTIVE
	start_clip("6-camera-on-body", 32)
	for (var/i = 1 to 6)
		sleep(50)
		states["body_[i]"] = list("x" = H.x, "y" = H.y, "step_x" = H.step_x, "step_y" = H.step_y, "pixel_x" = H.pixel_x, "pixel_y" = H.pixel_y, "glide_size" = H.glide_size, "client_pixel_y" = C ? C.pixel_y : null, "client_eye" = C ? "[C.eye]" : null)
	sleep(10)
	finish_clip("6-camera-on-body")
	K.set_speed(VESSEL_SPEED_STOP)
	pass("cameras", states)

/datum/ship_client_probe/proc/drive()
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
		mark("sea")
		centre = find_sea()
		require(centre, "No sea")
		build_hull()
		take_body()
		sleep(50)
		mark("sailing")
		check_sailing()
		mark("shove")
		check_shove()
		mark("voyage")
		check_voyage()
		mark("cameras")
		check_cameras()
	catch(var/exception/e)
		failure = "[e.name]"
		failed_phase = phase
	mark("finished")
	var/list/result = list("passed" = isnull(failure), "failure" = failure, "failed_phase" = failed_phase, "checks" = checks, "metrics" = metrics, "clips" = clips, "wall_ds" = world.timeofday - started_tod)
	fdel("result.json")
	text2file(json_encode(result), "result.json")
	world.log << (failure ? "FAIL: ship client probe: [failure]" : "PASS: ship client probe")
	sleep(20)
	del(world)

// A plain thing on open water stepping north a tile every 150 ds by loc, at a
// slow-ahead ship's glide (check_cameras).
/obj/ship_glide_marker
	anchored = TRUE
	density = FALSE
	var/list/trace = list() // "world.time/timeofday: x,y loc" at each step.

/obj/ship_glide_marker/New(loc, atom/look, movement)
	..()
	appearance = look.appearance
	animate_movement = movement
	glide_size = craft_glide_size(150)
	spawn(10)
		while (!QDELETED(src))
			var/turf/T = locate(x, y + 1, z)
			if (T)
				loc = T
			trace += "[world.time]/[world.timeofday] cpu [world.cpu]: [x],[y] [loc]"
			sleep(150)
