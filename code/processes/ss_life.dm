/process/ss_life

/process/ss_life/setup()
	name = "Life Subsystem"
	schedule_interval = 2 // 0.2 seconds
	priority = PROCESS_PRIORITY_HIGH
	processes.ss_life = src

/process/ss_life/fire()
	// Mob Life
	if (processes.mob)
		processes.mob.fire_as_member()

	// Object processing
	if (processes.obj)
		processes.obj.fire_as_member()

	// Dog AI/Life
	if (processes.dog)
		processes.dog.fire_as_member()

	// Chemistry
	if (processes.chemistry)
		processes.chemistry.fire_as_member()

	// Hazards
	if (processes.burning_objs)
		processes.burning_objs.fire_as_member()
	if (processes.burning_turfs)
		processes.burning_turfs.fire_as_member()
