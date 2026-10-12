/process/lighting_sources
	var/tmp/batch_index = 1
	var/tmp/processing_batch = FALSE

/process/lighting_sources/setup()
	name = "lighting sources process"
	schedule_interval = 0.1 SECONDS
	start_delay = 1 SECOND
	fires_at_gamestates = list(GAME_STATE_PLAYING, GAME_STATE_FINISHED)
	priority = PROCESS_PRIORITY_HIGH
	always_runs = TRUE // hacky stuff, but this is a very expensive process and it needs this
	processes.lighting_sources = src

/process/lighting_sources/fire()
	if (processing_batch)
		return PROCESS_TICK_CHECK_RETURNED_EARLY
	processing_batch = TRUE
	if (!current_list)
		var/batch_size = min(lighting_update_lights.len, 2000)
		current_list = lighting_update_lights.Copy(1, batch_size + 1)
		lighting_update_lights.Cut(1, batch_size + 1)
		batch_index = 1
	while (batch_index <= current_list.len)
		current = current_list[batch_index]
		current_list[batch_index++] = null
		if (!isDeleted(current))

			var/datum/light_source/L = current
			. = L.check()
			if (L.destroyed || . || L.force_update)
				L.remove_lum()
				if (!L.destroyed)
					L.apply_lum()

			else if (L.vis_update)	// We smartly update only tiles that became (in) visible to use.
				L.smart_vis_update()

			L.vis_update   = FALSE
			L.force_update = FALSE
			L.needs_update = FALSE
		else
			catchBadType(current)
		current = null
		if (world.tick_usage - run_time_tick_usage >= run_time_tick_usage_allowance)
			processing_batch = FALSE
			if (batch_index <= current_list.len)
				return PROCESS_TICK_CHECK_RETURNED_EARLY
			break
	current_list = null
	processing_batch = FALSE

/process/lighting_sources/reset_current_list()
	return
