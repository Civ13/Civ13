// Particle board (code/modules/1713/particle_board.dm): sawdust from the saw
// mills, the hot press pressing, the indoor builds and swelling in water.
// The procs run; only the hot press wait and the probe mob's hands are stood
// in for, and the minute worker is stopped so the probe soaks by hand.
/world
	hub = ""
	hub_password = ""
	maxx = 12
	maxy = 12
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/particle_probe/New()
	return
/mob/living/human/particle_probe/New()
	return
/mob/living/human/particle_probe/put_in_hands(obj/item/W)
	return FALSE
var/particle_failures = 0
var/particle_runtime_error = FALSE
var/particle_wait_ok = TRUE
/proc/particle_check(condition, label)
	if (!condition)
		particle_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	particle_runtime_error = TRUE
	world.log << "runtime error: [e] [e.file]:[e.line]"
/obj/structure/hot_press/particle_press_wait(mob/living/human/H)
	return particle_wait_ok

/proc/particle_count(turf/T, path)
	. = 0
	for (var/obj/item/stack/S in T)
		if (S.type == path)
			. += S.amount

/proc/particle_checks(mob/living/human/particle_probe/H, turf/T)
	H.a_intent = I_HELP
	particle_board_timer_off = TRUE
	// Saw mills.
	var/obj/structure/sawmill/large/L = new(locate(2, 2, 1))
	var/obj/item/stack/material/wood/W = new(locate(2, 3, 1), 5)
	L.sawmill_sawdust(W)
	particle_check(particle_count(get_turf(L), /obj/item/stack/sawdust) == 3, "a large saw mill leaves a pile of sawdust for every two logs")
	L.sawmill_sawdust(W)
	particle_check(particle_count(get_turf(L), /obj/item/stack/sawdust) == 6, "more sawdust joins the same pile")
	var/obj/structure/sawmill/primitive = new(locate(3, 2, 1))
	particle_check(!primitive.sawmill_sawdust(W) && particle_count(get_turf(primitive), /obj/item/stack/sawdust) == 0, "the primitive mill leaves no sawdust")
	var/obj/item/stack/material/woodplank/planks = new(locate(2, 3, 1), 5)
	particle_check(!L.sawmill_sawdust(planks), "only logs leave sawdust")
	// Hot press.
	var/obj/structure/hot_press/P = new(locate(6, 5, 1))
	var/turf/PT = get_turf(P)
	var/obj/item/stack/sawdust/D = new(T, 10)
	P.attackby(D, H)
	particle_check(D.amount == 10 && particle_count(PT, /obj/item/stack/material/particle_board) == 0, "no resin, no particle board")
	P.reagents.add_reagent("phenolic_resin", 20)
	var/obj/item/stack/sawdust/few = new(locate(8, 8, 1), 3)
	P.attackby(few, H)
	particle_check(few.amount == 3 && particle_count(PT, /obj/item/stack/material/particle_board) == 0, "three piles of sawdust are too few")
	particle_wait_ok = FALSE
	P.attackby(D, H)
	particle_wait_ok = TRUE
	particle_check(D.amount == 10 && P.reagents.get_reagent_amount("phenolic_resin") == 20 && P.icon_state == "hot_press", "an interrupted pressing uses nothing")
	P.attackby(D, H)
	particle_check(D.amount == 6 && P.reagents.get_reagent_amount("phenolic_resin") == 10 && particle_count(PT, /obj/item/stack/material/particle_board) == 3, "phenolic resin and four piles of sawdust press three sheets")
	P.reagents.remove_reagent("phenolic_resin", 10)
	P.reagents.add_reagent("resin", 10)
	P.attackby(D, H)
	particle_check(D.amount == 2 && particle_count(PT, /obj/item/stack/material/particle_board) == 5 && P.reagents.get_reagent_amount("resin") == 0, "plain pine resin presses two sheets")
	var/material/M = get_material_by_name("particle_board")
	particle_check(M && M.stack_type == /obj/item/stack/material/particle_board && M.hardness < get_material_by_name("wood").hardness, "particle board is a material softer than wood")
	// Recipes and nodes.
	if (!recipe_node_requirements.len)
		build_research_tree()
	for (var/path in list(/obj/structure/table/rack/shelf/wooden/particle_board, /obj/structure/table/modern/table/particle_board, /obj/structure/closet/cabinet/particle_board, /obj/structure/closet/cabinet/particle_board/wall, /obj/structure/bookcase/particle_board, /obj/covers/wood_wall/particle_board, /obj/covers/wood/particle_board))
		particle_check(particle_board_path(path) && recipe_node_requirements["[path]"] == "combustion", "[path] is a particle board build behind the combustion node")
	particle_check(!particle_board_path(/obj/structure/table/rack/shelf/wooden), "a plank shelf is not particle board")
	// Water.
	var/turf/dry = locate(10, 10, 1)
	var/turf/wet = locate(10, 2, 1)
	new /obj/effect/flooding(wet)
	particle_check(!particle_board_wet_at(dry) && particle_board_wet_at(wet), "a puddled tile is wet and a dry one is not")
	var/obj/item/stack/material/particle_board/B = new(wet, 7)
	particle_check(B in particle_board_things, "sheets are tracked")
	particle_board_tick()
	particle_check(!QDELETED(B) && B.particle_soak == 1, "one wet minute soaks the sheets")
	particle_board_tick()
	particle_check(QDELETED(B) && particle_count(wet, /obj/item/stack/swollen_particle_board) == 7 && particle_count(wet, /obj/item/stack/material/particle_board) == 0, "two wet minutes swell the sheets into swollen boards")
	particle_board_tick()
	particle_board_tick()
	particle_board_tick()
	particle_check(particle_count(wet, /obj/item/stack/swollen_particle_board) == 0, "swollen boards crumble away")
	var/obj/item/stack/material/particle_board/kept = new(dry, 4)
	for (var/i in 1 to 6)
		particle_board_tick()
	particle_check(!QDELETED(kept) && kept.particle_soak == 0, "dry sheets keep")
	var/obj/structure/bookcase/particle_board/case = new(wet)
	var/obj/item/stack/sawdust/inside = new(case, 1)
	particle_board_tick()
	particle_board_tick()
	particle_check(findtext(case.name, "swollen") == 1, "a wet bookcase swells")
	particle_board_tick()
	particle_board_tick()
	particle_board_tick()
	particle_check(QDELETED(case) && inside.loc == wet && !(case in particle_board_things), "it falls apart and spills what it held")
	var/obj/covers/wood_wall/particle_board/wall = new(wet)
	particle_board_tick()
	particle_board_tick()
	particle_check(wall.icon_state == "particle_wall_swollen" && wall.health <= wall.maxhealth / 2, "a wet partition swells and weakens")
	var/obj/structure/table/modern/table/particle_board/table = new(dry)
	table.table_destroy(2, H)
	particle_check(QDELETED(table) && !(locate(/obj/structure/table_frame) in dry), "taking a particle board table apart leaves no wooden frame")

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/particle_probe
		map.ordinal_age = 5
		populate_material_list()
		var/turf/T = locate(5, 5, 1)
		var/mob/living/human/particle_probe/H = new(locate(5, 6, 1))
		particle_check(!world.port, "fixture has no listening port")
		particle_checks(H, T)
	catch(var/exception/e)
		particle_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = particle_failures, "runtime_error" = particle_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)
