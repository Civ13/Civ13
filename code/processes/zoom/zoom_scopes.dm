/process/zoom_scopes

/process/zoom_scopes/setup()
	name = "zoom scopes"
	schedule_interval = 0.7 SECONDS
	start_delay = 2 SECONDS
	fires_at_gamestates = list(GAME_STATE_PLAYING, GAME_STATE_FINISHED)
	priority = PROCESS_PRIORITY_MEDIUM
	processes.zoom_scopes = src

/process/zoom_scopes/fire()

	// update gun, scope (in)visibility
	for (current in current_list)
		var/obj/item/weapon/attachment/scope/S = current

		if (!isDeleted(S))
			try
				if (S.scoped_invisible)
					S.invisibility = 0
					S.scoped_invisible = FALSE
				else if (istype(S.loc, /obj/item/weapon/gun))
					var/obj/item/weapon/gun/G = S.loc
					G.invisibility = 0
					G.scoped_invisible = FALSE
				zoom_scopes_list -= S
			catch(var/exception/e)
				catchException(e, S)
		else
			catchBadType(S)
			zoom_scopes_list -= S

		PROCESS_LIST_CHECK
		PROCESS_TICK_CHECK

/process/zoom_scopes/reset_current_list()
	PROCESS_USE_FASTEST_LIST(zoom_scopes_list)

/process/zoom_scopes/statProcess()
	..()
	stat(null, "[zoom_scopes_list.len] scopes")

/process/zoom_scopes/htmlProcess()
	return ..() + "[zoom_scopes_list.len] scopes"
