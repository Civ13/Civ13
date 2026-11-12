/client/proc/toggle_round_ending()
	set name = "Toggle Round Ending"
	set category = "Server"

	if (!check_rights(R_SERVER))
		to_chat(src, "<span class = 'danger'>You don't have the permissions.</span>")
		return

	if (map)
		map.admins_triggered_noroundend = !map.admins_triggered_noroundend
		switch (map.admins_triggered_noroundend)
			if (1)
				message_admins("[key_name(src)] prevented the round from ending.", key_name(usr))
				log_admin("[key_name(src)] prevented the round from ending.")
			if (0)
				message_admins("[key_name(src)] undid the administrative lock on the round ending.", key_name(usr))
				log_admin("[key_name(src)] undid the administrative lock on the round ending.")
	else
		to_chat(src, "<span class = 'danger'>Something went wrong.</span>")

// Stops or allows sites being loaded onto planes of an orbit world, for when
// memory is tight (craft/plane_pool.dm). Planes already held are untouched,
// and stations still claim their own decks and sectors.
/client/proc/toggle_orbit_site_loading()
	set name = "Toggle Orbit Site Loading"
	set category = "Server"

	if (!check_rights(R_SERVER))
		to_chat(src, "<span class = 'danger'>You don't have the permissions.</span>")
		return
	var/datum/plane_pool/orbit/pool = orbit_pool()
	if (!pool)
		to_chat(src, "This is not an orbit world.")
		return
	pool.set_paused(!pool.is_paused())
	message_admins("[key_name(src)] [pool.is_paused() ? "paused" : "resumed"] orbit site loading ([length(pool.free_planes())] planes free).", key_name(usr))
	log_admin("[key_name(src)] [pool.is_paused() ? "paused" : "resumed"] orbit site loading.")
