/process/info

/process/info/setup()
	name = "info"
	schedule_interval = 1 SECOND
	start_delay = 10 SECONDS
	fires_at_gamestates = list(GAME_STATE_PREGAME, GAME_STATE_SETTING_UP, GAME_STATE_PLAYING, GAME_STATE_FINISHED)
	priority = PROCESS_PRIORITY_IRRELEVANT
	processes.info = src

/process/info/fire()
	return

/process/info/statProcess()
	..()
	stat(null, "Current BYOND tick: #[world.time/world.tick_lag]")

/process/info/htmlProcess()
	return ..() + "Current BYOND tick: #[world.time/world.tick_lag]"