/process/mapswap
	// map = required players
	var/list/maps = list(
		MAP_NAVAL = 0,
		MAP_ISLAND = 0,
//		MAP_VOYAGE = 10,
		MAP_ROBUSTA = 20,
//		MAP_BATTLEROYALE = 20,
		MAP_SUPPLY_RAID = 8,
		MAP_RECIFE = 10,
		MAP_COLONY = 10,
		MAP_FOUR_COLONIES = 25,
		MAP_TRIBES = 10,
	)

	var/ready = TRUE
	var/admin_triggered = FALSE
	var/finished_at = -1
	var/next_map_title = "Naval"

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
		// round will end soon (tm)
		else if (map && map.admins_triggered_roundend)
			. = TRUE
		else if (ticker.finished)
			. = TRUE
	return .

/process/mapswap/proc/swap(var/winner = "Naval")
	next_map_title = winner
	winner = uppertext(winner)
	if (!maps.Find(winner))
		winner = maps[1]
	// there used to be messages here about success and failure but they lie so they're gone - Kachnov
	processes.python.execute("mapswap.py", list(winner))
