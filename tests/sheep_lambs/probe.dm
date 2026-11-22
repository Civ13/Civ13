// Native probe: lambs neither conceive nor sire (issue 6847).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/sheep_lambs/probe.dm
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
/obj/map_metadata/sheep_probe/New()
	return
var/sl_failures = 0
var/sl_runtime_error = FALSE
/proc/sl_check(condition, label)
	if (!condition)
		sl_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	sl_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		map = new /obj/map_metadata/sheep_probe
		sl_checks()
	catch(var/exception/e)
		sl_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = sl_failures, "runtime_error" = sl_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/sl_pair(x, ewe_lamb, ram_lamb)
	var/mob/living/simple_animal/sheep/female/E = new(locate(x, 4, 1))
	var/mob/living/simple_animal/sheep/R = new(locate(x + 1, 4, 1))
	E.lamb = ewe_lamb
	R.lamb = ram_lamb
	E.stat = CONSCIOUS
	R.stat = CONSCIOUS
	E.pregnant = FALSE
	E.overpopulationCountdown = 0
	return E

/proc/sl_checks()
	var/mob/living/simple_animal/sheep/female/adult = sl_pair(2, FALSE, FALSE)
	adult.Life()
	sl_check(adult.pregnant, "an adult ewe beside an adult ram conceives")
	var/mob/living/simple_animal/sheep/female/young_ewe = sl_pair(10, TRUE, FALSE)
	young_ewe.Life()
	sl_check(!young_ewe.pregnant, "a ewe lamb does not conceive")
	var/mob/living/simple_animal/sheep/female/with_ram_lamb = sl_pair(18, FALSE, TRUE)
	with_ram_lamb.Life()
	sl_check(!with_ram_lamb.pregnant, "a ram lamb does not sire")
