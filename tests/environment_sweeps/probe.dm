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

var/environment_measure = FALSE
var/environment_heartbeat = FALSE
var/environment_peak_tick = 0
var/environment_max_gap = 0
var/environment_last_beat = 0
var/environment_segment_work = 0
var/environment_max_segment = 0
var/environment_assertions = 0

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
	text2file(json_encode(list("phase"=label, "elapsed_ms"=(world.timeofday-started)*100, "peak_tick_percent"=environment_peak_tick, "peak_tick_ms"=environment_peak_tick*world.tick_lag, "max_heartbeat_gap_ms"=environment_max_gap*100, "max_work_between_heartbeats"=environment_max_segment, "turfs"=turfs.len, "overlays"=lighting_overlay_list.len, "areas"=area_list.len)), "metrics.jsonl")

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
		season = "WINTER"
		for (var/target in list(WEATHER_WET, WEATHER_EXTREME, WEATHER_NONE))
			environment_begin()
			var/started = world.timeofday
			change_weather(target, TRUE)
			environment_end("weather_[target]", started)
			for (var/area/caribbean/environment_probe/A in area_list)
				if (A.location == AREA_OUTSIDE)
					environment_assert(A.weather_intensity == weather_intensity, "weather intensity preserved")
					if (target == WEATHER_NONE)
						environment_assert(A.weather == WEATHER_NONE && A.icon_state == "", "weather clearing preserved")
			sleep(2)
		environment_heartbeat = FALSE
		text2file("PASS: [environment_assertions] assertions", "result.txt")
	catch (var/exception/E)
		text2file("FAIL: [E.name]", "result.txt")
	del(world)
