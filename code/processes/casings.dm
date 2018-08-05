/process/casings

/process/casings/setup()
	name = "bullet casings removal process"
	schedule_interval = 5 SECONDS
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

	// delete casings
	for (var/loc in turf2casings)
		if (turf2casings[loc] >= 2 && turf2casings[loc] <= 9)
			var/deleted = 0
			for (var/obj/item/ammo_casing/A in loc)
				bullet_casings -= A
				qdel(A)
				++deleted
				if (deleted >= turf2casings[loc]-1)
					break

/process/casings/reset_current_list()
	PROCESS_USE_FASTEST_LIST(bullet_casings)