/process/time_of_day_change
	var/changeto = null
	var/admincaller = null
	var/announce = TRUE
	var/setup_lighting = FALSE
	var/updating_lighting = FALSE
	var/lighting_revision = 0

/process/time_of_day_change/setup()
	name = "time of day change"
	schedule_interval = 2 SECONDS
	fires_at_gamestates = list() // this doesn't fire normally
	priority = PROCESS_PRIORITY_HIGH
	always_runs = TRUE
	processes.time_of_day_change = src

// Requests share one worker. Calls during a yield replace the pending target.
/process/time_of_day_change/fire(var/special = FALSE)
	if (!special)
		return
	lighting_revision++
	if (updating_lighting)
		return
	updating_lighting = TRUE
	try
		while (TRUE)
			var/revision = lighting_revision
			var/target = changeto
			var/client/request_admin = admincaller
			var/do_announce = announce
			var/old_time = time_of_day
			time_of_day = target
			if (!apply_daylight(target, revision))
				continue
			apply_time_of_day_effects(target)
			if (request_admin)
				to_chat(request_admin, "<span class = 'notice'>Updated lights for [target].</span>")
				var/message = "[key_name(request_admin)] changed the time of day from [old_time] to [target]."
				log_admin(message)
				message_admins(message)
			if (do_announce)
				for (var/M in player_list)
					to_chat(M, "<font size=3><span class = 'notice'>It's <b>[lowertext(capitalize(target))]</b>.</span></font>")
			break
	catch (var/exception/E)
		updating_lighting = FALSE
		admincaller = null
		throw E
	updating_lighting = FALSE
	admincaller = null

/process/time_of_day_change/proc/apply_daylight(target, revision)
	var/work = 0
	for (var/lighting_overlay in lighting_overlay_list)
		var/atom/movable/lighting_overlay/LO = lighting_overlay
		LO.invisibility = 0
		if (environment_sweep_pause(++work))
			work = 0
			if (revision != lighting_revision)
				return FALSE
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
		// All overlays carry TOD, including excluded areas/z levels for vampires.
		if (T.contents.len)
			for (var/atom/movable/lighting_overlay/LO in T.contents)
				LO.TOD = target
		if (environment_sweep_pause(++work))
			work = 0
			if (revision != lighting_revision)
				return FALSE
	return TRUE
