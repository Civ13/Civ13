/process/time_of_day_change
	var/changeto = null
	var/admincaller = null
	var/announce = TRUE
	var/setup_lighting = FALSE

/process/time_of_day_change/setup()
	name = "time of day change"
	schedule_interval = 2 SECONDS
	fires_at_gamestates = list() // this doesn't fire normally
	priority = PROCESS_PRIORITY_HIGH
	always_runs = TRUE
	processes.time_of_day_change = src

// only called in lighting_system.dm
/process/time_of_day_change/fire(var/special = FALSE)
	if (!special)
		return

	var/O_time_of_day = time_of_day
	time_of_day = changeto

	if (admincaller)
		to_chat(admincaller, "<span class = 'notice'>Updated lights for [time_of_day].</span>")
		var/M = "[key_name(admincaller)] changed the time of day from [O_time_of_day] to [time_of_day]."
		log_admin(M)
		message_admins(M)

	for (var/lighting_overlay in lighting_overlay_list)
		var/atom/movable/lighting_overlay/LO = lighting_overlay
		LO.invisibility = 0
		CHECK_TICK
	setup_lighting = TRUE

	var/m_lighting_z = max_lighting_z()
	for (var/turf/T in turfs)
		if (T.z <= m_lighting_z)
			var/area/a = T.loc

			var/areacheck = TRUE
			if (map)
				for (var/area_type in map.areas_without_lighting)
					if (istype(a, area_type))
						areacheck = FALSE
						break

			if (a && a.dynamic_lighting && areacheck && (!map || !map.zlevels_without_lighting.Find(T.z)))
				T.adjust_lighting_overlay_to_daylight()

		// regardless of whether or not we use dynamic lighting here
		// we still need to change the TOD to prevent Vampire dusting
		if (T.contents.len)
			for (var/atom/movable/lighting_overlay/LO in T.contents)
				LO.TOD = time_of_day
		CHECK_TICK

	if (announce)
		for (var/M in player_list)
			to_chat(M, "<font size=3><span class = 'notice'>It's <b>[lowertext(capitalize(time_of_day))]</b>.</span></font>")
