// Offshore drilling rigs (persistent-zones "offshore rigs" roadmap item).
//
// A steel oil well raised on a bridge deck over the open sea. It needs no
// petroleum spring: it drills into a seabed oil field instead. Fields are a
// fixed property of each map's sea, derived from the map ID and the tile's
// coordinates, so they need no saved state, survive restarts and are the same
// for every player. The sea is split into OFFSHORE_FIELD_CELL-tile squares;
// about one square in OFFSHORE_FIELD_ODDS holds a field of richness 1-3.
// Richness sets how much petroleum each pumping cycle yields.
//
// Building: stand on a steel bridge deck laid over deep saltwater above a
// field. The rig stands on the deck tile and is serviced like any oil well:
// load a barrel, take it off full, or connect factory pipes.

#define OFFSHORE_FIELD_CELL 8
#define OFFSHORE_FIELD_ODDS 3
#define OFFSHORE_FIELD_HASH_MOD 65521
#define OFFSHORE_RIG_YIELD_PER_RICHNESS 10

// A stable number for the current map. Every step stays below 2^24, so the
// float arithmetic is exact and matches tests/offshore_rig/model.py.
/proc/offshore_map_seed()
	var/id = (map && map.ID) ? "[map.ID]" : ""
	var/seed = 7
	for (var/i = 1, i <= length(id), i++)
		seed = (seed * 31 + text2ascii(id, i)) % OFFSHORE_FIELD_HASH_MOD
	return seed

/proc/offshore_field_hash(seed, cell_x, cell_y, z)
	var/h = seed % OFFSHORE_FIELD_HASH_MOD
	h = (h * 31 + cell_x) % OFFSHORE_FIELD_HASH_MOD
	h = (h * 31 + cell_y) % OFFSHORE_FIELD_HASH_MOD
	h = (h * 31 + z) % OFFSHORE_FIELD_HASH_MOD
	for (var/i = 1, i <= 3, i++)
		h = (h * 251 + 17) % OFFSHORE_FIELD_HASH_MOD
	return h

// Richness 0-3 of the field under deep saltwater coordinates.
/proc/offshore_field_richness_at(seed, x, y, z)
	var/h = offshore_field_hash(seed, round((x - 1) / OFFSHORE_FIELD_CELL), round((y - 1) / OFFSHORE_FIELD_CELL), z)
	if (h % OFFSHORE_FIELD_ODDS)
		return 0
	return 1 + (round(h / OFFSHORE_FIELD_ODDS) % 3)

// Open-sea surface water: deep saltwater, not the seabed layer.
/proc/offshore_sea_turf(turf/T)
	return istype(T, /turf/floor/beach/water/deep/saltwater) && !istype(T, /turf/floor/beach/water/deep/saltwater/underwater)

/proc/offshore_oil_richness(turf/T)
	if (!offshore_sea_turf(T))
		return 0
	return offshore_field_richness_at(offshore_map_seed(), T.x, T.y, T.z)

/proc/offshore_richness_text(richness)
	switch (richness)
		if (1)
			return "a thin"
		if (2)
			return "a good"
		if (3)
			return "a rich"
	return "no"

// Null when user may build result_type where they stand, otherwise why not.
/proc/offshore_rig_build_refusal(mob/user, result_type)
	if (!ispath(result_type, /obj/structure/oilwell/offshore))
		return null
	var/turf/T = user ? user.loc : null
	if (!isturf(T) || !offshore_sea_turf(T) || !bridge_deck_at(T))
		return "Stand on a steel bridge deck over the open sea to build an offshore rig."
	if (locate(/obj/structure/oilwell) in T)
		return "There is already a well on this deck."
	for (var/obj/O in T)
		if (O.density)
			return "There is no room for a rig on this deck."
	if (!offshore_oil_richness(T))
		return "Your soundings find no oil beneath this stretch of sea. Try another spot further out."
	return null

/obj/structure/oilwell/offshore
	name = "offshore drilling rig"
	desc = "A steel derrick on a bridge deck, drilling into an oil field under the seabed. It pumps petroleum into a barrel."
	icon_state = "oilwell_metal"
	flammable = FALSE

/obj/structure/oilwell/offshore/proc/richness()
	return isturf(loc) ? offshore_oil_richness(loc) : 0

// No spring: the seabed field is the source.
/obj/structure/oilwell/offshore/link_to_spring(load_floor_barrel = FALSE)
	base = null
	load_barrel(load_floor_barrel)
	start_extraction()

/obj/structure/oilwell/offshore/has_source()
	return richness() > 0

/obj/structure/oilwell/offshore/pump_batch()
	work_barrel.reagents.add_reagent("petroleum", min(work_barrel.reagents.get_free_space(), OFFSHORE_RIG_YIELD_PER_RICHNESS * richness()))

/obj/structure/oilwell/offshore/examine(mob/user)
	..()
	var/richness = richness()
	to_chat(user, "It is drilling into [offshore_richness_text(richness)] oil field[richness ? ", about [OFFSHORE_RIG_YIELD_PER_RICHNESS * richness] units of petroleum every two minutes" : ""].")
	if (work_barrel && work_barrel.loc == src && work_barrel.reagents)
		to_chat(user, "Its barrel holds [work_barrel.reagents.total_volume] of [work_barrel.reagents.maximum_volume] units.")
	else
		to_chat(user, "No barrel is connected.")

/obj/structure/oilwell/offshore/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/hammer))
		hammer_action(user, W, 400, list("/obj/item/stack/material/steel"), list(34))
		return
	..(W, user)

#undef OFFSHORE_FIELD_CELL
#undef OFFSHORE_FIELD_ODDS
#undef OFFSHORE_FIELD_HASH_MOD
#undef OFFSHORE_RIG_YIELD_PER_RICHNESS
