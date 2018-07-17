/client/proc/warn(warned_ckey)
	if (!check_rights(R_ADMIN))	return

	if (!warned_ckey || !istext(warned_ckey))	return
	if (warned_ckey in admin_datums)
		usr << "<font color='red'>Error: warn(): You can't warn admins.</font>"
		return

	for (var/client/C in clients)
		if (C.ckey == warned_ckey)
			C << "<font color='red'><big><b>You have been formally warned by an administrator.</b></big></font>"
			message_admins("[key_name_admin(src)] has warned [key_name_admin(C)].")
			return
	message_admins("[key_name_admin(src)] has warned [warned_ckey] (DC).")