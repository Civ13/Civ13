// Seeing down through open air (code/modules/multiz/open_air_view.dm): links the
// open-air cells around each player's screen to the level below.
/process/open_air_view/setup()
	name = "open air view"
	schedule_interval = 1 SECONDS
	start_delay = 10 SECONDS
	priority = PROCESS_PRIORITY_LOW
	fires_at_gamestates = list(GAME_STATE_PREGAME, GAME_STATE_SETTING_UP, GAME_STATE_PLAYING, GAME_STATE_FINISHED)

/process/open_air_view/fire()
	// The saver owns turf fields and the lighting registry while it works.
	if (open_air_view_busy())
		return
	for (var/client/C in clients)
		// One failing viewer must not stop the scan for everyone after it.
		try
			C.open_air_view_scan()
		catch (var/exception/scan_error)
			open_air_view_error(scan_error, C.eye)
		PROCESS_TICK_CHECK
	open_air_view_sync_fixed()
	// Proxies whose thing moved without a move hook, or went.
	for (var/obj/effect/open_air_proxy/P in open_air_proxies)
		P.open_air_proxy_check()
		PROCESS_TICK_CHECK

/process/open_air_view/reset_current_list()
	return
