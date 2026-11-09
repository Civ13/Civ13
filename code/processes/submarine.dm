// ============================================================
// Submarine Process - drives the overworld simulation and
// flooding/atmos tick for SUBCOM13 game mode.
// ============================================================

/process/submarine

/process/submarine/setup()
	name = "submarine process"
	schedule_interval = 1 SECOND
	fires_at_gamestates = list(GAME_STATE_PLAYING)
	priority = PROCESS_PRIORITY_MEDIUM
	processes.submarine = src

/process/submarine/fire()
	if(global.subcom_map)
		global.subcom_map.process_tick()
	// A copy: a sinking vessel takes its controller out of the list mid-tick.
	for(var/datum/flooding_controller/F in flooding_controllers.Copy())
		F.process_tick()
	// Process physical submarine machinery (bilge pumps, scrubbers, etc.)
	for(var/obj/structure/machinery/sub_physical/M in sub_physical_machines.Copy())
		if(!QDELETED(M))
			M.process()
		else
			sub_physical_machines -= M
