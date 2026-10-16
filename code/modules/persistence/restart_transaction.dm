// A completed generation is the recovery point. This does not make the yielding
// world serializer an atomic snapshot of every gameplay operation.
var/global/datum/persistence_restart_transaction/persistence_restart = new

/proc/persistence_lifecycle_hex(value)
	if(!istext(value) || length(value) != 32) return FALSE
	for(var/i = 1, i <= 32, i++)
		if(!findtext("0123456789abcdef", copytext(value, i, i+1))) return FALSE
	return TRUE

/datum/persistence_restart_transaction
	var/busy = FALSE
	var/startup_hold = FALSE
	var/import_started = FALSE
	var/import_complete = FALSE
	var/players_ready = FALSE
	var/expected_generation
	var/last_error
	var/intent_path = "map_saves/restart_intent.json"
	var/lifecycle_operation
	var/lifecycle_session

/datum/persistence_restart_transaction/proc/exists()
	return fexists(intent_path)

/datum/persistence_restart_transaction/proc/detect_startup()
	startup_hold = exists()
	if(startup_hold) persistence_save_in_progress = TRUE
	return startup_hold

/datum/persistence_restart_transaction/proc/read_intent()
	var/list/I = json_decode(file2text(intent_path))
	if(!islist(I) || !(I.len in list(4, 6)) || I["version"] != 1 || !istext(I["generation"]) || copytext(I["generation"], 1, 10) != "round-v2:" || !istext(I["metadata"]) || !istext(I["round"]))
		throw EXCEPTION("Malformed restart intent; preserve map_saves and inspect restart_intent.json")
	if(I.len == 6 && (!persistence_lifecycle_hex(I["lifecycle_operation"]) || !persistence_lifecycle_hex(I["lifecycle_session"])))
		throw EXCEPTION("Malformed lifecycle restart binding")
	if(I.len == 4 && (("lifecycle_operation" in I) || ("lifecycle_session" in I)))
		throw EXCEPTION("Partial lifecycle restart binding")
	return I

/datum/persistence_restart_transaction/proc/current_identity()
	if(!map_storage.validate_world_save())
		throw EXCEPTION("Save validation failed: [map_storage.last_error]")
	var/list/R = map_storage.read_round_state()
	if(R["version"] != 2)
		throw EXCEPTION("Restart recovery requires a durable round-v2 generation")
	var/list/I = list("version" = 1, "generation" = R["generation"], "metadata" = md5(file2text("map_saves/map.txt")), "round" = md5(file2text("map_saves/round.json")))
	if(lifecycle_operation)
		I["lifecycle_operation"] = lifecycle_operation
		I["lifecycle_session"] = lifecycle_session
	return I

/datum/persistence_restart_transaction/proc/matches(list/A, list/B)
	for(var/key in list("version", "generation", "metadata", "round", "lifecycle_operation", "lifecycle_session"))
		if(A[key] != B[key]) return FALSE
	return TRUE

/datum/persistence_restart_transaction/proc/publish(list/I)
	if(exists()) throw EXCEPTION("A restart intent already exists; resolve it before saving again")
	if(!text2file(json_encode(I), intent_path))
		throw EXCEPTION("Could not write restart intent")
	if(!matches(I, read_intent()))
		throw EXCEPTION("Restart intent readback failed")

/datum/persistence_restart_transaction/proc/consume(list/I)
	// Never delete a replacement intent belonging to another operation.
	if(!exists() || !matches(I, read_intent()))
		throw EXCEPTION("Restart intent changed or disappeared; preserving recovery state")
	if(!fdel(intent_path) || exists())
		throw EXCEPTION("Could not remove restart intent; preserve files and resolve before another save")

/datum/persistence_restart_transaction/proc/report(message)
	last_error = message
	world.log << "World restart transaction: [message]"
	message_admins("World restart transaction: [message]")

/datum/persistence_restart_transaction/proc/supported()
#ifdef OPENDREAM
	return FALSE
#else
	return map && map.uses_durable_metadata() && ticker
#endif

/datum/persistence_restart_transaction/proc/save_generation()
	return ticker.savemap(src)

/datum/persistence_restart_transaction/proc/load_generation()
	// Hand the same synchronous lock to loadmap before it can yield.
	persistence_save_in_progress = FALSE
	return ticker.loadmap(src)

/datum/persistence_restart_transaction/proc/request_restart()
	world.Reboot(0, expected_generation)
	// A normal successful native reboot does not resume this transaction.
	throw EXCEPTION("Native restart returned without replacing the world")

/datum/persistence_restart_transaction/proc/request_shutdown()
	var/list/I = read_intent()
	if(!busy || startup_hold || !expected_generation || I["generation"] != expected_generation || !matches(I, current_identity()))
		throw EXCEPTION("Validated shutdown lost its generation ownership")
	// Validation can yield. Recheck the durable ownership at the final boundary.
	if(!matches(I, read_intent()) || trim(file2text("map_saves/save_complete.txt")) != expected_generation)
		throw EXCEPTION("Validated shutdown generation changed after validation")
	// Native graceful world deletion lets the external supervisor preserve the
	// completed generation and replace the binary before the next startup.
	del(world)
	// Native deletion can return until the current execution yields. Give BYOND
	// that boundary before failure cleanup can consume the valid restart intent.
	sleep(1)
	throw EXCEPTION("Native shutdown returned without closing the world")

/datum/persistence_restart_transaction/proc/execute(shutdown = FALSE, operation, session)
	if(shutdown && (!persistence_lifecycle_hex(operation) || !persistence_lifecycle_hex(session)))
		report("Save/shutdown refused: invalid lifecycle binding")
		return FALSE
	if(building_allocating_z || map_storage.dimension_recovery_required)
		report("Save/restart refused: building allocation is incomplete; finish allocation or restart recovery")
		return FALSE
	if(busy || startup_hold || persistence_save_in_progress || exists())
		report("Save/restart refused: another save, import or unresolved restart intent owns recovery")
		return FALSE
	if(!supported())
		report("Save/restart currently supports native BYOND Gaia and Europe only")
		return FALSE
	busy = TRUE
	lifecycle_operation = shutdown ? operation : null
	lifecycle_session = shutdown ? session : null
	var/list/published
	try
		if(!save_generation()) throw EXCEPTION("World save failed; server remains running")
		var/list/I = current_identity()
		// Record ownership before publication, including a failed partial write.
		published = I
		publish(I)
		expected_generation = I["generation"]
		if(!matches(I, current_identity())) throw EXCEPTION("Completed generation changed before restart")
		if(shutdown)
			to_chat(world, "<b>Save validated. Shutting down for the local updater.</b>")
			request_shutdown()
		else
			to_chat(world, "<b>Save validated. Restarting now; reconnect to resume the saved generation.</b>")
			request_restart()
	catch(var/exception/e)
		var/cleanup = ""
		if(published && exists())
			try
				consume(published)
			catch(var/exception/cleanup_error)
				cleanup = " Intent cleanup FAILED: [cleanup_error]. Further saves are blocked until the intent is resolved."
		report("[e].[cleanup]")
	busy = FALSE
	expected_generation = null
	lifecycle_operation = null
	lifecycle_session = null
	return FALSE

/datum/persistence_restart_transaction/proc/resume_startup()
	if(!startup_hold || busy) return FALSE
	busy = TRUE
	try
		var/list/I = read_intent()
		lifecycle_operation = I["lifecycle_operation"]
		lifecycle_session = I["lifecycle_session"]
		if(!map_storage.prepare_saved_dimensions(I)) throw EXCEPTION("Saved dimension bootstrap failed: [map_storage.last_error]")
		if(!matches(I, current_identity())) throw EXCEPTION("Restart intent does not match the completed generation")
		expected_generation = I["generation"]
		if(import_started && !import_complete)
			throw EXCEPTION("An import already failed after it began; restart from the original map before retrying")
		if(!import_complete)
			import_started = TRUE
			if(!load_generation()) throw EXCEPTION("Intended generation import failed: [map_storage.last_error]")
			import_complete = TRUE
		consume(I)
		startup_hold = FALSE
		persistence_save_in_progress = FALSE
		last_error = null
		busy = FALSE
		report("Intended generation restored and one-shot intent consumed")
		last_error = null
		players_ready = map_storage.finish_player_restoration()
		return TRUE
	catch(var/exception/e)
		persistence_save_in_progress = TRUE
		report("RECOVERY HOLD: [e]. No fresh round or automatic retry will run. Preserve map_saves; repair the matching files, then use Resume Pending Recovery before import begins, or restart from the original map after an import failure.")
	busy = FALSE
	return FALSE
