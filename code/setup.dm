/proc/setup_everything()

	// job_master
	if (!job_master)
		job_master = new /datum/controller/occupations()
		job_master.SetupOccupations()
	//	job_master.LoadJobs("config/jobs.txt")
		admin_notice("<span class='danger'>Job setup complete.</span>", R_DEBUG)

	// ticklag

	world.tick_lag = config.Ticklag

	// objects

	admin_notice("<span class='danger'>Initializing objects...</span>", R_DEBUG)
	sleep(-1)
	for (var/atom/movable/object in world)
		if (!object.gcDestroyed)
			object.initialize()

	admin_notice("<span class='danger'>Initializing areas...</span>", R_DEBUG)
	sleep(-1)
	for (var/area/area in area_list)
		area.initialize()

	admin_notice("<span class='danger'>Initializing approved list...</span>", R_DEBUG)
	sleep(-1)
	var/F = file("SQL/approved.txt")
	if (fexists(F))
		var/list/approved_list_temp = file2list(F,"\n")
		for (var/i in approved_list_temp)
			if (findtext(i, "="))
				var/list/current = splittext(i, "=")
				approved_list += current[1]
	else
		admin_notice("<span class='danger'>Failed to load approved list!</span>", R_DEBUG)

	admin_notice("<span class='danger'>Initializing whitelistlist...</span>", R_DEBUG)
	sleep(-1)
	var/F2 = file("SQL/whitelist.txt")
	if (fexists(F2))
		var/list/whitelist_temp = file2list(F2,"\n")
		for (var/i in whitelist_temp)
			if (findtext(i, "="))
				var/list/current = splittext(i, "=")
				whitelist_list += current[1]
	else
		admin_notice("<span class='danger'>Failed to load whitelist!</span>", R_DEBUG)

	admin_notice("<span class='danger'>Initializing crafting recipes...</span>", R_DEBUG)
	sleep(-1)
	var/F3 = file("config/material_recipes.txt")
	if (fexists(F3))
		var/list/craftlist_temp = file2list(F3,"\n")
		for (var/i in craftlist_temp)
			if (findtext(i, ",") && findtext(i,"RECIPE: "))
				var/tmpi = replacetext(i, "RECIPE: ", "")
				var/list/current = splittext(tmpi, ",")
				craftlist_list += list(current)
				if (current.len != 13)
					world.log << "Error! Recipe [current[2]] has a length of [current.len] (should be 13)."
	else
		admin_notice("<span class='danger'>Failed to load crafting recipes!</span>", R_DEBUG)

	admin_notice("<span class='danger'>Initializing dictionary...</span>", R_DEBUG)
	sleep(-1)
	var/F4 = file("config/dictionary.txt")
	if (fexists(F4))
		var/list/dictionary_temp = file2list(F4,"\n")
		for (var/i in dictionary_temp)
			if (findtext(i, ","))
				var/list/current = splittext(i, ",")
				dictionary_list += list(current)
				if (current.len != 2)
					world.log << "Error! Dictionary entry [current[1]] has a length of [current.len] (should be 2)."
	else
		admin_notice("<span class='danger'>Failed to load the dictionary!</span>", R_DEBUG)

/////////////////PERSISTENCE STUFF/////////////////////
	var/Fp = file("set_persistent.py")
	if (fexists(Fp))
		shell("sudo python3 /home/1713/rescue.py &")
		log_debug("Executing python3 command 'rescue.py'")
		shell("sudo python3 set_persistent.py")
		log_debug("Executing python3 command 'set_persistent.py'")
//////////////////////////////////////////////////////
	admin_notice("<span class='danger'>Initializations complete.</span>", R_DEBUG)
	sleep(-1)