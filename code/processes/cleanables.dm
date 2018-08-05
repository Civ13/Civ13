/process/cleanables

/process/cleanables/setup()
	name = "cleanable decals removal process"
	schedule_interval = 5 SECONDS
	start_delay = 1 SECOND
	fires_at_gamestates = list(GAME_STATE_PREGAME, GAME_STATE_SETTING_UP, GAME_STATE_PLAYING, GAME_STATE_FINISHED)
	priority = PROCESS_PRIORITY_HIGH
	processes.cleanables = src

/process/cleanables/fire()
	var/list/turf2cleanables = list()

	// get cleanable decals
	for (current in current_list)
		var/obj/effect/decal/cleanable/C = current
		if (!isDeleted(C))
			if (!turf2cleanables[C.loc])
				turf2cleanables[C.loc] = 0
			++turf2cleanables[C.loc]
		else
			catchBadType(C)
			cleanables -= C
		PROCESS_LIST_CHECK
		PROCESS_TICK_CHECK

	// delete cleanable decals
	for (var/loc in turf2cleanables)
		if (turf2cleanables[loc] >= 2)
			var/deleted = 0
			for (var/obj/effect/decal/cleanable/C in loc)
				cleanables -= C
				qdel(C)
				++deleted
				if (deleted >= turf2cleanables[loc]-1)
					break

/process/cleanables/reset_current_list()
	PROCESS_USE_FASTEST_LIST(cleanables)