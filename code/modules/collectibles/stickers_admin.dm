/datum/admins/proc/view_sticker_collection()
	set category = "Admin"
	set name = "View Sticker Collection"
	if (!check_rights(R_ADMIN))
		return
	var/list/ckeys = list()
	for (var/client/C in clients)
		ckeys += C.ckey
	ckeys = sortList(ckeys)
	ckeys += "Custom Ckey"
	var/selected = input(usr, "Select a player", "View Sticker Collection") in ckeys
	if (!selected)
		return
	var/target_ckey
	if (selected == "Custom Ckey")
		target_ckey = ckey(input(usr, "Enter ckey:", "Custom Ckey") as text)
	else
		target_ckey = selected
	if (!target_ckey)
		return
	var/list/player_stickers = get_player_stickers(target_ckey)
	var/dat = "<html><head>[common_browser_style]</head><body>"
	dat += "<h2>Sticker Collection: [target_ckey]</h2>"
	dat += "<p>Collected: [length(player_stickers)] / [length(GLOB.sticker_registry)]</p>"
	dat += "<table style='width:100%;'>"
	var/count = 0
	for(var/id in GLOB.sticker_registry)
		var/datum/sticker/S = GLOB.sticker_registry[id]
		if(count % 3 == 0)
			dat += "<tr>"
		if(id in player_stickers)
			dat += "<td style='padding:4px;'><b>[S.name]</b> <font color='[S.rarity_color()]'>[S.rarity_name()]</font></td>"
		else
			dat += "<td style='padding:4px;color:#555;'>??? — Missing</td>"
		count++
		if(count % 3 == 0)
			dat += "</tr>"
	if(count % 3 != 0)
		dat += "</tr>"
	dat += "</table></body></html>"
	usr << browse(dat, "window=admin_sticker_view;size=500x600")
	log_admin("[key_name(usr)] viewed [target_ckey]'s sticker collection.")
	message_admins("[key_name(usr)] viewed [target_ckey]'s sticker collection.", key_name(usr))

/datum/admins/proc/give_sticker_pack()
	set category = "Admin"
	set name = "Give Sticker Pack"
	if (!check_rights(R_ADMIN))
		return
	var/list/ckeys = list()
	for (var/client/C in clients)
		ckeys += C.ckey
	ckeys = sortList(ckeys)
	var/selected = input(usr, "Select a player", "Give Sticker Pack") in ckeys
	if (!selected)
		return
	var/count = input(usr, "How many packs?", "Give Sticker Pack") as num|null
	if (!count || count < 1)
		count = 1
	var/mob/target
	for (var/mob/M in mob_list)
		if (M.ckey == selected && ismob(M))
			target = M
			break
	if (!target)
		to_chat(usr, "<span class='warning'>Could not find mob for [selected]. They may not be in the game.</span>")
		return
	for (var/i = 1 to count)
		new /obj/item/sticker_pack(get_turf(target))
	to_chat(usr, "<span class='notice'>Gave [count] sticker pack\s to [selected].</span>")
	log_admin("[key_name(usr)] gave [count] sticker pack\s to [selected].")
	message_admins("[key_name(usr)] gave [count] sticker pack\s to [selected].", key_name(usr))

/datum/admins/proc/give_sticker()
	set category = "Admin"
	set name = "Give Specific Sticker"
	if (!check_rights(R_ADMIN))
		return
	var/list/ckeys = list()
	for (var/client/C in clients)
		ckeys += C.ckey
	ckeys = sortList(ckeys)
	var/selected = input(usr, "Select a player", "Give Specific Sticker") in ckeys
	if (!selected)
		return
	if(!length(GLOB.sticker_registry))
		to_chat(usr, "<span class='warning'>The sticker registry is empty!</span>")
		return
	var/list/sticker_names = list()
	for(var/id in GLOB.sticker_registry)
		var/datum/sticker/S = GLOB.sticker_registry[id]
		sticker_names["[S.name] ([S.rarity_name()])"] = id
	var/picked_name = input(usr, "Select a sticker", "Give Specific Sticker") in sticker_names
	if (!picked_name)
		return
	var/picked_id = sticker_names[picked_name]
	var/mob/target
	for (var/mob/M in mob_list)
		if (M.ckey == selected && ismob(M))
			target = M
			break
	if (!target)
		to_chat(usr, "<span class='warning'>Could not find mob for [selected]. They may not be in the game.</span>")
		return
	new /obj/item/sticker(get_turf(target), picked_id)
	to_chat(usr, "<span class='notice'>Gave [picked_name] to [selected].</span>")
	log_admin("[key_name(usr)] gave sticker [picked_name] to [selected].")
	message_admins("[key_name(usr)] gave sticker [picked_name] to [selected].", key_name(usr))

/datum/admins/proc/unlock_sticker_admin()
	set category = "Admin"
	set name = "Unlock Sticker For Player"
	if (!check_rights(R_ADMIN))
		return
	var/list/ckeys = list()
	for (var/client/C in clients)
		ckeys += C.ckey
	ckeys = sortList(ckeys)
	ckeys += "Custom Ckey"
	var/selected = input(usr, "Select a player", "Unlock Sticker") in ckeys
	if (!selected)
		return
	var/target_ckey
	if (selected == "Custom Ckey")
		target_ckey = ckey(input(usr, "Enter ckey:", "Custom Ckey") as text)
	else
		target_ckey = selected
	if (!target_ckey)
		return
	if(!length(GLOB.sticker_registry))
		to_chat(usr, "<span class='warning'>The sticker registry is empty!</span>")
		return
	var/list/sticker_names = list()
	for(var/id in GLOB.sticker_registry)
		var/datum/sticker/S = GLOB.sticker_registry[id]
		sticker_names["[S.name] ([S.rarity_name()])"] = id
	var/picked_name = input(usr, "Select a sticker to unlock", "Unlock Sticker") in sticker_names
	if (!picked_name)
		return
	var/picked_id = sticker_names[picked_name]
	var/list/player_stickers = get_player_stickers(target_ckey)
	if(picked_id in player_stickers)
		to_chat(usr, "<span class='warning'>[target_ckey] already has that sticker!</span>")
		return
	player_stickers += picked_id
	save_sticker_collection(target_ckey, player_stickers)
	to_chat(usr, "<span class='notice'>Unlocked [picked_name] for [target_ckey].</span>")
	log_admin("[key_name(usr)] unlocked sticker [picked_name] for [target_ckey].")
	message_admins("[key_name(usr)] unlocked sticker [picked_name] for [target_ckey].", key_name(usr))

/datum/admins/proc/reset_sticker_collection()
	set category = "Admin"
	set name = "Reset Player Stickers"
	if (!check_rights(R_ADMIN))
		return
	var/list/ckeys = list()
	for (var/client/C in clients)
		ckeys += C.ckey
	ckeys = sortList(ckeys)
	ckeys += "Custom Ckey"
	var/selected = input(usr, "Select a player", "Reset Sticker Collection") in ckeys
	if (!selected)
		return
	var/target_ckey
	if (selected == "Custom Ckey")
		target_ckey = ckey(input(usr, "Enter ckey:", "Custom Ckey") as text)
	else
		target_ckey = selected
	if (!target_ckey)
		return
	if (alert(usr, "This will wipe ALL stickers for [target_ckey]. Continue?", "Reset Sticker Collection", "Yes", "No") != "Yes")
		return
	save_sticker_collection(target_ckey, list())
	to_chat(usr, "<span class='notice'>Reset sticker collection for [target_ckey].</span>")
	log_admin("[key_name(usr)] reset sticker collection for [target_ckey].")
	message_admins("[key_name(usr)] reset sticker collection for [target_ckey].", key_name(usr))
