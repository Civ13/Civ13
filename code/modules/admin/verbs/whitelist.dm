// todo: merge this with the code in whitelist_teststaff.dm

/client/proc/add_to_server_whitelist()
	set name = "Add To Server Whitelist"
	set category = "Server"

	if (!check_rights(R_ADMIN))
		src << "<span class = 'danger'>You don't have the permissions.</span>"
		return

	var/_ckey = input("What ckey?") as text
	_ckey = sanitizeSQL(_ckey, max_length = 50)

	if (!_ckey)
		return

	var/datum/whitelist/W = global_whitelists["server"]
	if (!W)
		src << "<span class = 'danger'>Something went wrong. This whitelist doesn't exist.</span>"
		return


	W.add(_ckey)
	save_whitelist("server")

	src << "<span class = 'notice'>Successfully added '[_ckey]' to the 'server' whitelist."
	var/M = "[key_name(src)] added '[_ckey]' to the 'server' whitelist."
	log_admin(M)
	message_admins(M)

/client/proc/remove_from_server_whitelist()
	set name = "Remove From Server Whitelist"
	set category = "Server"

	if (!check_rights(R_ADMIN))
		src << "<span class = 'danger'>You don't have the permissions.</span>"
		return

	var/_ckey = input("What ckey?") as text
	_ckey = sanitizeSQL(_ckey, max_length = 50)

	if (!_ckey)
		return

	var/datum/whitelist/W = global_whitelists["server"]
	if (!W)
		src << "<span class = 'danger'>Something went wrong. This whitelist doesn't exist.</span>"
		return

	if (W.remove(_ckey))
		save_whitelist("server")
		src << "<span class = 'notice'>Successfully removed '[_ckey]' from the 'server' whitelist."
		var/M = "[key_name(src)] REMOVED '[_ckey]' from the 'server' whitelist."
		log_admin(M)
		message_admins(M)
	else
		src << "<span class = 'warning'>FAILED to remove '[_ckey]' from the 'server' whitelist. They weren't in it."

/client/proc/view_server_whitelist()
	set name = "See Server Whitelist"
	set category = "Server"

	if (!check_rights(R_ADMIN))
		src << "<span class = 'danger'>You don't have the permissions.</span>"
		return

	var/datum/whitelist/W = global_whitelists["server"]
	src << W.data

/client/proc/enable_disable_server_whitelist()
	set name = "Enable/Disable Server Whitelist"
	set category = "Server"

	if (!check_rights(R_ADMIN))
		src << "<span class = 'danger'>You don't have the permissions.</span>"
		return

	var/datum/whitelist/W = global_whitelists["server"]
	W.enabled = !W.enabled
	if (W.enabled)
		src << "<span class = 'notice'>The server whitelist is now <b>ENABLED</b>.</span>"
		var/M = "[key_name(src)] ENABLED the server whitelist."
		log_admin(M)
		message_admins(M)
	else
		src << "<span class = 'notice'>The server whitelist is now <b>DISABLED</b>.</span>"
		var/M = "[key_name(src)] DISABLED the server whitelist."
		log_admin(M)
		message_admins(M)