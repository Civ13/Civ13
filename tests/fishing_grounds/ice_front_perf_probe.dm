// Native cost measurement for the ice front (code/modules/1713/ice_dynamics.dm),
// included by tests/ecology_spawning/run_linux.py, never by the game DME.
// A 500x200 sheet of water, more water than the Gaia surface has (about
// 92,000 tiles), with a shore down its west side. It times full sweeps in a
// thaw (nothing to do), in hard frost (the front moving) and with ice over
// half of it melting, and writes per-step tick usage to the log.
//   python3 tests/ecology_spawning/run_linux.py . tests/fishing_grounds/ice_front_perf_probe.dm 900
/world
	hub = ""
	hub_password = ""
	maxx = 500
	maxy = 200
	maxz = 1
	turf = /turf/floor/beach/water
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/ice_front_perf/New()
	map = src
	persistence = TRUE
/area/caribbean/ice_front_perf
var/ifp_failures = 0
var/ifp_runtime_error = FALSE
/proc/ifp_check(condition, label)
	if (!condition)
		ifp_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	ifp_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	sleep(1)
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		new /obj/map_metadata/ice_front_perf
		ifp_checks()
	catch(var/exception/e)
		ifp_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = ifp_failures, "runtime_error" = ifp_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

// One full sweep, a step per tick as the game runs it. Returns
// list(steps, mean tick usage per step, worst, tiles changed).
/proc/ifp_sweep(label)
	ice_front_wrap()
	var/sweeps = ice_front_sweeps
	var/steps = 0
	var/total = 0
	var/worst = 0
	var/changed = 0
	while (ice_front_sweeps == sweeps && steps < 1000)
		sleep(world.tick_lag)
		if (ice_front_changed)
			changed = ice_front_changed.len
		var/before = world.tick_usage
		ice_front_step()
		var/used = world.tick_usage - before
		total += used
		worst = max(worst, used)
		steps++
	world.log << "[label]: [steps] steps over [water_turf_list.len] water tiles, mean [round(total / max(1, steps), 0.1)]% of a tick per step, worst [round(worst, 0.1)]%, [changed] tiles changed in the sweep"
	return list(steps, total / max(1, steps), worst, changed)

/proc/ifp_area(climate)
	var/area/caribbean/ice_front_perf/A = new
	A.climate = climate
	A.location = AREA_OUTSIDE
	for (var/turf/T in block(locate(1, 1, 1), locate(world.maxx, world.maxy, 1)))
		A.contents += T
	return A

/proc/ifp_checks()
	// The shore: the west column is land.
	for (var/y = 1 to world.maxy)
		var/turf/T = locate(1, y, 1)
		T.ChangeTurf(/turf/floor/grass, FALSE, FALSE)
	ifp_check(water_turf_list.len >= 90000, "the sheet holds [water_turf_list.len] water tiles")
	season = "SUMMER"
	time_of_day = "Midday"
	var/area/A = ifp_area("jungle")
	var/list/warm = ifp_sweep("thaw, all open water")
	ifp_check(warm[4] == 0, "nothing changes in warm air")
	A.climate = "tundra"
	season = "WINTER"
	time_of_day = "Night"
	var/list/cold = ifp_sweep("hard frost, front moving")
	ifp_check(cold[4] > 0 && cold[4] < 2000, "the ice moves out from the shore, at most a tile or so per sweep ([cold[4]])")
	var/list/cold2 = ifp_sweep("hard frost, second sweep")
	// Half the sheet iced over, then a thaw.
	for (var/turf/T in block(locate(2, 1, 1), locate(250, world.maxy, 1)))
		T.ChangeTurf(/turf/floor/beach/water/ice, FALSE, FALSE)
		CHECK_TICK
	A.climate = "jungle"
	season = "SUMMER"
	time_of_day = "Midday"
	var/list/melt = ifp_sweep("thaw, half the sheet iced")
	ifp_check(melt[4] > 0, "the ice melts back from its edges ([melt[4]])")
	for (var/list/L in list(warm, cold, cold2, melt))
		ifp_check(L[2] < 10, "a step stays a small share of a tick ([round(L[2], 0.1)]%)")
	ifp_check(warm[1] >= 100 && warm[1] <= 240, "a sweep of 100,000 tiles takes [warm[1]] steps of 5 s, about [round(warm[1] / 12)] minutes")
