// make the world closed to non-staff, no matter what
/client/proc/forceClose_game_schedule()

	set name = "forceClose World"
	set category = "Server"

	if (!check_rights(R_HOST))
		return

	if (!global_game_schedule)
		return

	var/i = input("Forcibly off the game schedule? Current forceClosed setting is [global_game_schedule.forceClosed]. (If TRUE, selecting 'No' will disable it.)") in list("Yes", "No", "Cancel")
	if (i == "Yes")
		global_game_schedule.forceClose()
		src << "<span class = 'notice'>The world has been forcibly closed.</notice>"
		var/M = "[key_name(src)] forcibly closed the world!"
		message_admins(M)
		log_admin(M)
	else if (i == "No")
		global_game_schedule.unforceClose()
		src << "<span class = 'notice'>The world is no longer forcibly closed.</notice>"
		var/M = "[key_name(src)] made the world no longer forcibly closed!"
		message_admins(M)
		log_admin(M)

// make the world open to non-staff (but whitelisted non-staff), no matter what
/client/proc/forceOpen_game_schedule()

	set name = "forceOpen World"
	set category = "Server"

	if (!check_rights(R_HOST))
		return

	if (!global_game_schedule)
		return

	var/i = input("Forcibly open the game schedule? Current forceOpened setting is [global_game_schedule.forceOpened]. (If TRUE, selecting 'No' will disable it.)") in list("Yes", "No", "Cancel")
	if (i == "Yes")
		global_game_schedule.forceOpen()
		src << "<span class = 'notice'>The world has been forcibly opened.</notice>"
		var/M = "[key_name(src)] forcibly opened the world!"
		message_admins(M)
		log_admin(M)
	else if (i == "No")
		global_game_schedule.unforceOpen()
		src << "<span class = 'notice'>The world is no longer forcibly opened.</notice>"
		var/M = "[key_name(src)] made the world no longer forcibly opened!"
		message_admins(M)
		log_admin(M)

// make the world closed to anyone who isn't staff or whitelisted
// to eject people who are whitelisted too, just use forceClose World
/client/proc/eject_unwhitelisted()

	set name = "Eject Unwhitelisted Players"
	set category = "Server"

	if (!check_rights(R_ADMIN))
		return

	var/ejected = FALSE

	if ((input(src, "Are you sure you want to kick ALL unwhitelisted players?") in list("Yes", "No")) == "Yes")
		if ((input(src, "Seriously?") in list("Yes", "No")) == "Yes")
			for (var/client/C in clients)
				if (!C.holder && !C.validate_whitelist("Server", TRUE) && !C.isPatron("$10+"))
					++ejected
					C << "<span class = 'userdanger'>The server has been closed to those who aren't whitelisted for private testing. Get whitelisted on the Discord.</span>"
					del C

			var/M = "[key_name(src)] has ejected all unwhitelisted players ([ejected])!"
			message_admins(M)
			log_admin(M)