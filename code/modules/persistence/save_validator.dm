// Outside save validator: a validate-only boot of this build.
//
// The host supervisor (scripts/shard-group/shard_group.py, ensure_save_validation)
// copies a region's completed save and the region's build files into a private
// folder and starts DreamDaemon there with -params validate_save=1. That world
// runs the full preflight a normal start would run, which writes the validation
// record (map_saves/validated.json) for these files on this build, writes
// validation_result.json and ends. It never opens the round, the hub entry, the
// scheduler or any relay, bot or transfer link: world/New returns before them.
//
// The supervisor copies the record into the region only while the region's own
// files still match its checksums, so the next start on the same build (after a
// crash, a power loss or a restart without new code) trusts the record and skips
// the per-entry walk. A newer save leaves the copied record unmatched, and the
// start then runs the full check as before: the validator can only skip work,
// never vouch for files it did not read.

var/global/persistence_validate_only = FALSE

/proc/persistence_validate_only_requested()
	return islist(world.params) && world.params["validate_save"] == "1"

/proc/persistence_run_validate_only()
	set waitfor = FALSE
	sleep(1) // Let world/New return first.
	var/list/result = list("version" = 1, "ok" = FALSE, "generation" = null, "record" = FALSE)
	var/started = world.timeofday
	try
		if(fexists("map_saves/save_complete.txt")) result["generation"] = trim(file2text("map_saves/save_complete.txt"))
		// A stale record must not stand in for the walk this process exists to run.
		map_storage.clear_validation_record()
		// A start checks the save at its saved height before it adds any level
		// (prepare_saved_dimensions); check, and record, the same prospective world.
		var/target_z = map_storage.saved_dimension_target()
		if(target_z != world.maxz) map_storage.validation_maxz = target_z
		result["maxz"] = target_z
		result["ok"] = !!map_storage.validate_world_save()
		map_storage.validation_maxz = 0
		result["note"] = map_storage.last_validation_note
		result["full"] = !!map_storage.last_validation_full
		if(!result["ok"]) result["error"] = map_storage.last_error
		result["record"] = fexists("map_saves/validated.json")
	catch(var/exception/e)
		result["ok"] = FALSE
		result["error"] = "[e]"
	result["seconds"] = round((world.timeofday - started) / 10, 0.1)
	world.log << "Save validator: [json_encode(result)]"
	if(fexists("validation_result.json")) fdel("validation_result.json")
	text2file(json_encode(result), "validation_result.json")
	del(world)
