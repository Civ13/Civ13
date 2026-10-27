// Real qdel/engine collection with an accelerated queue age; production caps unchanged.
/proc/collector_checks()
	check(!world.port && !world.OpenPort(1), "collector fixture closes and refuses its port")
	var/process/garbage/G = processes.garbage
	var/old_stamp = world.time - 1000
	for (var/cycle = 1 to 20)
		G = new
		processes.garbage = G
		var/list/weak_refs = list()
		var/list/weak_targets = list()
		var/list/hard_targets = list()
		for (var/i = 1 to 30)
			var/obj/probe/A = new
			A.hint = QDEL_HINT_HARDDEL
			qdel(A)
			A.gcDestroyed = old_stamp
			G.destroyed["\ref[A]"] = old_stamp
			hard_targets += A
		for (var/i = 1 to 340)
			var/obj/probe/A = new
			qdel(A)
			G.destroyed["\ref[A]"] = old_stamp
			weak_refs += "\ref[A]"
			weak_targets += A
			A = null
		weak_targets.Cut()
		sleep(1)
		for (var/ref_id in weak_refs)
			check(!locate(ref_id), "unowned queued atom is collected natively")
		G.fire()
		if (cycle == 1)
			text2file("mixed_queue_initial=370 first_pass_drained=[G.queued_drained] first_pass_remaining=[G.destroyed.len] forced_deleted=[G.hard_dels] soft_drained=[G.soft_dels]", "benchmark.txt")
		check(G.hard_dels == 30 && G.soft_dels == 270 && G.queued_drained == 300 && G.destroyed.len == 70, "soft records drain after forced budget without exceeding candidate cap")
		check(!G.hard_references.len, "drained forced targets release all strong owners")
		for (var/obj/probe/A in hard_targets)
			check(!A, "forced targets are physically deleted")
		G.fire()
		check(!G.destroyed.len && G.queued_drained == 370 && G.hard_dels == 30, "remaining soft records clear on the next bounded pass")

	G = new
	processes.garbage = G
	var/obj/probe/last_hard
	for (var/i = 1 to 31)
		var/obj/probe/A = new
		A.hint = QDEL_HINT_HARDDEL
		qdel(A)
		A.gcDestroyed = old_stamp
		G.destroyed["\ref[A]"] = old_stamp
		last_hard = A
	var/list/weak_targets = list()
	for (var/i = 1 to 10)
		var/obj/probe/A = new
		qdel(A)
		G.destroyed["\ref[A]"] = old_stamp
		weak_targets += A
		A = null
	weak_targets.Cut()
	sleep(1)
	G.fire()
	check(G.hard_dels == 30 && G.queued_drained == 30 && G.destroyed.len == 11 && last_hard, "next forced target waits after the hard-delete cap")
	G.fire()
	check(!G.destroyed.len && !last_hard && G.hard_dels == 31 && G.soft_dels == 10, "waiting forced target and trailing soft entries resume")

	G = new
	processes.garbage = G
	var/obj/probe/young = new
	young.hint = QDEL_HINT_HARDDEL
	qdel(young)
	G.fire()
	check(young && G.destroyed.len == 1 && !G.queued_drained, "young queued target retains the full collection timeout")
	var/obj/probe/reused = new
	G.destroyed.Cut()
	G.hard_references.Cut()
	G.destroyed["\ref[reused]"] = old_stamp
	G.fire()
	check(reused && !G.destroyed.len && !G.hard_dels, "collector preserves a mismatched live identity")
