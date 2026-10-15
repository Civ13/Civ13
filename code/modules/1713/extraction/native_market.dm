// Server-local callers share economic planning and the actual conservation
// journal. This response adapter has no transport, linking or enabled spool.
/datum/extraction_ipc_service/native_market
	New()
		..(null)
		key = extraction_sha256("localquote\n\ref[src]\n[world.realtime]\n[rand(1, 1000000)]")
	response(list/request, status, reason, list/data)
		return list("request_id" = request["request_id"], "request_digest" = request["request_digest"], "actor_owner" = request["actor_owner"], "action" = request["action"], "status" = status, "reason" = reason, "data" = islist(data) ? data : list())

/datum/extraction_native_market_offer
	var/owner
	var/list/request
	var/list/candidate = list("quotes" = list())
	var/list/result
	var/datum/extraction_ipc_service/native_market/adapter = new
	var/used = FALSE

/obj/map_metadata/extraction_survival/proc/native_market_quote(mob/living/human/H, list/payload)
	if (!extraction_market_payload_valid(payload) || !supply_access(H) || !save_home(H.extraction_session)) return null
	var/datum/extraction_session/S = H.extraction_session
	var/datum/extraction_ipc_economy/economy = new(accounts)
	if (!economy.ready()) return null
	var/datum/extraction_native_market_offer/offer = new
	offer.owner = S.owner
	var/id = "native:[S.owner]:[S.profile["revision"]]:\ref[offer]"
	offer.request = list("request_id" = id, "request_digest" = extraction_sha256(id), "actor_owner" = S.owner, "action" = "trade.quote", "payload" = json_decode(json_encode(payload)))
	offer.result = economy.quote(offer.adapter, offer.request, offer.candidate, S.profile, extraction_ipc_now())
	return offer

/obj/map_metadata/extraction_survival/proc/native_market_confirm(mob/living/human/H, datum/extraction_native_market_offer/offer)
	if (!supply_access(H) || !offer || offer.used || offer.owner != H.extraction_session.owner || offer.result?["reason"] != "quote_created") return null
	var/datum/extraction_session/S = H.extraction_session
	var/list/actual = records(home_roots(S))
	var/list/garage = garage_snapshot(S)
	if (!actual || isnull(garage) || json_encode(actual) != json_encode(S.profile["stash"]) || json_encode(garage) != json_encode(S.profile["garage"])) return list("status" = "rejected", "reason" = "stale_equipment", "data" = list())
	var/list/current = json_decode(json_encode(S.profile))
	var/list/data = offer.result["data"]
	var/list/request = json_decode(json_encode(offer.request))
	request["request_id"] = "[request["request_id"]]:confirm"
	request["request_digest"] = extraction_sha256(request["request_id"])
	request["action"] = data["confirm_action"]
	request["payload"] = list("confirmation_token" = data["confirmation_token"])
	// The modal review has finished. No yielding between retirement and submit.
	S.transitioning = TRUE
	for (var/obj/item/I in home_roots(S))
		if (I.loc == H) H.unEquip(I, TRUE)
	if (!release(S, FALSE, FALSE))
		S.transitioning = FALSE
		return null
	offer.used = TRUE
	var/datum/extraction_ipc_economy/economy = new(accounts)
	var/list/result = economy.confirm(offer.adapter, request, offer.candidate, current, extraction_ipc_now())
	if (!admit(H))
		to_chat(H, "Your market result is [result?["status"]]: [result?["reason"]]. Private storage is locked for recovery; no equipment was issued.")
		return result
	to_chat(H, "Market result [result?["status"]]: [result?["reason"]]. Receipt [request["request_id"]]. Balance [game_credits(H.extraction_session)] game credits.")
	return result

/obj/map_metadata/extraction_survival/proc/native_market_catalog(mob/living/human/H, page = 0)
	if (!supply_access(H) || !isnum(page) || page < 0 || page > 15 || round(page) != page) return null
	var/datum/extraction_ipc_economy/economy = new(accounts)
	var/datum/extraction_ipc_service/native_market/adapter = new
	return economy.market_catalog(adapter, list("payload" = list("page" = page)), H.extraction_session.profile)

/obj/map_metadata/extraction_survival/proc/native_market_status(mob/living/human/H, request_id)
	if (!supply_access(H) || !istext(request_id) || length(request_id) > 256) return null
	var/list/receipt = H.extraction_session.profile["bot_receipts"]?[extraction_sha256(request_id)]
	return islist(receipt) ? json_decode(json_encode(receipt)) : null

/obj/map_metadata/extraction_survival/proc/choose_market_items(mob/living/human/H, require_fir)
	var/datum/extraction_ipc_economy/economy = new(accounts)
	var/list/options = list()
	for (var/list/entry in H.extraction_session.profile["stash"])
		if (!economy.eligible(entry, require_fir) || !economy.price(entry)) continue
		var/obj/item/prototype = text2path(entry["equipment"]["nodes"][1]["type"])
		options["[initial(prototype.name)] - [entry["id"]], [economy.price(entry) * (require_fir ? 2 : 1)] credits"] = entry["id"]
	var/list/selected = list()
	while (options.len && selected.len < 16)
		var/choice = WWinput(H, "Select up to sixteen exact item IDs. [require_fir ? "Listings require found-in-raid gear." : "The vendor pays from its finite game-credit treasury."]", "Market items", "Cancel", options + list("Review quote", "Cancel"))
		if (!supply_access(H) || choice == "Cancel") return null
		if (choice == "Review quote") break
		if (!options[choice]) return null
		selected += options[choice]
		options -= choice
	return selected.len ? selected : null

/obj/map_metadata/extraction_survival/proc/review_native_market(mob/living/human/H, list/payload)
	var/datum/extraction_native_market_offer/offer = native_market_quote(H, payload)
	if (!offer?.result) return FALSE
	if (offer.result["reason"] != "quote_created")
		to_chat(H, "Market quote [offer.result["status"]]: [offer.result["reason"]].")
		return FALSE
	var/list/data = offer.result["data"]
	var/choice = WWinput(H, "[data["confirm_action"]]: [data["price"]["amount"]] game credits. Selected IDs: [jointext(data["item_ids"], ", ")]. Quote expires at [data["expires_at"]]. Settlement returns your equipment to private storage. Confirm this exact quote?", "Market quote", "Cancel", list("Confirm", "Cancel"))
	if (choice != "Confirm") return FALSE
	var/list/result = native_market_confirm(H, offer)
	if (!result) to_chat(H, "Market confirmation rejected; check terminal access and quote freshness.")
	return result?["status"] == "committed"

/obj/map_metadata/extraction_survival/proc/manage_native_market(mob/living/human/H)
	if (!supply_access(H) || !save_home(H.extraction_session)) return FALSE
	var/choice = WWinput(H, "Sell owned gear to the finite vendor treasury, list found-in-raid gear, browse listings or inspect a saved receipt. Online counterparties are busy until their private equipment is released.", "Safe-house market", "Cancel", list("Sell to vendor", "List gear", "Browse listings", "Inspect receipt", "Cancel"))
	if (!supply_access(H)) return FALSE
	if (choice in list("Sell to vendor", "List gear"))
		var/list/ids = choose_market_items(H, choice == "List gear")
		if (!ids) return FALSE
		return review_native_market(H, list("sale_kind" = choice == "List gear" ? "player_listing" : "server_buyback", "item_ids" = ids))
	if (choice == "Inspect receipt")
		var/list/options = list()
		for (var/id in H.extraction_session.profile["bot_receipts"])
			var/list/receipt = H.extraction_session.profile["bot_receipts"][id]
			options["[receipt["request_id"]]"] = receipt["request_id"]
		var/selected = WWinput(H, "Choose a saved operation receipt. Pending operations require journal recovery before another transfer.", "Market receipts", "Cancel", options + list("Cancel"))
		var/list/receipt = options[selected] ? native_market_status(H, options[selected]) : null
		if (receipt) to_chat(H, "Receipt [receipt["request_id"]]: [receipt["status"]], [receipt["reason"]].")
		return !!receipt
	if (choice != "Browse listings") return FALSE
	var/page = 0
	while (page <= 15 && supply_access(H))
		var/list/catalog = native_market_catalog(H, page)
		if (catalog?["status"] != "committed")
			to_chat(H, "Market catalog unavailable: [catalog?["reason"]].")
			return FALSE
		var/list/options = list()
		for (var/list/listing in catalog["data"]["listings"])
			options["[listing["listing_id"]] - [listing["price"]["amount"]] credits, [listing["item_count"]] items"] = listing["listing_id"]
		var/list/navigation = list("Cancel")
		if (!isnull(catalog["data"]["next_page"])) navigation += "Next page"
		var/selected = WWinput(H, "Choose a listing to buy or cancel your own listing. Page [page + 1].", "Player listings", "Cancel", options + navigation)
		if (!supply_access(H)) return FALSE
		if (selected == "Next page")
			page = catalog["data"]["next_page"]
			continue
		if (!options[selected]) return FALSE
		for (var/list/listing in catalog["data"]["listings"])
			if (listing["listing_id"] != options[selected]) continue
			for (var/list/projection in listing["roots"])
				if (islist(projection["root"])) to_chat(H, stash_node_text(projection["root"]))
		var/action = WWinput(H, "Buy this listing, or cancel it if you own it. The server checks ownership and price before payment.", "Listing action", "Cancel", list("Buy", "Cancel own listing", "Cancel"))
		if (!supply_access(H) || !(action in list("Buy", "Cancel own listing"))) return FALSE
		return review_native_market(H, list("sale_kind" = action == "Buy" ? "player_purchase" : "listing_cancel", "listing_id" = options[selected]))
	return FALSE
