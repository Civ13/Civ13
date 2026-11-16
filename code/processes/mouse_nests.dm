// Settles mouse nests a couple at a time and lets mice out near players (code/modules/ecology/mouse_nests.dm).
#define MOUSE_PROCESS_SETTLES 2
#define MOUSE_PROCESS_OUT_CAP 40

/process/mouse_nests/setup()
	name = "mouse nests"
	schedule_interval = 10 SECONDS
	start_delay = 30 SECONDS
	priority = PROCESS_PRIORITY_LOW
	fires_at_gamestates = list(GAME_STATE_PLAYING)
	processes.mouse_nests = src

/process/mouse_nests/fire()
	if (persistence_active_operation || persistence_save_in_progress)
		return
	if (!ecology_world_unwatched)
		var/now = trap_now_minutes()
		var/checks = min(MOUSE_PROCESS_SETTLES, mouse_nest_list.len)
		while (checks-- > 0 && mouse_nest_list.len)
			if (mouse_nest_cursor > mouse_nest_list.len)
				mouse_nest_cursor = 1
			var/obj/structure/mouse_nest/N = mouse_nest_list[mouse_nest_cursor]
			mouse_nest_cursor++
			if (QDELETED(N))
				mouse_nest_list -= N
				continue
			N.settle(now)
	// Emerging is a cheap check per nest: observers are bucketed by area.
	for (var/obj/structure/mouse_nest/N in mouse_nest_list)
		if (mouse_out_list.len >= MOUSE_PROCESS_OUT_CAP)
			break
		N.try_emerge()

/process/mouse_nests/reset_current_list()
	return

#undef MOUSE_PROCESS_SETTLES
#undef MOUSE_PROCESS_OUT_CAP
