// Admin > Player Accolades: see, grant or remove a player's lifetime accolades
// (code/modules/accolades/accolades.dm, docs/accolades.md).
/client/proc/accolades_admin()
	set name = "Player Accolades"
	set category = "Admin"
	set desc = "See, grant or remove a player's accolades."
	if(!check_rights(R_ADMIN))
		return
	var/target = ckey(input(src, "Player ckey:", "Player Accolades") as text|null)
	if(!length(target))
		return
	var/list/state = accolade_state(target)
	var/list/catalog = accolade_catalog()
	var/list/lines = list("<b>[target]</b>: [state["points"]] lifetime point\s.")
	for(var/id in catalog)
		lines += "[accolade_name(id)]: [accolade_status(state, id)]"
	var/list/lands = state["lands"]
	lines += "Lands lived in: [length(lands) ? jointext(lands, ", ") : "none"]"
	to_chat(src, jointext(lines, "<br>"))
	var/choice = input(src, "Grant or remove an accolade?", "Player Accolades") as null|anything in list("Grant", "Remove", "Nothing")
	if(choice != "Grant" && choice != "Remove")
		return
	var/list/names = list()
	for(var/id in catalog)
		var/status = accolade_status(state, id)
		if((choice == "Grant" && status != "claimed") || (choice == "Remove" && status == "claimed"))
			names["[accolade_name(id)]"] = id
	if(!names.len)
		to_chat(src, SPAN_WARNING("No accolade can be [choice == "Grant" ? "granted" : "removed"] for [target]."))
		return
	var/picked = input(src, "Which accolade?", "Player Accolades") as null|anything in names
	if(!picked)
		return
	var/id = names[picked]
	var/reason = sanitize(input(src, "Reason (kept in the player's records):", "Player Accolades") as text|null)
	if(!length(reason))
		return
	if(choice == "Grant")
		if(shared_records.add(target, "accolade", list("accolade" = id, "points" = accolade_value(id), "grant" = 1, "reason" = reason), ckey, holder ? holder.rank : ""))
			log_admin("[key_name(src)] granted the accolade [id] to [target]: [reason]")
			message_admins("[key_name_admin(src)] granted the accolade [picked] to [target].")
	else
		var/list/claimed = state["claimed"]
		if(shared_records.revoke(claimed[id], ckey, holder ? holder.rank : "", reason))
			log_admin("[key_name(src)] removed the accolade [id] from [target]: [reason]")
			message_admins("[key_name_admin(src)] removed the accolade [picked] from [target].")
	accolade_forget(target)
	var/client/C = directory[target]
	if(C)
		C.refresh_accolade_window()
