// Included by isolated verification adapters only. No startup or world storage.
/obj/item/weapon/key/extraction_container/uncatalogued_probe
	target_map = MAP_EXTRACTION_SURVIVAL
	target_container_id = 61

/proc/container_key_assert(condition, message)
	if (!condition) CRASH("Container key contract: [message]")

/proc/container_key_catalog_probe()
	var/list/catalog = extraction_container_key_catalog()
	container_key_assert(catalog.len == 6, "six exact key types")
	var/list/targets = list()
	var/list/tables = list()
	var/list/map_sprites = list(MAP_EXTRACTION_SURVIVAL = "modern", MAP_EXTRACTION_CITY = "key", MAP_EXTRACTION_MALL = "treasure_key")
	var/datum/keyslot/native_lock = new
	for (var/path in catalog)
		var/obj/item/weapon/key/extraction_container/K = new path
		var/target_map = initial(K.target_map)
		var/target_id = initial(K.target_container_id)
		var/target = "[target_map]:[target_id]"
		container_key_assert(K.icon_state == map_sprites[target_map], "map-specific key sprite")
		container_key_assert(!targets[target], "each key opens a different exact target")
		targets[target] = TRUE
		container_key_assert(K.matches(target_map, target_id), "matching unused key")
		container_key_assert(!istype(K, /obj/item/weapon/key) && !native_lock.check_weapon(K, null, FALSE), "no generic door or closet key inheritance")
		container_key_assert(!K.matches("wrong_map", target_id) && !K.matches(target_map, target_id == 61 ? 62 : 61), "foreign and other-container rejection")
		K.target_map = "forged_map"
		K.target_container_id = 1
		K.max_uses = 999
		container_key_assert(K.matches(target_map, target_id) && !K.matches("forged_map", 1), "mutable metadata cannot retarget key")
		for (var/invalid in list(-1, 0, 1.5, 4, 999, "3"))
			K.uses_remaining = invalid
			container_key_assert(!K.valid_uses() && !K.matches(target_map, target_id), "invalid or exhausted uses cannot unlock")
		K.uses_remaining = null
		container_key_assert(!K.valid_uses(), "missing uses cannot restore defaults")
		for (var/remaining in 1 to 3)
			K.uses_remaining = remaining
			container_key_assert(K.matches(target_map, target_id), "remaining bounded uses")
		var/kind = extraction_container_key_pool_kind(target_map, target_id)
		container_key_assert(kind && !tables[kind], "independent named table per target")
		tables[kind] = TRUE
		var/datum/extraction_loot_pool/P = extraction_container_key_pool(kind)
		container_key_assert(P && P.valid(), "reward table uses supported bounded equipment")
		for (var/list/outcome in P.outcomes)
			container_key_assert(!(text2path(outcome["type"]) in catalog), "locked rewards do not contain keys")
		qdel(K)
	var/obj/item/weapon/key/extraction_container/base = new
	var/obj/item/weapon/key/extraction_container/uncatalogued_probe/unknown = new
	container_key_assert(!base.valid_uses() && !unknown.valid_uses() && !unknown.matches(MAP_EXTRACTION_SURVIVAL, 61), "base and uncatalogued child rejected")
	container_key_assert(!extraction_container_key_type("unknown_map", 61) && !extraction_container_key_pool_kind(MAP_EXTRACTION_SURVIVAL, 1) && !extraction_container_key_pool("unknown_pool"), "unknown targets and tables fail closed")
	catalog.Cut()
	container_key_assert(extraction_container_key_catalog().len == 6, "caller cannot mutate catalog")
	qdel(base)
	qdel(unknown)
	return TRUE

/proc/container_key_sprite_codec_probe()
	var/datum/extraction_equipment_codec/codec = new
	for (var/path in extraction_container_key_catalog())
		var/obj/item/weapon/key/extraction_container/K = new path
		// Restore the previous common sprite through the real equipment codec.
		K.uses_remaining = 2
		K.icon_state = "modern"
		K.color = "#ff0000"
		var/list/record = codec.encode(K)
		var/obj/item/weapon/key/extraction_container/restored = codec.decode(record, null)
		container_key_assert(restored && restored.icon_state == initial(K.icon_state) && restored.color == initial(K.color), "saved presentation restores the map sprite")
		container_key_assert(restored.uses_remaining == 2 && restored.extraction_item_id == K.extraction_item_id && restored.matches(initial(K.target_map), initial(K.target_container_id)), "sprite migration preserves key identity target and charges")
		qdel(restored)
		qdel(K)
	return TRUE

/proc/container_key_unlock_probe(obj/map_metadata/extraction_survival/M, mob/living/human/H)
	var/datum/extraction_account_store/original_store = M.loot_store
	var/datum/extraction_account_store/store = new
	store.root = "data/key_unlock_positive/"
	M.loot_store = store
	var/path = extraction_container_key_type(M.ID, 61)
	var/cache_path
	switch (M.ID)
		if (MAP_EXTRACTION_SURVIVAL) cache_path = /obj/effect/extraction_loot_marker/keyed/industrial_tool_cage
		if (MAP_EXTRACTION_CITY) cache_path = /obj/effect/extraction_loot_marker/keyed/city_pharmacy
		if (MAP_EXTRACTION_MALL) cache_path = /obj/effect/extraction_loot_marker/keyed/mall_security
	var/obj/effect/extraction_loot_marker/C
	for (var/obj/effect/extraction_loot_marker/next in extraction_loot_markers)
		if (next.container_id == 61) C = next
	var/created = !C
	if (!C) C = new cache_path(get_turf(H))
	var/list/original_profile = C.profile
	H.forceMove(get_turf(C))
	C.profile = null
	var/obj/item/weapon/key/extraction_container/K = new path(H)
	var/obj/item/weapon/key/extraction_container/foreign = new /obj/item/weapon/key/extraction_container/mall_hardware(H)
	equipment_assert(!C.prepare(M) && !C.unlock(M, H, foreign) && foreign.uses_remaining == 3, "locked cache and foreign key cannot expose rewards or consume uses")
	K.uses_remaining = 0
	equipment_assert(!C.unlock(M, H, K), "exhausted key cannot unlock")
	K.uses_remaining = 3
	C.busy = TRUE
	equipment_assert(!C.unlock(M, H, K) && K.uses_remaining == 3, "concurrent unlock rejects without consumption")
	C.busy = FALSE
	var/obj/effect/extraction_loot_marker/duplicate = new cache_path(get_turf(C))
	equipment_assert(!C.unlock(M, H, K), "duplicate live cache identity rejects before receipt")
	extraction_loot_markers -= duplicate
	qdel(duplicate)
	equipment_assert(C.unlock(M, H, K) && K.uses_remaining == 2 && C.unlock_receipt_valid(M), "unlock receipt commits before actual finite use consumption")
	C.profile = null
	equipment_assert(C.unlock(M, H, K) && K.uses_remaining == 2 && C.prepare(M), "same epoch reload reopens without charging again or rerolling")
	var/list/graph = M.codec.encode(K)
	equipment_assert(graph && graph["nodes"][1]["scalars"]["uses_remaining"] == 2, "successful extraction graph carries remaining finite key uses")
	var/obj/effect/extraction_loot_marker/ordinary = new(get_turf(H))
	ordinary.pool_kind = "workshop"
	var/list/plan = list()
	ordinary.test_key_rolls = list(99, 5)
	equipment_assert(ordinary.add_key_bonus(plan) && plan.len == 1 && plan[1]["type"] == "/obj/item/weapon/key/extraction_container/mall_hardware", "rare global roll can produce a foreign map key")
	ordinary.test_key_rolls = list(100)
	plan = list()
	equipment_assert(ordinary.add_key_bonus(plan) && !plan.len, "rare key appearance boundary rejects at one percent")
	C.test_key_rolls = list(0, 0)
	equipment_assert(C.add_key_bonus(plan) && !plan.len, "locked reward tables never add bonus keys")
	extraction_loot_markers -= ordinary
	qdel(ordinary)
	for (var/scenario in list("receipt_crash", "ack_failure"))
		store = new
		store.root = "data/key_unlock_[scenario]/"
		M.loot_store = store
		C.profile = null
		C.locked = FALSE
		C.unlock_recovery_required = FALSE
		C.test_fail_after_unlock_receipt = scenario == "receipt_crash"
		C.test_fail_unlock_ack = scenario == "ack_failure"
		K.uses_remaining = 3
		equipment_assert(!C.unlock(M, H, K) && H.extraction_session.locked && C.unlock_recovery_required, "ambiguous unlock quarantines account without replacement minting")
		equipment_assert(K.uses_remaining == (scenario == "receipt_crash" ? 3 : 2), "receipt interruption never adds key uses or replaces physical key")
		H.extraction_session.locked = FALSE // Fixture release to check durable marker denial.
		C.locked = FALSE
		C.profile = null
		equipment_assert(!C.unlock(M, H, K) && H.extraction_session.locked, "pending receipt reload cannot replay or unlock")
		H.extraction_session.locked = FALSE
	// Storage namespace test uses map IDs only, not a live map transition.
	var/old_id = M.ID
	store = new
	store.root = "data/key_namespace/"
	M.loot_store = store
	var/datum/extraction_account_store/first = C.journal_store(M)
	var/list/first_profile = first.load_profile("container61")
	first.test_fail_at = "intent"
	equipment_assert(!first.commit_profile("container61", first_profile) && !first.load_profile("container61"), "one map cache interrupted journal is quarantined")
	M.ID = old_id == MAP_EXTRACTION_CITY ? MAP_EXTRACTION_SURVIVAL : MAP_EXTRACTION_CITY
	var/datum/extraction_account_store/second = C.journal_store(M)
	var/list/second_profile = second.load_profile("container61")
	equipment_assert(first.root != second.root && second_profile && second.commit_profile("container61", second_profile), "same numbered foreign map cache journal remains independent")
	M.ID = old_id
	C.test_fail_after_unlock_receipt = FALSE
	C.test_fail_unlock_ack = FALSE
	C.unlock_recovery_required = FALSE
	C.locked = FALSE
	C.profile = original_profile
	M.loot_store = original_store
	qdel(K)
	qdel(foreign)
	if (created)
		extraction_loot_markers -= C
		qdel(C)
