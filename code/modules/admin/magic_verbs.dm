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

/datum/admins/proc/assign_moldy_man()
	set category = "Magic"
	set name = "Assign Moldy Man"
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
	
	var/selected = input(usr, "Select a player ckey or choose Custom Ckey", "Assign Moldy Man") in ckeys
	if (!selected)
		return
	
	var/target_ckey
	if (selected == "Custom Ckey")
		target_ckey = ckey(input(usr, "Enter ckey:", "Custom Ckey") as text)
	else
		target_ckey = selected
	
	if (!target_ckey)
		return
	
	if (W.make_moldy_man(target_ckey))
		to_chat(usr, "Made [target_ckey] a Moldy Man.")
		log_admin("[key_name(usr)] made [target_ckey] a Moldy Man.")
		message_admins("[key_name(usr)] made [target_ckey] a Moldy Man.", key_name(usr))
	else
		to_chat(usr, "Failed to make [target_ckey] a Moldy Man. They may already be one, or they may not be connected.")

/datum/admins/proc/remove_moldy_man()
	set category = "Magic"
	set name = "Remove Moldy Man"
	if (!check_rights(R_ADMIN))
		return
	var/obj/map_metadata/wizard_boy/W = map
	if (!istype(W))
		to_chat(usr, "The current map is not Wizard Boy.")
		return
	
	if (!W.moldy_men.len)
		to_chat(usr, "There are no Moldy Men to remove.")
		return
	
	var/selected = input(usr, "Select a Moldy Man to remove", "Remove Moldy Man") in W.moldy_men
	if (!selected)
		return
	
	if (W.remove_moldy_man(selected))
		to_chat(usr, "Removed [selected] from Moldy Men.")
		log_admin("[key_name(usr)] removed [selected] from Moldy Men.")
		message_admins("[key_name(usr)] removed [selected] from Moldy Men.", key_name(usr))
	else
		to_chat(usr, "Failed to remove [selected] from Moldy Men.")

/datum/admins/proc/check_moldy_men()
	set category = "Magic"
	set name = "Check Moldy Men"
	if (!check_rights(R_ADMIN))
		return
	var/obj/map_metadata/wizard_boy/W = map
	if (!istype(W))
		to_chat(usr, "The current map is not Wizard Boy.")
		return
	
	if (!W.moldy_men.len)
		to_chat(usr, "There are no Moldy Men this round.")
		return
	
	to_chat(usr, "<b>Current Moldy Men:</b>")
	for (var/entry in W.get_moldy_man_info())
		to_chat(usr, entry)

/datum/admins/proc/award_sabotage_points()
	set category = "Magic"
	set name = "Award Sabotage Points"
	if (!check_rights(R_ADMIN))
		return
	var/obj/map_metadata/wizard_boy/W = map
	if (!istype(W))
		to_chat(usr, "The current map is not Wizard Boy.")
		return
	if (!W.sabotage)
		to_chat(usr, "Sabotage system not initialized.")
		return

	var/amount = input(usr, "Enter points to award:", "Award Sabotage Points") as num
	if (isnull(amount) || amount <= 0)
		return

	var/source = input(usr, "Enter source description:", "Award Sabotage Points", "Admin Award") as text
	if (!source)
		source = "Admin Award"

	W.sabotage.award_points(amount, source)
	log_admin("[key_name(usr)] awarded [amount] sabotage point\s. Source: [source].")
	message_admins("[key_name(usr)] awarded [amount] sabotage point\s. Source: [source].", key_name(usr))

/datum/admins/proc/check_sabotage_progress()
	set category = "Magic"
	set name = "Check Sabotage Progress"
	if (!check_rights(R_ADMIN))
		return
	var/obj/map_metadata/wizard_boy/W = map
	if (!istype(W))
		to_chat(usr, "The current map is not Wizard Boy.")
		return
	if (!W.sabotage)
		to_chat(usr, "Sabotage system not initialized.")
		return

	var/datum/moldy_sabotage/S = W.sabotage
	to_chat(usr, "<b>Sabotage Progress:</b>")
	to_chat(usr, "Points: [S.sabotage_points]/[S.max_threshold]")
	to_chat(usr, "Ritual Unlocked: [S.ritual_unlocked]")
	to_chat(usr, "Members ([S.member_ckeys.len]):")
	for (var/ckey in S.member_ckeys)
		to_chat(usr, "  - [ckey]")

/datum/admins/proc/trigger_moldy_reveal()
	set category = "Magic"
	set name = "Trigger Moldy Reveal"
	if (!check_rights(R_ADMIN))
		return
	var/obj/map_metadata/wizard_boy/W = map
	if (!istype(W))
		to_chat(usr, "The current map is not Wizard Boy.")
		return
	if (!W.sabotage)
		to_chat(usr, "Sabotage system not initialized.")
		return

	if (alert(usr, "This will reveal ALL Moldy Men to the entire server. Continue?", "Trigger Moldy Reveal", "Yes", "No") != "Yes")
		return

	W.sabotage.reveal_all()
	to_chat(world, "<span class='danger'><font size=4>\"The Moldy Men have been exposed!\"</font></span>")
	log_admin("[key_name(usr)] triggered the Moldy Men global reveal.")
	message_admins("[key_name(usr)] triggered the Moldy Men global reveal.", key_name(usr))
