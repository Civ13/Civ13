// Exercise the real wait helpers with independent ordinary and heavy workloads.
/proc/probe_overlapping_work(mob/living/human/probe/H)
	H.probe_workload = 1
	spawn(0)
		do_after(H, 28, progress = FALSE, check_for_repeats = FALSE)
	sleep(1)
	consume(H, 0.06912, 0.06912, "light work")
	H.probe_workload = 3
	spawn(0)
		do_after(H, 5, progress = FALSE, check_for_repeats = FALSE)
	spawn(0)
		do_mob(H, H, 12, progress = FALSE)
	sleep(1)
	consume(H, 0.1512, 0.1728, "heavy labour")
	sleep(5)
	check(H.survival_actions == 2, "one heavy wait and the light wait still running")
	consume(H, 0.1512, 0.1728, "remaining heavy labour")
	sleep(8)
	check(H.survival_actions == 1, "only the light wait is still running")
	consume(H, 0.06912, 0.06912, "heavy work ends while light work continues")
	sleep(15)
	check(H.survival_current_workload() == 0, "light labour releases")

/proc/probe_repeat_lock(mob/living/human/probe/H)
	for (var/cancel_earlier in list(FALSE, TRUE))
		var/obj/target = new(locate(1, 1, 1))
		H.probe_workload = 3
		H.probe_wait_finished = FALSE
		H.probe_wait_result = null
		spawn(0)
			H.probe_wait_result = do_after(H, 8, target, progress = FALSE, check_for_repeats = FALSE)
			H.probe_wait_finished = TRUE
		sleep(1)
		H.probe_workload = 2
		spawn(0)
			do_after(H, 20, progress = FALSE)
		sleep(1)
		check(!H.may_do_after && H.survival_actions == 2, "only the second wait holds the repeat lock")
		if (cancel_earlier)
			target.loc = locate(2, 1, 1)
		sleep(8)
		check(H.probe_wait_finished && H.probe_wait_result == !cancel_earlier, "earlier unowned wait reaches intended outcome")
		check(!H.may_do_after && H.survival_actions == 1, "earlier unowned [cancel_earlier ? "cancellation" : "completion"] preserves repeat lock")
		consume(H, 0.0864, 0.0864, "remaining ordinary work uses ordinary rate")
		sleep(12)
		check(H.may_do_after && !H.survival_actions, "repeat lock is available after its owner finishes")
		qdel(target)
