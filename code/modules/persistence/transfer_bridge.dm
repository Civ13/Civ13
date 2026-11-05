// Bridge between world saves and the region's transfer agent
// (tools/transfer_storage/agent.py, design in
// tools/server-management/TRANSFER-STORAGE-SQLITE.md).
//
// Off unless config/transfer_agent.json names a loopback port and token file.
// Transfer effects (escrow removal, import credit, return) are applied only
// after the agent records them as tentative; the world save lists the applied
// effects so a committed save confirms them and a crash voids the rest.
// Character effects travel fast instead: the agent journals them as confirmed at
// once, and a load whose save lacks one gets it back to replay.

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
	// Regions this world may send goods to (config "peers"); the agent still
	// refuses any peer the operator has not enrolled.
	var/list/peers = list()
	var/polling = FALSE
	// Deciseconds between arrival polls (config "poll_seconds", 1-300).
	var/poll_interval = 300

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
	if(isnum(settings["poll_seconds"]) && settings["poll_seconds"] >= 1 && settings["poll_seconds"] <= 300)
		poll_interval = round(settings["poll_seconds"] * 10)
	if(islist(settings["peers"]))
		for(var/peer in settings["peers"])
			if(istext(peer) && length(peer) <= 64 && ckey(peer) == peer && !(peer in peers))
				peers += peer

/datum/transfer_bridge/proc/enabled()
	return port && token

/datum/transfer_bridge/proc/ready()
	return enabled() && !isnull(ledger_base) && !hold_reason

// One request to the agent. Returns the decoded answer, or null when the agent
// cannot be reached within five seconds.
/datum/transfer_bridge/proc/request(path, list/body)
	if(!enabled()) return null
	var/datum/http_request/R = new
	// An empty DM list encodes as a JSON array; the agent wants an object.
	var/payload = length(body) ? json_encode(body) : "{}"
	R.prepare(RUSTG_HTTP_METHOD_POST, "http://127.0.0.1:[port][path]", payload, list("Content-Type" = "application/json", "X-Transfer-Token" = token))
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
/datum/transfer_bridge/proc/begin_escrow(peer, list/payloads, fast = FALSE)
	return begin_effect("/escrow", list("peer" = peer, "payloads" = payloads, "fast" = fast ? 1 : 0))

/datum/transfer_bridge/proc/begin_import(transfer_id, fast = FALSE)
	return begin_effect("/import", list("transfer_id" = transfer_id, "fast" = fast ? 1 : 0))

/datum/transfer_bridge/proc/begin_return(transfer_id, fast = FALSE)
	return begin_effect("/return", list("transfer_id" = transfer_id, "fast" = fast ? 1 : 0))

/datum/transfer_bridge/proc/begin_effect(path, list/body)
	// The save's capture holds at most TRANSFER_CAPTURE_MAX effect ids; keep
	// room for a replay and wait for the next save to clear the list.
	if(!ready() || persistence_save_active() || length(applied) >= TRANSFER_CAPTURE_MAX / 2) return null
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
	// A resetting raid world never saves: each boot is a new map that adopts
	// the agent's ledger (region_raid_reset.dm).
	if(region_raid_resets())
		capture = list("generation" = "raid-[world.realtime]-[rand(1, 999999)]", "effects" = list(), "ledger_seq" = 0, "fresh" = 1)
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
				// A save running now must neither list replayed effects it did
				// not capture, nor capture replayed bodies under the loaded
				// generation; it reports the old generation, which the agent
				// ignores, and the replay waits for it. A load still restoring
				// the world is waited for too.
				while(persistence_active_operation || persistence_save_active())
					sleep(10)
				ledger_base = result["ledger_seq"]
				replay(result["replay"])
				if(!polling)
					polling = TRUE
					spawn(0)
						poll_loop()
			else
				hold_reason = answer["error"] || "reconcile refused"
				message_admins("Transfer agent refused the loaded save: [hold_reason]. Transfers stay paused until an operator resolves it.")
			return
		sleep(600)
	reconcile_pending = FALSE

// Applies journaled character effects that the loaded save does not hold, in
// the order they happened, and lists them for the next save. Called only when
// no world operation is running, and never sleeps, so no save sees a half-replayed world.
// Each effect is listed before its world change, like begin_effect, so a
// runtime in one cannot make the next load build it a second time.
/datum/transfer_bridge/proc/replay(list/entries)
	if(!islist(entries)) return
	var/count = 0
	for(var/list/entry in entries)
		var/effect_id = entry["effect_id"]
		if(!istext(effect_id) || (effect_id in applied) || !islist(entry["payloads"])) continue
		var/kind = entry["kind"]
		if(!(kind in list("remove", "credit", "return"))) continue
		applied += effect_id
		count++
		try
			if(kind == "remove")
				region_travel_replay_departure(entry["payloads"])
			else
				region_travel_arrive(entry["payloads"], kind == "credit", region_travel_arrival_turf(), TRUE)
		catch(var/exception/E)
			message_admins("Transfer agent: replaying [effect_id] failed: [E]. Check the arrival point.")
			log_game("Transfer agent: replaying [effect_id] failed: [E]")
	if(count)
		message_admins("Transfer agent: replayed [count] character trip effect\s the loaded save did not hold yet.")

// -- arrivals and returns ------------------------------------------------

// Imports goods that peers committed to this world, and takes back goods a peer
// refused, into the first trade post. Nothing happens without a trade post.
/datum/transfer_bridge/proc/poll_loop()
	while(enabled())
		sleep(poll_interval)
		if(ready() && !persistence_save_active())
			poll_once()

/datum/transfer_bridge/proc/poll_once()
	var/list/state = status()
	if(!islist(state) || !islist(state["pending_transfers"]) || !islist(state["active"])) return
	var/list/directions = list()
	for(var/list/row in state["active"])
		if(istext(row["transfer_id"])) directions[row["transfer_id"]] = row["direction"]
	var/list/kinds = islist(state["pending_kinds"]) ? state["pending_kinds"] : list()
	for(var/transfer_id in state["pending_transfers"])
		if(!istext(transfer_id)) continue
		var/list/transfer_kinds = kinds[transfer_id]
		if(islist(transfer_kinds) && ("character" in transfer_kinds))
			poll_character(transfer_id, directions[transfer_id] == "in")
			continue
		var/obj/structure/transfer_trade_post/post = transfer_trade_arrival_post()
		if(!post) return
		var/turf/post_turf = get_turf(post)
		var/incoming = directions[transfer_id] == "in"
		if(("[transfer_id]:[incoming ? "credit" : "return"]") in applied) continue
		var/list/result = incoming ? begin_import(transfer_id) : begin_return(transfer_id)
		if(!result) continue
		// The effect is recorded; credit it now, without sleeping.
		if(QDELETED(post)) post = transfer_trade_arrival_post() || new /obj/structure/transfer_trade_post(post_turf)
		transfer_trade_credit(post, result["payloads"], incoming)

// Travellers (region_travel.dm) arrive at a gate or a late-join point rather
// than a trade post. Nothing is imported while the world has neither.
/datum/transfer_bridge/proc/poll_character(transfer_id, incoming)
	if(("[transfer_id]:[incoming ? "credit" : "return"]") in applied) return
	var/turf/T = region_travel_arrival_turf()
	if(!T) return
	var/list/result = incoming ? begin_import(transfer_id, TRUE) : begin_return(transfer_id, TRUE)
	if(!result) return
	// The effect is recorded; build the character now, without sleeping. If the
	// arrival point went away during the request, the build picks another.
	region_travel_arrive(result["payloads"], incoming, T)

/map_storage/transfer_capture(generation)
	return transfer_bridge.capture(generation)

/map_storage/transfer_saved(list/capture)
	transfer_bridge.saved(capture)

/map_storage/transfer_loaded(list/round_state)
	transfer_bridge.loaded(round_state)
