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
	if(global.subcom_flooding)
		global.subcom_flooding.process_tick()
