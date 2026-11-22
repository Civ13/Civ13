// Native probe: rolling mill takes preset iron and steel stacks (#6784).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/rolling_mill/stock_probe.dm
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
/obj/map_metadata/rm_probe/New()
	return

var/rm_failures = 0
var/rm_runtime_error = FALSE
/proc/rm_check(condition, label)
	if (!condition)
		rm_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	rm_runtime_error = TRUE
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
		map = new /obj/map_metadata/rm_probe
		rm_checks()
	catch(var/exception/e)
		rm_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = rm_failures, "runtime_error" = rm_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)


/proc/rm_checks()
	var/obj/structure/workshop_machine/rolling_mill/M = new(locate(5, 5, 1))
	var/obj/item/stack/material/iron/twentyfive/I = new(locate(4, 4, 1))
	var/obj/item/stack/material/steel/twentyfive/S = new(locate(4, 4, 1))
	var/obj/item/stack/material/steel/plain = new(locate(4, 4, 1))
	rm_check(M.takes(I), "the mill takes a preset 25-sheet iron stack")
	rm_check(M.takes(S), "the mill takes a preset 25-sheet steel stack")
	rm_check(M.takes(plain), "the mill still takes ordinary steel")
	rm_check(rolling_mill_stock_type(I) == /obj/item/stack/material/iron, "preset iron counts as iron")
	rm_check(rolling_mill_stock_type(S) == /obj/item/stack/material/steel, "preset steel counts as steel")
	var/obj/item/stack/material/steel/maraging/G = new(locate(4, 4, 1))
	rm_check(!M.takes(G), "special steel grades are still refused")
