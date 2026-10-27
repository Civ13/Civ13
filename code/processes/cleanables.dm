/process/cleanables
	var/tmp/list/turf2cleanables = null
	var/tmp/deleting = FALSE
	var/tmp/list/location_contents = null
	var/tmp/obj/effect/decal/cleanable/kept_cleanable = null

/process/cleanables/setup()
	name = "cleanable decals removal process"
	schedule_interval = 0.5 MINUTES
	start_delay = 1 SECOND
	fires_at_gamestates = list(GAME_STATE_PREGAME, GAME_STATE_SETTING_UP, GAME_STATE_PLAYING, GAME_STATE_FINISHED)
	priority = PROCESS_PRIORITY_HIGH
	processes.cleanables = src

/process/cleanables/fire()
	if (!deleting)
		// Count once across all resumes of this snapshot.
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
			// Install deletion work before a final-entry budget return.
			if (!current_list.len)
				current_list = turf2cleanables.Copy()
				deleting = current_list.len > 0
				if (!deleting)
					turf2cleanables = null
			PROCESS_TICK_CHECK
		if (!deleting)
			turf2cleanables = null
			return

	// current_list now owns pending locations, not the counted decal snapshot.
	for (current in current_list)
		var/atom/place = current
		if (isDeleted(place) || turf2cleanables[place] < 2)
			finish_location()
			PROCESS_TICK_CHECK
			continue
		if (isnull(location_contents))
			location_contents = place.contents.Copy()
		while (location_contents.len && turf2cleanables[place] >= 2)
			var/atom/A = location_contents[1]
			location_contents -= A
			if (istype(A, /obj/effect/decal/cleanable) && !isDeleted(A) && A.loc == place)
				// Keep a survivor even if other decals disappeared while pending.
				if (!isDeleted(kept_cleanable) && kept_cleanable.loc == place)
					cleanables -= kept_cleanable
					qdel(kept_cleanable)
					--turf2cleanables[place]
				kept_cleanable = A
			if (!location_contents.len || turf2cleanables[place] < 2)
				finish_location()
			PROCESS_TICK_CHECK
			if (isnull(location_contents))
				break
		if (!isnull(location_contents))
			finish_location()
			PROCESS_TICK_CHECK

/process/cleanables/proc/finish_location()
	turf2cleanables -= current
	PROCESS_LIST_CHECK
	location_contents = null
	kept_cleanable = null
	if (!current_list.len)
		turf2cleanables = null
		deleting = FALSE

/process/cleanables/reset_current_list()
	turf2cleanables = list()
	location_contents = null
	kept_cleanable = null
	deleting = FALSE
	PROCESS_USE_FASTEST_LIST(cleanables)

/process/cleanables/finished(fire_result = null)
	. = ..(fire_result)
	// Also release subclass state if a paused pass finished without firing.
	if (isnull(current_list))
		turf2cleanables = null
		location_contents = null
		kept_cleanable = null
		deleting = FALSE
