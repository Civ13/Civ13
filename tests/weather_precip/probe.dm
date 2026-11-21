// Native probe for precipitation types (docs/weather-precip.md).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/weather_precip/probe.dm
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
/obj/map_metadata/wp_probe/New()
	return
/area/caribbean/wp_probe
var/wp_failures = 0
var/wp_runtime_error = FALSE
/proc/wp_check(condition, label)
	if (!condition)
		wp_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	wp_runtime_error = TRUE
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
		map = new /obj/map_metadata/wp_probe
		wp_checks()
	catch(var/exception/e)
		wp_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = wp_failures, "runtime_error" = wp_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/wp_area(climate, x1, x2)
	var/area/caribbean/wp_probe/A = new
	A.climate = climate
	A.location = AREA_OUTSIDE
	for (var/turf/T in block(locate(x1, 1, 1), locate(x2, world.maxy, 1)))
		A.contents += T
	return A

// A storm standing still over x, y at full strength.
/proc/wp_storm(x, y, severe = FALSE)
	var/datum/weather_system/S = weather_system_spawn(WEATHER_SYSTEM_STORM, severe, x, y)
	S.origin_x = x
	S.origin_y = y
	S.origin_time = world.time
	S.vel_x = 0
	S.vel_y = 0
	S.radius_x = 60
	S.radius_y = 60
	S.peak = 1
	S.born = world.time - 6000
	S.lifetime = 60000
	weather_sample_time = -1
	return S

/proc/wp_air(temp, dew)
	var/datum/weather_air_grid/G = weather_air
	for (var/i = 1, i <= G.temp.len, i++)
		G.temp[i] = temp
		G.dew[i] = dew
	weather_sample_time = -1

/proc/wp_checks()
	season = "SPRING"
	time_of_day = "Morning"
	map.winddirection = "West"
	map.windspeedvar = 1
	map.valid_weather_types = list(WEATHER_NONE, WEATHER_WET, WEATHER_EXTREME)
	wp_area("temperate", 1, 96)
	var/turf/field = locate(48, 32, 1)

	// The rules.
	wp_check(weather_precip_kind(10, 2, FALSE, FALSE, FALSE, 0.5, 70) == "rain", "rain at 10 C")
	wp_check(weather_precip_kind(2, 2, FALSE, FALSE, FALSE, 0.5, 70) == "sleet", "sleet at 2 C")
	wp_check(weather_precip_kind(0.5, 2, FALSE, FALSE, FALSE, 0.5, 70) == "snow", "snow below 1 C")
	wp_check(weather_precip_kind(-3, 2, TRUE, FALSE, FALSE, 0.5, 70) == "freezing_rain", "freezing rain at -3 C under warm air aloft")
	wp_check(weather_precip_kind(-3, 2, FALSE, FALSE, FALSE, 0.5, 70) == "snow", "but snow without it")
	wp_check(weather_precip_kind(25, 3, FALSE, TRUE, TRUE, 0.9, 70) == "hail", "hail in a severe thunderstorm's core")
	wp_check(weather_precip_kind(25, 3, FALSE, TRUE, TRUE, 0.5, 70) == "rain" && weather_precip_kind(25, 3, FALSE, FALSE, TRUE, 0.9, 70) == "rain", "only in the core, and only of a thunderstorm")
	wp_check(weather_precip_kind(8, 1, FALSE, FALSE, FALSE, 0.3, 95) == "drizzle", "light rain in saturated air is drizzle")

	// Before the air grid exists, the climate table decides alone.
	weather_air = null
	var/datum/weather_system/S = wp_storm(48, 32)
	wp_check(weather_look_at(field) == "rain2" && weather_precip_at(field) == "rain", "no grid: a spring storm rains ([weather_look_at(field)])")

	// With the grid, the air on the tile decides.
	weather_air_grid()
	wp_air(10, 6)
	wp_check(weather_look_at(field) == "rain2" && weather_precip_at(field) == "rain", "10 C: rain")
	wp_air(2, 1)
	wp_check(weather_look_at(field) == "rain2" && weather_at(field) == WEATHER_WET && weather_precip_at(field) == "sleet", "2 C: sleet, wet like rain ([weather_precip_at(field)])")
	wp_air(-5, -7)
	wp_check(findtext(weather_look_at(field), "snow") && weather_precip_at(field) == "snow", "-5 C: the spring rain falls as snow ([weather_look_at(field)])")
	season = "WINTER"
	weather_state_cache.Cut()
	wp_air(8, 5)
	wp_check(weather_look_at(field) == "rain2" && weather_precip_at(field) == "rain", "a mild winter day rains instead of snowing ([weather_look_at(field)])")
	season = "SPRING"
	weather_state_cache.Cut()

	// Freezing rain ahead of a low, and the ice it leaves.
	wp_air(-3, -5)
	var/datum/weather_centre/L = weather_centre_spawn(WEATHER_CENTRE_LOW, 18, 32)
	L.vel_x = 0.01
	L.vel_y = 0
	L.origin_time = world.time
	L.born = world.time - 6000
	L.lifetime = 60000
	L.radius = 60
	wp_check(weather_centres_temperature_at(48, 32) >= 1, "the field lies in the warm air ahead of the low")
	wp_check(weather_precip_at(field) == "freezing_rain" && findtext(weather_look_at(field), "rain"), "-3 C under it: freezing rain, falling as rain ([weather_look_at(field)])")
	wp_check(!weather_glazed_at(field), "no ice until the weather tick")
	weather_air.settle_precip()
	wp_check(weather_glazed_at(field) && footwear_ice_turf(field), "freezing rain glazes the ground with ice that boots must grip")
	weather_centres_clear()
	weather_system_end(S)
	weather_air.settle_precip()
	wp_check(weather_glazed_at(field), "the ice outlasts the rain while it stays cold")
	wp_air(5, 2)
	weather_air.settle_precip()
	wp_check(!weather_glazed_at(field) && !footwear_ice_turf(field), "and thaws when it warms")

	// Hail in a severe afternoon thunderstorm, and helmets.
	wp_air(26, 20)
	var/datum/weather_system/T = weather_convective_storm(48, 32, TRUE)
	T.born = world.time - 6000
	T.lifetime = 60000
	weather_sample_time = -1
	wp_check(T.convective && weather_precip_at(field) == "hail" && weather_look_at(field) == "rain3", "a severe thunderstorm's core hails ([weather_precip_at(field)])")
	var/mob/living/human/H = new /mob/living/human(field)
	var/before = H.getBruteLoss()
	wp_check(weather_hail_strike(H, 100) == "hit" && H.getBruteLoss() > before, "hail hurts a bare head")
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet(H), slot_head)
	before = H.getBruteLoss()
	wp_check(weather_hail_strike(H, 100) == "blocked" && H.getBruteLoss() == before, "a helmet stops it")
	wp_air(6, 3)
	wp_check(weather_precip_at(field) == "rain", "in cold air the same storm only rains")
	weather_system_end(T)

	// Hills: wetter facing the wind, drier in its shadow.
	var/datum/weather_air_grid/G = weather_air
	for (var/row = 0, row < G.rows, row++)
		for (var/col = 0, col < G.cols, col++)
			G.heights[G.index(col, row)] = col * 3
	G.survey_wind()
	wp_air(10, 6)
	map.windspeedvar = 2
	map.winddirection = "West"
	G.settle_wind(TRUE)
	G.settle_precip()
	var/up = weather_orographic_at(48, 32)
	S = wp_storm(48, 32)
	S.peak = 0.5
	var/wet_side = weather_storm_strength(48, 32)
	map.winddirection = "East"
	G.settle_wind(TRUE)
	G.settle_precip()
	var/down = weather_orographic_at(48, 32)
	var/dry_side = weather_storm_strength(48, 32)
	wp_check(up > 1.1 && down < 0.9, "air pushed up a slope drops more, air coming down drops less ([up], [down])")
	wp_check(wet_side > dry_side, "so the same storm is heavier on the windward side ([wet_side] vs [dry_side])")
	weather_system_end(S)
