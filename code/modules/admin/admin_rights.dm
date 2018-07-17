

/*
checks if usr is an admin with at least ONE of the flags in rights_required. (Note, they don't need all the flags)
if rights_required == FALSE, then it simply checks if they are an admin.
if it doesn't return TRUE and show_msg=1 it will prints a message explaining why the check has failed
generally it would be used like so:

proc/admin_proc()
	if (!check_rights(R_ADMIN)) return
	world << "you have enough rights!"

NOTE: It checks usr by default. Supply the "user" argument if you wish to check for a specific mob.
*/
/proc/check_rights(rights_required, show_msg=1, var/mob/user = usr)
	if (user && user.client)
		if (rights_required)
			if (user.client.holder)
				if (rights_required & user.client.holder.rights)
					return TRUE
				else
					if (show_msg)
						user << "<font color='red'>Error: You do not have sufficient rights to do that. You require one of the following flags:[rights2text(rights_required," ")].</font>"
		else
			if (user.client.holder)
				return TRUE
			else
				if (show_msg)
					user << "<font color='red'>Error: You are not an admin.</font>"
	return FALSE

//probably a bit iffy - will hopefully figure out a better solution
/proc/check_if_greater_rights_than(client/other)
	if (usr && usr.client)
		if (usr.client.holder)
			if (!other || !other.holder)
				return TRUE
			if (usr.client.holder.rights != other.holder.rights)
				if ( (usr.client.holder.rights & other.holder.rights) == other.holder.rights )
					return TRUE	//we have all the rights they have and more
		usr << "<font color='red'>Error: Cannot proceed. They have more or equal rights to us.</font>"
	return FALSE

