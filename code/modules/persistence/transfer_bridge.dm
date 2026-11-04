// Bridge between world saves and the region's transfer agent
// (tools/transfer_storage/agent.py, design in
// tools/server-management/TRANSFER-STORAGE-SQLITE.md).
//
// Off unless config/transfer_agent.json names a loopback port and token file.
// Transfer effects (escrow removal, import credit, return) are applied only
// after the agent records them as tentative; the world save lists the applied
// effects so a committed save confirms them and a crash voids the rest.

var/global/datum/transfer_bridge/transfer_bridge = new

/datum/transfer_bridge
	var/port = 0
	var/token = null
	// Ledger sequence the agent last acknowledged; null until the loaded
	// world has been reconciled, and no effect may be applied before that.
	var/ledger_base = null
	// Effect ids applied in memory since ledger_base was acknowledged.
	var/list/applied = list()
	// The transfer capture of the loaded save, repeated by saves made before
	// reconciliation succeeds (no effect can happen in between).
	var/list/loaded_capture = null
	var/hold_reason = null
	var/reconcile_pending = FALSE

/datum/transfer_bridge/New()
	..()
	if(!fexists("config/transfer_agent.json")) return
	var/list/settings
	try
		settings = json_decode(file2text("config/transfer_agent.json"))
	catch
		world.log << "Transfer bridge: config/transfer_agent.json is not valid JSON; transfers stay off."
		return
	if(!islist(settings) || !isnum(settings["port"]) || settings["port"] < 1024 || settings["port"] > 65535 || !istext(settings["token_file"]))
		world.log << "Transfer bridge: config/transfer_agent.json needs a port and token_file; transfers stay off."
		return
	var/secret = fexists(settings["token_file"]) ? trim(file2text(settings["token_file"])) : null
	if(!istext(secret) || length(secret) < 32)
		world.log << "Transfer bridge: the token file is missing or shorter than 32 characters; transfers stay off."
		return
	port = settings["port"]
	token = secret

/datum/transfer_bridge/proc/enabled()
	return port && token

/datum/transfer_bridge/proc/ready()
	return enabled() && !isnull(ledger_base) && !hold_reason

// One request to the agent. Returns the decoded answer, or null when the agent
// cannot be reached within five seconds.
/datum/transfer_bridge/proc/request(path, list/body)
	if(!enabled()) return null
	var/datum/http_request/R = new
	R.prepare(RUSTG_HTTP_METHOD_POST, "http://127.0.0.1:[port][path]", json_encode(body || list()), list("Content-Type" = "application/json", "X-Transfer-Token" = token))
	R.begin_async()
	var/deadline = world.timeofday + 50
	while(!R.is_complete())
		if(world.timeofday > deadline || world.timeofday < deadline - 100) return null
		sleep(1)
	var/datum/http_response/response = R.into_response()
	if(response.error || !istext(response.body)) return null
	var/list/answer
	try
		answer = json_decode(response.body)
	catch
		return null
	if(!islist(answer)) return null
	if(answer["held"]) hold_reason = answer["error"]
	return answer

// -- world effects ---------------------------------------------------------

// Each returns the agent's result list, or null when the effect must not be
// applied. Callers change the world only after a non-null result, and must
// not sleep between the call and the world change.
/datum/transfer_bridge/proc/begin_escrow(peer, list/payloads)
	return begin_effect("/escrow", list("peer" = peer, "payloads" = payloads))

/datum/transfer_bridge/proc/begin_import(transfer_id)
	return begin_effect("/import", list("transfer_id" = transfer_id))

/datum/transfer_bridge/proc/begin_return(transfer_id)
	return begin_effect("/return", list("transfer_id" = transfer_id))

/datum/transfer_bridge/proc/begin_effect(path, list/body)
	if(!ready() || persistence_save_active()) return null
	var/list/answer = request(path, body)
	if(!answer || !answer["ok"]) return null
	var/list/result = answer["result"]
	if(!islist(result) || !istext(result["effect_id"])) return null
	// A save may have started while the request was in flight; the effect is
	// still tentative in the agent and will be voided, so refuse it here.
	if(persistence_save_active()) return null
	applied += result["effect_id"]
	return result

/datum/transfer_bridge/proc/status()
	var/list/answer = request("/status")
	return answer && answer["ok"] ? answer["result"] : null

// -- save and load hooks ---------------------------------------------------

/datum/transfer_bridge/proc/capture(generation)
	if(!enabled()) return null
	if(isnull(ledger_base))
		// Unreconciled: this save repeats the loaded save's transfer state.
		return loaded_capture ? loaded_capture.Copy() : null
	return list("generation" = generation, "effects" = applied.Copy(), "ledger_seq" = ledger_base)

/datum/transfer_bridge/proc/saved(list/capture)
	set waitfor = FALSE
	// An older base is fine: the previous save's report may still be in
	// flight or lost, and the agent skips effects it already confirmed.
	if(isnull(ledger_base) || capture["ledger_seq"] > ledger_base) return
	var/list/answer = request("/save", capture)
	var/list/result = answer && answer["ok"] ? answer["result"] : null
	if(!islist(result) || !isnum(result["ledger_seq"])) return
	ledger_base = max(ledger_base, result["ledger_seq"])
	applied -= capture["effects"]

/datum/transfer_bridge/proc/loaded(list/round_state)
	if(!enabled()) return
	ledger_base = null
	applied = list()
	var/list/capture = islist(round_state) ? round_state["transfer"] : null
	if(!valid_transfer_capture(capture))
		var/generation = islist(round_state) && istext(round_state["generation"]) ? round_state["generation"] : "unsaved"
		capture = list("generation" = generation, "effects" = list(), "ledger_seq" = 0)
	loaded_capture = capture
	if(!reconcile_pending)
		reconcile_pending = TRUE
		spawn(0)
			reconcile_loop()

// Retries until the agent answers; until then no effect can be applied.
/datum/transfer_bridge/proc/reconcile_loop()
	for(var/attempt in 1 to 1000000)
		var/list/answer = request("/load", loaded_capture)
		if(answer)
			reconcile_pending = FALSE
			var/list/result = answer["ok"] ? answer["result"] : null
			if(islist(result) && isnum(result["ledger_seq"]))
				ledger_base = result["ledger_seq"]
			else
				hold_reason = answer["error"] || "reconcile refused"
				message_admins("Transfer agent refused the loaded save: [hold_reason]. Transfers stay paused until an operator resolves it.")
			return
		sleep(600)
	reconcile_pending = FALSE

/map_storage/transfer_capture(generation)
	return transfer_bridge.capture(generation)

/map_storage/transfer_saved(list/capture)
	transfer_bridge.saved(capture)

/map_storage/transfer_loaded(list/round_state)
	transfer_bridge.loaded(round_state)
