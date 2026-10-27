// Proposed recording fixture; requires a NEW build and runtime admission.
// Crop translation: original (x,y,z=2) -> (x-48,y-138,z=1).
var/intro_ready = FALSE
var/intro_prepared = FALSE
var/intro_started = FALSE
var/intro_stopping = FALSE
var/client/intro_observer_client
var/intro_observer_ckey
var/intro_port
var/mob/living/human/intro_driver
var/mob/living/simple_animal/horse/intro_horse
var/obj/structure/vehicle/carriage/intro_carriage
var/obj/structure/closet/crate/wood/intro_crate
var/list/intro_crate_contents

/world
	name = "Civ13 carriage take"
	hub = ""
	hub_password = ""
	visibility = FALSE
	mob = /mob/intro_observer
	maxx = 15
	maxy = 15
	maxz = 1
	view = 7
	fps = 20

/world/OpenPort(requested)
	if (requested == "none")
		return ..("none")
	if (INTRO_TRANSPORT_RELEASED && intro_ready && intro_port && requested == intro_port)
		return ..(requested)
	return FALSE

/world/Topic()
	return null

/world/Reboot()
	intro_stop("reboot prohibited")

/world/Error(exception/E)
	intro_stop("native error: [E.name]")

/proc/intro_denied_shell()
	throw EXCEPTION("Carriage fixture: OS shell disabled")

/proc/intro_denied_export()
	throw EXCEPTION("Carriage fixture: outbound network disabled")

/proc/intro_check(ok, label)
	if (!ok)
		throw EXCEPTION("Carriage fixture: [label]")
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
	if (!INTRO_TRANSPORT_RELEASED)
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
	if (!INTRO_TRANSPORT_RELEASED || !intro_ready || intro_observer_client || copytext(key, 1, 7) != "Guest-" || address != "127.0.0.1" || byond_version != 516 || byond_build != 1688)
		del(src)
		return
	intro_observer_client = src
	intro_observer_ckey = ckey
	for (var/fixture_verb in verbs.Copy())
		verbs -= fixture_verb
	..()
	eye = locate(8, 8, 1)
	perspective = EYE_PERSPECTIVE
	view = 7
	intro_check(byond_version == 516 && byond_build == 1688, "existing client engine 516.1688")
	fps = 20
	intro_cadence_write("admission")
	text2file("guest=1;version=516;build=1688", "cloud-client.txt")
	spawn(20)
		var/mob/intro_observer/O = mob
		O.Prepare_carriage()
		O.Run_carriage()

/client/Del()
	if (src == intro_observer_client)
		intro_stop("observer disconnected")
	return ..()

/client/Topic()
	return null

/client/Move()
	return FALSE

/mob/intro_observer
	name = "Transport observer"
	density = FALSE
	invisibility = 101

/mob/intro_observer/Login()
	loc = locate(8, 8, 1)
	verbs = list()

/mob/intro_observer/Move()
	return FALSE

/mob/intro_observer/Logout()
	return

/mob/intro_observer/ClickOn()
	return

/mob/intro_observer/proc/Abort_carriage()
	if (client == intro_observer_client)
		intro_stop("observer abort")

/mob/intro_observer/proc/Prepare_carriage()
	if (!INTRO_TRANSPORT_RELEASED || client != intro_observer_client || intro_driver || intro_stopping)
		return
	try
		intro_prepare()
	catch (var/exception/prepare_error)
		intro_stop("preparation failed: [prepare_error.name]")

/mob/intro_observer/proc/Run_carriage()
	if (!INTRO_TRANSPORT_RELEASED || client != intro_observer_client || !intro_prepared || intro_started || intro_stopping)
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
		intro_state("before")
		var/driver_health = intro_driver.health
		var/horse_health = intro_horse.health
		var/carriage_health = intro_carriage.health
		sleep(20)
		var/datum/intro_transport_take/action = new
		action.carriage_straight(intro_carriage, intro_driver, intro_crate)
		intro_check(intro_driver.health == driver_health && intro_horse.health == horse_health && intro_carriage.health == carriage_health, "no collision injury during short drive")
		intro_check(intro_crate.contents.len == intro_crate_contents.len, "cargo count retained")
		for (var/atom/A in intro_crate_contents)
			intro_check(A.loc == intro_crate, "same original crate content retained")
		intro_state("after")
		text2file(json_encode(list("source" = "58404f5bd16e3fed80f1d9844c5db3edd144942c", "engine" = "516.1688", "world_fps" = world.fps, "elapsed_deciseconds" = world.time - start_time, "scope" = "scripted native carriage; no ordinary-client acceptance")), "intro-take.json")
	catch (var/exception/take_error)
		intro_stop("take failed: [take_error.name]")

/proc/intro_prepare()
	intro_carriage = locate(/obj/structure/vehicle/carriage) in locate(8,9,1)
	intro_crate = locate(/obj/structure/closet/crate/wood) in locate(11,14,1)
	intro_check(intro_carriage && intro_crate && intro_carriage.dir == SOUTH, "original authored carriage and crate")
	// Explicit pre-roll staging only. Horse type matches authored Stables horse
	// at (107,145,2); it is provisioned here, not claimed to have walked here.
	intro_driver = new(locate(7,9,1))
	intro_driver.real_name = "Driver"
	intro_driver.name = "Driver"
	intro_driver.lastarea = get_area(intro_driver)
	intro_driver.m_intent = "walk"
	intro_driver.equip_to_slot(new /obj/item/clothing/under/civ1(intro_driver), slot_w_uniform)
	intro_driver.equip_to_slot(new /obj/item/clothing/shoes/leatherboots(intro_driver), slot_shoes)
	intro_horse = new(locate(7,10,1))
	intro_crate.forceMove(locate(7,8,1))
	intro_crate_contents = intro_crate.contents.Copy()
	intro_check(!intro_driver.client && !intro_driver.ckey && !intro_driver.incapacitated(), "fixture-owned capable human")
	var/datum/intro_transport_take/hitch_action = new
	hitch_action.carriage_hitch(intro_carriage, intro_driver, intro_horse)
	var/datum/intro_transport_take/load_action = new
	load_action.carriage_load(intro_carriage, intro_driver, intro_crate)
	var/datum/intro_transport_take/board_action = new
	board_action.carriage_board(intro_carriage, intro_driver)
	intro_check(!intro_driver.incapacitated() && intro_driver.get_active_hand() == intro_carriage.dwheel, "normal driver and reins ready")
	intro_prepared = TRUE
	text2file("ready; native paid waits completed; staged horse and authored crate", "intro-ready.txt")
	spawn(0)
		intro_life_loop()

/proc/intro_life_loop()
	// Preserve normal actor Life handlers at the mob process's one-second cadence.
	// This is an isolated two-actor scene, not full-round scheduler acceptance.
	while (!intro_stopping)
		try
			intro_driver.Life()
			intro_horse.Life()
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
	if (!INTRO_TRANSPORT_RELEASED)
		intro_stop("NATIVE HOLD: compile-review only")
		return
	try
		intro_check(!port && byond_version == 516 && byond_build == 1688, "engine and closed port")
		intro_check(maxx == 15 && maxy == 15 && maxz == 1, "exact 225-cell crop")
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
		var/turf/driver_turf = locate(7,9,1)
		intro_check(driver_turf.lighting_overlay && !driver_turf.lighting_overlay.invisibility, "driver tile has visible native lighting overlay")
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

/proc/intro_state(phase)
	intro_check(phase in list("before", "after"), "bounded state phase")
	var/list/items = list()
	for (var/atom/A in intro_crate_contents)
		items += list(list("ref" = "\ref[A]", "type" = "[A.type]", "in_original_crate" = A.loc == intro_crate))
	intro_check(items.len <= 16, "bounded authored cargo witness")
	text2file(json_encode(list("phase" = phase, "time" = world.time, "carriage" = "\ref[intro_carriage]", "driver" = "\ref[intro_driver]", "horse" = "\ref[intro_horse]", "crate" = "\ref[intro_crate]", "x" = intro_carriage.x, "y" = intro_carriage.y, "z" = intro_carriage.z, "moving" = intro_carriage.moving, "speed" = intro_carriage.axis.currentspeed, "driver_bound" = intro_carriage.driver == intro_driver, "cargo_bound" = intro_crate in intro_carriage.ontop_o, "items" = items)), "intro-state-[phase].json")
