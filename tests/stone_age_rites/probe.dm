// Native Stone Age rites probe, included by tests/ecology_spawning/run_linux.py, never by
// the game DME. It drives code/modules/1713/stone_age_rites.dm.
/world
	hub = ""
	hub_password = ""
	maxx = 30
	maxy = 30
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/rites_probe/New()
	map = src
/mob/living/human/rites_probe/New()
	icon_update = FALSE
	return
var/rites_failures = 0
var/rites_runtime_error = FALSE
/proc/rites_check(condition, label)
	if (!condition)
		rites_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	rites_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"


/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		new /obj/map_metadata/rites_probe
		for (var/turf/T in block(locate(1, 1, 1), locate(30, 30, 1)))
			T.ChangeTurf(/turf/floor/grass, FALSE, FALSE)
		rites_mound_checks()
		rites_feast_checks()
	catch(var/exception/e)
		rites_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = rites_failures, "runtime_error" = rites_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/rites_probe_human(x, y)
	var/mob/living/human/rites_probe/H = new(locate(x, y, 1))
	H.real_name = "Probe [x] [y]"
	H.civilization = "Wolves"
	H.stat = CONSCIOUS
	return H

/proc/rites_mound_checks()
	var/mob/living/human/H = rites_probe_human(3, 4)
	var/obj/structure/religious/grave/G = new(locate(3, 3, 1))
	G.open = FALSE
	G.icon_state = "grave_filled"
	var/obj/item/weapon/barrier/D = new(locate(3, 4, 1))
	rites_check(!G.add_mound_dirt(D, H) && !G.mound_dirt, "an empty grave gets no mound")
	new /obj/structure/religious/remains(G)
	for (var/i = 1 to MOUND_DIRT - 1)
		G.add_mound_dirt(new /obj/item/weapon/barrier(locate(3, 4, 1)), H)
	rites_check(!G.mound_raised && G.mound_dirt == MOUND_DIRT - 1, "the mound needs [MOUND_DIRT] piles of dirt")
	G.add_mound_dirt(new /obj/item/weapon/barrier(locate(3, 4, 1)), H, "Old Grey")
	rites_check(G.mound_raised && G.name == "burial mound of Old Grey" && G.icon_state == "burial_mound", "the last pile raises a named mound")
	rites_check(H.pending_deeds && H.pending_deeds["burial_mound"] == "Raised a burial mound over Old Grey", "raising a mound is a deed")
	G.icon_state = "grave_filled"
	G.initialize()
	rites_check(G.icon_state == "burial_mound", "a reloaded mound keeps its look")
	var/obj/structure/religious/cairn/C = new(locate(5, 5, 1))
	rites_check(C.icon_state == "cairn" && !C.density, "a cairn stands as a marker")

/proc/rites_feast_checks()
	var/obj/structure/feast_mat/M = new(locate(15, 15, 1))
	var/list/people = list()
	for (var/i = 1 to 3)
		people += rites_probe_human(14 + i, 16)
	for (var/i = 1 to 4)
		new /obj/item/weapon/reagent_containers/food/snacks/grown/wheat(M)
	M.update_icon()
	rites_check(M.icon_state == "feast_mat_food", "food shows on the mat")
	var/mob/living/human/host = people[1]
	rites_check(M.feast_refusal(host) && !M.hold_feast(host), "three people are not a feast")
	var/mob/living/human/late = rites_probe_human(15, 14)
	people += late
	for (var/mob/living/human/H in people)
		H.nutrition = 10
	var/now = 20000000
	rites_check(!M.feast_refusal(host) && M.hold_feast(host, now) == 4, "four people hold a feast")
	rites_check(!length(M.dishes()) && M.icon_state == "feast_mat", "the feast eats one dish each")
	rites_check(late.nutrition == late.max_nutrition && late.feasting(now + 60) && !late.feasting(now + 200), "guests are full for three hours")
	rites_check(host.pending_deeds && host.pending_deeds["feast"] == "Held a feast for 4 people", "holding a feast is a deed")
	new /obj/item/weapon/reagent_containers/food/snacks/grown/wheat(M)
	rites_check(M.feast_refusal(host), "one dish is not enough for four")
