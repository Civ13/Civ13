// Production journal, codec and actual item custody; runtime is opt-in.
/proc/extraction_surface_probe(obj/map_metadata/extraction_survival/M, mob/living/human/H)
	var/datum/extraction_surface_service/V = new(M, "data/surface_fixture/")
	var/obj/effect/extraction_surface_source/S = new(get_turf(H))
	S.source_id = 1
	S.pool_id = "repair_parts"
	equipment_assert(V.register_source(S), "surface source registers without constructors issuing stock")
	equipment_assert(!V.prepare_source(S) && !S.profile && !S.live_root, "surface disabled gate prevents journal and item issuance")
	V.enabled = TRUE
	equipment_assert(V.prepare_source(S) && S.profile["stash"].len == 1, "surface finite plan persists before materialization")
	var/list/entry = S.profile["stash"][1]
	var/id = entry["id"]
	var/epoch = V.epoch_profile["raid_sequence"]
	var/datum/extraction_surface_service/restart = new(M, "data/surface_fixture/")
	equipment_assert(restart.ensure_epoch() && restart.epoch_profile["raid_sequence"] == epoch, "surface restart preserves epoch without refill")
	equipment_assert(V.materialize_source(S), "surface materialization exposes exactly one planned identity")
	var/obj/item/I = S.live_root
	equipment_assert(I && I.extraction_item_id == id && I.extraction_found_in_raid && I.anchored && I.extraction_surface_source == S, "surface root retains actual identity FIR and custody link")
	equipment_assert(!V.materialize_source(S) && S.live_root == I, "surface second materialization cannot duplicate root")
	var/obj/effect/extraction_surface_source/R = new(get_turf(H))
	R.source_id = 1
	R.pool_id = "repair_parts"
	equipment_assert(restart.register_source(R) && !restart.reconcile_source(R) && R.quarantined, "surface missing restart root quarantines rather than rematerializes")
	S.busy = TRUE
	equipment_assert(!V.claim_root(S, H, I) && I.loc == get_turf(S), "surface busy claim rejects concurrent pickup")
	S.busy = FALSE
	var/obj/item/held = H.get_active_hand()
	if (held) H.drop_from_inventory(held, get_turf(H), TRUE)
	V.test_fail_claim_ack = TRUE
	equipment_assert(!V.claim_root(S, H, I) && S.quarantined && H.extraction_session.locked, "surface interrupted claim acknowledgement quarantines actual custody")
	var/list/pending = V.store.load_profile("source1")
	equipment_assert(pending && pending["surface_state"] == "claiming" && pending["surface_claim"]["item"] == id, "surface claim intent survives failed acknowledgement")
	equipment_assert(!V.prepare_source(S) && !V.materialize_source(S), "surface pending claim cannot refill or replay")
	H.extraction_session.locked = FALSE
	I.extraction_surface_source = null
	M.raid_items -= I
	qdel(I)
	if (held) equipment_assert(H.put_in_active_hand(held), "surface fixture restores original carried item")
	var/obj/effect/extraction_surface_source/D = new(get_turf(H))
	D.source_id = 1
	D.pool_id = "repair_parts"
	equipment_assert(!V.register_source(D) && D.quarantined && S.quarantined, "surface duplicate IDs quarantine both sources")
	var/obj/effect/extraction_surface_source/F = new(get_turf(H))
	F.source_id = 2
	F.pool_id = "canned_food"
	equipment_assert(V.register_source(F) && !V.prepare_source(F), "surface food remains disabled without reviewed codec")
	F.pool_id = "register_cash"
	equipment_assert(!V.prepare_source(F), "surface cash remains disabled without authoritative currency receipts")
	var/obj/effect/extraction_surface_source/B = new(get_turf(H))
	B.source_id = 3
	B.pool_id = "repair_parts"
	equipment_assert(V.register_source(B) && V.prepare_source(B), "surface budget case has a durable finite plan")
	var/list/original_items = M.raid_items
	M.raid_items = list()
	for (var/index in 1 to 2048) M.raid_items += index
	equipment_assert(!V.materialize_source(B) && B.quarantined && !B.live_root, "surface shared node budget rejects issuance before exposure")
	M.raid_items = original_items
	qdel(S)
	qdel(R)
	qdel(D)
	qdel(F)
	qdel(B)
	extraction_surface_custody_probe(M, H)
	extraction_surface_discovery_fence_probe(M, H)
	extraction_surface_inventory_probe(M)

/proc/extraction_surface_custody_probe(obj/map_metadata/extraction_survival/M, mob/living/human/H)
	var/datum/extraction_surface_service/V = new(M, "data/surface_custody_fixture/")
	V.enabled = TRUE
	var/obj/effect/extraction_surface_source/S = new(get_turf(H))
	S.source_id = 1
	S.pool_id = "parking_fuel"
	equipment_assert(V.register_source(S) && V.prepare_source(S) && V.materialize_source(S), "surface custody fixture materializes real fuel graph")
	var/obj/item/I = S.live_root
	var/id = I.extraction_item_id
	var/turf/original = get_turf(I)
	equipment_assert(!I.forceMove(H) && I.loc == original, "surface alternate forced pickup cannot bypass journal")
	equipment_assert(!I.Move(get_step(original, EAST), EAST) && I.loc == original, "surface walking drag cannot bypass custody")
	equipment_assert(!H.put_in_inactive_hand(I) && I.loc == original, "surface alternate hand insertion rejects unacknowledged root")
	var/obj/item/extraction_salvage/container = new(null)
	equipment_assert(!I.forceMove(container) && I.loc == original && !container.contents.len, "surface nesting cannot bypass claim")
	qdel(container)
	var/obj/item/weapon/storage/backpack/bag = new(null)
	equipment_assert(!bag.handle_item_insertion(I) && I.loc == original && !bag.contents.len, "surface native storage insertion rejects direct location bypass")
	equipment_assert(!H.equip_to_slot(I, slot_back) && I.loc == original && H.back != I, "surface slot equipment rejects invalid custody before slot mutation")
	equipment_assert(!bag.can_be_inserted(I, TRUE) && !bag.remove_from_storage(I, H) && I.loc == original, "surface storage validation and removal reject linked roots")
	equipment_assert(!H.equip_to_slot_if_possible(I, slot_back, TRUE, TRUE) && I.loc == original, "surface safe equip rejects before destructive failure handling")
	equipment_assert(!H.equip_to_slot_or_drop(I, slot_back) && I.loc == original, "surface equip-or-drop cannot relocate linked root")
	var/obj/item/extraction_salvage/ordinary = new(null)
	equipment_assert(bag.handle_item_insertion(ordinary, TRUE) && ordinary.loc == bag, "surface guards preserve ordinary storage insertion")
	equipment_assert(bag.remove_from_storage(ordinary, original) && ordinary.loc == original, "surface guards preserve ordinary storage removal")
	qdel(ordinary)
	qdel(bag)
	var/before = json_encode(M.codec.encode(I))
	I.attack_self(H)
	equipment_assert(json_encode(M.codec.encode(I)) == before, "surface fuel self interaction cannot alter unclaimed graph")
	// Explicit loader input uses the actual decoded graph and refuses duplicates.
	var/datum/extraction_surface_service/restart = new(M, "data/surface_custody_fixture/")
	var/obj/effect/extraction_surface_source/R = new(original)
	R.source_id = 1
	R.pool_id = "parking_fuel"
	I.extraction_surface_source = null
	equipment_assert(restart.register_source(R) && restart.discover_world_roots(list(I)) && restart.reconcile_source(R) && R.live_root == I, "surface saved-root discovery rebinds actual matching identity")
	var/datum/extraction_surface_service/conflict = new(M, "data/surface_conflict_fixture/")
	equipment_assert(conflict.discover_world_roots(list(I)) && !conflict.discover_account_entries(list(S.profile["surface_entry"])) && conflict.discovery_locked, "surface world-account identity duplication quarantines discovery")
	var/datum/extraction_surface_service/duplicates = new(M, "data/surface_duplicate_fixture/")
	equipment_assert(!duplicates.discover_world_roots(list(I, I)) && duplicates.discovery_locked, "surface duplicate loaded roots lock discovery")
	var/datum/extraction_surface_service/malformed = new(M, "data/surface_malformed_fixture/")
	equipment_assert(!malformed.discover_world_roots(list("invalid")) && malformed.discovery_locked, "surface malformed world discovery locks rather than skips input")
	var/datum/extraction_surface_service/wrong_entry = new(M, "data/surface_wrong_entry_fixture/")
	var/list/invalid_entry = json_decode(json_encode(S.profile["surface_entry"]))
	invalid_entry["id"] = "wrong-root"
	equipment_assert(!wrong_entry.discover_account_entries(list(invalid_entry)) && wrong_entry.discovery_locked, "surface account discovery rejects mismatched root identity")
	restart.enabled = TRUE
	var/old_closing = M.round_closing
	var/old_over = M.game_over
	M.round_closing = TRUE
	equipment_assert(restart.forfeit_source(R) && R.profile["surface_state"] == "forfeited" && (!I || !I.loc) && !R.live_root, "surface round forfeit retires actual root before acknowledgement")
	var/list/sessions = M.accounts.sessions
	M.accounts.sessions = list()
	M.game_over = TRUE
	var/epoch = restart.epoch_profile["raid_sequence"]
	equipment_assert(!restart.advance_epoch(epoch + 1), "surface stale epoch advance rejects refill")
	equipment_assert(restart.advance_epoch(epoch) && restart.prepare_source(R), "surface completed closed round permits terminal next-epoch plan")
	equipment_assert(R.profile["surface_entry"]["id"] != id && R.profile["surface_retired_entry"]["id"] == id, "surface next epoch preserves retired identity and mints distinct planned root")
	equipment_assert(restart.epoch_profile["surface_retired_ids"][id], "surface forfeited identity remains in durable epoch retirement index")
	var/obj/item/stale = M.codec.decode(R.profile["surface_retired_entry"]["equipment"], null)
	var/datum/extraction_surface_service/history = new(M, "data/surface_custody_fixture/")
	equipment_assert(stale && !history.discover_world_roots(list(stale)) && history.discovery_locked, "surface restart refuses historical forfeited snapshot identity")
	qdel(stale)
	M.accounts.sessions = sessions
	M.round_closing = old_closing
	M.game_over = old_over
	qdel(S)
	qdel(R)

/proc/extraction_surface_discovery_fence_probe(obj/map_metadata/extraction_survival/M, mob/living/human/H)
	for (var/kind in list("malformed", "account", "world"))
		var/datum/extraction_surface_service/V = new(M, "data/surface_fence_[kind]/")
		V.enabled = TRUE
		var/obj/effect/extraction_surface_source/S = new(get_turf(H))
		S.source_id = 1
		S.pool_id = "repair_parts"
		equipment_assert(V.register_source(S) && V.prepare_source(S), "surface discovery fence has private durable plan")
		var/obj/item/loaded
		if (kind == "malformed")
			equipment_assert(!V.discover_world_roots(list("invalid")), "surface fence malformed input rejected")
			equipment_assert(!V.prepare_source(S), "surface discovery failure blocks planning mutation")
		else if (kind == "account")
			equipment_assert(V.discover_account_entries(list(S.profile["surface_entry"])), "surface fence accepts authoritative account graph input")
		else
			loaded = M.codec.decode(S.profile["surface_entry"]["equipment"], null)
			equipment_assert(loaded && V.discover_world_roots(list(loaded)), "surface fence accepts actual loaded graph input")
		equipment_assert(!V.materialize_source(S) && !S.live_root && S.profile["surface_state"] == "planned", "surface discovery conflict never exposes or issues planned duplicate")
		if (loaded) qdel(loaded)
		qdel(S)

/proc/extraction_surface_inventory_probe(obj/map_metadata/extraction_survival/M)
	var/obj/item/extraction_salvage/unidentified = new(null)
	var/datum/extraction_surface_service/missing_id = new(M, "data/surface_missing_identity/")
	equipment_assert(!missing_id.discover_world_roots(list(unidentified)) && !unidentified.extraction_item_id && missing_id.discovery_locked, "surface loaded identity discovery never mints missing item identity")
	qdel(unidentified)
	var/datum/extraction_surface_service/worlds = new(M, "data/surface_world_inventory/")
	equipment_assert(worlds.begin_world_inventory(2) && worlds.feed_loaded_level(1, list()), "surface loader accepts first actual empty level batch")
	equipment_assert(!worlds.finish_world_inventory() && worlds.discovery_locked && !worlds.world_inventory_complete, "surface incomplete world levels cannot seal discovery")
	var/datum/extraction_surface_service/complete = new(M, "data/surface_complete_inventory/")
	equipment_assert(complete.begin_world_inventory(1) && complete.feed_loaded_level(1, list()) && complete.finish_world_inventory() && complete.world_inventory_complete, "surface complete world level feed seals only world inventory")
	equipment_assert(complete.inventory_incomplete(), "surface world completion cannot authorize missing account auxiliary feeds")
	var/datum/extraction_account_store/original_store = M.accounts.store
	var/list/original_sessions = M.accounts.sessions
	var/datum/extraction_account_store/accounts = new
	accounts.root = "data/surface_account_inventory/"
	M.accounts.store = accounts
	M.accounts.sessions = list()
	var/list/P = accounts.load_profile("inventoryowner")
	equipment_assert(accounts.commit_profile("inventoryowner", P), "surface inventory fixture persists ordinary offline account")
	var/datum/extraction_surface_service/scan = new(M, "data/surface_scan/")
	equipment_assert(scan.begin_account_inventory() && scan.account_inventory_batch() && scan.account_inventory_recheck_batch() && scan.account_inventory_complete, "surface bounded account pass rechecks stable committed profiles")
	equipment_assert(scan.begin_auxiliary_inventory() && scan.auxiliary_inventory_batch() && scan.auxiliary_inventory_verify_batch() && scan.finish_auxiliary_inventory_batch() && scan.auxiliary_inventory_complete && scan.inventory_incomplete(), "empty auxiliary census seals only auxiliary ownership")
	equipment_assert(scan.abandon_account_inventory() && scan.inventory_incomplete(), "abandoning completed census releases writes without authorizing loot")
	var/datum/extraction_surface_service/changed = new(M, "data/surface_changed/")
	equipment_assert(changed.begin_account_inventory() && changed.account_inventory_batch(), "surface revision fixture completes initial pass")
	P = accounts.load_profile("inventoryowner")
	P["credits"] = 1
	equipment_assert(!accounts.commit_profile("inventoryowner", P), "surface account census blocks actual profile writes")
	equipment_assert(accounts.release_read_lease(changed.account_inventory_lease), "fixture explicitly revokes census lease")
	equipment_assert(accounts.commit_profile("inventoryowner", P), "surface revoked lease permits ordinary disk write")
	equipment_assert(!changed.account_inventory_recheck_batch() && changed.discovery_locked, "surface revoked lease cannot seal inventory")
	accounts.test_fail_at = "snapshot"
	P = accounts.load_profile("inventoryowner")
	P["credits"] = 2
	equipment_assert(!accounts.commit_profile("inventoryowner", P), "surface pending fixture interrupts actual account commit")
	accounts.test_fail_at = null
	var/datum/extraction_surface_service/pending = new(M, "data/surface_pending/")
	equipment_assert(pending.begin_account_inventory() && !pending.account_inventory_batch() && pending.discovery_locked, "surface newest pending account blocks inventory without rollback")
	equipment_assert(pending.abandon_account_inventory(), "failed pending census releases only on explicit abandonment")
	extraction_surface_auxiliary_probe(M, accounts)
	M.accounts.store = original_store
	M.accounts.sessions = original_sessions

/proc/extraction_surface_auxiliary_probe(obj/map_metadata/extraction_survival/M, datum/extraction_account_store/accounts)
	var/datum/extraction_surface_service/check = new(M, "data/surface_auxiliary_check/")
	var/obj/item/extraction_salvage/item = new(null)
	item.extraction_found_in_raid = TRUE
	var/list/graph = M.codec.encode(item)
	var/list/entry = list("id" = item.extraction_item_id, "equipment" = graph)
	var/list/market = accounts.load_profile("extractionmarket")
	market["level"] = 4
	market["economy_system"] = "extractionmarket"
	market["stash"] = list(entry)
	var/listing_id = extraction_sha256("listing-fixture")
	market["listings"] = list()
	market["listings"][listing_id] = list("owner" = "inventoryowner", "state" = "active", "revision" = 1, "price" = 20, "item_ids" = list(entry["id"]), "graph_digests" = list())
	market["listings"][listing_id]["graph_digests"][entry["id"]] = extraction_sha256(json_encode(graph))
	equipment_assert(check.market_inventory_valid(market), "market binds actual escrow graph exactly once")
	var/list/bad = json_decode(json_encode(market))
	bad["listings"][listing_id]["graph_digests"][entry["id"]] = extraction_sha256("wrong")
	equipment_assert(!check.market_inventory_valid(bad), "market wrong escrow digest rejected")
	bad = json_decode(json_encode(market))
	bad["stash"] = list()
	equipment_assert(!check.market_inventory_valid(bad), "market missing actual escrow root rejected")
	bad = json_decode(json_encode(market))
	bad["listings"][extraction_sha256("duplicate-listing")] = bad["listings"][listing_id].Copy()
	equipment_assert(!check.market_inventory_valid(bad), "market duplicate listing ownership rejected")
	bad = json_decode(json_encode(market))
	bad["listings"][listing_id]["state"] = "sold"
	equipment_assert(!check.market_inventory_valid(bad), "market unbound escrow root rejected")
	bad["stash"] = list()
	equipment_assert(check.market_inventory_valid(bad), "closed listing is historical rather than owned escrow")
	qdel(item)
	// Read actual two-slot shared records, never invoke settlement ready/repair.
	var/datum/extraction_account_store/shared = new
	var/list/P
	var/datum/extraction_account_store/fresh_accounts = new
	fresh_accounts.root = "data/surface_auxiliary_accounts/"
	M.accounts.store = fresh_accounts
	P = fresh_accounts.load_profile("auxowner")
	equipment_assert(fresh_accounts.commit_profile("auxowner", P), "persist auxiliary fixture owner")
	shared.root = "[fresh_accounts.root]_settlement/"
	P = shared.load_profile("world")
	P["phase"] = "pending"
	P["sequence"] = 1
	P["history"] = list()
	equipment_assert(shared.commit_profile("world", P), "persist isolated pending auxiliary projection")
	var/datum/extraction_surface_service/pending = new(M, "data/surface_auxiliary_pending/")
	equipment_assert(pending.begin_account_inventory() && pending.account_inventory_batch() && pending.account_inventory_recheck_batch() && pending.begin_auxiliary_inventory() && !pending.auxiliary_inventory_batch() && pending.discovery_locked, "pending shared projection blocks auxiliary census without repair")
	equipment_assert(shared.load_profile("world")["phase"] == "pending" && pending.abandon_account_inventory(), "census preserves pending journal and explicit lease fence")
	P = shared.load_profile("world")
	P["phase"] = "committed"
	P["sequence"] = 0
	equipment_assert(shared.commit_profile("world", P), "fixture supplies terminal shared journal")
	var/datum/extraction_mail_store/mail = new(M.accounts, M.codec)
	var/list/returned = json_decode(json_encode(entry))
	returned["returned_generation"] = 1
	returned["eligible_generation"] = 2
	var/list/operations = mail.plan_append("auxowner", list(returned))
	equipment_assert(operations && mail.apply(operations), "fixture writes actual sharded mail page and identity index")
	var/datum/extraction_surface_service/positive = new(M, "data/surface_auxiliary_positive/")
	equipment_assert(positive.begin_account_inventory() && positive.account_inventory_batch() && positive.account_inventory_recheck_batch() && positive.begin_auxiliary_inventory() && positive.auxiliary_inventory_batch() && positive.auxiliary_inventory_verify_batch() && positive.finish_auxiliary_inventory_batch() && positive.auxiliary_inventory_complete && positive.account_ids[entry["id"]], "auxiliary census joins actual mail graphs and active identity indices")
	equipment_assert(positive.abandon_account_inventory(), "positive auxiliary scan remains explicitly abandonable")
	var/node_key = mail.shard_key(null, "node", entry["id"])
	P = mail.journal.load_profile(node_key)
	P["entry_id"] = "wrong-root"
	equipment_assert(mail.journal.commit_profile(node_key, P), "fixture persists mismatched actual mail identity binding")
	var/datum/extraction_surface_service/wrong = new(M, "data/surface_auxiliary_wrong/")
	equipment_assert(wrong.begin_account_inventory() && wrong.account_inventory_batch() && wrong.account_inventory_recheck_batch() && wrong.begin_auxiliary_inventory() && wrong.auxiliary_inventory_batch() && wrong.auxiliary_inventory_verify_batch() && !wrong.finish_auxiliary_inventory_batch() && wrong.discovery_locked, "auxiliary mismatched active mail identity fails closed")
	equipment_assert(wrong.abandon_account_inventory(), "mismatched mail retains lease until abandonment")
	M.accounts.store = accounts
