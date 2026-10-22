// Fixed, bounded catalog. Targets come from concrete type defaults, never
// account scalars or a generic numeric door code. Return fresh lists to callers.
/proc/extraction_container_key_catalog()
	return list(/obj/item/weapon/key/extraction_container/industrial_tool_cage, /obj/item/weapon/key/extraction_container/industrial_dispatch, /obj/item/weapon/key/extraction_container/city_pharmacy, /obj/item/weapon/key/extraction_container/city_evidence, /obj/item/weapon/key/extraction_container/mall_security, /obj/item/weapon/key/extraction_container/mall_hardware)

/proc/extraction_container_key_type(map_id, container_id)
	for (var/path in extraction_container_key_catalog())
		var/obj/item/weapon/key/extraction_container/prototype = path
		if (initial(prototype.target_map) == map_id && initial(prototype.target_container_id) == container_id) return path
	return null

/obj/item/weapon/key/extraction_container
	// Generic keys can re-key native closets. These exact-target tokens must not
	// inherit that capability, despite their human-readable key namespace.
	parent_type = /obj/item
	name = "worn container key"
	desc = "A fragile key for one specific cache. Each successful unlock wears it down."
	icon = 'icons/obj/key.dmi'
	icon_state = "modern"
	item_state = "key"
	w_class = ITEM_SIZE_TINY
	dropsound = 'sound/effects/drop_knife.ogg'
	var/target_map
	var/target_container_id = 0
	var/target_container_label = "unidentified cache"
	var/max_uses = 3
	var/uses_remaining = 3
	after_load()
		..()
		// Old equipment records stored the shared key sprite. Presentation comes
		// from this exact key type; restoring it must never replenish charges.
		icon = initial(icon)
		icon_state = initial(icon_state)
		item_state = initial(item_state)
		color = initial(color)
	proc/valid_uses()
		return (type in extraction_container_key_catalog()) && isnum(uses_remaining) && round(uses_remaining) == uses_remaining && uses_remaining >= 1 && uses_remaining <= initial(max_uses)
	proc/matches(map_id, container_id)
		return valid_uses() && initial(target_map) == map_id && initial(target_container_id) == container_id && extraction_container_key_type(map_id, container_id) == type
	proc/target_hint()
		return "Opens only: [initial(target_container_label)]."
	examine(mob/user)
		..(user)
		to_chat(user, SPAN_NOTICE(target_hint()))
		to_chat(user, SPAN_NOTICE("[uses_remaining] of [initial(max_uses)] unlocks remain."))

/obj/item/weapon/key/extraction_container/industrial_tool_cage
	name = "Industrial District tool cage key"
	icon_state = "modern"
	desc = "Tagged for the locked maintenance stock cage in the southwest warehouse of Industrial District."
	target_map = MAP_EXTRACTION_SURVIVAL
	target_container_id = 61
	target_container_label = "maintenance stock cage, southwest warehouse, Industrial District"
/obj/item/weapon/key/extraction_container/industrial_dispatch
	name = "Industrial District dispatch locker key"
	icon_state = "modern"
	desc = "Tagged for the dispatch reserves locker in the central warehouse of Industrial District."
	target_map = MAP_EXTRACTION_SURVIVAL
	target_container_id = 62
	target_container_label = "dispatch reserves locker, central warehouse, Industrial District"
/obj/item/weapon/key/extraction_container/city_pharmacy
	name = "Modern City pharmacy cabinet key"
	icon_state = "key"
	desc = "Tagged for the pharmacy's sealed treatment cabinet in the southwest block of Modern City."
	target_map = MAP_EXTRACTION_CITY
	target_container_id = 61
	target_container_label = "pharmacy treatment cabinet, southwest block, Modern City"
/obj/item/weapon/key/extraction_container/city_evidence
	name = "Modern City evidence locker key"
	icon_state = "key"
	desc = "Tagged for the abandoned evidence locker in the north central block of Modern City."
	target_map = MAP_EXTRACTION_CITY
	target_container_id = 62
	target_container_label = "evidence locker, north central block, Modern City"
/obj/item/weapon/key/extraction_container/mall_security
	name = "Interchange Mall security cache key"
	icon_state = "treasure_key"
	desc = "Tagged for the Transit security cache on Interchange Mall's retail floor."
	target_map = MAP_EXTRACTION_MALL
	target_container_id = 61
	target_container_label = "Transit security cache, retail floor, Interchange Mall"
/obj/item/weapon/key/extraction_container/mall_hardware
	name = "Interchange Mall hardware reserves key"
	icon_state = "treasure_key"
	desc = "Tagged for the Foundry hardware reserves chest on Interchange Mall's retail floor."
	target_map = MAP_EXTRACTION_MALL
	target_container_id = 62
	target_container_label = "Foundry hardware reserves chest, retail floor, Interchange Mall"

// Gameplay access and the unlock receipt belong to the shared loot journal.
// These mapped subtypes bind a unique container to its own named reward table.
/obj/effect/extraction_loot_marker/keyed
	icon_state = "securecrate"
	name = "locked scavenger cache"
	desc = "The surviving lock needs the exact key named on this container."
/obj/effect/extraction_loot_marker/keyed/industrial_tool_cage
	name = "Industrial District maintenance stock cage"
	container_id = 61
	pool_kind = "locked_industrial_tools"
/obj/effect/extraction_loot_marker/keyed/industrial_dispatch
	name = "Industrial District dispatch reserves locker"
	container_id = 62
	pool_kind = "locked_industrial_dispatch"
/obj/effect/extraction_loot_marker/keyed/city_pharmacy
	name = "Modern City pharmacy treatment cabinet"
	container_id = 61
	pool_kind = "locked_city_pharmacy"
/obj/effect/extraction_loot_marker/keyed/city_evidence
	name = "Modern City evidence locker"
	container_id = 62
	pool_kind = "locked_city_evidence"
/obj/effect/extraction_loot_marker/keyed/mall_security
	name = "Interchange Mall Transit security cache"
	container_id = 61
	pool_kind = "locked_mall_security"
/obj/effect/extraction_loot_marker/keyed/mall_hardware
	name = "Interchange Mall Foundry hardware reserves"
	container_id = 62
	pool_kind = "locked_mall_hardware"

/proc/extraction_container_key_pool_kind(map_id, container_id)
	switch (extraction_container_key_type(map_id, container_id))
		if (/obj/item/weapon/key/extraction_container/industrial_tool_cage) return "locked_industrial_tools"
		if (/obj/item/weapon/key/extraction_container/industrial_dispatch) return "locked_industrial_dispatch"
		if (/obj/item/weapon/key/extraction_container/city_pharmacy) return "locked_city_pharmacy"
		if (/obj/item/weapon/key/extraction_container/city_evidence) return "locked_city_evidence"
		if (/obj/item/weapon/key/extraction_container/mall_security) return "locked_mall_security"
		if (/obj/item/weapon/key/extraction_container/mall_hardware) return "locked_mall_hardware"
	return null

// Each cache has an independent table. Ordinary first-access loot supplies the
// rare global key bonus; locked rewards do not roll an additional key bonus.
/proc/extraction_container_key_pool(kind)
	var/datum/extraction_loot_pool/P = new
	P.slots = 3
	P.chance = 10000
	switch (kind)
		if ("locked_industrial_tools")
			P.outcomes = list(list("type" = "/obj/item/extraction_salvage", "rarity" = "common", "weight" = 600, "quantity" = 2), list("type" = "/obj/item/stack/material/steel", "rarity" = "common", "weight" = 250, "quantity" = 2), list("type" = "/obj/item/stack/material/copper", "rarity" = "rare", "weight" = 150, "quantity" = 2))
		if ("locked_industrial_dispatch")
			P.outcomes = list(list("type" = "/obj/item/weapon/reagent_containers/glass/barrel/jerrycan/gasoline", "rarity" = "rare", "weight" = 400, "quantity" = 1), list("type" = "/obj/item/stack/material/cloth", "rarity" = "common", "weight" = 300, "quantity" = 2), list("type" = "/obj/item/stack/material/leather", "rarity" = "common", "weight" = 300, "quantity" = 2))
		if ("locked_city_pharmacy")
			P.outcomes = list(list("type" = "/obj/item/stack/medical/bruise_pack/bint", "rarity" = "rare", "weight" = 600, "quantity" = 1), list("type" = "/obj/item/stack/medical/splint", "rarity" = "rare", "weight" = 300, "quantity" = 1), list("type" = "/obj/item/stack/material/cloth", "rarity" = "common", "weight" = 100, "quantity" = 2))
		if ("locked_city_evidence")
			P.slots = 2
			P.outcomes = list(list("type" = "/obj/item/weapon/gun/projectile/pistol/m9beretta", "rarity" = "rare", "weight" = 500, "quantity" = 1), list("type" = "/obj/item/ammo_magazine/m9beretta", "rarity" = "common", "weight" = 300, "quantity" = 2), list("type" = "/obj/item/stack/material/gold", "rarity" = "exceptional", "weight" = 200, "quantity" = 1))
		if ("locked_mall_security")
			P.slots = 2
			P.outcomes = list(list("type" = "/obj/item/stack/material/kevlar", "rarity" = "rare", "weight" = 400, "quantity" = 2), list("type" = "/obj/item/weapon/gun/projectile/pistol/m9beretta", "rarity" = "rare", "weight" = 300, "quantity" = 1), list("type" = "/obj/item/ammo_magazine/m9beretta", "rarity" = "common", "weight" = 300, "quantity" = 2))
		if ("locked_mall_hardware")
			P.outcomes = list(list("type" = "/obj/item/stack/cable_coil", "rarity" = "common", "weight" = 350, "quantity" = 2), list("type" = "/obj/item/stack/material/glass", "rarity" = "common", "weight" = 300, "quantity" = 2), list("type" = "/obj/item/stack/material/copper", "rarity" = "rare", "weight" = 250, "quantity" = 2), list("type" = "/obj/item/weapon/attachment/scope/adjustable/advanced/reddot", "rarity" = "exceptional", "weight" = 100, "quantity" = 1))
		else
			return null
	return P
