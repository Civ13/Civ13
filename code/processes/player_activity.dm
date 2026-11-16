// Fires the player activity recorder once a minute: a heartbeat every five
// minutes, then a flush (code/modules/player_activity/player_activity.dm).
/process/player_activity/setup()
	name = "player activity"
	schedule_interval = (60 SECONDS)
	start_delay = (60 SECONDS)
	priority = PROCESS_PRIORITY_IRRELEVANT
	fires_at_gamestates = list(GAME_STATE_PREGAME, GAME_STATE_SETTING_UP, GAME_STATE_PLAYING, GAME_STATE_FINISHED)
	player_activity.last_heartbeat = world.time

/process/player_activity/fire()
	player_activity.tick()

/process/player_activity/reset_current_list()
	return // nothing is iterated across fires
