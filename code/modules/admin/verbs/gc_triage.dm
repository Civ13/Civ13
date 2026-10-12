/client/proc/gc_outcomes()
	set category = "Debug"
	set name = "GC Outcomes"
	if (!check_rights(R_DEBUG) || !processes.garbage)
		return
	var/process/garbage/G = processes.garbage
	var/list/snapshot = G.profile_snapshot()
	var/html = "<html><body><h2>GC outcomes</h2><p>Queue admission is not deletion. Absent refs have disappeared by eligibility; prior explicit deletion cannot be distinguished from native collection. Stale identities are preserved. Failure counts exclude requested hard deletes. First 128 types plus overflow; metadata capped at 1024 ([G.triage_metadata_dropped] admissions without type metadata).</p><table border='1'><tr><th>Type</th><th>Queued</th><th>Absent</th><th>Stale</th><th>Collection failures</th><th>Requested forced</th><th>Immediate requested</th><th>Verified forced</th><th>Incomplete forced</th><th>Changed forced identity</th><th>Forced errors</th><th>Direct deleted</th><th>Unverified direct</th><th>Pooled retired</th><th>Unchecked handoff</th><th>Let live</th><th>First failure ds</th><th>Last failure ds</th></tr>"
	for (var/type_name in snapshot)
		var/list/row = snapshot[type_name]
		html += "<tr><td>[html_encode(type_name)][row["collection_failed"] >= 3 ? " (repeated failures)" : ""]</td>"
		for (var/field in list("enqueued", "queue_absent", "queue_stale_identity", "collection_failed", "forced_requested", "immediate_requested", "forced_deleted", "forced_incomplete", "forced_identity_changed", "forced_error", "direct_deleted", "direct_incomplete", "pooled_retired", "unchecked_handoff", "let_live", "first_failure_ds", "last_failure_ds"))
			html += "<td>[isnum(row[field]) ? row[field] : 0]</td>"
		html += "</tr>"
	var/list/pending = G.triage_pending_snapshot()
	html += "</table><h3>First 64 pending queue refs</h3><p>Use GC Inspect Owner Field with a queue ref, a nominated owner's ref and one field. No automatic reference scan. Admission stamp is world.time in deciseconds; the grace period is 300 ds. This sample does not locate targets.</p><table border='1'><tr><th>Queue ref</th><th>Recorded type</th><th>Stamp ds</th></tr>"
	for (var/ref_id in pending)
		var/list/entry = pending[ref_id]
		html += "<tr><td>[html_encode(ref_id)]</td><td>[html_encode(entry["type"])]</td><td>[entry["stamp_ds"]]</td></tr>"
	html += "</table></body></html>"
	src << browse(html, "window=gc_outcomes;size=1100x650")

/client/proc/gc_inspect_owner_field()
	set category = "Debug"
	set name = "GC Inspect Owner Field"
	if (!check_rights(R_DEBUG) || !processes.garbage)
		return
	var/ref_id = input(src, "Pending target ref from GC Outcomes", "GC target") as null|text
	if (!ref_id)
		return
	var/owner_ref = input(src, "Explicit owner ref to inspect (no world scan)", "GC owner") as null|text
	if (!owner_ref)
		return
	var/field = input(src, "One owner field; nested lists limited to 256 slots/32 lists", "GC field") as null|text
	if (!field || !check_rights(R_DEBUG) || !processes.garbage)
		return
	var/list/result = processes.garbage.inspect_queue_reference(ref_id, owner_ref, field)
	to_chat(src, "GC field inspection: [result["status"]], [result["matches"]] matching slots, [result["slots"]] visited, truncated: [result["truncated"]]. Unselected owners/fields and engine/proc references are not searched.")
