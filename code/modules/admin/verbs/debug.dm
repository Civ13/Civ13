/client/proc/Debug2()
	set category = "Debug"
	set name = "Debug-Game"
	if (!check_rights(R_DEBUG))	return

	if (Debug2)
		Debug2 = FALSE
		message_admins("[key_name(src)] toggled debugging off.")
		log_admin("[key_name(src)] toggled debugging off.")
	else
		Debug2 = TRUE
		message_admins("[key_name(src)] toggled debugging on.")
		log_admin("[key_name(src)] toggled debugging on.")

// callproc moved to code/modules/admin/callproc


/client/proc/Cell()
	set category = "Debug"
	set name = "Cell"
	if (!mob)
		return
	var/turf/T = mob.loc

	if (!istype(T, /turf))
		return

	var/datum/gas_mixture/env = T.return_air()

	var/t = "<span class = 'notice'>Coordinates: [T.x],[T.y],[T.z]\n</span>"
	t += "<span class = 'red'>Temperature: [env.temperature]</span>\n"
	t += "<span class = 'red'>Pressure: [env.return_pressure()]kPa</span>\n"
	for (var/g in env.gas)
		t += "<span class = 'notice'>[g]: [env.gas[g]] / [env.gas[g] * R_IDEAL_GAS_EQUATION * env.temperature / env.volume]kPa</span>\n"

	usr.show_message(t, TRUE)



//TODO: merge the vievars version into this or something maybe mayhaps
/client/proc/cmd_debug_del_all()
	set category = "Debug"
	set name = "Del-All"

	// to prevent REALLY stupid deletions
	var/blocked = list(/obj, /mob, /mob/living, /mob/living/carbon, /mob/living/carbon/human, /mob/observer)
	var/hsbitem = input(usr, "Choose an object to delete.", "Delete:") as null|anything in typesof(/obj) + typesof(/mob) - blocked
	if (hsbitem)
		for (var/atom/O in world)
			if (istype(O, hsbitem))
				qdel(O)
		log_admin("[key_name(src)] has deleted all instances of [hsbitem].")
		message_admins("[key_name_admin(src)] has deleted all instances of [hsbitem].", FALSE)

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
	message_admins("<span class = 'notice'>[key_name_admin(usr)] assumed direct control of [M].</span>", TRUE)
	log_admin("[key_name(usr)] assumed direct control of [M].")
	var/mob/adminmob = mob
	M.ckey = ckey
	if (isghost(adminmob))
		qdel(adminmob)