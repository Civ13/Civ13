#define RIVER_SCAN_PER_TICK 4096

/process/river_current/setup()
	name = "river currents"
	schedule_interval = 5 SECONDS
	start_delay = 5 SECONDS
	priority = PROCESS_PRIORITY_LOW
	fires_at_gamestates = list(GAME_STATE_PLAYING)

/process/river_current/reset_current_list()
	river_moved.Cut()
	PROCESS_USE_FASTEST_LIST(river_active_water)

/process/river_current/fire()
	// Pick up mapped and restored occupants even if they entered before map setup.
	if (isnull(river_initial_scan))
		river_initial_scan = water_turf_list.Copy()
	while (river_scan_index <= river_initial_scan.len && river_scan_index <= RIVER_SCAN_PER_TICK)
		var/turf/floor/beach/water/T = river_initial_scan[river_scan_index++]
		if (istype(T))
			T.river_wake_if_occupied()
	if (river_scan_index > RIVER_SCAN_PER_TICK)
		river_initial_scan.Cut(1, river_scan_index)
		river_scan_index = 1
	for (current in current_list)
		var/turf/floor/beach/water/T = current
		if (!istype(T))
			river_active_water -= current
		else
			T.river_current_step()
		PROCESS_LIST_CHECK
		PROCESS_TICK_CHECK

#undef RIVER_SCAN_PER_TICK
