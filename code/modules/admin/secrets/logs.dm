/datum/admin_secret_item/admin_secret/admin_logs
	name = "Admin Logs"

/datum/admin_secret_item/admin_secret/admin_logs/execute(var/mob/user)
	. = ..()
	if (!.)
		return
	var/dat = "<b>Admin Log<HR></b>"
	dat += "Recent history normally keeps up to 1,024 entries. Older entries are archived in the private server log before removal. If archiving fails, they remain here.<HR>"
	for (var/l in admin_log)
		dat += "<li>[l]</li>"
	if (!admin_log.len)
		dat += "No-one has done anything this round!"
	user << browse(dat, "window=admin_log")
