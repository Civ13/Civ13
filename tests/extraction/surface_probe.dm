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
