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
	var/busy = FALSE
	var/last_error
	var/list/used_operations = list()

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
	return list("ok" = ok, "revision" = read_revision(), "session" = boot_session(), "map" = map ? map.ID : null, "maxx" = world.maxx, "maxy" = world.maxy, "maxz" = world.maxz, "ready" = ready ? TRUE : FALSE, "busy" = locked ? TRUE : FALSE, "operation" = operation, "error" = error, "generation" = trim(file2text("map_saves/save_complete.txt")), "clients" = clients.len, "restart_hold" = persistence_restart.startup_hold, "restart_import_complete" = persistence_restart.import_complete, "restart_intent" = persistence_restart.exists())

/datum/nomads_lifecycle_control/proc/handle(list/input, addr)
	// BYOND supplies IPv4 peers as 127.0.0.1:port. IPv6 is deliberately not
	// accepted through the legacy Topic limiter's IPv4-only whitelist.
	var/list/peer = istext(addr) ? splittext(addr, ":") : list("")
	var/token = read_token()
	if(peer[1] != "127.0.0.1" || !nomads_lifecycle_hex(token, 32) || input["token"] != token || !nomads_lifecycle_hex(read_revision(), 40))
		return json_encode(list("ok" = FALSE, "error" = "unauthorized_or_disabled"))
	var/action = input["action"]
	var/list/allowed = action == "status" ? list("nomads_lifecycle", "token", "action") : list("nomads_lifecycle", "token", "action", "session", "operation")
	if(input["nomads_lifecycle"] != "1" || input.len != allowed.len || !(action in list("status", "save_shutdown")))
		return json_encode(snapshot(FALSE, "malformed_request"))
	for(var/key in input)
		if(!(key in allowed)) return json_encode(snapshot(FALSE, "malformed_request"))
	if(action == "status") return json_encode(snapshot())
	if(input["session"] != boot_session() || !nomads_lifecycle_hex(input["operation"], 32))
		return json_encode(snapshot(FALSE, "invalid_session_or_operation"))
	if(input["operation"] in used_operations)
		return json_encode(snapshot(FALSE, "operation_replayed"))
	if(used_operations.len >= 64)
		return json_encode(snapshot(FALSE, "operation_limit_restart_required"))
	if(busy || persistence_save_in_progress || persistence_restart.busy || persistence_restart.startup_hold || persistence_restart.exists() || building_allocating_z || map_storage.dimension_recovery_required || !persistence_restart.supported())
		return json_encode(snapshot(FALSE, "save_or_recovery_unavailable"))
	operation = input["operation"]
	used_operations += operation
	busy = TRUE // Reserve before the asynchronous saver can yield.
	last_error = null
	spawn(0)
		run_operation()
	return json_encode(snapshot())

/datum/nomads_lifecycle_control/proc/run_operation()
	try
		persistence_restart.execute(TRUE, operation, boot_session())
		last_error = persistence_restart.last_error ? persistence_restart.last_error : "shutdown_returned"
	catch(var/exception/e)
		last_error = "[e]"
	busy = FALSE
