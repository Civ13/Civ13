/obj/probe/profile_sleeper/Destroy()
	sleep(2)
	return ..()

/obj/probe/profile_self_delete/Destroy()
	del(src)

/world/New()
	world.OpenPort("none")
	try
		processes.garbage = new
		processes.callproc = new
		processes.callproc.setup()
		var/process/garbage/G = processes.garbage
		var/obj/probe/A = new
		A.reentry = TRUE
		qdel(A)
		qdel(A)
		var/list/row = G.deletion_profile["/obj/probe"]
		check(row && row["cleanup_count"] == 1, "cleanup hook counts once across recursive and repeated qdel")
		check(!row["forced_count"], "queued cleanup is separate from forced deletion")
		A.gcDestroyed = world.time - 1000
		G.destroyed["\ref[A]"] = A.gcDestroyed
		G.fire()
		check(!A && row["forced_count"] == 1, "collector times actual forced deletion")
		var/obj/probe/now = new
		now.hint = QDEL_HINT_HARDDEL_NOW
		qdel(now)
		check(!now && row["cleanup_count"] == 2 && row["forced_count"] == 2, "immediate hint has separate cleanup and forced costs")
		var/obj/probe/live = new
		live.hint = QDEL_HINT_LETMELIVE
		qdel(live)
		check(live && !QDELETED(live) && row["cleanup_count"] == 3 && row["forced_count"] == 2, "let-live cleanup does not claim forced deletion")
		var/obj/probe/profile_sleeper/S = new
		qdel(S)
		var/list/sleep_row = G.deletion_profile["/obj/probe/profile_sleeper"]
		check(sleep_row["cleanup_yielded"] == 1 && sleep_row["cleanup_total_ds"] >= 1 && sleep_row["cleanup_max_ds"] == sleep_row["cleanup_total_ds"], "yielded cleanup measures elapsed wall time")
		var/obj/probe/profile_self_delete/D = new
		qdel(D)
		var/list/self_row = G.deletion_profile["/obj/probe/profile_self_delete"]
		check(!D && self_row["cleanup_count"] == 1 && !self_row["forced_count"], "self-deleting cleanup retains type identity without retaining target")
		var/list/snapshot = G.profile_snapshot()
		var/list/copied = snapshot["/obj/probe"]
		copied["cleanup_count"] = -1
		check(row["cleanup_count"] == 3, "read-only snapshot does not alias internal rows")
		for (var/i = 1 to 200)
			G.profile_cost("fixture-type-[i]", FALSE, world.timeofday, world.time)
		check(G.deletion_profile.len == 129, "type rows stay bounded including overflow")
		var/list/overflow = G.deletion_profile["(other types)"]
		check(overflow["cleanup_count"] == 75, "overflow aggregates all excess types")
		for (var/type_name in G.deletion_profile)
			check(istext(type_name), "profile keys are strings")
			var/list/values = G.deletion_profile[type_name]
			for (var/key in values)
				check(istext(key) && isnum(values[key]), "profile retains only scalar values")
		var/process/garbage/timing = new
		profile_fixture_clock = 10
		timing.profile_cost("timing", FALSE, 5, world.time)
		timing.profile_cost("timing", FALSE, 8, world.time)
		var/list/timing_row = timing.profile_row("timing")
		check(timing_row["cleanup_count"] == 2 && timing_row["cleanup_total_ds"] == 7 && timing_row["cleanup_max_ds"] == 5, "totals and maxima aggregate separate elapsed samples")
		profile_fixture_clock = 1
		timing.profile_cost("midnight", TRUE, 863998, world.time)
		var/list/wrap_row = timing.profile_row("midnight")
		check(wrap_row["forced_count"] == 1 && wrap_row["forced_total_ds"] == 3 && wrap_row["forced_max_ds"] == 3, "elapsed samples handle one midnight wrap")
		profile_fixture_clock = null
		var/overhead_started = world.timeofday
		for (var/i = 1 to 10000)
			timing.profile_cost("timing", FALSE, world.timeofday, world.time)
		text2file("10000 scalar profile updates elapsed_ds=[world.timeofday - overhead_started]; coarse isolated wall time, not full-game overhead", "benchmark.txt")
		collector_checks()
		text2file("PASS: [assertions] GC profiling assertions", "result.txt")
	catch (var/exception/E)
		text2file("FAIL: [E]", "result.txt")
	del(world)
