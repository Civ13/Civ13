/proc/extraction_native_market_probe(obj/map_metadata/extraction_survival/M)
	world.log << "MARKET: start"
	var/mob/living/human/A = new(locate(3,3,1))
	var/mob/living/human/B = new(locate(3,3,1))
	A.m_intent = "stealth"
	B.m_intent = "stealth"
	M.test_owners[A] = "pool1"
	M.test_owners[B] = "pool2"
	equipment_assert(M.admit(A) && M.admit(B), "native market uses actual separately admitted bodies")
	var/datum/extraction_session/S = A.extraction_session
	var/obj/item/weapon/gun/projectile/pistol/m9beretta/G
	for (var/obj/item/weapon/gun/projectile/pistol/m9beretta/I in M.home_roots(S)) G = I
	equipment_assert(G, "native buyback uses actual priced gear beyond salvage")
	var/id = G.extraction_item_id
	var/datum/extraction_native_market_offer/nonfir = M.native_market_quote(A, list("sale_kind" = "player_listing", "item_ids" = list(id)))
	equipment_assert(nonfir?.result?["reason"] == "item_ineligible" && G.loc, "native listing rejects starter gear without raid provenance")
	equipment_assert(!M.native_market_quote(A, list("sale_kind" = "server_buyback", "item_ids" = list(id, id))) && G.loc, "native quote rejects duplicate IDs before retirement")
	equipment_assert(!M.native_market_quote(A, list("sale_kind" = "server_buyback", "item_ids" = list(id), "extra" = TRUE)), "native quote rejects unknown fields")
	var/datum/extraction_party/P = M.create_party(A)
	var/datum/extraction_native_market_offer/sale = M.native_market_quote(A, list("sale_kind" = "server_buyback", "item_ids" = list(id)))
	equipment_assert(sale?.result?["reason"] == "quote_created", "native gear sale uses shared price and graph quote")
	var/amount = sale.result["data"]["price"]["amount"]
	var/vendor_before = M.accounts.store.load_profile("extractionvendor")["credits"]
	equipment_assert(!M.native_market_confirm(B, sale) && G.loc, "foreign actor cannot consume native quote")
	var/old_health = G.health
	G.health--
	var/list/stale = M.native_market_confirm(A, sale)
	equipment_assert(stale?["reason"] == "stale_equipment" && G.loc && !sale.used, "changed original gear rejects before retirement")
	G.health = old_health
	var/list/sold = M.native_market_confirm(A, sale)
	equipment_assert(sold?["status"] == "committed" && !G.loc && S.closed && A.extraction_session.active(), "native sale retires originals before shared settlement and rebinds account")
	equipment_assert(M.game_credits(A.extraction_session) == amount && M.accounts.store.load_profile("extractionvendor")["credits"] == vendor_before - amount, "native buyback conserves shared finite vendor treasury")
	equipment_assert(M.party_by_owner["pool1"] == P && P.alive, "native retirement/rebind preserves party membership")
	equipment_assert(!M.native_market_confirm(A, sale), "native confirmation replay cannot sell same graph twice")
	equipment_assert(M.native_market_status(A, sold["request_id"]) && !M.native_market_status(B, sold["request_id"]), "native saved receipt is private and survives rebind")
	var/obj/item/extraction_salvage/loot = new(get_turf(A.extraction_session.house))
	M.codec.set_raid_provenance(loot, TRUE)
	loot.health = 41
	M.codec.encode(loot)
	var/loot_id = loot.extraction_item_id
	var/datum/extraction_native_market_offer/listing = M.native_market_quote(A, list("sale_kind" = "player_listing", "item_ids" = list(loot_id)))
	equipment_assert(listing?.result?["reason"] == "quote_created", "native listing quotes exact found-in-raid original")
	var/list/listed = M.native_market_confirm(A, listing)
	equipment_assert(listed?["status"] == "committed" && !loot.loc, "native listing moves original graph into shared escrow")
	var/list/catalog = M.native_market_catalog(B)
	var/list/listings = catalog?["data"]?["listings"]
	equipment_assert(catalog?["status"] == "committed" && listings.len == 1, "ordinary native catalog discovers shared active listing")
	var/list/public_listing = listings[1]
	var/listing_id = public_listing["listing_id"]
	var/price = public_listing["price"]["amount"]
	var/datum/extraction_native_market_offer/foreign_cancel = M.native_market_quote(B, list("sale_kind" = "listing_cancel", "listing_id" = listing_id))
	equipment_assert(foreign_cancel?.result?["reason"] == "item_not_owned", "native cancellation rejects foreign listing")
	var/datum/extraction_native_market_offer/busy = M.native_market_quote(B, list("sale_kind" = "player_purchase", "listing_id" = listing_id))
	equipment_assert(busy?.result?["reason"] == "account_busy", "native quote preserves online counterparty ownership gate")
	M.release(A.extraction_session, TRUE, FALSE)
	var/datum/extraction_native_market_offer/unfunded = M.native_market_quote(B, list("sale_kind" = "player_purchase", "listing_id" = listing_id))
	var/list/denied = M.native_market_confirm(B, unfunded)
	equipment_assert(denied?["reason"] == "insufficient_funds" && B.extraction_session.active() && M.game_credits(B.extraction_session) == 0, "native unfunded settlement rebinds originals without buying escrow")
	equipment_assert(M.native_market_catalog(B)?["data"]?["listings"]?.len == 1, "rejected native purchase preserves active listing")
	var/list/funded = B.extraction_session.copy_profile()
	funded["credits"] = 100
	equipment_assert(B.extraction_session.commit(funded), "fixture labels its isolated starting buyer wallet")
	var/datum/extraction_native_market_offer/purchase = M.native_market_quote(B, list("sale_kind" = "player_purchase", "listing_id" = listing_id))
	equipment_assert(purchase?.result?["reason"] == "quote_created", "native purchase uses released seller and actual escrow quote")
	var/list/bought = M.native_market_confirm(B, purchase)
	equipment_assert(bought?["status"] == "committed" && M.game_credits(B.extraction_session) == 100 - price && M.accounts.store.load_profile("pool1")["credits"] == amount + price, "native purchase conserves both player wallets")
	var/count = 0
	for (var/obj/item/I in M.home_roots(B.extraction_session))
		if (I.extraction_item_id == loot_id)
			count++
			equipment_assert(I.health == 41 && I.extraction_found_in_raid, "native purchase preserves original condition and FIR")
	equipment_assert(count == 1 && !M.native_market_confirm(B, purchase), "native purchase issues original ID once and rejects replay")
	var/datum/extraction_native_market_offer/relist = M.native_market_quote(B, list("sale_kind" = "player_listing", "item_ids" = list(loot_id)))
	var/list/relisted = M.native_market_confirm(B, relist)
	equipment_assert(relisted?["status"] == "committed", "native buyer can relist conserved original")
	var/datum/extraction_native_market_offer/cancel = M.native_market_quote(B, list("sale_kind" = "listing_cancel", "listing_id" = relisted["data"]["listing_id"]))
	var/list/cancelled = M.native_market_confirm(B, cancel)
	equipment_assert(cancelled?["status"] == "committed" && M.game_credits(B.extraction_session) == 100 - price, "native cancellation restores original without wallet change")
	count = 0
	for (var/obj/item/I in M.home_roots(B.extraction_session))
		if (I.extraction_item_id == loot_id) count++
	equipment_assert(count == 1 && !M.native_market_confirm(B, cancel), "native cancellation preserves one copy and rejects replay")
	equipment_assert(M.admit(A) && M.party_by_owner["pool1"] == P, "released seller reopens conserved account and existing party")
	M.release(A.extraction_session)
	M.release(B.extraction_session)
	qdel(A)
	qdel(B)
	equipment_assert(!M.accounts.sessions.len, "native market fixture releases actual bodies and sessions")
	world.log << "MARKET: complete"
