/process/subsystem
	var/list/sub_processes = list()

/process/subsystem/fire()
	for (var/datum/sub_process/S in sub_processes)
		if (S.disabled)
			continue
		
		// Check if it's time for this sub-process to fire
		if (world.time < S.next_fire)
			continue
			
		S.fire()
		S.next_fire = world.time + S.fire_interval
		
		PROCESS_TICK_CHECK

/datum/sub_process
	var/name = "sub-process"
	var/disabled = FALSE
	var/fire_interval = 10 // deciseconds
	var/next_fire = 0
	var/process/subsystem/parent

/datum/sub_process/New(process/subsystem/P)
	parent = P

/datum/sub_process/proc/fire()
	return
