// Counts one minute of play for every played character and checks the
// accolades that come from time (code/modules/accolades/accolades.dm).
/process/accolades/setup()
	name = "accolades"
	schedule_interval = (60 SECONDS)
	start_delay = (60 SECONDS)
	priority = PROCESS_PRIORITY_IRRELEVANT
	fires_at_gamestates = list(GAME_STATE_PLAYING)

/process/accolades/fire()
	accolades_tick()

/process/accolades/reset_current_list()
	return // one pass per fire
