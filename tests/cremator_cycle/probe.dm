// Native probe: a cremator stays running and locked while a later living
// occupant burns, after an earlier dead occupant is processed (#6273).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/cremator_cycle/probe.dm
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
/obj/map_metadata/cr_probe/New()
	return

var/cr_failures = 0
var/cr_runtime_error = FALSE
/proc/cr_check(condition, label)
	if (!condition)
		cr_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	cr_runtime_error = TRUE
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
		map = new /obj/map_metadata/cr_probe
		cr_cycle_checks()
	catch(var/exception/e)
		cr_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = cr_failures, "runtime_error" = cr_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/cr_cycle_checks()
	var/obj/structure/cremator/C = new(locate(5, 5, 1))
	var/mob/living/human/operator = new(locate(4, 4, 1))
	var/mob/living/human/corpse = new(locate(6, 6, 1))
	var/mob/living/human/victim = new(locate(6, 6, 1))
	corpse.stat = DEAD
	corpse.forceMove(C)
	victim.forceMove(C)
	spawn(0)
		C.cremate(operator)
	// The corpse is processed at once; the victim then burns, sleeping 3s per step.
	sleep(15)
	cr_check(!(corpse in C.contents), "the dead occupant is processed first")
	cr_check(victim in C.contents, "the living occupant is still burning")
	cr_check(C.cremating, "the cremator stays running while a later occupant burns")
	cr_check(C.locked, "the cremator stays locked while a later occupant burns")
	// Ending the burn by taking the occupant out finishes the cycle normally.
	victim.forceMove(locate(7, 7, 1))
	var/waited = 0
	while (C.cremating && waited < 200)
		sleep(5)
		waited += 5
	cr_check(!C.cremating && !C.locked, "the cycle unlocks once every occupant is done")
