// Village trailer fixture: isolated scene startup, guest observer camera and
// lighting. Derived from the reviewed cloud harvest/bakery/carriage fixtures.
// Disposable trailer build only; never part of a live or persistent world.
var/intro_ready = FALSE
var/intro_started = FALSE
var/intro_stopping = FALSE
var/intro_headless = FALSE
var/client/intro_observer_client
var/intro_port

// Scripted headless actor, not a connected player. Keep inherited Life and status checks.
/mob/living/human/intro_actor/ssd_check()
	return FALSE

/world
	name = "Civ13 village trailer"
	hub = ""
	hub_password = ""
	visibility = FALSE
	mob = /mob/intro_observer
	// One extra ring of tiles beyond the 15x9 frame, clipped by the zoomed map
	// control, so the camera's sub-tile pixel offsets never reveal unsent tiles.
	view = "17x11"
	fps = 20

/world/OpenPort(requested)
	if (requested == "none")
		return ..("none")
	if (intro_ready && intro_port && requested == intro_port)
		return ..(requested)
	return FALSE

/world/Topic()
	return null

/world/Reboot()
	intro_stop("reboot prohibited")

/world/Error(exception/E)
	text2file("[world.time] runtime: [E.name] at [E.file]:[E.line]", "trailer-runtimes.txt")

/proc/intro_denied_shell()
	throw EXCEPTION("Trailer fixture: OS shell disabled")

/proc/intro_denied_export()
	throw EXCEPTION("Trailer fixture: outbound network disabled")

/proc/intro_check(ok, label)
	if (!ok)
		throw EXCEPTION("Trailer fixture: [label]")

/proc/trailer_log(text)
	text2file("[world.time] [text]", "trailer-log.txt")

/proc/intro_stop(reason)
	if (intro_stopping)
		return
	intro_stopping = TRUE
	world.OpenPort("none")
	text2file(reason, "trailer-stop.txt")
	del(world)

/obj/map_metadata/little_creek/intro/New()
	// Keep inherited era/rules; omit base round timers, jobs and mode startup.
	map = src

/proc/intro_initialize()
	config = new
	config.webhook_can_fire = FALSE
	config.ToRban = FALSE
	map = new /obj/map_metadata/little_creek/intro
	generate_gameid()
	makeDatumRefLists()
	initialize_chemical_reagents()
	initialize_chemical_reactions()
	populate_material_list()

/client/New()
	if (intro_headless || !intro_ready || intro_observer_client || copytext(key, 1, 7) != "Guest-" || address != "127.0.0.1")
		del(src)
		return
	intro_observer_client = src
	for (var/fixture_verb in verbs.Copy())
		verbs -= fixture_verb
	..()
	view = "17x11"
	fps = 20
	trailer_camera_attach(src)
	text2file("guest=1;version=[byond_version];build=[byond_build]", "cloud-client.txt")
	spawn(20)
		trailer_begin()

/client/Del()
	if (src == intro_observer_client)
		intro_stop("observer disconnected")
	return ..()

/client/Topic()
	return null

/client/Move()
	return FALSE

/mob/intro_observer
	name = "Trailer camera"
	density = FALSE
	invisibility = 101
	// A film camera, not a character: see past opaque trees and walls so
	// tiles behind them are never blacked out by line of sight.
	sight = SEE_TURFS|SEE_MOBS|SEE_OBJS

/mob/intro_observer/Login()
	loc = locate(8, 10, 1)
	for (var/fixture_verb in verbs.Copy())
		verbs -= fixture_verb

/mob/intro_observer/Move()
	return FALSE

/mob/intro_observer/Logout()
	return

/mob/intro_observer/ClickOn()
	return

// Stepping all actors' native Life handlers at the mob process's one-second cadence.
/proc/intro_life_loop()
	while (!intro_stopping)
		for (var/mob/living/L in trailer_living)
			if (!QDELETED(L))
				try
					L.Life()
				catch (var/exception/life_error)
					trailer_log("life error [L]: [life_error.name]")
		sleep(10)

/proc/intro_lighting_loop()
	var/process/lighting_sources/S = new
	var/process/lighting_overlays/O = new
	S.setup()
	O.setup()
	while (!intro_stopping)
		try
			if (fexists("trailer-abort.txt"))
				intro_stop("controller abort")
				return
			S.run_time_tick_usage = world.tick_usage
			S.run_time_tick_usage_allowance = 5
			S.fire()
			O.run_time_tick_usage = world.tick_usage
			O.run_time_tick_usage_allowance = 5
			O.fire()
		catch (var/exception/light_error)
			trailer_log("lighting error: [light_error.name]")
		sleep(1)

/proc/trailer_begin()
	if (intro_started || intro_stopping)
		return
	intro_started = TRUE
	try
		trailer_prepare()
		spawn(0)
			intro_life_loop()
		sleep(10)
		trailer_camera_cut(TRAILER_OPENING_X, TRAILER_OPENING_Y)
		sleep(10)
		// Hand-shake with the capture controller so frame zero is the opening shot.
		text2file("armed", "trailer-armed.txt")
		var/deadline = world.time + 300
		while (!intro_headless && !fexists("trailer-capturing.txt") && world.time < deadline)
			sleep(1)
		intro_check(intro_headless || fexists("trailer-capturing.txt"), "capture controller started")
		trailer_timeline_origin = world.time
		trailer_beat("start")
		trailer_run()
		trailer_beat("end")
		text2file("done", "trailer-done.txt")
		if (intro_headless)
			intro_stop("headless take complete")
	catch (var/exception/take_error)
		trailer_log("take failed: [take_error.name] at [take_error.file]:[take_error.line]")
		intro_stop("take failed: [take_error.name]")

/world/New()
	OpenPort("none")
	try
		intro_headless = params["headless"] == "1"
		trailer_log("world start [world.maxx]x[world.maxy]x[world.maxz] headless=[intro_headless]")
		intro_check(maxx == TRAILER_MAP_W && maxy == TRAILER_MAP_H && maxz == 1, "authored village dimensions")
		intro_check(GLOB && GLOB.moved_event && GLOB.dir_set_event && GLOB.nanomanager, "original global registries")
		movementMachine = new
		init_sticker_registry()
		for (var/atom/movable/A in world)
			if (!A.gcDestroyed)
				A.initialize()
		for (var/area/A in area_list)
			A.initialize()
		var/process/time_of_day_change/T = new
		T.setup()
		create_lighting("Midday")
		intro_check(apply_restored_lighting(), "normal daylight application")
		spawn(0)
			intro_lighting_loop()
		sleep(3)
		intro_ready = TRUE
		if (intro_headless)
			spawn(0)
				trailer_begin()
		else
			intro_port = text2num(params["intro_port"])
			intro_check(intro_port >= 1024 && intro_port <= 65535, "isolated port")
			OpenPort(intro_port)
			intro_check(port == intro_port, "observer listener opened")
			text2file("port=[port]", "cloud-listening.txt")
		spawn(TRAILER_TIMEOUT)
			intro_stop("bounded scene timeout")
	catch (var/exception/startup_error)
		trailer_log("startup failed: [startup_error.name] at [startup_error.file]:[startup_error.line]")
		intro_stop("startup failed: [startup_error.name]")
