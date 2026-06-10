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