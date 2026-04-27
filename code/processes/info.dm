/datum/subsystem_module/info
	name = "info"

/datum/subsystem_module/info/fire()
	return

/datum/subsystem_module/info/proc/statProcess()
	stat(null, "Current BYOND tick: #[world.time/world.tick_lag]")