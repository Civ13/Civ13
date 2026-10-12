// Explicit, bounded inspection of one nominated owner's field. Never scans world.
// Results contain scalars only; traversal references exist only during this call.
#define GC_TRIAGE_REFERENCE_SLOTS 256
#define GC_TRIAGE_REFERENCE_LISTS 32

/process/garbage/proc/inspect_queue_reference(ref_id, owner_ref, field)
	var/list/result = list("status" = "not_pending", "matches" = 0, "slots" = 0, "truncated" = FALSE)
	if (!istext(ref_id) || !istext(owner_ref) || !istext(field) || length(ref_id) > 64 || length(owner_ref) > 64 || length(field) > 128 || field == "vars")
		return result
	if (!(ref_id in destroyed))
		return result
	var/datum/target = locate(ref_id)
	if (!target || target.gcDestroyed != destroyed[ref_id])
		return result
	var/datum/owner = locate(owner_ref)
	if (!owner || !(field in owner.vars))
		result["status"] = "invalid_owner_field"
		return result
	result["status"] = "inspected"
	result["slots"] = 1
	var/value = owner.vars[field]
	if (value == target)
		result["matches"] = 1
		result["slots"] = 1
		return result
	if (!islist(value))
		return result
	var/list/work = list(value)
	var/list/seen = list()
	var/slots = 0
	var/cursor = 1
	while (cursor <= work.len)
		var/list/current = work[cursor++]
		if (current in seen)
			continue
		seen += list(current)
		for (var/key in current)
			if (slots >= GC_TRIAGE_REFERENCE_SLOTS)
				result["truncated"] = TRUE
				break
			slots++
			// Numeric list values are positional indices, not association keys.
			var/associated
			if (!isnum(key))
				associated = current[key]
			if (key == target)
				result["matches"]++
			if (associated == target)
				result["matches"]++
			if (islist(key))
				if (work.len < GC_TRIAGE_REFERENCE_LISTS)
					work += list(key)
				else
					result["truncated"] = TRUE
			if (islist(associated))
				if (work.len < GC_TRIAGE_REFERENCE_LISTS)
					work += list(associated)
				else
					result["truncated"] = TRUE
		if (slots >= GC_TRIAGE_REFERENCE_SLOTS)
			if (cursor <= work.len)
				result["truncated"] = TRUE
			break
	result["slots"] = slots
	return result

#undef GC_TRIAGE_REFERENCE_SLOTS
#undef GC_TRIAGE_REFERENCE_LISTS
