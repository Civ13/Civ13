// Startup observation only. Default-off; never authorizes recovery or server control.
var/global/datum/game_ready_startup/game_ready_startup = new

/proc/game_ready_identifier(value, maximum)
	if(!istext(value) || !length(value) || length(value) > maximum) return FALSE
	for(var/i = 1, i <= length(value), i++)
		if(!findtextEx("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-", copytext(value, i, i+1))) return FALSE
	return TRUE

/proc/game_ready_hex(value)
	if(!istext(value) || length(value) != 32) return FALSE
	for(var/i = 1, i <= 32, i++)
		if(!findtextEx("0123456789abcdef", copytext(value, i, i+1))) return FALSE
	return TRUE

/datum/game_ready_load_ticket
	should_save = FALSE
	var/datum/game_ready_startup/owner
	var/datum/persistence_restart_transaction/transaction
	var/datum/persistence_world_operation/operation
	var/used = FALSE

/datum/game_ready_startup
	should_save = FALSE
	var/datum/expected_area
	var/active = FALSE
	var/failed = FALSE
	var/initialized = FALSE
	var/selection
	var/boot
	var/server
	var/map_storage/storage
	var/datum/game_ready_load_ticket/ticket
	var/datum/persistence_restart_transaction/restart_owner
	var/round_id
	var/generation
	var/generation_kind
	var/restore_complete = FALSE
	var/committed = FALSE
	var/payload_json
	var/expected_ack
	var/pending = FALSE
	var/stopped = FALSE
	var/attempts = 0
	var/window_end

	proc/begin(datum/area_token)
		if(active || failed || !area_token || !config || !config.webhook_game_ready) return FALSE
		if(!game_ready_identifier(config.webhook_game_ready_server, 64) || !nomads_lifecycle || !map_storage) return FALSE
		boot = nomads_lifecycle.boot_session()
		if(!game_ready_hex(boot)) return FALSE
		server = config.webhook_game_ready_server
		storage = map_storage
		expected_area = area_token
		active = TRUE
		return TRUE

	proc/current()
		return active && !failed && config && config.webhook_game_ready && config.webhook_game_ready_server == server && nomads_lifecycle && nomads_lifecycle.boot_session() == boot && map_storage == storage

	proc/initialization_failed()
		expected_area = null
		if(ticket) ticket.operation = null
		failed = TRUE
		return FALSE

	proc/initialization_complete(success)
		if(!current() || success != TRUE) return initialization_failed()
		expected_area = null
		initialized = TRUE
		return maybe_ready()

	proc/select_fresh(identity)
		if(!current() || selection || storage.round_restored || !game_ready_identifier(identity, 128)) return FALSE
		selection = "fresh"
		round_id = identity
		generation_kind = "fresh"
		generation = "fresh:[boot]"
		restore_complete = TRUE
		return maybe_ready()

	proc/reserve_restore(datum/persistence_restart_transaction/transaction)
		if(!current() || selection) return null
		if(transaction && (transaction != persistence_restart || !transaction.startup_hold)) return null
		selection = transaction ? "restart" : "restore"
		restart_owner = transaction
		ticket = new
		ticket.owner = src
		ticket.transaction = transaction
		return ticket

	proc/restart_ticket(datum/persistence_restart_transaction/transaction)
		if(!current() || selection != "restart" || transaction != restart_owner) return null
		return ticket

	proc/claim_load(datum/game_ready_load_ticket/candidate, datum/persistence_world_operation/operation, map_storage/loaded_storage, datum/persistence_restart_transaction/transaction)
		if(!current() || !candidate || candidate != ticket || candidate.owner != src || candidate.used || candidate.operation) return null
		if(loaded_storage != storage || candidate.transaction != transaction || !operation || !operation.current(storage, "load")) return null
		candidate.operation = operation
		return candidate

	proc/load_failed(datum/game_ready_load_ticket/candidate, datum/persistence_world_operation/operation)
		if(!candidate || candidate != ticket || candidate.operation != operation) return FALSE
		candidate.operation = null
		if(operation.mutation_started) return initialization_failed()
		return FALSE

	proc/loaded(datum/game_ready_load_ticket/candidate, datum/persistence_world_operation/operation, map_storage/loaded_storage, datum/persistence_restart_transaction/transaction, identity, loaded_generation)
		if(!candidate || candidate != ticket || candidate.owner != src || candidate.used || candidate.operation != operation) return FALSE
		candidate.operation = null
		candidate.used = TRUE
		if(!current()) return initialization_failed()
		if(loaded_storage != storage || operation.storage != storage || operation.kind != "load" || operation.restart_transaction != transaction || candidate.transaction != transaction || persistence_active_operation || !game_ready_identifier(identity, 128) || game_id != identity) return initialization_failed()
		// Unsupported legacy/v1 identities are suppressed, never rewritten.
		if(!istext(loaded_generation) || length(loaded_generation) != 41 || copytext(loaded_generation, 1, 10) != "round-v2:" || !game_ready_hex(copytext(loaded_generation, 10))) return initialization_failed()
		round_id = identity
		generation = loaded_generation
		generation_kind = "restored"
		if(!transaction) restore_complete = TRUE
		return maybe_ready()

	proc/restart_failed(datum/persistence_restart_transaction/transaction)
		if(transaction != restart_owner || !ticket || !ticket.operation) return FALSE
		return load_failed(ticket, ticket.operation)

	proc/restart_completed(datum/persistence_restart_transaction/transaction, players_return)
		if(!current() || selection != "restart" || transaction != restart_owner || !ticket || !ticket.used || ticket.operation || !generation) return FALSE
		if(players_return != TRUE || transaction.players_ready != TRUE || !transaction.import_complete || transaction.expected_generation != generation || transaction.startup_hold || transaction.busy || transaction.exists()) return FALSE
		restore_complete = TRUE
		return maybe_ready()

	proc/healthy()
		if(!current() || !ticker || !game_ready_identifier(round_id, 128) || game_id != round_id) return FALSE
		if(persistence_active_operation || persistence_save_in_progress || persistence_load_recovery_required || persistence_startup_recovery_status) return FALSE
		if(storage.last_error || storage.dimension_recovery_required || storage.dimension_budget_hold || world_z_budget.active) return FALSE
		if(!persistence_restart || persistence_restart.startup_hold || persistence_restart.busy || persistence_restart.exists() || persistence_restart.last_error) return FALSE
		if(nomads_lifecycle.busy) return FALSE
		if(generation_kind == "restored" && !persistence_player_restore_ready) return FALSE
		return TRUE

	proc/maybe_ready()
		if(committed || !initialized || !restore_complete || !healthy()) return FALSE
		var/list/values = list("game_ready.v1", "game_ready", server, boot, round_id, generation_kind, generation)
		var/list/payload = list("schema" = values[1], "event" = values[2], "server" = values[3], "boot" = values[4], "round" = values[5], "generation_kind" = values[6], "generation" = values[7])
		payload_json = json_encode(payload)
		if(length(payload_json) > 1024) return initialization_failed()
		expected_ack = md5(jointext(values, "\n"))
		committed = TRUE
		window_end = world.time + 120 SECONDS
		spawn(0)
			attempt()
		return TRUE

	proc/acknowledged(list/response)
		if(!islist(response) || !istext(response["STATUS"])) return FALSE
		var/status = response["STATUS"]
		if(!(copytext(status, 1, 4) in list("200", "202")) || (length(status) > 3 && copytext(status, 4, 5) != " ")) return FALSE
		var/matched = FALSE
		for(var/name in response)
			if(istext(name) && lowertext(name) == "x-civ13-game-ready")
				if(matched || response[name] != expected_ack) return FALSE
				matched = TRUE
		return matched

	proc/attempt()
		if(stopped || pending || !committed) return FALSE
		if(attempts >= 3 || world.time > window_end || !healthy())
			stopped = TRUE
			return FALSE
		pending = TRUE
		attempts++
		var/list/response
		try
			response = game_ready_export(payload_json)
		catch
			response = null
		// An unresolved Export keeps this ownership; no parallel timeout retry.
		pending = FALSE
		if(world.time > window_end || !healthy())
			stopped = TRUE
			return FALSE
		if(acknowledged(response))
			stopped = TRUE
			return TRUE
		if(attempts >= 3)
			stopped = TRUE
			return FALSE
		var/delay = attempts == 1 ? 5 SECONDS : 15 SECONDS
		spawn(delay)
			attempt()
		return FALSE

// Same authenticated destination as existing webhooks. Never logs the URL/key.
// Export may outlive the admission window; this is not hard transport containment.
/proc/game_ready_export(payload_json)
	if(!config || !config.webhook_game_ready || !config.webhook_can_fire || !config.webhook_address || !config.webhook_key) return null
	if(!istext(payload_json) || length(payload_json) > 1024 || !istext(config.webhook_address) || length(config.webhook_address) > 2048 || !istext(config.webhook_key) || length(config.webhook_key) > 512) return null
	var/query = "[config.webhook_address]?key=[url_encode(config.webhook_key)]&method=game_ready&data=[url_encode(payload_json)]"
	return world.Export(query)

// Fixed internal observer seam. Minimal persistence probes may omit this module;
// absence means no notification, never permission to bypass save/load admission.
/proc/game_ready_startup_event(event, first, second, third, fourth, fifth, sixth)
	switch(event)
		if("begin")
			if(game_ready_startup.begin(first)) return game_ready_startup
		if("setup_context")
			if(game_ready_startup.current() && !game_ready_startup.initialized && !game_ready_startup.selection && first == game_ready_startup.expected_area) return game_ready_startup
		if("initialization_failed")
			if(first == game_ready_startup) return game_ready_startup.initialization_failed()
		if("initialization_complete")
			if(first == game_ready_startup) return game_ready_startup.initialization_complete(second)
		if("fresh")
			if(first == game_ready_startup) return game_ready_startup.select_fresh(second)
		if("reserve_restore")
			if(first == game_ready_startup) return game_ready_startup.reserve_restore(second)
		if("restart_ticket")
			return game_ready_startup.restart_ticket(first)
		if("claim_load")
			return game_ready_startup.claim_load(first, second, third, fourth)
		if("load_failed")
			return game_ready_startup.load_failed(first, second)
		if("loaded")
			return game_ready_startup.loaded(first, second, third, fourth, fifth, sixth)
		if("restart_failed")
			return game_ready_startup.restart_failed(first)
		if("restart_completed")
			return game_ready_startup.restart_completed(first, second)
	return null
