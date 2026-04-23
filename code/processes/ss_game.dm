/process/ss_game
	
/process/ss_game/setup()
	name = "Game Subsystem"
	schedule_interval = 2 // 0.2 seconds
	priority = PROCESS_PRIORITY_HIGH
	processes.ss_game = src

/process/ss_game/fire()
	// Ticker logic
	if (processes.ticker)
		processes.ticker.fire()
	
	// Gamemode logic
	if (processes.gamemode)
		processes.gamemode.fire()
		
	// Job Data logic
	if (processes.job_data)
		processes.job_data.fire()
		
	// Map/Epoch swapping
	if (processes.mapswap)
		processes.mapswap.fire()
	if (processes.epochswap)
		processes.epochswap.fire()
		
	// Supply logic
	if (processes.supply)
		processes.supply.fire()
