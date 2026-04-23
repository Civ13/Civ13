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
		processes.time_of_day.fire_as_member()
	if (processes.time_of_day_change)
		processes.time_of_day_change.fire_as_member()

	// Weather logic (every 5 seconds)
	if (world.time >= next_weather)
		if (processes.weather)
			processes.weather.fire_as_member()
		next_weather = world.time + 50

	// Lighting logic (every 1 second)
	if (world.time >= next_lighting)
		if (processes.lighting_sources)
			processes.lighting_sources.fire_as_member()
		if (processes.lighting_overlays)
			processes.lighting_overlays.fire_as_member()
		next_lighting = world.time + 10

	// Cleanup tasks (every 10 seconds)
	if (world.time >= next_cleanup)
		if (processes.cleanables)
			processes.cleanables.fire_as_member()
		if (processes.casings)
			processes.casings.fire_as_member()
		if (processes.self_cleaning)
			processes.self_cleaning.fire_as_member()
		next_cleanup = world.time + 100
