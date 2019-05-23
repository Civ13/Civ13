/process/projectile

/process/projectile/setup()
	name = "projectile movement"
	schedule_interval = 0.03 SECONDS
	start_delay = 1 SECOND
	fires_at_gamestates = list(GAME_STATE_PREGAME, GAME_STATE_SETTING_UP, GAME_STATE_PLAYING, GAME_STATE_FINISHED)
	priority = PROCESS_PRIORITY_VERY_HIGH
	processes.projectile = src

/process/projectile/fire()

	for (current in current_list)

		var/obj/item/projectile/P = current

		// projectiles will qdel() and remove themselves from projectile_list automatically
		if (!isDeleted(P))
			if (P.loc)
				try
					P.process()
				catch (var/exception/e)
					catchException(e, P)
					log_debug("Hey a bullet just froze!")
					qdel(P)
		else
			catchBadType(P)
			projectile_list -= P

		PROCESS_LIST_CHECK
		PROCESS_TICK_CHECK

/process/projectile/reset_current_list()
	PROCESS_USE_FASTEST_LIST(projectile_list)
	if (current_list.len > 500)
		current_list.len = min(current_list.len, 500)
/process/projectile/statProcess()
	..()
	stat(null, "[projectile_list.len] projectiles")

/process/projectile/htmlProcess()
	return ..() + "[projectile_list.len] projectiles"