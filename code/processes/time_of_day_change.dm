

/process/time_of_day_change
	var/changeto = null
	var/admincaller = null
	var/announce = TRUE
	var/setup_lighting = FALSE

/process/time_of_day_change/setup()
	name = "time of day change process"
	schedule_interval = 1 SECONDS
	start_delay = 0.5 SECONDS
	fires_at_gamestates = list() // this doesn't fire normally
	priority = PROCESS_PRIORITY_IRRELEVANT
	always_runs = TRUE
	processes.time_of_day_change = src

// only called in lighting_system.dm
/process/time_of_day_change/fire(var/special = FALSE)

	if (!special)
		return

	var/list/my_turfs = turfs.Copy()

	var/O_time_of_day = time_of_day
	time_of_day = changeto

	var/turfs_len = my_turfs.len // this makes things faster and it works because single-threadedness

	#define DIVISOR 50 // less lag, approx 200 seconds on forest though

	for (var/v in 1 to turfs_len)
		spawn (ceil(v/DIVISOR)) // 100,000 turfs = 50 seconds (when DIVISOR = 200)
			var/turf/T = my_turfs[v]
			if (!T)
				continue
			if (T.z <= max_lighting_z())
				var/area/a = get_area(T)

				var/areacheck = TRUE
				if (map)
					for (var/area_type in map.areas_without_lighting)
						if (istype(a, area_type))
							areacheck = FALSE
							break

				if (a && a.dynamic_lighting && areacheck && (!map || !map.zlevels_without_lighting.Find(T.z)))
					T.adjust_lighting_overlay_to_daylight()
				else
					// todo: way to determine if walls should be dark or not
					if (locate_type(T.contents, /obj/train_track))
						var/TOD_2_rgb = min(255, round(time_of_day2luminosity[time_of_day] * 281))
						T.color = rgb(TOD_2_rgb, TOD_2_rgb, TOD_2_rgb)
						for (var/obj/train_track/TT in T.contents)
							TT.color = T.color

			// regardless of whether or not we use dynamic lighting here
			// we still need to change the TOD to prevent Vampire dusting
			for (var/atom/movable/lighting_overlay/LO in T.contents)
				LO.TOD = time_of_day

	spawn (ceil(turfs_len/DIVISOR))
		if (admincaller)
			admincaller << "<span class = 'notice'>Updated lights for [time_of_day].</span>"
			var/M = "[key_name(admincaller)] changed the time of day from [O_time_of_day] to [time_of_day]."
			log_admin(M)
			message_admins(M)

		if (announce)
			for (var/M in player_list)
				M << "<font size=3><span class = 'notice'>It's <b>[lowertext(capitalize(time_of_day))]</b>.</span></font>"

		if (!setup_lighting)
			for (var/lighting_overlay in lighting_overlay_list)
				var/atom/movable/lighting_overlay/LO = lighting_overlay
				if (LO.invisibility)
					LO.invisibility = 0

		setup_lighting = TRUE

	#undef DIVISOR