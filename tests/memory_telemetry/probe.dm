#define TRUE 1
#define FALSE 0
var/list/grass_turf_list = list()
var/list/water_turf_list = list()
var/list/timed_cleanables = list()
var/list/abandoned_items = list()
var/list/corpse_decay_candidates = list()
var/pooled_count = 0
var/datum/test_processes/processes = new
var/failures = 0
var/checks = 0
var/parent_destroys = 0
/datum/proc/Destroy()
	parent_destroys++
	return 0
/datum/proc/persistence_runtime_var(key)
	return key == "parent_runtime"
/datum/test_processes
	var/process/garbage/garbage = new
	var/process/callproc/callproc = new
/process/garbage
	var/list/destroyed = list()
	var/queue_high_water = 0
	var/enqueued = 0
	var/total_dels = 999
	var/queued_drained = 0
	var/hard_dels = 0
	var/list/logging = list()
	var/list/hard_references = list()
/process/garbage/proc/oldest_queue_seconds()
	return 7
/process/callproc
	var/list/queue = list()
	var/list/helpers = list()
	var/list/by_object = list()
	var/queue_high_water = 0
/proc/check(ok, message)
	checks++
	if (!ok)
		failures++
		world.log << "FAIL [message]"
/proc/scalars(list/row)
	for (var/key in row)
		if (!istext(key) || !isnum(row[key]))
			return FALSE
	return TRUE
/world
	fps = 10
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/world/Error(exception/E)
	world.log << "RUNTIME [E]"
	failures++
/world/New()
	OpenPort("none")
	spawn(0)
		run_tests()
/proc/run_tests()
	check(!world.port && !world.OpenPort(12345), "native fixture refuses listening port")
	var/datum/owner = new
	grass_turf_list += owner
	water_turf_list.len = 2
	timed_cleanables.len = 3
	abandoned_items.len = 4
	corpse_decay_candidates.len = 5
	pooled_count = 6
	processes.garbage.destroyed.len = 8
	processes.garbage.queue_high_water = 9
	processes.garbage.enqueued = 100
	processes.garbage.queued_drained = 50
	processes.garbage.hard_dels = 11
	processes.garbage.logging["/test"] = 11
	processes.garbage.hard_references += owner
	processes.callproc.queue += owner
	processes.callproc.helpers.len = 12
	processes.callproc.by_object[owner] = 1
	processes.callproc.queue_high_water = 13
	var/list/snapshot = memory_lifetime_snapshot()
	check(scalars(snapshot), "snapshot retains only scalars")
	check(snapshot["gc_queued"] == 8 && snapshot["gc_oldest_seconds"] == 7 && snapshot["gc_high_water"] == 9, "GC queue projection")
	check(snapshot["gc_enqueued"] == 100 && snapshot["gc_drained"] == 50 && snapshot["gc_forced"] == 11 && snapshot["gc_forced_types"] == 1 && snapshot["gc_forced_owners"] == 1, "GC totals projection")
	check(snapshot["helper_queued"] == 1 && snapshot["helper_reserve"] == 12 && snapshot["helper_targets"] == 1 && snapshot["helper_high_water"] == 13 && snapshot["pooled"] == 6, "helper/pool projection")
	check(snapshot["grass"] == 1 && snapshot["water"] == 2 && snapshot["cleanables"] == 3 && snapshot["abandoned_items"] == 4 && snapshot["corpse_candidates"] == 5, "registry projections")
	grass_turf_list.Cut()
	check(snapshot["grass"] == 1, "snapshot does not alias live registry")
	var/datum/memory_lifetime_recorder/R = new
	check(!R.active && !R.run_token && !R.rows.len, "default off")
	sleep(2)
	check(!R.rows.len, "default does not schedule")
	R.last_clock = 863999
	R.record_tick(1)
	check(R.elapsed_seconds == 0.2, "midnight elapsed interval")
	R.reset()
	for (var/i in 1 to 130)
		R.record_tick(i * 10)
	check(R.tick_intervals.len == 120 && R.elapsed_seconds == 130, "tick ring bounded after wrap")
	var/list/metrics = R.interval_metrics()
	check(metrics["observed_tick_interval_p95_seconds"] == 1 && metrics["observed_tick_interval_max_seconds"] == 1, "uniform interval metrics")
	R.reset()
	var/clock = 0
	for (var/i in 1 to 120)
		clock += i
		R.record_tick(clock)
	metrics = R.interval_metrics()
	check(metrics["observed_tick_interval_p95_seconds"] == 11.4 && metrics["observed_tick_interval_max_seconds"] == 12, "nearest-rank p95 and max")
	check(R.tick_intervals[1] == 0.1, "metrics sorting does not mutate ring")
	R.reset()
	row_zero_span(R)
	R.previous_enqueued = 100
	R.previous_drained = 50
	R.record_tick(25)
	processes.garbage.enqueued = 110
	processes.garbage.queued_drained = 55
	var/list/row = R.record_snapshot()
	check(row["observed_window_seconds"] == 2.5 && row["gc_enqueue_per_second"] == 4 && row["gc_drain_per_second"] == 2, "rates use observed seconds")
	check(scalars(row), "row retains only scalars")
	processes.garbage.enqueued = 0
	processes.garbage.queued_drained = 0
	R.record_tick(35)
	row = R.record_snapshot()
	check(row["gc_enqueue_per_second"] == 0 && row["gc_drain_per_second"] == 0, "counter reset rates cannot be negative")
	R.reset()
	for (var/i in 1 to 130)
		R.record_tick(i * 10)
		R.record_snapshot()
	check(R.rows.len == 120 && R.recorded_samples == 130, "snapshot ring bounded after wrap")
	var/list/exported = R.export_rows()
	var/list/first = exported[1]
	var/list/last = exported[120]
	check(first["observed_elapsed_seconds"] == 11 && last["observed_elapsed_seconds"] == 130, "chronological wrapped export")
	first["grass"] = 999
	exported = R.export_rows()
	first = exported[1]
	check(first["grass"] == 0, "export mutation cannot alter retained samples")
	check(R.reset() && !R.rows.len && !R.tick_intervals.len && !R.elapsed_seconds && !R.recorded_samples, "reset releases rings and counters")
	check(R.start(1000) && R.requested_samples == 120, "sample count upper clamp")
	var/list/old_token = R.run_token
	check(!R.start(2) && R.run_token == old_token && !R.reset(), "reentry preserves active invocation")
	R.stop()
	check(!R.active && !R.run_token, "stop invalidates pending loop")
	check(R.start(0) && R.requested_samples == 1, "sample count lower clamp and restart")
	R.observe(old_token)
	sleep(14)
	check(!R.active && R.recorded_samples == 1 && R.rows.len == 1, "native loop finite and old invocation cancelled")
	row = R.rows[1]
	check(row["observed_elapsed_seconds"] >= 1 && scalars(row), "native observed scalar sample")
	R.start(2)
	R.stop()
	sleep(3)
	check(!R.recorded_samples && !R.rows.len, "stop prevents pending capture")
	R.start(2)
	R.Destroy()
	sleep(3)
	check(!R.active && !R.run_token && !R.rows.len && !R.tick_intervals.len && parent_destroys == 1, "Destroy clears owners and delegates")
	check(R.persistence_runtime_var("rows") && R.persistence_runtime_var("run_token") && R.persistence_runtime_var("parent_runtime") && !R.persistence_runtime_var("durable"), "runtime exclusions delegate to parent")
	for (var/key in list("active", "run_token", "tick_intervals", "rows", "tick_cursor", "row_cursor", "last_clock", "elapsed_seconds", "last_row_seconds", "previous_enqueued", "previous_drained", "requested_samples", "recorded_samples"))
		check(R.persistence_runtime_var(key), "runtime exclusion [key]")
	var/datum/test_processes/saved = processes
	processes = null
	snapshot = memory_lifetime_snapshot()
	check(snapshot["gc_queued"] == 0 && snapshot["helper_queued"] == 0 && scalars(snapshot), "uninitialized processes supported")
	processes = saved
	text2file(json_encode(list("checks" = checks, "failures" = failures)), "result.json")
	world.log << "DONE [checks] checks [failures] failures"
	del(world)

/proc/row_zero_span(datum/memory_lifetime_recorder/R)
	var/list/row = R.record_snapshot()
	check(row["gc_enqueue_per_second"] == 0 && row["gc_drain_per_second"] == 0, "zero-duration rates finite")
	R.reset()
