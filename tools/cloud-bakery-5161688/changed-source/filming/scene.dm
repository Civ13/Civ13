// Derived cloud fixture, source review required before execution.
// Genuine engine guest camera; not a user account or ordinary-player acceptance.
#define FILMING_NATIVE_RELEASED TRUE

var/filming_ready = FALSE
var/filming_started = FALSE
var/filming_stopping = FALSE
var/client/filming_observer_client
var/filming_expected_observer
var/filming_allowed_port
var/filming_startup_phase = "pre-world initialization"

/world
	name = "Civ13 tree process showcase"
	hub = ""
	hub_password = ""
	visibility = 0
	mob = /mob/filming_observer
	// The authored DMM supplies dimensions; exact runtime size is asserted below.
	view = 3
	fps = 20

/world/OpenPort(requested)
	if (requested == "none")
		return ..("none")
	if (FILMING_NATIVE_RELEASED && filming_ready && filming_allowed_port && requested == filming_allowed_port)
		return ..(requested)
	return FALSE

/world/Topic()
	return null

/world/Reboot()
	filming_stop("reboot requested: fixture stops instead")

/world/Error(exception/E)
	filming_stop("native runtime error: [filming_exception_detail(E)]")

/proc/filming_exception_detail(exception/E)
	// Bound each original field; the existing stop receipt has a 64 KiB cap.
	if (!istype(E))
		return json_encode(list("phase" = copytext(filming_startup_phase, 1, 257), "exception_available" = FALSE))
	var/name_text = "[E.name]"
	var/file_text = "[E.file]"
	var/desc_text = "[E.desc]"
	return json_encode(list("phase" = copytext(filming_startup_phase, 1, 257), "exception_name" = copytext(name_text, 1, 257), "exception_file" = copytext(file_text, 1, 257), "exception_line" = E.line, "exception_desc" = copytext(desc_text, 1, 2049), "phase_truncated" = length(filming_startup_phase) > 256, "name_truncated" = length(name_text) > 256, "file_truncated" = length(file_text) > 256, "desc_available" = !!length(desc_text), "desc_truncated" = length(desc_text) > 2048))

/proc/filming_denied_shell()
	throw EXCEPTION("Filming profile: OS shell disabled")

/proc/filming_denied_export()
	throw EXCEPTION("Filming profile: production outbound export disabled")

/proc/filming_check(ok, label)
	if (!ok)
		throw EXCEPTION("Filming check failed: [label]")
	text2file("[world.time] [label]", "filming-checks.txt")

/proc/filming_stop(reason)
	if (filming_stopping)
		return
	filming_stopping = TRUE
	world.OpenPort("none")
	text2file(reason, "filming-stop.txt")
	del(world)

// Keep the Little Creek era/rules, omit scenario timers, jobs and round logic.
/obj/map_metadata/little_creek/filming/New()
	map = src

/proc/filming_initialize()
	if (!FILMING_NATIVE_RELEASED)
		return
	config = new
	config.webhook_can_fire = FALSE
	config.ToRban = FALSE
	map = new /obj/map_metadata/little_creek/filming
	makeDatumRefLists()
	initialize_chemical_reagents()
	initialize_chemical_reactions()
	populate_material_list()

// Fixed authored DMM witnesses only; never reconstruct or paint over a missing map.
/proc/filming_assert_authored_map(phase)
	var/list/witnesses = list(
		list(7, 7, /turf/floor/dirt/ploughed/fertile, null),
		list(6, 7, /turf/floor/dirt, null),
		list(6, 8, /turf/floor/dirt, null),
		list(5, 7, /turf/floor/dirt, null),
		list(6, 6, /turf/floor/dirt, null),
		list(9, 5, /turf/floor/grass, /obj/structure/table/wood))
	var/list/observed = list()
	var/ok = (world.maxx == 15 && world.maxy == 13 && world.maxz == 1)
	for (var/list/row in witnesses)
		var/turf/T = locate(row[1], row[2], 1)
		var/area/A = T ? get_area(T) : null
		var/expected_turf = row[3]
		var/expected_object = row[4]
		var/obj/O = expected_object && T ? (locate(expected_object) in T) : null
		var/turf_ok = T && T.type == expected_turf
		var/area_ok = A && A.type == /area/caribbean/forest
		var/object_ok = !expected_object || (O && O.loc == T)
		var/actual_turf = T ? "[T.type]" : "missing"
		var/actual_area = A ? "[A.type]" : "missing"
		observed += list(list("x" = row[1], "y" = row[2], "z" = 1, "turf" = copytext(actual_turf, 1, 129), "area" = copytext(actual_area, 1, 129), "turf_ok" = !!turf_ok, "area_ok" = !!area_ok, "object_ok" = !!object_ok))
		if (!turf_ok || !area_ok || !object_ok)
			ok = FALSE
	// Observe only the same six coordinates on z2; never use them for admission.
	var/list/z2_observed = list()
	if (phase == "world New before fixture initialization")
		for (var/list/row in witnesses)
			var/turf/T = locate(row[1], row[2], 2)
			var/area/A = T ? get_area(T) : null
			var/expected_turf = row[3]
			var/expected_object = row[4]
			var/obj/O = expected_object && T ? (locate(expected_object) in T) : null
			var/actual_turf = T ? "[T.type]" : "missing"
			var/actual_area = A ? "[A.type]" : "missing"
			z2_observed += list(list("x" = row[1], "y" = row[2], "z" = 2, "turf" = copytext(actual_turf, 1, 129), "area" = copytext(actual_area, 1, 129), "turf_ok" = !!(T && T.type == expected_turf), "area_ok" = !!(A && A.type == /area/caribbean/forest), "object_ok" = !!(!expected_object || (O && O.loc == T))))
	var/evidence = json_encode(list("phase" = copytext(phase, 1, 65), "dimensions" = list(world.maxx, world.maxy, world.maxz), "witnesses" = observed, "z2_diagnostic" = z2_observed))
	text2file("authored-map [evidence]", "filming-checks.txt")
	filming_check(ok, "authored map witnesses [phase]")

/client/New()
	if (!FILMING_NATIVE_RELEASED || !filming_ready || filming_observer_client || copytext(key, 1, 7) != "Guest-" || byond_version != 516 || byond_build != 1688 || address != "127.0.0.1")
		del(src)
		return
	filming_assert_authored_map("client admission")
	filming_assert_tree_initial()
	filming_observer_client = src
	// Special verb lists support subtraction, not Cut; iterate a stable copy.
	for (var/fixture_verb in verbs.Copy())
		verbs -= fixture_verb
	filming_check(!verbs.len, "client verbs empty before native New")
	..()
	filming_check(!verbs.len, "client verbs empty after native New")
	filming_check(istype(mob, /mob/filming_observer) && !mob.verbs.len, "observer verbs empty before capture")
	// No preferences, admin holder, production host file, login webhook or bridge.
	eye = locate(7, 7, 1)
	perspective = EYE_PERSPECTIVE
	view = 3
	var/is_guest = (copytext(key, 1, 7) == "Guest-")
	text2file("guest=[is_guest];version=[byond_version];build=[byond_build]", "cloud-client.txt")
	spawn(20)
		try
			while (!fexists("cloud-stage-captured.txt"))
				sleep(1)
			filming_started = TRUE
			filming_take()
		catch (var/exception/E)
			filming_stop("cloud sequence failed: [E.name]")

/client/Del()
	if (src == filming_observer_client)
		filming_stop("observer disconnected")
	return ..()

/client/Topic()
	return null

/client/Move()
	return FALSE

/mob/filming_observer
	name = "Filming observer"
	density = FALSE
	invisibility = 101

/mob/filming_observer/Login()
	loc = locate(7, 7, 1)
	// Fixed cloud sequence only; mutate the special list, never assign it.
	for (var/fixture_verb in verbs.Copy())
		verbs -= fixture_verb
	filming_check(!verbs.len, "observer verbs empty after Login")

/mob/filming_observer/Move()
	return FALSE

/mob/filming_observer/Logout()
	return

/mob/filming_observer/ClickOn()
	return

/mob/filming_observer/verb/Abort_scene()
	set category = "Filming"
	filming_stop("observer abort")

/proc/filming_actor(tx, ty, actor_name, uniform_type)
	var/mob/living/human/H = new(locate(tx, ty, 1))
	H.real_name = actor_name
	H.name = actor_name
	H.lastarea = get_area(H)
	H.m_intent = "walk"
	H.equip_to_slot(new uniform_type(H), slot_w_uniform)
	H.equip_to_slot(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
	filming_check(!H.client && !H.ckey && H.stat == CONSCIOUS, "fixture-owned human, no client impersonation")
	return H

/proc/filming_pickup(mob/living/human/H, obj/item/I)
	filming_check(I && I.Adjacent(H) && !H.get_active_hand(), "pickup reach and free hand")
	I.attack_hand(H)
	filming_check(H.get_active_hand() == I, "normal pickup completed")

var/mob/living/human/tree_grower
var/mob/living/human/tree_receiver
var/obj/item/stack/farming/seeds/tree/tree_seeds
var/obj/item/weapon/reagent_containers/glass/bucket/tree_bucket
var/obj/item/weapon/material/hatchet/steel/tree_hatchet
var/turf/floor/dirt/ploughed/fertile/tree_plot

/proc/filming_assert_tree_initial()
	filming_check(tree_plot && !(locate(/obj/structure/farming/plant) in tree_plot) && !(locate(/obj/structure/wild/tree/live_tree) in tree_plot), "initial plot has no fabricated plant or tree")
	filming_check(!(locate(/obj/item/stack/material/wood) in tree_plot), "initial plot has no finished timber")
	filming_check(tree_seeds.amount == 2 && tree_bucket.reagents.total_volume == 15, "initial resources unchanged")
	filming_check(!tree_grower.client && !tree_receiver.client, "only fixture owned actors")

/proc/tree_beat(label, take_start)
	text2file(json_encode(list("beat" = label, "elapsed_ds" = world.time - take_start)), "filming-checks.txt")

/proc/filming_prepare_scene()
	// PRE-ROLL ONLY: prepared soil and supplied starting resources, not claimed crafted/foraged.
	// Integrator must call before listener/client admission, not after first captured frame.
	tree_plot = locate(7, 7, 1)
	filming_check(tree_plot && tree_plot.type == /turf/floor/dirt/ploughed/fertile && tree_plot.soil_nutrition == 150, "authored fertile plot")
	season = "SUMMER" // isolated scene setting; production seasonal rendering remains intact
	map.heat_wave = FALSE
	tree_grower = filming_actor(6, 7, "Grower", /obj/item/clothing/under/civ4)
	tree_receiver = filming_actor(7, 5, "Woodworker", /obj/item/clothing/under/civ1)
	tree_grower.dir = EAST
	tree_receiver.dir = NORTH
	tree_seeds = new(locate(6, 7, 1), 2)
	tree_bucket = new(locate(6, 8, 1))
	tree_bucket.reagents.add_reagent("water", 15)
	tree_hatchet = new(locate(5, 7, 1))
	filming_check(tree_bucket.is_open_container() && tree_bucket.reagents.total_volume == 15, "visible supplied bucket contains fifteen water")
	filming_check(tree_hatchet.chopping_speed == 1.55 && tree_hatchet.health > 0.25, "unaltered stock steel hatchet")
	var/area/plot_area = get_area(tree_plot)
	filming_check(!tree_planting_error(tree_plot) && plot_area.climate == "temperate", "clear outdoor temperate plot")
	text2file("ready; supplied seeds water tool and prepared soil; accelerated growth only", "filming-ready.txt")

/proc/filming_take()
	var/take_start = world.time
	tree_beat("materials and prepared plot", take_start)
	sleep(15)
	filming_pickup(tree_grower, tree_seeds)
	tree_plot.attackby(tree_seeds, tree_grower)
	var/obj/structure/farming/plant/tree/P = locate() in tree_plot
	filming_check(P && P.stage == 1 && P.water == 80 && tree_seeds.amount == 1, "real planting paid exactly one seed")
	filming_check(P in processing_objects, "production seedling registered")
	tree_grower.drop_item() // remaining seed packet stays visibly beside grower
	tree_beat("planted seedling", take_start)
	sleep(15)
	// Explicit DEMONSTRATION-ONLY time compression: six 60-second stages shortened
	// to one second each on this one fixture-owned seedling. No fake clock credit,
	// stage assignment, direct stageGrowth call, mature-tree spawn, or scheduler loop.
	for (var/pulse = 1, pulse <= 6, pulse++)
		filming_check(P && !P.gc_destroyed && P.stage == pulse && P.growth_time_left == 600, "expected live growth stage before compression")
		P.growth_time_left = 10
		sleep(10)
		var/soil_before = tree_plot.soil_nutrition
		var/water_before = P.water
		P.process_interval(1) // actual elapsed tick cap; unchanged production handler
		filming_check(tree_plot.soil_nutrition == soil_before - 3, "production growth paid soil")
		if (pulse < 6)
			filming_check(P.water == water_before - 15, "production growth consumed water")
			filming_check(P && P.stage == pulse + 1 && P.icon_state == "tree-grow[pulse + 1]", "next original growth sprite")
			tree_beat("growth stage [pulse + 1]", take_start)
		if (pulse == 1)
			filming_check(P.water == 65, "first growth consumed fifteen water")
			filming_pickup(tree_grower, tree_bucket)
			tree_grower.a_intent = I_HARM
			tree_grower.dir = EAST
			tree_bucket.secondary_attack_self(tree_grower)
			filming_check(tree_bucket.reagents.total_volume == 0 && P.water == 80, "real pour debited fifteen water and restored crop")
			tree_grower.a_intent = I_HELP
			tree_grower.drop_item()
			tree_beat("care through real water pour", take_start)
			sleep(10)
	var/obj/structure/wild/tree/live_tree/mature = locate() in tree_plot
	filming_check(mature && mature.loc == tree_plot && !(P in processing_objects) && tree_plot.soil_nutrition == 132, "production-created mature tree after six paid stages")
	tree_beat("mature leafy tree", take_start)
	sleep(20)
	filming_pickup(tree_grower, tree_hatchet)
	var/tool_health = tree_hatchet.health
	var/chop_start = world.time
	tree_beat("timed chopping begins", take_start)
	mature.attackby(tree_hatchet, tree_grower)
	var/obj/item/stack/material/wood/logs = locate() in tree_plot
	filming_check(world.time - chop_start >= 46.5 && logs && logs.amount == 7 && tree_hatchet.health == tool_health - 0.25, "normal timed chop creates seven logs and pays tool wear")
	filming_check(!(locate(/obj/structure/wild/tree/live_tree) in tree_plot), "mature tree removed by production chop")
	tree_grower.drop_item()
	tree_beat("finished timber on ground", take_start)
	sleep(10)
	filming_pickup(tree_grower, logs)
	// Production Move wrappers may discard their parent's return; actual state is authoritative.
	var/mob/living/human/grower_identity = tree_grower
	var/obj/item/stack/material/wood/grower_timber = logs
	filming_check(grower_identity && grower_identity.loc == locate(6, 7, 1) && !grower_identity.step_x && !grower_identity.step_y && logs.loc == grower_identity && logs.amount == 7, "grower handoff movement starts at exact tile with same seven logs")
	var/list/grower_start = list(grower_identity.x, grower_identity.y, grower_identity.z, grower_identity.step_x, grower_identity.step_y)
	var/grower_step_return = step(tree_grower, SOUTH)
	text2file(json_encode(list("movement" = "grower", "start" = grower_start, "step_return_numeric" = isnum(grower_step_return) ? grower_step_return : null, "step_return_null" = isnull(grower_step_return), "x" = grower_identity.x, "y" = grower_identity.y, "z" = grower_identity.z, "step_x" = grower_identity.step_x, "step_y" = grower_identity.step_y, "actor_same" = tree_grower == grower_identity, "timber_same" = logs == grower_timber, "carried" = logs.loc == grower_identity, "amount" = logs.amount)), "filming-checks.txt")
	filming_check(tree_grower == grower_identity && logs == grower_timber && grower_identity.loc == locate(6, 6, 1) && !grower_identity.step_x && !grower_identity.step_y && logs.loc == grower_identity && logs.amount == 7, "grower moves actual timber to handoff")
	tree_grower.drop_item()
	filming_check(logs.loc == locate(6, 6, 1), "same seven logs visibly placed for next process")
	sleep(5)
	filming_pickup(tree_receiver, logs)
	// Production Move wrappers may discard their parent's return; actual state is authoritative.
	var/mob/living/human/receiver_identity = tree_receiver
	var/obj/item/stack/material/wood/receiver_timber = logs
	filming_check(receiver_identity && receiver_identity.loc == locate(7, 5, 1) && !receiver_identity.step_x && !receiver_identity.step_y && logs.loc == receiver_identity && logs.amount == 7, "receiver handoff movement starts at exact tile with same seven logs")
	var/list/receiver_start = list(receiver_identity.x, receiver_identity.y, receiver_identity.z, receiver_identity.step_x, receiver_identity.step_y)
	var/receiver_step_return = step(tree_receiver, EAST)
	text2file(json_encode(list("movement" = "receiver", "start" = receiver_start, "step_return_numeric" = isnum(receiver_step_return) ? receiver_step_return : null, "step_return_null" = isnull(receiver_step_return), "x" = receiver_identity.x, "y" = receiver_identity.y, "z" = receiver_identity.z, "step_x" = receiver_identity.step_x, "step_y" = receiver_identity.step_y, "actor_same" = tree_receiver == receiver_identity, "timber_same" = logs == receiver_timber, "carried" = logs.loc == receiver_identity, "amount" = logs.amount)), "filming-checks.txt")
	filming_check(tree_receiver == receiver_identity && logs == receiver_timber && receiver_identity.loc == locate(8, 5, 1) && !receiver_identity.step_x && !receiver_identity.step_y && logs.loc == receiver_identity && logs.amount == 7, "receiver carries actual timber toward work area")
	filming_check(logs.loc == tree_receiver && logs.amount == 7, "same production timber received for next process")
	tree_beat("timber handed to woodworker", take_start)
	sleep(5)
	filming_check(world.time - take_start <= 195, "sequence completed inside unchanged recording interval")
	text2file(json_encode(list("elapsed_deciseconds" = world.time - take_start, "engine" = "516.1688", "source" = "9683866a89d2bdc12f8dc7d25444e350583c5483", "scope" = "scripted native actors; six fixture growth durations compressed from sixty seconds to one second; real planting care chopping and timber handoff")), "filming-take.json")

/proc/filming_lighting_loop()
	// Only these two native visual processes; no general production scheduler.
	var/process/lighting_sources/S = new
	var/process/lighting_overlays/O = new
	S.setup()
	O.setup()
	while (!filming_stopping)
		S.run_time_tick_usage = world.tick_usage
		S.run_time_tick_usage_allowance = 5
		S.fire()
		O.run_time_tick_usage = world.tick_usage
		O.run_time_tick_usage_allowance = 5
		O.fire()
		sleep(2)

/world/New()
	filming_startup_phase = "close initial port"
	OpenPort("none")
	if (!FILMING_NATIVE_RELEASED)
		filming_stop("NATIVE HOLD: review only")
		return
	try
		filming_startup_phase = "validate engine and parameters"
		filming_check(!port && byond_version == 516 && byond_build == 1688, "closed port and accepted engine")
		filming_allowed_port = text2num(params["filming_port"])
		filming_check(params["observer_mode"] == "engine_guest_camera" && filming_allowed_port >= 1024 && filming_allowed_port <= 65535, "explicit guest camera and isolated port")
		filming_assert_authored_map("world New before fixture initialization")
		filming_startup_phase = "movementMachine.New"
		movementMachine = new
		filming_startup_phase = "init_sticker_registry"
		filming_check(!!GLOB, "global controller published")
		filming_check(islist(GLOB.sticker_registry), "sticker registry is a list")
		filming_check(!length(GLOB.sticker_registry), "sticker registry initially empty")
		init_sticker_registry()
		filming_startup_phase = "movable initialization loop"
		for (var/atom/movable/A in world)
			if (!A.gcDestroyed)
				filming_startup_phase = "movable.initialize [A.type] ([A.x],[A.y],[A.z])"
				A.initialize()
		filming_startup_phase = "area initialization loop"
		for (var/area/A in area_list)
			filming_startup_phase = "area.initialize [A.type]"
			A.initialize()
		filming_startup_phase = "time_of_day_change.New"
		var/process/time_of_day_change/T = new
		filming_startup_phase = "time_of_day_change.setup"
		T.setup()
		filming_startup_phase = "create_lighting Midday"
		create_lighting("Midday")
		filming_startup_phase = "apply_restored_lighting"
		filming_check(apply_restored_lighting(), "native daylight initialized")
		spawn(0)
			filming_lighting_loop()
		filming_assert_authored_map("after fixture initialization before listener")
		filming_startup_phase = "prepare visible starting materials"
		filming_prepare_scene()
		filming_assert_tree_initial()
		filming_startup_phase = "open isolated listener"
		filming_ready = TRUE
		OpenPort(filming_allowed_port)
		filming_check(port == filming_allowed_port, "isolated observer listener")
		text2file("port=[port];version=[byond_version];build=[byond_build]", "cloud-listening.txt")
		filming_startup_phase = "startup complete"
		spawn(1800)
			filming_stop("three minute world timeout")
	catch (var/exception/E)
		filming_stop("startup failed: [filming_exception_detail(E)]")
