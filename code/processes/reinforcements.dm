/process/reinforcements

/process/reinforcements/setup()
	name = "reinforcements"
	schedule_interval = 1 SECOND
	fires_at_gamestates = list(GAME_STATE_PLAYING)
	priority = PROCESS_PRIORITY_IRRELEVANT
	processes.reinforcements = src

/process/reinforcements/fire()
	if (reinforcements_master && reinforcements_master.trytostartup())
		reinforcements_master.tick()