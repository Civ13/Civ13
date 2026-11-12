/process/map

/process/map/setup()
	name = "map process"
	schedule_interval = 2 SECONDS
	fires_at_gamestates = list(GAME_STATE_PREGAME, GAME_STATE_SETTING_UP, GAME_STATE_PLAYING, GAME_STATE_FINISHED)
	priority = PROCESS_PRIORITY_IRRELEVANT
	processes.map = src

/process/map/fire()
	if (map)
		map.tick()
		// Book research: has the current era lost its last written record? (era_loss.dm)
		if (ticker && ticker.current_state == GAME_STATE_PLAYING)
			map.era_loss_tick()
