/process/mob

/process/mob/setup()
	name = "mob"
	schedule_interval = 1 SECONDS
	start_delay = 0.6 SECONDS
	fires_at_gamestates = list(GAME_STATE_PREGAME, GAME_STATE_SETTING_UP, GAME_STATE_PLAYING, GAME_STATE_FINISHED)
	priority = PROCESS_PRIORITY_HIGH
	processes.mob = src

/process/mob/fire()
	for (current in current_list)

		var/mob/M = current
		if (!M || !isliving(M))
			continue

		if (isDeleted(M))
			catchBadType(M)
			mob_list -= M
			living_mob_list -= M
			continue

		else if (istype(M, /mob/new_player))
			if (!M.client || M.client.mob != M)
				qdel(M)
			continue

		try
			// since we spent so long getting here we have to do this again
			if (!M)
				catchBadType(M)
				mob_list -= M
				living_mob_list -= M
				continue
			M.Life()
			if (!(M == null))
				if (world.time - M.last_movement > 7)
					M.velocity = 0
			if (ishuman(M) && M.client)
				zoom_processing_mobs |= M
			else
				zoom_processing_mobs -= M
		catch (var/exception/e)
			catchException(e)

		PROCESS_LIST_CHECK
		PROCESS_TICK_CHECK

/process/mob/reset_current_list()
	PROCESS_USE_FASTEST_LIST(living_mob_list)

/process/mob/statProcess()
	..()
	stat(null, "[mob_list.len] mobs")

/process/mob/htmlProcess()
	return ..() + "[mob_list.len] mobs"