/process/obj/setup()
	name = "obj"
	schedule_interval = 2 SECONDS
	start_delay = 0.8 SECONDS
	fires_at_gamestates = list(GAME_STATE_PLAYING, GAME_STATE_FINISHED)
	priority = PROCESS_PRIORITY_MEDIUM
	processes.obj = src

/process/obj/fire()
	for (current in current_list)
		var/obj/O = current
		if (!isDeleted(O))
			try
				if (O.process() == PROCESS_KILL)
					processing_objects -= O
			catch(var/exception/e)
				catchException(e, O)
		else
			catchBadType(O)
			processing_objects -= O
		PROCESS_LIST_CHECK
		PROCESS_TICK_CHECK

/process/obj/reset_current_list()
	PROCESS_USE_FASTEST_LIST(processing_objects)

/process/obj/statProcess()
	..()
	stat(null, "[processing_objects.len] objects in the vital loop")

/process/obj/htmlProcess()
	return ..() + "[processing_objects.len] objects in the vital loop"