// Private service adapter, disabled by default. Never owns a live game session.
// The authenticated game UI is the only caller allowed to issue a challenge.
/datum/extraction_ipc_service
	var/enabled = FALSE
	var/tmp/key
	var/datum/extraction_account_store/accounts
	var/datum/extraction_account_store/journal = new
	var/list/profile
	var/blocked = FALSE
	var/busy = FALSE
	var/test_fail_at
	var/last_error
	var/datum/economic_adapter
	New(datum/extraction_account_store/store)
		..()
		accounts = store
	proc/ready()
		if (!enabled || blocked || busy || !accounts || !istext(key) || length(key) < 32 || length(key) > 4096 || !islist(extraction_crypto_bytes(key))) return FALSE
		if (!profile)
			journal.root = "[accounts.root]_bot/"
			profile = journal.load_profile("world")
			if (!profile)
				blocked = TRUE
				return FALSE
			if (!profile["links"]) profile["links"] = list()
			if (!profile["owners"]) profile["owners"] = list()
			if (!profile["challenges"]) profile["challenges"] = list()
			if (!profile["receipts"]) profile["receipts"] = list()
			if (!profile["quotes"]) profile["quotes"] = list()
		if (!valid_state(profile))
			blocked = TRUE
			return FALSE
		return TRUE
	proc/valid_state(list/state)
		if (!journal.valid_profile(state, "world")) return FALSE
		var/list/links = state["links"], owners = state["owners"], challenges = state["challenges"], receipts = state["receipts"]
		if (!islist(links) || !islist(owners) || length(links) > 1000 || length(owners) != length(links) || !islist(challenges) || length(challenges) > 64 || !islist(receipts) || length(receipts) > 1000) return FALSE
		if (!islist(state["quotes"]) || length(state["quotes"]) > 64) return FALSE
		for (var/token in state["quotes"])
			var/list/quote = state["quotes"][token]
			if (!islist(quote) || !extraction_ipc_identifier(token, FALSE, 64) || length(token) != 64 || !accounts.valid_owner(quote["owner"]) || !extraction_ipc_identifier(quote["discord_id"], TRUE, 22) || !(quote["action"] in list("trade.confirm", "market.list", "market.buy", "market.cancel", "room.manage")) || !islist(extraction_ipc_time(quote["expires_at"])) || !islist(quote["item_ids"]) || length(quote["item_ids"]) < 1 || length(quote["item_ids"]) > 16 || !islist(quote["graph_digests"]) || length(quote["graph_digests"]) != length(quote["item_ids"]) || !extraction_ipc_equal(token, extraction_hmac_sha256(key, "civ13.safehouse.quote.v1\n[json_encode(quote)]"))) return FALSE
		for (var/actor in links)
			var/owner = links[actor]
			if (!extraction_ipc_identifier(actor, TRUE, 22) || !accounts.valid_owner(owner) || owners[owner] != actor) return FALSE
		for (var/id in challenges)
			var/list/challenge = challenges[id]
			if (!islist(challenge) || !accounts.valid_owner(challenge["owner"]) || !extraction_ipc_identifier(id, FALSE, 64) || length(id) != 64 || !extraction_ipc_identifier(challenge["proof_digest"], FALSE, 64) || length(challenge["proof_digest"]) != 64 || !islist(extraction_ipc_time(challenge["expires"])) || !(challenge["used"] in list(FALSE, TRUE))) return FALSE
		for (var/id in receipts)
			var/list/receipt = receipts[id]
			if (!islist(receipt) || !islist(receipt["response"]) || !extraction_ipc_identifier(receipt["request_digest"], FALSE, 64) || length(receipt["request_digest"]) != 64 || !extraction_ipc_identifier(receipt["discord_id"], TRUE, 22) || extraction_sha256(receipt["request_id"]) != id) return FALSE
			var/list/result = receipt["response"]
			if (result["protocol"] != "civ13.safehouse.v1" || result["request_id"] != receipt["request_id"] || result["discord_id"] != receipt["discord_id"] || result["request_digest"] != receipt["request_digest"] || !(result["status"] in list("committed", "rejected")) || !islist(result["data"])) return FALSE
		return TRUE
	proc/commit(list/candidate)
		if (!ready() || !valid_state(candidate)) return FALSE
		busy = TRUE
		journal.test_fail_at = test_fail_at
		var/success = journal.commit_profile("world", candidate)
		busy = FALSE
		if (!success)
			blocked = TRUE
			last_error = journal.last_error
			return FALSE
		profile = candidate
		return TRUE
	proc/response(list/request, status, reason, list/data)
		if (!islist(data)) data = list()
		if (status != "committed")
			var/list/codes = list("unlinked_actor" = "unlinked", "account_busy" = "busy", "account_in_raid" = "in_raid", "request_id_conflict" = "request_conflict", "quote_action_mismatch" = "action_mismatch", "account_recovery_required" = "recovery_required", "journal_recovery_required" = "recovery_required", "journal_capacity" = "recovery_required")
			data["code"] = codes[reason] ? codes[reason] : reason
		return list("protocol" = request["protocol"], "request_id" = request["request_id"], "discord_id" = request["discord_id"], "action" = request["action"], "request_digest" = request["request_digest"], "status" = status, "reason" = reason, "data" = data)
	// Expiry supplied by the trusted game clock adapter, not the bot request.
	proc/issue_challenge(owner, now_text, expires_text)
		if (!ready() || !accounts.valid_owner(owner)) return null
		if (isnull(now_text)) now_text = extraction_ipc_now()
		if (isnull(expires_text)) expires_text = extraction_ipc_after(now_text, 300)
		var/list/now = extraction_ipc_time(now_text)
		var/list/expires = extraction_ipc_time(expires_text)
		if (!islist(now) || !islist(expires) || extraction_ipc_elapsed(expires, now) != 300) return null
		var/list/candidate = json_decode(json_encode(profile))
		var/list/challenges = candidate["challenges"]
		for (var/id in challenges.Copy())
			var/list/challenge = challenges[id]
			if (challenge["used"] || extraction_ipc_elapsed(now, extraction_ipc_time(challenge["expires"])) > 0) challenges.Remove(id)
		if (length(challenges) >= 64 || candidate["owners"][owner]) return null
		var/proof = extraction_hmac_sha256(key, "civ13.safehouse.link.proof\n[owner]\n[profile["revision"]]\n[now_text]")
		var/id = extraction_sha256("civ13.safehouse.link.id\n[proof]")
		challenges[id] = list("owner" = owner, "proof_digest" = extraction_sha256(proof), "expires" = expires_text, "used" = FALSE)
		if (!commit(candidate)) return null
		return list("challenge_id" = id, "proof" = proof, "expires" = expires_text)
	proc/process_wire(wire, now_text)
		if (!ready()) return null
		if (isnull(now_text)) now_text = extraction_ipc_now()
		var/list/request = extraction_ipc_request(extraction_ipc_verify(wire, key, now_text))
		if (!islist(request)) return null
		var/id = extraction_sha256(request["request_id"])
		var/list/previous = profile["receipts"][id]
		if (islist(previous))
			if (previous["discord_id"] != request["discord_id"] || previous["request_digest"] != request["request_digest"]) return response(request, "rejected", "request_id_conflict")
			return json_decode(json_encode(previous["response"]))
		var/linked_owner = profile["links"][request["discord_id"]]
		if (linked_owner && economic_adapter)
			var/list/economic_receipt = call(economic_adapter, "receipt")(src, linked_owner, request["request_id"], request["request_digest"])
			if (islist(economic_receipt) && economic_receipt["status"] == "committed") return economic_receipt
		if (length(profile["receipts"]) >= 1000) return response(request, "pending", "journal_capacity")
		var/list/candidate = json_decode(json_encode(profile))
		var/list/payload = request["payload"]
		var/actor = request["discord_id"]
		var/action = request["action"]
		var/owner = candidate["links"][actor]
		var/list/result = response(request, "rejected", "unlinked_actor")
		if (action in list("link.challenge", "link.complete"))
			var/list/challenge = candidate["challenges"][payload["challenge_id"]]
			result = response(request, "rejected", "invalid_challenge")
			if (islist(challenge) && !challenge["used"] && extraction_ipc_elapsed(extraction_ipc_time(challenge["expires"]), extraction_ipc_time(now_text)) >= 0)
				if (action == "link.challenge")
					result = response(request, "committed", "challenge_available", list("challenge_id" = payload["challenge_id"], "expires" = challenge["expires"]))
				else if (extraction_ipc_equal(extraction_sha256(payload["proof"]), challenge["proof_digest"]) && !owner && !candidate["owners"][challenge["owner"]])
					candidate["links"][actor] = challenge["owner"]
					candidate["owners"][challenge["owner"]] = actor
					challenge["used"] = TRUE
					result = response(request, "committed", "account_linked")
		else if (owner)
			if (action == "trade.status" && payload["operation_request_id"])
				var/list/original = candidate["receipts"][extraction_sha256(payload["operation_request_id"])]
				if (!islist(original) && economic_adapter)
					var/list/operation = call(economic_adapter, "receipt")(src, owner, payload["operation_request_id"], payload["operation_request_digest"])
					if (islist(operation)) original = list("discord_id" = actor, "request_digest" = payload["operation_request_digest"], "response" = operation)
				if (islist(original) && original["discord_id"] == actor && original["request_digest"] == payload["operation_request_digest"])
					var/list/operation = original["response"]
					result = response(request, "committed", "operation_status", list("operation_status" = operation["status"], "operation_receipt" = operation["status"] == "pending" ? null : operation))
				else result = response(request, "committed", "operation_not_found", list("operation_status" = "not_found", "operation_receipt" = null))
			else if (action in list("stash.inspect", "stash.detail", "room.inspect"))
				var/list/account = accounts.load_profile(owner)
				if ((economic_adapter && !call(economic_adapter, "ready")()) || !islist(account)) result = response(request, "pending", "account_recovery_required")
				else if (economic_adapter && call(economic_adapter, "session_busy")(owner)) result = response(request, "rejected", "account_busy")
				else if (account["state"] != "home") result = response(request, "rejected", "account_in_raid")
				else if (!isnull(request["expected_account_revision"]) && request["expected_account_revision"] != account["revision"]) result = response(request, "rejected", "stale_revision")
				else if (action == "stash.detail")
					var/list/detail = extraction_ipc_detail_projection(account, payload["item_id"], payload["page"])
					result = islist(detail) ? response(request, "committed", "saved_detail", detail) : response(request, "rejected", "item_unavailable")
				else
					var/list/entries = list()
					var/start = payload["page"] * 8 + 1
					var/list/stash = account["stash"]
					for (var/i = start, i <= min(start + 7, length(stash)), i++)
						var/list/item = stash[i]
						entries += list(extraction_ipc_root_projection(item))
					result = response(request, "committed", "saved_snapshot", list("revision" = account["revision"], "level" = account["level"], "capacity" = account["level"] * 16, "state" = account["state"], "page" = payload["page"], "items" = entries))
			else if (economic_adapter)
				result = call(economic_adapter, "process")(src, request, candidate, now_text, owner)
				if (!islist(result)) result = response(request, "rejected", "action_not_available")
			else result = response(request, "rejected", "action_not_available")
		// Link changes and their idempotent receipt commit in the same snapshot.
		if (length(extraction_crypto_bytes(json_encode(result))) > 8192) result = response(request, "rejected", "response_too_large")
		if (result["account_receipt"])
			result.Remove("account_receipt")
			return result
		if (result["status"] == "pending") return result
		candidate["receipts"][id] = list("request_id" = request["request_id"], "request_digest" = request["request_digest"], "discord_id" = actor, "response" = result)
		if (!commit(candidate)) return response(request, "pending", "journal_recovery_required")
		return result
	// Read-only recovery for an already authenticated immutable request. It does
	// not authorize execution of an expired request or create another quote.
	proc/durable_response(list/request)
		if (!ready() || !islist(request)) return null
		var/list/receipt = profile["receipts"][extraction_sha256(request["request_id"])]
		if (islist(receipt))
			if (receipt["discord_id"] != request["discord_id"] || receipt["request_digest"] != request["request_digest"]) return null
			return json_decode(json_encode(receipt["response"]))
		var/owner = profile["links"][request["discord_id"]]
		if (!owner || !economic_adapter) return null
		var/list/result = call(economic_adapter, "receipt")(src, owner, request["request_id"], request["request_digest"])
		return islist(result) && result["status"] == "committed" ? result : null
