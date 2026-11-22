// Native probe for shared weather across regions (docs/weather-shared.md).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/weather_shared/probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 64
	maxy = 64
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
		config = new /datum/configuration
		map = new /obj/map_metadata/ws_probe
		ws_checks()
	catch(var/exception/e)
		ws_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = ws_failures, "runtime_error" = ws_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

// The calendar at a slot and ds into it.
/proc/ws_at(slot, in_slot = 0)
	var/day = round(slot / 288)
	world_calendar_test_now = list(day, (slot - day * 288) * 3000 + in_slot)

/proc/ws_find(list/systems, key)
	for (var/list/S in systems)
		if (S[2] == key)
			return S
	return null

/proc/ws_checks()
	config.season_duration_minutes = 60
	map.valid_weather_types = list(WEATHER_NONE, WEATHER_WET, WEATHER_EXTREME)
	ws_check(!weather_shared_on(), "a map off the calendar keeps its own weather")
	map.world_longitude = 10
	map.sun_latitude = 50
	map.world_region = "europe"
	ws_check(weather_shared_on() && weather_shared_storms_on(), "a region on the calendar shares its weather")
	ws_check(map.persistence_runtime_var("world_region"), "world_region is map data, never saved")

	// The seed: the same on every world, different between regions and slots.
	var/a = json_encode(weather_shared_slot("europe", 2840000))
	weather_shared_cache = list()
	var/b = json_encode(weather_shared_slot("europe", 2840000))
	ws_check(a == b, "a region's systems for a slot are the same every time")
	var/differs = FALSE
	for (var/s = 2840000 to 2840020)
		if (json_encode(weather_shared_slot("europe", s)) != json_encode(weather_shared_slot("asia", s)))
			differs = TRUE
	ws_check(differs, "regions have their own systems")

	// How often: a low or high in about 45% of slots, storms by season.
	var/centres = 0
	var/storms = 0
	var/eastward = 0
	var/westward = 0
	for (var/s = 2840000 to 2840999)
		for (var/list/rec in weather_shared_slot("europe", s))
			if (rec[1] == "c")
				centres++
				if (rec[10] > 0)
					eastward++
			else
				storms++
		for (var/list/rec in weather_shared_slot("africa", s))
			if (rec[1] == "c" && rec[10] < 0)
				westward++
	ws_check(centres > 380 && centres < 520, "a low or high forms in about 45% of slots ([centres] of 1000)")
	ws_check(storms > 400 && storms < 1000, "Europe gets about one storm every eight minutes ([storms] in 1000 slots)")
	ws_check(eastward > centres * 0.9, "middle-latitude systems drift east ([eastward] of [centres])")
	ws_check(westward > 350, "tropical systems drift west ([westward])")
	var/list/early = weather_shared_slot("europe", 2840000 + 3)
	var/list/later = weather_shared_slot("europe", 2840000 + 3)
	ws_check(early == later, "slots are cached")

	// Carrying a point over Europe's east edge into Asia's west edge, where
	// Europe meets its northern 59-92%.
	var/list/link = null
	for (var/list/L in weather_shared_links("asia"))
		if (L[1] == "europe")
			link = L
	ws_check(link && link[2] == "east" && link[4] == "west", "Asia's west edge leads in from Europe's east edge")
	var/list/T = weather_shared_transform(link, "asia")
	var/list/p = weather_shared_carry_point(T, 846, 286)
	ws_check(abs(p[1] - 1) < 0.01 && abs(p[2] - (0.5897 + 0.5 * (0.9231 - 0.5897)) * 854) < 0.5, "the middle of Europe's east edge is on Asia's west edge, 76% up ([p[1]], [p[2]])")
	var/list/inside = weather_shared_carry_point(T, 800, 286)
	var/list/beyond = weather_shared_carry_point(T, 900, 286)
	ws_check(inside[1] < 1 && beyond[1] > 1, "a point still in Europe is west of Asia; past the edge it is in Asia")
	var/list/v = weather_shared_carry_vector(T, 0.01, 0.002)
	ws_check(v[1] > 0 && v[2] > 0 && abs(v[1] / v[2] - 5) < 0.001, "a course keeps its compass over the edge")
	ws_check(weather_shared_near_edge(T, 800, 286, 100) && !weather_shared_near_edge(T, 300, 286, 100), "only systems near the edge are carried")

	// Every link has a matching stretch on the far side.
	var/missing = list()
	for (var/region in weather_region_frames)
		for (var/list/L in weather_shared_links(region))
			if (!weather_shared_transform(L, region))
				missing += "[region]<-[L[1]]"
	ws_check(!length(missing), "every link can carry weather ([jointext(missing, ", ")])")

	// The same storm seen from both sides: wherever Europe has a storm near its
	// east edge, Asia has it too, at the carried place.
	var/seen = 0
	var/agree = 0
	for (var/s = 2840000 to 2840400 step 2)
		ws_at(s, 1500)
		var/list/europe = weather_shared_systems("europe")
		var/list/asia = weather_shared_systems("asia")
		for (var/list/S in europe)
			if (S[1] != "s" || copytext(S[2], 1, 9) != "s|europe")
				continue
			var/x = S[5] + S[7] * S[4]
			var/y = S[6] + S[8] * S[4]
			var/list/rec = S[3]
			if (x < 846 - max(rec[4], rec[5]) || y < 0.0 || y > 572)
				continue
			seen++
			var/list/A = ws_find(asia, S[2])
			if (!A)
				continue
			var/list/carried = weather_shared_carry_point(T, x, y)
			var/ax = A[5] + A[7] * A[4]
			var/ay = A[6] + A[8] * A[4]
			if (abs(ax - carried[1]) < 0.01 && abs(ay - carried[2]) < 0.01 && A[4] == S[4])
				agree++
	ws_check(seen > 0 && agree == seen, "Asia sees every storm near Europe's east edge at the same place and age ([agree] of [seen])")

	// An island takes its ocean's lows and highs, scaled, and no ocean storms.
	var/island_centres = 0
	var/island_storms = 0
	for (var/s = 2840000 to 2840200 step 5)
		ws_at(s)
		for (var/list/S in weather_shared_systems("gaia"))
			if (S[1] == "c")
				island_centres++
				if (copytext(S[2], 1, 11) != "c|atlantic")
					island_storms += 100
			else
				island_storms++
	ws_check(island_centres > 0 && !island_storms, "Gaia gets the Atlantic's lows and highs and keeps its own storms ([island_centres], [island_storms])")
	map.world_region = "gaia"
	ws_check(weather_shared_on() && !weather_shared_storms_on(), "Gaia shares lows and highs but not storms")
	map.world_region = "europe"

	// Syncing this world: centres and storms follow the shared set, steadily.
	ws_at(2840100, 1000)
	weather_centres = list()
	weather_systems = list()
	weather_storm_count = 0
	var/datum/weather_centre/stray = new
	weather_centres += stray
	weather_shared_sync()
	ws_check(!(stray in weather_centres), "a stray local centre is dropped")
	var/list/expected = weather_shared_systems("europe")
	var/want_storms = 0
	for (var/list/S in expected)
		if (S[1] == "s")
			want_storms++
	ws_check(weather_centres.len <= 5, "at most five lows and highs ([weather_centres.len])")
	ws_check(weather_systems.len == min(want_storms, WEATHER_SYSTEM_MAX) && weather_storm_count == weather_systems.len, "the storms are the shared ones ([weather_systems.len] of [want_storms])")
	var/list/first_ids = list()
	for (var/datum/weather_system/S in weather_systems)
		first_ids += S.id
	var/centre_count = weather_centres.len
	weather_shared_sync()
	var/list/second_ids = list()
	for (var/datum/weather_system/S in weather_systems)
		second_ids += S.id
	ws_check(json_encode(first_ids) == json_encode(second_ids) && weather_centres.len == centre_count, "syncing again keeps the same systems")
	if (weather_systems.len)
		var/datum/weather_system/S = weather_systems[1]
		var/list/X = ws_find(expected, S.shared_key)
		ws_check(X && abs(S.centre_x() - (X[5] + X[7] * X[4])) < 0.01, "a shared storm stands where the seed puts it")
		S.lifetime = 10
		weather_shared_sync()
		ws_check(S.lifetime == 10, "a storm broken up here stays broken up")
	var/before = weather_systems.len
	weather_roll(WEATHER_WET)
	ws_check(weather_systems.len == before, "a weather roll sends no local storm where storms are shared")
	// Storms are off where the map has no wet weather.
	map.valid_weather_types = list(WEATHER_NONE)
	weather_centres_step()
	ws_check(TRUE, "a dry map's step runs")
	map.valid_weather_types = list(WEATHER_NONE, WEATHER_WET, WEATHER_EXTREME)
	map.world_region = null
	map.world_longitude = null
	world_calendar_test_now = null
