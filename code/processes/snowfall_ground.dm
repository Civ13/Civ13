/process/snowfall_ground/setup()
	name = "snowfall ground cover"
	schedule_interval = SNOWFALL_GROUND_INTERVAL
	start_delay = 10 SECONDS
	priority = PROCESS_PRIORITY_LOW
	fires_at_gamestates = list(GAME_STATE_PLAYING)
	processes.snowfall_ground = src

/process/snowfall_ground/fire()
	if (persistence_save_in_progress || persistence_active_operation || persistence_load_recovery_required || world.time < snowfall_ground_next)
		return
	snowfall_ground_next = world.time + SNOWFALL_GROUND_INTERVAL
	var/checks = min(SNOWFALL_GROUND_BATCH, snowfall_ground.len)
	while (checks-- > 0 && snowfall_ground.len)
		if (snowfall_ground_cursor > snowfall_ground.len)
			snowfall_ground_cursor = 1
		var/turf/T = snowfall_ground[snowfall_ground_cursor]
		var/index = snowfall_ground_cursor
		if (T && T.snowfall_ground_index == index)
			T.snowfall_ground_check()
		snowfall_ground_cursor++
		if (world.tick_usage >= 20)
			break

/process/snowfall_ground/reset_current_list()
	return // Never copy the candidate registry.
