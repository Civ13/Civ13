/process/paratrooper_plane
	var/altitude = 10000  // takes ~9.5 minutes to get to nonlethal altitude ((1000 - (19*500)) = 500, 19 * 30 = 570 seconds)
	var/first_nonlethal_altitude = 500
	var/tmpTime = 0
	var/list/my_turfs = list()

/process/paratrooper_plane/setup()
	name = "paratrooper plane controller"
	schedule_interval = 1 SECOND
	start_delay = 5 SECONDS
	fires_at_gamestates = list(GAME_STATE_PLAYING)
	priority = PROCESS_PRIORITY_IRRELEVANT
	processes.paratrooper_plane = src

/process/paratrooper_plane/fire()
	if (altitude <= first_nonlethal_altitude || !latejoin_turfs["Paratrooper"] || !latejoin_turfs["Paratrooper"]:len)
		return
	try
		if (!my_turfs.len)
			if (latejoin_turfs["Paratrooper"] && latejoin_turfs["Paratrooper"]:len)
				for (var/turf/T in range(10, latejoin_turfs["Paratrooper"][1]))
					my_turfs += T

		// make our pixel x different from before
		var/shift = pick(-1, 0, 1)
		while (shift == my_turfs[1].contents[1].pixel_x)
			shift = pick(-1, 0, 1)

		var/mobs = 0

		for (current in my_turfs)
			var/turf/T = current
			for (current in T.contents)
				var/atom/movable/AM = current
				if (!ismob(AM))
					AM.pixel_x = shift
				else
					++mobs

		tmpTime += schedule_interval
		if (tmpTime >= 300)
			tmpTime = 0
			if (altitude == round(initial(altitude)/2, 500) && mobs)
				world << "A plane flies overhead dropping Paratroopers."
			if (altitude <= first_nonlethal_altitude)
				return // we're done
			altitude -= 500
			for (var/mob/living/human/H in player_list)
				if (H.original_job.is_paratrooper)
					if (H.z == 2)
						H << getMessage()

	catch(var/exception/e)
		catchException(e)

/process/paratrooper_plane/proc/isLethalToJump()
	return altitude > first_nonlethal_altitude

/process/paratrooper_plane/proc/getMessage()
	return "<big><span class = 'red'>The plane's current altitude is [altitude]m. <b>It is lethal to jump</b> until it has descended to [first_nonlethal_altitude]m."

