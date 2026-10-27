/world
	maxx = 4
	maxy = 4
	maxz = 1
	turf = /turf/environment_probe
	area = /area/caribbean/environment_probe
	fps = 20

// Skip ordinary startup callbacks; all measured sweep/overlay code is production.
/turf/environment_probe/New()
	return

/area/caribbean/environment_probe
	climate = "temperate"
	location = AREA_OUTSIDE
	dynamic_lighting = TRUE

/area/caribbean/environment_probe/New()
	return

/obj/map_metadata/environment_probe/New()
	map = src

/obj/map_metadata/nomads/wasteland/two/environment_probe
	var/probe_zombies = FALSE

/obj/map_metadata/nomads/wasteland/two/environment_probe/New()
	map = src

/obj/map_metadata/nomads/wasteland/two/environment_probe/zombies(start = TRUE)
	probe_zombies = start

var/environment_measure = FALSE
var/environment_heartbeat = FALSE
var/environment_peak_tick = 0
var/environment_max_gap = 0
var/environment_last_beat = 0
var/environment_segment_work = 0
var/environment_max_segment = 0
var/environment_assertions = 0
var/environment_lighting_active = 0
var/environment_weather_active = 0
var/environment_max_lighting_workers = 0
var/environment_max_weather_workers = 0

/proc/environment_lighting_enter()
	environment_lighting_active++
	environment_max_lighting_workers = max(environment_max_lighting_workers, environment_lighting_active)

/proc/environment_weather_enter()
	environment_weather_active++
	environment_max_weather_workers = max(environment_max_weather_workers, environment_weather_active)


/proc/environment_assert(ok, message)
	environment_assertions++
	if (!ok)
		throw EXCEPTION(message)

/proc/environment_probe_work()
	if (!environment_measure)
		return
	environment_peak_tick = max(environment_peak_tick, world.tick_usage)
	environment_segment_work++
	environment_max_segment = max(environment_max_segment, environment_segment_work)

/proc/environment_beat()
	while (environment_heartbeat)
		if (environment_measure)
			environment_max_gap = max(environment_max_gap, world.timeofday - environment_last_beat)
			environment_last_beat = world.timeofday
			environment_segment_work = 0
		sleep(world.tick_lag)

/proc/environment_begin()
	environment_peak_tick = 0
	environment_max_gap = 0
	environment_segment_work = 0
	environment_max_segment = 0
	environment_last_beat = world.timeofday
	environment_measure = TRUE

/proc/environment_end(label, started)
	environment_probe_work()
	environment_max_gap = max(environment_max_gap, world.timeofday - environment_last_beat)
	environment_measure = FALSE
	#ifndef ENVIRONMENT_BASELINE
	environment_assert(environment_max_segment <= ENVIRONMENT_SWEEP_BATCH+1, "bounded sweep batch")
	#endif
	text2file(json_encode(list("phase"=label, "elapsed_ms"=(world.timeofday-started)*100, "peak_tick_percent"=environment_peak_tick, "peak_tick_ms"=environment_peak_tick*world.tick_lag, "max_heartbeat_gap_ms"=environment_max_gap*100, "max_work_between_heartbeats"=environment_max_segment, "turfs"=turfs.len, "overlays"=lighting_overlay_list.len, "areas"=area_list.len, "lighting_workers"=environment_max_lighting_workers, "weather_workers"=environment_max_weather_workers)), "metrics.jsonl")

/proc/environment_check_lights(target)
	environment_assert(time_of_day == target, "final time of day")
	var/count = 0
	for (var/turf/T in turfs)
		var/atom/movable/lighting_overlay/LO = T.lighting_overlay
		environment_assert(LO && LO.TOD == target && LO.invisibility == 0, "overlay target and visibility")
		var/area/A = T.loc
		if (A.dynamic_lighting)
			var/expected = min(1, time_of_day2luminosity[target] * T.get_window_coeff())
			environment_assert(abs(LO.color[1]-expected)<0.00001, "production color matrix matches target")
		count++
		if (count % 1024 == 0)
			sleep(world.tick_lag)

/world/New()
	try
		config = new
		var/obj/map_metadata/environment_probe/meta = new
		meta.valid_weather_types = list(WEATHER_NONE, WEATHER_WET, WEATHER_EXTREME, WEATHER_SMOG)
		world.maxx = text2num(world.params["size"])
		world.maxy = world.maxx
		world.maxz = 2
		turfs = list()
		area_list = list()
		var/list/probe_areas = list()
		var/list/climates = list("temperate", "tundra", "taiga", "jungle", "desert", "semiarid", "sea", "savanna")
		for (var/i=1 to text2num(world.params["areas"]))
			var/area/caribbean/environment_probe/A = new
			A.climate = climates[(i-1)%climates.len+1]
			A.icon_state = ""
			A.weather = WEATHER_NONE
			A.weather_intensity = weather_intensity
			A.location = (i%5 == 0) ? AREA_INSIDE : AREA_OUTSIDE
			probe_areas += A
			area_list += A
		var/n = 0
		for (var/turf/T in world)
			n++
			var/area/target_area = probe_areas[(n-1)%probe_areas.len+1]
			target_area.contents += T
			turfs += T
			for (var/i=1 to 4)
				if (!T.corners[i])
					T.corners[i] = new/datum/lighting_corner(T, LIGHTING_CORNER_DIAGONAL[i])
			new/atom/movable/lighting_overlay(T)
			if (n%1024 == 0)
				sleep(world.tick_lag)
		created_lighting_corners_and_overlays = TRUE
		var/process/time_of_day_change/P = new
		P.setup()
		environment_heartbeat = TRUE
		spawn(0)
			environment_beat()
		sleep(2)
		for (var/target in list("Night", "Midday", "Night"))
			environment_begin()
			var/started = world.timeofday
			update_lighting(target, null, FALSE)
			environment_end("lighting_[target]", started)
			environment_check_lights(target)
			sleep(2)
		environment_begin()
		var/overlap_started = world.timeofday
		var/list/day_done = list(FALSE)
		spawn(0)
			update_lighting("Midday", null, FALSE)
			day_done[1] = TRUE
		sleep(world.tick_lag)
		update_lighting("Evening", null, FALSE)
		update_lighting("Night", null, FALSE)
		while (!day_done[1])
			sleep(world.tick_lag)
		#ifndef ENVIRONMENT_BASELINE
		environment_assert(environment_max_lighting_workers == 1, "one daylight worker")
		#endif
		environment_end("lighting_overlap", overlap_started)
		environment_check_lights("Night")
		#ifndef ENVIRONMENT_BASELINE
		environment_assert(environment_max_lighting_workers == 1, "one daylight worker")
		environment_assert(!P.updating_lighting && !P.admincaller, "daylight worker released")
		#endif
		// Night's caller must not overwrite a newer Morning's map effect.
		var/obj/map_metadata/nomads/wasteland/two/environment_probe/wasteland = new
		wasteland.ID = MAP_NOMADS_WASTELAND_2
		day_done[1] = FALSE
		spawn(0)
			update_lighting("Night", null, FALSE)
			day_done[1] = TRUE
		sleep(world.tick_lag)
		update_lighting("Morning", null, FALSE)
		while (!day_done[1])
			sleep(world.tick_lag)
		#ifndef ENVIRONMENT_BASELINE
		environment_assert(!wasteland.probe_zombies, "latest Wasteland map effect")
		#endif
		map = meta
		// Excluded z levels keep their colors, but carry the latest TOD.
		meta.zlevels_without_lighting = list(2)
		var/turf/excluded = locate(1, 1, 2)
		var/old_color = excluded.lighting_overlay.color[1]
		update_lighting("Night", null, FALSE)
		environment_assert(excluded.lighting_overlay.color[1] == old_color, "excluded z color preserved")
		environment_assert(excluded.lighting_overlay.TOD == "Night", "excluded z TOD updated")
		meta.zlevels_without_lighting = list()
		meta.areas_without_lighting = list(/area/caribbean/environment_probe)
		update_lighting("Midday", null, FALSE)
		environment_assert(excluded.lighting_overlay.color[1] == old_color, "excluded area color preserved")
		environment_assert(excluded.lighting_overlay.TOD == "Midday", "excluded area TOD updated")
		meta.areas_without_lighting = list()
		for (var/probe_season in list("WINTER", "SUMMER", "Wet Season", "Dry Season"))
			season = probe_season
			for (var/target in list(WEATHER_WET, WEATHER_EXTREME, WEATHER_SMOG, WEATHER_NONE))
				environment_begin()
				var/started = world.timeofday
				change_weather(target, TRUE)
				environment_end("weather_[season]_[target]", started)
				var/list/signature = list()
				for (var/area/caribbean/environment_probe/A in area_list)
					signature += list(list(A.climate, A.location, A.icon_state, A.weather, A.weather_intensity))
					if (A.location == AREA_INSIDE)
						environment_assert(A.weather == WEATHER_NONE && A.icon_state == "", "indoor weather preserved")
				text2file(json_encode(list("phase"="weather_[season]_[target]", "digest"=md5(json_encode(signature)))), "weather_states.jsonl")
				sleep(2)
		global_radiation = 300
		change_weather(WEATHER_WET, TRUE)
		for (var/area/caribbean/environment_probe/A in area_list)
			if (A.location == AREA_OUTSIDE)
				environment_assert(findtext(A.icon_state, "rad_") == 1, "outdoor radiation prefix")
			else
				environment_assert(A.icon_state == "", "indoor radiation excluded")
		global_radiation = 0
		change_weather(WEATHER_NONE, TRUE)
		environment_begin()
		overlap_started = world.timeofday
		var/list/weather_done = list(FALSE)
		spawn(0)
			change_weather(WEATHER_WET, TRUE)
			weather_done[1] = TRUE
		sleep(world.tick_lag)
		change_weather(WEATHER_EXTREME, TRUE)
		change_weather(WEATHER_NONE, TRUE)
		while (!weather_done[1])
			sleep(world.tick_lag)
		environment_end("weather_overlap", overlap_started)
		environment_assert(weather == WEATHER_NONE, "latest weather request wins")
		#ifndef ENVIRONMENT_BASELINE
		environment_assert(environment_max_weather_workers == 1 && !environment_weather_running, "one released weather worker")
		#endif
		for (var/area/caribbean/environment_probe/A in area_list)
			if (A.location == AREA_OUTSIDE)
				environment_assert(A.weather == WEATHER_NONE && A.icon_state == "", "overlap final weather clearing")
		environment_heartbeat = FALSE
		text2file("PASS: [environment_assertions] assertions", "result.txt")
	catch (var/exception/E)
		text2file("FAIL: [E.name]", "result.txt")
	del(world)
