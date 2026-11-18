/world
	hub = ""
	hub_password = ""
	maxx = 10
	maxy = 10
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/climate_probe/New()
	return
var/climate_failures = 0
var/climate_runtime_error = FALSE
/proc/climate_check(condition, label)
	if (!condition)
		climate_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	climate_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/climate_probe
		map.elevation_regions = list(list("x1" = 1, "x2" = 5, "y1" = 1, "y2" = 10, "z" = 1, "metres" = 2000))
		climate_checks()
	catch(var/exception/e)
		climate_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = climate_failures, "runtime_error" = climate_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/climate_checks()
	var/turf/high = locate(3, 3, 1)
	var/turf/low = locate(8, 3, 1)
	var/area/A = get_area(high)
	A.location = AREA_OUTSIDE
	A.climate = "temperate"
	A.weather = WEATHER_WET
	A.weather_intensity = 1
	A.icon_state = "rain1"
	season = "SPRING"
	time_of_day = "Evening"
	climate_check(get_elevation(high) == 2000 && get_elevation(low) == 0, "fixture has a 2000 m plateau")
	climate_check(elevation_temperature_drop(high) == 0 && get_temp(high) == get_temp(low), "default lapse rate changes nothing")
	climate_check(local_precipitation(high) == "rain", "default lapse rate keeps rain as rain")
	map.elevation_lapse_c_per_km = 6.5
	climate_check(elevation_temperature_drop(high) == 13 && elevation_temperature_drop(low) == 0, "6.5 C/km cools 2000 m by 13 C")
	climate_check(get_temp(low) - get_temp(high) == 13, "high ground is 13 C colder")
	climate_check(local_precipitation(high) == "snow" && local_precipitation(low) == "rain", "rain falls as snow on the cold plateau only")
	A.icon_state = "snow1"
	climate_check(local_precipitation(low) == "snow", "area snow is still snow everywhere")
	A.weather = WEATHER_NONE
	climate_check(isnull(local_precipitation(high)), "dry weather has no precipitation")
	map.elevation_lapse_c_per_km = 50
	climate_check(elevation_temperature_drop(high) == 0, "an invalid lapse rate is ignored")
	map.elevation_lapse_c_per_km = 6.5
	climate_text_checks(high, low)
	map.elevation_lapse_c_per_km = 0
	climate_normal_checks(low)
	climate_terrain_checks(high, low)

// Generated region maps carry their profile as text on the map metadata.
/proc/climate_text_checks(turf/high, turf/low)
	var/list/authored = map.elevation_regions
	map.elevation_regions = null
	map.elevation_regions_text = "1 5 1 10 1 1000|6 10 1 2 1 -40"
	map.elevation_profile_cache = null
	climate_check(get_elevation(high) == 1000 && get_elevation(low) == 0 && get_elevation(locate(8, 1, 1)) == -40, "text profile gives the same heights as authored rows")
	climate_check(elevation_temperature_drop(high) == 6.5, "text profile feeds the lapse rate")
	map.elevation_regions = authored
	map.elevation_profile_cache = null
	climate_check(get_elevation(high) == 2000, "authored rows win over the text form")
	climate_check(!length(elevation_regions_from_text("")), "empty text is a flat profile")
	for (var/bad in list("1 5 1 10 1", "1 5 1 10 1 20x", "1,5,1,10,1,20", "1 5 1 10 1 1e3", "1  5 1 10 1 20"))
		var/refused = FALSE
		try
			elevation_regions_from_text(bad)
		catch
			refused = TRUE
		climate_check(refused, "malformed text '[bad]' is refused")
	var/refused_overlap = FALSE
	try
		build_elevation_profile(0, elevation_regions_from_text("1 5 1 5 1 100|5 6 5 6 1 200"), 10, 10, 1)
	catch
		refused_overlap = TRUE
	climate_check(refused_overlap, "text rows still get the overlap check")

// Climate normals (climate_normals.dm): smooth seasons, an additive day and
// weather that adds rather than multiplies.
/proc/climate_normal_checks(turf/T)
	var/area/A = get_area(T)
	A.location = AREA_OUTSIDE
	A.weather = WEATHER_NONE
	A.icon_state = ""
	climate_check(climate_mean_at("temperate", "SUMMER", 0.5) == 20 && climate_mean_at("temperate", "WINTER", 0.5) == -2, "temperate mid-summer is 20 C and mid-winter -2 C")
	climate_check(abs(climate_mean_at("temperate", "SPRING", 0.5) - 9) < 0.01 && abs(climate_mean_at("temperate", "FALL", 0.5) - 9) < 0.01, "spring and fall sit at the annual mean")
	climate_check(abs(climate_mean_at("temperate", "FALL", 1) - climate_mean_at("temperate", "WINTER", 0)) < 0.01 && abs(climate_mean_at("temperate", "WINTER", 1) - climate_mean_at("temperate", "SPRING", 0)) < 0.01, "the year has no jump at a season change")
	climate_check(climate_mean_at("temperate", "WINTER", 0.25) > climate_mean_at("temperate", "WINTER", 0.5), "early winter is milder than mid-winter")
	climate_check(climate_mean_at("savanna", "Dry Season", 0.5) > climate_mean_at("savanna", "Wet Season", 0.5), "the dry season is the hot one")
	climate_check(climate_mean_at("desert", "Wet Season", 0.5) < 30 && climate_mean_at("desert", "Dry Season", 0.5) > 25, "desert wet and dry seasons follow the desert, not one flat value")
	climate_check(climate_mean_at("unknown", "SUMMER", 0.5) == 20, "an unknown climate keeps 20 C")
	climate_check(climate_season_mean("tundra", "SUMMER") == 8 && climate_season_mean("desert", "WINTER") == 13, "tundra summers are above freezing and desert winters cool")
	A.climate = "desert"
	season = "SUMMER"
	time_of_day = "Early Morning"
	var/dawn = get_temp(T)
	time_of_day = "Afternoon"
	var/afternoon = get_temp(T)
	climate_check(dawn == 25 && afternoon == 43, "a desert summer runs from 25 C at dawn to 43 C in the afternoon ([dawn], [afternoon])")
	A.climate = "temperate"
	season = "WINTER"
	time_of_day = "Night"
	var/winter_night = get_temp(T)
	time_of_day = "Afternoon"
	climate_check(winter_night < get_temp(T), "a winter night is colder than the afternoon, not warmer ([winter_night])")
	time_of_day = "Evening"
	var/dry = get_temp(T)
	A.weather = WEATHER_WET
	A.weather_intensity = 2
	A.icon_state = "rain2"
	climate_check(get_temp(T) < dry, "rain cools freezing air instead of warming it ([dry] -> [get_temp(T)])")
	A.weather = WEATHER_EXTREME
	A.icon_state = "snow_storm"
	climate_check(get_temp(T) == round(climate_air_temperature(T, A) - 10), "a blizzard is 10 C below the season, not a flat -82 C ([get_temp(T)])")
	A.weather = WEATHER_NONE
	A.icon_state = ""
	season = "SPRING"

// Hills from a terrain height file cool the air at 6.5 C per km, 50 m a level.
/proc/climate_terrain_checks(turf/high, turf/low)
	climate_check(terrain_temperature_drop(high) == 0, "no height file, no hill cooling")
	var/list/rows = list()
	for (var/y = 1, y <= 10, y++)
		rows += "aaaaa00000"
	fdel("climate_probe_heights.txt")
	text2file("civ13-terrain-heights 2\nsize 10 10\nz 1\n[jointext(rows, "\n")]\n", "climate_probe_heights.txt")
	map.terrain_height_file = "climate_probe_heights.txt"
	climate_check(terrain_temperature_drop(high) == 3.25 && terrain_temperature_drop(low) == 0, "a level-10 hill is 3.25 C colder ([terrain_temperature_drop(high)])")
	climate_check(elevation_temperature_drop(high) == 3.25, "hill cooling counts without a lapse rate")
	climate_check(get_temp(low) - get_temp(high) == 3 || get_temp(low) - get_temp(high) == 4, "the hilltop reads colder ([get_temp(low)] vs [get_temp(high)])")
	map.terrain_height_file = null
	fdel("climate_probe_heights.txt")
