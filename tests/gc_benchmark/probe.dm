// Production GC and actual PROCESS_TICK_CHECK; isolated native weak references.
/proc/gc_benchmark_prepare(mode, batches)
	var/process/garbage/G = new
	processes.garbage = G
	G.priority = PROCESS_PRIORITY_VERY_HIGH
	var/list/weak = list()
	var/list/refs = list()
	var/stamp = world.time - 1000
	for (var/b = 1 to batches)
		var/hard = mode == "soft" ? 0 : (mode == "hard" ? 370 : 30)
		var/soft = 370 - hard
		for (var/i = 1 to hard)
			var/obj/probe/A = new
			A.hint = QDEL_HINT_HARDDEL
			qdel(A)
			A.gcDestroyed = stamp
			G.destroyed["\ref[A]"] = stamp
			A = null
		for (var/i = 1 to soft)
			var/obj/probe/A = new
			qdel(A)
			G.destroyed["\ref[A]"] = stamp
			refs += "\ref[A]"
			weak += A
			A = null
	weak.Cut()
	sleep(2)
	for (var/ref_id in refs)
		check(!locate(ref_id), "native weak target settled before timing")
	return G
/proc/gc_benchmark_checks()
	check(!world.port && !world.OpenPort(1), "closed runtime port")
	var/process/garbage/G = gc_benchmark_prepare("mixed", 1)
	G.fire()
	var/is_baseline = world.params["baseline"]
	check(G.hard_dels == 30 && G.queued_drained == (is_baseline ? 30 : 300), "mixed first pass preserves forced and candidate budgets")
	while (G.destroyed.len)
		G.fire()
	check(G.soft_dels == 340 && G.hard_dels == 30, "mixed eventual drain")
	G = gc_benchmark_prepare("hard", 1)
	G.fire()
	check(G.hard_dels == 30 && G.destroyed.len == 340, "hard budget remains thirty")
	while (G.destroyed.len)
		G.fire()
	G = new
	processes.garbage = G
	G.priority = PROCESS_PRIORITY_VERY_HIGH
	var/obj/probe/young = new
	young.hint = QDEL_HINT_HARDDEL
	qdel(young)
	G.fire()
	check(young && G.destroyed.len == 1 && !G.queued_drained, "full native thirty second expiry remains")
	G.destroyed["\ref[young]"] = world.time - 299
	G.fire()
	check(young && !G.queued_drained, "not expired at twenty nine point nine seconds")
	del(young)
	G.destroyed.Cut()
	G.hard_references.Cut()
	var/datum/live = new
	var/ref_id = "\ref[live]"
	G.destroyed[ref_id] = world.time - 1000
	G.destroyed["missing-second-entry"] = world.time - 1000
	G.priority = PROCESS_PRIORITY_HIGH
	G.run_time_tick_usage = world.tick_usage
	G.run_time_tick_usage_allowance = -1
	check(G.fire() == PROCESS_TICK_CHECK_RETURNED_EARLY, "actual production macro returns early on budget")
	check(live && G.destroyed.len == 1 && G.soft_dels == 1 && !G.hard_dels, "budget return preserves mismatched live identity and queue")
	live = null
	sleep(2)
	check(!locate(ref_id), "collector stack releases local live target after early return")
	G.run_time_tick_usage = world.tick_usage
	check(G.fire() == PROCESS_TICK_CHECK_RETURNED_EARLY && !G.destroyed.len && G.soft_dels == 2, "next fire resumes remaining queue")
	G = null
	sleep(2)
/world/New()
	world.OpenPort("none")
	try
		gc_benchmark_checks()
		var/id = 0
		var/repetitions = text2num(world.params["repetitions"])
		var/batches = text2num(world.params["batches"])
		for (var/mode in list("soft", "hard", "mixed"))
			// Warmup is settled and drained, excluded from measurement.
			var/process/garbage/G = gc_benchmark_prepare(mode, 2)
			while (G.destroyed.len)
				G.fire()
			G = null
			sleep(2)
			for (var/rep = 1 to repetitions)
				G = gc_benchmark_prepare(mode, batches)
				id++
				text2file("ready", "begin-[id].txt")
				while (!fexists("ack-[id].txt"))
					sleep(1)
				var/start = world.timeofday
				var/passes = 0
				var/first_drained = 0
				while (G.destroyed.len)
					var/previous = G.queued_drained
					var/previous_hard = G.hard_dels
					G.fire()
					passes++
					if (passes == 1)
						first_drained = G.queued_drained
					check(G.queued_drained - previous <= 300 && G.hard_dels - previous_hard <= 30, "per fire budgets")
					check(G.queued_drained > previous, "each expired pass progresses")
				var/elapsed = (world.timeofday - start + 864000) % 864000
				check(G.queued_drained == batches * 370 && !G.hard_references.len, "all queued records and strong owners clear")
				text2file(json_encode(list("mode"=mode, "rep"=rep, "records"=batches*370, "passes"=passes, "first_drained"=first_drained, "soft"=G.soft_dels, "hard"=G.hard_dels, "elapsed_deciseconds"=elapsed)), "end-[id].json")
				while (!fexists("end-ack-[id].txt"))
					sleep(1)
				G = null
				sleep(2)
		text2file("PASS: [assertions] collector benchmark assertions", "result.txt")
	catch (var/exception/E)
		text2file("FAIL: [E]", "result.txt")
	sleep(2)
	del(world)
