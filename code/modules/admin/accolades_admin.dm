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
	// Character slots (character_slots.dm): bought slots, the one played, names.
	var/list/slots = character_slot_state(target)
	var/list/slot_names = slots["names"]
	var/list/slot_lines = list()
	for(var/slot = 1 to character_slots_max)
		var/list/locked = slots["locked"]
		var/status = locked["[slot]"] ? "locked by staff" : (character_slot_open(slots, slot) ? "open" : "not bought")
		slot_lines += "[slot] [status][slot == slots["active"] ? " (played)" : ""][islist(slot_names["[slot]"]) ? " - [slot_names["[slot]"][1]]" : ""]"
	lines += "Character slots: [jointext(slot_lines, "; ")]. Points spent: [slots["spent"]]."
	to_chat(src, jointext(lines, "<br>"))
	var/choice = input(src, "Grant or remove an accolade, or lock a character slot?", "Player Accolades") as null|anything in list("Grant", "Remove", "Lock slot", "Nothing")
	if(choice == "Lock slot")
		var/list/open = list()
		var/list/unlocked = slots["unlocked"]
		for(var/key in unlocked)
			open["Slot [key]"] = unlocked[key]
		if(!open.len)
			to_chat(src, SPAN_WARNING("[target] has no extra character slot to lock."))
			return
		var/pick = input(src, "Which slot? Its character stays asleep and the points stay spent.", "Player Accolades") as null|anything in open
		if(!pick)
			return
		var/why = sanitize(input(src, "Reason (kept in the player's records):", "Player Accolades") as text|null)
		if(!length(why))
			return
		if(shared_records.revoke(open[pick], ckey, holder ? holder.rank : "", why))
			character_slot_forget(target)
			log_admin("[key_name(src)] locked [pick] of [target]: [why]")
			message_admins("[key_name_admin(src)] locked character [pick] of [target].")
		return
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
