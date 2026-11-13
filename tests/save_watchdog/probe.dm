// Standalone harness for code/modules/persistence/save_watchdog.dm and the
// production save_work_check() (staged by run.py). Stubs the operation,
// storage and notice sinks, drives the watchdog with simulated times and
// writes result.json.
var/datum/persistence_world_operation/persistence_active_operation
var/saving_unattended = FALSE
var/list/notices = list()
var/list/admin_lines = list()
var/list/failures = list()

/datum/persistence_world_operation
	var/kind = "save"
	var/map_storage/storage
	var/progress_at = 0
	var/phase_at = 0
	var/last_phase = "admitted"
	var/abort_reason
	var/abandoned = FALSE
	var/shutdown_save = FALSE
	var/diagnostic_save_id = "save-probe"
	var/diagnostic_phase = "capture"
	var/finished = 0
	proc/finish(success)
		if(persistence_active_operation != src) return FALSE
		finished++
		persistence_active_operation = null
		return TRUE

/datum/moving_save_capture/proc/check()
/datum/save_export_frame
	var/datum/source
	var/current_field

/map_storage
	var/saving_z = 1
	var/last_error
	var/last_export_error
	var/cleanups = 0
	var/failures_recorded = 0
	var/datum/moving_save_capture/moving_save_chunk
	var/saving_work = 0
	var/saving_slice_start = 0
	var/saving_unattended = TRUE
	var/list/saving_export_stack = list()
	proc/cleanup_world_operation()
		cleanups++
		saving_export_stack = list()
	proc/record_save_outcome(success)
		if(!success) failures_recorded++

/proc/notify_world_save(event, datum/persistence_world_operation/operation, success)
	notices += "[event]:[success]"
/proc/persistence_game_log(text)
/proc/message_admins(text)
	admin_lines += text

/proc/expect(condition, message)
	if(!condition) failures += message

/proc/probe_operation(map_storage/storage, at)
	var/datum/persistence_world_operation/operation = new
	operation.storage = storage
	operation.progress_at = at
	operation.phase_at = at
	persistence_active_operation = operation
	return operation

/world
	maxx = 4
	maxy = 4
	maxz = 1

/world/New()
	..()
	spawn(0) probe_run()

/proc/probe_run()
	var/map_storage/storage = new
	// A save doing work is left alone, however long it has run in total.
	var/datum/persistence_world_operation/operation = probe_operation(storage, 0)
	expect(isnull(persistence_save_watchdog(5999)), "nine minutes idle is not a stall")
	operation.progress_at = 20000
	expect(isnull(persistence_save_watchdog(25000)), "a save that keeps working is left alone")
	// Ten minutes without work: alarm once and ask the save to stop, naming
	// the entry it was exporting.
	var/turf/stuck_turf = locate(2, 3, 1)
	var/datum/save_export_frame/frame = new
	frame.source = stuck_turf
	frame.current_field = "contents"
	storage.saving_export_stack += frame
	operation.progress_at = 0
	operation.phase_at = 0
	expect(persistence_save_watchdog(6000) == "alarm", "ten idle minutes raise the alarm")
	expect(findtext(operation.abort_reason, "no save progress for 10 minutes"), "abort reason: [operation.abort_reason]")
	expect(admin_lines.len == 1 && findtext(admin_lines[1], "World save stalled") && findtext(admin_lines[1], "level 1") && findtext(admin_lines[1], "exporting /turf at 2,3,1 (contents)"), "admins hear of it: [json_encode(admin_lines)]")
	expect(isnull(persistence_save_watchdog(6300)), "the alarm is raised once")
	// A live save proc stops at its next work check and takes the ordinary failure path.
	var/thrown = null
	try
		storage.save_work_check()
	catch(var/exception/stopped)
		thrown = "[stopped]"
	expect(thrown && findtext(thrown, "stopped by the stall watchdog"), "the next work check throws ([thrown])")
	// No progress for fifteen minutes: the watchdog releases the operation itself.
	operation.progress_at = 0
	expect(persistence_save_watchdog(9000) == "released", "fifteen idle minutes release the save")
	expect(operation.abandoned && !persistence_active_operation && operation.finished == 1, "admission released")
	expect(storage.cleanups == 1 && storage.failures_recorded == 1 && findtext(storage.last_error, "World save abandoned"), "failure path ran: [storage.cleanups] [storage.failures_recorded] [storage.last_error]")
	expect(json_encode(notices) == json_encode(list("finished:0")), "Discord hears a failed save: [json_encode(notices)]")
	expect(isnull(persistence_save_watchdog(20000)), "nothing left to watch")
	// A save stuck in one phase while its work checks keep ticking is stopped too.
	var/datum/persistence_world_operation/spinning = probe_operation(storage, 0)
	spinning.last_phase = "level 1"
	spinning.progress_at = 27000
	expect(persistence_save_watchdog(27000) == "alarm" && findtext(spinning.abort_reason, "since the level 1 phase"), "phase limit: [spinning.abort_reason]")
	expect(isnull(persistence_save_watchdog(30000)), "a working save is not released, only stopped")
	spinning.finish(FALSE)
	// Loads are never watched.
	var/datum/persistence_world_operation/load = probe_operation(storage, 0)
	load.kind = "load"
	expect(isnull(persistence_save_watchdog(100000)) && !load.abort_reason, "loads are not watched")
	load.finish(TRUE)
	// Ordinary work checks record progress and do not throw.
	var/datum/persistence_world_operation/healthy = probe_operation(storage, 0)
	sleep(5)
	storage.save_work_check()
	expect(healthy.progress_at == world.time && world.time > 0, "work checks record progress")
	text2file(json_encode(list("failures" = failures.len, "messages" = failures)), "result.json")
	del(world)
