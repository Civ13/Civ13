// Admin verbs (Fun). Added to the fun verb list at startup.

/hook/startup/proc/nomad_raid_admin_verbs()
	admin_verbs_fun |= list(/client/proc/start_nomad_raid_verb, /client/proc/end_nomad_raid_verb, /client/proc/nomad_raid_status_verb)
	return TRUE

/client/proc/start_nomad_raid_verb()
	set category = "Fun"
	set name = "Start Nomad Visit"
	if (!check_rights(R_FUN))
		return
	if (nomad_raid)
		to_chat(src, SPAN_WARNING("A nomad visit is already running: [nomad_raid.status_text()]"))
		return
	var/kind = input(src, "Raiders or traders?", "Nomad visit") as null|anything in list("Raiders", "Traders")
	if (!kind)
		return
	kind = kind == "Traders" ? "trade" : "raid"
	var/how = input(src, "Who should they visit?", "Nomad visit") as null|anything in list("Busiest settlement", "A player", "My location")
	if (!how)
		return
	var/turf/T
	var/list/ckeys = list()
	switch (how)
		if ("Busiest settlement")
			var/list/picked = nomad_raid_pick(nomad_raid_candidates())
			if (!picked)
				to_chat(src, SPAN_WARNING("No group of [NOMAD_RAID_MIN_DEFENDERS] or more active players is off cooldown."))
				return
			T = picked["turf"]
			ckeys = picked["ckeys"]
		if ("A player")
			var/list/choices = list()
			for (var/client/C in clients)
				if (nomad_raid_defender(C.mob))
					choices["[C.mob.real_name] ([C.ckey])"] = C.mob
			var/choice = input(src, "Target player", "Nomad visit") as null|anything in choices
			if (!choice)
				return
			var/mob/M = choices[choice]
			T = get_turf(M)
			for (var/mob/living/human/H in nomad_raid_defenders_near(T))
				ckeys += H.ckey
		if ("My location")
			T = get_turf(mob)
			for (var/mob/living/human/H in nomad_raid_defenders_near(T))
				ckeys += H.ckey
	var/size = input(src, "Party size, including the leader ([NOMAD_RAID_MIN_MEMBERS] to [NOMAD_RAID_MAX_MEMBERS])", "Nomad visit", kind == "trade" ? 2 : 4) as null|num
	if (isnull(size))
		return
	var/error = start_nomad_raid(T, ckeys, size, key_name(src), kind)
	if (error)
		to_chat(src, SPAN_WARNING("The visit could not start: [error]."))
	else
		to_chat(src, SPAN_NOTICE("Nomad visit started. [nomad_raid.status_text()]"))

/client/proc/end_nomad_raid_verb()
	set category = "Fun"
	set name = "End Nomad Visit"
	if (!check_rights(R_FUN))
		return
	if (!nomad_raid)
		to_chat(src, SPAN_NOTICE("No nomad visit is running."))
		return
	var/how = input(src, "End the visit how?", "Nomad visit") as null|anything in list("Send them home", "Remove them now")
	if (!how || !nomad_raid)
		return
	if (how == "Send them home")
		nomad_raid.send_home("sent home by [key_name(src)]")
	else
		nomad_raid.remove_all("removed by [key_name(src)]")

/client/proc/nomad_raid_status_verb()
	set category = "Fun"
	set name = "Nomad Visit Status"
	if (!check_rights(R_FUN))
		return
	to_chat(src, SPAN_NOTICE(nomad_raid ? nomad_raid.status_text() : "No nomad visit is running."))
