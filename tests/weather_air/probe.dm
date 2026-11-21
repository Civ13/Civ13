// Native probe for the air grid (docs/weather-air.md).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/weather_air/probe.dm
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
/obj/map_metadata/wa_probe/New()
	return
/area/caribbean/wa_probe
var/wa_failures = 0
var/wa_runtime_error = FALSE
/proc/wa_check(condition, label)
	if (!condition)
		wa_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	wa_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		map = new /obj/map_metadata/wa_probe
		wa_checks()
	catch(var/exception/e)
		wa_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = wa_failures, "runtime_error" = wa_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/wa_area(climate, x1, x2)
	var/area/caribbean/wa_probe/A = new
	A.climate = climate
	A.location = AREA_OUTSIDE
	for (var/turf/T in block(locate(x1, 1, 1), locate(x2, world.maxy, 1)))
		A.contents += T
	return A

/proc/wa_steps(n)
	for (var/i = 1, i <= n, i++)
		weather_air.settle()
		weather_sample_time = -1

/proc/wa_checks()
	season = "SUMMER"
	time_of_day = "Afternoon"
	map.winddirection = "West"
	map.windspeedvar = 1
	wa_area("temperate", 1, 48)
	wa_area("desert", 49, 96)
	var/turf/field = locate(16, 32, 1)
	var/turf/sand = locate(80, 32, 1)
	var/turf/edge = locate(48, 32, 1)

	// Formulas.
	wa_check(abs(weather_dew_point(20, 100) - 20) < 0.01, "saturated air's dew point is its temperature")
	wa_check(abs(weather_dew_point(20, 50) - 9.3) < 0.2, "20 C at 50% has a dew point near 9.3 C ([weather_dew_point(20, 50)])")
	wa_check(abs(weather_relative_humidity(20, weather_dew_point(20, 40)) - 40) < 0.1, "humidity and dew point convert both ways")

	// A fresh grid starts at the climate's own air, with nothing to spin up.
	weather_air = null
	var/datum/weather_air_grid/G = weather_air_grid()
	wa_check(G.cols == 6 && G.rows == 4, "a 96 x 64 map has 6 x 4 cells of 16 tiles")
	wa_check(G.climates[1] == "temperate" && G.climates[6] == "desert", "cells take the climate under them")
	var/expect = climate_mean_at("temperate", "SUMMER", climate_season_fraction()) + climate_daily_offset("temperate", "Afternoon")
	wa_check(abs(weather_air_temp_at(field) - expect) < 0.5, "temperate air is the climate's afternoon ([weather_air_temp_at(field)] vs [expect])")
	wa_check(weather_air_temp_at(sand) > weather_air_temp_at(field) + 10, "the desert is far hotter ([weather_air_temp_at(sand)])")
	var/field_dew = weather_dew_point(climate_mean_at("temperate", "SUMMER", climate_season_fraction()), 75)
	var/sand_dew = weather_dew_point(climate_mean_at("desert", "SUMMER", climate_season_fraction()), 25)
	wa_check(abs(weather_dew_point_at(field) - field_dew) < 0.5 && abs(weather_dew_point_at(sand) - sand_dew) < 0.5, "the dew point is each climate's normal humidity at the day's mean ([weather_dew_point_at(field)], [weather_dew_point_at(sand)])")
	wa_check(weather_humidity_at(field) < 75 && weather_humidity_at(field) > 50, "so the afternoon is drier than the day's mean ([weather_humidity_at(field)]%)")
	wa_check(abs(weather_pressure_at(field) - 1013) < 0.01 && weather_cloud_at(field) == 0, "a clear sky is 1013 hPa with no cloud")
	var/t_mid = weather_air_temp_at(edge)
	wa_check(t_mid > weather_air_temp_at(field) && t_mid < weather_air_temp_at(sand), "values blend smoothly across a climate edge ([t_mid])")

	// Night falls: the air cools a little each tick, not all at once.
	time_of_day = "Early Morning"
	var/before = weather_air_temp_at(sand)
	wa_steps(1)
	var/after_one = weather_air_temp_at(sand)
	wa_check(after_one < before && after_one > before - 3, "the air cools gradually ([before] -> [after_one])")
	wa_steps(60)
	wa_check(abs(weather_air_temp_at(sand) - (climate_mean_at("desert", "SUMMER", climate_season_fraction()) + climate_daily_offset("desert", "Early Morning"))) < 0.5, "after ten minutes it reaches the dawn value ([weather_air_temp_at(sand)])")
	wa_check(weather_humidity_at(sand) > 25, "cooling air grows more humid at the same dew point ([weather_humidity_at(sand)]%)")

	// A storm over the field: pressure falls, cloud and humidity rise.
	time_of_day = "Afternoon"
	var/datum/weather_system/S = weather_system_spawn(WEATHER_SYSTEM_STORM, FALSE, 16, 32)
	wa_check(S, "a storm can be sent")
	S.origin_x = 16
	S.origin_y = 32
	S.origin_time = world.time
	S.vel_x = 0
	S.vel_y = 0
	S.born -= 1200
	S.peak = 1
	S.radius_x = 40
	S.radius_y = 40
	weather_sample_time = -1
	var/p_clear = weather_pressure_at(field)
	wa_steps(40)
	wa_check(weather_pressure_at(field) < p_clear - 10, "pressure falls under the storm ([p_clear] -> [weather_pressure_at(field)] hPa)")
	wa_check(weather_cloud_at(field) > 0.8, "the storm clouds over the sky ([weather_cloud_at(field)])")
	wa_check(weather_humidity_at(field) > 90, "air under rain nears saturation ([weather_humidity_at(field)]%)")
	wa_check(weather_dew_point_at(field) <= weather_air_temp_at(field), "the dew point never passes the temperature")
	wa_check(weather_pressure_at(sand) > weather_pressure_at(field), "pressure is higher away from the storm")
	weather_system_end(S)

	// A heat system raises pressure and dries the air.
	var/datum/weather_system/H = weather_system_spawn(WEATHER_SYSTEM_HEAT, FALSE, 80, 32)
	H.origin_x = 80
	H.origin_y = 32
	H.origin_time = world.time
	H.vel_x = 0
	H.vel_y = 0
	H.born -= 1200
	H.peak = 1
	H.radius_x = 40
	H.radius_y = 40
	weather_sample_time = -1
	var/t_before = weather_air_temp_at(sand)
	wa_steps(40)
	wa_check(weather_pressure_at(sand) > 1015, "a heat system builds high pressure ([weather_pressure_at(sand)] hPa)")
	wa_check(weather_air_temp_at(sand) > t_before + 2, "and heats the air ([t_before] -> [weather_air_temp_at(sand)])")
	weather_system_end(H)

	// Water cells swing less between day and night.
	weather_air = null
	G = weather_air_grid()
	G.water[1] = TRUE
	G.settle(TRUE)
	var/water_day = G.temp[1]
	var/land_day = G.temp[2]
	time_of_day = "Early Morning"
	G.settle(TRUE)
	wa_check(water_day - G.temp[1] < land_day - G.temp[2], "open water cools less at night than land")

	// The admin map data has one entry per cell in each layer.
	var/list/data = weather_air_map_data()
	wa_check(data[1] == 6 && data[2] == 4 && length(data[4]) == 24 && length(data[7]) == 24, "the weather map gets every cell of every layer")

	// The weather tick runs the grid.
	var/steps = G.steps
	weather_systems_step()
	wa_check(G.steps == steps + 1, "the weather tick settles the air grid")
	var/start = world.timeofday
	for (var/i = 1, i <= 200, i++)
		G.settle()
	world.log << "200 settles of 24 cells took [(world.timeofday - start) / 10] s"
