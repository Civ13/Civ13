// Included after the graph probe's common isolated definitions.
var/persistence_save_in_progress = FALSE
/datum/proc/Destroy()
	return
/datum/fixture_metadata
	var/flag = TRUE
	var/value = 17
	var/name_value = "SUMMER"
	var/list/table = list("paid" = 4)
	var/deadline = -1
	var/origin = 0
	var/real_deadline = 0
/datum/fixture_timer_owner
	var/fired = 0
/datum/fixture_timer_owner/proc/tick()
	fired++
/datum/durable_timer_queue/fixture
	var/clock = 100
/datum/durable_timer_queue/fixture/now()
	return clock

/proc/check_contract()
	var/list/full_schema = durable_metadata_map_schema()
	check(full_schema.len == 131, "durable map field inventory changed without test update")
	check(!("season_epoch" in full_schema) && !("faction_symbol_icon" in full_schema), "runtime fields entered contract")
	var/list/schema = list("flag" = "flag", "value" = "number", "name_value" = "text", "table" = "list", "deadline" = "world_time_deadline", "origin" = "world_time_origin", "real_deadline" = "realtime_deadline")
	var/datum/fixture_metadata/source = new
	source.deadline = world.time + 71
	source.origin = world.time - 19
	// Native numeric realtime values have coarser precision at this epoch.
	// Use an exactly representable interval rather than assert nonexistent ticks.
	source.real_deadline = world.realtime + 4096
	var/list/snapshot = durable_metadata_snapshot_fields(source, schema)
	check(snapshot["deadline"] == 71 && snapshot["origin"] == 19 && snapshot["real_deadline"] == 4096, "runtime clock values were not made portable: [snapshot["deadline"]], [snapshot["origin"]], [snapshot["real_deadline"]]")
	sleep(2)
	var/datum/fixture_metadata/target = new
	durable_metadata_restore_fields(target, snapshot, schema)
	check(target.deadline - world.time == 71 && world.time - target.origin == 19 && target.real_deadline - world.realtime == 4096, "clock values did not rebase: [target.deadline - world.time], [world.time - target.origin], [target.real_deadline - world.realtime]")
	check(target.name_value == "SUMMER" && target.table["paid"] == 4, "metadata field values changed")
	source.deadline = -1
	snapshot = durable_metadata_snapshot_fields(source, schema)
	durable_metadata_restore_fields(target, snapshot, schema)
	check(target.deadline == -1, "disabled deadline became active")
	snapshot -= "name_value"
	var/omission_rejected = FALSE
	try
		durable_metadata_restore_fields(target, snapshot, schema)
	catch(var/exception/omission_error)
		omission_rejected = !!omission_error
	check(omission_rejected && target.name_value == "SUMMER", "missing field mutated metadata")
	snapshot["name_value"] = "WINTER"
	snapshot["flag"] = 5
	var/invalid_rejected = FALSE
	try
		durable_metadata_restore_fields(target, snapshot, schema)
	catch(var/exception/invalid_error)
		invalid_rejected = !!invalid_error
	check(invalid_rejected && target.name_value == "SUMMER", "invalid field mutated metadata")

/proc/check_timers()
	var/datum/fixture_timer_owner/owner = new
	var/datum/durable_timer_queue/fixture/Q = new(owner, list("tick" = "tick"))
	check(Q.schedule("tick", 3) && !Q.schedule("tick", 3), "duplicate callback accepted")
	Q.clock = 102
	var/list/state = Q.snapshot()
	check(state["tick"] == 1, "timer remaining delay did not preserve progress")
	Q.clock = 9000
	Q.restore(state)
	sleep(5)
	check(owner.fired == 1 && !Q.pending.len, "old callback survived restored timer or new callback duplicated")
	Q.restore(list("tick" = 1))
	Q.restore(list("tick" = 1))
	sleep(3)
	check(owner.fired == 2, "repeated restoration stacked callbacks")
	Q.schedule("tick", 1)
	var/invalid_rejected = FALSE
	try
		Q.restore(list("unknown" = 1))
	catch(var/exception/invalid_error)
		invalid_rejected = !!invalid_error
	sleep(3)
	check(invalid_rejected && owner.fired == 3, "invalid restore cancelled valid pending callback")
	persistence_save_in_progress = TRUE
	Q.schedule("tick", 1)
	sleep(3)
	check(owner.fired == 3, "timer fired while save/load lock was owned")
	persistence_save_in_progress = FALSE
	sleep(3)
	check(owner.fired == 4, "deferred callback did not resume exactly once")
	Q.schedule("tick", 1)
	Q.cancel_all()
	sleep(3)
	check(owner.fired == 4, "cancelled callback fired")
