// Native probe: a bow, sling or atlatl loads only ammunition still in hand or a held handful (issue 6984).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/bow_load_source/probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 30
	maxy = 8
	maxz = 1
	turf = /turf/floor/dirt
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/bow_load_source_probe/New()
	return
var/bl_failures = 0
var/bl_runtime_error = FALSE
/proc/bl_check(condition, label)
	if (!condition)
		bl_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	bl_runtime_error = TRUE
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
		map = new /obj/map_metadata/bow_load_source_probe
		bl_checks()
	catch(var/exception/e)
		bl_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = bl_failures, "runtime_error" = bl_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/bl_count(mob/living/human/H, path)
	. = 0
	for (var/obj/item/I in H.contents)
		if (I.type == path)
			.++

/proc/bl_checks()
	var/mob/living/human/H = new(locate(4, 4, 1))
	var/obj/item/ammo_casing/atlatl_dart/D = new(H)
	bl_check(bow_load_source_ok(D, H, H), "a dart in hand loads")
	D.forceMove(locate(5, 4, 1))
	bl_check(!bow_load_source_ok(D, H, H), "a dart taken from the hand does not load")
	var/obj/item/ammo_handful/hand = new(H)
	D.forceMove(hand)
	bl_check(bow_load_source_ok(D, hand, H), "a dart in a held handful loads")
	hand.forceMove(locate(6, 4, 1))
	bl_check(!bow_load_source_ok(D, hand, H), "a dart in a dropped handful does not load")
	var/mob/living/human/T = new(locate(7, 4, 1))
	D.forceMove(T)
	bl_check(!bow_load_source_ok(D, H, H), "a dart stripped into another inventory does not load")
	bl_check(!bow_load_source_ok(null, H, H), "a missing dart does not load")
