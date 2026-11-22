// Native probe: suit patching follows the wearer (#6746).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/suit_patch_wait/probe.dm
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
/obj/map_metadata/sp_probe/New()
	return

var/sp_failures = 0
var/sp_runtime_error = FALSE
/proc/sp_check(condition, label)
	if (!condition)
		sp_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	sp_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		GLOB.name_set_event = new /decl/observ/name_set
		GLOB.stat_set_event = new /decl/observ/stat_set
		makeDatumRefLists()
		movementMachine = new
		map = new /obj/map_metadata/sp_probe
		sp_checks()
	catch(var/exception/e)
		sp_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = sp_failures, "runtime_error" = sp_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)


/proc/sp_wearer(x)
	var/mob/living/human/H = new(locate(x, 3, 1))
	var/obj/item/clothing/suit/pressure_suit/S = new(H)
	H.equip_to_slot_or_del(S, slot_wear_suit)
	S.integrity = SUIT_INTEGRITY_MAX - SUIT_PATCH_INTEGRITY
	return H

/proc/sp_checks()
	// Control: a wearer who stays put is patched and the kit is used.
	var/mob/living/human/patcher = new(locate(2, 2, 1))
	var/mob/living/human/still = sp_wearer(2)
	var/obj/item/clothing/suit/pressure_suit/S = still.wear_suit
	sp_check(istype(S), "the suit is worn")
	var/obj/item/pressure_suit_patch/P = new(patcher)
	sp_check(P.patch(S, patcher) && S.integrity == SUIT_INTEGRITY_MAX && QDELETED(P), "a still wearer is patched")

	// A wearer who walks away during the wait interrupts the repair.
	var/mob/living/human/leaver = sp_wearer(3)
	var/obj/item/clothing/suit/pressure_suit/L = leaver.wear_suit
	var/obj/item/pressure_suit_patch/K = new(patcher)
	spawn(10)
		leaver.forceMove(locate(10, 10, 1))
	sp_check(!K.patch(L, patcher), "patching fails when the wearer walks away")
	sp_check(!QDELETED(K), "the kit is kept when the wearer walks away")
	sp_check(L.integrity == SUIT_INTEGRITY_MAX - SUIT_PATCH_INTEGRITY, "the distant suit is not patched")
