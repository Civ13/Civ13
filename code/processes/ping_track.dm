// ported from /tg/station - Kachnov
/process/ping_track
	var/avg = 0
	var/client_ckey_check[1000]
	var/tmp/ping_total = 0
	var/tmp/clients_checked = 0

/process/ping_track/setup()
	name = "Ping Tracking"
	schedule_interval = 0.5 SECONDS
	fires_at_gamestates = list(GAME_STATE_PREGAME, GAME_STATE_SETTING_UP, GAME_STATE_PLAYING, GAME_STATE_FINISHED)
	priority = PROCESS_PRIORITY_LOW
	processes.ping_track = src

/process/ping_track/fire()

	if (!current_list.len)
		return

	if (world && world.time > 864000)
		avg = 0
		ping_total = 0
		clients_checked = 0
		disabled = TRUE
		return

	for (current in current_list)
		var/client/C = current
		track_client(C)
		PROCESS_LIST_CHECK
		// Publish before the final budget check can return from fire().
		if (!current_list.len)
			avg = clients_checked ? ping_total / clients_checked : 0
			ping_total = 0
			clients_checked = 0
		PROCESS_TICK_CHECK

/process/ping_track/proc/track_client(client/C)
	if (!C)
		return

	// BYOND treats "update_ping" and ".update_ping" the same for hascall.
	if (!hascall(C, ".update_ping"))
		return
	if (!client_ckey_check[C.ckey])
		client_ckey_check[C.ckey] = world.time+100
		return
	if (world.time < client_ckey_check[C.ckey])
		return

	winset(C, null, "command=.update_ping+[world.time+world.tick_lag*world.tick_usage/100]")
	if (C)
		ping_total += C.last_ping
	++clients_checked

/process/ping_track/reset_current_list()
	ping_total = 0
	clients_checked = 0
	PROCESS_USE_FASTEST_LIST(clients)
