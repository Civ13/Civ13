// ported from /tg/station - Kachnov
#define LAG_CAPTURE_DILATION 50 // percent
#define LAG_CAPTURE_SECONDS 3 // consecutive fires over the threshold
#define LAG_CAPTURE_COOLDOWN 3000 // deciseconds of game time between captures
#define LAG_CAPTURE_WINDOW 100 // deciseconds of game time profiled
/process/time_track
	var/dilation = 0
	var/last_tick_realtime = 0
	var/last_tick_byond_time = 0
	var/last_tick_tickcount = 0
	var/first_run = TRUE
	var/list/averages = list()
	var/list/average_cpus = list()
	var/list/average_tick_usages = list()
	// Lag-spike capture: a profile of the procs running while the server falls behind.
	var/lag_seconds = 0
	var/last_lag_capture = -LAG_CAPTURE_COOLDOWN
	var/lag_capture_due = 0
	var/lag_capture_started_profiler = FALSE
	var/lag_capture_spike = 0
	var/lag_capture_map_cpu = 0
	var/stored_averages = list(
		"dilation" = 0,
		"cpu" = 0,
		"tick_usage" = 0)

/process/time_track/setup()
	name = "time tracking"
	schedule_interval = 1 SECONDS
	fires_at_gamestates = list(GAME_STATE_PREGAME, GAME_STATE_SETTING_UP, GAME_STATE_PLAYING, GAME_STATE_FINISHED)
	averages.len = 10
	priority = PROCESS_PRIORITY_IRRELEVANT
	processes.time_track = src

/process/time_track/fire()

	var/current_realtime = world.timeofday

	if (current_realtime < last_tick_realtime) // midnight rollerover
		current_realtime = 864000 + schedule_interval

	var/current_byondtime = world.time
	var/current_tickcount = world.time/world.tick_lag

	if (!first_run)
		var/tick_drift = max(0, (((current_realtime - last_tick_realtime) - (current_byondtime - last_tick_byond_time)) / world.tick_lag))
		if ((current_tickcount - last_tick_tickcount) * 100 == 0)
			dilation = 0
		else
			dilation = tick_drift / (current_tickcount - last_tick_tickcount) * 100
	else
		first_run = FALSE

	if (current_realtime == (864000 + schedule_interval))
		current_realtime = world.timeofday

	last_tick_realtime = current_realtime
	last_tick_byond_time = current_byondtime
	last_tick_tickcount = current_tickcount

	averages += dilation
	check_lag_capture()
	if (averages.len >= 20)
		var/list/old = averages.Copy()
		averages.Cut()
		averages.len = 10
		for (var/v in 11 to 20)
			averages[v-10] = old[v]

	average_cpus += world.cpu
	if (average_cpus.len >= 20)
		var/list/old = average_cpus.Copy()
		average_cpus.Cut()
		average_cpus.len = 10
		for (var/v in 11 to 20)
			average_cpus[v-10] = old[v]

	average_tick_usages += world.tick_usage
	if (average_tick_usages.len >= 20)
		var/list/old = average_tick_usages.Copy()
		average_tick_usages.Cut()
		average_tick_usages.len = 10
		for (var/v in 11 to 20)
			average_tick_usages[v-10] = old[v]

	stored_averages["dilation"] = average_dilation()
	stored_averages["cpu"] = average_cpu()
	stored_averages["tick_usage"] = average_tick_usage()

/process/time_track/proc/average_dilation()
	if (!averages.len)
		return 0
	. = 0
	for (var/n in averages)
		. += n
	. /= averages.len


/process/time_track/proc/average_cpu()
	if (!average_cpus.len)
		return 0
	. = 0
	for (var/n in average_cpus)
		. += n
	. /= average_cpus.len


/process/time_track/proc/average_tick_usage()
	if (!average_tick_usages.len)
		return 0
	. = 0
	for (var/n in average_tick_usages)
		. += n
	. /= average_tick_usages.len


// When the server stays well behind real time, profile what runs during the
// spike and save it to data/profile/ (see code/modules/admin/profile_dump.dm),
// so the cause can be read after the round instead of guessed from chat.
// Called every fire, so the capture finishes on a later fire, not a spawn.
/process/time_track/proc/check_lag_capture()
	if (lag_capture_due && world.time >= lag_capture_due)
		finish_lag_capture()
	if (dilation < LAG_CAPTURE_DILATION)
		lag_seconds = 0
		return
	if (++lag_seconds < LAG_CAPTURE_SECONDS)
		return
	if (lag_capture_due || world.time - last_lag_capture < LAG_CAPTURE_COOLDOWN)
		return
	last_lag_capture = world.time
	lag_seconds = 0
	lag_capture_started_profiler = !profile_dump_running
	if (lag_capture_started_profiler)
		world.Profile(PROFILE_CLEAR)
		world.Profile(PROFILE_START)
	lag_capture_spike = round(dilation)
	lag_capture_map_cpu = round(world.map_cpu)
	lag_capture_due = world.time + LAG_CAPTURE_WINDOW

/process/time_track/proc/finish_lag_capture()
	lag_capture_due = 0
	var/path = profile_dump_write()
	if (lag_capture_started_profiler && !profile_dump_running)
		world.Profile(PROFILE_STOP)
	var/msg = "Time dilation reached [lag_capture_spike]% (CPU [round(world.cpu)]%, map sending [lag_capture_map_cpu]%, [length(clients)] players); profile [path ? "saved to [path]" : "unavailable"]."
	log_game(msg)
	message_admins(msg)

#undef LAG_CAPTURE_DILATION
#undef LAG_CAPTURE_SECONDS
#undef LAG_CAPTURE_COOLDOWN
#undef LAG_CAPTURE_WINDOW
