/process/casings

/process/casings/setup()
	name = "casings"
	schedule_interval = 10 SECONDS
	start_delay = 1 SECOND
	fires_at_gamestates = list(GAME_STATE_PREGAME, GAME_STATE_SETTING_UP, GAME_STATE_PLAYING, GAME_STATE_FINISHED)
	priority = PROCESS_PRIORITY_HIGH
	processes.casings = src

/process/casings/fire()
	// Remove retired casings from the registry while preserving the process budget checks.
	for (current in current_list)
		var/obj/item/ammo_casing/A = current
		if (isDeleted(A))
			catchBadType(A)
			bullet_casings -= A

		PROCESS_LIST_CHECK
		PROCESS_TICK_CHECK

/process/casings/reset_current_list()
	PROCESS_USE_FASTEST_LIST(bullet_casings)
