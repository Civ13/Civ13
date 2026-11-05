// Headless animal AI range-sweep profile (CM-SS13 adoption plan, step 12a).
// Test-only: native_probe.py appends it to a temporary copy of civ13.dme. The
// production code runs unchanged. Once the round is playing, the probe runs
// BYOND's proc profiler for a fixed window and writes the snapshot, the CPU
// and tick usage, and the living animal count. native_probe.py turns that into
// the share of server time spent in animal AI procs (where the range()/view()
// sweeps live). Developer evidence only; it decides whether step 12b (a
// spatial grid) is worth building.
var/global/datum/range_probe/range_probe = new

/datum/range_probe
	var/started_tod = 0
	var/list/result = list("passed" = FALSE, "failure" = null)
	var/list/tick_samples = list()
	var/sampling = FALSE

/datum/range_probe/New()
	if (!all_species || !all_species.len)
		makeDatumRefLists()
	if (!config)
		load_configuration()
		initialize_chemical_reagents()
		initialize_chemical_reactions()
	if (config)
		config.webhook_can_fire = FALSE
		config.ToRban = FALSE
	started_tod = world.timeofday
	spawn(10)
		drive()

/datum/range_probe/proc/scheduler_ready()
	return ticker && processScheduler && processes && ticker.current_state >= GAME_STATE_PREGAME

/datum/range_probe/proc/game_playing()
	return ticker && ticker.current_state == GAME_STATE_PLAYING

/datum/range_probe/proc/wait_for(proc_name, deadline_ds)
	var/until = world.time + deadline_ds
	while (!call(src, proc_name)())
		if (world.time > until)
			throw EXCEPTION("timed out waiting for [proc_name]")
		sleep(10)

/datum/range_probe/proc/sample_ticks()
	set waitfor = FALSE
	while (sampling)
		tick_samples += world.tick_usage
		sleep(world.tick_lag)

/datum/range_probe/proc/drive()
	try
		wait_for("scheduler_ready", 9000)
		if (ticker)
			ticker.admin_started = TRUE
			if (ticker.pregame_timeleft > 1)
				ticker.pregame_timeleft = 1
		wait_for("game_playing", 9000)
		sleep(600) // let roundstart sweeps settle
		var/window = text2num(world.params["window_ds"]) || 6000
		var/animals = 0
		for (var/mob/living/simple_animal/A in living_mob_list)
			if (A.stat != DEAD)
				animals++
		result["living_animals"] = animals
		result["world_fps"] = world.fps
		world.Profile(PROFILE_CLEAR)
		world.Profile(PROFILE_START)
		var/wall_start = world.timeofday
		var/time_start = world.time
		sampling = TRUE
		sample_ticks()
		sleep(window)
		sampling = FALSE
		result["profile"] = world.Profile(PROFILE_REFRESH, null, "json")
		world.Profile(PROFILE_STOP)
		result["window_game_seconds"] = (world.time - time_start) / 10
		result["window_wall_seconds"] = (world.timeofday - wall_start) / 10
		result["cpu"] = world.cpu
		var/total = 0
		var/peak = 0
		for (var/v in tick_samples)
			total += v
			peak = max(peak, v)
		result["ticks"] = tick_samples.len
		result["mean_tick_usage"] = tick_samples.len ? round(total / tick_samples.len, 0.1) : 0
		result["max_tick_usage"] = peak
		result["passed"] = TRUE
	catch (var/exception/e)
		result["failure"] = "[e.name] ([e.file]:[e.line])"
	text2file(json_encode(result), "result.json")
	sleep(5)
	del(world)
