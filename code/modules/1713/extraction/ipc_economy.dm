// Offline economic projections reuse the production conservation journal.
// The adapter must be explicitly wired; constructing it does not enable IPC.
/datum/extraction_ipc_economy
	var/datum/extraction_service/game
	var/datum/extraction_equipment_codec/codec = new
	var/blocked = FALSE
	var/last_error
	New(datum/extraction_service/service)
		..()
		game = service
	proc/ready()
		if (blocked || !game || !game.settlement_ready()) return FALSE
		for (var/owner in list("extractionvendor", "extractionmarket"))
			var/list/account = game.store.load_profile(owner)
			if (!islist(account)) return FALSE
			if (account["revision"] == 0)
				account["level"] = 4
				account["economy_system"] = owner
				account["credits"] = owner == "extractionvendor" ? 1000000 : 0
				if (owner == "extractionmarket") account["listings"] = list()
				if (!game.store.commit_profile(owner, account))
					blocked = TRUE
					return FALSE
			if (account["economy_system"] != owner || account["state"] != "home" || account["level"] != 4 || game.sessions[owner])
				blocked = TRUE
				return FALSE
		return TRUE
	proc/wallet(list/account)
		return isnull(account["credits"]) ? 0 : account["credits"]
	proc/session_busy(owner)
		return !!game?.sessions[owner]
	proc/account(owner)
		if (!ready() || game.sessions[owner]) return null
		var/list/result = game.store.load_profile(owner)
		if (!islist(result) || result["state"] != "home" || !game.insurance_profile_valid(result)) return null
		return result
	proc/eligible(list/entry, require_fir = FALSE)
		if (!islist(entry) || entry["secure"] || !islist(entry["equipment"]) || entry["equipment"]["schema"] != 2 || !codec.validate(entry["equipment"])) return FALSE
		var/list/nodes = entry["equipment"]["nodes"]
		if (require_fir && !nodes[1]["found_in_raid"]) return FALSE
		for (var/list/node in nodes)
			if (node["insurance_token"]) return FALSE
		return length(json_encode(entry["equipment"])) <= 32768
	proc/price(list/entry)
		if (!eligible(entry)) return 0
		var/list/root = entry["equipment"]["nodes"][1]
		var/list/table = list("/obj/item/extraction_salvage" = 10, "/obj/item/weapon/gun/projectile/submachinegun/ak47" = 60, "/obj/item/weapon/gun/projectile/pistol/m9beretta" = 40, "/obj/item/ammo_magazine/ak47" = 10, "/obj/item/ammo_magazine/m9beretta" = 5, "/obj/item/clothing/head/helmet/modern/pasgt" = 25, "/obj/item/clothing/accessory/armor/nomads/pcarrierblack" = 40, "/obj/item/weapon/material/handle" = 5, "/obj/item/weapon/material/part/pickaxe" = 10, "/obj/item/weapon/material/part/shovel" = 10, "/obj/item/weapon/material/part/axehead/hatchet" = 10)
		var/value = table[root["type"]]
		if (root["type"] in list("/obj/item/stack/material/wood", "/obj/item/stack/material/cloth", "/obj/item/stack/material/rope", "/obj/item/stack/material/steel")) value = root["scalars"]["amount"]
		if (!isnum(value) || value <= 0 || value > 1000000) return 0
		var/list/scalars = root["scalars"]
		if (isnum(scalars["health"]) && isnum(scalars["maxhealth"]) && scalars["maxhealth"] > 0)
			value = round(value * min(1, max(0, scalars["health"] / scalars["maxhealth"])))
		return value
	proc/selected(list/account, list/ids, require_fir = FALSE)
		if (!islist(ids) || !length(ids) || length(ids) > 16) return null
		var/list/results = list()
		for (var/id in ids)
			var/list/found
			for (var/list/entry in account["stash"])
				if (entry["id"] == id) found = entry
			if (!eligible(found, require_fir)) return null
			results += list(found)
		return results
	proc/graph_digests(list/entries)
		var/list/results = list()
		for (var/list/entry in entries)
			var/digest = extraction_sha256(json_encode(entry["equipment"]))
			if (!istext(digest)) return null
			results[entry["id"]] = digest
		return results
	proc/receipt(datum/extraction_ipc_service/ipc, owner, request_id, digest)
		if (!ready()) return list("status" = "pending", "reason" = "account_recovery_required", "data" = list("code" = "recovery_required"))
		var/list/account = game.store.load_profile(owner)
		var/list/receipt = account?["bot_receipts"]?[extraction_sha256(request_id)]
		if (!islist(receipt) || receipt["discord_id"] != ipc.profile["owners"][owner] || receipt["request_digest"] != digest) return null
		return json_decode(json_encode(receipt))
	proc/process(datum/extraction_ipc_service/ipc, list/request, list/candidate, now_text, owner)
		if (!ready()) return ipc.response(request, "pending", "account_recovery_required")
		var/list/previous = receipt(ipc, owner, request["request_id"], request["request_digest"])
		if (islist(previous))
			previous["account_receipt"] = TRUE
			return previous
		if (game.sessions[owner]) return ipc.response(request, "rejected", "account_busy")
		var/list/current = game.store.load_profile(owner)
		if (!islist(current)) return ipc.response(request, "pending", "account_recovery_required")
		if (islist(current["bot_receipts"]) && current["bot_receipts"][extraction_sha256(request["request_id"])]) return ipc.response(request, "rejected", "request_id_conflict")
		if (current["state"] != "home") return ipc.response(request, "rejected", "account_in_raid")
		if (!isnull(request["expected_account_revision"]) && request["expected_account_revision"] != current["revision"]) return ipc.response(request, "rejected", "stale_revision")
		if (request["action"] == "market.browse") return market_catalog(ipc, request, current)
		if (request["action"] == "insurance.inspect") return insurance_inspect(ipc, request, owner)
		if (request["action"] == "room.quote") return room_quote(ipc, request, candidate, current, now_text)
		if (request["action"] == "room.manage") return room_confirm(ipc, request, candidate, current, now_text)
		if (request["action"] == "trade.quote") return quote(ipc, request, candidate, current, now_text)
		if (request["action"] in list("trade.confirm", "market.list", "market.buy", "market.cancel")) return confirm(ipc, request, candidate, current, now_text)
		return null
	proc/insurance_inspect(datum/extraction_ipc_service/ipc, list/request, owner)
		var/datum/extraction_insurance_returns/gate = game.insurance_gate
		if (!gate) gate = new(game, codec)
		var/datum/extraction_session/S = game.open(owner)
		if (!S) return ipc.response(request, "pending", "account_recovery_required")
		var/list/data = S.inspect_insurance_mail(request["payload"]["cursor"])
		var/datum/extraction_mail_store/mail = game.mail_service()
		var/reason = mail.last_error
		S.close()
		if (!data)
			if (reason in list("stale_cursor", "invalid_cursor")) return ipc.response(request, "rejected", reason)
			return ipc.response(request, "pending", "account_recovery_required")
		return ipc.response(request, "committed", "insurance_snapshot", data)
	proc/market_catalog(datum/extraction_ipc_service/ipc, list/request, list/current)
		var/list/market = account("extractionmarket")
		if (!islist(market)) return ipc.response(request, "pending", "account_recovery_required")
		var/list/active = list()
		for (var/id in market["listings"])
			if (market["listings"][id]["state"] == "active") active += id
		var/page = request["payload"]["page"]
		var/start = page * 8 + 1
		var/list/listings = list()
		for (var/i = start, i <= min(start + 7, length(active)), i++)
			var/id = active[i]
			var/list/listing = market["listings"][id]
			var/list/entries = selected(market, listing["item_ids"])
			if (!islist(entries) || json_encode(graph_digests(entries)) != json_encode(listing["graph_digests"])) return ipc.response(request, "pending", "account_recovery_required")
			var/list/roots = list()
			for (var/list/entry in entries) roots += list(extraction_ipc_root_projection(entry))
			listings += list(list("listing_id" = id, "listing_revision" = listing["revision"], "price" = list("currency_id" = "civ13.game_credits.v1", "amount" = listing["price"]), "item_ids" = listing["item_ids"], "item_count" = length(entries), "roots" = roots))
		return ipc.response(request, "committed", "market_catalog", list("account_revision" = current["revision"], "page" = page, "next_page" = start + 8 <= length(active) ? page + 1 : null, "listings" = listings))
	proc/room_parts(list/current, list/ids)
		var/list/entries = selected(current, ids)
		if (!islist(entries) || current["level"] >= 4 || length(entries) != current["level"] * 5) return null
		for (var/list/entry in entries)
			if (!entry["salvage"] || length(entry["equipment"]["nodes"]) != 1 || entry["equipment"]["nodes"][1]["type"] != "/obj/item/extraction_salvage") return null
		return entries
	proc/room_quote(datum/extraction_ipc_service/ipc, list/request, list/candidate, list/current, now_text)
		var/list/ids = request["payload"]["item_ids"]
		var/list/entries = room_parts(current, ids)
		if (!islist(entries)) return ipc.response(request, "rejected", "upgrade_parts_unavailable")
		var/list/record = list("quote_id" = extraction_sha256("roomquote\n[request["request_id"]]\n[request["request_digest"]]"), "action" = "room.manage", "discord_id" = request["discord_id"], "owner" = current["owner"], "revision" = current["revision"], "account_digest" = md5(json_encode(current)), "expires_at" = extraction_ipc_after(now_text, 120), "item_ids" = ids, "graph_digests" = graph_digests(entries), "current_level" = current["level"], "target_level" = current["level"] + 1, "required_parts" = length(entries), "operation" = "upgrade")
		var/list/quotes = candidate["quotes"]
		for (var/old_token in quotes.Copy())
			if (extraction_ipc_elapsed(extraction_ipc_time(now_text), extraction_ipc_time(quotes[old_token]["expires_at"])) > 0) quotes.Remove(old_token)
		if (length(quotes) >= 64) return ipc.response(request, "pending", "journal_capacity")
		var/token = extraction_hmac_sha256(ipc.key, "civ13.safehouse.quote.v1\n[json_encode(record)]")
		quotes[token] = record
		return ipc.response(request, "committed", "quote_created", list("quote_id" = record["quote_id"], "confirmation_token" = token, "confirm_action" = "room.manage", "expected_account_revision" = current["revision"], "expires_at" = record["expires_at"], "operation" = "upgrade", "current_level" = current["level"], "target_level" = current["level"] + 1, "required_parts" = length(entries), "item_ids" = ids))
	proc/room_confirm(datum/extraction_ipc_service/ipc, list/request, list/candidate, list/current, now_text)
		var/token = request["payload"]["confirmation_token"]
		var/list/record = candidate["quotes"][token]
		if (!islist(record) || !extraction_ipc_equal(token, extraction_hmac_sha256(ipc.key, "civ13.safehouse.quote.v1\n[json_encode(record)]")) || record["owner"] != current["owner"] || record["discord_id"] != request["discord_id"]) return ipc.response(request, "rejected", "token_invalid")
		if (record["action"] != "room.manage") return ipc.response(request, "rejected", "quote_action_mismatch")
		if (extraction_ipc_elapsed(extraction_ipc_time(now_text), extraction_ipc_time(record["expires_at"])) >= 0) return ipc.response(request, "rejected", "quote_expired")
		if (record["revision"] != current["revision"] || record["account_digest"] != md5(json_encode(current))) return ipc.response(request, "rejected", "stale_revision")
		var/list/entries = room_parts(current, record["item_ids"])
		if (!islist(entries) || json_encode(graph_digests(entries)) != json_encode(record["graph_digests"])) return ipc.response(request, "rejected", "invalid_graph")
		var/datum/extraction_session/planner = new
		planner.profile = current
		var/list/after = planner.plan_upgrade(record["item_ids"], FALSE)
		if (!islist(after)) return ipc.response(request, "rejected", "upgrade_parts_unavailable")
		if (!islist(after["bot_receipts"])) after["bot_receipts"] = list()
		if (length(after["bot_receipts"]) >= 256) return ipc.response(request, "pending", "journal_capacity")
		var/list/result = ipc.response(request, "committed", "room_upgrade_committed", list("quote_id" = record["quote_id"], "account_revision" = current["revision"] + 1, "level" = after["level"], "required_parts" = record["required_parts"], "item_ids" = record["item_ids"]))
		after["bot_receipts"][extraction_sha256(request["request_id"])] = json_decode(json_encode(result))
		if (!game.store.commit_profile(current["owner"], after)) result = ipc.response(request, "pending", "account_recovery_required")
		result["account_receipt"] = TRUE
		return result
	proc/quote(datum/extraction_ipc_service/ipc, list/request, list/candidate, list/current, now_text)
		var/list/payload = request["payload"]
		var/kind = payload["sale_kind"]
		var/list/entries
		var/list/escrow
		var/list/listing
		var/list/counterparty
		var/amount = 0
		var/action
		if (kind in list("server_buyback", "player_listing"))
			entries = selected(current, payload["item_ids"], kind == "player_listing")
			if (!islist(entries)) return ipc.response(request, "rejected", "item_ineligible")
			for (var/list/entry in entries)
				var/value = price(entry)
				if (!value) return ipc.response(request, "rejected", "pricing_unavailable")
				amount += value
			if (kind == "player_listing")
				amount *= 2
				action = "market.list"
			else
				action = "trade.confirm"
				counterparty = account("extractionvendor")
		else
			escrow = account("extractionmarket")
			listing = escrow?["listings"]?[payload["listing_id"]]
			if (!islist(listing) || listing["state"] != "active") return ipc.response(request, "rejected", "listing_unavailable")
			entries = selected(escrow, listing["item_ids"])
			if (!islist(entries) || json_encode(graph_digests(entries)) != json_encode(listing["graph_digests"])) return ipc.response(request, "pending", "account_recovery_required")
			if (kind == "listing_cancel")
				if (listing["owner"] != current["owner"]) return ipc.response(request, "rejected", "item_not_owned")
				action = "market.cancel"
			else
				if (listing["owner"] == current["owner"]) return ipc.response(request, "rejected", "self_purchase")
				counterparty = account(listing["owner"])
				if (!islist(counterparty)) return ipc.response(request, "rejected", "account_busy")
				amount = listing["price"]
				action = "market.buy"
		if (!isnum(amount) || amount < 0 || amount > 1000000) return ipc.response(request, "rejected", "pricing_unavailable")
		var/list/ids = list()
		for (var/list/entry in entries) ids += entry["id"]
		var/list/record = list("quote_id" = extraction_sha256("quote\n[request["request_id"]]\n[request["request_digest"]]"), "action" = action, "discord_id" = request["discord_id"], "owner" = current["owner"], "revision" = current["revision"], "account_digest" = md5(json_encode(current)), "expires_at" = extraction_ipc_after(now_text, 120), "price" = amount, "item_ids" = ids, "graph_digests" = graph_digests(entries), "table_id" = "modern_safehouse_prices_v1")
		if (islist(listing))
			record["listing_id"] = payload["listing_id"]
			record["listing_revision"] = listing["revision"]
		if (islist(counterparty))
			record["counterparty"] = counterparty["owner"]
			record["counterparty_revision"] = counterparty["revision"]
		var/token = extraction_hmac_sha256(ipc.key, "civ13.safehouse.quote.v1\n[json_encode(record)]")
		var/list/quotes = candidate["quotes"]
		for (var/old_token in quotes.Copy())
			var/list/old = quotes[old_token]
			if (extraction_ipc_elapsed(extraction_ipc_time(now_text), extraction_ipc_time(old["expires_at"])) > 0) quotes.Remove(old_token)
		if (length(quotes) >= 64) return ipc.response(request, "pending", "journal_capacity")
		quotes[token] = record
		var/list/data = list("quote_id" = record["quote_id"], "confirmation_token" = token, "confirm_action" = action, "expected_account_revision" = current["revision"], "expires_at" = record["expires_at"], "price" = list("currency_id" = "civ13.game_credits.v1", "amount" = amount), "table_id" = record["table_id"], "item_ids" = ids)
		if (islist(listing))
			data["listing_id"] = record["listing_id"]
			data["listing_revision"] = record["listing_revision"]
		return ipc.response(request, "committed", "quote_created", data)
	proc/confirm(datum/extraction_ipc_service/ipc, list/request, list/candidate, list/current, now_text)
		var/token = request["payload"]["confirmation_token"]
		var/list/record = candidate["quotes"][token]
		if (!islist(record) || !extraction_ipc_equal(token, extraction_hmac_sha256(ipc.key, "civ13.safehouse.quote.v1\n[json_encode(record)]"))) return ipc.response(request, "rejected", "token_invalid")
		if (record["discord_id"] != request["discord_id"] || record["owner"] != current["owner"]) return ipc.response(request, "rejected", "token_invalid")
		if (record["action"] != request["action"]) return ipc.response(request, "rejected", "quote_action_mismatch")
		if (islist(current["bot_receipts"]))
			for (var/id in current["bot_receipts"])
				var/list/previous = current["bot_receipts"][id]
				if (previous?["data"]?["quote_id"] == record["quote_id"]) return ipc.response(request, "rejected", "token_used")
		if (extraction_ipc_elapsed(extraction_ipc_time(now_text), extraction_ipc_time(record["expires_at"])) >= 0) return ipc.response(request, "rejected", "quote_expired")
		if (record["revision"] != current["revision"] || record["account_digest"] != md5(json_encode(current))) return ipc.response(request, "rejected", "stale_revision")
		var/action = request["action"]
		var/list/source = current
		var/list/destination
		var/list/seller
		var/list/listing
		if (action == "trade.confirm") destination = account("extractionvendor")
		else if (action == "market.list") destination = account("extractionmarket")
		else
			source = account("extractionmarket")
			listing = source?["listings"]?[record["listing_id"]]
			if (!islist(listing) || listing["state"] != "active" || listing["revision"] != record["listing_revision"]) return ipc.response(request, "rejected", "listing_unavailable")
			destination = current
			if (action == "market.cancel" && listing["owner"] != current["owner"]) return ipc.response(request, "rejected", "item_not_owned")
			if (action == "market.buy")
				if (listing["owner"] == current["owner"]) return ipc.response(request, "rejected", "self_purchase")
				seller = account(listing["owner"])
		if (!islist(source) || !islist(destination) || (action == "market.buy" && !islist(seller))) return ipc.response(request, "rejected", "account_busy")
		var/list/counterparty = action == "trade.confirm" ? destination : seller
		if (islist(counterparty) && (record["counterparty"] != counterparty["owner"] || record["counterparty_revision"] != counterparty["revision"])) return ipc.response(request, "rejected", "stale_revision")
		var/list/entries = selected(source, record["item_ids"], action == "market.list")
		if (!islist(entries) || json_encode(graph_digests(entries)) != json_encode(record["graph_digests"])) return ipc.response(request, "rejected", "invalid_graph")
		var/amount = record["price"]
		if (!isnum(amount) || amount < 0 || amount > 1000000 || round(amount) != amount) return ipc.response(request, "rejected", "pricing_unavailable")
		if ((action == "trade.confirm" && wallet(destination) < amount) || (action == "market.buy" && wallet(current) < amount)) return ipc.response(request, "rejected", "insufficient_funds")
		if ((action == "trade.confirm" && wallet(current) + amount > 1000000) || (action == "market.buy" && wallet(seller) + amount > 1000000)) return ipc.response(request, "rejected", "capacity_exceeded")
		if (length(destination["stash"]) + length(entries) > destination["level"] * 16) return ipc.response(request, "rejected", "capacity_exceeded")
		var/list/parts = list()
		var/list/after_by_owner = list()
		var/list/accounts = list(source, destination)
		if (islist(seller)) accounts += list(seller)
		for (var/list/before in accounts)
			var/list/after = json_decode(json_encode(before))
			after["revision"]++
			after_by_owner[before["owner"]] = after
			parts += list(list("owner" = before["owner"], "before" = before, "after" = after))
		var/list/source_after = after_by_owner[source["owner"]]
		var/list/destination_after = after_by_owner[destination["owner"]]
		var/list/actor_after = after_by_owner[current["owner"]]
		for (var/list/entry in source_after["stash"].Copy())
			if (entry["id"] in record["item_ids"])
				source_after["stash"] -= list(entry)
				destination_after["stash"] += list(entry)
		if (action == "trade.confirm")
			actor_after["credits"] = wallet(current) + amount
			destination_after["credits"] = wallet(destination) - amount
		else if (action == "market.buy")
			actor_after["credits"] = wallet(current) - amount
			var/list/seller_after = after_by_owner[seller["owner"]]
			seller_after["credits"] = wallet(seller) + amount
		var/list/data = list("quote_id" = record["quote_id"], "account_revision" = actor_after["revision"], "item_ids" = record["item_ids"], "price" = list("currency_id" = "civ13.game_credits.v1", "amount" = amount))
		if (action == "market.list")
			if (!islist(destination_after["listings"]) || length(destination_after["listings"]) >= 128) return ipc.response(request, "pending", "journal_capacity")
			var/listing_id = extraction_sha256("listing\n[record["quote_id"]]")
			destination_after["listings"][listing_id] = list("owner" = current["owner"], "state" = "active", "revision" = 1, "price" = amount, "item_ids" = record["item_ids"], "graph_digests" = record["graph_digests"])
			data["listing_id"] = listing_id
			data["listing_revision"] = 1
		else if (islist(listing))
			var/list/closed_listing = source_after["listings"][record["listing_id"]]
			closed_listing["state"] = action == "market.buy" ? "sold" : "cancelled"
			closed_listing["revision"]++
			data["listing_id"] = record["listing_id"]
			data["listing_revision"] = closed_listing["revision"]
		if (!islist(actor_after["bot_receipts"])) actor_after["bot_receipts"] = list()
		if (length(actor_after["bot_receipts"]) >= 256) return ipc.response(request, "pending", "journal_capacity")
		var/list/result = ipc.response(request, "committed", "economic_settlement_committed", data)
		actor_after["bot_receipts"][extraction_sha256(request["request_id"])] = json_decode(json_encode(result))
		if (!game.settlement.submit(game.settlement.profile["sequence"] + 1, parts)) result = ipc.response(request, "pending", "account_recovery_required")
		result["account_receipt"] = TRUE
		return result
