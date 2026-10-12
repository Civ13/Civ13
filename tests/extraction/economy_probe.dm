// Boundary-only adapter: real graph projections are checked separately below.
/datum/extraction_oversized_reply_fixture
	proc/ready()
		return TRUE
	proc/receipt(datum/extraction_ipc_service/ipc, owner, id, digest)
		return null
	proc/process(datum/extraction_ipc_service/ipc, list/request, list/candidate, now_text, owner)
		var/padding = "x"
		for (var/i = 1, i <= 14, i++) padding += padding
		return ipc.response(request, "committed", "fixture_oversize", list("padding" = padding))

/proc/economy_request(actor, action, id, revision, list/payload)
	var/list/result = list("protocol" = "civ13.safehouse.v1", "request_id" = id, "discord_id" = actor, "action" = action, "expected_account_revision" = revision, "payload" = payload)
	result["request_digest"] = extraction_sha256(json_encode(result))
	return result

/proc/economy_wire(datum/extraction_ipc_service/ipc, list/request)
	var/body = extraction_ipc_base64_encode(extraction_crypto_bytes(json_encode(request)))
	var/mac = extraction_hmac_sha256(ipc.key, "civ13.safehouse.ipc.v1\nrequest\n1000\n1120\n[body]")
	return "{\"protocol\":\"civ13.safehouse.ipc.v1\",\"issued_at\":1000,\"expires_at\":1120,\"body\":\"[replacetext(body, "/", "\\/")]\",\"mac\":\"[mac]\"}"

/proc/economy_quote(datum/extraction_ipc_service/ipc, datum/extraction_ipc_economy/economy, actor, owner, id, kind, list/ids, listing_id)
	var/list/account = economy.game.store.load_profile(owner)
	var/list/payload = list("sale_kind" = kind)
	if (islist(ids)) payload["item_ids"] = ids
	else payload["listing_id"] = listing_id
	var/list/request = economy_request(actor, "trade.quote", id, account["revision"], payload)
	var/list/result = ipc.process_wire(economy_wire(ipc, request), "1000")
	equipment_assert(result["status"] == "committed" && result["reason"] == "quote_created", "native economic quote [kind]: [json_encode(result)]")
	return result["data"]

/proc/economy_confirm(datum/extraction_ipc_service/ipc, datum/extraction_ipc_economy/economy, actor, owner, id, list/quote)
	var/list/request = economy_request(actor, quote["confirm_action"], id, quote["expected_account_revision"], list("confirmation_token" = quote["confirmation_token"]))
	return ipc.process_wire(economy_wire(ipc, request), "1001")

/proc/run_economy_probe()
	var/datum/extraction_service/game = new
	game.store.root = "data/economic_accounts/"
	var/datum/extraction_ipc_service/ipc = new(game.store)
	ipc.enabled = TRUE
	ipc.key = "0123456789abcdef0123456789abcdef"
	equipment_assert(ipc.ready(), "isolated economic IPC journal")
	ipc.profile["links"]["123"] = "marketseller"
	ipc.profile["owners"]["marketseller"] = "123"
	ipc.profile["links"]["456"] = "marketbuyer"
	ipc.profile["owners"]["marketbuyer"] = "456"
	equipment_assert(ipc.commit(json_decode(json_encode(ipc.profile))), "durable test actor bindings")
	var/datum/extraction_ipc_economy/economy = new(game)
	ipc.economic_adapter = economy
	equipment_assert(economy.ready() && !game.open("extractionvendor"), "reserved finite treasury cannot be claimed by a player")
	var/list/seller = game.store.load_profile("marketseller")
	var/list/buyer = game.store.load_profile("marketbuyer")
	var/datum/extraction_equipment_codec/codec = new
	var/obj/item/extraction_salvage/part = new(locate(1,1,1))
	equipment_assert(codec.set_raid_provenance(part, TRUE), "market lot acquired in raid")
	var/list/graph = codec.encode(part)
	graph["nodes"][1]["id"] = "market-part"
	equipment_assert(codec.validate(graph), "actual market lot equipment graph")
	seller["stash"] = list(list("id" = "market-part", "equipment" = graph))
	buyer["credits"] = 100
	equipment_assert(game.store.commit_profile("marketseller", seller) && game.store.commit_profile("marketbuyer", buyer), "isolated funded accounts")
	var/digest = md5(json_encode(graph))
	var/list/quote = economy_quote(ipc, economy, "123", "marketseller", "list-quote", "player_listing", list("market-part"))
	var/list/wrong = economy_request("123", "trade.confirm", "wrong-action", quote["expected_account_revision"], list("confirmation_token" = quote["confirmation_token"]))
	equipment_assert(ipc.process_wire(economy_wire(ipc, wrong), "1001")["reason"] == "quote_action_mismatch", "confirmation token binds exact action")
	wrong = economy_request("456", "market.list", "wrong-actor", buyer["revision"], list("confirmation_token" = quote["confirmation_token"]))
	equipment_assert(ipc.process_wire(economy_wire(ipc, wrong), "1001")["reason"] == "token_invalid", "confirmation token binds exact linked actor")
	var/list/expired = economy_request("123", "market.list", "expired-quote", quote["expected_account_revision"], list("confirmation_token" = quote["confirmation_token"]))
	equipment_assert(economy.process(ipc, expired, json_decode(json_encode(ipc.profile)), "1120", "marketseller")["reason"] == "quote_expired", "quote expires at precise deadline")
	var/list/listed = economy_confirm(ipc, economy, "123", "marketseller", "list-confirm", quote)
	equipment_assert(listed["status"] == "committed", "listing settlement committed: [json_encode(listed)]")
	var/list/escrow = game.store.load_profile("extractionmarket")
	seller = game.store.load_profile("marketseller")
	equipment_assert(!length(seller["stash"]) && length(escrow["stash"]) == 1 && md5(json_encode(escrow["stash"][1]["equipment"])) == digest, "listing holds exact graph in durable escrow")
	equipment_assert(economy_confirm(ipc, economy, "123", "marketseller", "used-list-token", quote)["reason"] == "stale_revision", "old revision prevents consumed token reuse through signed service")
	var/listing_id = listed["data"]["listing_id"]
	var/list/catalog_request = economy_request("456", "market.browse", "active-market", null, list("page" = 0))
	var/list/catalog_response = ipc.process_wire(economy_wire(ipc, catalog_request), "1000")
	equipment_assert(catalog_response["status"] == "committed" && length(catalog_response["data"]["listings"]) == 1 && catalog_response["data"]["listings"][1]["listing_id"] == listing_id && catalog_response["data"]["listings"][1]["price"]["amount"] == 20 && !findtext(json_encode(catalog_response), "marketseller"), "active catalog supplies native price and escrow ID without seller identity")
	buyer["credits"] = 10
	equipment_assert(game.store.commit_profile("marketbuyer", buyer), "isolated insufficient buyer balance")
	quote = economy_quote(ipc, economy, "456", "marketbuyer", "poor-quote", "player_purchase", null, listing_id)
	var/list/poor = economy_confirm(ipc, economy, "456", "marketbuyer", "poor-confirm", quote)
	equipment_assert(poor["reason"] == "insufficient_funds" && game.store.load_profile("marketbuyer")["credits"] == 10 && length(game.store.load_profile("extractionmarket")["stash"]) == 1, "insufficient funds leave exact escrow and balances untouched")
	buyer["credits"] = 100
	equipment_assert(game.store.commit_profile("marketbuyer", buyer), "restore isolated buyer balance")
	quote = economy_quote(ipc, economy, "456", "marketbuyer", "buy-quote", "player_purchase", null, listing_id)
	var/list/bought = economy_confirm(ipc, economy, "456", "marketbuyer", "buy-confirm", quote)
	equipment_assert(bought["status"] == "committed", "purchase three-account settlement committed: [json_encode(bought)]")
	buyer = game.store.load_profile("marketbuyer")
	seller = game.store.load_profile("marketseller")
	escrow = game.store.load_profile("extractionmarket")
	equipment_assert(buyer["credits"] == 80 && seller["credits"] == 20 && !length(escrow["stash"]) && md5(json_encode(buyer["stash"][1]["equipment"])) == digest, "purchase conserves credits and exact graph once")
	var/list/replayed = economy_confirm(ipc, economy, "456", "marketbuyer", "buy-confirm", quote)
	equipment_assert(json_encode(replayed) == json_encode(bought) && game.store.load_profile("marketbuyer")["revision"] == buyer["revision"], "confirmed duplicate returns original economic receipt without a second debit")
	var/list/status_request = economy_request("456", "trade.status", "buy-recovery-status", null, list("operation_request_digest" = bought["request_digest"], "operation_request_id" = "buy-confirm"))
	var/list/status = ipc.process_wire(economy_wire(ipc, status_request), "1001")
	equipment_assert(status["data"]["operation_status"] == "committed" && json_encode(status["data"]["operation_receipt"]) == json_encode(bought), "fresh signed status reads authoritative economic receipt")
	quote = economy_quote(ipc, economy, "456", "marketbuyer", "cancel-list-quote", "player_listing", list("market-part"))
	listed = economy_confirm(ipc, economy, "456", "marketbuyer", "cancel-list-confirm", quote)
	equipment_assert(listed["status"] == "committed", "second listing committed")
	quote = economy_quote(ipc, economy, "456", "marketbuyer", "cancel-quote", "listing_cancel", null, listed["data"]["listing_id"])
	var/list/cancelled = economy_confirm(ipc, economy, "456", "marketbuyer", "cancel-confirm", quote)
	equipment_assert(cancelled["status"] == "committed" && length(game.store.load_profile("marketbuyer")["stash"]) == 1, "cancellation returns escrow graph exactly")
	quote = economy_quote(ipc, economy, "456", "marketbuyer", "vendor-quote", "server_buyback", list("market-part"))
	game.settlement.test_fail_at = "after_receipt"
	var/list/pending = economy_confirm(ipc, economy, "456", "marketbuyer", "vendor-confirm", quote)
	equipment_assert(pending["status"] == "pending" && !game.open("marketbuyer"), "interrupted shared receipt gates access")
	var/datum/extraction_service/restarted = new
	restarted.store.root = game.store.root
	var/datum/extraction_ipc_economy/recovered = new(restarted)
	equipment_assert(recovered.ready(), "fresh service recovers durable pending settlement")
	buyer = restarted.store.load_profile("marketbuyer")
	var/list/vendor = restarted.store.load_profile("extractionvendor")
	equipment_assert(buyer["credits"] == 90 && vendor["credits"] == 999990 && !length(buyer["stash"]) && length(vendor["stash"]) == 1 && md5(json_encode(vendor["stash"][1]["equipment"])) == digest, "recovered buyback conserves finite treasury and exact graph")
	var/list/original = recovered.receipt(ipc, "marketbuyer", "vendor-confirm", pending["request_digest"])
	equipment_assert(original["status"] == "committed" && original["reason"] == "economic_settlement_committed", "recovery returns authoritative committed operation receipt")
	ipc.economic_adapter = recovered
	run_room_projection_probe(ipc, recovered, graph)
	world.log << "PASS: native signed market escrow, conservation, cancellation, actor/action/expiry/funds guards, replay/status and interrupted settlement recovery"
	qdel(part)

/proc/run_room_projection_probe(datum/extraction_ipc_service/ipc, datum/extraction_ipc_economy/economy, list/part_graph)
	var/list/account = economy.game.store.load_profile("marketbuyer")
	var/list/ids = list()
	for (var/i in 1 to 5)
		var/id = "upgrade-part-[i]"
		var/list/graph = json_decode(json_encode(part_graph))
		graph["nodes"][1]["id"] = id
		ids += id
		account["stash"] += list(list("id" = id, "equipment" = graph, "salvage" = TRUE))
	equipment_assert(economy.game.store.commit_profile("marketbuyer", account), "isolated actual upgrade stock")
	var/list/request = economy_request("456", "stash.detail", "part-detail", account["revision"], list("item_id" = ids[1], "page" = 0))
	var/list/detail = ipc.process_wire(economy_wire(ipc, request), "1000")
	equipment_assert(detail["status"] == "committed" && detail["data"]["total_nodes"] == 1 && detail["data"]["nodes"][1]["id"] == ids[1] && detail["data"]["nodes"][1]["found_in_raid"] && !findtext(json_encode(detail), "insurance_token"), "signed detail preserves actual stable node and FIR without insurance secrets")
	request = economy_request("123", "stash.detail", "foreign-detail", null, list("item_id" = ids[1], "page" = 0))
	equipment_assert(ipc.process_wire(economy_wire(ipc, request), "1000")["reason"] == "item_unavailable", "saved detail cannot read another linked account")
	request = economy_request("456", "room.quote", "room-quote", account["revision"], list("operation" = "upgrade", "item_ids" = ids))
	var/list/quoted = ipc.process_wire(economy_wire(ipc, request), "1000")
	var/list/quote = quoted["data"]
	equipment_assert(quoted["status"] == "committed" && quote["required_parts"] == 5 && quote["current_level"] == 1 && quote["target_level"] == 2 && quote["confirm_action"] == "room.manage" && istext(quote["expires_at"]), "room quote binds native level cost and decimal expiry")
	var/datum/extraction_session/active = economy.game.open("marketbuyer")
	equipment_assert(active, "actual native active account gate")
	request = economy_request("456", "stash.detail", "busy-detail", null, list("item_id" = ids[1], "page" = 0))
	equipment_assert(ipc.process_wire(economy_wire(ipc, request), "1000")["reason"] == "account_busy", "detail rejects a concurrently materialized native account")
	var/list/busy = economy_confirm(ipc, economy, "456", "marketbuyer", "room-busy", quote)
	equipment_assert(busy["reason"] == "account_busy", "room confirmation rejects active native session")
	active.close()
	var/list/upgraded = economy_confirm(ipc, economy, "456", "marketbuyer", "room-confirm", quote)
	account = economy.game.store.load_profile("marketbuyer")
	equipment_assert(upgraded["status"] == "committed" && upgraded["reason"] == "room_upgrade_committed" && account["level"] == 2 && !length(account["stash"]) && account["credits"] == 90, "native upgrade consumes exactly five roots and preserves unrelated wallet")
	var/list/replayed = economy_confirm(ipc, economy, "456", "marketbuyer", "room-confirm", quote)
	equipment_assert(json_encode(replayed) == json_encode(upgraded) && economy.game.store.load_profile("marketbuyer")["revision"] == account["revision"], "room receipt replays without another upgrade or debit")
	var/datum/extraction_service/restart = new
	restart.store.root = economy.game.store.root
	var/datum/extraction_ipc_economy/reloaded = new(restart)
	equipment_assert(json_encode(reloaded.receipt(ipc, "marketbuyer", "room-confirm", upgraded["request_digest"])) == json_encode(upgraded), "fresh service recovers room receipt in the same committed account snapshot")
	request = economy_request("456", "market.browse", "empty-market", null, list("page" = 0))
	var/list/catalog = ipc.process_wire(economy_wire(ipc, request), "1000")
	equipment_assert(catalog["status"] == "committed" && !length(catalog["data"]["listings"]) && isnull(catalog["data"]["next_page"]), "catalog excludes sold and cancelled escrow lots")
	var/obj/item/weapon/storage/backpack/bag = new(locate(3,6,1))
	for (var/i in 1 to 17) new /obj/item/extraction_salvage(bag)
	var/obj/item/weapon/gun/projectile/pistol/m9beretta/G = new(bag)
	G.health = 61
	G.extraction_insurance_token = md5("test-insurance-secret")
	var/datum/extraction_equipment_codec/codec = new
	equipment_assert(codec.set_raid_provenance(bag, TRUE), "actual nested fixture graph acquired in raid")
	var/list/nested_graph = codec.encode(bag)
	equipment_assert(nested_graph && length(nested_graph["nodes"]) > 16, "real contained equipment exceeds a single detail page")
	var/id = nested_graph["nodes"][1]["id"]
	account["stash"] += list(list("id" = id, "equipment" = nested_graph))
	equipment_assert(economy.game.store.commit_profile("marketbuyer", account), "commit actual nested detail stock")
	request = economy_request("456", "stash.detail", "nested-page-one", account["revision"], list("item_id" = id, "page" = 0))
	detail = ipc.process_wire(economy_wire(ipc, request), "1000")
	equipment_assert(detail["status"] == "committed" && length(detail["data"]["nodes"]) == 16 && detail["data"]["next_page"] == 1 && detail["data"]["nodes"][2]["parent"] == 1 && detail["data"]["nodes"][2]["found_in_raid"], "nested graph pagination preserves original parent indexes and FIR")
	request = economy_request("456", "stash.detail", "nested-page-two", account["revision"], list("item_id" = id, "page" = 1))
	detail = ipc.process_wire(economy_wire(ipc, request), "1000")
	var/found_gun = FALSE
	for (var/list/node in detail["data"]["nodes"])
		if (node["id"] == G.extraction_item_id)
			found_gun = node["condition"]["health"] == 61 && node["parent"] == 1
	equipment_assert(detail["status"] == "committed" && found_gun && !findtext(json_encode(detail), G.extraction_insurance_token) && !findtext(json_encode(detail), "insurance_token"), "later detail page preserves gun condition and identity without exposing insurance secret")
	request = economy_request("456", "stash.detail", "stale-detail", account["revision"] - 1, list("item_id" = id, "page" = 0))
	equipment_assert(ipc.process_wire(economy_wire(ipc, request), "1000")["reason"] == "stale_revision", "detail paging rejects a supplied stale snapshot revision")
	qdel(bag)
	var/snapshot_revision = account["revision"]
	ipc.economic_adapter = new /datum/extraction_oversized_reply_fixture
	request = economy_request("456", "market.browse", "oversized-response", null, list("page" = 0))
	var/list/oversized = ipc.process_wire(economy_wire(ipc, request), "1000")
	equipment_assert(oversized["status"] == "rejected" && oversized["reason"] == "response_too_large" && length(extraction_crypto_bytes(json_encode(oversized))) <= 8192, "oversized response fails explicitly instead of truncating a successful DTO")
	equipment_assert(json_encode(ipc.process_wire(economy_wire(ipc, request), "1000")) == json_encode(oversized) && economy.game.store.load_profile("marketbuyer")["revision"] == snapshot_revision, "oversized rejection replays immutably without an account mutation")
	ipc.economic_adapter = economy
