/datum/subsystem_module/info
	name = "info"

/datum/subsystem_module/info/fire()
	return

/datum/subsystem_module/info/proc/statProcess(client/C)
	C.add_stat("Current BYOND tick: #[world.time/world.tick_lag]")
