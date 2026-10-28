/proc/setup_everything(datum/persistence_area_startup/startup)

	// job_master
	if (!job_master)
		job_master = new /datum/controller/occupations()
		job_master.SetupOccupations()
	//	job_master.LoadJobs("config/jobs.txt")
		admin_notice("<span class='danger'>Job setup complete.</span>", R_DEBUG)

	// ticklag

	world.tick_lag = config.Ticklag

	// objects

	admin_notice("<span class='danger'>Initializing sticker registry...</span>", R_DEBUG)
	sleep(-1)
	init_sticker_registry()

	admin_notice("<span class='danger'>Initializing objects...</span>", R_DEBUG)
	sleep(-1)
	for (var/atom/movable/object in world)
		if (!object.gcDestroyed)
			object.initialize()

	admin_notice("<span class='danger'>Initializing areas...</span>", R_DEBUG)
	sleep(-1)
#ifdef CIV13_ZONE_PERSISTENCE
	if(!startup) throw EXCEPTION("Initial area pass capability missing")
	startup.initialize_areas()
#else
	for (var/area/area in area_list)
		area.initialize()
#endif

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
				switch (current[2])
					if ("Blue Faction")
						faction_list_blue += current[1]
					if ("Red Faction")
						faction_list_red += current[1]
					if ("Faction Organizer")
						faction_list_organizer += current[1]
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
		dictionary_list += parse_dictionary_lines(dictionary_temp)
	else
		admin_notice("<span class='danger'>Failed to load the dictionary!</span>", R_DEBUG)
	sleep(-1)
/////////////////PERSISTENCE STUFF/////////////////////
	// An intended or incomplete startup restore must resolve before a notice.
	var/startup_round_pending = persistence_restart.startup_hold
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
			to_chat(world, "<big><b>The current round has been set as a Persistent Round.</b></big>")
*/
	if (config.allowedgamemodes == "PERSISTENCE")
		map.persistence = TRUE
		map.apply_persistence_age_floor()
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
		to_chat(world, "<big><b>The current round has been set as a Persistent Round.</b></big>")

		// Resume from the last completed save for this map, if any. The daily
		// save+reboot cycle (see start_persistence_loop()) relies on this to
		// carry the world across restarts.
		if (!persistence_restart.startup_hold && fexists("map_saves/map.txt"))
			// Any existing save needs resolution, even if its header is unreadable
			// or for another map. Do not announce a provisional fresh identity.
			startup_round_pending = TRUE
			var/saved_metadata_text
			try
				saved_metadata_text = file2text("map_saves/map.txt")
			catch
				world.log << "Saved map metadata could not be read; round announcement remains pending."
			var/list/saved_meta = istext(saved_metadata_text) ? splittext(saved_metadata_text, "\n") : list()
			if (saved_meta.len && saved_meta[1] == map.ID)
				if (fexists("map_saves/save_complete.txt"))
					startup_round_pending = TRUE
					nextsave = world.realtime + 216000 // don't immediately resave what we are about to load
					spawn(50)
						if (ticker)
							to_chat(world, "<big><b>Restoring the world from the last persistent save...</b></big>")
							if(ticker.loadmap()) announce_restored_round_once()
				else
					startup_round_pending = TRUE
					admin_notice("<span class='danger'>A map save exists but has no completion marker (interrupted save?). Not auto-loading; restore map_saves/ from map_backups/ and use the Load Map verb if needed.</span>", R_DEBUG)
			else
				admin_notice("<span class='danger'>Found a map save for '[saved_meta.len ? saved_meta[1] : "unknown"]' but the current map is '[map.ID]'. Not auto-loading.</span>", R_DEBUG)
		else if (!persistence_restart.startup_hold && fexists("map_saves/save_complete.txt"))
			startup_round_pending = TRUE
			admin_notice("<span class='danger'>A save completion marker exists without map metadata. Not auto-loading or announcing a round.</span>", R_DEBUG)

	// All constructors/configuration are initialized before importing. An intent
	// applies independently of the PERSISTENCE gamemode configuration above.
	if(persistence_restart.startup_hold)
		nextsave = world.realtime + 216000
		spawn(50)
			if(ticker && persistence_restart.resume_startup() && persistence_restart.players_ready)
				announce_restored_round_once()
	if(!startup_round_pending)
		announce_round_start_once()
	//////////////////////////////////////////////////////
	admin_notice("<span class='danger'>Initializations complete.</span>", R_DEBUG)
	sleep(-1)
