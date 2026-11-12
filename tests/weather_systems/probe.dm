// Native probe for moving weather systems (docs/weather-systems.md).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/weather_systems/probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 200
	maxy = 120
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/ws_probe/New()
	return
/area/caribbean/ws_probe
/area/caribbean/ws_probe/roofed
	location = AREA_INSIDE
var/ws_failures = 0
var/ws_runtime_error = FALSE
/proc/ws_check(condition, label)
	if (!condition)
		ws_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	ws_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		map = new /obj/map_metadata/ws_probe
		ws_checks()
	catch(var/exception/e)
		ws_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = ws_failures, "runtime_error" = ws_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/ws_area(climate, x1, x2, roofed = FALSE)
	var/area/caribbean/ws_probe/A = roofed ? new /area/caribbean/ws_probe/roofed : new /area/caribbean/ws_probe
	A.climate = climate
	for (var/turf/T in block(locate(x1, 1, 1), locate(x2, world.maxy, 1)))
		A.contents += T
	return A

// Age a system as if this many deciseconds had passed.
/proc/ws_age(datum/weather_system/S, time)
	S.origin_time -= time
	S.born -= time
	weather_sample_time = -1

/proc/ws_checks()
	season = "SPRING"
	time_of_day = "Midday"
	map.valid_weather_types = list(WEATHER_NONE, WEATHER_WET, WEATHER_EXTREME)
	map.winddirection = "West" // blows from the west: weather travels east
	map.windspeedvar = 2
	// West to east: temperate, a roofed strip, tundra, desert.
	var/area/temperate = ws_area("temperate", 1, 80)
	var/area/roofed = ws_area("temperate", 81, 90, TRUE)
	ws_area("tundra", 91, 150)
	ws_area("desert", 151, 200)
	var/turf/field = locate(60, 60, 1)
	var/turf/indoors = locate(85, 60, 1)
	var/turf/ice = locate(120, 60, 1)
	var/turf/sand = locate(170, 60, 1)

	// The one table both zone weather and systems read.
	var/list/state = climate_weather_state("temperate", WEATHER_WET, 2)
	ws_check(state[1] == "rain2" && state[2] == WEATHER_WET && state[3] == 2, "temperate spring wet is rain")
	state = climate_weather_state("tundra", WEATHER_EXTREME, 3)
	ws_check(state[1] == "snow_storm" && state[2] == WEATHER_EXTREME, "tundra spring extreme is a blizzard")
	state = climate_weather_state("desert", WEATHER_WET, 1)
	ws_check(state[1] == "rain1" && state[2] == WEATHER_WET, "desert wet season rains")
	ws_check(roofed.icon_state == "roof" && roofed.plane == WEATHER_ROOF_PLANE && temperate.icon_state == "", "roofed areas draw the weather mask, open ones do not")

	// Clear sky.
	ws_check(weather_at(field) == WEATHER_NONE && weather_look_at(field) == "" && weather_intensity_at(field) == 0 && !weather_anywhere(), "clear sky is clear")
	ws_check(weather_system_capacity() == 1, "a small map holds one storm")

	// A storm aimed at the field starts off the map, upwind.
	var/datum/weather_system/S = weather_system_spawn(WEATHER_SYSTEM_STORM, FALSE, 60, 60)
	S.peak = 1
	ws_check(S && weather_systems.len == 1 && weather_storm_count == 1, "storm spawned")
	ws_check(S.centre_x() + S.radius_x <= 0.01 && S.vel_x > 0 && S.vel_y == 0, "storm starts off the west edge heading east")
	ws_check(weather_at(field) == WEATHER_NONE, "field is dry before it arrives")
	// Bring its centre over the field, past its first minute of growth.
	ws_age(S, (60 - S.origin_x) / S.vel_x)
	ws_check(abs(S.centre_x() - 60) < 0.5, "storm centre reached the field")
	ws_check(S.power() == 1, "storm at full power")
	ws_check(weather_at(field) == WEATHER_WET && weather_look_at(field) == "rain2" && weather_intensity_at(field) == 3, "ordinary storm core is heavy rain, not extreme weather")
	ws_check(weather_at(indoors) == WEATHER_NONE || S.strength_at(85, 60) == 0, "roofed tile stays dry")
	var/turf/far = locate(60 + round(S.radius_x) + 12, 60, 1)
	ws_check(S.strength_at(far.x, far.y) == 0, "nothing beyond the oval")
	// The band at the edge is lighter than the core.
	var/edge_x = 60 + round(S.radius_x * 0.85)
	var/edge = S.strength_at(edge_x, 60)
	ws_check(edge > 0 && edge < 1, "edge of the storm is weaker than its core ([edge])")
	ws_check(weather_anywhere(), "weather is about")
	ws_check(weather_wind_at(field) >= 3, "wind rises under the storm")
	var/steady_peak = S.peak
	S.peak = 0.5
	ws_check(!weather_lightning_sky(field), "steady rain throws no lightning")
	S.peak = 1
	ws_check(weather_lightning_sky(field), "heavy rain is a lightning sky")
	var/strikes = weather_lightning_count
	ws_check(weather_lightning(field.x, field.y) == 0 && weather_lightning_count == strikes + 1, "a strike with nobody near is seen by nobody")
	map.winddirection = "North"
	S.peak = steady_peak
	ws_check(weather_shadow_look() == "shadow_s", "cloud shadow slides the way a north wind carries it")
	map.winddirection = "West"
	ws_check(weather_shadow_look() == "shadow_e", "cloud shadow slides east on a west wind")

	// The same storm over other climates.
	S.origin_x = 120
	S.origin_y = 60
	S.origin_time = world.time
	weather_sample_time = -1
	ws_check(weather_at(ice) == WEATHER_WET && weather_look_at(ice) == "snow2", "the same storm snows on the tundra")
	S.severe = TRUE
	weather_sample_time = -1
	ws_check(weather_at(ice) == WEATHER_EXTREME && weather_look_at(ice) == "snow_storm", "a severe core over tundra is a blizzard")
	ws_check(get_temp(ice) == -82, "blizzard temperature under the core")
	ws_check(local_precipitation(ice) == "snow", "ground snow sees the storm's snow")
	var/list/chunk = weather_chunk_state(round(119 / 4), round(59 / 4), 1)
	ws_check(islist(chunk) && chunk[1] == "snow_storm" && chunk[2] == 255, "drawn chunk under the core is a full blizzard")
	ws_check(chunk[3] == 190, "the core casts the full cloud shadow")
	ws_check(!weather_lightning_sky(ice), "a blizzard throws no lightning")
	ws_check(isnull(weather_chunk_state(0, 0, 1)), "no chunk is drawn outside the storm")
	season = "Dry Season"
	weather_sample_time = -1
	S.origin_x = 170
	S.origin_time = world.time
	weather_sample_time = -1
	ws_check(weather_at(sand) == WEATHER_EXTREME && weather_look_at(sand) == "sandstorm", "a severe core over dry desert is a sandstorm")
	season = "SPRING"

	// It passes over and is retired.
	S.origin_x = world.maxx + S.radius_x + 5
	S.origin_time = world.time
	weather_sample_time = -1
	ws_check(S.spent(), "storm past the east edge is spent")
	weather_systems_step()
	ws_check(!weather_systems.len && !weather_storm_count && weather_at(sand) == WEATHER_NONE, "spent storm is removed")

	// Rolls.
	weather_roll(WEATHER_NONE)
	ws_check(!weather_systems.len, "a clear roll sends nothing")
	weather_roll(WEATHER_WET)
	ws_check(weather_systems.len == 1, "a wet roll sends a storm")
	weather_roll(WEATHER_EXTREME)
	ws_check(weather_systems.len == 1, "no more storms than the map holds")
	weather_systems_clear()
	map.valid_weather_types = list(WEATHER_NONE, WEATHER_WET)
	weather_roll(WEATHER_EXTREME)
	ws_check(!weather_systems.len, "a map without extreme weather gets no severe storm")
	map.valid_weather_types = list(WEATHER_NONE, WEATHER_WET, WEATHER_EXTREME)

	// Pinned zone weather still works and a clear roll lifts it.
	change_weather(WEATHER_WET)
	ws_check(weather == WEATHER_WET && temperate.icon_state == "rain2" && weather_at(field) == WEATHER_WET && weather_look_at(field) == "rain2", "pinned zone weather still rains on the zone")
	ws_check(weather_at(indoors) == WEATHER_NONE && roofed.icon_state == "roof", "pinned zone weather leaves roofed areas alone")
	weather_roll(WEATHER_NONE)
	ws_check(weather == WEATHER_NONE && weather_at(field) == WEATHER_NONE, "a clear roll lifts pinned zone weather")

	// Called-down events are systems.
	map.triggered_blizzard = TRUE
	weather_events()
	ws_check(!map.triggered_blizzard && weather_systems.len == 1, "a triggered blizzard is a storm system")
	var/datum/weather_system/B = weather_systems[1]
	ws_check(B.severe && B.kind == WEATHER_SYSTEM_STORM, "the triggered storm is severe")
	weather_systems_clear()
	map.triggered_heatwave = TRUE
	weather_events()
	var/datum/weather_system/H = weather_systems.len ? weather_systems[1] : null
	ws_check(H && H.kind == WEATHER_SYSTEM_HEAT && !weather_storm_count && !map.triggered_heatwave, "a triggered heat wave is a heat system")
	if (H)
		H.origin_x = 60
		H.origin_y = 60
		H.origin_time = world.time
		H.born = world.time - 6000
		weather_sample_time = -1
		ws_check(weather_heat_at(field) && !weather_heat_at(sand), "heat only under the heat system")
		ws_check(weather_at(field) == WEATHER_NONE, "a heat wave brings no rain")
	weather_systems_clear()
	ws_check(!weather_heat_at(field), "no heat once it has gone")

	// Wind veers, never reverses.
	var/static/list/opposite = list("North" = "South", "South" = "North", "East" = "West", "West" = "East")
	var/reversed = FALSE
	var/turned = FALSE
	var/direction = "North"
	for (var/i = 1, i <= 400, i++)
		var/next = weather_veer(direction)
		if (next == opposite[direction])
			reversed = TRUE
		if (next != direction)
			turned = TRUE
		direction = next
	ws_check(!reversed && turned, "wind veers by quarter turns and never reverses")

	// A storm comes round to a new wind without jumping.
	S = weather_system_spawn(WEATHER_SYSTEM_STORM, FALSE, 100, 60)
	var/before_x = S.centre_x()
	var/before_y = S.centre_y()
	map.winddirection = "South"
	weather_systems_step()
	ws_check(abs(S.centre_x() - before_x) < 0.01 && abs(S.centre_y() - before_y) < 0.01 && S.vel_y > 0 && S.vel_x > 0, "a storm turns toward a new wind from where it is")
	weather_disperse(locate(clamp(round(S.centre_x()), 1, world.maxx), 60, 1))
	weather_systems_clear()
	ws_check(length(weather_system_report()) == 0, "report is empty with a clear sky")
