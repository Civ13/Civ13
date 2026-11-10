// Native probe for underground excavation (code/modules/1713/underground_excavation.dm).
// Full production sources with ordinary startup disabled; run with
// python3 tests/ecology_spawning/run_linux.py . tests/underground_excavation/probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 12
	maxy = 12
	maxz = 1
	turf = /turf/floor/dirt/underground
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/excavation_probe/New()
	return
/mob/living/human/excavation_probe/New()
	return
/mob/living/human/excavation_probe/update_icons()
	return

var/excavation_failures = 0
var/excavation_runtime_error = FALSE
/proc/excavation_check(condition, label)
	if (!condition)
		excavation_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	excavation_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/excavation_probe
		excavation_probe_run()
	catch(var/exception/e)
		excavation_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = excavation_failures, "runtime_error" = excavation_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/excavation_count(turf/T, path)
	. = 0
	for (var/atom/movable/A in T)
		if (istype(A, path))
			.++

/proc/excavation_probe_run()
	var/area/A = get_area(locate(1, 1, 1))
	A.climate = "temperate"
	var/turf/rock = locate(3, 3, 1)
	excavation_check(istype(rock, /turf/floor/dirt/underground) && rock.density, "fixture starts as soft cave rock")
	excavation_check(isnull(underground_excavation_problem(rock)), "soft rock can be dug out with a shovel")
	rock.mining_in_progress = TRUE
	excavation_check(findtext(underground_excavation_problem(rock), "already digging"), "a tile being mined cannot be dug at the same time")
	rock.mining_in_progress = FALSE

	var/turf/opened = underground_excavation_finish(rock)
	excavation_check(opened == locate(3, 3, 1), "finish returns the opened tile")
	excavation_check(istype(opened, /turf/floor/dirt) && !istype(opened, /turf/floor/dirt/underground) && !opened.density, "dug-out rock opens into dirt floor")
	excavation_check(excavation_count(opened, /obj/item/weapon/barrier) == 2, "soft rock gives two dirt piles")
	excavation_check(!excavation_count(opened, /obj/item/stack/material/stone) && !excavation_count(opened, /obj/item/stack/ore), "shovelling gives no stone or ore")
	excavation_check(opened.available_dirt > 0, "the opened floor can still be scooped for dirt")
	excavation_check(findtext(underground_excavation_problem(opened), "no earth left"), "an open floor cannot be dug out again")

	var/turf/sandy = locate(5, 3, 1)
	sandy.ChangeTurf(/turf/floor/dirt/underground/sandy)
	sandy = underground_excavation_finish(locate(5, 3, 1))
	excavation_check(excavation_count(sandy, /obj/item/weapon/barrier) == 2 && excavation_count(sandy, /obj/item/stack/ore/glass) == 1, "sandy rock gives two dirt piles and a sand pile")

	var/turf/debris = locate(7, 3, 1)
	debris.ChangeTurf(/turf/floor/dirt/underground/empty)
	debris = locate(7, 3, 1)
	excavation_check(isnull(underground_excavation_problem(debris)), "cave-in rubble can be shovelled away")
	debris = underground_excavation_finish(debris)
	excavation_check(istype(debris, /turf/floor/dirt) && !debris.density && excavation_count(debris, /obj/item/weapon/barrier) == 1, "rubble clears into dirt floor and one dirt pile")

	var/turf/icy = locate(9, 3, 1)
	icy.ChangeTurf(/turf/floor/dirt/underground/icy)
	icy = locate(9, 3, 1)
	excavation_check(findtext(underground_excavation_problem(icy), "frozen"), "frozen rock needs a pickaxe")
	var/turf/hard = locate(9, 5, 1)
	hard.is_mineable = FALSE
	excavation_check(findtext(underground_excavation_problem(hard), "too hard"), "unmineable rock refuses a shovel")
	var/turf/floor/plating/plating = locate(9, 7, 1)
	plating.ChangeTurf(/turf/floor/plating)
	excavation_check(findtext(underground_excavation_problem(locate(9, 7, 1)), "no earth left"), "built floors have nothing to dig out")

	// A shovel on frozen rock is routed to excavation and refused without changing it.
	var/mob/living/human/excavation_probe/H = new(locate(9, 2, 1))
	var/obj/item/weapon/material/shovel/S = new(locate(9, 2, 1))
	icy.attackby(S, H)
	excavation_check(istype(locate(9, 3, 1), /turf/floor/dirt/underground/icy) && !H.shoveling, "shovel on frozen rock leaves it intact")

	// A finished tunnel shaft leaves its earth at the digger's feet.
	var/turf/feet = locate(11, 11, 1)
	feet.ChangeTurf(/turf/floor/dirt)
	H.forceMove(locate(11, 11, 1))
	excavation_shaft_spoil(H)
	excavation_check(excavation_count(locate(11, 11, 1), /obj/item/weapon/barrier) == 2, "a tunnel shaft leaves two dirt piles")
