// At most 128 registered sources per second, independent of world dimensions.
/process/civ_generation/setup()
	name = "civilian electrical generation"
	schedule_interval = 1 SECOND
	start_delay = 1 SECOND
	priority = PROCESS_PRIORITY_LOW
	fires_at_gamestates = list(GAME_STATE_PLAYING)
	processes.civ_generation = src

/process/civ_generation/fire()
	for (var/obj/structure/civ_generator/G in civ_generators.Copy())
		G.settle_generation()
	// Meters copy the totals that settling just published (power_meter.dm).
	for (var/obj/structure/power_meter/M in power_meters)
		M.sample()
