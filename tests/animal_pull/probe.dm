// Native probe: a pulled animal keeps sliding on the free-movement pull rope.
// Run: python3 tests/ecology_spawning/run_linux.py . tests/animal_pull/probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 20
	maxy = 20
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/animal_pull_probe/New()
	return
/mob/living/human/animal_pull_probe/New()
	return
/mob/living/human/animal_pull_probe/update_icons()
	return
/mob/living/simple_animal/deer/animal_pull_probe/New()
	return
var/pull_failures = 0
var/pull_runtime_error = FALSE
/proc/pull_check(condition, label)
	if (!condition)
		pull_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	pull_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/animal_pull_probe
		pull_checks()
	catch(var/exception/e)
		pull_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = pull_failures, "runtime_error" = pull_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/pull_px(atom/movable/M)
	return M.x * 32 + M.step_x

/proc/pull_checks()
	for (var/turf/T in block(locate(1, 1, 1), locate(20, 20, 1)))
		T.ChangeTurf(/turf/floor/grass, FALSE, FALSE)
	var/mob/living/human/animal_pull_probe/H = new(locate(12, 10, 1))
	var/mob/living/simple_animal/deer/animal_pull_probe/D = new(locate(10, 10, 1))
	D.stat = DEAD
	D.lying = TRUE
	// A dead animal left a few pixels off its tile, as free-moving wildlife is.
	D.step_x = 6
	D.npc_subtile_offset_owned = TRUE
	var/start = pull_px(D)
	pull_check(!H.human_subtile_pull_shift(D, 4, 0), "an unpulled animal keeps its owned offset")
	pull_check(pull_px(D) == start, "an unpulled animal did not move")
	H.pulling = D
	D.pulledby = H
	pull_check(H.human_subtile_pull_shift(D, 4, 0), "the first rope slide moves the pulled animal")
	pull_check(D.npc_subtile_offset_owned, "the slide claims the offset")
	pull_check(H.human_subtile_pull_shift(D, 4, 0), "the next rope slide still moves it")
	pull_check(H.human_subtile_pull_shift(D, 4, 0), "and the one after")
	pull_check(pull_px(D) == start + 12, "it followed 12px in three slides")
