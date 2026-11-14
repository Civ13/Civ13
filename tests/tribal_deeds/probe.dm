// Native tribal deeds probe, included by tests/ecology_spawning/run_linux.py, never by
// the game DME. It drives code/modules/1713/tribal_deeds.dm.
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
/obj/map_metadata/deed_probe/New()
	map = src
/mob/living/human/deed_probe/New()
	icon_update = FALSE
	return
var/deed_failures = 0
var/deed_runtime_error = FALSE
/proc/deed_check(condition, label)
	if (!condition)
		deed_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	deed_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"


/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		new /obj/map_metadata/deed_probe
		for (var/turf/T in block(locate(1, 1, 1), locate(30, 30, 1)))
			T.ChangeTurf(/turf/floor/grass, FALSE, FALSE)
		deed_record_checks()
		deed_carve_checks()
		deed_hook_checks()
	catch(var/exception/e)
		deed_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = deed_failures, "runtime_error" = deed_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/deed_probe_human(x, y, tribe)
	var/mob/living/human/deed_probe/H = new(locate(x, y, 1))
	H.real_name = "Probe [x]"
	H.civilization = tribe
	return H

/proc/deed_record_checks()
	var/mob/living/human/H = deed_probe_human(3, 3, "none")
	deed_check(!record_deed(H, "x", "Did a thing"), "no deeds without a tribe")
	H.civilization = "Wolves"
	deed_check(record_deed(H, "x", "Did a thing"), "a tribesman remembers a deed")
	deed_check(!record_deed(H, "x", "Did it again"), "a kind is remembered once")
	deed_check(H.pending_deeds["x"] == "Did a thing", "the first telling is kept")

/proc/deed_carve_checks()
	var/mob/living/human/A = deed_probe_human(10, 10, "Wolves")
	var/mob/living/human/B = deed_probe_human(10, 11, "Bears")
	var/obj/structure/religious/totem_pole/P = new(locate(11, 10, 1))
	record_deed(A, "one", "First|deed")
	record_deed(A, "two", "Second deed")
	deed_check(P.add_deeds(A) == 2 && P.tribe == "Wolves", "carving claims the pole for the tribe")
	deed_check(!length(A.pending_deeds) && ("one" in A.carved_deeds), "carved deeds leave the pending list")
	deed_check(!record_deed(A, "one", "First deed"), "a carved kind is not remembered again")
	deed_check(findtext(P.deeds[1], "First/deed|Probe 10|") == 1, "the pipe in a deed cannot break the record")
	record_deed(B, "b", "Bear deed")
	deed_check(!P.add_deeds(B) && length(B.pending_deeds) == 1, "another tribe cannot carve the pole")
	P.deeds.len = 0
	for (var/i = 1 to DEED_POLE_CAP - 1)
		P.deeds += "filler|x|y"
	record_deed(A, "three", "Third")
	record_deed(A, "four", "Fourth")
	deed_check(P.add_deeds(A) == 1 && length(A.pending_deeds) == 1, "a full pole keeps the rest waiting")

/proc/deed_hook_checks()
	var/mob/living/human/H = deed_probe_human(20, 20, "Wolves")
	var/mob/living/simple_animal/sheep/S = new(locate(20, 21, 1))
	S.make_wild()
	S.tame_trust = TAME_FEEDINGS - 1
	S.tame_feeding(H, 20000000)
	deed_check(H.pending_deeds && H.pending_deeds["tame_/mob/living/simple_animal/sheep"] == "Tamed a wild sheep", "taming a wild sheep is a deed")
	var/mob/living/simple_animal/rabbit/R = new(locate(22, 22, 1))
	deed_check(!deed_big_game(R), "a rabbit is no great deed")
	var/mob/living/simple_animal/cattle/C = new(locate(23, 23, 1))
	C.maxHealth = 200
	C.mob_size = MOB_LARGE
	deed_check(deed_big_game(C), "a big beast is a great deed")
	C.lastattacker = H
	C.death()
	deed_check(H.pending_deeds["big_game_[C.type]"], "bringing down a big beast is a deed")
	var/obj/structure/dugout_log/L = new(locate(25, 25, 1))
	L.finish(H)
	deed_check(H.pending_deeds["dugout_canoe"], "finishing a canoe is a deed")
