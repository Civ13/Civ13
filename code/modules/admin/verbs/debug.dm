/client/proc/Debug2()
	set category = "Debug"
	set name = "Debug-Game"
	if (!check_rights(R_DEBUG))	return

	spawn(2)
		winset(src, null, "command=.command") //spawn so a window doesn't overlap it
		message_admins("[key_name(src)] started debugging a command.", key_name(src))
		log_admin("[key_name(src)] started debugging a command.")

// callproc moved to code/modules/admin/callproc


//TODO: merge the vievars version into this or something maybe mayhaps
/client/proc/cmd_debug_del_all()
	set category = "Debug"
	set name = "Del-All"

	// to prevent REALLY stupid deletions
	var/blocked = list(/obj, /mob, /mob/living, /mob/living/human, /mob/living/human, /mob/observer)
	var/hsbitem = input(usr, "Choose an object to delete.", "Delete:") as null|anything in typesof(/obj) + typesof(/mob) - blocked
	if (hsbitem)
		for (var/atom/O in world)
			if (istype(O, hsbitem))
				qdel(O)
		log_admin("[key_name(src)] has deleted all instances of [hsbitem].")
		message_admins("[key_name_admin(src)] has deleted all instances of [hsbitem].", key_name_admin(src))

/client/proc/cmd_assume_direct_control(var/mob/M in mob_list)
	set category = "Admin"
	set name = "Assume direct control"
	set desc = "Direct intervention"

	if (!check_rights(R_DEBUG|R_ADMIN))	return
	if (M.ckey)
		if (WWinput(src, "This mob is being controlled by [M.ckey]. Are you sure you wish to assume control of it? [M.ckey] will be made a ghost.", "Assume Direct Control", "Yes", list("Yes","No")) != "Yes")
			return
		else
			var/mob/observer/ghost/ghost = new/mob/observer/ghost(M,1)
			ghost.ckey = M.ckey
	message_admins("<span class = 'notice'>[key_name_admin(usr)] assumed direct control of [M].</span>", key_name_admin(src))
	log_admin("[key_name(usr)] assumed direct control of [M].")
	var/mob/adminmob = mob
	M.ckey = ckey
	if (isghost(adminmob))
		qdel(adminmob)

/datum/admins/proc/view_runtimes()
	set category = "Debug"
	set name = "View Runtimes"
	set desc = "Open the Runtime Viewer"

	if(!check_rights(R_DEBUG))
		return

	GLOB.error_cache.show_to(usr.client)