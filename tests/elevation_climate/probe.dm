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
