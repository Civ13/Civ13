/process/lighting_overlays

/process/lighting_overlays/setup()
	name = "lighting overlays process"
	schedule_interval = 0.1 SECONDS
	start_delay = 1 SECOND
	fires_at_gamestates = list(GAME_STATE_PLAYING, GAME_STATE_FINISHED)
	priority = PROCESS_PRIORITY_HIGH
	always_runs = TRUE // hacky stuff, but this is a very expensive process and it needs this
	processes.lighting_overlays = src

/process/lighting_overlays/fire()

	for (current in lighting_update_overlays)
		if (!isDeleted(current))
			var/atom/movable/lighting_overlay/L = current
			L.update_overlay()
			L.needs_update = FALSE
			lighting_update_overlays -= L
		else
			catchBadType(current)
			lighting_update_overlays -= current

		PROCESS_TICK_CHECK

/process/lighting_overlays/reset_current_list()
	return