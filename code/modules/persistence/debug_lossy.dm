// Explicit, bounded DEBUG ONLY recovery; normal saves never construct this policy.
// The first supported lossy action omits a moved, unoccupied leaf animal from
// a fresh candidate, without deleting or editing the live animal.
/datum/save_debug_recovery
	should_save = FALSE
	var/id
	var/attempt = 0
	var/const/max_attempts = 3
	var/closed = FALSE
	var/retryable = FALSE
	var/stop_reason
	var/datum/persistence_world_operation/owner
	var/atom/pending_parent
	var/mob/living/simple_animal/pending_child
	var/pending_child_type
	var/pending_parent_type
	var/pending_child_ref
	var/pending_parent_ref
	var/atom/pending_destination
	var/pending_destination_ref
	var/pending_destination_type
	var/pending_expires
	var/pending_operation_id
	var/pending_generation
	var/pending_fault_id
	var/list/signatures = list()
	var/list/quarantine = list()
	// One bounded witness per selected target; retained only for this session.
	var/list/quarantine_witnesses = list()
	var/list/incidents = list()
	var/list/omissions = list()
	var/list/attempt_history = list()
	var/encoding_depth = 0
	// Each frame names one encoded list slot, never the slot's live value.
	var/list/encoding_list_context = list()

/datum/save_debug_recovery/New()
	..()
	id = "debug-save-[md5("[world.realtime]-[world.time]-[rand(1, 1000000000)]-\ref[src]")]"

/datum/save_debug_recovery/proc/bind(datum/persistence_world_operation/operation)
	if(closed || owner || !operation || !operation.current(map_storage, "save") || attempt < 1 || attempt > max_attempts) return FALSE
	owner = operation
	retryable = FALSE
	pending_parent = null
	pending_child = null
	pending_destination = null
	pending_operation_id = null
	pending_generation = null
	pending_fault_id = null
	omissions = list()
	encoding_list_context = list()
	return TRUE

// Called only on the existing changed-child failure branch; never edits world state.
/datum/save_debug_recovery/proc/observe(atom/parent, atom/movable/child, datum/persistence_world_operation/operation)
	if(closed || owner != operation || !operation.current(map_storage, "save") || !istext(operation.diagnostic_save_id) || !istext(operation.diagnostic_generation)) return FALSE
	if(!parent || !istype(child, /mob/living/simple_animal)) return FALSE
	var/mob/living/simple_animal/A = child
	if(A.gc_destroyed || A.gcDestroyed || A.client || A.contents.len || A.loc == parent) return FALSE
	pending_parent = parent
	pending_child = A
	pending_parent_type = "[parent.type]"
	pending_child_type = "[A.type]"
	pending_parent_ref = "\ref[parent]"
	pending_child_ref = "\ref[A]"
	pending_destination = A.loc
	pending_destination_ref = A.loc ? "\ref[A.loc]" : null
	pending_destination_type = A.loc ? "[A.loc.type]" : "unavailable"
	pending_operation_id = operation.diagnostic_save_id
	pending_generation = operation.diagnostic_generation
	pending_expires = world.time + 300
	pending_fault_id = md5("[id]-[pending_operation_id]-[pending_generation]-[world.time]-[rand(1, 1000000000)]")
	return TRUE

// Called only after the failed owner was cleaned up and released. A stale
// capability or changed object is never resolved from its textual reference.
/datum/save_debug_recovery/proc/pending_valid()
	var/mob/living/simple_animal/A = pending_child
	var/atom/P = pending_parent
	return A && P && world.time <= pending_expires && !A.gc_destroyed && !A.gcDestroyed && !P.gc_destroyed && !P.gcDestroyed && !A.client && !A.contents.len && A.loc != P && A.loc == pending_destination && (!!A.loc == !!pending_destination_ref) && (!A.loc || ("\ref[A.loc]" == pending_destination_ref && "[A.loc.type]" == pending_destination_type)) && "\ref[A]" == pending_child_ref && "\ref[P]" == pending_parent_ref && "[A.type]" == pending_child_type && "[P.type]" == pending_parent_type

/datum/save_debug_recovery/proc/admit_retry(expected_fault_id, expected_attempt_id, expected_generation)
	if(closed || owner || attempt >= max_attempts || !retryable) return FALSE
	if(!istext(expected_fault_id) || expected_fault_id != pending_fault_id || expected_attempt_id != pending_operation_id || expected_generation != pending_generation) return FALSE
	if(persistence_active_operation || persistence_save_in_progress || fexists("map_saves/save_complete.txt") || !pending_valid())
		stop_reason = "failure_identity_stale_or_unsupported"
		return FALSE
	if(!map_storage.debug_backup_identity_valid())
		stop_reason = "previous_backup_unverified"
		return FALSE
	// Backup inspection can yield; revalidate the owner, marker and handles.
	if(closed || owner || persistence_active_operation || persistence_save_in_progress || fexists("map_saves/save_complete.txt") || !pending_valid())
		stop_reason = "failure_identity_stale_or_unsupported"
		return FALSE
	var/mob/living/simple_animal/A = pending_child
	var/signature = md5("[pending_parent_ref]|[pending_child_ref]|[pending_generation]")
	// An already quarantined handle repeating is not a reason to loop.
	if(signatures[signature] || quarantine[pending_child_ref])
		stop_reason = "repeated_failure_signature"
		return FALSE
	signatures[signature] = TRUE
	quarantine[pending_child_ref] = A
	quarantine_witnesses[pending_child_ref] = list("animal" = A, "animal_type" = pending_child_type, "destination" = pending_destination, "destination_ref" = pending_destination_ref, "destination_type" = pending_destination_type)
	incidents += list(list("attempt" = attempt, "operation_id" = pending_operation_id, "generation" = pending_generation, "kind" = "moved_leaf_animal", "parent_type" = pending_parent_type, "parent_ref" = pending_parent_ref, "child_type" = pending_child_type, "child_ref" = pending_child_ref, "observed_destination_type" = pending_destination_type, "observed_destination_ref" = pending_destination_ref, "action" = "omit_entity_and_replace_references_with_null"))
	try
		world.log << "Debug loss selection [id]: [json_encode(incidents[incidents.len])]"
	catch
		stop_reason = "audit_log_unavailable"
		return FALSE
	pending_parent = null
	pending_child = null
	pending_destination = null
	pending_fault_id = null
	return TRUE

/datum/save_debug_recovery/proc/is_quarantined(value)
	if(!istype(value, /atom/movable) || !value) return FALSE
	return quarantine["\ref[value]"] == value

// The selected live object must still be at its admitted immediate location.
// A deleted destination turns its stored handle null but retains its ref/type,
// so it cannot be confused with a destination that was originally null.
/datum/save_debug_recovery/proc/quarantine_witness_valid(ref, atom/movable/value)
	if(!istext(ref) || !istype(value, /mob/living/simple_animal) || quarantine[ref] != value || "\ref[value]" != ref) return FALSE
	var/list/witness = quarantine_witnesses[ref]
	if(!islist(witness) || witness.len != 5 || witness["animal"] != value || "[value.type]" != witness["animal_type"]) return FALSE
	var/mob/living/simple_animal/A = value
	if(A.gc_destroyed || A.gcDestroyed || A.client || A.contents.len) return FALSE
	var/atom/destination = A.loc
	if(destination != witness["destination"] || (!!destination != !!witness["destination_ref"])) return FALSE
	if(destination)
		if(destination.gc_destroyed || destination.gcDestroyed || "\ref[destination]" != witness["destination_ref"] || "[destination.type]" != witness["destination_type"]) return FALSE
	else if(witness["destination_type"] != "unavailable") return FALSE
	return TRUE

// Keep nested slot context attached to the owned encoding call across yields.
// The caller owns list identity and association handling; this is not a
// mutation of the live list or a new authority to select an omitted target.
/datum/save_debug_recovery/proc/encode_list_member(map_storage/storage, savefile/F, list_id, index, side, value)
	if(closed || !owner || !owner.current(storage, "save") || !isnum(list_id) || list_id < 1 || list_id != round(list_id) || !isnum(index) || index < 1 || index != round(index) || !(side in list("key", "value")) || encoding_list_context.len >= 64) throw EXCEPTION("Debug list context is invalid")
	var/datum/save_export_frame/frame = storage.saving_export_stack.len ? storage.saving_export_stack[storage.saving_export_stack.len] : null
	var/list/context = list("z" = storage.saving_z, "list_id" = list_id, "index" = index, "side" = side, "frame" = frame)
	encoding_list_context += list(context)
	try
		. = storage.encode_saved_value(F, value)
	catch(var/exception/error)
		if(encoding_list_context.len && encoding_list_context[encoding_list_context.len] == context) encoding_list_context.Cut(encoding_list_context.len, encoding_list_context.len + 1)
		throw error
	var/datum/save_export_frame/current_frame = storage.saving_export_stack.len ? storage.saving_export_stack[storage.saving_export_stack.len] : null
	if(closed || !owner || !owner.current(storage, "save") || !encoding_list_context.len || encoding_list_context[encoding_list_context.len] != context || storage.saving_z != context["z"] || current_frame != frame) throw EXCEPTION("Debug list context lost ownership")
	encoding_list_context.Cut(encoding_list_context.len, encoding_list_context.len + 1)

/datum/save_debug_recovery/proc/omits(atom/movable/value, source_field)
	if(closed || !owner || !owner.current(map_storage, "save") || !value) return FALSE
	var/ref = "\ref[value]"
	if(quarantine[ref] != value) return FALSE
	if(!quarantine_witness_valid(ref, value)) throw EXCEPTION("Debug omitted animal changed; candidate refused")
	if(encoding_depth > 1 && !encoding_list_context.len) throw EXCEPTION("Debug nested omission lacks list context")
	if(omissions.len >= 256) throw EXCEPTION("Debug omission audit limit exceeded")
	var/datum/save_export_frame/frame = map_storage.saving_export_stack.len ? map_storage.saving_export_stack[map_storage.saving_export_stack.len] : null
	var/source_type = frame && frame.source ? "[frame.source.type]" : "unknown"
	var/field = source_field == "moving_roster" ? "moving_roster" : (frame && istext(frame.current_field) ? copytext(frame.current_field, 1, 81) : "contents")
	var/replacement = source_field == "moving_roster" ? "roster_not_admitted" : ((encoding_depth || source_field == "level_link") ? "null_reference" : "omitted_content")
	var/list/row = list("attempt" = attempt, "target_ref" = ref, "target_type" = "[value.type]", "source_type" = source_type, "source_ref" = frame && frame.source ? "\ref[frame.source]" : null, "field" = field, "replacement" = replacement)
	if(encoding_list_context.len)
		var/list/location = encoding_list_context[encoding_list_context.len]
		if(location["z"] != map_storage.saving_z) throw EXCEPTION("Debug list context changed level")
		// A list member may recursively serialize another object. Only the
		// member's own frame belongs to this slot; nested object fields retain
		// their own source/field attribution instead of inheriting this slot.
		if(location["frame"] == frame)
			row["list_location"] = list("z" = location["z"], "list_id" = location["list_id"], "index" = location["index"], "side" = location["side"])
	omissions += list(row)
	return TRUE

/datum/save_debug_recovery/proc/audit(generation, datum/persistence_world_operation/operation)
	if(closed || owner != operation || !operation.current(map_storage, "save") || generation != operation.diagnostic_generation || incidents.len > 2 || omissions.len > 256) throw EXCEPTION("Debug audit is not owned or exceeds its bound")
	if(quarantine_witnesses.len != quarantine.len) throw EXCEPTION("Debug omission witness coverage changed")
	for(var/ref in quarantine)
		var/mob/living/simple_animal/A = quarantine[ref]
		if(!quarantine_witness_valid(ref, A)) throw EXCEPTION("Debug omitted animal changed before publication")
	var/list/result = list("schema" = 1, "mode" = "debug_lossy", "request_id" = id, "attempt" = attempt, "attempt_id" = operation.diagnostic_save_id, "outcome" = "candidate_commit_intent", "generation" = generation, "attempt_history" = attempt_history.Copy(), "incidents" = incidents.Copy(), "omissions" = omissions.Copy())
	if(!valid_debug_recovery_audit(result, generation)) throw EXCEPTION("Debug recovery audit is invalid or too large")
	return result

/datum/save_debug_recovery/proc/close()
	closed = TRUE
	owner = null
	pending_parent = null
	pending_child = null
	pending_destination = null
	pending_fault_id = null
	quarantine = list()
	quarantine_witnesses = list()
	encoding_list_context = list()
	if(map_storage && map_storage.debug_recovery_session == src) map_storage.debug_recovery_session = null

// Read-only handoff for a future authorized owner-thread adapter. The opaque
// identifier correlates a fixed pending fault; it does not authenticate a caller.
/map_storage/proc/debug_recovery_fault()
	var/datum/save_debug_recovery/policy = debug_recovery_session
	if(!policy || policy.closed || !policy.pending_fault_id || !policy.pending_child || !policy.pending_parent || world.time > policy.pending_expires) return null
	return list("request_id" = policy.id, "attempt" = policy.attempt, "attempt_id" = policy.pending_operation_id, "generation" = policy.pending_generation, "fault_id" = policy.pending_fault_id, "expires_world_time" = policy.pending_expires, "kind" = "moved_leaf_animal", "parent_type" = policy.pending_parent_type, "child_type" = policy.pending_child_type, "state" = policy.owner ? "capturing" : "retry_candidate")

// The capability never accepts a caller-supplied object path, reference or code.
/proc/save_debug_omits(atom/movable/value, source_field)
	var/datum/persistence_world_operation/operation = persistence_active_operation
	var/datum/save_debug_recovery/policy = operation ? operation.debug_recovery : null
	return policy && policy.omits(value, source_field)

// Identity and generation checks only; this never mutates, restores or claims
// a full byte-integrity proof for the retained backup.
/map_storage/proc/debug_backup_identity_valid()
	var/marker_path = "map_backups/save_complete.txt"
	var/map_path = "map_backups/map.txt"
	var/round_path = "map_backups/round.json"
	if(!fexists(marker_path) || !fexists(map_path) || !fexists(round_path)) return FALSE
	if(length(file(marker_path)) > 256 || length(file(map_path)) > 65536 || length(file(round_path)) > 33554432) return FALSE
	try
		var/marker = trim(file2text(marker_path))
		if(copytext(marker, 1, 10) != "round-v2:") return FALSE
		var/text = file2text(map_path)
		var/list/meta = splittext(text, "\n")
		var/list/state = json_decode(file2text(round_path))
		if(!islist(meta) || !meta.len || meta[1] != map.ID || !islist(state) || state["version"] != 2 || state["generation"] != marker || state["metadata"] != md5(text) || state["map"] != map.ID || state["maxx"] != world.maxx || state["maxy"] != world.maxy || state["maxz"] != world.maxz) return FALSE
		for(var/z = 1, z <= world.maxz, z++)
			var/path = "map_backups/[z].sav"
			if(!fexists(path) || !length(file(path))) return FALSE
			var/savefile/F = new(path)
			F.cd = "/"
			if(!("generation" in F.dir) || F["generation"] != marker || !("maxx" in F.dir) || F["maxx"] != world.maxx || !("maxy" in F.dir) || F["maxy"] != world.maxy || !("maxz" in F.dir) || F["maxz"] != world.maxz) return FALSE
			F = null
		return TRUE
	catch
		return FALSE

/proc/valid_debug_recovery_audit(value, generation)
	if(!islist(value)) return FALSE
	var/list/audit = value
	if(audit.len != 10 || audit["schema"] != 1 || audit["mode"] != "debug_lossy" || !istext(audit["request_id"]) || !length(audit["request_id"]) || length(audit["request_id"]) > 80 || !istext(audit["attempt_id"]) || !length(audit["attempt_id"]) || length(audit["attempt_id"]) > 80 || audit["outcome"] != "candidate_commit_intent" || audit["generation"] != generation || !isnum(audit["attempt"]) || audit["attempt"] != round(audit["attempt"]) || audit["attempt"] < 1 || audit["attempt"] > 3) return FALSE
	if(!islist(audit["attempt_history"]) || audit["attempt_history"].len > 2) return FALSE
	if(!islist(audit["incidents"]) || audit["incidents"].len > 2 || !islist(audit["omissions"]) || audit["omissions"].len > 256) return FALSE
	return length(json_encode(audit)) <= 131072

/datum/save_debug_recovery/proc/finish_failure(datum/persistence_world_operation/operation, exception/error, cleanup_ok, released)
	if(owner != operation) return FALSE
	owner = null
	retryable = cleanup_ok && released && error && error.name == "Child moved or disappeared during capture" && pending_child && pending_parent && pending_operation_id == operation.diagnostic_save_id && pending_generation == operation.diagnostic_generation
	if(!retryable) stop_reason = !cleanup_ok ? "cleanup_failed" : (!released ? "owner_lost" : "failure_not_supported")
	if(attempt_history.len < 3)
		attempt_history += list(list("attempt" = attempt, "operation_id" = operation.diagnostic_save_id, "generation" = operation.diagnostic_generation, "outcome" = retryable ? "failed_retryable" : stop_reason, "omissions" = omissions.Copy()))
	world.log << "Debug lossy save [id] attempt: [json_encode(attempt_history[attempt_history.len])]"
	return retryable

/datum/save_debug_recovery/proc/finish_success(datum/persistence_world_operation/operation)
	if(owner != operation) return FALSE
	owner = null
	return TRUE

// Clean each part under the same owner. If cleanup fails, refuse later saves
// without holding the gameplay movement flag; never clean a successor's state.
/map_storage/proc/debug_cleanup_owned(datum/persistence_world_operation/operation)
	if(!operation || !operation.current(src, "save")) return FALSE
	var/ok = TRUE
	try
		clear_saved_zones()
	catch
		ok = FALSE
	if(!operation.current(src, "save")) return FALSE
	try
		clear_zone_export()
	catch
		ok = FALSE
	if(!operation.current(src, "save")) return FALSE
	try
		clear_saved_roof_areas()
	catch
		ok = FALSE
	if(!operation.current(src, "save")) return FALSE
	try
		clear_bookkeeping()
	catch
		ok = FALSE
	if(!operation.current(src, "save")) return FALSE
	try
		release_durable_world()
	catch
		ok = FALSE
	if(!operation.current(src, "save")) return FALSE
	if(!ok) debug_recovery_hold = TRUE
	return ok

/datum/controller/gameticker/proc/debug_lossy_save()
	if(!map_storage || map_storage.debug_recovery_session) return FALSE
	var/datum/save_debug_recovery/policy = new
	map_storage.debug_recovery_session = policy
	var/success = FALSE
	try
		for(var/n = 1, n <= policy.max_attempts, n++)
			if(n > 1)
				sleep(2)
				if(persistence_active_operation || persistence_save_in_progress || fexists("map_saves/save_complete.txt"))
					policy.stop_reason = "save_owner_or_generation_changed"
					break
				if(!policy.admit_retry(policy.pending_fault_id, policy.pending_operation_id, policy.pending_generation)) break
			policy.attempt = n
			if(savemap(null, policy))
				success = TRUE
				break
			if(!policy.retryable) break
	catch
		policy.stop_reason = "unexpected_recovery_error"
		var/datum/persistence_world_operation/failed_owner = policy.owner
		if(failed_owner && failed_owner.current(map_storage, "save"))
			var/cleanup_ok = FALSE
			try
				cleanup_ok = map_storage.debug_cleanup_owned(failed_owner)
			catch
				cleanup_ok = FALSE
			if(failed_owner.current(map_storage, "save"))
				if(!cleanup_ok) map_storage.debug_recovery_hold = TRUE
				failed_owner.finish(FALSE)
	if(!success && !policy.stop_reason) policy.stop_reason = "attempts_exhausted_or_admission_refused"
	try
		world.log << "Debug lossy save [policy.id]: [success ? "committed" : policy.stop_reason]; attempts=[policy.attempt]"
		message_admins("Debug lossy save [policy.id]: [success ? "committed with audit" : policy.stop_reason]; attempts=[policy.attempt].")
	catch
		// A failed notification must not retain live fault handles.
		policy.stop_reason = policy.stop_reason
	policy.close()
	return success
