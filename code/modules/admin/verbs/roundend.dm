/client/proc/trigger_roundend()
	set name = "End the round"
	set category = "Server"

	if (!check_rights(R_SERVER))
		src << "<span class = 'danger'>You don't have the permissions.</span>"
		return

	if (!ticker || ticker.current_state != GAME_STATE_PLAYING)
		src << "<span class = 'danger'>You can't end the round right now.</span>"
		return

	var/conf_1 = input("Are you absolutely positively sure you want to END THE ROUND?") in list ("Yes", "No")
	if (conf_1 == "No")
		return

	var/conf_2 = input("Seriously?") in list ("Yes", "No")
	if (conf_2 == "No")
		return

	if (map)
		map.next_win = world.time - 100
	else
		ticker.finished = TRUE

	message_admins("[key_name(src)] ended the round!")
	log_admin("[key_name(src)] ended the round!")

/client/proc/toggle_round_ending()
	set name = "Toggle Round Ending"
	set category = "Server"

	if (!check_rights(R_SERVER))
		src << "<span class = 'danger'>You don't have the permissions.</span>"
		return

	if (map)
		map.admins_triggered_noroundend = !map.admins_triggered_noroundend
		switch (map.admins_triggered_noroundend)
			if (1)
				message_admins("[key_name(src)] prevented the round from ending.")
				log_admin("[key_name(src)] prevented the round from ending.")
			if (0)
				message_admins("[key_name(src)] undid the administrative lock on the round ending.")
				log_admin("[key_name(src)] undid the administrative lock on the round ending.")
	else
		src << "<span class = 'danger'>Something went wrong.</span>"