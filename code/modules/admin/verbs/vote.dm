//dont use this! use epoch vote
/client/proc/start_epochswap_vote()
	set category = "Server"
	set name = "Start Epoch Vote"
	if (!check_rights(R_ADMIN))
		return
	if (processes.epochswap)
		processes.epochswap.restart_triggered = TRUE
		processes.epochswap.ready = TRUE
		processes.epochswap.fire()
		log_admin("[key_name(usr)] triggered am epoch vote.")
		message_admins("[key_name(usr)] triggered an epoch vote.")
	else
		to_chat(src, "<span class = 'notice'>There is no processes.epochswap datum, or it is not ready.</span>")