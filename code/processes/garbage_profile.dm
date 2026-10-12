// Bounded scalar diagnostics. No target, ref ID, or event history is retained.
#define GC_PROFILE_TYPE_LIMIT 128
#define GC_PROFILE_OVERFLOW "(other types)"

/process/garbage
	var/list/deletion_profile = list()

/process/garbage/proc/profile_row(type_name)
	if (!istext(type_name))
		return null
	var/list/row = deletion_profile[type_name]
	if (!row)
		var/type_count = deletion_profile.len - (deletion_profile[GC_PROFILE_OVERFLOW] ? 1 : 0)
		if (type_count >= GC_PROFILE_TYPE_LIMIT)
			type_name = GC_PROFILE_OVERFLOW
			row = deletion_profile[type_name]
		if (!row)
			row = list("cleanup_count" = 0, "cleanup_total_ds" = 0, "cleanup_max_ds" = 0, "cleanup_yielded" = 0, "forced_count" = 0, "forced_total_ds" = 0, "forced_max_ds" = 0, "forced_yielded" = 0)
			deletion_profile[type_name] = row
	return row

// timeofday is elapsed wall time in deciseconds, including waits and scheduling.
/process/garbage/proc/profile_cost(type_name, forced, started, start_tick)
	var/elapsed = world.timeofday - started
	if (elapsed < 0)
		elapsed += 864000
	var/list/row = profile_row(type_name)
	if (!row)
		return
	var/phase = forced ? "forced" : "cleanup"
	row["[phase]_count"]++
	row["[phase]_total_ds"] += elapsed
	row["[phase]_max_ds"] = max(row["[phase]_max_ds"], elapsed)
	if (world.time != start_tick)
		row["[phase]_yielded"]++

/process/garbage/proc/profile_snapshot()
	var/list/result = list()
	for (var/type_name in deletion_profile)
		var/list/row = deletion_profile[type_name]
		result[type_name] = row.Copy()
	return result
