var/TOD_may_automatically_change = FALSE

/process/time_of_day
	var/TOD_ticks = 0

/process/time_of_day/setup()
	name = "time of day cycle"
	schedule_interval = 10 SECONDS
	start_delay = 2 SECONDS
	fires_at_gamestates = list(GAME_STATE_PLAYING)
	priority = PROCESS_PRIORITY_IRRELEVANT
	always_runs = TRUE
	processes.time_of_day = src

/process/time_of_day/fire()
	if (!roundstart_time || (map && map.times_of_day.len == 1))
		return
	try
		TOD_ticks += schedule_interval/10
		if (TOD_ticks >= time_of_day2ticks[time_of_day])
			TOD_ticks = 0
			TOD_may_automatically_change = TRUE // not sure how else to do this without breaking the process

	catch(var/exception/e)
		catchException(e)