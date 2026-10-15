// A completed generation is the recovery point. This does not make the yielding
// world serializer an atomic snapshot of every gameplay operation.
var/global/datum/persistence_restart_transaction/persistence_restart = new

/datum/persistence_restart_transaction
	var/busy = FALSE
	var/startup_hold = FALSE
	var/import_started = FALSE
	var/import_complete = FALSE
	var/expected_generation
	var/last_error
	var/intent_path = "map_saves/restart_intent.json"

/datum/persistence_restart_transaction/proc/exists()
	return fexists(intent_path)

/datum/persistence_restart_transaction/proc/detect_startup()
	startup_hold = exists()
	if(startup_hold) persistence_save_in_progress = TRUE
	return startup_hold

/datum/persistence_restart_transaction/proc/read_intent()
	var/list/I = json_decode(file2text(intent_path))
	if(!islist(I) || I.len != 4 || I["version"] != 1 || !istext(I["generation"]) || copytext(I["generation"], 1, 10) != "round-v2:" || !istext(I["metadata"]) || !istext(I["round"]))
		throw EXCEPTION("Malformed restart intent; preserve map_saves and inspect restart_intent.json")
	return I

/datum/persistence_restart_transaction/proc/current_identity()
	if(!map_storage.validate_world_save())
		throw EXCEPTION("Save validation failed: [map_storage.last_error]")
	var/list/R = map_storage.read_round_state()
	if(R["version"] != 2)
		throw EXCEPTION("Restart recovery requires a durable round-v2 generation")
	return list("version" = 1, "generation" = R["generation"], "metadata" = md5(file2text("map_saves/map.txt")), "round" = md5(file2text("map_saves/round.json")))

/datum/persistence_restart_transaction/proc/matches(list/A, list/B)
	for(var/key in list("version", "generation", "metadata", "round"))
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

/datum/persistence_restart_transaction/proc/execute()
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
	var/list/published
	try
		if(!save_generation()) throw EXCEPTION("World save failed; server remains running")
		var/list/I = current_identity()
		// Record ownership before publication, including a failed partial write.
		published = I
		publish(I)
		expected_generation = I["generation"]
		if(!matches(I, current_identity())) throw EXCEPTION("Completed generation changed before restart")
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
	return FALSE

/datum/persistence_restart_transaction/proc/resume_startup()
	if(!startup_hold || busy) return FALSE
	busy = TRUE
	try
		var/list/I = read_intent()
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
		map_storage.finish_player_restoration()
		return TRUE
	catch(var/exception/e)
		persistence_save_in_progress = TRUE
		report("RECOVERY HOLD: [e]. No fresh round or automatic retry will run. Preserve map_saves; repair the matching files, then use Resume Pending Recovery before import begins, or restart from the original map after an import failure.")
	busy = FALSE
	return FALSE
