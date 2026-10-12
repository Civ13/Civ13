/process/lighting_overlays
	// Detach at most one bounded FIFO batch. Dirty flags keep enqueue deduplication
	// active while budget-yielded entries wait; consumed slots release ownership.
	var/tmp/batch_index = 1
	var/tmp/processing_batch = FALSE

/process/lighting_overlays/setup()
	name = "lighting overlays process"
	schedule_interval = 0.1 SECONDS
	start_delay = 1 SECOND
	fires_at_gamestates = list(GAME_STATE_PLAYING, GAME_STATE_FINISHED)
	priority = PROCESS_PRIORITY_HIGH
	always_runs = TRUE // hacky stuff, but this is a very expensive process and it needs this
	processes.lighting_overlays = src

/process/lighting_overlays/fire()
	if (processing_batch)
		return PROCESS_TICK_CHECK_RETURNED_EARLY
	processing_batch = TRUE
	if (!current_list)
		var/batch_size = min(lighting_update_overlays.len, lighting_update_overlays.len > 1000 ? 2000 : 1000)
		current_list = lighting_update_overlays.Copy(1, batch_size + 1)
		lighting_update_overlays.Cut(1, batch_size + 1)
		batch_index = 1
	while (batch_index <= current_list.len)
		var/atom/movable/lighting_overlay/L = current_list[batch_index]
		current_list[batch_index++] = null
		if (!isDeleted(L))
			L.update_overlay()
			L.needs_update = FALSE
		if (priority != PROCESS_PRIORITY_VERY_HIGH && world.tick_usage - run_time_tick_usage >= run_time_tick_usage_allowance)
			processing_batch = FALSE
			if (batch_index <= current_list.len)
				return PROCESS_TICK_CHECK_RETURNED_EARLY
			break
	current_list = null
	processing_batch = FALSE

/process/lighting_overlays/reset_current_list()
	return

/process/lighting_overlays/copyStateFrom(process/lighting_overlays/target)
	current_list = target.current_list
	batch_index = target.batch_index
	target.current_list = null

/process/lighting_overlays/onKill()
	// A killed process must not strand dirty overlays outside the live queue.
	if (current_list)
		lighting_update_overlays.Insert(1, current_list.Copy(batch_index))
	current_list = null
	processing_batch = FALSE
