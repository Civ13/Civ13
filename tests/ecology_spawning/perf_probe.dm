/world
	hub = ""
	hub_password = ""
	maxx = 300
	maxy = 300
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/eco_perf/New()
	return
/datum/eco_fake_client
var/perf_failures = 0
var/perf_runtime = FALSE
/world/Error(exception/e)
	perf_runtime = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	var/list/report = list()
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/eco_perf
		var/area/A = get_area(locate(1, 1, 1))
		A.location = AREA_OUTSIDE
		A.climate = "temperate"
		for (var/turf/T in block(locate(1, 1, 1), locate(world.maxx, world.maxy, 1)))
			T.ChangeTurf(/turf/floor/grass, FALSE, FALSE)
		// handle_ai() idles when nobody is connected; a typed loop over clients skips this stand-in.
		clients += new /datum/eco_fake_client
		var/list/kinds = list(/mob/living/simple_animal/deer/male, /mob/living/simple_animal/deer/female, /mob/living/simple_animal/sheep, /mob/living/simple_animal/sheep/female, /mob/living/simple_animal/rabbit, /mob/living/simple_animal/boar_boar, /mob/living/simple_animal/turkey_f, /mob/living/simple_animal/goat/female, /mob/living/simple_animal/cattle/cow, /mob/living/simple_animal/horse, /mob/living/simple_animal/hostile/wolf, /mob/living/simple_animal/hostile/fox)
		for (var/n in list(100, 300, 600, 900))
			report["[n]"] = perf_run(n, kinds)
		for (var/n in list(600, 900))
			report["[n]_rest_nobody_near"] = perf_run(n, kinds, TRUE)
			report["[n]_rest_one_player_mid"] = perf_run(n, kinds, TRUE, list(locate(150, 150, 1)))
	catch(var/exception/e)
		perf_failures++
		world.log << "exception [e] [e.file]:[e.line]"
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = perf_failures, "runtime_error" = perf_runtime, "report" = report)), "result.json")
	del(world)

/proc/perf_run(n, list/kinds, use_rest = FALSE, list/observers = null)
	var/list/animals = list()
	for (var/i = 1, i <= n, i++)
		var/path = kinds[(i % kinds.len) + 1]
		animals += new path(locate(rand(5, world.maxx - 5), rand(5, world.maxy - 5), 1))
	var/rounds = 40
	var/started = world.timeofday
	var/lives = 0
	for (var/r = 1, r <= rounds, r++)
		if (use_rest)
			ecology_advance_rest_phase()
			ecology_refresh_observers()
			ecology_observer_turfs = observers ? observers : list()
		for (var/mob/living/simple_animal/S in animals)
			if (use_rest && ecology_animal_resting(S))
				continue
			S.Life()
			lives++
	var/elapsed_ms = (world.timeofday - started) * 100
	var/per_life_us = elapsed_ms * 1000 / (rounds * n)
	var/per_second_ms = per_life_us * n / 1000
	world.log << "PERF animals=[n] rest=[use_rest] observers=[observers ? observers.len : 0] rounds=[rounds] lives_run=[lives] total_ms=[elapsed_ms] per_animal_second_us=[per_life_us] mob_process_ms_per_second=[per_second_ms]"
	for (var/mob/M in animals)
		qdel(M)
	return list("animals" = n, "lives_run" = lives, "ms_per_second" = per_second_ms)
