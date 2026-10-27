/client/proc/reset_faction_symbol()
	set category = "Admin"
	set name = "Reset Faction Symbol"
	set desc = "Wipes a faction's custom-drawn banner symbol to blank white (moderation action)."

	if (!check_rights(R_ADMIN))
		return
	if (!map)
		to_chat(usr, SPAN_WARNING("No map loaded."))
		return

	var/list/choices = list()
	for (var/fname in map.custom_faction_nr)
		choices += fname
	if (!choices.len)
		to_chat(usr, SPAN_WARNING("There are no factions to reset."))
		return
	choices += "Cancel"

	var/picked = input(usr, "Reset which faction's symbol to blank?", "Reset Faction Symbol", "Cancel") in choices
	if (!picked || picked == "Cancel")
		return

	// One-way wipe of player-drawn artwork -- confirm before pulling the trigger.
	if (WWinput(usr, "This permanently erases [picked]'s drawn symbol. Are you sure?", "Reset Faction Symbol", "No", list("Yes","No")) != "Yes")
		return

	if (map.admin_reset_faction_symbol(picked))
		message_admins("[key_name_admin(src)] reset [picked]'s faction symbol to blank.")
		log_admin("[key_name_admin(src)] reset [picked]'s faction symbol to blank.")
	else
		to_chat(usr, SPAN_WARNING("Failed to reset the symbol -- see the debug log."))
