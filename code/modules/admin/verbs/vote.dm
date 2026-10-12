//dont use this! use epoch vote
/client/proc/start_epochswap_vote()
	set category = "Server"
	set name = "Start Epoch Vote"
	if (!check_rights(R_ADMIN))
		return
	if (!vote.disruptive_votes_enabled)
		to_chat(src, "Round-ending votes are disabled by an administrator.")
		return
	if (processes.epochswap)
		processes.epochswap.restart_triggered = TRUE
		processes.epochswap.ready = TRUE
		processes.epochswap.fire()
		log_admin("[key_name(usr)] triggered am epoch vote.")
		message_admins("[key_name(usr)] triggered an epoch vote.")
	else
		to_chat(src, "<span class = 'notice'>There is no processes.epochswap datum, or it is not ready.</span>")

/client/proc/toggle_disruptive_votes()
	set category = "Server"
	set name = "Toggle Round-Ending Votes"
	if (!check_rights(R_ADMIN)) return
	vote.set_disruptive_votes(!vote.disruptive_votes_enabled)
	var/status = vote.disruptive_votes_enabled ? "enabled" : "disabled"
	log_admin("[key_name(usr)] [status] automatic and manual round-ending votes.")
	message_admins("[key_name(usr)] [status] automatic and manual round-ending votes.")
