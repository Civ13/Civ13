// Timer bucket ejection under floating-point drift (run with
// tests/ecology_spawning/run_linux.py, see README.md).
/world
	hub = ""
	hub_password = ""
	maxx = 5
	maxy = 5
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE

// Built by hand: the probe sets timeToRun and the subsystem offsets itself.
/datum/timedevent/timer_probe/New()
	return

var/timer_probe_failures = 0
var/timer_probe_runtime = FALSE
/proc/timer_probe_check(condition, label)
	if (!condition)
		timer_probe_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	timer_probe_runtime = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

/proc/timer_probe_pos(ttr, head)
	return ((round((ttr - head) / world.tick_lag) + 1) % 600) || 600

/world/New()
	OpenPort("none")
	try
		timer_probe_drift()
	catch(var/exception/e)
		timer_probe_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = timer_probe_failures, "runtime_error" = timer_probe_runtime, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/timer_probe_drift()
	SStimer.bucket_list.len = 600
	SStimer.bucket_count = 0
	SStimer.second_queue = list()
	var/tl = world.tick_lag
	// The buckets started 50 ticks ago and the fire loop is up to date.
	var/old_head = world.time - 50 * tl
	SStimer.head_offset = old_head
	SStimer.practical_offset = 51
	// Two events due one bucket before the next lap's 43rd: floor() of the
	// old-head position lands just under 642, so they join bucket 42.
	var/ttr = old_head + 642 * tl - 0.0001
	var/datum/timedevent/timer_probe/A = new
	var/datum/timedevent/timer_probe/B = new
	for (var/datum/timedevent/timer_probe/T in list(A, B))
		T.callBack = new /datum/callback(GLOBAL_PROC, /proc/timer_probe_pos)
		T.flags = 0
		T.timeToRun = ttr
	A.bucketJoin()
	B.bucketJoin()
	var/joined = timer_probe_pos(ttr, old_head)
	timer_probe_check(joined == 42 && A.bucket_pos == 42 && B.bucket_pos == 42 && SStimer.bucket_list[42] == A, "both events join bucket 42 ([joined], [A.bucket_pos])")
	// The lap ends; head_offset carries float error, so recomputing the
	// position now names bucket 43.
	SStimer.head_offset = old_head + 600 * tl - 0.0003
	SStimer.practical_offset = 1
	timer_probe_check(timer_probe_pos(ttr, SStimer.head_offset) == 43, "the drifted head recomputes bucket 43 ([timer_probe_pos(ttr, SStimer.head_offset)])")
	A.bucketEject()
	timer_probe_check(SStimer.bucket_list[42] == B && SStimer.bucket_count == 1 && A.bucket_pos == -1, "ejecting the head hands bucket 42 to the other event")
	B.bucketEject()
	timer_probe_check(isnull(SStimer.bucket_list[42]) && SStimer.bucket_count == 0, "ejecting the last event empties bucket 42")
	// A looping event re-joins after its eject; it must not stay at the head
	// of the bucket being fired, or the fire loop pops it again forever.
	A.timeToRun = SStimer.head_offset + 41 * tl + 20
	A.bucketJoin()
	timer_probe_check(A.bucket_pos != 42 && isnull(SStimer.bucket_list[42]), "a re-joined looping event leaves the fired bucket")
	A.bucketEject()
	// An event in the long-run queue leaves the queue.
	A.timeToRun = world.time + 100000
	A.bucketJoin()
	timer_probe_check(A.bucket_pos == -1 && (A in SStimer.second_queue), "a distant event waits in the long-run queue")
	A.bucketEject()
	timer_probe_check(!(A in SStimer.second_queue) && SStimer.bucket_count == 0, "ejecting it leaves the queue")
