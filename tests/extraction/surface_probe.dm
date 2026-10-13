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
	var/datum/extraction_account_store/original_store = M.accounts.store
	var/list/original_sessions = M.accounts.sessions
	M.accounts.sessions = list()
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
	extraction_home_replica_probe(M)
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

/proc/extraction_home_replica_probe(obj/map_metadata/extraction_survival/M)
	var/datum/extraction_account_store/previous_store = M.accounts.store
	var/datum/extraction_account_store/accounts = new
	accounts.root = "data/surface_home_replicas/"
	M.accounts.store = accounts
	var/obj/effect/extraction_house_marker/house
	for (var/obj/effect/extraction_house_marker/H in extraction_house_markers)
		if (H.admission_available())
			house = H
			break
	equipment_assert(house && istype(get_turf(house), /turf/floor/plating/extraction_house), "replica fixture uses actual unoccupied private home")
	var/obj/item/extraction_salvage/I = new(get_turf(house))
	I.extraction_found_in_raid = TRUE
	var/list/graph = M.codec.encode(I)
	var/list/P = accounts.load_profile("replicaowner")
	P["stash"] = list(list("id" = I.extraction_item_id, "equipment" = graph))
	equipment_assert(accounts.commit_profile("replicaowner", P), "replica fixture commits actual account graph")
	var/datum/extraction_surface_service/V = new(M, "data/surface_home_scan/")
	equipment_assert(V.bind_home_replica("replicaowner", house, list(I)), "replica contract durably binds actual graph owner revision and placement")
	equipment_assert(V.begin_account_inventory() && V.account_inventory_batch() && V.account_inventory_recheck_batch(), "replica account census reads durable binding")
	equipment_assert(V.begin_auxiliary_inventory() && V.auxiliary_inventory_batch() && V.auxiliary_inventory_verify_batch() && V.finish_auxiliary_inventory_batch() && V.auxiliary_inventory_complete, "replica fixture seals actual empty auxiliary records")
	var/list/ids = V.graph_ids(graph, 2048)
	equipment_assert(V.approved_home_replica(I, graph, ids), "identical approved private-home replica accepted")
	house.replica_owner = "wrongowner"
	equipment_assert(!V.approved_home_replica(I, graph, ids), "private-home replica wrong owner rejected")
	house.replica_owner = "replicaowner"
	house.replica_revision++
	equipment_assert(!V.approved_home_replica(I, graph, ids), "private-home replica stale revision rejected")
	house.replica_revision--
	I.extraction_found_in_raid = FALSE
	equipment_assert(!V.approved_home_replica(I, M.codec.encode(I, FALSE), ids), "private-home replica changed graph rejected")
	I.extraction_found_in_raid = TRUE
	var/turf/original = I.loc
	I.forceMove(get_step(original, NORTH))
	equipment_assert(!V.approved_home_replica(I, graph, ids), "private-home replica wrong placement rejected")
	I.forceMove(original)
	equipment_assert(V.begin_world_inventory(1) && V.feed_loaded_level(1, list(I)) && V.finish_world_inventory() && V.canonical_home_roots[I.extraction_item_id] == I, "replica census joins one approved account and actual world root")
	equipment_assert(V.inventory_incomplete() && !V.current_world_complete, "saved replica feed cannot authorize incomplete fresh-world census")
	var/obj/item/copy = M.codec.decode(graph, original)
	equipment_assert(copy && !V.discover_world_roots(list(copy)) && V.discovery_locked, "second physical private-home replica rejected")
	equipment_assert(V.abandon_account_inventory(), "replica scan releases fence only on explicit abandonment")
	extraction_replica_admission_probe(M, house, I)
	extraction_replica_marker_save_probe()
	qdel(copy)
	extraction_home_retirement_probe(M, house, I)
	qdel(I)
	var/datum/extraction_surface_service/stale = new(M, "data/surface_stale_load/")
	equipment_assert(stale.begin_world_inventory(1) && stale.feed_loaded_level(1, list()), "stale barrier fixture records actual empty feed")
	stale.world_inventory_stamp--
	equipment_assert(!stale.finish_world_inventory() && stale.discovery_locked, "stale world load barrier cannot seal census")
	// Fixture cleanup only; production never unbinds before saved-world proof.
	house.replica_owner = null
	house.replica_revision = 0
	house.replica_digest = null
	M.accounts.store = previous_store

/proc/extraction_replica_admission_probe(obj/map_metadata/extraction_survival/M, obj/effect/extraction_house_marker/house, obj/item/owner_item)
	// The injected owner adapter exists only in the mode fixture. This shared
	// probe also compiles in equipment-only worlds that do not declare it.
	var/list/test_owners = M.vars["test_owners"]
	equipment_assert(islist(test_owners), "replica admission fixture requires injected mode owner adapter")
	var/turf/original = get_turf(owner_item)
	var/owner_id = owner_item.extraction_item_id
	var/owner_graph = json_encode(M.codec.encode(owner_item, FALSE))
	var/mob/living/human/other = new(locate(3,3,1))
	test_owners[other] = "replicaother"
	equipment_assert(M.admit(other) && other.extraction_session.house != house && house.session == null && owner_item.loc == original && owner_item.extraction_item_id == owner_id && json_encode(M.codec.encode(owner_item, FALSE)) == owner_graph && !original.Enter(other, get_turf(other)), "unbound second owner cannot enter replica-bound room or access its actual stash")
	equipment_assert(M.release(other.extraction_session, FALSE), "other owner releases only its unbound room")
	M.round_participants -= "replicaother"
	test_owners -= other
	qdel(other)
	var/mob/living/human/bound = new(locate(3,3,1))
	test_owners[bound] = "replicaowner"
	equipment_assert(!M.admit(bound) && !bound.extraction_session && owner_item.loc == original, "bound owner cannot decode another copy before retirement handoff")
	test_owners -= bound
	qdel(bound)
	// Each partial-field negative uses a real marker but cannot touch its stash.
	var/obj/effect/extraction_house_marker/partial = new(null)
	equipment_assert(partial.admission_available(), "default marker is available for ordinary admission")
	partial.replica_owner = ""
	equipment_assert(!partial.admission_available(), "empty persisted replica owner reserves room")
	partial.replica_owner = null
	partial.replica_digest = ""
	equipment_assert(!partial.admission_available(), "empty persisted replica digest reserves room")
	partial.replica_digest = null
	for (var/revision in list(1, -1, null, "0"))
		partial.replica_revision = revision
		equipment_assert(!partial.admission_available(), "partial persisted replica revision reserves room")
	qdel(partial)

/proc/extraction_replica_marker_save_probe()
	var/obj/effect/extraction_house_marker/saved = new(null)
	saved.room = 23
	saved.name = "saved replica marker"
	saved.replica_owner = "savedowner"
	saved.replica_revision = 7
	saved.replica_digest = extraction_sha256("actual marker binding")
	saved.extraction_vehicle_part_id = "parent-effect-field"
	saved.session = new
	var/datum/extraction_session/runtime_session = saved.session
	var/map_storage/storage = new("extraction_marker_probe")
	var/savefile/F = new("data/surface_house_marker.sav")
	F["/format_version"] << 2
	var/ref = storage.BuildVarDirectory(F, saved, 1)
	F = null
	storage.clear_bookkeeping()
	F = new("data/surface_house_marker.sav")
	var/obj/effect/extraction_house_marker/restored = storage.Load_Entry(F, ref, starting_loc = null)
	equipment_assert(restored && restored.room == saved.room && restored.replica_owner == saved.replica_owner && restored.replica_revision == saved.replica_revision && restored.replica_digest == saved.replica_digest && restored.name == saved.name && restored.extraction_vehicle_part_id == saved.extraction_vehicle_part_id && isnull(restored.session) && !restored.admission_available(), "native marker entry round trip preserves room binding and parent fields while excluding session")
	storage.clear_bookkeeping()
	saved.session = null
	qdel(runtime_session)
	qdel(saved)
	qdel(restored)

/datum/extraction_surface_service/home_retirement_failure_probe
	var/test_suffix
	home_retirement_store()
		var/datum/extraction_account_store/J = ..()
		J.root = "[metadata.accounts.store.root]_home_replica_[test_suffix]/"
		return J

/proc/extraction_home_retirement_probe(obj/map_metadata/extraction_survival/M, obj/effect/extraction_house_marker/H, obj/item/I)
	var/datum/extraction_surface_service/R = new(M, "data/home_retirement_probe/")
	var/list/account = M.accounts.store.load_profile("replicaowner")
	var/account_digest = extraction_sha256(json_encode(account))
	var/marker_digest = H.replica_digest
	equipment_assert(!R.prepare_home_retirement("replicaother", H, list(I)) && I.loc, "other owner cannot prepare replica retirement")
	H.replica_owner = "replicaother"
	equipment_assert(!R.prepare_home_retirement("replicaowner", H, list(I)) && I.loc, "marker owned by another account cannot authorize retirement")
	H.replica_owner = "replicaowner"
	H.replica_digest = ""
	equipment_assert(!R.prepare_home_retirement("replicaowner", H, list(I)) && I.loc, "partial marker binding cannot authorize replica retirement")
	H.replica_digest = marker_digest
	var/datum/extraction_surface_service/home_retirement_failure_probe/failed = new(M, "data/home_retirement_failure/")
	failed.test_suffix = "intent"
	failed.home_retirement_fail_at = "prepare_intent"
	equipment_assert(!failed.prepare_home_retirement("replicaowner", H, list(I)) && I.loc && !H.admission_available() && extraction_sha256(json_encode(M.accounts.store.load_profile("replicaowner"))) == account_digest, "interrupted replica retirement intent preserves actual gear and account")
	var/datum/extraction_surface_service/home_retirement_failure_probe/receipt_failure = new(M, "data/home_retirement_receipt_failure/")
	receipt_failure.test_suffix = "receipt"
	equipment_assert(receipt_failure.prepare_home_retirement("replicaowner", H, list(I)), "receipt failure fixture journals actual prepared root")
	equipment_assert(R.prepare_home_retirement("replicaowner", H, list(I)) && I.loc && !H.admission_available(), "replica retirement intent commits before physical removal")
	var/datum/extraction_account_store/prepared_store = R.home_retirement_store()
	var/list/prepared_receipt = prepared_store.load_profile("replicaowner")
	equipment_assert(prepared_receipt && prepared_receipt["home_retirement"]["phase"] == "prepared" && prepared_receipt["home_retirement"]["account_digest"] == account_digest, "replica retirement preparation has actual durable account-bound receipt")
	equipment_assert(R.prepare_home_retirement("replicaowner", H, list(I)), "same runtime exact retirement preparation is idempotent")
	var/datum/extraction_surface_service/restarted = new(M, "data/home_retirement_restart/")
	equipment_assert(!restarted.retire_home_replica("replicaowner", H) && I.loc, "restart cannot infer replica retirement from supplied or missing roots")
	I.extraction_found_in_raid = FALSE
	equipment_assert(!R.retire_home_replica("replicaowner", H) && I.loc, "changed actual replica graph blocks retirement before removal")
	I.extraction_found_in_raid = TRUE
	R.home_retirement_fail_at = "retire1"
	equipment_assert(!R.retire_home_replica("replicaowner", H) && !I.loc && !H.admission_available(), "partial runtime retirement leaves durable binding and admission reserved")
	R.home_retirement_fail_at = null
	receipt_failure.home_retirement_fail_at = "retirement_snapshot"
	equipment_assert(!receipt_failure.retire_home_replica("replicaowner", H) && !I.loc && !H.admission_available() && extraction_sha256(json_encode(M.accounts.store.load_profile("replicaowner"))) == account_digest, "interrupted retirement receipt preserves binding and account for recovery")
	equipment_assert(R.retire_home_replica("replicaowner", H) && R.retire_home_replica("replicaowner", H), "exact runtime retirement finishes once and replays without physical reissue")
	equipment_assert(!restarted.retire_home_replica("replicaowner", H) && !H.admission_available() && H.replica_digest == marker_digest && extraction_sha256(json_encode(M.accounts.store.load_profile("replicaowner"))) == account_digest, "retired replica receipt never releases room or account before durable world proof")
