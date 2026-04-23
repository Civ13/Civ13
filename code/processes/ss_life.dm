/process/ss_life
	
/process/ss_life/setup()
	name = "Life Subsystem"
	schedule_interval = 2 // 0.2 seconds
	priority = PROCESS_PRIORITY_HIGH
	processes.ss_life = src

/process/ss_life/fire()
	// Mob Life
	if (processes.mob)
		processes.mob.fire()
	
	// Object processing
	if (processes.obj)
		processes.obj.fire()
		
	// Dog AI/Life
	if (processes.dog)
		processes.dog.fire()
		
	// Chemistry
	if (processes.chemistry)
		processes.chemistry.fire()
		
	// Hazards
	if (processes.burning_objs)
		processes.burning_objs.fire()
	if (processes.burning_turfs)
		processes.burning_turfs.fire()
