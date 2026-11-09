// Ground pollution: spreads queued emissions and decays polluted turfs in
// bounded batches. See code/modules/ecology/pollution.dm.
/process/pollution/setup()
	name = "ground pollution"
	schedule_interval = 10 SECONDS
	start_delay = 10 SECONDS
	priority = PROCESS_PRIORITY_LOW
	fires_at_gamestates = list(GAME_STATE_PREGAME, GAME_STATE_SETTING_UP, GAME_STATE_PLAYING, GAME_STATE_FINISHED)

/process/pollution/fire()
	// The saver owns turf fields while it captures them.
	if (persistence_active_operation)
		return
	pollution_flush_pending()
	pollution_decay_batch()

/process/pollution/reset_current_list()
	return // No copied candidate list.
