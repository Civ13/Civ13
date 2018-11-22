//dont use this! use epoch vote
/client/proc/start_mapswap_vote()
	set category = "Server"
	set name = "Start Map Vote"
	if (!check_rights(R_ADMIN))
		return
	if (processes.mapswap)
		processes.mapswap.admin_triggered = TRUE
		processes.mapswap.ready = TRUE
		processes.mapswap.fire()
		log_admin("[key_name(usr)] triggered a map vote.")
		message_admins("[key_name(usr)] triggered a map vote.")
	else
		src << "<span class = 'notice'>There is no processes.mapswap datum, or it is not ready.</span>"

/client/proc/start_epochswap_vote()
	set category = "Server"
	set name = "Start Epoch Vote"
	if (!check_rights(R_ADMIN))
		return
	if (processes.epochswap)
		processes.epochswap.admin_triggered = TRUE
		processes.epochswap.ready = TRUE
		processes.epochswap.fire()
		log_admin("[key_name(usr)] triggered am epoch vote.")
		message_admins("[key_name(usr)] triggered an epoch vote.")
	else
		src << "<span class = 'notice'>There is no processes.epochswap datum, or it is not ready.</span>"