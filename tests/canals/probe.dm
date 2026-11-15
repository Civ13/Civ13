// Native probe for canals and pound locks (code/modules/1713/canals.dm).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/canals/probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 12
	maxy = 8
	maxz = 1
	turf = /turf/floor/dirt
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/canal_probe/New()
	return
/mob/living/human/cn_fixture
	m_intent = "stealth"
/mob/living/human/cn_fixture/New()
	return
/mob/living/human/cn_fixture/adaptStat(stat, amount)
	return
/mob/living/human/cn_fixture/update_body(update_icons = 1, forced = FALSE)
	return
/mob/living/human/cn_fixture/update_icons()
	return
/mob/living/human/cn_fixture/regenerate_icons()
	return
// Row 3: a lower pound at height 1 (x 1-4), the lock at x 5, an upper pound at height 2 (x 6-8).
// Row 6: a river running down its own slope, heights 1 and 2.
/datum/terrain_heights/canal_probe
	var/list/heights = list("6,3" = 2, "7,3" = 2, "8,3" = 2, "9,3" = 2, "3,6" = 2, "9,5" = 2)
/datum/terrain_heights/canal_probe/at(x, y, z)
	var/h = heights["[x],[y]"]
	return isnull(h) ? 1 : h
var/cn_failures = 0
var/cn_runtime_error = FALSE
/proc/cn_check(condition, label)
	if (!condition)
		cn_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	cn_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		map = new /obj/map_metadata/canal_probe
		map.terrain_height_file = "probe"
		map.terrain_heights_cache = new /datum/terrain_heights/canal_probe
		cn_checks()
	catch(var/exception/e)
		cn_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = cn_failures, "runtime_error" = cn_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/cn_checks()
	var/turf/W1 = locate(1, 3, 1)
	W1.ChangeTurf(/turf/floor/beach/water/deep)
	for (var/x in 2 to 8)
		var/turf/T = locate(x, 3, 1)
		T.ChangeTurf(/turf/floor/trench/flooded)
	var/turf/A = locate(4, 3, 1)
	var/turf/L = locate(5, 3, 1)
	var/turf/B = locate(6, 3, 1)
	cn_check(canal_step_blocked(L, B), "a boat can't cross a step in a canal")
	cn_check(!canal_step_blocked(A, L) && !canal_step_blocked(B, locate(7, 3, 1)), "level canal water is free to cross")

	// Natural rivers run down their own slope.
	var/turf/R1 = locate(2, 6, 1)
	var/turf/R2 = locate(3, 6, 1)
	R1.ChangeTurf(/turf/floor/beach/water)
	R2.ChangeTurf(/turf/floor/beach/water)
	cn_check(!canal_step_blocked(R1, R2), "a river's own slope doesn't stop boats")

	// The lock: its chamber matches one side at a time.
	var/obj/structure/canal_lock/K = new(L)
	cn_check(K.dir == EAST && K.chamber_level == 1 && K.icon_state == "lock_low", "a new lock faces the upper pound and starts low")
	cn_check(!canal_step_blocked(A, L) && canal_step_blocked(L, B), "low, it opens to the lower pound only")
	K.set_high(TRUE)
	cn_check(K.chamber_level == 2 && K.icon_state == "lock_high", "worked, the chamber fills to the upper level")
	cn_check(canal_step_blocked(A, L) && !canal_step_blocked(L, B), "high, it opens to the upper pound only")

	// Rafts respect the step.
	var/obj/structure/vehicle/raft/RF = new(A)
	var/mob/living/human/cn_fixture/D = new(A)
	D.dir = EAST
	RF.driver = D
	cn_check(!RF.do_vehicle_check(), "a raft can't enter a lock that stands high")
	K.set_high(FALSE)
	cn_check(RF.do_vehicle_check(), "and floats in once it is emptied")

	// Gravity: water floods only ground no higher than itself.
	cn_check(!canal_can_flood(A, locate(9, 3, 1)), "low water doesn't flood higher ground")
	cn_check(canal_can_flood(B, locate(9, 4, 1)), "high water floods lower ground")

	// An aqueduct channel feeds a dry cut beside it.
	var/turf/C = locate(9, 5, 1)
	C.ChangeTurf(/turf/floor/trench)
	var/obj/structure/aqueduct/channel/P = new(locate(10, 5, 1))
	P.wet_level = 1
	aqueduct_feed(locate(9, 5, 1), P)
	cn_check(!istype(locate(9, 5, 1), /turf/floor/trench/flooded), "a channel lower than the cut doesn't flood it")
	P.wet_level = 2
	aqueduct_feed(locate(9, 5, 1), P)
	cn_check(istype(locate(9, 5, 1), /turf/floor/trench/flooded), "a channel at its level floods it")
