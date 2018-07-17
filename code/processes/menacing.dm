/process/menacing
	var/list/kana = list()

/process/menacing/setup()
	name = "menacing"
	schedule_interval = 2 SECONDS
	start_delay = 5 SECONDS
	fires_at_gamestates = list(GAME_STATE_PLAYING, GAME_STATE_FINISHED)
	priority = PROCESS_PRIORITY_MEDIUM
	processes.menacing = src

/process/menacing/fire()
	for (var/motherfuckingjojoreference in kana)
		qdel(motherfuckingjojoreference)
	for (current in current_list)
		var/atom/A = current
		if (!isDeleted(A))
			try
				var/list/turfs = list(get_turf(A))
				for (var/turf/T in range(1, turfs[1]))
					turfs += T
				for (var/turf/T in turfs)
					if (prob(25))
						if (ismovable(A))
							kana += new /obj/effect/kana (T, A)
						else
							kana += new /obj/effect/kana (T)
			catch(var/exception/e)
				catchException(e, A)
		else
			catchBadType(A)
			menacing_atoms -= A
		PROCESS_LIST_CHECK
		PROCESS_TICK_CHECK

/process/menacing/reset_current_list()
	PROCESS_USE_FASTEST_LIST(menacing_atoms)

/process/menacing/statProcess()
	..()
	stat(null, "[menacing_atoms.len] atoms")

/process/menacing/htmlProcess()
	return ..()  + "[menacing_atoms.len] atoms"