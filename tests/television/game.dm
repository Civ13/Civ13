// Real lesson procedures with isolated startup, actor physiology and clock.
var/tv_fixture_time = 1000
var/tv_failures = 0
/world
	hub = ""
	hub_password = ""
	maxx = 100
	maxy = 8
	maxz = 1
	turf = /turf
	visibility = 0
/world/OpenPort(port)
	return port == "none" ? ..() : FALSE
/obj/map_metadata/tv_fixture/New()
	return
/mob/living/human/tv_fixture
	var/active = TRUE
/mob/living/human/tv_fixture/New()
	species = new /datum/species/human
	body_build = new /datum/body_build
	bloodstr = new /datum/reagents/metabolism(1000, src, CHEM_BLOOD)
	ingested = new /datum/reagents/metabolism(1000, src, CHEM_INGEST)
	touching = new /datum/reagents/metabolism(1000, src, CHEM_TOUCH)
	reagents = bloodstr
	vessel = new /datum/reagents(1000, src)
	initialize_recipe_knowledge()
/mob/living/human/tv_fixture/broadcast_online()
	return active
/mob/living/human/tv_fixture/node_lesson_active()
	return active && stat == CONSCIOUS && !sleeping
/mob/living/human/tv_fixture
	var/heard = 0
/mob/living/human/tv_fixture/hear_station_line(message)
	heard++
/proc/tv_check(condition, label)
	if (!condition) tv_failures++
	world.log << "[condition ? "PASS" : "FAIL:"] [label]"
/world/Error(exception/e)
	tv_failures++
	world.log << "runtime error: [e] [e.file]:[e.line]"
/proc/tv_advance(obj/structure/telecom/station/S, ticks)
	for (var/i = 1, i <= ticks, i++)
		tv_fixture_time += 10
		S.tick_node_lesson()
/world/New()
	OpenPort("none")
	generate_gameid()
	GLOB.all_observable_events = list()
	GLOB.moved_event = new /decl/observ/moved
	GLOB.dir_set_event = new /decl/observ/dir_set
	GLOB.name_set_event = new /decl/observ/name_set
	GLOB.stat_set_event = new /decl/observ/stat_set
	movementMachine = new
	map = new /obj/map_metadata/tv_fixture
	map.ID = MAP_NOMADS_CONTINENTAL
	map.ordinal_age = 7
	map.persistence = TRUE
	map.recipe_books = TRUE
	build_research_tree()
	try
		tv_check(!world.port && !OpenPort(0), "closed port refuses reopening")
		var/obj/structure/cable/C = new(locate(3,3,1))
		var/obj/structure/engine/E = new(locate(3,3,1))
		E.on = TRUE
		E.maxpower = 1000
		C.connections |= E
		E.connections |= C
		var/obj/structure/telecom/station/tv/S = new(locate(3,3,1))
		var/obj/structure/telecom/tv/R = new(locate(4,3,1))
		var/obj/structure/telecom/antenna/A = new(locate(3,4,1))
		tv_check(A.anchored, "station antenna anchored")
		S.frequency = 210
		R.frequency = 210
		S.enabled = TRUE
		R.enabled = TRUE
		S.powersource = C
		R.powersource = C
		C.connections |= S
		C.connections |= R
		var/mob/living/human/tv_fixture/teacher = new(locate(3,3,1))
		var/mob/living/human/tv_fixture/student = new(locate(4,4,1))
		S.presenter = teacher
		var/obj/item/tv_camera/K = new(teacher)
		tv_check(S.pair_camera(teacher, K), "physical desk pairing succeeds")
		K.forceMove(locate(4,4,1))
		K.anchored = TRUE
		K.enabled = TRUE
		K.powersource = C
		C.connections |= K
		map.ordinal_age = 6
		tv_check(!S.operational() && !R.operational() && !K.operational(), "pre-1969 blocks all TV equipment")
		map.ordinal_age = 7
		tv_check(S.operational() && R.operational() && K.operational(), "1969 powers TV equipment")
		tv_check(!civ_telecom_era_allowed(/obj/item/weapon/telephone/landline) && !civ_telecom_era_allowed(/obj/structure/telecom/terminal), "phones and terminals remain 2013")
		S.station_name = "Test Television"
		S.faction_tag = "Roleplay"
		tv_check(S.transmit_live(teacher, "Live television", null) > 0 && student.heard > 0, "1969 TV transmits live speech")
		teacher.learn_recipe_node("basic_tools")
		tv_check(S.start_node_lesson(teacher, "basic_tools"), "TV starts node lesson")
		tv_advance(S, 300)
		tv_check(student.knows_recipe_node("basic_tools"), "TV full-series node lesson completes")
		tv_fixture_time = 3000
		S.prepared = TRUE
		S.program = "medical"
		S.transmit_lesson()
		tv_check("medical:1" in student.broadcast_lessons, "TV shares six-lesson skill curriculum")
		tv_check(S.start_video(K) && R.start_watching(student, S) && R.feed_ok(student), "paired camera reaches receiver")
		student.forceMove(locate(5,4,1))
		tv_check(R.check_eye(student) == -1 && !R.tv_watchers.len && !student.using_object, "viewer movement cuts feed")
		student.forceMove(locate(4,4,1))
		R.start_watching(student, S)
		R.enabled = FALSE
		civ_tick_tv_views()
		tv_check(!R.tv_watchers.len, "receiver power switch cuts feed")
		R.enabled = TRUE
		R.start_watching(student, S)
		S.enabled = FALSE
		civ_tick_tv_views()
		tv_check(!S.video_camera && !R.tv_watchers.len, "desk power switch cuts feed")
		S.enabled = TRUE
		S.start_video(K)
		R.start_watching(student, S)
		K.enabled = FALSE
		civ_tick_tv_views()
		tv_check(!S.video_camera && !R.tv_watchers.len, "camera power switch cuts feed")
		K.enabled = TRUE
		S.start_video(K)
		R.start_watching(student, S)
		E.on = FALSE
		civ_tick_tv_views()
		tv_check(!S.video_camera && !R.tv_watchers.len, "actual cable supply loss cuts feed")
		E.on = TRUE
		S.start_video(K)
		R.start_watching(student, S)
		R.frequency++
		civ_tick_tv_views()
		tv_check(!R.tv_watchers.len, "receiver retuning cuts feed")
		R.frequency = S.frequency
		R.start_watching(student, S)
		K.frequency++
		civ_tick_tv_views()
		tv_check(!S.video_camera && !R.tv_watchers.len, "camera retuning cuts feed")
		K.frequency = S.frequency
		var/network = K.network_id
		K.network_id = "foreign"
		tv_check(!S.start_video(K), "foreign camera network rejected")
		K.network_id = network
		S.start_video(K)
		R.start_watching(student, S)
		K.forceMove(locate(4,2,1))
		civ_tick_tv_views()
		tv_check(!S.video_camera && !R.tv_watchers.len, "fixed camera movement cuts feed")
		K.forceMove(locate(70,3,1))
		tv_check(!S.start_video(K), "camera range rejects beyond 60 tiles")
		K.forceMove(locate(4,4,1))
		S.start_video(K)
		R.start_watching(student, S)
		R.forceMove(locate(3,4,1))
		civ_tick_tv_views()
		tv_check(!R.tv_watchers.len, "receiver movement cuts feed")
		R.forceMove(locate(4,3,1))
		R.start_watching(student, S)
		S.forceMove(locate(2,3,1))
		civ_tick_tv_views()
		tv_check(!S.video_camera && !R.tv_watchers.len, "desk movement cuts feed")
		S.forceMove(locate(3,3,1))
		var/obj/item/tv_camera/helmet/HC = new(teacher)
		S.pair_camera(teacher, HC)
		var/obj/item/clothing/head/hat = new(teacher)
		teacher.head = hat
		HC.forceMove(hat)
		HC.enabled = TRUE
		HC.battery_charge = 2
		tv_check(HC.camera_eye() == teacher && S.start_video(HC), "fitted visible helmet camera has wearer eye")
		R.start_watching(student, S)
		teacher.forceMove(locate(10,3,1))
		tv_check(S.video_available() && R.feed_ok(student), "helmet wearer can move inside station range")
		teacher.forceMove(locate(90,3,1))
		civ_tick_tv_views()
		tv_check(!S.video_camera && !R.tv_watchers.len, "helmet wearer out of range cuts feed")
		teacher.forceMove(locate(3,3,1))
		S.start_video(HC)
		R.start_watching(student, S)
		civ_tick_television()
		civ_tick_television()
		tv_check(!HC.battery_charge && !S.video_camera && !R.tv_watchers.len, "helmet battery depletion cuts feed")
		HC.battery_charge = 20
		S.start_video(HC)
		R.start_watching(student, S)
		teacher.head = null
		civ_tick_tv_views()
		tv_check(!S.video_camera && !R.tv_watchers.len, "removed headgear cannot film")
		teacher.head = hat
		HC.forceMove(locate(6,3,1))
		tv_check(!HC.camera_eye() && !S.start_video(HC), "loose helmet camera is not a hidden feed")
		K.battery_charge = 7
		K.camera_health = 31
		S.start_video(K)
		R.start_watching(student, S)
		var/list/saved_camera = K.get_saved_vars()
		for (var/key in list("network_id", "frequency", "enabled", "camera_health", "battery_charge"))
			tv_check((key in saved_camera) && !K.persistence_runtime_var(key), "camera field durable: [key]")
		var/list/saved_desk = S.get_saved_vars()
		tv_check("tv_network_id" in saved_desk, "station network identity durable")
		for (var/key in list("video_camera", "video_eye", "video_desk_origin", "video_camera_origin"))
			tv_check(!(key in saved_desk) && S.persistence_runtime_var(key), "desk session transient: [key]")
		var/list/saved_receiver = R.get_saved_vars()
		for (var/key in list("tv_watchers", "watching_station", "receiver_origin", "receiver_eye"))
			tv_check(!(key in saved_receiver) && R.persistence_runtime_var(key), "receiver session transient: [key]")
		tv_check(map_storage.Save_World() && map_storage.validate_world_save(), "native television world save")
		map_storage.ClearMap()
		tv_check(map_storage.Load_World(), "native television world reload")
		K = locate(/obj/item/tv_camera) in locate(4,4,1)
		S = locate(/obj/structure/telecom/station/tv) in locate(3,3,1)
		R = locate(/obj/structure/telecom/tv) in locate(4,3,1)
		tv_check(K && K.network_id == network && K.camera_health == 31 && K.enabled && K.frequency == 210, "camera and settings persist")
		tv_check(S && S.tv_network_id == network && !S.video_camera && !S.video_eye && !S.presenter, "desk network persists without feed or presenter")
		tv_check(R && !R.tv_watchers.len && !R.watching_station && !civ_tv_receivers.len, "receiver restores without viewer references")
	catch (var/exception/e)
		tv_failures++
		world.log << "FAIL: exception [e] [e.file]:[e.line]"
	var/list/params = params2list(world.params)
	text2file(json_encode(list("failures" = tv_failures, "commit" = params["tested_commit"], "byond_build" = world.byond_build)), "result.json")
	shutdown()
