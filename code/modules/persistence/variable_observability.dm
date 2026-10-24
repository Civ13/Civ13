// Compile-time integration marker. Runtime collection/export remains default-off.
#define CIV13_VARIABLE_OBSERVABILITY
#define VARIABLE_OBSERVABILITY_LIMIT 32768

var/global/variable_observability_sequence = 0
var/global/variable_observability_operation_sequence = 0

/proc/variable_observability_enabled()
	// No new credential or listener. A deployment must explicitly opt in locally.
	if(!fexists("config/variable-observability.txt") || length(file("config/variable-observability.txt")) > 16) return FALSE
	if(trim(file2text("config/variable-observability.txt")) != "enabled") return FALSE
	if(!fexists("config/lifecycle-token.txt") || length(file("config/lifecycle-token.txt")) > 128) return FALSE
	if(!fexists("config/lifecycle-revision.txt") || length(file("config/lifecycle-revision.txt")) > 128) return FALSE
	return nomads_lifecycle_hex(nomads_lifecycle.read_token(), 32) && nomads_lifecycle_hex(nomads_lifecycle.read_revision(), 40)

// Only this fixed schema is copied. No names, values, vars, clients or errors.
/proc/variable_observability_identity(datum/D)
	var/list/row = list("present" = !!D, "lookup_ref" = D ? "\ref[D]" : null, "type" = D ? copytext("[D.type]", 1, 161) : null, "validity" = "capture_only", "generation" = "unavailable", "gc_destroyed" = D ? D.gc_destroyed : null, "gcDestroyed" = D ? D.gcDestroyed : null)
	var/list/path = list()
	var/list/seen = list()
	var/atom/A = istype(D, /atom) ? D : null
	if(A) row["native"] = list("x" = A.x, "y" = A.y, "z" = A.z)
	var/state = A ? "depth_limit" : "not_atom"
	for(var/i = 1 to 8)
		if(!A)
			if(state != "not_atom") state = "no_turf"
			break
		if(A in seen)
			state = "cycle"
			break
		seen += A
		path += list(list("lookup_ref" = "\ref[A]", "type" = copytext("[A.type]", 1, 161)))
		if(isturf(A))
			row["turf"] = list("x" = A.x, "y" = A.y, "z" = A.z, "lookup_ref" = "\ref[A]")
			state = "found"
			break
		A = A.loc
	row["location_state"] = state
	row["location_chain"] = path
	return row

/proc/variable_observability_membership(list/registry, datum/D)
	var/scanned = 0
	var/matches = 0
	if(registry && D)
		for(var/i = 1 to min(registry.len, 256))
			scanned++
			if(registry[i] == D) matches++
	var/complete = !registry || scanned == registry.len
	return list("total" = registry ? registry.len : 0, "scanned" = scanned, "matches_in_prefix" = matches, "complete" = complete, "membership" = !D ? "unavailable" : (matches ? "present" : (complete ? "absent" : "unknown")))

/proc/variable_observability_object(datum/D)
	var/list/row = variable_observability_identity(D)
	row["thrown_list"] = variable_observability_membership(thrown_list, D)
	row["processing_objects"] = variable_observability_membership(processing_objects, D)
	if(istype(D, /atom/movable))
		var/atom/movable/M = D
		row["throw"] = list("throwing" = !!M.throwing, "throwmode" = M.throwmode, "speed" = M.speed, "range" = M.range, "dist_travelled" = M.dist_travelled, "throw_speed" = M.throw_speed, "throw_range" = M.throw_range, "original_target" = variable_observability_identity(M.original_target), "thrower" = variable_observability_identity(M.thrower), "throw_source" = variable_observability_identity(M.throw_source))
	return row

/datum/persistence_world_operation
	var/observability_id
	var/observability_started
	var/observability_collecting = FALSE
	var/observability_fields_skipped = 0
	var/observability_references_skipped = 0
	var/observability_legacy_fields_skipped = 0

// Observe only the existing policy's accepted skip decision, without deciding
// policy again, retaining the value or changing any link. Counts are decisions,
// not unique objects; list-valued fields are not direct datum references.
/proc/variable_observability_skipped(value, legacy = FALSE)
	var/datum/persistence_world_operation/P = persistence_active_operation
	if(!P || !P.observability_collecting) return
	if(legacy)
		P.observability_legacy_fields_skipped = min(P.observability_legacy_fields_skipped + 1, 1000000000)
	else
		P.observability_fields_skipped = min(P.observability_fields_skipped + 1, 1000000000)
		if(istype(value, /datum)) P.observability_references_skipped = min(P.observability_references_skipped + 1, 1000000000)

/map_storage
	var/list/last_variable_failure
	var/list/last_variable_operation

/proc/variable_observability_operation(datum/persistence_world_operation/P)
	if(!P) return null
	var/stage = P.restoring_players ? "restoring_players" : (P.contents_started ? "contents" : (P.backend_started ? "backend" : "admitted"))
	return list("id" = P.observability_id, "kind" = P.kind, "started_tick" = P.observability_started, "stage" = stage, "backend_started" = !!P.backend_started, "contents_started" = !!P.contents_started, "mutation_started" = !!P.mutation_started, "restoring_players" = !!P.restoring_players, "owns_storage" = P.storage == map_storage, "active" = P == persistence_active_operation, "skip_counts_available" = P.observability_collecting, "runtime_field_skip_decisions" = P.observability_fields_skipped, "runtime_reference_skip_decisions" = P.observability_references_skipped, "legacy_runtime_field_skip_decisions" = P.observability_legacy_fields_skipped, "skip_count_limit" = 1000000000)

/proc/variable_observability_utc()
	// Absolute realtime is a large 32-bit float and can round into the future.
	// time2text interprets timeofday as today's UTC date with finer precision.
	var/before = world.timeofday
	var/stamp = time2text(before, "YYYY-MM-DD hh:mm:ss", 0)
	// A midnight rollover during formatting must fail closed rather than attach
	// yesterday's time-of-day to today's date. No sleep, clock mutation or retry.
	if(world.timeofday < before) return null
	return stamp

/proc/variable_observability_envelope()
	return list("schema" = 1, "revision" = nomads_lifecycle.read_revision(), "session" = nomads_lifecycle.boot_session(), "round_id" = istext(game_id) ? copytext(game_id, 1, 161) : "unavailable", "tick" = world.time, "realtime" = world.realtime, "utc" = variable_observability_utc())

/map_storage/proc/variable_observability_publish(list/evidence)
	var/encoded = json_encode(evidence)
	if(length(encoded) > VARIABLE_OBSERVABILITY_LIMIT)
		evidence = variable_observability_envelope()
		evidence["snapshot_id"] = "failure-[variable_observability_sequence]"
		evidence["partial"] = TRUE
		evidence["error"] = "snapshot_size_limit"
		encoded = json_encode(evidence)
	last_variable_failure = evidence
	// Provision this private directory separately. Never create it, fall back to
	// data/, or let failed diagnostic I/O replace the serializer's own result.
	try
		if(!("variable-observability/" in flist("data/desktop-supervisor/variable-observability"))) return FALSE
		var/path = "data/desktop-supervisor/variable-observability/last-failure.json"
		if(fexists(path) && !fdel(path)) return FALSE
		return text2file(encoded, path)
	catch
		return FALSE

/map_storage/proc/variable_observability_finish(datum/persistence_world_operation/P, success)
	if(!variable_observability_enabled()) return
	last_variable_operation = variable_observability_operation(P)
	last_variable_operation["success"] = !!success
	last_variable_operation["finished_tick"] = world.time
	last_variable_operation["active"] = FALSE
	if(success) return
	var/list/failure_operation = last_variable_failure ? last_variable_failure["operation"] : null
	if(failure_operation && failure_operation["id"] == P.observability_id) return
	var/list/evidence = variable_observability_envelope()
	evidence["snapshot_id"] = "failure-[++variable_observability_sequence]"
	evidence["kind"] = "operation_failed"
	evidence["policy_classification"] = "operation_failed_without_reference_context"
	evidence["operation"] = last_variable_operation.Copy()
	evidence["historical"] = TRUE
	evidence["partial"] = FALSE
	evidence["live_resolution"] = "unsupported"
	variable_observability_publish(evidence)

/map_storage/proc/variable_observability_capture(datum/target)
	if(!variable_observability_enabled()) return
	var/list/evidence = variable_observability_envelope()
	evidence["snapshot_id"] = "failure-[++variable_observability_sequence]"
	evidence["operation"] = variable_observability_operation(persistence_active_operation)
	var/list/chain = list()
	for(var/i = max(1, saving_export_stack.len - 7), i <= saving_export_stack.len, i++)
		var/datum/save_export_frame/F = saving_export_stack[i]
		var/valid = istype(F, /datum/save_export_frame)
		var/list/row = variable_observability_object(valid ? F.source : null)
		row["field"] = valid ? (istext(F.current_field) ? copytext(F.current_field, 1, 81) : "contents") : "unavailable"
		row["entry"] = valid ? F.entry : 0
		chain += list(row)
	evidence["source"] = chain.len ? chain[chain.len] : variable_observability_object(null)
	evidence["target"] = variable_observability_object(target)
	evidence["owner_chain"] = chain
	evidence["owner_chain_truncated"] = saving_export_stack.len > 8
	evidence["policy_classification"] = "rejected_by_persistence_guard"
	// Exact serializer identifiers are already bounded scalar context.
	for(var/key in list("kind", "saved_z", "current_entry", "first_z", "first_entry"))
		evidence[key] = last_save_reference_failure[key]
	evidence["historical"] = TRUE
	evidence["live_resolution"] = "unsupported"
	evidence["partial"] = FALSE
	variable_observability_publish(evidence)

/proc/variable_observability_status()
	if(!variable_observability_enabled()) return list("schema" = 1, "enabled" = FALSE)
	var/list/state = variable_observability_envelope()
	state["enabled"] = TRUE
	state["operation"] = variable_observability_operation(persistence_active_operation)
	state["last_operation"] = map_storage.last_variable_operation
	state["failure"] = map_storage.last_variable_failure
	if(length(json_encode(state)) > VARIABLE_OBSERVABILITY_LIMIT - 8192)
		state["failure"] = list("partial" = TRUE, "error" = "status_size_limit")
	return state
