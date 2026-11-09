// Native probe: a finished washing machine cycle clears fleas like a sink (#4215).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/washing_machine/probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 8
	maxy = 8
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/wm_probe/New()
	return

var/wm_failures = 0
var/wm_runtime_error = FALSE
/proc/wm_check(condition, label)
	if (!condition)
		wm_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	wm_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/wm_probe
		wm_checks()
	catch(var/exception/e)
		wm_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = wm_failures, "runtime_error" = wm_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/wm_load(obj/machinery/washing_machine/W, obj/item/I)
	I.loc = W
	W.washing += I

/proc/wm_checks()
	var/turf/T = locate(2, 2, 1)
	var/obj/machinery/washing_machine/W = new(T)
	var/obj/item/clothing/infested = new /obj/item/clothing/under(T)
	infested.fleas = TRUE
	infested.dirtyness = 50
	var/obj/item/clothing/clean = new /obj/item/clothing/under(T)
	wm_load(W, infested)
	wm_load(W, clean)
	W.state = 4
	W.complete_wash()
	wm_check(!infested.fleas, "a completed wash clears flea-infested clothing")
	wm_check(!clean.fleas && clean.dirtyness == -100, "uninfested clothing stays flea-free and is cleaned")
	wm_check(infested.dirtyness == -100 && W.state == 4, "the cycle still cleans and leaves the door closed")
	// Clothing taken out or destroyed mid-cycle is not touched by the finished cycle.
	var/obj/item/clothing/removed = new /obj/item/clothing/under(T)
	removed.fleas = TRUE
	var/obj/item/clothing/destroyed = new /obj/item/clothing/under(T)
	destroyed.fleas = TRUE
	wm_load(W, removed)
	wm_load(W, destroyed)
	removed.loc = T
	qdel(destroyed)
	W.complete_wash()
	wm_check(removed.fleas, "clothing removed before the cycle ends keeps its fleas")
	wm_check(!(removed in W.washing) && !(destroyed in W.washing), "removed and destroyed items leave the wash list")
