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
	equipment_assert(I && I.loc == H && I.extraction_found_in_raid && C.profile["stash"]:len == 0, "claim durably debits before delivering native raid item")
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
