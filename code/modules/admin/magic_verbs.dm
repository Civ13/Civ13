/datum/admins/proc/load_houses()
	set category = "Magic"
	set name = "Load Houses"
	if (!check_rights(R_ADMIN))
		return
	var/obj/map_metadata/wizard_boy/W = map
	if (!istype(W))
		to_chat(usr, "The current map is not Wizard Boy.")
		return
	W.load_houses()
	to_chat(usr, "Houses loaded successfully.")
	log_admin("[key_name(usr)] loaded wizard houses.")
	message_admins("[key_name(usr)] loaded wizard houses.", key_name(usr))

/datum/admins/proc/save_houses()
	set category = "Magic"
	set name = "Save Houses"
	if (!check_rights(R_ADMIN))
		return
	var/obj/map_metadata/wizard_boy/W = map
	if (!istype(W))
		to_chat(usr, "The current map is not Wizard Boy.")
		return
	W.save_houses()
	to_chat(usr, "Houses saved successfully.")
	log_admin("[key_name(usr)] saved wizard houses.")
	message_admins("[key_name(usr)] saved wizard houses.", key_name(usr))

/datum/admins/proc/check_house()
	set category = "Magic"
	set name = "Check House"
	if (!check_rights(R_ADMIN))
		return
	var/obj/map_metadata/wizard_boy/W = map
	if (!istype(W))
		to_chat(usr, "The current map is not Wizard Boy.")
		return
	
	var/list/ckeys = list()
	for (var/client/C in clients)
		ckeys += C.ckey
	ckeys = sortList(ckeys)
	ckeys += "Custom Ckey"
	
	var/selected = input(usr, "Select a player ckey or choose Custom Ckey", "Check House") in ckeys
	if (!selected)
		return
	
	var/target_ckey
	if (selected == "Custom Ckey")
		target_ckey = ckey(input(usr, "Enter ckey:", "Custom Ckey") as text)
	else
		target_ckey = selected
	
	if (!target_ckey)
		return
	
	var/house = W.check_house(target_ckey)
	to_chat(usr, "Ckey [target_ckey] is in house: [house]")

/datum/admins/proc/check_level()
	set category = "Magic"
	set name = "Check Level"
	if (!check_rights(R_ADMIN))
		return
	var/obj/map_metadata/wizard_boy/W = map
	if (!istype(W))
		to_chat(usr, "The current map is not Wizard Boy.")
		return
	
	var/list/ckeys = list()
	for (var/client/C in clients)
		ckeys += C.ckey
	ckeys = sortList(ckeys)
	ckeys += "Custom Ckey"
	
	var/selected = input(usr, "Select a player ckey or choose Custom Ckey", "Check Level") in ckeys
	if (!selected)
		return
	
	var/target_ckey
	if (selected == "Custom Ckey")
		target_ckey = ckey(input(usr, "Enter ckey:", "Custom Ckey") as text)
	else
		target_ckey = selected
	
	if (!target_ckey)
		return
	
	var/level = W.check_level(target_ckey)
	var/level_text = W.level_to_text(level)
	to_chat(usr, "Ckey [target_ckey] is qualification level: [level] ([level_text])")

/datum/admins/proc/change_level()
	set category = "Magic"
	set name = "Change Level"
	if (!check_rights(R_ADMIN))
		return
	var/obj/map_metadata/wizard_boy/W = map
	if (!istype(W))
		to_chat(usr, "The current map is not Wizard Boy.")
		return
	
	var/list/ckeys = list()
	for (var/client/C in clients)
		ckeys += C.ckey
	ckeys = sortList(ckeys)
	ckeys += "Custom Ckey"
	
	var/selected = input(usr, "Select a player ckey or choose Custom Ckey", "Change Level") in ckeys
	if (!selected)
		return
	
	var/target_ckey
	if (selected == "Custom Ckey")
		target_ckey = ckey(input(usr, "Enter ckey:", "Custom Ckey") as text)
	else
		target_ckey = selected
	
	if (!target_ckey)
		return
	
	var/list/levels = list(
		"I.D.I.O.T. (0)" = "0",
		"U.N.G.A. (1)" = "1",
		"C.O.A.L. (2)" = "2",
		"G.E.M. (3)" = "3",
		"B.A.S.E.D. (4)" = "4",
		"C.H.A.D. (5)" = "5",
		"L.O.S.E.R. (R)" = "R",
		"Professor of Magical Arts (T)" = "T"
	)
	var/level_choice = input(usr, "Select new level", "Change Level") in levels
	if (!level_choice)
		return
	
	var/level_val = levels[level_choice]
	if (W.change_level(target_ckey, level_val))
		to_chat(usr, "Changed [target_ckey]'s level to [level_choice].")
		log_admin("[key_name(usr)] changed [target_ckey]'s level to [level_val].")
		message_admins("[key_name(usr)] changed [target_ckey]'s level to [level_val].", key_name(usr))
	else
		to_chat(usr, "Failed to change level. Make sure the ckey is already in a house.")

/datum/admins/proc/remove_from_house()
	set category = "Magic"
	set name = "Remove From House"
	if (!check_rights(R_ADMIN))
		return
	var/obj/map_metadata/wizard_boy/W = map
	if (!istype(W))
		to_chat(usr, "The current map is not Wizard Boy.")
		return
	
	var/list/ckeys = list()
	for (var/client/C in clients)
		ckeys += C.ckey
	ckeys = sortList(ckeys)
	ckeys += "Custom Ckey"
	
	var/selected = input(usr, "Select a player ckey or choose Custom Ckey", "Remove From House") in ckeys
	if (!selected)
		return
	
	var/target_ckey
	if (selected == "Custom Ckey")
		target_ckey = ckey(input(usr, "Enter ckey:", "Custom Ckey") as text)
	else
		target_ckey = selected
	
	if (!target_ckey)
		return
	
	if (W.remove_from_house(target_ckey))
		to_chat(usr, "Removed [target_ckey] from house.")
		log_admin("[key_name(usr)] removed [target_ckey] from house.")
		message_admins("[key_name(usr)] removed [target_ckey] from house.", key_name(usr))
	else
		to_chat(usr, "Failed to remove [target_ckey] from house. Make sure the ckey is in a house.")

/datum/admins/proc/change_house()
	set category = "Magic"
	set name = "Change House"
	if (!check_rights(R_ADMIN))
		return
	var/obj/map_metadata/wizard_boy/W = map
	if (!istype(W))
		to_chat(usr, "The current map is not Wizard Boy.")
		return
	
	var/list/ckeys = list()
	for (var/client/C in clients)
		ckeys += C.ckey
	ckeys = sortList(ckeys)
	ckeys += "Custom Ckey"
	
	var/selected = input(usr, "Select a player ckey or choose Custom Ckey", "Change House") in ckeys
	if (!selected)
		return
	
	var/target_ckey
	if (selected == "Custom Ckey")
		target_ckey = ckey(input(usr, "Enter ckey:", "Custom Ckey") as text)
	else
		target_ckey = selected
	
	if (!target_ckey)
		return
	
	var/new_house = input(usr, "Select new house", "Change House") in list("Rubywyrm", "Mintysnek", "Slatepie", "Mustardweasel")
	if (!new_house)
		return
	
	if (W.change_house(target_ckey, new_house))
		to_chat(usr, "Changed [target_ckey]'s house to [new_house].")
		log_admin("[key_name(usr)] changed [target_ckey]'s house to [new_house].")
		message_admins("[key_name(usr)] changed [target_ckey]'s house to [new_house].", key_name(usr))
	else
		to_chat(usr, "Failed to change house. Make sure the ckey is already in a house.")

/datum/admins/proc/add_to_house()
	set category = "Magic"
	set name = "Add To House"
	if (!check_rights(R_ADMIN))
		return
	var/obj/map_metadata/wizard_boy/W = map
	if (!istype(W))
		to_chat(usr, "The current map is not Wizard Boy.")
		return
	
	var/list/ckeys = list()
	for (var/client/C in clients)
		ckeys += C.ckey
	ckeys = sortList(ckeys)
	ckeys += "Custom Ckey"
	
	var/selected = input(usr, "Select a player ckey or choose Custom Ckey", "Add To House") in ckeys
	if (!selected)
		return
	
	var/target_ckey
	if (selected == "Custom Ckey")
		target_ckey = ckey(input(usr, "Enter ckey:", "Custom Ckey") as text)
	else
		target_ckey = selected
	
	if (!target_ckey)
		return
	
	var/house = input(usr, "Select house", "Add To House") in list("Rubywyrm", "Mintysnek", "Slatepie", "Mustardweasel")
	if (!house)
		return
	
	W.add_to_house(target_ckey, house)
	to_chat(usr, "Added [target_ckey] to house [house].")
	log_admin("[key_name(usr)] added [target_ckey] to house [house].")
	message_admins("[key_name(usr)] added [target_ckey] to house [house].", key_name(usr))

/datum/admins/proc/set_house_points()
	set category = "Magic"
	set name = "Set House Points"
	if (!check_rights(R_ADMIN))
		return
	var/obj/map_metadata/wizard_boy/W = map
	if (!istype(W))
		to_chat(usr, "The current map is not Wizard Boy.")
		return

	var/house = input(usr, "Select house", "Set House Points") in list("Rubywyrm", "Mintysnek", "Slatepie", "Mustardweasel")
	if (!house)
		return

	var/new_points = input(usr, "Enter the points to add/subtract to [house]:", "Set House Points", W.house_points[house]) as num
	if (isnull(new_points))
		return

	W.house_points[house] += new_points
	to_chat(usr, "Changed [house] points by [new_points] (new value: [W.house_points[house]]).")
	log_admin("[key_name(usr)] changed [house] points by [new_points] (new value: [W.house_points[house]]).")
	message_admins("[key_name(usr)] changed [house] points by [new_points] (new value: [W.house_points[house]]).", key_name(usr))
