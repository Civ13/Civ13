// Divine Patron > Tend repositories: staff list every magic repository in this
// world (code/modules/divine/repository*.dm) and set its charge or tier, wake a
// fallen or withdrawn one, make one ordinary or jump to it. Every change is
// logged and shown to staff. Hidden mechanic: keep it out of changelog lines
// and the wiki.
/client/proc/divine_tend_repositories()
	if (!check_rights(R_ADMIN))
		return
	var/list/rows = list()
	for (var/id in magic_repo_index)
		var/obj/O = magic_repo_find(id)
		if (!O)
			continue
		var/turf/T = get_turf(O)
		var/state = O.magic_repo_captured ? ", fallen" : (O.magic_repo_withdrawn ? ", withdrawn" : (O.magic_repo_dormant() ? ", still" : ""))
		rows["[O.name] [O.magic_repo_tier ? "tier [O.magic_repo_tier]" : "unfinished"], [round(O.magic_repo_charge)]/[O.magic_repo_capacity], [O.magic_repo_deity][state] at [T ? "[T.x],[T.y],[T.z]" : "nowhere"] ([id])"] = id
	if (!rows.len)
		to_chat(usr, SPAN_NOTICE("There are no repositories in this world."))
		return
	var/id = rows[input(usr, "Which repository?", "Tend repositories") as null|anything in sortList(rows)]
	var/obj/O = magic_repo_find(id)
	if (!O || !check_rights(R_ADMIN))
		return
	var/list/keepers = islist(O.magic_repo_keepers) ? O.magic_repo_keepers : list()
	to_chat(usr, SPAN_NOTICE("[O.name] ([O.type]): maker [O.magic_repo_maker], keepers [keepers.len ? english_list(keepers) : "none"], [length(O.magic_repo_registrants)] tied, [length(O.magic_repo_targets)] targets[O.magic_repo_faction ? ", seat of [O.magic_repo_faction] ([O.magic_repo_group])" : ""]."))
	var/action = input(usr, "Do what?", "Tend repositories") as null|anything in list("Set charge", "Set tier", "Wake it", "Make it ordinary", "Jump to it")
	if (!action || !check_rights(R_ADMIN) || QDELETED(O) || O.magic_repo_id != id)
		return
	var/note = null
	switch (action)
		if ("Set charge")
			var/amount = input(usr, "Charge (0 to [O.magic_repo_capacity])?", "Tend repositories", round(O.magic_repo_charge)) as null|num
			if (!isnum(amount) || QDELETED(O))
				return
			O.magic_repo_charge = clamp(amount, 0, O.magic_repo_capacity)
			note = "set its charge to [O.magic_repo_charge]"
		if ("Set tier")
			var/tier = input(usr, "Tier (1 to [magic_tier_count()])?", "Tend repositories", max(1, O.magic_repo_tier)) as null|num
			if (!isnum(tier) || QDELETED(O))
				return
			tier = clamp(round(tier), 1, magic_tier_count())
			if (!O.magic_repo_tier)
				O.magic_repo_skill = max(O.magic_repo_skill, 5)
			O.magic_repo_set_tier(tier)
			O.magic_repo_full_since = 0
			note = "set it to tier [O.magic_repo_tier] (capacity [O.magic_repo_capacity])"
		if ("Wake it")
			O.magic_repo_captured = FALSE
			O.magic_repo_withdrawn = FALSE
			O.magic_repo_seat_checked = world.time
			note = "woke it"
		if ("Make it ordinary")
			if (alert(usr, "Make [O.name] ordinary? Its charge, ties and keepers are lost.", "Tend repositories", "Make it ordinary", "Cancel") != "Make it ordinary" || QDELETED(O))
				return
			O.magic_repo_unmake("staff ([ckey])")
			note = "made it ordinary"
		if ("Jump to it")
			var/turf/T = get_turf(O)
			if (T && mob)
				mob.forceMove(T)
			return
	log_admin("[key_name(usr)] tended repository [id] ([O.type]): [note].")
	message_admins("[key_name_admin(usr)] tended repository [id] ([O.name]): [note].")
