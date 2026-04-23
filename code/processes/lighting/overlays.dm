/process/lighting_overlays

/process/lighting_overlays/setup()
	name = "lighting overlays process"
	schedule_interval = 0.5 SECONDS
	start_delay = 1 SECOND
	fires_at_gamestates = list(GAME_STATE_PLAYING, GAME_STATE_FINISHED)
	priority = PROCESS_PRIORITY_HIGH
	always_runs = TRUE // hacky stuff, but this is a very expensive process and it needs this
	processes.lighting_overlays = src

/process/lighting_overlays/fire()
	var/max_updates_per_tick = 100
	var/count = 0
	for (var/atom/movable/lighting_overlay/L in lighting_update_overlays)
		if (count++ >= max_updates_per_tick)
			break

		if (!isDeleted(L))
			L.update_overlay()
			L.needs_update = FALSE

		lighting_update_overlays -= L

		PROCESS_TICK_CHECK

/process/lighting_overlays/reset_current_list()
	return