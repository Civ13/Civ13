// Disabled without a valid local token and revision. This is a finite local
// supervisor interface, not an admin command/eval or remote control service.
var/global/datum/nomads_lifecycle_control/nomads_lifecycle = new

/proc/nomads_lifecycle_hex(value, size)
	if(!istext(value) || length(value) != size) return FALSE
	for(var/i = 1, i <= size, i++)
		if(!findtext("0123456789abcdef", copytext(value, i, i+1))) return FALSE
	return TRUE

/datum/nomads_lifecycle_control
	var/session
	var/operation
	var/operation_is_maintenance = FALSE
	var/busy = FALSE
	var/last_error
	var/list/used_operations = list()
	var/maintenance_operation
	var/maintenance_announcing = FALSE
	var/list/maintenance_used = list()

/datum/nomads_lifecycle_control/proc/request_maintenance()
	if(maintenance_operation || maintenance_announcing || maintenance_used.len >= 64 || busy || persistence_save_in_progress || persistence_restart.busy || persistence_restart.startup_hold || persistence_restart.exists() || !persistence_restart.supported() || !nomads_lifecycle_hex(read_token(), 32) || !nomads_lifecycle_hex(read_revision(), 40)) return FALSE
	maintenance_announcing = TRUE
	maintenance_operation = md5("maintenance-[world.realtime]-[world.time]-[rand(1,1000000000)]-\ref[src]")
	if(maintenance_operation in maintenance_used)
		maintenance_operation = null
		maintenance_announcing = FALSE
		return FALSE
	maintenance_used += maintenance_operation
	var/requested_operation = maintenance_operation
	to_chat(world, "<b>An administrator requested maintenance. The server will save and shut down after one minute if its supervisor accepts the request. Stop gameplay now.</b>")
	spawn(600)
		maintenance_announcing = FALSE
	spawn(3000)
		if(maintenance_operation == requested_operation && !busy)
			maintenance_operation = null
			message_admins("Maintenance request expired without an accepted shutdown. Check the supervisor and its operation journal before retrying.")
	return TRUE

/datum/nomads_lifecycle_control/proc/read_token()
	if(!fexists("config/lifecycle-token.txt")) return null
	return trim(file2text("config/lifecycle-token.txt"))
/datum/nomads_lifecycle_control/proc/read_revision()
	if(!fexists("config/lifecycle-revision.txt")) return null
	return trim(file2text("config/lifecycle-revision.txt"))
/datum/nomads_lifecycle_control/proc/boot_session()
	if(!session) session = md5("[world.realtime]-[world.time]-[rand(1,1000000000)]-\ref[src]")
	return session
/datum/nomads_lifecycle_control/proc/snapshot(ok = TRUE, error)
	var/locked = busy || persistence_save_in_progress || persistence_restart.busy
	var/ready = ticker && ticker.current_state == GAME_STATE_PLAYING && !locked && !last_error && !persistence_restart.startup_hold && !map_storage.last_error && !persistence_restart.last_error && (!persistence_restart.import_started || (persistence_restart.import_complete && persistence_restart.players_ready))
	if(!error) error = last_error
	if(!error) error = persistence_restart.last_error
	if(!error) error = map_storage.last_error
	return list("ok" = ok, "revision" = read_revision(), "session" = boot_session(), "map" = map ? map.ID : null, "maxx" = world.maxx, "maxy" = world.maxy, "maxz" = world.maxz, "ready" = ready ? TRUE : FALSE, "busy" = locked ? TRUE : FALSE, "operation" = operation, "maintenance_operation" = maintenance_announcing ? null : maintenance_operation, "error" = error, "generation" = trim(file2text("map_saves/save_complete.txt")), "clients" = clients.len, "restart_hold" = persistence_restart.startup_hold, "restart_import_complete" = persistence_restart.import_complete, "restart_intent" = persistence_restart.exists(), "debug" = agent_diagnostic_state())

// Fixed cached state only. No arbitrary vars, logs, file reads or world scans.
/proc/agent_diagnostic_source_file(value)
	if(!istext(value) || length(value) > 160) return null
	var/path = replacetext(value, "\\", "/")
	if(copytext(path, 1, 6) != "code/" || copytext(path, -3) != ".dm" || findtext(path, "..")) return null
	for(var/i = 1 to length(path))
		if(!findtext("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_/.", copytext(path, i, i+1))) return null
	return path

/proc/agent_diagnostic_state()
	var/datum/persistence_world_operation/P = persistence_active_operation
	var/kind = P && (P.kind in list("save", "load")) ? P.kind : "idle"
	var/list/progress = list("active" = !!P, "kind" = kind, "saving_z" = kind == "save" ? map_storage.saving_z : null, "loading_z" = kind == "load" ? map_storage.loading_z : null, "backend_started" = P ? P.backend_started : FALSE, "contents_started" = P ? P.contents_started : FALSE, "mutation_started" = P ? P.mutation_started : FALSE, "restoring_players" = P ? P.restoring_players : FALSE, "percent_available" = FALSE)
	var/datum/error_viewer/error_cache/cache = GLOB ? GLOB.error_cache : null
	var/list/sources = list()
	if(cache)
		for(var/i = 1 to min(cache.error_sources.len, 8))
			var/uid = cache.error_sources[i]
			if(!istext(uid) || length(uid) > 180) continue
			var/list/parts = splittext(uid, ",")
			if(parts.len != 2) continue
			var/path = agent_diagnostic_source_file(parts[1])
			var/line_text = parts[2]
			if(!path || !istext(line_text) || length(line_text) > 7) continue
			var/valid = length(line_text) > 0
			for(var/j = 1 to length(line_text))
				if(!findtext("0123456789", copytext(line_text, j, j+1))) valid = FALSE
			var/line_number = text2num(line_text)
			if(!valid || line_number < 1) continue
			var/datum/error_viewer/error_source/S = cache.error_sources[uid]
			if(!istype(S)) continue
			sources += list(list("file" = path, "line" = line_number, "logged" = S.total_logged, "skipped" = S.total_skipped, "retired" = S.total_retired))
	var/list/runtime = list("total" = GLOB ? GLOB.total_runtimes : null, "skipped" = GLOB ? GLOB.total_runtimes_skipped : null, "cache_available" = !!cache, "source_total" = cache ? cache.error_sources.len : null, "prefix_limit" = 8, "sources" = sources, "stack_available" = FALSE, "proc_available" = FALSE)
	var/list/state = list("schema" = 1, "tick" = world.time, "progress" = progress, "runtime" = runtime)
#ifdef CIV13_VARIABLE_OBSERVABILITY
	state["variables"] = variable_observability_status()
#endif
	return state

/datum/nomads_lifecycle_control/proc/handle(list/input, addr)
	// BYOND supplies IPv4 peers as 127.0.0.1:port. IPv6 is deliberately not
	// accepted through the legacy Topic limiter's IPv4-only whitelist.
	var/list/peer = istext(addr) ? splittext(addr, ":") : list("")
	var/token = read_token()
	if(peer[1] != "127.0.0.1" || !nomads_lifecycle_hex(token, 32) || input["token"] != token || !nomads_lifecycle_hex(read_revision(), 40))
		return json_encode(list("ok" = FALSE, "error" = "unauthorized_or_disabled"))
	var/action = input["action"]
	var/list/allowed = action == "status" ? list("nomads_lifecycle", "token", "action") : list("nomads_lifecycle", "token", "action", "session", "operation")
	if(action == "diagnose") allowed = list("nomads_lifecycle", "token", "action", "session", "operation", "target")
	if(input["nomads_lifecycle"] != "1" || input.len != allowed.len || !(action in list("status", "save_shutdown", "maintenance_save_shutdown", "maintenance_failed", "diagnose")))
		return json_encode(snapshot(FALSE, "malformed_request"))
	for(var/key in input)
		if(!(key in allowed)) return json_encode(snapshot(FALSE, "malformed_request"))
	if(action == "status") return json_encode(snapshot())
	if(action == "diagnose") return diagnose(input)
	if(input["session"] != boot_session() || !nomads_lifecycle_hex(input["operation"], 32))
		return json_encode(snapshot(FALSE, "invalid_session_or_operation"))
	if(action == "maintenance_failed")
		if(input["operation"] != maintenance_operation || maintenance_announcing || busy)
			return json_encode(snapshot(FALSE, "maintenance_not_pending"))
		maintenance_operation = null
		message_admins("Maintenance failed or was refused by the supervisor. Inspect its operation journal before retrying.")
		return json_encode(snapshot())
	if(action == "maintenance_save_shutdown")
		if(!maintenance_operation || maintenance_announcing || input["operation"] != maintenance_operation)
			return json_encode(snapshot(FALSE, "maintenance_operation_mismatch"))
	else if(maintenance_operation)
		return json_encode(snapshot(FALSE, "maintenance_operation_pending"))
	if(input["operation"] in used_operations)
		return json_encode(snapshot(FALSE, "operation_replayed"))
	if(used_operations.len >= 64)
		return json_encode(snapshot(FALSE, "operation_limit_restart_required"))
	if(busy || persistence_save_in_progress || persistence_restart.busy || persistence_restart.startup_hold || persistence_restart.exists() || building_allocating_z || map_storage.dimension_recovery_required || !persistence_restart.supported())
		return json_encode(snapshot(FALSE, "save_or_recovery_unavailable"))
	operation = input["operation"]
	operation_is_maintenance = action == "maintenance_save_shutdown"
	used_operations += operation
	busy = TRUE // Reserve before the asynchronous saver can yield.
	last_error = null
	spawn(0)
		run_operation()
	return json_encode(snapshot())

/datum/nomads_lifecycle_control/proc/run_operation()
	try
		persistence_restart.execute(TRUE, operation, boot_session(), operation_is_maintenance)
		last_error = persistence_restart.last_error ? persistence_restart.last_error : "shutdown_returned"
	catch(var/exception/e)
		last_error = "[e]"
	busy = FALSE
