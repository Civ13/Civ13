// Native probe: wolf cubs neither conceive nor sire (issue 6942).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/wolf_cubs/probe.dm
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
/obj/map_metadata/wolf_probe/New()
	return
var/wc_failures = 0
var/wc_runtime_error = FALSE
/proc/wc_check(condition, label)
	if (!condition)
		wc_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	wc_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		map = new /obj/map_metadata/wolf_probe
		wc_checks()
	catch(var/exception/e)
		wc_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = wc_failures, "runtime_error" = wc_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/wc_pair(x, she_cub, male_cub)
	var/mob/living/simple_animal/hostile/wolf/female/F = new(locate(x, 4, 1))
	var/mob/living/simple_animal/hostile/wolf/M = new(locate(x + 1, 4, 1))
	F.cub = she_cub
	M.cub = male_cub
	F.growing = TRUE // keep the 4500-tick growth timer out of the probe
	M.growing = TRUE
	F.stat = CONSCIOUS
	M.stat = CONSCIOUS
	F.pregnant = FALSE
	F.following_mob = M // skip wandering behaviour this tick
	return F

/proc/wc_checks()
	var/mob/living/simple_animal/hostile/wolf/female/adult = wc_pair(2, FALSE, FALSE)
	adult.Life()
	wc_check(adult.pregnant, "an adult she-wolf beside an adult male conceives")
	var/mob/living/simple_animal/hostile/wolf/female/young = wc_pair(10, TRUE, FALSE)
	young.Life()
	wc_check(!young.pregnant, "a female cub does not conceive")
	var/mob/living/simple_animal/hostile/wolf/female/with_cub = wc_pair(18, FALSE, TRUE)
	with_cub.Life()
	wc_check(!with_cub.pregnant, "a male cub does not sire")
