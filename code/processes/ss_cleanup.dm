/process/ss_cleanup

/process/ss_cleanup/setup()
	name = "Cleanup Subsystem"
	schedule_interval = 50 // 5 seconds
	priority = PROCESS_PRIORITY_LOW
	processes.ss_cleanup = src

/process/ss_cleanup/fire()
	// Garbage collection
	if (processes.garbage)
		processes.garbage.fire_as_member()

	// Python bridge
	if (processes.python)
		processes.python.fire_as_member()

	// Paratrooper plane controller
	if (processes.paratrooper_plane)
		processes.paratrooper_plane.fire_as_member()
