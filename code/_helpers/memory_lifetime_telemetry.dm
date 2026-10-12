// Opt-in lifetime telemetry. No startup singleton, callbacks, entity samples or scans.
/proc/memory_lifetime_snapshot()
	var/process/garbage/G = processes ? processes.garbage : null
	var/process/callproc/C = processes ? processes.callproc : null
	return list(
		"gc_queued" = G ? G.destroyed.len : 0,
		"gc_oldest_seconds" = G ? G.oldest_queue_seconds() : 0,
		"gc_high_water" = G ? G.queue_high_water : 0,
		"gc_enqueued" = G ? G.enqueued : 0,
		"gc_drained" = G ? G.queued_drained : 0,
		"gc_forced" = G ? G.hard_dels : 0,
		"gc_forced_types" = G ? G.logging.len : 0,
		"gc_forced_owners" = G ? G.hard_references.len : 0,
		"pooled" = pooled_count,
		"helper_queued" = C ? C.queue.len : 0,
		"helper_reserve" = C ? C.helpers.len : 0,
		"helper_targets" = C ? C.by_object.len : 0,
		"helper_high_water" = C ? C.queue_high_water : 0,
		"grass" = grass_turf_list.len,
		"water" = water_turf_list.len,
		"cleanables" = timed_cleanables.len,
		"abandoned_items" = abandoned_items.len,
		"corpse_candidates" = corpse_decay_candidates.len)

/datum/memory_lifetime_recorder
	var/tmp/active = FALSE
	var/tmp/list/run_token
	var/tmp/list/tick_intervals = list()
	var/tmp/list/rows = list()
	var/tmp/tick_cursor = 1
	var/tmp/row_cursor = 1
	var/tmp/last_clock = 0
	var/tmp/elapsed_seconds = 0
	var/tmp/last_row_seconds = 0
	var/tmp/previous_enqueued = 0
	var/tmp/previous_drained = 0
	var/tmp/requested_samples = 0
	var/tmp/recorded_samples = 0

/datum/memory_lifetime_recorder/proc/observed_clock()
	return world.timeofday

// A second start cannot replace the state of an active sleeping invocation.
/datum/memory_lifetime_recorder/proc/start(sample_count = 60)
	if (active)
		return FALSE
	reset()
	requested_samples = min(120, max(1, round(sample_count)))
	var/list/initial = memory_lifetime_snapshot()
	previous_enqueued = initial["gc_enqueued"]
	previous_drained = initial["gc_drained"]
	last_clock = observed_clock()
	active = TRUE
	run_token = list()
	var/list/token = run_token
	spawn(0)
		observe(token)
	return TRUE

/datum/memory_lifetime_recorder/proc/observe(list/token)
	while (active && run_token == token)
		sleep(max(1, world.tick_lag))
		if (!active || run_token != token)
			return
		record_tick(observed_clock())
		if (elapsed_seconds - last_row_seconds >= 1)
			record_snapshot()
			if (recorded_samples >= requested_samples)
				stop()

// Real awake intervals in deciseconds, modulo midnight. Not CPU duration.
/datum/memory_lifetime_recorder/proc/record_tick(now)
	var/delta = now - last_clock
	if (delta < 0)
		delta += 864000
	last_clock = now
	elapsed_seconds += delta / 10
	if (tick_intervals.len < 120)
		tick_intervals += delta / 10
	else
		tick_intervals[tick_cursor] = delta / 10
	tick_cursor = (tick_cursor % 120) + 1

// Sort only bounded numeric copies at snapshot time or on request.
/datum/memory_lifetime_recorder/proc/interval_metrics()
	var/list/sorted = tick_intervals.Copy()
	for (var/i in 2 to sorted.len)
		var/value = sorted[i]
		var/j = i - 1
		while (j >= 1 && sorted[j] > value)
			sorted[j + 1] = sorted[j]
			j--
		sorted[j + 1] = value
	if (!sorted.len)
		return list("observed_tick_interval_p95_seconds" = 0, "observed_tick_interval_max_seconds" = 0)
	return list("observed_tick_interval_p95_seconds" = sorted[max(1, -round(-sorted.len * 0.95))], "observed_tick_interval_max_seconds" = sorted[sorted.len])

/datum/memory_lifetime_recorder/proc/record_snapshot()
	var/list/row = memory_lifetime_snapshot()
	var/span = elapsed_seconds - last_row_seconds
	row["observed_elapsed_seconds"] = elapsed_seconds
	row["observed_window_seconds"] = span
	row["gc_enqueue_per_second"] = span > 0 ? max(0, row["gc_enqueued"] - previous_enqueued) / span : 0
	row["gc_drain_per_second"] = span > 0 ? max(0, row["gc_drained"] - previous_drained) / span : 0
	previous_enqueued = row["gc_enqueued"]
	previous_drained = row["gc_drained"]
	last_row_seconds = elapsed_seconds
	var/list/metrics = interval_metrics()
	for (var/key in metrics)
		row[key] = metrics[key]
	if (rows.len < 120)
		rows += list(row)
	else
		rows[row_cursor] = row
	row_cursor = (row_cursor % 120) + 1
	recorded_samples++
	return row

// Export chronological scalar rows, never aliases of internal storage.
/datum/memory_lifetime_recorder/proc/export_rows()
	var/list/result = list()
	for (var/i in 1 to rows.len)
		var/index = rows.len == 120 ? ((row_cursor + i - 2) % 120) + 1 : i
		var/list/row = rows[index]
		result += list(row.Copy())
	return result

/datum/memory_lifetime_recorder/proc/stop()
	active = FALSE
	run_token = null

/datum/memory_lifetime_recorder/proc/reset()
	if (active)
		return FALSE
	run_token = null
	tick_intervals = list()
	rows = list()
	tick_cursor = 1
	row_cursor = 1
	last_clock = 0
	elapsed_seconds = 0
	last_row_seconds = 0
	previous_enqueued = 0
	previous_drained = 0
	requested_samples = 0
	recorded_samples = 0
	return TRUE

/datum/memory_lifetime_recorder/Destroy()
	stop()
	reset()
	return ..()

/datum/memory_lifetime_recorder/persistence_runtime_var(key)
	if (key in list("active", "run_token", "tick_intervals", "rows", "tick_cursor", "row_cursor", "last_clock", "elapsed_seconds", "last_row_seconds", "previous_enqueued", "previous_drained", "requested_samples", "recorded_samples"))
		return TRUE
	return ..()
