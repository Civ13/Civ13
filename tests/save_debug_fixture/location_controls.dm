// Synthetic-only controls. Each case starts after a failed ordinary capture,
// while the completed seed is retained in map_backups and its marker is absent.
var/global/fixture_late_capture_mode
var/global/fixture_late_capture_fired = 0

/proc/debug_fixture_backups_unchanged()
	if(fexists("map_saves/save_complete.txt")) return FALSE
	for(var/file_name in list("map.txt", "round.json", "1.sav", "save_complete.txt"))
		if(!fexists("fixture_seed/[file_name]") || !fexists("map_backups/[file_name]") || md5(file("fixture_seed/[file_name]")) != md5(file("map_backups/[file_name]"))) return FALSE
	return TRUE

// The stage adapter calls this immediately before the production final audit.
/proc/debug_fixture_before_final_audit(datum/save_debug_recovery/policy)
	if(!fixture_late_capture_mode) return
	debug_fixture_assert(policy && policy.attempt == 2 && policy.owner && policy.owner.current(map_storage, "save"), "late_capture_wrong_owner")
	debug_fixture_assert(policy.quarantine_witness_valid("\ref[fixture_subject]", fixture_subject), "late_capture_invalid_initial_witness")
	fixture_subject.loc = fixture_late_capture_mode == "detached_after_encode" ? null : locate(3, 2, 1)
	fixture_late_capture_fired++
	fixture_late_capture_mode = null

/proc/debug_fixture_late_capture_controls(obj/structure/debug_save_fixture/box, mob/living/simple_animal/debug_save_fixture/animal)
	var/list/results = list()
	for(var/name in list("moved_after_encode", "detached_after_encode"))
		animal.loc = box
		fixture_armed = TRUE
		fixture_late_capture_mode = name
		var/before = fixture_late_capture_fired
		debug_fixture_assert(!ticker.debug_lossy_save(), "late_capture_published")
		debug_fixture_assert(!fixture_late_capture_mode && fixture_late_capture_fired == before + 1, "late_capture_hook_not_reached")
		debug_fixture_assert(findtext(map_storage.last_error, "Debug omitted animal changed before publication"), "late_capture_wrong_refusal")
		debug_fixture_assert(debug_fixture_backups_unchanged(), "late_capture_marker_or_backup_changed")
		results[name] = TRUE
	animal.loc = locate(2, 2, 1)
	return results

/proc/debug_fixture_location_controls(obj/structure/debug_save_fixture/box, mob/living/simple_animal/debug_save_fixture/animal)
	var/list/results = list()
	var/atom/admitted_destination = animal.loc
	debug_fixture_assert(admitted_destination == locate(2, 2, 1), "location_control_original_destination")
	for(var/name in list("moved_before_encode", "detached_before_encode", "moved_after_encode", "detached_after_encode"))
		animal.loc = admitted_destination
		var/datum/save_debug_recovery/policy = new
		policy.attempt = 1
		var/datum/persistence_world_operation/first = begin_persistence_operation(map_storage, "save")
		debug_fixture_assert(first && policy.bind(first), "location_control_first_owner")
		first.diagnostic_save_id = "synthetic-location-first"
		first.diagnostic_generation = "round-v2:11111111111111111111111111111111"
		debug_fixture_assert(policy.observe(box, animal, first), "location_control_observe")
		debug_fixture_assert(first.withdraw(), "location_control_first_release")
		var/exception/failure = EXCEPTION("Child moved or disappeared during capture")
		debug_fixture_assert(policy.finish_failure(first, failure, TRUE, TRUE), "location_control_failure")
		debug_fixture_assert(policy.admit_retry(policy.pending_fault_id, policy.pending_operation_id, policy.pending_generation), "location_control_admission")
		policy.attempt = 2
		var/datum/persistence_world_operation/second = begin_persistence_operation(map_storage, "save")
		debug_fixture_assert(second && policy.bind(second), "location_control_retry_owner")
		second.debug_recovery = policy
		second.diagnostic_save_id = "synthetic-location-second"
		second.diagnostic_generation = "round-v2:22222222222222222222222222222222"
		if(findtext(name, "after_encode"))
			debug_fixture_assert(policy.omits(animal, null), "location_control_encode_before_move")
			debug_fixture_assert(islist(policy.audit(second.diagnostic_generation, second)), "location_control_stable_audit")
		animal.loc = findtext(name, "detached") ? null : locate(3, 2, 1)
		var/encode_refused = FALSE
		try
			policy.omits(animal, null)
		catch(var/exception/encode_error)
			encode_refused = encode_error.name == "Debug omitted animal changed; candidate refused"
		debug_fixture_assert(encode_refused, "location_control_stale_encode_accepted")
		var/audit_refused = FALSE
		try
			policy.audit(second.diagnostic_generation, second)
		catch(var/exception/audit_error)
			audit_refused = audit_error.name == "Debug omitted animal changed before publication"
		debug_fixture_assert(audit_refused, "location_control_stale_audit_accepted")
		debug_fixture_assert(debug_fixture_backups_unchanged(), "location_control_marker_or_backup_changed")
		debug_fixture_assert(second.withdraw(), "location_control_retry_release")
		policy.close()
		results[name] = TRUE
	animal.loc = admitted_destination
	return results
