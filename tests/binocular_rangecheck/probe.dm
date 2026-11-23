// Native probe: range-check locks are runtime-only and never saved (issue 6983).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/binocular_rangecheck/probe.dm
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
/obj/map_metadata/binocular_probe/New()
	return
var/br_failures = 0
var/br_runtime_error = FALSE
/proc/br_check(condition, label)
	if (!condition)
		br_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	br_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		map = new /obj/map_metadata/binocular_probe
		br_checks()
	catch(var/exception/e)
		br_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = br_failures, "runtime_error" = br_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/br_checks()
	var/list/kinds = list(/obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars, /obj/item/weapon/attachment/scope/adjustable/binoculars/periscope, /obj/item/weapon/attachment/scope/adjustable/binoculars/laser_designator)
	for (var/kind in kinds)
		var/obj/item/I = new kind(locate(4, 4, 1))
		I:checking = TRUE
		br_check(I.persistence_runtime_var("checking"), "[kind] keeps its range-check lock out of saves")
		br_check(I:checking == TRUE, "[kind] still holds the live lock")
