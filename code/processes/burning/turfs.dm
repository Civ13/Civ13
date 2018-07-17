/process/burning_turfs/setup()
	name = "burning turfs"
	schedule_interval = 5 SECONDS
	start_delay = 10 SECONDS
	fires_at_gamestates = list(GAME_STATE_PLAYING, GAME_STATE_FINISHED)
	priority = PROCESS_PRIORITY_MEDIUM
	processes.burning_turfs = src

/process/burning_turfs/fire()

	for (current in current_list)
		var/turf/T = current
		if (!isDeleted(T) && T.density)
			try
				if (prob(3))
					for (var/v in 4 to 5)
						new/obj/effect/decal/cleanable/ash(T)
					burning_turf_list -= T
					T.ex_act(1.0)
				else if (prob(10))
					new/obj/effect/effect/smoke/bad(T, TRUE)
			catch(var/exception/e)
				catchException(e, T)
		else
			catchBadType(T)
			burning_turf_list -= T
		PROCESS_TICK_CHECK

/process/burning_turfs/reset_current_list()
	PROCESS_USE_FASTEST_LIST(burning_turf_list)

/process/burning_turfs/statProcess()
	..()
	stat(null, "[burning_turf_list.len] turfs")

/process/burning_turfs/htmlProcess()
	return ..() + "[burning_turf_list.len] turfs"