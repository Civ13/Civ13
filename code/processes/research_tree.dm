// ============================================================
// Research Tree Process - drives passive analysis ticks for all
// research benches. Iterates the registered bench list (no world
// scans). One node advances per bench per completed snapshot.
// ============================================================

/process/research_tree

/process/research_tree/setup()
	name = "research tree process"
	schedule_interval = 10 SECONDS
	fires_at_gamestates = list(GAME_STATE_PLAYING)
	priority = PROCESS_PRIORITY_LOW
	processes.research_tree = src

/process/research_tree/fire()
	// Retain the unfinished snapshot across tick-budget returns.
	for (current in current_list)
		var/obj/structure/research_bench/B = current
		if (QDELETED(B))
			research_benches -= B
		else
			try
				B.analysis_tick()
			catch (var/exception/e)
				catchException(e, B)
		PROCESS_LIST_CHECK
		PROCESS_TICK_CHECK

/process/research_tree/reset_current_list()
	PROCESS_USE_FASTEST_LIST(research_benches)

/process/research_tree/statProcess(client/C)
	..(C)
	C.add_stat("[research_benches.len] research benches")

/process/research_tree/htmlProcess()
	return ..() + "[research_benches.len] research benches"
