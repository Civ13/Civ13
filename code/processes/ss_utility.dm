/process/ss_utility
	var/next_ping_track = 0
	var/next_time_track = 0

/process/ss_utility/setup()
	name = "Utility Subsystem"
	schedule_interval = 10 // 1 second
	priority = PROCESS_PRIORITY_IRRELEVANT
	processes.ss_utility = src

/process/ss_utility/fire()
	// NanoUI updates
	if (processes.nanoUI)
		processes.nanoUI.fire_as_member()

	// Scheduler (delayed task execution)
	if (processes.scheduler)
		processes.scheduler.fire_as_member()

	// Vote logic
	if (processes.vote)
		processes.vote.fire_as_member()

	// Callproc (train timers etc.)
	if (processes.callproc)
		processes.callproc.fire_as_member()

	// Time Track (every 1 second)
	if (world.time >= next_time_track)
		if (processes.time_track)
			processes.time_track.fire_as_member()
		next_time_track = world.time + 10

	// Ping Track (every 0.5 seconds)
	if (world.time >= next_ping_track)
		if (processes.ping_track)
			processes.ping_track.fire_as_member()
		next_ping_track = world.time + 5

	// Client processing
	if (processes.client)
		processes.client.fire_as_member()

/process/ss_utility/statProcess()
	..()
	stat(null, "Current BYOND tick: #[world.time/world.tick_lag]")
