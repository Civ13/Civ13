// Native probe for weather instruments by era (docs/weather-instruments.md).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/weather_instruments/probe.dm
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
/obj/map_metadata/wi_probe/New()
	return
/area/caribbean/wi_probe
var/wi_failures = 0
var/wi_runtime_error = FALSE
/proc/wi_check(condition, label)
	if (!condition)
		wi_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	wi_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	sleep(1)
	try
		config = new
		config.webhook_can_fire = FALSE
		makeDatumRefLists()
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		GLOB.stat_set_event = new
		GLOB.name_set_event = new
		movementMachine = new
		map = new /obj/map_metadata/wi_probe
		wi_checks()
	catch(var/exception/e)
		wi_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = wi_failures, "runtime_error" = wi_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/wi_area(climate, x1, x2, location = AREA_OUTSIDE)
	var/area/caribbean/wi_probe/A = new
	A.climate = climate
	A.location = location
	for (var/turf/T in block(locate(x1, 1, 1), locate(x2, world.maxy, 1)))
		A.contents += T
	return A

// A storm standing still over x, y at full strength.
/proc/wi_storm(x, y, severe = FALSE)
	var/datum/weather_system/S = weather_system_spawn(WEATHER_SYSTEM_STORM, severe, x, y)
	S.origin_x = x
	S.origin_y = y
	S.origin_time = world.time
	S.vel_x = 0
	S.vel_y = 0
	S.radius_x = 30
	S.radius_y = 30
	S.peak = 1
	S.born = world.time - 6000
	S.lifetime = 60000
	weather_sample_time = -1
	return S

/proc/wi_checks()
	season = "SUMMER"
	time_of_day = "Midday"
	map.winddirection = "West"
	map.windspeedvar = 3
	map.valid_weather_types = list(WEATHER_NONE, WEATHER_WET, WEATHER_EXTREME)
	wi_area("temperate", 1, 96)
	wi_area("temperate", 80, 90, AREA_INSIDE)
	weather_centres_clear()
	weather_systems_clear()
	weather_storm_count = 0
	weather_air_grid()
	weather_air.settle(TRUE)
	var/turf/field = locate(20, 32, 1)
	var/turf/hall = locate(85, 32, 1)

	// Words.
	wi_check(weather_beaufort_name(0) == "calm" && weather_beaufort_name(8) == "a gale" && weather_beaufort_name(12) == "a hurricane-force wind", "Beaufort names")
	wi_check(weather_pressure_tendency_word(0.2) == "steady" && weather_pressure_tendency_word(-1) == "falling slowly" && weather_pressure_tendency_word(6) == "rising fast", "tendency words")
	wi_check(weather_minutes_rough(1200) == "within five minutes" && weather_minutes_rough(7800) == "in about 15 minutes", "a barometer rounds to five minutes ([weather_minutes_rough(7800)])")

	// The pressure tendency follows the grid every three minutes.
	var/datum/weather_air_grid/G = weather_air
	G.settle_instruments()
	wi_check(G.pressure_tend.len == G.cols * G.rows && weather_pressure_tendency_at(field) == 0, "the tendency starts steady")
	for (var/i = 1, i <= G.pressure.len, i++)
		G.pressure[i] -= 4
	G.steps = 18
	G.settle_instruments()
	var/tend = weather_pressure_tendency_at(field)
	wi_check(abs(tend + 4) < 0.01, "a 4 hPa drop reads as falling ([tend])")
	wi_check(findtext(barometer_hpa_reading(field), "hPa</b>, falling"), "the barometer reads hPa and the fall ([barometer_hpa_reading(field)])")
	G.steps = 19
	for (var/i = 1, i <= G.pressure.len, i++)
		G.pressure[i] += 4
	G.settle_instruments()
	wi_check(weather_pressure_tendency_at(field) == tend, "between marks the tendency holds")

	// Thermometer: feels-like out in the sun, not indoors.
	var/sunny = thermometer_feels_reading(field)
	wi_check(findtext(sunny, "feel like") || get_temp(field) < 20, "outdoors the thermometer tells what the air feels like ([sunny])")
	wi_check(!findtext(thermometer_feels_reading(hall), "feel like"), "indoors it reads only the air")

	// Hygrometer.
	for (var/i = 1, i <= G.temp.len, i++)
		G.temp[i] = 8
		G.dew[i] = 6
		G.cloud[i] = 0
	time_of_day = "Evening"
	var/hyg = hygrometer_reading(field)
	wi_check(findtext(hyg, "%</b>") && findtext(hyg, "dew will settle"), "a damp clear evening: the hygrometer promises dew ([hyg])")
	for (var/i = 1, i <= G.temp.len, i++)
		G.temp[i] = 2
		G.dew[i] = 0
	hyg = hygrometer_reading(field)
	wi_check(findtext(hyg, "frost"), "a cold one: frost ([hyg])")
	time_of_day = "Midday"
	weather_air.settle(TRUE)

	// The rain gauge fills under a storm, outdoors only, and tips out.
	var/obj/structure/weather_instrument/rain_gauge/out = new(field)
	var/obj/structure/weather_instrument/rain_gauge/under = new(hall)
	wi_check(out in weather_instruments(), "gauges join the instrument list")
	wi_storm(20, 32)
	weather_storm_count = max(weather_storm_count, 1)
	for (var/n = 1, n <= 20, n++)
		weather_instruments_step()
	wi_check(out.rain_mm > 5 && out.icon_state == "rain_gauge_full", "the gauge out of doors fills ([out.rain_mm] mm)")
	wi_check(under.rain_mm == 0, "the gauge under a roof stays dry")
	var/mob/living/human/H = new /mob/living/human(locate(21, 32, 1))
	out.attack_hand(H)
	wi_check(out.rain_mm == 0 && out.icon_state == "rain_gauge", "an empty hand tips it out")
	qdel(under)
	wi_check(!(under in weather_instruments()), "a gauge leaves the list when destroyed")

	// The anemometer.
	var/obj/structure/weather_instrument/anemometer/cups = new(locate(22, 32, 1))
	var/ane = anemometer_reading(cups)
	wi_check(findtext(ane, "m/s</b>") && findtext(ane, "force"), "the anemometer reads m/s and Beaufort ([ane])")
	wi_check(cups.icon_state == "anemometer", "its cups spin in the wind")
	var/obj/structure/weather_instrument/anemometer/shut = new(hall)
	wi_check(shut.icon_state == "anemometer_still" && findtext(anemometer_reading(shut), "under a roof"), "indoors they hang still")

	// The station: readings, a forecast with what falls, and the log.
	var/obj/structure/weather_instrument/station/ST = new(locate(24, 32, 1))
	var/list/lines = weather_station_reading(ST)
	var/all = jointext(lines, " | ")
	wi_check(lines.len >= 5 && findtext(all, "hPa") && findtext(all, "Forecast:"), "the station reads everything ([all])")
	wi_check(findtext(all, "rain") || findtext(all, "snow") || findtext(all, "sleet"), "and names what is falling")
	weather_systems_clear()
	weather_storm_count = 0
	wi_storm(70, 32)
	var/datum/weather_system/S = weather_systems[weather_systems.len]
	S.vel_x = -0.004 // 24 tiles a minute toward the station
	weather_storm_count = 1
	lines = weather_station_reading(ST)
	all = jointext(lines, " | ")
	wi_check(findtext(all, "from the east"), "the station sees a storm coming from the east ([all])")
	var/hpa_line = barometer_hpa_reading(ST)
	ST.weather_tick()
	wi_check(ST.log_lines.len == 1 && findtext(ST.log_lines[1], "Midday") && ST.logged_at == "Midday", "it logs a line when the part of the day begins ([ST.log_lines.len ? ST.log_lines[1] : "none"])")
	ST.weather_tick()
	wi_check(ST.log_lines.len == 1, "but only one a part of the day")
	time_of_day = "Afternoon"
	ST.weather_tick()
	wi_check(ST.log_lines.len == 2, "and the next part of the day gets the next line")
	for (var/n = 1, n <= 20, n++)
		ST.log_lines += "x"
	time_of_day = "Evening"
	ST.weather_tick()
	wi_check(ST.log_lines.len == 12, "the log keeps the last twelve lines")
	wi_check(findtext(hpa_line, "hPa"), "barometer line ([hpa_line])")

	// A low coming in shows in the station's outlook.
	weather_systems_clear()
	weather_storm_count = 0
	var/datum/weather_centre/L = weather_centre_spawn(WEATHER_CENTRE_LOW, 90, 32)
	L.born = world.time - 6000
	L.lifetime = 60000
	L.radius = 60
	L.depth = 20
	L.vel_x = -0.01
	L.vel_y = 0
	var/outlook = weather_station_outlook(ST)
	wi_check(findtext(outlook, "low lies to the east") && findtext(outlook, "coming"), "a low coming from the east ([outlook])")
	L.vel_x = 0.01
	wi_check(findtext(weather_station_outlook(ST), "moving away"), "and one going away")

	// Temperate summers rain (they used to stay dry).
	season = "SUMMER"
	var/list/summer = climate_weather_state("temperate", WEATHER_WET, 2)
	wi_check(summer[1] == "rain2" && summer[2] == WEATHER_WET, "a temperate summer storm rains ([summer[1]])")
