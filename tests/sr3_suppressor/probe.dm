// Native probe: the SR-3 spawns with its suppressor installed (#6363).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/sr3_suppressor/probe.dm 300
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
/obj/map_metadata/ss_probe/New()
	return

var/ss_failures = 0
var/ss_runtime_error = FALSE
/proc/ss_check(condition, label)
	if (!condition)
		ss_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	ss_runtime_error = TRUE
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
		map = new /obj/map_metadata/ss_probe
		ss_checks()
	catch(var/exception/e)
		ss_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = ss_failures, "runtime_error" = ss_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/ss_checks()
	var/obj/item/weapon/gun/projectile/submachinegun/srm/G = new(locate(5, 5, 1))
	ss_check(istype(G.silencer, /obj/item/weapon/attachment/silencer/rifle/srm), "a new SR-3 has its SRM suppressor installed")
	var/obj/item/weapon/attachment/silencer/rifle/srm/S = new(locate(5, 5, 1))
	var/obj/item/weapon/gun/projectile/submachinegun/mp40/other = new(locate(5, 5, 1))
	ss_check(!other.configuration_compatible(S), "the 9x39 suppressor still does not fit another caliber")
