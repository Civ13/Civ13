/process/ss_combat

/process/ss_combat/setup()
	name = "Combat Subsystem"
	schedule_interval = 1 // Every tick
	priority = PROCESS_PRIORITY_VERY_HIGH
	always_runs = TRUE
	processes.ss_combat = src

/process/ss_combat/fire()
	// Projectiles
	if (processes.projectile)
		processes.projectile.fire_as_member()

	// Throwing
	if (processes.throwing)
		processes.throwing.fire_as_member()

	// Movement
	if (processes.movement)
		processes.movement.fire_as_member()

	// Explosions
	if (processes.explosion)
		processes.explosion.fire_as_member()
