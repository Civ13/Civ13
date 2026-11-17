// Native probe of code/game/objects/map_metadata/nomads/newcomer_start.dm,
// included by tests/ecology_spawning/run_linux.py, never by the game DME.
/world
	hub = ""
	hub_password = ""
	maxx = 220
	maxy = 220
	maxz = 1
	turf = /turf/floor/grass
	area = /area/start_probe
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/client/New()
	del(src)
	return
/area/start_probe
	climate = "temperate"
/obj/map_metadata/nomads/start_probe
	new_player_start_z = 1
/obj/map_metadata/nomads/start_probe/New()
	map = src
/mob/living/human/start_tester/New()
	return
var/start_failures = 0
var/start_runtime_error = FALSE
/proc/start_check(condition, label)
	if (!condition)
		start_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	start_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		var/obj/map_metadata/nomads/start_probe/M = new
		start_check(M.new_player_has_exit(locate(110, 110, 1)), "the probe land passes the usual safe-start checks")
		var/list/hosts = list()
		for (var/spot in list(list(100, 100), list(105, 100), list(100, 108), list(30, 30)))
			hosts += new /mob/living/human/start_tester(locate(spot[1], spot[2], 1))
		var/mob/living/human/centre = M.newcomer_gathering(hosts)
		start_check(centre && get_dist(centre, locate(100, 100, 1)) <= 8, "the largest group is chosen, not the lone wanderer")
		start_check(isnull(M.newcomer_gathering(list())), "nobody about means no gathering")
		var/turf/camp = locate(100, 100, 1)
		var/in_band = TRUE
		var/found = 0
		for (var/i in 1 to 200)
			var/turf/T = M.newcomer_ground_near(camp)
			if (!T)
				continue
			found++
			var/away = sqrt((T.x - camp.x) ** 2 + (T.y - camp.y) ** 2)
			if (away < 39 || away > 81 || !M.new_player_has_exit(T))
				in_band = FALSE
		start_check(found == 200 && in_band, "every start is a safe tile 40 to 80 tiles from the group ([found] of 200 found)")
		for (var/turf/T in block(locate(1, 1, 1), locate(220, 220, 1)))
			if (get_dist(T, camp) <= 90 && get_dist(T, camp) >= 30)
				T.density = TRUE
		start_check(isnull(M.newcomer_ground_near(camp)), "no safe tile in the band gives no start, so the random pick applies")
		start_check(isnull(M.newcomer_ground_near(null)), "no centre gives no start")
		start_check(isnull(M.pick_newcomer_ground(null)), "without a new account there is no special start")
		start_check(!M.newcomer_hosts().len, "people without a connection are not hosts")
	catch(var/exception/e)
		start_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = start_failures, "runtime_error" = start_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)
