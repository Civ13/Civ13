// A formal warning is kept as a "warning" record in the shared player records
// (player_notes.dm), so staff on every region see it in the player's notes.
/client/proc/warn(warned_ckey)
	if (!check_rights(R_ADMIN))	return

	if (!warned_ckey || !istext(warned_ckey))	return
	warned_ckey = ckey(warned_ckey)
	if (warned_ckey in admin_datums)
		to_chat(usr, "<font color='red'>Error: warn(): You can't warn admins.</font>")
		return
	var/reason = sanitize(input(usr, "Why is [warned_ckey] being warned? Every region's staff will see this in their notes.", "Warn") as null|text)
	if (!reason)
		return
	if (!notes_warn(warned_ckey, reason, usr))
		to_chat(usr, "<font color='red'>Error: warn(): the warning could not be recorded.</font>")
		return
	log_admin("[key_name(src)] warned [warned_ckey]: [reason]")

	for (var/client/C in clients)
		if (C.ckey == warned_ckey)
			to_chat(C, "<font color='red'><big><b>You have been formally warned by an administrator.</b></big></font>")
			to_chat(C, "<font color='red'>Reason: [reason]</font>")
			message_admins("[key_name_admin(src)] has warned [key_name_admin(C)]: [reason]", key_name_admin(src))
			return
	message_admins("[key_name_admin(src)] has warned [warned_ckey] (DC): [reason]", key_name_admin(src))
