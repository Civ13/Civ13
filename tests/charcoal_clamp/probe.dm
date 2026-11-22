// Native probe: charcoal clamp output survives merging into a pile (issue 6863).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/charcoal_clamp/probe.dm
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
/obj/map_metadata/charcoal_probe/New()
	return
var/cc_failures = 0
var/cc_runtime_error = FALSE
/proc/cc_check(condition, label)
	if (!condition)
		cc_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	cc_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		map = new /obj/map_metadata/charcoal_probe
		cc_checks()
	catch(var/exception/e)
		cc_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = cc_failures, "runtime_error" = cc_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/cc_total(turf/T, path)
	. = 0
	for (var/obj/item/stack/S in T)
		if (istype(S, path) && !QDELETED(S))
			. += S.amount

/proc/cc_checks()
	var/turf/T1 = locate(3, 4, 1)
	var/obj/item/stack/ore/charcoal/pile = new(T1)
	pile.amount = 5
	var/obj/structure/charcoal_clamp/C1 = new(T1)
	C1.wood_charge = 20
	C1.burning = TRUE
	var/lumps = C1.charcoal_yield()
	C1.finish_burn()
	cc_check(lumps == 10, "twenty logs yield ten lumps")
	cc_check(cc_total(T1, /obj/item/stack/ore/charcoal) == 15, "the burn adds its whole yield to an existing charcoal pile")
	var/turf/T2 = locate(10, 4, 1)
	var/obj/structure/charcoal_clamp/C2 = new(T2)
	C2.wood_charge = 20
	C2.burning = TRUE
	C2.finish_burn()
	cc_check(cc_total(T2, /obj/item/stack/ore/charcoal) == 10, "the burn on an empty turf leaves the whole yield")
	var/turf/T3 = locate(17, 4, 1)
	var/obj/item/stack/material/wood/logs = new(T3)
	logs.amount = 3
	var/obj/structure/charcoal_clamp/C3 = new(T3)
	C3.wood_charge = 12
	new /obj/item/stack/material/wood(T3, C3.wood_charge)
	C3.wood_charge = 0
	cc_check(cc_total(T3, /obj/item/stack/material/wood) == 15, "unburnt logs given back by amount join a log pile whole")
