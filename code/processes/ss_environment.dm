/process/ss_environment
	var/next_weather = 0
	var/next_lighting = 0
	var/next_cleanup = 0
	
/process/ss_environment/setup()
	name = "Environment Subsystem"
	schedule_interval = 20 // 2 seconds
	priority = PROCESS_PRIORITY_MEDIUM
	processes.ss_environment = src

/process/ss_environment/fire()
	// Time of Day logic
	if (processes.time_of_day)
		processes.time_of_day.fire()
	if (processes.time_of_day_change)
		processes.time_of_day_change.fire()
		
	// Weather logic
	if (world.time >= next_weather)
		if (processes.weather)
			processes.weather.fire()
		next_weather = world.time + 50
		
	// Lighting logic
	if (world.time >= next_lighting)
		if (processes.lighting_sources)
			processes.lighting_sources.fire()
		if (processes.lighting_overlays)
			processes.lighting_overlays.fire()
		next_lighting = world.time + 10
		
	// Cleanup tasks
	if (world.time >= next_cleanup)
		if (processes.cleanables)
			processes.cleanables.fire()
		if (processes.casings)
			processes.casings.fire()
		if (processes.self_cleaning)
			processes.self_cleaning.fire()
		next_cleanup = world.time + 100
