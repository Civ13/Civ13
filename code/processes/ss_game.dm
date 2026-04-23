/process/ss_game
	var/next_mapswap = 0

/process/ss_game/setup()
	name = "Game Subsystem"
	schedule_interval = 20 // 2 seconds
	priority = PROCESS_PRIORITY_HIGH
	processes.ss_game = src

/process/ss_game/fire()
	// Ticker logic
	if (processes.ticker)
		processes.ticker.fire_as_member()

	// Gamemode logic
	if (processes.gamemode)
		processes.gamemode.fire_as_member()

	// Job Data logic
	if (processes.job_data)
		processes.job_data.fire_as_member()

	// Map/Epoch swapping (every 5 seconds)
	if (world.time >= next_mapswap)
		if (processes.mapswap)
			processes.mapswap.fire_as_member()
		if (processes.epochswap)
			processes.epochswap.fire_as_member()
		next_mapswap = world.time + 50

	// Supply logic
	if (processes.supply)
		processes.supply.fire_as_member()

	// Map tick
	if (processes.map)
		processes.map.fire_as_member()

	// Battle report
	if (processes.battle_report)
		processes.battle_report.fire_as_member()
