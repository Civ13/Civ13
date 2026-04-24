/process/ss_combat

/process/ss_combat/setup()
	name = "Combat Subsystem"
	schedule_interval = 1 // Every tick
	priority = PROCESS_PRIORITY_VERY_HIGH
	always_runs = TRUE
	processes.ss_combat = src

/process/ss_combat/fire()
	// Projectiles
	// Check fires_at_gamestates to respect process gamestate restrictions
	if (processes.projectile && (processes.projectile.fires_at_gamestates.len == 0 || (ticker && processes.projectile.fires_at_gamestates.Find(ticker.current_state))))
		processes.projectile.run_time_tick_usage_allowance = 8 // Explicit budget: 8% per member
		processes.projectile.fire_as_member()

	// Throwing
	// Check fires_at_gamestates to respect process gamestate restrictions
	if (processes.throwing && (processes.throwing.fires_at_gamestates.len == 0 || (ticker && processes.throwing.fires_at_gamestates.Find(ticker.current_state))))
		processes.throwing.run_time_tick_usage_allowance = 8 // Explicit budget: 8% per member
		processes.throwing.fire_as_member()

	// TODO: processes.movement does not exist - this was dead code
	// Commenting out as there is no movement process defined
	// if (processes.movement)
	//	processes.movement.fire_as_member()

	// Explosions
	// Check fires_at_gamestates to respect process gamestate restrictions (explosion only runs in PLAYING/FINISHED)
	if (processes.explosion && (processes.explosion.fires_at_gamestates.len == 0 || (ticker && processes.explosion.fires_at_gamestates.Find(ticker.current_state))))
		processes.explosion.run_time_tick_usage_allowance = 8 // Explicit budget: 8% per member
		processes.explosion.fire_as_member()
