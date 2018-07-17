/process/burning_objs/setup()
	name = "burning objs"
	schedule_interval = 5 SECONDS
	start_delay = 10 SECONDS
	fires_at_gamestates = list(GAME_STATE_PLAYING, GAME_STATE_FINISHED)
	priority = PROCESS_PRIORITY_MEDIUM
	processes.burning_objs = src

/process/burning_objs/fire()

	for (current in current_list)
		var/obj/O = current
		if (!isDeleted(O))
			try
				if (prob(5))
					for (var/v in 2 to 3)
						new/obj/effect/decal/cleanable/ash(get_turf(O))
					burning_obj_list -= O
					qdel(O)
				else if (prob(10))
					new/obj/effect/effect/smoke/bad(get_turf(O), TRUE)
			catch(var/exception/e)
				catchException(e, O)
		else
			catchBadType(O)
			burning_obj_list -= O

		PROCESS_LIST_CHECK
		PROCESS_TICK_CHECK

/process/burning_objs/reset_current_list()
	PROCESS_USE_FASTEST_LIST(burning_obj_list)

/process/burning_objs/statProcess()
	..()
	stat(null, "[burning_obj_list.len] objects")

/process/burning_objs/htmlProcess()
	return ..() + "[burning_obj_list.len] objects"