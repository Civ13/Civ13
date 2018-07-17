/process/client
	var/list/logged_next_normal_respawns[500] // stop people from logging off to reset respawn delay

/process/client/setup()
	name = "client"
	schedule_interval = 5 SECONDS
	start_delay = 10
	fires_at_gamestates = list()
	priority = PROCESS_PRIORITY_IRRELEVANT
	processes.client = src

/process/client/fire()
	return