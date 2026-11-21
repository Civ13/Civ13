// Native probe: a salting container restored mid-batch restarts its completion (#6446).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/salting_restore/probe.dm 300
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
/obj/map_metadata/sr_probe/New()
	return

var/sr_failures = 0
var/sr_runtime_error = FALSE
/proc/sr_check(condition, label)
	if (!condition)
		sr_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	sr_runtime_error = TRUE
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
		map = new /obj/map_metadata/sr_probe
		sr_checks()
	catch(var/exception/e)
		sr_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = sr_failures, "runtime_error" = sr_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/obj/structure/salting_container/sr_probe
	var/restarts = 0
/obj/structure/salting_container/sr_probe/salting()
	restarts++

/proc/sr_checks()
	var/obj/structure/salting_container/sr_probe/busy = new(locate(5, 5, 1))
	new /obj/item/weapon/pigleg(busy)
	busy.producttype = /obj/item/weapon/pigleg
	busy.saltamount = 30
	busy.salting = TRUE
	busy.after_load()
	sr_check(busy.restarts == 1, "a container saved mid-batch restarts its salting once on load ([busy.restarts])")
	var/obj/structure/salting_container/sr_probe/idle = new(locate(6, 5, 1))
	idle.after_load()
	sr_check(idle.restarts == 0, "an idle container does not start salting on load")
