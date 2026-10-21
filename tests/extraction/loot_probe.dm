/proc/loot_mode_probe(obj/map_metadata/extraction_survival/M, mob/living/human/H)
	for (var/obj/effect/extraction_loot_marker/C in extraction_loot_markers)
		equipment_assert(!C.profile && !C.contents.len, "untouched containers remain ungenerated")
	var/datum/extraction_loot_pool/ammo = new("ammunition")
	ammo.test_rolls = list(0, 0, 7999, 999)
	var/list/plan = ammo.plan()
	equipment_assert(plan && plan.len == 2, "chance and weighted endpoints produce bounded ammo/key outcomes")
	var/list/common = plan[1]
	var/list/rare = plan[2]
	equipment_assert(common["type"] == "/obj/item/ammo_magazine/m9beretta" && common["quantity"] == 2 && rare["type"] == "/obj/item/weapon/key/extraction_room", "container table type and quantity differentiation")
	ammo.test_rolls = list(8000, 9999)
	equipment_assert(ammo.plan().len == 0, "exact appearance boundary and high endpoint produce empty outcomes")
	var/list/outcome = ammo.outcomes[1]
	outcome["weight"] = -1
	equipment_assert(!ammo.plan(), "negative weight rejected without rolling")
	outcome["weight"] = 10000
	equipment_assert(!ammo.plan(), "excess aggregate weight rejected")
	outcome["weight"] = 900
	outcome["type"] = "/mob/living/human"
	equipment_assert(!ammo.plan(), "incompatible loot type rejected before constructors")
	var/obj/effect/extraction_loot_marker/C = extraction_loot_markers[1]
	C.test_pool = new("workshop")
	C.test_pool.test_rolls = list(0, 0, 9999, 9999)
	equipment_assert(C.prepare(M) && C.profile["stash"]:len == 1 && !C.contents.len, "first access commits one result before exposure")
	var/encoded = json_encode(C.profile)
	C.busy = TRUE
	H.forceMove(get_turf(C))
	C.attack_hand(H)
	equipment_assert(json_encode(C.profile) == encoded, "concurrent open guard cannot mutate or expose generated contents")
	C.busy = FALSE
	equipment_assert(C.prepare(M) && json_encode(C.profile) == encoded, "repeated open does not reroll or recommit")
	C.profile = null
	equipment_assert(C.prepare(M) && json_encode(C.profile) == encoded, "container journal reload retains exact generated result")
	var/list/stash = C.profile["stash"]
	var/list/entry = stash[1]
	H.forceMove(get_turf(C))
	var/obj/item/I = C.claim(M, H, entry["id"])
	equipment_assert(I && I.loc == H && (H.l_hand == I || H.r_hand == I) && I.extraction_found_in_raid && C.profile["stash"]:len == 0, "claim durably debits before delivering usable native hand item")
	equipment_assert(!C.claim(M, H, entry["id"]), "same generated item cannot be claimed twice")
	qdel(I)
	C.profile = null
	equipment_assert(C.prepare(M) && C.profile["stash"]:len == 0, "claimed container remains empty after reload")
	C = extraction_loot_markers[2]
	C.test_pool = new("armory")
	C.test_pool.test_rolls = list(9999)
	equipment_assert(C.prepare(M) && C.profile["stash"]:len == 0, "empty armory generation commits once")
	C.profile = null
	equipment_assert(C.prepare(M) && C.profile["stash"]:len == 0, "empty result persists and cannot reroll")
	equipment_assert(flist("data/extraction_loot/").len == 2, "only accessed containers create bounded journal directories")
	C = extraction_loot_markers[3]
	C.test_pool = new("workshop")
	C.test_pool.test_rolls = list(0,0,0,0,9999)
	C.test_fail_constructor_after = 1
	equipment_assert(!C.prepare(M) && C.profile["loot_state"] == "planned" && !C.contents.len, "partial constructor failure retains committed plan without exposing objects")
	var/saved_plan = json_encode(C.profile["loot_plan"])
	C.test_fail_constructor_after = null
	C.profile = null
	equipment_assert(C.prepare(M) && C.profile["stash"]:len == 2 && json_encode(C.profile["loot_plan"]) == saved_plan && !C.test_pool.test_rolls.len, "failed construction reload retries the same plan without new random draws")
	stash = C.profile["stash"]
	entry = stash[1]
	H.forceMove(get_turf(C))
	C.test_fail_delivery_ack = TRUE
	equipment_assert(!C.claim(M, H, entry["id"]) && C.locked, "interrupted delivery acknowledgment retires live copy and locks recovery")
	M.loot_store.test_fail_at = null
	C.profile = null
	equipment_assert(!C.prepare(M), "interrupted claim cannot reroll or replay")
	var/datum/extraction_account_store/restart = new
	restart.root = "data/extraction_loot/"
	equipment_assert(!restart.load_profile("container[C.container_id]"), "native restart rejects incomplete delivery journal instead of rolling back")
	for (var/kind in list("workshop", "ammunition", "armory"))
		var/datum/extraction_loot_pool/P = new(kind)
		P.test_rolls = list(0,0,0,0,0,0,0,0)
		plan = P.plan()
		var/quantity = 0
		for (var/list/next in plan) quantity += next["quantity"]
		equipment_assert(plan.len <= 4 && quantity <= 8, "maximum appearance/quantity endpoints remain bounded")
	loot_hand_delivery_probe(M, H)

// Only the acknowledgement boundary is injected; construction, real hand
// assignment, journal commits, floor movement and stack callbacks are production.
/obj/effect/extraction_loot_marker/hand_delivery_probe
	var/mob/living/human/claim_actor
	var/turf/move_after_ack
	var/obj/item/observed_root
	commit_container(obj/map_metadata/extraction_survival/M, list/candidate)
		var/acknowledging = profile && profile["loot_state"] == "pending" && candidate["loot_state"] == "ready"
		if (acknowledging)
			var/list/pending = profile["pending_item"]
			for (var/obj/item/I in M.raid_items)
				if (I.extraction_item_id == pending["id"]) observed_root = I
			equipment_assert(observed_root && observed_root.loc && !observed_root.loc.loc && observed_root.loc != claim_actor && claim_actor.l_hand != observed_root && claim_actor.r_hand != observed_root, "unacknowledged claim stays privately staged outside actual hands")
		. = ..()
		if (. && acknowledging && move_after_ack) claim_actor.forceMove(move_after_ack)

/proc/loot_hand_delivery_probe(obj/map_metadata/extraction_survival/M, mob/living/human/H)
	var/turf/origin = get_turf(H)
	var/obj/item/old_left = H.l_hand
	var/obj/item/old_right = H.r_hand
	if (old_left) H.drop_from_inventory(old_left)
	if (old_right) H.drop_from_inventory(old_right)
	for (var/case in 1 to 4)
		var/obj/effect/extraction_loot_marker/hand_delivery_probe/C = new(origin)
		C.container_id = 59 + case
		C.claim_actor = H
		C.test_pool = new("supplies")
		C.test_pool.slots = 1
		C.test_pool.chance = 10000
		C.test_pool.outcomes = list(list("type" = "/obj/item/stack/material/steel", "rarity" = "common", "weight" = 10000, "quantity" = 1))
		C.test_pool.test_rolls = list(0, 0)
		equipment_assert(C.prepare(M) && C.profile["stash"]:len == 1, "hand-delivery case prepares one stable root")
		var/list/stash = C.profile["stash"]
		var/list/entry = stash[1]
		var/obj/item/extraction_salvage/left = new(null)
		var/obj/item/extraction_salvage/right = new(null)
		equipment_assert(H.put_in_active_hand(left) && H.get_active_hand() == left, "delivery control occupies actual active hand")
		if (case != 1) equipment_assert(H.put_in_inactive_hand(right) && H.get_inactive_hand() == right, "delivery control occupies both actual hands")
		var/obj/item/stack/material/steel/existing = new(origin)
		var/existing_amount = existing.amount
		if (case == 3) C.move_after_ack = locate(origin.x + 3, origin.y + 3, origin.z)
		if (case == 4) C.test_fail_delivery_ack = TRUE
		var/obj/item/I = C.claim(M, H, entry["id"])
		if (case == 1)
			equipment_assert(I && H.get_inactive_hand() == I && H.get_active_hand() == left && I.loc == H, "occupied active hand delivers original loot into actual inactive hand")
		else if (case == 2 || case == 3)
			equipment_assert(I && I.loc == origin && I.extraction_item_id == entry["id"] && existing.amount == existing_amount && H.l_hand != I && H.r_hand != I, "full hands or moved actor leaves original stable loot accessible at original raid floor without stack merge")
			if (case == 3) equipment_assert(get_turf(H) != origin, "acknowledgement movement control actually moved claimant")
		else
			equipment_assert(!I && C.locked && C.observed_root?.loc == null && H.get_active_hand() == left && H.get_inactive_hand() == right && existing.amount == existing_amount, "failed acknowledgement exposes no loot and preserves both actual hands and floor stack")
			M.loot_store.test_fail_at = null
			C.profile = null
			equipment_assert(!C.prepare(M), "failed hand delivery remains recovery-blocked without replay")
		if (I) qdel(I)
		qdel(left)
		qdel(right)
		qdel(existing)
		extraction_loot_markers -= C
		qdel(C)
		H.forceMove(origin)
	if (old_left) H.put_in_l_hand(old_left)
	if (old_right) H.put_in_r_hand(old_right)
