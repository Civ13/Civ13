// Generated-copy profiling only. No production DME or serialization changes.
var/global/world_save_profile_current = "other"
var/global/world_save_profile_since = 0
var/global/list/world_save_profile_totals
var/global/world_save_profile_visited = 0
var/global/world_save_profile_selected = 0
var/global/world_save_profile_objects = 0
var/global/world_save_profile_values = 0

/proc/world_save_profile_begin(started)
	world_save_profile_current = "other"
	world_save_profile_since = started
	world_save_profile_totals = list("other" = 0, "traversal" = 0, "object" = 0, "value" = 0, "index" = 0, "yield" = 0)
	world_save_profile_visited = 0
	world_save_profile_selected = 0
	world_save_profile_objects = 0
	world_save_profile_values = 0

/proc/world_save_profile_phase(next_phase)
	if(!world_save_progress_active || !world_save_profile_totals)
		return world_save_profile_current
#ifdef WORLD_SAVE_PHASE_COLLAPSE_VALUES
	if(next_phase == "value") next_phase = "object"
#endif
	var/now = world_save_progress_now()
	world_save_profile_totals[world_save_profile_current] += world_save_progress_elapsed(world_save_profile_since, now)
	. = world_save_profile_current
	world_save_profile_current = next_phase
	world_save_profile_since = now

/proc/world_save_profile_row(list/row)
	world_save_profile_phase(world_save_profile_current)
	row["elapsed_real_ds"] = world_save_progress_elapsed(world_save_progress_started, world_save_profile_since)
	row["phase_wall_ds"] = world_save_profile_totals.Copy()
	row["visited_turfs_all_levels"] = world_save_profile_visited
	row["selected_turfs_all_levels"] = world_save_profile_selected
	row["object_calls_including_references"] = world_save_profile_objects
	row["value_calls_including_recursive"] = world_save_profile_values
	row["phase_scope"] = "exclusive active DM regions; 0.1s wall clock; native work inline included; yield includes engine flush; diagnostic overhead included; not CPU"
