// Native probe for the wind field (docs/weather-wind.md).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/weather_wind/probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 96
	maxy = 64
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/ww_probe/New()
	return
/area/caribbean/ww_probe
var/ww_failures = 0
var/ww_runtime_error = FALSE
/proc/ww_check(condition, label)
	if (!condition)
		ww_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	ww_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		map = new /obj/map_metadata/ww_probe
		ww_checks()
	catch(var/exception/e)
		ww_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = ww_failures, "runtime_error" = ww_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/ww_area(climate, x1, x2)
	var/area/caribbean/ww_probe/A = new
	A.climate = climate
	A.location = AREA_OUTSIDE
	for (var/turf/T in block(locate(x1, 1, 1), locate(x2, world.maxy, 1)))
		A.contents += T
	return A

// The wind in a cell, by column and row from 0.
/proc/ww_cell(col, row)
	var/i = weather_air.index(col, row)
	return list(weather_air.wind_x[i], weather_air.wind_y[i])

/proc/ww_speed(list/v)
	return sqrt(v[1] * v[1] + v[2] * v[2])

/proc/ww_reset()
	weather_air = null
	weather_centres_clear()
	weather_systems_clear()
	weather_storm_count = 0
	return weather_air_grid()

/proc/ww_checks()
	season = "SPRING"
	time_of_day = "Morning"
	map.winddirection = "West"
	map.windspeedvar = 2
	map.valid_weather_types = list(WEATHER_NONE, WEATHER_WET, WEATHER_EXTREME)
	ww_area("temperate", 1, 96)
	var/turf/field = locate(40, 30, 1)

	// Scales.
	ww_check(weather_beaufort(0.3) == 0 && weather_beaufort(5) == 3 && weather_beaufort(18) == 8 && weather_beaufort(40) == 12, "Beaufort forces from m/s")
	var/scale_ok = TRUE
	for (var/s = 0, s <= 4, s++)
		if (weather_wind_strength(weather_wind_ms(s)) != s)
			scale_ok = FALSE
	ww_check(scale_ok, "each map strength converts to m/s and back")
	ww_check(weather_wind_dir_from_vector(5, 0) == WEST && weather_wind_dir_from_vector(0, -5) == NORTH && weather_wind_dir_from_vector(-3, -3) == NORTHEAST && weather_wind_dir_from_vector(3, 3) == SOUTHWEST, "a wind is named for where it blows from")
	ww_check(weather_wind_heading(NORTHEAST) == "north-east" && weather_wind_heading(SOUTH) == "south", "headings read as words")

	// Before the air grid exists, readers give the map's wind.
	weather_air = null
	ww_check(weather_wind_at(field) == 2 && weather_wind_dir_at(field) == WEST, "with no grid the map's wind holds")

	// Flat, dry, even air: every cell carries exactly the map's wind.
	var/datum/weather_air_grid/G = ww_reset()
	var/same = TRUE
	for (var/s = 0, s <= 4, s++)
		map.windspeedvar = s
		G.settle(TRUE)
		if (weather_wind_at(field) != s)
			same = FALSE
	ww_check(same, "on flat dry ground old readers see the map's strength 0 to 4")
	map.windspeedvar = 2
	map.winddirection = "Northeast"
	G.settle(TRUE)
	ww_check(weather_wind_dir_at(field) == NORTHEAST, "a diagonal map wind reaches the ground ([weather_wind_dir_at(field)])")
	ww_check(abs(ww_speed(weather_wind_vector_at(field)) - 6) < 0.01, "at the same speed as a straight one ([ww_speed(weather_wind_vector_at(field))] m/s)")
	var/obj/structure/weather_vane/vane = new(field)
	ww_check(vane.icon_state == "weather_vane_northeast" && ("weather_vane_northeast" in icon_states(vane.icon)), "a vane points into a north-east wind ([vane.icon_state])")
	qdel(vane)
	var/datum/weather_system/S = weather_system_spawn(WEATHER_SYSTEM_STORM, FALSE, 48, 32)
	ww_check(abs(sqrt(S.vel_x * S.vel_x + S.vel_y * S.vel_y) - weather_wind_speed()) < 0.0001 && S.vel_x < 0 && S.vel_y < 0, "a diagonal wind carries a storm south-west no faster than a straight one")
	weather_systems_clear()
	weather_storm_count = 0

	// Eight headings, an eighth of a turn at a time.
	var/list/compass = list("North", "Northeast", "East", "Southeast", "South", "Southwest", "West", "Northwest")
	var/seen = list()
	var/step_ok = TRUE
	var/heading = "North"
	for (var/i = 1, i <= 600, i++)
		var/next = weather_veer(heading)
		var/gap = abs(compass.Find(next) - compass.Find(heading))
		if (gap > 1 && gap != 7)
			step_ok = FALSE
		seen[next] = TRUE
		heading = next
	ww_check(step_ok && length(seen) == 8, "the wind veers through all eight headings an eighth at a time")

	// Round a low the wind circles it: anticlockwise in the north.
	map.winddirection = "West"
	map.windspeedvar = 0
	G = ww_reset()
	var/datum/weather_centre/L = weather_centre_spawn(WEATHER_CENTRE_LOW, 48, 32)
	L.vel_x = 0
	L.vel_y = 0
	L.born = world.time - 6000
	L.lifetime = 30000
	L.depth = 20
	L.radius = 40
	G.settle(TRUE)
	var/list/east = ww_cell(4, 2) // x 72, east of the low
	var/list/west = ww_cell(1, 2) // x 24
	ww_check(east[2] > 1 && west[2] < -1, "north of the equator air goes north east of a low and south west of it ([east[2]], [west[2]])")
	ww_check(east[1] < 0 && west[1] > 0, "and spills in toward its heart")
	ww_check(weather_wind_at(locate(72, 40, 1)) >= 2, "a 20 hPa low brings a fresh wind round it ([weather_wind_at(locate(72, 40, 1))])")
	map.sun_latitude = -30
	G.settle(TRUE)
	east = ww_cell(4, 2)
	ww_check(east[2] < -1, "south of the equator it turns the other way ([east[2]])")
	map.sun_latitude = null
	weather_centres_clear()
	G.settle(TRUE)
	ww_check(ww_speed(ww_cell(4, 2)) < 0.01, "with the low gone and no map wind, the air is calm")

	// Sea and land breezes.
	for (var/row = 0, row < G.rows, row++)
		G.water[G.index(0, row)] = TRUE
	G.survey_wind()
	time_of_day = "Afternoon"
	G.settle(TRUE)
	var/list/shore = ww_cell(1, 1)
	ww_check(shore[1] > 2 && ww_cell(0, 1)[1] > 2, "on a sunny afternoon the breeze blows in off the water ([shore[1]] m/s)")
	ww_check(ww_speed(ww_cell(4, 1)) < 0.01, "inland, away from the shore, it does not reach")
	time_of_day = "Dark Night"
	G.settle(TRUE)
	ww_check(ww_cell(1, 1)[1] < -1, "on a clear night it drains back out to the water ([ww_cell(1, 1)[1]])")
	for (var/i = 1, i <= G.cloud.len, i++)
		G.cloud[i] = 1
	G.settle_wind(TRUE)
	ww_check(abs(ww_cell(1, 1)[1]) < 0.01, "under overcast the breezes die")
	time_of_day = "Morning"
	for (var/row = 0, row < G.rows, row++)
		G.water[G.index(0, row)] = FALSE
	G.survey_wind()

	// Hills and valleys: a valley runs north to south down columns 2 and 3.
	var/list/profile = list(6, 3, 0, 0, 3, 6)
	for (var/row = 0, row < G.rows, row++)
		for (var/col = 0, col < G.cols, col++)
			G.heights[G.index(col, row)] = profile[col + 1]
	G.survey_wind()
	ww_check(G.has_heights, "a map with hills notices them")
	map.windspeedvar = 2
	map.winddirection = "West"
	G.settle(TRUE)
	ww_check(ww_speed(ww_cell(2, 1)) < ww_speed(ww_cell(0, 1)), "the valley floor is sheltered and the ridge exposed ([ww_speed(ww_cell(2, 1))] vs [ww_speed(ww_cell(0, 1))])")
	map.winddirection = "Southwest"
	G.settle(TRUE)
	var/list/valley = ww_cell(2, 1)
	ww_check(abs(valley[2]) > abs(valley[1]) * 1.5, "the valley turns a slanting wind along its floor ([valley[1]], [valley[2]])")
	map.windspeedvar = 0
	time_of_day = "Dark Night"
	for (var/i = 1, i <= G.cloud.len, i++)
		G.cloud[i] = 0
	G.settle_wind(TRUE)
	ww_check(ww_cell(1, 1)[1] > 1 && ww_cell(4, 1)[1] < -1, "on a clear night cold air slides down both slopes into the valley")
	time_of_day = "Midday"
	G.settle_wind(TRUE)
	ww_check(ww_speed(ww_cell(1, 1)) < 0.01, "and by day it does not")

	// The wind settles over a few ticks rather than jumping.
	map.windspeedvar = 3
	map.winddirection = "East"
	G.settle()
	var/first = ww_speed(ww_cell(0, 1))
	for (var/i = 1, i <= 30, i++)
		G.settle()
	ww_check(first > 0 && first < ww_speed(ww_cell(0, 1)) * 0.5, "a new wind builds over a few ticks")
	ww_check(weather_wind_dir_at(locate(8, 24, 1)) == EAST, "and comes from its new heading")

	// The Admin Map gets each cell's wind.
	var/list/data = weather_air_map_data()
	ww_check(data.len >= 9 && length(data[8]) == G.cols * G.rows && length(data[9]) == G.cols * G.rows, "the map data carries each cell's wind")
