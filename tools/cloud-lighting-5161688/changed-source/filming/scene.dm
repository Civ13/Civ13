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
	name = "Civ13 lighting V2 pair"
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
	rand_seed(3225)
	weather = WEATHER_NONE
	config = new
	config.webhook_can_fire = FALSE
	config.ToRban = FALSE
	map = new /obj/map_metadata/little_creek/filming
	makeDatumRefLists()
	initialize_chemical_reagents()
	initialize_chemical_reactions()
	populate_material_list()

var/mob/living/human/filming_worker/light_viewer
var/lighting_clear = FALSE

/proc/filming_assert_authored_map(phase)
	filming_check(world.maxx == 15 && world.maxy == 13 && world.maxz == 1, "15x13 single-level scene")
	for(var/turf/T in world)
		var/area/A = get_area(T)
		filming_check(T.type == /turf/floor/grass && A && A.type == /area/caribbean/forest, "fixture turf and dynamic area unchanged")
	var/obj/structure/wild/tree/live_tree/pine/lighting_capture/P = locate() in locate(8,6,1)
	filming_check(P && P.icon_state == "new_pine_1" && P.pixel_x == -16 && P.pixel_y == 0 && P.opacity == !lighting_clear, "fixed original pine art and root state")
	filming_check(!!(locate(/obj/effect/lighting_capture_marker) in locate(8,7,1)) && !!(locate(/obj/effect/lighting_capture_marker) in locate(7,5,1)), "source-authored marker coordinates")
	text2file("map phase [phase]", "filming-checks.txt")

/client/New()
	if(!FILMING_NATIVE_RELEASED || !filming_ready || filming_observer_client || copytext(key,1,7) != "Guest-" || byond_version != 516 || byond_build != 1688 || address != "127.0.0.1")
		del(src)
		return
	filming_observer_client = src
	for(var/fixture_verb in verbs.Copy())
		verbs -= fixture_verb
	filming_check(!verbs.len, "client verbs empty before native New")
	..()
	filming_check(!verbs.len && istype(mob,/mob/filming_observer) && !mob.verbs.len, "guest lobby has no arbitrary input")
	filming_check(light_viewer && !light_viewer.client && !light_viewer.ckey && light_viewer.loc == locate(8,5,1), "fixture human before guest binding")
	mob = light_viewer
	filming_check(mob == light_viewer && light_viewer.client == src && light_viewer.key == key && !mob.verbs.len && !verbs.len, "genuine guest bound to exact human")
	eye = light_viewer
	perspective = EYE_PERSPECTIVE
	view = 3
	lighting_capture_attach_hud(light_viewer)
	spawn(20)
		try
			filming_save_snapshot("opaque", FALSE)
			text2file("guest=1;version=[byond_version];build=[byond_build]", "cloud-client.txt")
			while(!fexists("cloud-stage-captured.txt"))
				sleep(1)
			lighting_capture_witness(light_viewer, FALSE)
			lighting_capture_clear_control()
			lighting_clear = TRUE
			sleep(10)
			filming_save_snapshot("clear", TRUE)
			text2file(json_encode(list("engine"="516.1688", "source"="ff67d89241336d55f456967ec596d5cd10358df6", "mode"=LIGHTING_COMPOSITION_V2, "native_acceptance"=FALSE)), "filming-take.json")
			text2file("clear-root ready", "filming-ready.txt")
		catch(var/exception/capture_error)
			filming_stop("lighting sequence failed: [filming_exception_detail(capture_error)]")

/mob/living/human/filming_worker/Login()
	filming_check(src == light_viewer && client == filming_observer_client && client.mob == src, "guest human Login identity")
	for(var/fixture_verb in verbs.Copy())
		verbs -= fixture_verb
	filming_check(!verbs.len, "human has zero input verbs")
	// Deliberately isolated Login; actual HUD constructor runs after camera binding.

/mob/living/human/filming_worker/Logout()
	if(!filming_stopping)
		filming_stop("guest disconnected or reassigned")

/mob/living/human/filming_worker/ClickOn()
	return

/mob/filming_observer
	name = "Lighting observer"
	density = FALSE
	invisibility = 101

/mob/filming_observer/Login()
	loc = locate(8,5,1)
	for(var/fixture_verb in verbs.Copy())
		verbs -= fixture_verb
	filming_check(!verbs.len, "guest lobby zero verbs")

/mob/filming_observer/Move()
	return FALSE

/mob/filming_observer/Logout()
	return

/mob/filming_observer/ClickOn()
	return

/proc/filming_prepare_scene()
	light_viewer = new /mob/living/human/filming_worker(locate(8,5,1))
	light_viewer.real_name = "Lighting test observer"
	light_viewer.name = light_viewer.real_name
	light_viewer.dir = NORTH
	filming_check(!light_viewer.client && !light_viewer.ckey && light_viewer.stat == CONSCIOUS, "ordinary awake fixture human")
	filming_check(weather == WEATHER_NONE && time_of_day == "Night", "fixed natural night and no weather")

/proc/filming_save_snapshot(phase, clear_control)
	filming_assert_authored_map(phase)
	var/list/data = lighting_capture_snapshot(light_viewer, clear_control)
	data["phase"] = phase
	data["mode"] = LIGHTING_COMPOSITION_V2
	data["engine"] = "516.1688"
	data["source"] = "ff67d89241336d55f456967ec596d5cd10358df6"
	data["world_time"] = world.time
	data["native_acceptance"] = FALSE
	var/list/corner_rows = list()
	for(var/turf/T in range(3, light_viewer))
		var/list/corners = list()
		for(var/datum/lighting_corner/C in T.corners)
			corners += list(list("x"=C.x, "y"=C.y, "active"=C.active, "r"=C.lum_r, "g"=C.lum_g, "b"=C.lum_b, "window"=C.window_coeff))
		corner_rows += list(list("x"=T.x,"y"=T.y,"corners"=corners))
	data["corners"] = corner_rows
	var/json = json_encode(data)
	filming_check(length(json) <= 60000, "bounded native lighting snapshot")
	text2file(json, "lighting-[phase].json")

/client/Del()
	if (src == filming_observer_client)
		filming_stop("observer disconnected")
	return ..()

/client/Topic()
	return null

/client/Move()
	return FALSE

// No arbitrary clicks, topics, keyboard movement or verbs enter production gameplay.
/client/Click()
	return null

/client/DblClick()
	return null

/client/MouseDown()
	return null

/client/MouseUp()
	return null

/client/MouseDrop()
	return null

/client/MouseDrag()
	return null

/client/MouseMove()
	return null

/client/MouseEntered()
	return null

/client/MouseExited()
	return null

/client/North()
	return null

/client/South()
	return null

/client/East()
	return null

/client/West()
	return null

/client/Northeast()
	return null

/client/Northwest()
	return null

/client/Southeast()
	return null

/client/Southwest()
	return null

/client/Center()
	return null

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
		filming_startup_phase = "create_lighting Night"
		create_lighting("Night")
		filming_startup_phase = "apply_restored_lighting"
		filming_check(apply_restored_lighting(), "native night initialized")
		spawn(0)
			filming_lighting_loop()
		filming_assert_authored_map("after fixture initialization before listener")
		filming_startup_phase = "prepare ordinary human viewer"
		filming_prepare_scene()
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
