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

/client/proc/end_vote_early()
	set category = "Server"
	set name = "End Vote Early"
	set desc = "Close the current vote now, using the votes cast so far."
	if (!check_rights(R_ADMIN)) return
	if (!vote.mode || !vote.active_request)
		to_chat(src, "There is no vote running.")
		return
	if (alert(src, "End the [vote.mode] vote now on the current votes?", "End Vote Early", "End it", "Cancel") != "End it") return
	if (!vote.admin_close(key))
		to_chat(src, "The vote already ended.")

/client/proc/force_vote_choice()
	set category = "Server"
	set name = "Force Vote Choice"
	set desc = "End the current vote with the option you pick."
	if (!check_rights(R_ADMIN)) return
	if (!vote.mode || !vote.active_request)
		to_chat(src, "There is no vote running.")
		return
	var/running = vote.generation
	var/list/options = list()
	for (var/choice in vote.choices)
		var/label = choice
		if ((vote.mode in list("map", "safehouse map")) && map_id_to_title[choice])
			label = map_id_to_title[choice]
		if (vote.disabled.Find(choice))
			label = "[label] (normally unavailable)"
		options[label] = choice
	var/picked = input(src, "Which option should win the [vote.mode] vote?", "Force Vote Choice") as null|anything in options
	if (!picked) return
	if (vote.generation != running || !vote.admin_close(key, options[picked]))
		to_chat(src, "That vote already ended.")
