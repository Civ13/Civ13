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

	admin_notice("<span class='danger'>Initializing factionlist...</span>", R_DEBUG)
	sleep(-1)
	var/F6 = file("SQL/factionlist.txt")
	if (fexists(F6))
		var/list/flist_temp = file2list(F6,"\n")
		for (var/i in flist_temp)
			if (findtext(i, ";"))
				var/list/current = splittext(i, ";")
				if (current[2] == "red")
					faction_list_red += current[1]
				else if (current[2] == "blue")
					faction_list_blue += current[1]
	else
		admin_notice("<span class='danger'>Failed to load factionlist!</span>", R_DEBUG)
	admin_notice("<span class='danger'>Initializing ban list...</span>", R_DEBUG)
	sleep(-1)
	if (load_bans())
	else
		admin_notice("<span class='danger'>Failed to load ban list!</span>", R_DEBUG)

	admin_notice("<span class='danger'>Initializing crafting recipes...</span>", R_DEBUG)
	sleep(-1)

	var/all_craft_lists = flist("config/crafting/")

	for (var/i in all_craft_lists)
		var/current_list = "global"
		var/F3 = file("config/crafting/[i]")
		current_list = replacetext(i,"material_recipes_","")
		current_list = replacetext(current_list,".txt","")
		if (fexists(F3) && findtext(i,"material_recipes"))
			var/list/craftlist_temp = file2list(F3,"\n")
			for (var/j in craftlist_temp)
				if (findtext(j, ",") && findtext(j,"RECIPE: ") && !(findtext(j,"//")))
					var/tmpj = replacetext(j, "RECIPE: ", "")
					var/list/current = splittext(tmpj, ",")
					craftlist_lists[current_list] += list(current)
					if (current.len != 13)
						world.log << "Error! Recipe [current[2]] has a length of [current.len] (should be 13) ([current_list])."
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
	sleep(-1)
/////////////////PERSISTENCE STUFF/////////////////////
/*	var/Fp = file("set_persistent.py")
	if (fexists(Fp))
		shell("sudo python3 /home/1713/rescue.py &")
		log_debug("Executing python3 command 'rescue.py'")
		shell("sudo python3 set_persistent.py")
		log_debug("Executing python3 command 'set_persistent.py'")
		spawn(150)
			map.persistence = TRUE
			map.research_active = FALSE
			if (!map.autoresearch)
				map.autoresearch = TRUE
				spawn(100)
					map.autoresearch_proc()
			map.autoresearch_mult = 0.006
			if (map.default_research < 19)
				map.default_research = 19
			map.gamemode = "Persistent (Auto-Research)"
			config.allow_vote_restart = FALSE
			world << "<big><b>The current round has been set as a Persistent Round.</b></big>"
*/
	if (config.allowedgamemodes == "PERSISTENCE")
		map.persistence = TRUE
		map.research_active = FALSE
		if (!map.autoresearch)
			map.autoresearch = TRUE
			spawn(100)
				map.autoresearch_proc()
		map.autoresearch_mult = 0.006
		if (map.default_research < 19)
			map.default_research = 19
		map.gamemode = "Persistent (Auto-Research)"
		config.allow_vote_restart = FALSE
		world << "<big><b>The current round has been set as a Persistent Round.</b></big>"

	//////////////////////////////////////////////////////
	admin_notice("<span class='danger'>Initializations complete.</span>", R_DEBUG)
	sleep(-1)