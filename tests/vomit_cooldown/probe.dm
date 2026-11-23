// Native probe: the vomit cooldown never saves or restores (issue 6892).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/vomit_cooldown/probe.dm
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
/obj/map_metadata/vc_probe/New()
	return

var/vc_failures = 0
var/vc_runtime_error = FALSE
/proc/vc_check(condition, label)
	if (!condition)
		vc_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	vc_runtime_error = TRUE
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
		map = new /obj/map_metadata/vc_probe
		vc_checks()
	catch(var/exception/e)
		vc_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = vc_failures, "runtime_error" = vc_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/vc_checks()
	var/mob/living/human/H = new(locate(2, 2, 1))
	H.lastpuke = TRUE
	vc_check(H.persistence_runtime_var("lastpuke"), "the vomit cooldown is runtime state, left out of saves and imports")
	vc_check(!H.persistence_runtime_var("nutrition"), "control: nutrition still saves")
	var/list/saved = H.get_saved_vars()
	vc_check(!("lastpuke" in saved), "an active vomit cooldown is not in the human's saved fields")
