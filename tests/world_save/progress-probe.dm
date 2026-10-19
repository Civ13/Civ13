// Test-only generated-copy hooks. Never include in the production DME.
var/global/world_save_progress_active = FALSE
var/global/world_save_progress_started = 0
var/global/world_save_progress_last_write = 0
var/global/world_save_progress_yields = 0
var/global/world_save_progress_yield_ds = 0
var/global/world_save_progress_sleeps = 0
var/global/world_save_progress_sleep_ds = 0
var/global/world_save_progress_unavailable = FALSE
var/global/world_save_progress_error = null
#ifdef WORLD_SAVE_PROGRESS_TEST_CLOCK
var/global/world_save_progress_test_clock = 0
#endif

/proc/world_save_progress_now()
#ifdef WORLD_SAVE_PROGRESS_TEST_CLOCK
#ifdef WORLD_SAVE_PROGRESS_COMPONENT_CLOCK
	// Fixture-only reproduction of the frozen OpenDream realtime component bug.
	return world_save_progress_test_clock % 10
#else
	return world_save_progress_test_clock
#endif
#else
	return world.timeofday
#endif

/proc/world_save_progress_elapsed(started, now)
	// Bounded diagnostic runs are shorter than one day. This is wall time,
	// not a monotonic clock or CPU measurement.
	return (now - started + 864000) % 864000

/proc/world_save_progress_begin()
	world_save_progress_active = TRUE
	world_save_progress_started = world_save_progress_now()
	world_save_progress_last_write = world_save_progress_started
	world_save_progress_yields = 0
	world_save_progress_yield_ds = 0
	world_save_progress_sleeps = 0
	world_save_progress_sleep_ds = 0
	world_save_progress_unavailable = FALSE
	world_save_progress_error = null
	world_save_progress_emit("save_entered", 0, 0, TRUE)

/proc/world_save_progress_stoplag()
	if(!world_save_progress_active) return stoplag()
	var/started = world_save_progress_now()
	world_save_progress_yields++
	. = stoplag()
	world_save_progress_yield_ds += world_save_progress_elapsed(started, world_save_progress_now())

// Separate explicit sleep observations from the historical stoplag counters.
/proc/world_save_progress_sleep(delay)
	if(!world_save_progress_active)
		sleep(delay)
		return
	var/started = world_save_progress_now()
	world_save_progress_sleeps++
	sleep(delay)
	world_save_progress_sleep_ds += world_save_progress_elapsed(started, world_save_progress_now())

/proc/world_save_progress_emit(stage, level, completed_turfs, force = FALSE)
	if(!world_save_progress_active) return
	var/now = world_save_progress_now()
	if(!force && world_save_progress_elapsed(world_save_progress_last_write, now) < 100) return
	world_save_progress_last_write = now
	try
		var/list/row = list("scope" = "test-only serialization progress", "clock_source" = "world.timeofday (24-hour wrap)", "stage" = stage, "level" = level, "completed_turfs" = completed_turfs, "turfs_per_level" = world.maxx * world.maxy, "levels" = world.maxz, "elapsed_real_ds" = world_save_progress_elapsed(world_save_progress_started, now), "world_time_ds" = world.time, "tick_usage_percent" = world.tick_usage, "sleep_calls" = world_save_progress_sleeps, "sleep_elapsed_real_ds" = world_save_progress_sleep_ds, "stoplag_calls" = world_save_progress_yields, "stoplag_elapsed_real_ds" = world_save_progress_yield_ds, "entries_active_level" = map_storage.saving_reference_pins.len, "lists_active_level" = map_storage.saving_list_pins.len, "save_complete_marker" = fexists("map_saves/save_complete.txt"))
#ifdef WORLD_SAVE_PROGRESS_TEST_CLOCK
		row["clock_source"] = "fixture timeofday (24-hour wrap)"
#endif
		var/path = "world_save_progress.json"
		world_save_progress_fault(stage, "json")
		var/encoded = json_encode(row)
		world_save_progress_fault(stage, "delete")
		if(fexists(path) && !fdel(path)) throw EXCEPTION("Could not replace progress diagnostic")
		world_save_progress_fault(stage, "write")
		if(!text2file(encoded, path)) throw EXCEPTION("Could not write progress diagnostic")
		world.log << "SAVE_PROGRESS [encoded]"
	catch(var/exception/E)
#ifdef WORLD_SAVE_PROGRESS_PROPAGATE_FAULT
		// Generated-fixture negative control only; must fail semantic isolation.
		throw E
#endif
		world_save_progress_active = FALSE
		world_save_progress_unavailable = TRUE
		world_save_progress_error = E.name
		// Diagnostics must never change the saver result, including after marker.
		try
			world.log << "SAVE_PROGRESS_UNAVAILABLE [world_save_progress_error]"
		catch(var/exception/log_error)
			world_save_progress_error = copytext("[world_save_progress_error]; log: [log_error.name]", 1, 513)
			return

/proc/world_save_progress_fault(stage, operation)
#ifdef WORLD_SAVE_PROGRESS_FAULT_STAGE
#ifdef WORLD_SAVE_PROGRESS_FAULT_OPERATION
	if(stage == WORLD_SAVE_PROGRESS_FAULT_STAGE && operation == WORLD_SAVE_PROGRESS_FAULT_OPERATION)
		throw EXCEPTION("Injected progress [operation] failure at [stage]")
#endif
#endif
	return
