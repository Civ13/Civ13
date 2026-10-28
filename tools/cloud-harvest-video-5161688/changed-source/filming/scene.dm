// Proposed recording fixture; requires a NEW build and runtime admission.
// Crop translation: original (x,y,z=2) -> (x,y-151,z=1).
var/intro_ready = FALSE
var/intro_prepared = FALSE
var/intro_started = FALSE
var/intro_stopping = FALSE
var/client/intro_observer_client
var/intro_observer_ckey
var/intro_port
// Scripted headless actor, not a connected player. Keep inherited Life and status checks.
/mob/living/human/intro_actor/ssd_check()
	return FALSE // Match existing core_boot_actor and game_loop_actor fixtures.

/world
	name = "Civ13 harvest take"
	hub = ""
	hub_password = ""
	visibility = FALSE
	mob = /mob/intro_observer
	// The authored DMM supplies dimensions; exact runtime size is asserted below.
	view = 7
	fps = 20

/world/OpenPort(requested)
	if (requested == "none")
		return ..("none")
	if (HARVEST_VIDEO_RELEASED && intro_ready && intro_port && requested == intro_port)
		return ..(requested)
	return FALSE

/world/Topic()
	return null

/world/Reboot()
	intro_stop("reboot prohibited")

/world/Error(exception/E)
	intro_stop("native error: [E.name]")

/proc/intro_denied_shell()
	throw EXCEPTION("Harvest fixture: OS shell disabled")

/proc/intro_denied_export()
	throw EXCEPTION("Harvest fixture: outbound network disabled")

/proc/intro_check(ok, label)
	if (!ok)
		throw EXCEPTION("Harvest fixture: [label]")
	text2file("[world.time] [label]", "intro-checks.txt")

/proc/intro_stop(reason)
	if (intro_stopping)
		return
	intro_stopping = TRUE
	world.OpenPort("none")
	text2file(reason, "intro-stop.txt")
	// Process exit must still be confirmed by the admitted owned supervisor.
	del(world)

/obj/map_metadata/little_creek/intro/New()
	// Keep inherited era/rules; omit base round timers, jobs and mode startup.
	map = src

/proc/intro_initialize()
	if (!HARVEST_VIDEO_RELEASED)
		return
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
	if (!HARVEST_VIDEO_RELEASED || !intro_ready || intro_observer_client || copytext(key, 1, 7) != "Guest-" || address != "127.0.0.1" || byond_version != 516 || byond_build != 1688)
		del(src)
		return
	intro_observer_client = src
	intro_observer_ckey = ckey
	for (var/fixture_verb in verbs.Copy())
		verbs -= fixture_verb
	intro_check(!verbs.len, "client verbs empty before native New")
	..()
	intro_check(!verbs.len, "client verbs empty after native New")
	intro_check(istype(mob, /mob/intro_observer) && !mob.verbs.len, "observer verbs empty before capture")
	eye = locate(8, 8, 1)
	perspective = EYE_PERSPECTIVE
	view = 7
	intro_check(byond_version == 516 && byond_build == 1688, "existing client engine 516.1688")
	fps = 20
	intro_cadence_write("admission")
	text2file("guest=1;version=516;build=1688", "cloud-client.txt")
	spawn(20)
		var/mob/intro_observer/O = mob
		O.Prepare_harvest()
		O.Run_harvest()

/client/Del()
	if (src == intro_observer_client)
		intro_stop("observer disconnected")
	return ..()

/client/Topic()
	return null

/client/Move()
	return FALSE

/mob/intro_observer
	name = "Harvest observer"
	density = FALSE
	invisibility = 101

/mob/intro_observer/Login()
	loc = locate(8, 8, 1)
	// Mutate the native special list; do not replace it or remove procs.
	for (var/fixture_verb in verbs.Copy())
		verbs -= fixture_verb
	intro_check(!verbs.len, "observer verbs empty after Login")

/mob/intro_observer/Move()
	return FALSE

/mob/intro_observer/Logout()
	return

/mob/intro_observer/ClickOn()
	return

/mob/intro_observer/proc/Abort_harvest()
	if (client == intro_observer_client)
		intro_stop("observer abort")

/mob/intro_observer/proc/Prepare_harvest()
	if (!HARVEST_VIDEO_RELEASED || client != intro_observer_client || harvest_actor || intro_stopping)
		return
	try
		intro_prepare()
	catch (var/exception/prepare_error)
		intro_stop("preparation failed: [prepare_error.name]")

/mob/intro_observer/proc/Run_harvest()
	if (!HARVEST_VIDEO_RELEASED || client != intro_observer_client || !intro_prepared || intro_started || intro_stopping)
		return
	intro_started = TRUE
	try
		intro_check(!fexists("intro-first-sample.txt") && !fexists("intro-armed.txt"), "fresh one-shot capture handshake")
		intro_cadence_write("start")
		text2file("armed", "intro-armed.txt")
		var/ack_deadline = world.time + 50
		while (!intro_stopping && !fexists("intro-first-sample.txt") && world.time < ack_deadline)
			sleep(0.5)
		intro_check(!intro_stopping && world.time < ack_deadline && file2text("intro-first-sample.txt") == "first_owned_sample\n", "first owned sample releases unchanged action")
		var/start_time = world.time
		text2file(json_encode(list("world_time_ds" = start_time)), "intro-action-start.json")
		harvest_take()
	catch (var/exception/take_error)
		intro_stop("take failed: [take_error.name]")

/proc/intro_prepare()
	harvest_prepare()
	spawn(0)
		intro_life_loop()
	// Native pre-roll settling only; work/growth timers remain unchanged.
	sleep(10)
	intro_check(!intro_stopping && !harvest_actor.incapacitated(), "capable actor after native render settling")
	intro_prepared = TRUE

/proc/intro_life_loop()
	// Preserve normal actor Life handlers at the mob process's one-second cadence.
	// This is an isolated one-actor scene, not full-round scheduler acceptance.
	while (!intro_stopping)
		try
			harvest_actor.Life()
		catch (var/exception/life_error)
			intro_stop("actor life failed: [life_error.name]")
		sleep(10)

/proc/intro_lighting_loop()
	var/process/lighting_sources/S = new
	var/process/lighting_overlays/O = new
	S.setup()
	O.setup()
	while (!intro_stopping)
		try
			intro_capture_requests()
			S.run_time_tick_usage = world.tick_usage
			S.run_time_tick_usage_allowance = 5
			S.fire()
			O.run_time_tick_usage = world.tick_usage
			O.run_time_tick_usage_allowance = 5
			O.fire()
		catch (var/exception/light_error)
			intro_stop("lighting failed: [light_error.name]")
		sleep(1)

/world/New()
	OpenPort("none")
	if (!HARVEST_VIDEO_RELEASED)
		intro_stop("NATIVE HOLD: compile-review only")
		return
	try
		intro_check(!port && byond_version == 516 && byond_build == 1688, "engine and closed port")
		text2file(json_encode(list("schema" = 1, "phase" = "before_crop_guard", "maxx" = world.maxx, "maxy" = world.maxy, "maxz" = world.maxz, "map_file" = "filming/harvest.dmm", "expected_map_sha256" = "55f245424868c71ef3838b4c66a1c042a2ab7a4336837ac996a113f4737dafea", "game_source" = "58404f5bd16e3fed80f1d9844c5db3edd144942c")), "intro-checks.txt")
		intro_check(maxx == 15 && maxy == 15 && maxz == 1, "exact 225-cell crop")
		intro_check((locate(/obj/structure/farming/plant/wheat) in locate(8,9,1)), "authored harvest landmark")
		intro_check(GLOB && GLOB.moved_event && GLOB.dir_set_event && GLOB.nanomanager, "original global registries")
		intro_port = text2num(params["intro_port"])
		intro_check(params["observer_mode"] == "engine_guest_camera" && intro_port >= 1024 && intro_port <= 65535, "explicit observer and isolated port")
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
		var/turf/actor_turf = locate(8,10,1)
		intro_check(actor_turf.lighting_overlay && !actor_turf.lighting_overlay.invisibility, "actor tile has visible native lighting overlay")
		intro_ready = TRUE
		OpenPort(intro_port)
		intro_check(port == intro_port, "observer listener opened")
		text2file("port=[port];version=516;build=1688", "cloud-listening.txt")
		spawn(1200)
			intro_stop("bounded scene timeout")
	catch (var/exception/startup_error)
		intro_stop("startup failed: [startup_error.name]")

// Fixed-name, one-use local evidence handshake. No arbitrary verbs or commands.
/proc/intro_cadence_write(phase)
	intro_check(phase in list("admission", "start", "end"), "fixed cadence phase")
	intro_check(intro_observer_client && istype(intro_observer_client.mob, /mob/intro_observer) && intro_observer_client.ckey == intro_observer_ckey, "same admitted observer")
	var/filename = "intro-cadence-[phase].json"
	intro_check(!fexists(filename), "fresh cadence evidence")
	text2file(json_encode(list("phase" = phase, "world_time_ds" = world.time, "world_fps" = world.fps, "world_tick_lag" = world.tick_lag, "client_fps" = intro_observer_client.fps, "client_tick_lag" = intro_observer_client.tick_lag, "same_admitted_client" = TRUE)), filename)

/proc/intro_capture_requests()
	if (fexists("intro-abort.txt"))
		intro_stop("owned controller abort")
		return
	if (fexists("intro-end-request.txt") && !fexists("intro-cadence-end.json"))
		intro_check(file2text("intro-end-request.txt") == "end\n", "fixed end request")
		intro_cadence_write("end")

