// Staff manage the magic whitelist (code/modules/divine/magic_whitelist.dm): only
// players on it may follow a god, pray with Beseech, read sealed advancement
// notes or gain the magic skill on persistent worlds. The list is shared by every
// region of the group. Hidden mechanic: keep it out of changelog lines and the wiki.
/client/proc/cmd_admin_magic_whitelist()
	set category = "Admin"
	set name = "Magic Whitelist"
	set desc = "Choose which players may follow a god and learn magic on persistent worlds."
	if (!check_rights(R_ADMIN))
		return
	magic_whitelist_refresh(TRUE)
	var/list/actions = list("Add a player", "Remove a player", "Show the list", "Followers here not on the list")
	var/action = input(usr, "[magic_whitelist.len] player\s on the magic whitelist. It is shared by every region.[magic_whitelist_applies() ? "" : " This world is not persistent, so it is not enforced here."]", "Magic Whitelist") as null|anything in actions
	if (!action || !check_rights(R_ADMIN))
		return
	switch (action)
		if ("Add a player")
			var/list/choices = list("Type a key...")
			for (var/client/C in clients)
				if (!(C.ckey in magic_whitelist))
					choices["[C.key][C.mob && C.mob.real_name ? " ([C.mob.real_name])" : ""]"] = C.ckey
			var/pick = input(usr, "Add whom to the magic whitelist?", "Magic Whitelist") as null|anything in choices
			if (!pick)
				return
			var/key = choices[pick]
			if (pick == "Type a key...")
				key = ckey(input(usr, "Player key to add:", "Magic Whitelist") as text|null)
			if (!length(key) || !check_rights(R_ADMIN))
				return
			magic_whitelist_change(key, TRUE)
		if ("Remove a player")
			if (!magic_whitelist.len)
				to_chat(usr, SPAN_WARNING("The magic whitelist is empty."))
				return
			var/key = input(usr, "Remove whom from the magic whitelist? Their characters keep what they learned, but it is suspended until they are added again.", "Magic Whitelist") as null|anything in sortList(magic_whitelist.Copy())
			if (!key || !check_rights(R_ADMIN))
				return
			magic_whitelist_change(key, FALSE)
		if ("Show the list")
			to_chat(usr, "<b>Magic whitelist ([magic_whitelist.len], file [html_encode(magic_whitelist_file())]):</b><br>[magic_whitelist.len ? jointext(sortList(magic_whitelist.Copy()), ", ") : "nobody"]")
		if ("Followers here not on the list")
			var/list/lines = list()
			for (var/mob/living/human/H in human_mob_list)
				if (!QDELETED(H) && istext(H.divine_patron) && length(H.divine_patron) && !H.magic_allowed())
					lines += "[H.real_name] ([H.magic_key() ? H.magic_key() : "no player"]), follows [H.divine_patron]"
			to_chat(usr, "<b>Suspended followers in this world:</b><br>[lines.len ? jointext(lines, "<br>") : "none"]")

/client/proc/magic_whitelist_change(key, add)
	if (!magic_whitelist_set(key, add))
		to_chat(usr, SPAN_WARNING("[key] is [add ? "already" : "not"] on the magic whitelist, or the file could not be written."))
		return FALSE
	log_admin("[key_name(usr)] [add ? "added" : "removed"] [key] [add ? "to" : "from"] the magic whitelist.")
	message_admins("[key_name_admin(usr)] [add ? "added" : "removed"] [key] [add ? "to" : "from"] the magic whitelist.")
	for (var/mob/living/human/H in human_mob_list)
		if (!QDELETED(H) && H.magic_key() == key)
			if (add)
				H.divine_refresh_verbs()
			else
				H.magic_whitelist_revoked()
	return TRUE

// Before staff initiate or teach someone: they must be on the list. Offers to add them.
/client/proc/magic_whitelist_admit(mob/living/human/H)
	if (!H || QDELETED(H))
		return FALSE
	if (H.magic_allowed())
		return TRUE
	var/key = H.magic_key()
	if (!length(key))
		to_chat(usr, SPAN_WARNING("[H.real_name] has no player, so they can't be put on the magic whitelist."))
		return FALSE
	if (alert(usr, "[H.real_name] ([key]) is not on the magic whitelist, so they can't follow a god or learn magic. Add [key] to it now?", "Magic Whitelist", "Add them", "Cancel") != "Add them")
		return FALSE
	return check_rights(R_ADMIN) && magic_whitelist_change(key, TRUE) && !QDELETED(H) && H.magic_allowed()
