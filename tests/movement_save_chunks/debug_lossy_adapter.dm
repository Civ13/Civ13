// This reduced serializer fixture never runs the debug recovery policy.
// Any attempt to use it fails closed; the full-source debug fixture owns the
// actual recovery behavior and round-trip assertions.
/datum/save_debug_recovery
	var/encoding_depth = 0
	var/stop_reason
	proc/bind(datum/persistence_world_operation/operation)
		throw EXCEPTION("Debug recovery requires the full-source fixture")
	proc/observe(atom/parent, atom/movable/child, datum/persistence_world_operation/operation)
		throw EXCEPTION("Debug recovery requires the full-source fixture")
	proc/finish_failure(datum/persistence_world_operation/operation, exception/error, cleanup_ok, released)
		throw EXCEPTION("Debug recovery requires the full-source fixture")
	proc/finish_success(datum/persistence_world_operation/operation)
		throw EXCEPTION("Debug recovery requires the full-source fixture")
	proc/audit(generation, datum/persistence_world_operation/operation)
		throw EXCEPTION("Debug recovery requires the full-source fixture")

/map_storage/proc/debug_backup_identity_valid()
	throw EXCEPTION("Debug recovery requires the full-source fixture")

/map_storage/proc/debug_cleanup_owned(datum/persistence_world_operation/operation)
	throw EXCEPTION("Debug recovery requires the full-source fixture")

/proc/valid_debug_recovery_audit(value, generation)
	throw EXCEPTION("Debug recovery requires the full-source fixture")

/proc/save_debug_omits(atom/movable/value, source_field)
	if(persistence_active_operation && persistence_active_operation.debug_recovery)
		throw EXCEPTION("Debug recovery requires the full-source fixture")
	return FALSE
