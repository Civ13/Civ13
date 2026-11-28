/proc/check_overlay_gc_state()
	var/process/lighting_overlays/overlays = new
	var/atom/movable/lighting_overlay/retired = new
	var/atom/movable/lighting_overlay/live = new
	retired.gcDestroyed = 1
	active_process = overlays
	lighting_update_overlays = list(null, retired, live)
	overlays.run_time_tick_usage_allowance = 0
	overlays.run_time_tick_usage = world.tick_usage
	if(overlays.fire() != PROCESS_TICK_CHECK_RETURNED_EARLY || overlays.batch_index != 2 || overlays.current_list[2] != retired)
		CRASH("Null overlay slot did not yield")
	overlays.run_time_tick_usage = world.tick_usage
	if(overlays.fire() != PROCESS_TICK_CHECK_RETURNED_EARLY || overlays.batch_index != 3 || overlays.current_list[2])
		CRASH("Retired overlay slot did not yield and release")
	if(retired.calls || !retired.needs_update)
		CRASH("Retired overlay was updated")
	overlays.priority = PROCESS_PRIORITY_VERY_HIGH
	overlays.fire()
	if(live.calls != 1 || live.needs_update || overlays.current_list || lighting_update_overlays.len)
		CRASH("Live overlay did not complete after retired slot")
	active_process = null
	del(retired)
	del(live)
