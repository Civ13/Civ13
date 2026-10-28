// Inactive data-only prototype. No singleton, process, callbacks or world reads.
// Caller supplies anonymous occupied (z, cell_x, cell_y) rows and elapsed seconds.
/datum/ecology_activity_heatmap
	should_save = FALSE
	var/tmp/configured = FALSE
	var/tmp/coverage_valid = FALSE
	var/tmp/cell_limit = 0
	var/tmp/sample_interval = 0
	var/tmp/decay_half_life = 0
	var/tmp/sample_increment = 0
	var/tmp/last_time = 0
	var/tmp/last_bucket = -1
	var/tmp/epoch = 0
	var/tmp/list/cells = list()

/datum/ecology_activity_heatmap/New(max_cells = 4096, interval = 10, half_life = 600, increment = 0.25)
	..()
	if (!bounded_integer(max_cells, 1, 4096) || !bounded_number(interval, 1, 3600) || !bounded_number(half_life, 1, 86400) || !bounded_number(increment, 0.0001, 1))
		return
	cell_limit = max_cells
	sample_interval = interval
	decay_half_life = half_life
	sample_increment = increment
	configured = TRUE
	coverage_valid = TRUE

/datum/ecology_activity_heatmap/proc/bounded_number(value, low, high)
	// Positive finite ranges reject infinities and NaN without sentinel coercion.
	return isnum(value) && value >= low && value <= high

/datum/ecology_activity_heatmap/proc/bounded_integer(value, low, high)
	return bounded_number(value, low, high) && value == round(value)

/datum/ecology_activity_heatmap/proc/accept_time(now)
	if (!configured || !bounded_number(now, 0, 1000000000) || now < last_time)
		coverage_valid = FALSE
		return FALSE
	last_time = now
	return TRUE

/datum/ecology_activity_heatmap/proc/cell_key(list/row)
	if (!islist(row) || row.len != 3)
		return null
	if (!bounded_integer(row[1], 1, 4096) || !bounded_integer(row[2], 1, 65535) || !bounded_integer(row[3], 1, 65535))
		return null
	return "[row[1]]:[row[2]]:[row[3]]"

/datum/ecology_activity_heatmap/proc/sample(now, list/occupied_cells, complete = FALSE, expected_epoch = null)
	// Reject old geometry before touching the current epoch clock or validity.
	if (isnull(expected_epoch) || expected_epoch != epoch)
		return FALSE
	if (!accept_time(now))
		return FALSE
	// Check before bucket deduplication: even a repeated partial pass invalidates.
	if (complete != TRUE || !islist(occupied_cells) || occupied_cells.len > 256)
		coverage_valid = FALSE
		return FALSE
	if (!coverage_valid)
		return FALSE
	var/bucket = round(now / sample_interval)
	if (bucket == last_bucket)
		return FALSE
	// Validate and stage the entire bounded snapshot before changing any scores.
	var/list/staged = list()
	var/additional = 0
	for (var/i = 1, i <= occupied_cells.len, i++)
		var/key = cell_key(occupied_cells[i])
		if (!key)
			coverage_valid = FALSE
			return FALSE
		if (staged[key])
			continue
		staged[key] = TRUE
		if (!cells[key])
			additional++
	if (cells.len + additional > cell_limit)
		coverage_valid = FALSE
		return FALSE
	for (var/key in staged)
		var/list/old = cells[key]
		var/score = old ? old[1] * (0.5 ** ((now - old[2]) / decay_half_life)) : 0
		cells[key] = list(min(1, score + sample_increment), now)
	last_bucket = bucket
	return TRUE

/datum/ecology_activity_heatmap/proc/pressure(now, list/row, expected_epoch = null)
	if (isnull(expected_epoch) || expected_epoch != epoch)
		return null
	if (!accept_time(now) || !coverage_valid)
		return null // UNKNOWN is distinct from numeric zero.
	var/key = cell_key(row)
	if (!key)
		return null
	var/list/old = cells[key]
	if (!old)
		return 0
	return old[1] * (0.5 ** ((now - old[2]) / decay_half_life))

/datum/ecology_activity_heatmap/proc/reset_epoch(now)
	if (!accept_time(now) || epoch >= 1000000)
		coverage_valid = FALSE
		return FALSE
	epoch++
	cells = list()
	last_bucket = -1
	coverage_valid = TRUE
	return TRUE

/datum/ecology_activity_heatmap/persistence_runtime_var(key)
	// Custom persistence enumerates tmp vars, so exclude each field explicitly.
	switch (key)
		if ("configured", "coverage_valid", "cell_limit", "sample_interval", "decay_half_life", "sample_increment", "last_time", "last_bucket", "epoch", "cells")
			return TRUE
	return ..()

/datum/ecology_activity_heatmap/Destroy()
	configured = FALSE
	coverage_valid = FALSE
	cells = null
	return ..()
