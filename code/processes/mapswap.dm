/process/mapswap
	// map = required players
	var/list/maps = list(
		MAP_CITY = 0,
		MAP_FOREST = 20,
		MAP_TOWER = 0,
		MAP_CAMP = 15,
//		MAP_SURVIVAL = 0, until its fixed
		MAP_REICHSTAG = 0,
//		MAP_ESCORT = 15,
//		MAP_FOREST_NEW = 25,
		MAP_ISLAND = 10,
		MAP_PARTISAN = 0
	)

	var/ready = TRUE
	var/admin_triggered = FALSE
	var/finished_at = -1
	var/next_map_title = "City"

/process/mapswap/setup()
	name = "mapswap"
	schedule_interval = 5 SECONDS
	start_delay = 5 SECONDS
	fires_at_gamestates = list(GAME_STATE_PLAYING, GAME_STATE_FINISHED)
	priority = PROCESS_PRIORITY_IRRELEVANT
	processes.mapswap = src

/process/mapswap/fire()
	// no SCHECK here
	if (is_ready())
		ready = FALSE
		vote.initiate_vote("map", "MapSwap Process", TRUE, list(src, "swap"))

/process/mapswap/proc/is_ready()
	. = FALSE

	if (ready)
		if (admin_triggered)
			. = TRUE
		// 60 minutes have passed
		else if (ticks >= 720)
			. = TRUE
		// round will end soon (tm)
		else if (map && map.next_win_time() <= ((map.short_win_time() / 600) * 0.60) && map.next_win != -1)
			. = TRUE
		else if (map && map.admins_triggered_roundend)
			. = TRUE
		else if (ticker.finished)
			. = TRUE
	return .

/process/mapswap/proc/swap(var/winner = "City")
	next_map_title = winner
	winner = uppertext(winner)
	if (!maps.Find(winner))
		winner = maps[1]
	// there used to be messages here about success and failure but they lie so they're gone - Kachnov
	processes.python.execute("mapswap.py", list(winner))
