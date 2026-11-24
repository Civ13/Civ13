// Seeing down through open air (code/modules/multiz/open_air_view.dm): links the
// open-air cells around each player's screen to the level below.
/process/open_air_view
	var/tmp/work_index = 1
	var/tmp/list/paused_work

/process/open_air_view/setup()
	name = "open air view"
	schedule_interval = 1 SECONDS
	start_delay = 10 SECONDS
	priority = PROCESS_PRIORITY_LOW
	fires_at_gamestates = list(GAME_STATE_PREGAME, GAME_STATE_SETTING_UP, GAME_STATE_PLAYING, GAME_STATE_FINISHED)

/process/open_air_view/fire()
	while (work_index <= length(current_list))
		// Ownership can change between budget slices. Keep the unprocessed work,
		// but let the scheduler wait its ordinary interval while the world is busy.
		if (open_air_view_busy())
			paused_work = current_list
			current_list = null
			return
		var/work = current_list[work_index]
		current_list[work_index++] = null
		if (work_index > current_list.len)
			current_list = null
		refresh_work(work)
		PROCESS_TICK_CHECK

/process/open_air_view/proc/refresh_work(work)
	var/atom/where
	try
		if (istype(work, /client))
			var/client/C = work
			// A reconnect gets its own slot in the next pass, not the old client's.
			if (directory[C.ckey] == C)
				where = C.eye
				C.open_air_view_scan()
		else if (istype(work, /obj/effect/open_air_view))
			var/obj/effect/open_air_view/V = work
			if (!QDELETED(V))
				where = V.shows
				V.open_air_view_sync()
		else if (istype(work, /obj/effect/open_air_proxy))
			var/obj/effect/open_air_proxy/P = work
			if (!QDELETED(P))
				where = P.loc
				P.open_air_proxy_check()
	catch (var/exception/scan_error)
		// One failed viewer, fixed view or proxy must not stop the rest.
		open_air_view_error(scan_error, where)

/process/open_air_view/reset_current_list()
	if (open_air_view_busy())
		return
	if (paused_work)
		current_list = paused_work
		paused_work = null
		return
	// Snapshot only the existing work registries, never map cells. Use indexed
	// slots so retiring a processed proxy does not shift the remaining work.
	current_list = clients.Copy()
	current_list += open_air_views_fixed
	current_list += open_air_proxies
	work_index = 1
