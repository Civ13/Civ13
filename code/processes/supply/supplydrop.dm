/process/supplydrop

/process/supplydrop/setup()
	name = "supplydrop process"
	schedule_interval = 0.5 MINUTES
	start_delay = 10 SECONDS
	fires_at_gamestates = list(GAME_STATE_PLAYING, GAME_STATE_FINISHED)
	priority = PROCESS_PRIORITY_LOW
	processes.supplydrop = src

/process/supplydrop/fire()
	for (var/l in 1 to 2)

		var/list/objects = null
		var/list/dropspots = null

		switch (l)
			if (1)
				objects = supplydrop_processing_objects_german
				dropspots = german_supplydrop_spots
			if (2)
				objects = supplydrop_processing_objects_soviet
				dropspots = soviet_supplydrop_spots

		if (!islist(objects) || !islist(dropspots))
			continue

		for (var/v in 1 to objects.len)
			spawn (v * 2)
				if (objects.len >= v)
					var/last_path = objects[v]
					if (last_path)
						try
							var/spawned = FALSE
							for (current in dropspots) // FORNEXT doesn't work here

								var/turf/T = current

								if (!T)
									continue

								if (T.density)
									continue

								if (searchloc(T, /obj/structure, TRUE))
									continue

								if (searchloc(T, /mob/living, FALSE))
									continue

								if (searchloc(T, /obj/item/weapon, FALSE))
									continue

								var/real_path = text2path(last_path)

								if (ispath(real_path))
									var/atom/A = new real_path(T)

									if (A)
										A.visible_message("<span class = 'notice'>[A] falls from the sky!</span>")
										playsound(T, 'sound/effects/bamf.ogg', rand(70,80))
										spawned = TRUE

									break

							if (spawned)
								if (objects.Find(last_path))
									objects -= last_path

						catch (var/exception/e)
							catchException(e)
					else
						if (objects.Find(last_path))
							objects -= last_path
			PROCESS_TICK_CHECK

// we don't use this, current_list will be == null
/process/lighting_sources/reset_current_list()
	return

/process/supplydrop/statProcess()
	..()
	stat(null, "[supplydrop_processing_objects_german.len+supplydrop_processing_objects_soviet.len] paths")

/process/supplydrop/htmlProcess()
	return ..() + "[supplydrop_processing_objects_german.len+supplydrop_processing_objects_soviet.len] paths"

/process/supplydrop/proc/add(var/object_path, var/faction)
	if (object_path)
		switch (faction)
			if (GERMAN)
				supplydrop_processing_objects_german += object_path
			if (SOVIET)
				supplydrop_processing_objects_soviet += object_path

/process/supplydrop/proc/searchloc(turf/location, _type, dense = FALSE)
	for (var/atom/movable/A in location.contents)
		if (istype(A, _type))
			if (!dense || (dense && A.density))
				return TRUE
	return FALSE