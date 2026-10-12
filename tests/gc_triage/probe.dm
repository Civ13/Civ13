/datum/triage_owner
	var/held

/proc/triage_reference_checks()
	var/process/garbage/G = processes.garbage
	var/obj/probe/target = new
	qdel(target)
	var/ref_id = "\ref[target]"
	var/datum/triage_owner/owner = new
	owner.held = target
	var/list/result = G.inspect_queue_reference(ref_id, "\ref[owner]", "held")
	check(result["status"] == "inspected" && result["matches"] == 1, "targeted inspection sees direct owner without world scans")
	var/list/nested = list(1000000, "target" = target)
	nested += list(nested)
	owner.held = list(nested)
	result = G.inspect_queue_reference(ref_id, "\ref[owner]", "held")
	check(result["matches"] == 1 && result["slots"] <= 256, "targeted inspection handles association numeric values and cycles")
	var/list/large = list()
	for (var/i = 1 to 1000)
		large += i
	owner.held = large
	result = G.inspect_queue_reference(ref_id, "\ref[owner]", "held")
	check(result["truncated"] && result["slots"] == 256, "targeted inspection stops at its slot cap")
	owner.held = list()
	for (var/i = 1 to 80)
		owner.held += list(list(i))
	result = G.inspect_queue_reference(ref_id, "\ref[owner]", "held")
	check(result["truncated"] && result["slots"] <= 256, "targeted inspection stops at its list cap")
	result = G.inspect_queue_reference(ref_id, "\ref[owner]", "vars")
	check(result["status"] == "not_pending", "targeted inspection rejects whole owner vars")
	G.destroyed[ref_id] = target.gcDestroyed + 1
	result = G.inspect_queue_reference(ref_id, "\ref[owner]", "held")
	check(result["status"] == "not_pending", "targeted inspection rejects mismatched queue identity")
	G.destroyed.Cut()
	owner.held = null
	nested.Cut()
	nested = null
	var/target_ref = "\ref[target]"
	target = null
	sleep(1)
	check(!locate(target_ref), "targeted inspection results retain no offender objects")
	triage_outcome_checks()

/obj/probe/triage_failure
/obj/probe/triage_requested
/obj/probe/triage_absent
/obj/probe/triage_throw
	var/reject_delete = TRUE
/obj/probe/triage_throw/Del()
	if (reject_delete)
		throw "controlled forced-delete failure"
	return ..()
/obj/probe/triage_pooled
/obj/probe/triage_self_delete/Destroy()
	del(src)
/datum/triage_direct

/proc/triage_age(process/garbage/G, obj/probe/A)
	A.gcDestroyed = world.time - 1000
	G.destroyed["\ref[A]"] = A.gcDestroyed

/proc/triage_outcome_checks()
	var/process/garbage/G = new
	processes.garbage = G
	var/datum/triage_direct/direct = new
	qdel(direct)
	var/list/direct_row = G.profile_row("/datum/triage_direct")
	check(!direct && direct_row["direct_deleted"] == 1 && !direct_row["enqueued"], "direct datum deletion is physically complete and not a queue result")
	var/obj/probe/immediate = new /obj/probe/triage_requested
	immediate.hint = QDEL_HINT_HARDDEL_NOW
	qdel(immediate)
	var/list/immediate_row = G.profile_row("/obj/probe/triage_requested")
	check(!immediate && immediate_row["immediate_requested"] == 1 && immediate_row["forced_deleted"] == 1 && !immediate_row["collection_failed"], "immediate requested deletion is verified without claiming a collection failure")
	var/obj/probe/unchecked = new /obj/probe/triage_absent
	unchecked.hint = QDEL_HINT_IWILLGC
	qdel(unchecked)
	var/list/unchecked_row = G.profile_row("/obj/probe/triage_absent")
	check(unchecked && unchecked_row["unchecked_handoff"] == 1 && !unchecked_row["queue_absent"], "unchecked handoff never claims physical collection")
	del(unchecked)
	var/obj/probe/live = new /obj/probe/triage_absent
	live.hint = QDEL_HINT_LETMELIVE
	qdel(live)
	check(live && !live.gc_destroyed && unchecked_row["let_live"] == 1, "let-live outcome preserves live state")
	del(live)
	pool_type_roots += /obj/probe/triage_pooled
	var/obj/probe/pooled = PoolOrNew(/obj/probe/triage_pooled)
	qdel(pooled)
	var/list/pooled_row = G.profile_row("/obj/probe/triage_pooled")
	check(pooled && (pooled in pool_idle) && pooled_row["pooled_retired"] == 1 && !pooled_row["direct_deleted"], "pool retirement retains its object without claiming deletion")
	var/obj/probe/self_deleted = new /obj/probe/triage_self_delete
	qdel(self_deleted)
	var/list/self_row = G.profile_row("/obj/probe/triage_self_delete")
	check(!self_deleted && self_row["direct_deleted"] == 1 && !self_row["enqueued"], "self-deleting cleanup records physical deletion once")
	var/obj/probe/A = new /obj/probe/triage_failure
	qdel(A)
	var/list/row = G.profile_row("[A.type]")
	check(row["enqueued"] == 1 && !row["queue_absent"] && !row["forced_deleted"], "queue admission never claims collection")
	triage_age(G, A)
	G.fire()
	check(!A && row["collection_failed"] == 1 && row["forced_deleted"] == 1 && !row["forced_requested"], "retained ordinary queue target records failure and verified forced deletion")
	for (var/i = 1 to 3)
		A = new /obj/probe/triage_failure
		qdel(A)
		triage_age(G, A)
		G.fire()
	check(row["collection_failed"] == 4 && !G.triage_pending_types.len && row["last_failure_ds"] >= row["first_failure_ds"], "persistent offender row accumulates bounded scalar diagnostics")
	A = new /obj/probe/triage_requested
	A.hint = QDEL_HINT_HARDDEL
	qdel(A)
	row = G.profile_row("[A.type]")
	triage_age(G, A)
	G.fire()
	check(!A && row["forced_requested"] == 1 && row["forced_deleted"] == 2 && !row["collection_failed"], "requested hard deletion is not a collection failure")
	A = new /obj/probe/triage_absent
	qdel(A)
	row = G.profile_row("[A.type]")
	triage_age(G, A)
	var/ref_id = "\ref[A]"
	A = null
	sleep(1)
	check(!locate(ref_id), "unpinned ordinary queued atom disappears on pinned BYOND")
	G.fire()
	check(row["queue_absent"] == 1 && !row["collection_failed"] && !row["forced_deleted"], "expired absent ref is distinct from forced deletion")
	A = new /obj/probe/triage_absent
	qdel(A)
	triage_age(G, A)
	A.gcDestroyed++
	G.fire()
	check(A && row["queue_stale_identity"] == 1 && row["queue_absent"] == 1, "live stale queue identity is never counted as absent")
	del(A)
	check(!G.triage_pending_types.len, "draining all outcomes releases scalar pending metadata")
	var/obj/probe/triage_throw/failing = new
	qdel(failing)
	triage_age(G, failing)
	row = G.profile_row("[failing.type]")
	var/caught = FALSE
	try
		G.fire()
	catch (var/exception/E)
		caught = TRUE
	check(caught && row["forced_error"] == 1 && !row["forced_deleted"], "forced-delete exceptions are recorded and propagated without claiming success")
	if (failing)
		failing.reject_delete = FALSE
		G.fire()
	G.destroyed.Cut()
	G = new
	processes.garbage = G
	for (var/i = 1 to 1200)
		A = new /obj/probe/triage_absent
		qdel(A)
		triage_age(G, A)
		A = null
	check(G.triage_pending_types.len == 1024 && G.triage_metadata_dropped == 176, "pending outcome metadata stops at exact cap")
	var/list/pending = G.triage_pending_snapshot()
	check(pending.len == 64, "pending diagnostics sample is bounded without locating targets")
	var/list/entry = pending[pending[1]]
	entry["stamp_ds"] = 99999
	check(G.destroyed[pending[1]] != 99999, "pending diagnostics copies do not mutate queue state")
	sleep(1)
	for (var/i = 1 to 5)
		G.fire()
	row = G.profile_row("/obj/probe/triage_absent")
	var/list/overflow = G.profile_row("(other types)")
	check(!G.destroyed.len && !G.triage_pending_types.len && row["queue_absent"] == 1024 && overflow["queue_absent"] == 176, "overflow outcomes remain honest and bounded metadata drains")
	for (var/i = 1 to 200)
		G.triage_outcome("none", "collection_failed", "type[i]")
	check(G.deletion_profile.len == 129, "outcomes share profiling type cap and overflow row")
	var/list/protected_row = G.profile_row("/obj/probe/triage_absent")
	var/field_count = protected_row.len
	G.triage_outcome("none", "arbitrary_event_key", "/obj/probe/triage_absent")
	check(protected_row.len == field_count, "outcomes reject arbitrary event keys to bound row width")
	var/list/snapshot = G.profile_snapshot()
	for (var/type_name in snapshot)
		var/list/values = snapshot[type_name]
		for (var/key in values)
			check(isnum(values[key]), "outcome snapshots contain scalar counters only")
