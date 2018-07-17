/process/burning_sounds/setup()
	name = "burning sounds"
	schedule_interval = 5 SECONDS
	start_delay = 10 SECONDS
	fires_at_gamestates = list(GAME_STATE_PLAYING, GAME_STATE_FINISHED)
	priority = PROCESS_PRIORITY_LOW
	processes.burning_sounds = src

/process/burning_sounds/fire()

	var/sound/S = sound('sound/effects/fire_loop.ogg')
	S.repeat = FALSE
	S.wait = FALSE
	S.volume = 50
	S.channel = 1

	for (current in current_list)
		if (current == null)
			continue
		// range(20, tcc) = checks ~500 objects (400 turfs)
		// player_list will rarely be above 100 objects
		// so this should be more efficient - Kachnov
		for (var/M in player_list)
			if (M:loc) // make sure we aren't in the lobby
				var/dist = abs_dist(M, current)
				if (dist <= 20)
					var/volume = 100
					volume -= (dist*3)
					S.volume = volume
					M << S

		PROCESS_LIST_CHECK
		// no PROCESS_TICK_CHECK here: everyone has to hear the sound

/process/burning_sounds/reset_current_list()
	PROCESS_USE_FASTEST_LIST(burning_obj_list|burning_turf_list)

/process/burning_sounds/statProcess()
	..()
	stat(null, "[player_list.len] who may hear burning sounds")

/process/burning_sounds/htmlProcess()
	return ..() + "[player_list.len] who may hear burning sounds"