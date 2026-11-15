// Save stall watchdog. On Gaia (2026-11-13) an empty-server save logged its
// backup phase and then never advanced or finished. Its operation held save
// admission for good, so no later save could start, and the next restart loaded
// the last completed save: a night of play was lost without any alarm.
//
// The persistence loop (world.dm) calls persistence_save_watchdog() every 30 s.
// A save that does no save work for PERSISTENCE_SAVE_STALL_ALARM, or stays in
// one phase past PERSISTENCE_SAVE_PHASE_LIMIT, is reported to the logs, admins
// and Discord, and asked to stop: its next work check throws, so the ordinary
// failure path cleans up. If it still does nothing for
// PERSISTENCE_SAVE_STALL_RELEASE (its proc died or waits forever), the watchdog
// releases its admission itself. The completed backup stays the recovery point,
// and the empty-server loop retries the save five minutes later.
//
// world.time only advances while the world ticks, so a native call or a long
// copy that blocks the whole server never counts as a stall.
#define PERSISTENCE_SAVE_STALL_ALARM 6000 // 10 minutes without save work
#define PERSISTENCE_SAVE_STALL_RELEASE 9000 // 15 minutes without save work
#define PERSISTENCE_SAVE_PHASE_LIMIT 27000 // 45 minutes in one phase

// Returns null, "alarm" or "released"; now is for the probe.
/proc/persistence_save_watchdog(now = world.time)
	var/datum/persistence_world_operation/operation = persistence_active_operation
	if(!operation || operation.kind != "save" || operation.abandoned) return null
	var/idle = now - operation.progress_at
	var/in_phase = now - operation.phase_at
	if(!operation.abort_reason)
		if(idle >= PERSISTENCE_SAVE_STALL_ALARM)
			operation.abort_reason = "no save progress for [round(idle / 600)] minutes"
		else if(in_phase >= PERSISTENCE_SAVE_PHASE_LIMIT)
			operation.abort_reason = "over [round(in_phase / 600)] minutes since the [operation.last_phase] phase"
		else
			return null
		persistence_save_watchdog_alert("World save stalled: [operation.abort_reason] ([persistence_save_watchdog_where(operation)]). It will be stopped and retried once the server is empty; the last completed save is kept.")
		return "alarm"
	if(idle < PERSISTENCE_SAVE_STALL_RELEASE) return null
	persistence_save_watchdog_release(operation)
	return "released"

/proc/persistence_save_watchdog_where(datum/persistence_world_operation/operation)
	var/map_storage/storage = operation.storage
	var/level = storage ? storage.saving_z : null
	return "[operation.diagnostic_save_id ? operation.diagnostic_save_id : "save"], phase [operation.diagnostic_phase], after [operation.last_phase][level ? ", level [level]" : ""][persistence_save_watchdog_frames(storage)]"

// The entries the save was exporting when it stopped, innermost last: the
// 2026-11-13 Gaia stall left level 1 a quarter written with no hint of where.
/proc/persistence_save_watchdog_frames(map_storage/storage)
	if(!storage || !islist(storage.saving_export_stack) || !storage.saving_export_stack.len) return ""
	var/list/parts = list()
	var/list/stack = storage.saving_export_stack
	for(var/i = max(1, stack.len - 2), i <= stack.len, i++)
		var/datum/save_export_frame/frame = stack[i]
		if(!istype(frame)) continue
		var/datum/source = frame.source
		var/atom/A = source
		var/where = istype(A) && A.z ? " at [A.x],[A.y],[A.z]" : ""
		parts += "[source ? source.type : "a deleted entry"][where] ([istext(frame.current_field) ? copytext(frame.current_field, 1, 41) : "contents"])"
	return parts.len ? ", exporting [jointext(parts, " > ")]" : ""

/proc/persistence_save_watchdog_alert(message)
	world.log << message
	persistence_game_log(message)
	try
		message_admins(message)
	catch
		world.log << "Save watchdog alert could not reach admins."

// The stalled proc never returned: run its failure path for it. Cleanup errors
// are contained so admission is always released.
/proc/persistence_save_watchdog_release(datum/persistence_world_operation/operation)
	operation.abandoned = TRUE
	var/map_storage/storage = operation.storage
	var/message = "World save abandoned: [operation.abort_reason] ([persistence_save_watchdog_where(operation)]). Admission released; the last completed save is kept and the save is retried once the server is empty."
	if(storage)
		try
			storage.cleanup_world_operation()
		catch(var/exception/cleanup_error)
			world.log << "Stalled save cleanup failed: [cleanup_error]"
		storage.last_error = message
		storage.last_export_error = message
		try
			storage.record_save_outcome(FALSE)
		catch
			world.log << "Stalled save outcome could not be recorded."
	notify_world_save("finished", operation, FALSE)
	operation.finish(FALSE)
	persistence_save_watchdog_alert(message)
