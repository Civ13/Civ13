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
/obj/map_metadata/canal_probe
	nomads = TRUE
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
	var/list/heights = list("3,1" = 2, "4,1" = 3, "6,3" = 2, "7,3" = 2, "8,3" = 2, "9,3" = 2, "3,6" = 2, "9,5" = 2)
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

	// A real hand operation closes both gates to boats until the lift completes.
	var/mob/living/human/cn_fixture/operator = new(locate(5, 2, 1))
	operator.stat = CONSCIOUS
	spawn(0)
		K.attack_hand(operator)
	sleep(1)
	cn_check(K.busy && !RF.do_vehicle_check(), "working a lock blocks the raft entry point on its level side")
	cn_check(canal_step_blocked(A, L) && canal_step_blocked(L, A) && canal_step_blocked(B, L) && canal_step_blocked(L, B), "both gates block both ways during filling")
	RF.forceMove(L)
	D.forceMove(L)
	D.dir = WEST
	cn_check(!RF.do_vehicle_check(), "the same movement check refuses passage out through the level gate")
	RF.forceMove(A)
	D.forceMove(A)
	D.dir = EAST
	sleep(102)
	cn_check(!K.busy && K.high && K.chamber_level == 2 && !canal_step_blocked(L, B) && canal_step_blocked(A, L), "an intact lift opens only the upper gates after filling")

	// Emptying closes the level upper gate in both directions. An operator
	// walking away releases the lock with its old level and icon.
	spawn(0)
		K.attack_hand(operator)
	sleep(1)
	cn_check(K.busy && canal_step_blocked(L, B) && canal_step_blocked(B, L), "emptying shuts the gate connected to its current upper level")
	operator.forceMove(locate(4, 2, 1))
	sleep(3)
	cn_check(!K.busy && K.high && K.chamber_level == 2 && K.icon_state == "lock_high" && !canal_step_blocked(L, B), "an interrupted operator leaves the lock high and reopens its upper gate")
	operator.forceMove(locate(5, 2, 1))

	// Trench removal while a real hand interaction is waiting must not commit
	// the lift, change the chamber level, or leave the gates closed.
	K.set_high(FALSE)
	spawn(0)
		K.attack_hand(operator)
	sleep(1)
	cn_check(K.busy, "the second filling cycle is underway before removing its upper trench")
	B.ChangeTurf(/turf/floor/dirt)
	sleep(102)
	cn_check(!K.busy && !K.high && K.chamber_level == 1 && K.icon_state == "lock_low" && RF.do_vehicle_check(), "losing the upper pound cancels the lift without changing the lock and reopens the low gate")
	var/turf/restored = locate(6, 3, 1)
	restored.ChangeTurf(/turf/floor/trench/flooded)
	B = locate(6, 3, 1)

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

	// A raised, dry bank can be dug down to the sea without changing terrain.
	var/turf/sea = locate(2, 1, 1)
	sea.ChangeTurf(/turf/floor/beach/water/deep/saltwater)
	var/turf/floor/trench/coast = locate(3, 1, 1)
	coast = coast.ChangeTurf(/turf/floor/trench)
	cn_check(!coast.trench_try_flood() && coast.trench_bed_level() == 2, "a raised undug bed cannot flood")
	coast.trench_cut = 1
	coast.trench_lining = "timber"
	cn_check(coast.trench_try_flood(), "a cut low enough to reach the sea floods")
	coast = locate(3, 1, 1)
	cn_check(coast.salty && coast.trench_cut == 1 && coast.trench_lining == "timber" && coast.trench_max_cut() == 2, "saltwater replacement preserves the cut and its timber")
	cn_check(terrain_height_at(coast) == 2 && canal_level(coast) == 1 && !canal_step_blocked(sea, coast), "the old ground stays put and the cut shares the sea surface")

	var/turf/floor/trench/inland = locate(4, 1, 1)
	inland = inland.ChangeTurf(/turf/floor/trench)
	inland.trench_lining = "stone"
	inland.trench_cut = 3
	cn_check(inland.trench_try_flood(), "the source level carries inland to a deeper connected bed")
	inland = locate(4, 1, 1)
	cn_check(inland.trench_max_cut() == 4 && inland.trench_bed_level() == 0 && canal_level(inland) == 1 && !canal_step_blocked(coast, inland), "boats can cross a change of bed at the same water surface")
	inland.check_filling()
	cn_check(inland.flooded && inland.trench_cut == 2 && canal_level(inland) == 1, "filling to the surface keeps the tile navigable")
	inland.check_filling()
	inland = locate(4, 1, 1)
	cn_check(!inland.flooded && inland.trench_cut == 1 && inland.trench_lining == "stone", "filling above the surface dries the tile without losing lining")
	var/list/fields = inland.get_saved_vars()
	cn_check(("trench_cut" in fields) && ("trench_lining" in fields), "new terrain properties are in the persistence allowlist")
	fields = coast.get_saved_vars()
	cn_check("trench_water_level" in fields, "a supplied water surface is saved")
	var/turf/isolated_sea = locate(11, 7, 1)
	isolated_sea.ChangeTurf(/turf/floor/beach/water/deep/saltwater)
	var/turf/floor/trench/corner = locate(12, 8, 1)
	corner = corner.ChangeTurf(/turf/floor/trench)
	cn_check(!corner.trench_try_flood() && corner.trench_max_cut() == 1, "corner-only sea contact cannot create a canal and the bare cap is one extra cut")
	cn_check(isnull(canal_flood_source_level(L)), "lock chambers have a navigation level but do not feed cuts")
