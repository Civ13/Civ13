/process/self_cleaning

/process/self_cleaning/setup()
	name = "self-cleaning decals"
	schedule_interval = 10 SECONDS
	start_delay = 2 SECONDS
	fires_at_gamestates = list(GAME_STATE_PLAYING)
	priority = PROCESS_PRIORITY_MEDIUM
	processes.self_cleaning = src

/process/self_cleaning/fire()

	var/deleted = 0

	for (current in current_list)
		if (!isDeleted(current))
			var/area/A = get_area(current)
			if (A && A.weather == WEATHER_RAIN)
				qdel(current)
				++deleted
				if (deleted >= 100)
					break
		else
			catchBadType(current)
			cleanables -= current

		PROCESS_LIST_CHECK
		PROCESS_TICK_CHECK

/process/self_cleaning/reset_current_list()
	PROCESS_USE_FASTEST_LIST(cleanables)