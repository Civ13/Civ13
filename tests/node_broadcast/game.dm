// Real lesson procedures with isolated startup, actor physiology and clock.
var/node_fixture_time = 1000
var/node_failures = 0
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
/obj/map_metadata/node_fixture/New()
	return
/mob/living/human/node_fixture
	var/active = TRUE
/mob/living/human/node_fixture/New()
	species = new /datum/species/human
	body_build = new /datum/body_build
	bloodstr = new /datum/reagents/metabolism(1000, src, CHEM_BLOOD)
	ingested = new /datum/reagents/metabolism(1000, src, CHEM_INGEST)
	touching = new /datum/reagents/metabolism(1000, src, CHEM_TOUCH)
	reagents = bloodstr
	vessel = new /datum/reagents(1000, src)
	initialize_recipe_knowledge()
/mob/living/human/node_fixture/broadcast_online()
	return active
/mob/living/human/node_fixture/node_lesson_active()
	return active && stat == CONSCIOUS && !sleeping
/mob/living/human/node_fixture/hear_station_line(message)
	return
/proc/node_check(condition, label)
	if (!condition) node_failures++
	world.log << "[condition ? "PASS" : "FAIL:"] [label]"
/world/Error(exception/e)
	node_failures++
	world.log << "runtime error: [e] [e.file]:[e.line]"
/proc/node_advance(obj/structure/telecom/station/S, ticks)
	for (var/i = 1, i <= ticks, i++)
		node_fixture_time += 10
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
	map = new /obj/map_metadata/node_fixture
	map.ID = MAP_NOMADS_CONTINENTAL
	map.ordinal_age = 5
	map.persistence = TRUE
	map.recipe_books = TRUE
	build_research_tree()
	try
		node_check(!world.port, "offline fixture")
		var/obj/structure/cable/C = new(locate(3,3,1))
		var/obj/structure/engine/E = new(locate(3,3,1))
		E.on = TRUE
		E.maxpower = 1000
		C.connections |= E
		E.connections |= C
		var/obj/structure/telecom/station/S = new(locate(3,3,1))
		var/obj/structure/telecom/R = new(locate(4,3,1))
		var/obj/structure/telecom/antenna/A = new(locate(3,4,1))
		S.enabled = TRUE
		R.enabled = TRUE
		S.powersource = C
		R.powersource = C
		C.connections |= S
		C.connections |= R
		var/mob/living/human/node_fixture/teacher = new(locate(3,3,1))
		var/mob/living/human/node_fixture/student = new(locate(4,4,1))
		S.presenter = teacher
		var/id = "basic_tools"
		node_check(!S.start_node_lesson(teacher, id), "presenter must know the node")
		teacher.learn_recipe_node(id)
		node_check(S.start_node_lesson(teacher, id), "qualified presenter starts one node")
		node_check(!S.start_node_lesson(teacher, id), "one simultaneous node per station")
		node_advance(S, 50)
		S.stop_presenting(teacher)
		S.presenter = teacher
		node_check(!S.node_lesson_id && !S.node_lesson_progress, "stop/resume between ticks discards prior lesson")
		node_check(!S.start_node_lesson(teacher, id), "stop/resume between ticks enforces cooldown")
		node_fixture_time += 601
		node_check(S.start_node_lesson(teacher, id), "new lesson starts after explicit-stop cooldown")
		node_advance(S, 299)
		node_check(!student.knows_recipe_node(id), "partial 299-second attendance teaches nothing")
		var/mob/living/human/node_fixture/late = new(locate(4,4,1))
		node_advance(S, 1)
		node_check(student.knows_recipe_node(id) && !late.knows_recipe_node(id), "five-minute learner completes but late joiner does not")
		node_check(!S.node_lesson_id && !S.node_lesson_listeners.len && !(S in active_node_lesson_stations), "completion retires actor references")
		node_check(!S.start_node_lesson(teacher, id), "per-station cooldown enforced")
		node_fixture_time += 601
		node_check(S.start_node_lesson(teacher, id), "cooldown expiry permits next lesson")
		late.active = FALSE
		node_advance(S, 1)
		late.active = TRUE
		node_check(!S.node_lesson_id && !late.knows_recipe_node(id), "AFK or disconnect removes listener without credit")
		node_fixture_time += 601
		S.start_node_lesson(teacher, id)
		late.sleeping = 1
		node_advance(S, 1)
		late.sleeping = 0
		node_check(!S.node_lesson_id && !late.knows_recipe_node(id), "sleeping listener cannot complete")
		node_fixture_time += 601
		S.start_node_lesson(teacher, id)
		R.frequency++
		R.interrupt_node_reception()
		R.frequency--
		node_advance(S, 1)
		node_check(!S.node_lesson_id && !late.knows_recipe_node(id), "retuning and returning between ticks cuts attendance")
		node_fixture_time += 601
		S.start_node_lesson(teacher, id)
		R.enabled = FALSE
		R.interrupt_node_reception()
		R.enabled = TRUE
		node_advance(S, 1)
		node_check(!S.node_lesson_id, "receiver power off/on between ticks cuts attendance")
		node_fixture_time += 601
		S.start_node_lesson(teacher, id)
		late.loc = locate(90,4,1)
		node_advance(S, 1)
		late.loc = locate(4,4,1)
		node_check(!S.node_lesson_id, "leaving receiver range cuts attendance")
		node_fixture_time += 601
		S.start_node_lesson(teacher, id)
		teacher.known_recipe_nodes = list()
		node_advance(S, 1)
		teacher.learn_recipe_node(id)
		node_check(!S.node_lesson_id, "teacher knowledge revocation cancels session")
		node_fixture_time += 601
		S.start_node_lesson(teacher, id)
		node_fixture_time += 21
		S.tick_node_lesson()
		node_check(S.node_lesson_id && S.node_lesson_progress == 0, "unobserved scheduler gaps receive no credit but keep the session")
		S.stop_node_lesson()
		node_fixture_time += 601
		S.start_node_lesson(teacher, id)
		var/datum/research_node/N = get_research_node(id)
		var/old_tier = N.era_tier
		N.era_tier = 9
		node_advance(S, 1)
		N.era_tier = old_tier
		node_check(!S.node_lesson_id && !late.knows_recipe_node(id), "research ceiling remains required through completion")
		node_fixture_time += 601
		for (var/i = 1, i <= 40, i++) new /mob/living/human/node_fixture(locate(4,4,1))
		S.start_node_lesson(teacher, id)
		node_check(S.node_lesson_listeners.len == 32, "audience bounded at 32")
		var/list/saved = S.get_saved_vars()
		for (var/key in list("node_lesson_id", "node_lesson_teacher", "node_lesson_listeners", "node_lesson_progress", "node_lesson_last_tick", "node_lesson_cooldown_until"))
			node_check(!(key in saved) && S.persistence_runtime_var(key), "transient field excluded: [key]")
		S.after_load()
		node_check(!S.node_lesson_id && !(S in active_node_lesson_stations), "restored station has no live lesson")
		map.recipe_books = FALSE
		node_check(!S.start_node_lesson(teacher, id), "disabled feature cannot teach")
		A.anchored = FALSE
	catch (var/exception/e)
		node_failures++
		world.log << "FAIL: exception [e] [e.file]:[e.line]"
	var/list/params = params2list(world.params)
	text2file(json_encode(list("failures" = node_failures, "commit" = params["tested_commit"], "byond_build" = world.byond_build)), "result.json")
	shutdown()
