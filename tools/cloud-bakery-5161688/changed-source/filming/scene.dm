// Derived cloud fixture, source review required before execution.
// Genuine engine guest camera; not a user account or ordinary-player acceptance.
#define FILMING_NATIVE_RELEASED TRUE

var/filming_ready = FALSE
var/filming_started = FALSE
var/filming_stopping = FALSE
var/client/filming_observer_client
var/mob/living/human/filming_baker
var/mob/living/human/filming_customer
var/obj/structure/oven/filming_oven
var/obj/structure/table/filming_counter
var/obj/item/weapon/reagent_containers/food/snacks/dough/filming_dough
var/filming_expected_observer
var/filming_allowed_port
var/filming_startup_phase = "pre-world initialization"

/world
	name = "Civ13 native bakery cloud"
	hub = ""
	hub_password = ""
	visibility = 0
	mob = /mob/filming_observer
	maxx = 15
	maxy = 13
	maxz = 1
	view = 7
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

/client/New()
	if (!FILMING_NATIVE_RELEASED || !filming_ready || filming_observer_client || copytext(key, 1, 7) != "Guest-" || byond_version != 516 || byond_build != 1688 || address != "127.0.0.1")
		del(src)
		return
	filming_observer_client = src
	verbs.Cut()
	..()
	// No preferences, admin holder, production host file, login webhook or bridge.
	eye = locate(7, 7, 1)
	perspective = EYE_PERSPECTIVE
	view = 7
	var/is_guest = (copytext(key, 1, 7) == "Guest-")
	text2file("guest=[is_guest];version=[byond_version];build=[byond_build]", "cloud-client.txt")
	spawn(20)
		try
			while (!fexists("cloud-stage-captured.txt"))
				sleep(1)
			filming_prepare_scene()
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
	verbs = list() // Fixed cloud sequence only; no external command/verb dispatcher.

/mob/filming_observer/Move()
	return FALSE

/mob/filming_observer/Logout()
	return

/mob/filming_observer/ClickOn()
	return

/mob/filming_observer/verb/Abort_scene()
	set category = "Filming"
	filming_stop("observer abort")

/mob/filming_observer/verb/Prepare_scene()
	set category = "Filming"
	if (client != filming_observer_client || filming_baker)
		return
	try
		filming_prepare_scene()
	catch (var/exception/E)
		filming_stop("prepare failed: [E.name]")

/mob/filming_observer/verb/Run_take()
	set category = "Filming"
	if (client != filming_observer_client || !filming_dough || filming_started)
		return
	filming_started = TRUE
	try
		filming_take()
	catch (var/exception/E)
		filming_stop("take failed: [E.name]")

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

/proc/filming_prepare_scene()
	// Only pre-roll provisioning. No new ingredients, fuel, dough or bread in take.
	filming_baker = filming_actor(7, 8, "Baker", /obj/item/clothing/under/civ4)
	filming_customer = filming_actor(7, 6, "Customer", /obj/item/clothing/under/civ1)
	filming_baker.dir = SOUTH
	filming_customer.dir = NORTH
	filming_oven = locate(/obj/structure/oven) in locate(6, 8, 1)
	filming_counter = locate(/obj/structure/table) in locate(7, 7, 1)
	filming_check(filming_oven && filming_counter && !filming_oven.on, "authored oven and counter found")
	var/obj/item/stack/material/wood/W = new(filming_baker.loc)
	W.amount = 1
	filming_pickup(filming_baker, W)
	var/old_fuel = filming_oven.fuel
	filming_check(filming_oven.Adjacent(filming_baker), "fuel within reach")
	filming_oven.attackby(W, filming_baker)
	filming_check(filming_oven.fuel == old_fuel + 1, "wood consumed through normal oven handler")
	// qdel may retain a reference until collection; normal removal clears hands.
	filming_baker.drop_item()
	var/obj/item/weapon/reagent_containers/glass/bucket/B = new(filming_baker.loc)
	B.reagents.add_reagent("water", 5)
	var/obj/item/weapon/reagent_containers/food/condiment/flour/F = new(filming_baker.loc)
	filming_pickup(filming_baker, B)
	filming_baker.swap_hand()
	filming_pickup(filming_baker, F)
	var/water_before = B.reagents.get_reagent_amount("water")
	var/flour_before = F.reagents.get_reagent_amount("flour")
	F.attack_self(filming_baker)
	filming_check(B.reagents.get_reagent_amount("water") == water_before - 5 && F.reagents.get_reagent_amount("flour") == flour_before - 5, "normal dough recipe paid five water and five flour")
	filming_dough = locate(/obj/item/weapon/reagent_containers/food/snacks/dough) in filming_baker.loc
	filming_check(filming_dough, "recipe created dough")
	filming_baker.drop_item()
	filming_baker.swap_hand()
	filming_baker.drop_item()
	filming_pickup(filming_baker, filming_dough)
	text2file("ready; paid dough in baker hand; staged native mechanics", "filming-ready.txt")

/proc/filming_take()
	var/take_start = world.time
	var/list/old_bread = list()
	for (var/obj/item/weapon/reagent_containers/food/snacks/flatbread/B in world)
		old_bread += B
	filming_check(filming_oven.Adjacent(filming_baker) && filming_baker.get_active_hand() == filming_dough, "oven loading reach and held dough")
	filming_oven.attackby(filming_dough, filming_baker)
	filming_check(filming_dough.loc == filming_oven, "normal oven loading")
	var/fuel_before = filming_oven.fuel
	var/cook_started = world.time
	filming_oven.attack_hand(filming_baker)
	filming_check(filming_oven.on && filming_oven.fuel == fuel_before - 1, "normal ignition consumed fuel")
	var/obj/item/weapon/reagent_containers/food/snacks/flatbread/bread
	while (!bread && world.time - cook_started < 150)
		for (var/obj/item/weapon/reagent_containers/food/snacks/flatbread/B in filming_oven.loc)
			if (!(B in old_bread))
				bread = B
		if (!bread)
			sleep(1)
	filming_check(bread && world.time - cook_started >= filming_oven.cooking_time, "fresh flatbread after real cooking timer")
	filming_pickup(filming_baker, bread)
	filming_check(filming_counter.Adjacent(filming_baker), "counter reach")
	filming_counter.attackby(bread, filming_baker, "icon-x=16;icon-y=16")
	filming_check(bread.loc == filming_counter.loc && !filming_baker.get_active_hand(), "normal table placement")
	sleep(10)
	filming_pickup(filming_customer, bread)
	filming_check(bread.loc == filming_customer && !filming_baker.client && !filming_customer.client, "customer received the same newly cooked bread")
	sleep(20)
	text2file(json_encode(list("elapsed_deciseconds" = world.time - take_start, "engine" = "516.1688", "source" = "58404f5bd16e3fed80f1d9844c5db3edd144942c", "scope" = "scripted native actors; no ordinary client acceptance")), "filming-take.json")
	// Leave a short inspection window; supervisor remains the hard kill boundary.
	spawn(300)
		filming_stop("take complete")

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
