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
	var/datum/keyslot/native_lock = new
	for (var/path in catalog)
		var/obj/item/weapon/key/extraction_container/K = new path
		var/target_map = initial(K.target_map)
		var/target_id = initial(K.target_container_id)
		var/target = "[target_map]:[target_id]"
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
