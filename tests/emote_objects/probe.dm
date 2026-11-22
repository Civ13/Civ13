// Native probe: an emote reaches the objects in view in one deferred pass.
// Run: python3 tests/ecology_spawning/run_linux.py . tests/emote_objects/probe.dm
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
/obj/map_metadata/eo_probe/New()
	return

var/eo_failures = 0
var/eo_runtime_error = FALSE
/proc/eo_check(condition, label)
	if (!condition)
		eo_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	eo_runtime_error = TRUE
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
		map = new /obj/map_metadata/eo_probe
		eo_checks()
	catch(var/exception/e)
		eo_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = eo_failures, "runtime_error" = eo_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

var/eo_seen = 0
var/eo_seen_deleted = 0
/obj/eo_watcher
	name = "watcher"
/obj/eo_watcher/see_emote(mob/M, text, emote_type)
	if (QDELETED(src))
		eo_seen_deleted++
	else
		eo_seen++

/proc/eo_checks()
	var/mob/living/human/C = new(locate(5, 5, 1))
	var/list/watchers = list()
	for (var/i = 1, i <= 40, i++)
		watchers += new /obj/eo_watcher(locate(6, 5, 1))
	var/obj/eo_watcher/gone = watchers[1]
	C.custom_emote(1, "stretches.")
	qdel(gone)
	eo_check(!eo_seen, "objects are told after the emote returns, not during it")
	sleep(1)
	eo_check(eo_seen == 39, "every remaining object in view sees the emote once ([eo_seen])")
	eo_check(!eo_seen_deleted, "an object deleted before the pass is skipped ([eo_seen_deleted])")
	eo_seen = 0
	C.custom_emote(2, "purrs.")
	sleep(1)
	eo_check(eo_seen == 39, "an audible emote reaches the same objects ([eo_seen])")
