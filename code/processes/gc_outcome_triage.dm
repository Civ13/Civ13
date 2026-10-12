// Extends the profiling table rather than creating another per-type registry.
#define GC_TRIAGE_PENDING_LIMIT 1024
#define GC_TRIAGE_UNKNOWN_TYPE "(other types)"

/process/garbage
	// Ref strings -> type strings only. The existing queue owns age/identity.
	var/list/triage_pending_types = list()
	var/triage_metadata_dropped = 0

/process/garbage/proc/triage_enqueued(ref_id, type_name)
	if (!istext(ref_id) || !istext(type_name))
		return
	var/list/row = profile_row(type_name)
	row["enqueued"]++
	triage_pending_types -= ref_id
	if (triage_pending_types.len < GC_TRIAGE_PENDING_LIMIT)
		triage_pending_types[ref_id] = type_name
	else
		triage_metadata_dropped++

/process/garbage/proc/triage_outcome(ref_id, outcome, live_type)
	var/static/list/valid_outcomes = list("queue_absent", "queue_stale_identity", "collection_failed", "forced_requested", "immediate_requested", "forced_deleted", "forced_incomplete", "forced_error", "direct_deleted", "pooled_retired", "unchecked_handoff", "let_live")
	if (!(outcome in valid_outcomes) || !istext(ref_id))
		return
	var/type_name = triage_pending_types[ref_id]
	if (!type_name)
		type_name = live_type ? live_type : GC_TRIAGE_UNKNOWN_TYPE
	var/list/row = profile_row(type_name)
	row[outcome]++
	if (outcome == "collection_failed")
		if (row["collection_failed"] == 1)
			row["first_failure_ds"] = world.time
		row["last_failure_ds"] = world.time
	triage_pending_types -= ref_id

/process/garbage/proc/triage_pending_snapshot()
	var/list/result = list()
	var/count = 0
	for (var/ref_id in destroyed)
		if (++count > 64)
			break
		var/type_name = triage_pending_types[ref_id]
		result[ref_id] = list("type" = type_name ? type_name : "(type metadata unavailable)", "stamp_ds" = destroyed[ref_id])
	return result

// The caller's existing timing wrapper still owns forced-delete costs.
// An observed ordinary queue failure and a completed physical delete differ.
/process/garbage/proc/triage_force_delete(datum/A, kind)
	var/type_name = "[A.type]"
	var/ref_id = "\ref[A]"
	triage_outcome(ref_id, kind, type_name)
	try
		del(A)
	catch (var/exception/E)
		triage_outcome(ref_id, "forced_error", type_name)
		throw E
	triage_outcome(ref_id, A ? "forced_incomplete" : "forced_deleted", type_name)

#undef GC_TRIAGE_PENDING_LIMIT
#undef GC_TRIAGE_UNKNOWN_TYPE
