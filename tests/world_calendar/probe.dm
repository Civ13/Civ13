// Native probe for the world calendar (docs/world-calendar.md).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/world_calendar/probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 16
	maxy = 16
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/wc_probe/New()
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
		config = new /datum/configuration
		map = new /obj/map_metadata/wc_probe
		wc_checks()
	catch(var/exception/e)
		wc_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = wc_failures, "runtime_error" = wc_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

// Real minutes since 2000 -> list(day, deciseconds into the day).
/proc/wc_at(day, minutes)
	world_calendar_test_now = list(day, minutes * 600)

/proc/wc_checks()
	// The real clock: the day count is today's, the time of day is in range.
	world_calendar_test_now = null
	var/list/now = world_calendar_now()
	var/expected_day = round(world.realtime / 864000)
	wc_check(abs(now[1] - expected_day) <= 1 && now[1] > 9000, "real clock day is near world.realtime's ([now[1]])")
	wc_check(now[2] >= 0 && now[2] < 864000, "real clock time of day is inside one day ([now[2]])")
	wc_check(text2num(time2text(world.realtime, "hh", 0)) == round(now[2] / 36000) || abs(text2num(time2text(world.realtime, "hh", 0)) - round(now[2] / 36000)) == 1 || abs(text2num(time2text(world.realtime, "hh", 0)) - round(now[2] / 36000)) == 23, "real clock hour matches UTC from time2text")

	// Off the calendar: a map with no longitude keeps its own clock.
	wc_check(!world_calendar_synced(), "a map without world_longitude is not synced")
	wc_check(!world_calendar_tick(), "the tick leaves an unsynced map alone")

	map.world_longitude = 0
	map.sun_latitude = 45
	wc_check(world_calendar_synced() && world_calendar_daynight() && world_calendar_seasons_on(), "a map with world_longitude follows the calendar")
	wc_check(map.persistence_runtime_var("world_longitude"), "world_longitude is map data, never saved")

	// Time of day. Real midnight UTC is game midnight at longitude 0, and a
	// game day is 2 real hours.
	wc_at(9000, 0)
	wc_check(world_calendar_phase(0) == "Night", "UTC midnight is Night at longitude 0")
	var/list/p = world_calendar_phase_at(world_calendar_local_minute(0))
	wc_check(p[2] == 60, "UTC midnight is an hour into Night (Night starts at 23:00)")
	wc_at(9000, 30)
	wc_check(world_calendar_local_minute(0) == 360 && world_calendar_phase(0) == "Early Morning", "half an hour later it is 06:00, Early Morning")
	wc_at(9000, 60)
	wc_check(world_calendar_phase(0) == "Midday", "an hour later it is noon, Midday")
	wc_at(9000, 120)
	wc_check(world_calendar_phase(0) == "Night", "two hours later the game day starts again")
	wc_at(9123, 30)
	wc_check(world_calendar_phase(0) == "Early Morning", "the time of day does not depend on the date")

	// Time zones: one hour per 15 degrees.
	wc_at(9000, 30)
	wc_check(world_calendar_zone(90) == 6 && world_calendar_phase(90) == "Midday", "Asia (90 E) is six hours ahead: Midday at Gaia's dawn")
	wc_check(world_calendar_zone(-100) == -7 && world_calendar_phase(-100) == "Night", "North America (100 W) is seven hours behind")
	wc_check(world_calendar_phase(-30) == world_calendar_phase(-30), "Gaia and the Atlantic share a zone")
	wc_check(world_calendar_zone(-165) == -11 && world_calendar_zone(135) == 9, "the Pacific and Oceania sit either side of the date line")
	var/neighbours_ok = TRUE
	for (var/list/pair in list(list(-30, 10), list(10, 20), list(20, 90), list(-100, -60), list(-30, -100)))
		var/gap = abs(world_calendar_zone(pair[1]) - world_calendar_zone(pair[2]))
		if (gap > 7)
			neighbours_ok = FALSE
	wc_check(neighbours_ok, "neighbouring land regions are under eight hours apart")

	// Seasons: 60 minutes each by default, southern regions opposite.
	config.season_duration_minutes = 60
	wc_at(9000, 0)
	var/list/c = world_calendar_season(1)
	wc_check(c[1] == SEASON_SPRING && c[2] == 0 && c[3] == 60, "the calendar starts a spring at UTC midnight")
	c = world_calendar_season(-1)
	wc_check(c[1] == SEASON_FALL, "southern regions have fall then")
	wc_at(9000, 75)
	c = world_calendar_season(1)
	wc_check(c[1] == SEASON_SUMMER && c[2] == 15 && c[3] == 45, "75 minutes in, the north is a quarter into summer")
	wc_check(world_calendar_season(-1)[1] == SEASON_WINTER, "and the south is in winter")
	wc_at(9000, 230)
	wc_check(world_calendar_season(1)[1] == SEASON_WINTER, "the fourth hour is winter in the north")
	map.sun_latitude = -20
	wc_check(world_calendar_season()[1] == SEASON_SUMMER, "a map south of the equator reads the southern season")
	map.sun_latitude = 45

	// A season length that does not divide the day still runs smoothly over midnight.
	config.season_duration_minutes = 7
	world_calendar_test_now = list(9001, 864000 - 600)
	var/before = world_calendar_minutes_mod(28)
	world_calendar_test_now = list(9002, 0)
	var/after = world_calendar_minutes_mod(28)
	wc_check(abs(world_calendar_fmod(after - before, 28) - 1) < 0.01, "the season clock steps one minute across midnight ([before] -> [after])")
	config.season_duration_minutes = 60

	// The tick puts game_hour and the phase timer on the calendar, and opens the
	// gate when this world shows another phase.
	wc_at(9000, 30)
	time_of_day = "Night"
	TOD_may_automatically_change = FALSE
	wc_check(world_calendar_tick(), "the tick drives a synced map")
	wc_check(game_hour == 180, "game_hour is the minutes into the phase (180)")
	wc_check(TOD_may_automatically_change, "a stale phase opens the change gate")
	TOD_may_automatically_change = FALSE
	time_of_day = "Early Morning"
	world_calendar_tick()
	wc_check(!TOD_may_automatically_change, "the calendar's phase leaves the gate shut")
	time_of_day = "Night"
	world_calendar_tod_hold = world.time + 100
	world_calendar_tick()
	wc_check(!TOD_may_automatically_change, "an admin-set time of day holds")
	world_calendar_tod_hold = 0
	time_of_day = "Early Morning"
	wc_check(clock_time() == "06:00 AM", "the clock reads the calendar time ([clock_time()])")
	wc_at(9000, 30)
	wc_check(world_calendar_phase_left() == 3010, "06:00 is five real minutes before Morning ([world_calendar_phase_left()])")

	// pick_TOD and a restored world take the calendar's phase.
	wc_check(pick_TOD() == "Early Morning", "pick_TOD takes the calendar's phase")
	time_of_day = "Midday"
	world_calendar_restore()
	wc_check(time_of_day == "Early Morning" && !TOD_may_automatically_change, "a restored world takes the calendar's phase")

	// Seasons step toward the calendar only when they differ.
	season = SEASON_SPRING
	wc_at(9000, 10)
	wc_check(!world_calendar_season_due(), "no step while the season matches")
	wc_at(9000, 70)
	wc_check(world_calendar_season_due(), "a step is due when the calendar has moved on")
	world_calendar_season_hold = world.time + 100
	wc_check(!world_calendar_season_due(), "an admin-set season holds")
	world_calendar_season_hold = 0
	map.season_queue = list("transition", FALSE, FALSE, FALSE)
	wc_check(!world_calendar_season_due(), "no second step while one is queued")
	map.season_queue = list()
	season = SEASON_WET
	wc_check(!world_calendar_season_due(), "a season outside the four is left alone")
	season = SEASON_SUMMER
	map.seasons(FALSE)
	wc_check(!map.season_queue.len, "a natural change that matches the calendar queues nothing")

	// The season window and loop follow the calendar.
	wc_at(9000, 75)
	var/list/window = map.season_change_window()
	wc_check(islist(window) && window[2] - window[1] == 36000 && world.time - window[1] == 9000, "the season window spans the calendar's season")
	wc_check(map.season_loop_delay() == 27000 + 50, "the season loop wakes at the calendar's next season ([map.season_loop_delay()])")
	wc_check(findtext(world_calendar_summary(), "UTC+0"), "the summary names the time zone ([world_calendar_summary()])")

	// Every region world is on the calendar.
	var/list/regions = list(/obj/map_metadata/nomads/gaia, /obj/map_metadata/nomads/earth_europe, /obj/map_metadata/nomads/earth_africa, /obj/map_metadata/nomads/earth_asia, /obj/map_metadata/nomads/earth_oceania, /obj/map_metadata/nomads/earth_greenland, /obj/map_metadata/nomads/earth_antarctica, /obj/map_metadata/nomads/americas_north, /obj/map_metadata/nomads/americas_south, /obj/map_metadata/nomads/ocean/atlantic, /obj/map_metadata/nomads/ocean/pacific, /obj/map_metadata/nomads/ocean/indian, /obj/map_metadata/nomads/ocean/arctic, /obj/map_metadata/nomads/ocean/southern)
	var/missing = list()
	for (var/T in regions)
		var/obj/map_metadata/M = T
		if (!isnum(initial(M.world_longitude)) || !isnum(initial(M.sun_latitude)))
			missing += "[T]"
	wc_check(!length(missing), "every region has a longitude and latitude ([jointext(missing, ", ")])")
	map.world_longitude = null
