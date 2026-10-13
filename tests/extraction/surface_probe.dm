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
	M.accounts.sessions = sessions
	M.round_closing = old_closing
	M.game_over = old_over
	qdel(S)
	qdel(R)
