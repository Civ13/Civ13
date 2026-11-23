// Native probe: a dead animal takes no rider (issue 6915).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/dead_mount/probe.dm
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
/obj/map_metadata/dm_probe/New()
	return

var/dm_failures = 0
var/dm_runtime_error = FALSE
/proc/dm_check(condition, label)
	if (!condition)
		dm_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	dm_runtime_error = TRUE
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
		map = new /obj/map_metadata/dm_probe
		dm_checks()
	catch(var/exception/e)
		dm_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = dm_failures, "runtime_error" = dm_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/dm_checks()
	var/mob/living/simple_animal/horse/live = new(locate(5, 5, 1))
	var/mob/living/human/A = new(locate(5, 5, 1))
	dm_check(live.can_ride, "an ordinary horse is rideable")
	dm_check(live.take_rider(A), "a living horse takes a rider")
	dm_check(live.rider == A && A.riding_mob == live, "the rider is seated")

	var/mob/living/simple_animal/horse/corpse = new(locate(7, 7, 1))
	var/mob/living/human/B = new(locate(7, 7, 1))
	corpse.stat = DEAD
	dm_check(!corpse.take_rider(B), "a dead horse refuses a rider")
	dm_check(isnull(corpse.rider) && isnull(B.riding_mob) && !B.riding, "nobody is seated on the corpse")
	corpse.MouseDrop_T(B, B)
	sleep(1)
	dm_check(isnull(corpse.rider) && isnull(B.riding_mob), "dragging yourself onto a corpse does not mount it")
