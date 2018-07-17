/proc/setup_everything()

	// job_master
	if (!job_master)
		job_master = new /datum/controller/occupations()
		job_master.SetupOccupations()
	//	job_master.LoadJobs("config/jobs.txt")
		admin_notice("<span class='danger'>Job setup complete</span>", R_DEBUG)

	// ticklag

	world.tick_lag = config.Ticklag

	// objects

	admin_notice("<span class='danger'>Initializing objects</span>", R_DEBUG)
	sleep(-1)
	for (var/atom/movable/object in world)
		if (!object.gcDestroyed)
			object.initialize()

	admin_notice("<span class='danger'>Initializing areas</span>", R_DEBUG)
	sleep(-1)
	for (var/area/area in area_list)
		area.initialize()

	// Set up antagonists.
//	populate_antag_type_list()

	//Set up spawn points.
	//populate_spawn_points()

	admin_notice("<span class='danger'>Initializations complete.</span>", R_DEBUG)
	sleep(-1)