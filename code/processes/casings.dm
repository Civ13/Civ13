/process/casings

/process/casings/setup()
	name = "casings"
	is_subsystem_member = TRUE
	schedule_interval = 30 SECONDS
	start_delay = 1 SECOND
	fires_at_gamestates = list(GAME_STATE_PREGAME, GAME_STATE_SETTING_UP, GAME_STATE_PLAYING, GAME_STATE_FINISHED)
	priority = PROCESS_PRIORITY_HIGH
	processes.casings = src

/process/casings/fire()
	var/list/turf2casings = list()

	// get casings
	for (current in current_list)
		var/obj/item/ammo_casing/A = current
		if (!isDeleted(A))
			if (A.loc && isturf(A.loc)) // so we don't delete ammo casings in guns or mags or nullspace
				if (!turf2casings[A.loc])
					turf2casings[A.loc] = 0
				++turf2casings[A.loc]
		else
			catchBadType(A)
			bullet_casings -= A

		PROCESS_LIST_CHECK
		PROCESS_TICK_CHECK

/process/casings/reset_current_list()
	PROCESS_USE_FASTEST_LIST(bullet_casings)