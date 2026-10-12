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
