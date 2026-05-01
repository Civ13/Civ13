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
	var/queue_length = lighting_update_overlays.len
	var/max_updates_per_tick = 1000

	// Scale max_updates_per_tick based on queue length
	if (queue_length > 1000)
		//log_debug("lighting_overlays: Warning - queue length is [queue_length], scaling processing rate")
		max_updates_per_tick = min(queue_length, max_updates_per_tick * 2)

	var/count = 0
	var/list/update_list = lighting_update_overlays.Copy()
	for (var/atom/movable/lighting_overlay/L in update_list)
		if (count++ >= max_updates_per_tick)
			break

		if (!isDeleted(L))
			L.update_overlay()
			L.needs_update = FALSE

		lighting_update_overlays -= L

		PROCESS_TICK_CHECK

/process/lighting_overlays/reset_current_list()
	return