// index of all processes
var/datum/process_list/processes = new

/datum/process_list

	// --- Subsystems (top-level scheduler entries) ---
	var/process/ss_utility/ss_utility = null
	var/process/ss_environment/ss_environment = null
	var/process/ss_game/ss_game = null
	var/process/ss_combat/ss_combat = null
	var/process/ss_life/ss_life = null
	var/process/ss_cleanup/ss_cleanup = null

	// --- Subsystem Members (driven by subsystems, not the main scheduler) ---

	// SSUtility members
	var/process/nanoUI/nanoUI = null
	var/process/scheduler/scheduler = null
	var/process/vote/vote = null
	var/process/time_track/time_track = null
	var/process/ping_track/ping_track = null
	var/process/client/client = null

	// SSEnvironment members
	var/process/time_of_day/time_of_day = null
	var/process/time_of_day_change/time_of_day_change = null
	var/process/weather/weather = null
	var/process/lighting_sources/lighting_sources = null
	var/process/lighting_overlays/lighting_overlays = null
	var/process/cleanables/cleanables = null
	var/process/casings/casings = null
	var/process/self_cleaning/self_cleaning = null

	// SSGame members
	var/process/ticker/ticker = null
	var/process/gamemode/gamemode = null
	var/process/job_data/job_data = null
	var/process/mapswap/mapswap = null
	var/process/epochswap/epochswap = null
	var/process/supply/supply = null
	var/process/map/map = null
	var/process/battle_report/battle_report = null

	// SSCombat members
	var/process/projectile/projectile = null
	var/process/throwing/throwing = null
	var/process/movement/movement = null
	var/process/explosion/explosion = null

	// SSLife members
	var/process/mob/mob = null
	var/process/obj/obj = null
	var/process/dog/dog = null
	var/process/chemistry/chemistry = null
	var/process/burning_objs/burning_objs = null
	var/process/burning_turfs/burning_turfs = null

	// SSCleanup members
	var/process/garbage/garbage = null
	var/process/python/python = null

	// --- Standalone processes (run directly by the main scheduler) ---
	// (processes not yet migrated to a subsystem remain here)
	var/process/callproc/callproc = null
	
	// --- Internal tracking ---
	var/next_get_num_processes = -1
	var/last_num_processes = 0

/datum/process_list/proc/get_num_processes()
	if (world.time >= next_get_num_processes)
		. = 0
		for (var/varname in vars)
			if (istype(vars[varname], /process))
				++.
		last_num_processes = .
		next_get_num_processes = world.time + 50
	else
		return last_num_processes
