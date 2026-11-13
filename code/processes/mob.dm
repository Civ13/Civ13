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
			unregister_living_mob(M)
			continue

		try
			if (ecology_animal_frozen(M))
				var/mob/living/simple_animal/frozen = M
				frozen.ecology_hold_still()
			else if (!ecology_animal_resting(M) && !(persistence_frozen_levels.len && persistence_life_frozen(M)) && !(ishuman(M) && event_stash_holds(M)))
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
	ecology_advance_rest_phase()
	// Once per pass: a budgeted fire resumes many times a second, and the
	// observers used to be rebuilt on every resume.
	ecology_refresh_observers()

/process/mob/statProcess(client/C)
	..(C)
	C.add_stat(null, "[mob_list.len] mobs")

/process/mob/htmlProcess()
	return ..() + "[mob_list.len] mobs"
