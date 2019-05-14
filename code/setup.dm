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
	admin_notice("<span class='danger'>Initializations complete.</span>", R_DEBUG)
	sleep(-1)