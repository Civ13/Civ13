// ============================================================
// Hull weight (docs/craft-core.md "Hull weight")
// ------------------------------------------------------------
// A built hull's mass is counted in tiles of hull: a tile of plank floor is
// one. A floor of another material weighs against planks by the same table
// that weighs vehicle hulls (vehicle_hull_stats() in vehicle_hulls.dm), so a
// steel deck is heavier and an aluminium one lighter, by the rule that makes
// an aluminium car faster. Every tile of her other decks (the deck above, a
// second deck above, her hold) weighs like a tile of her main deck in its own
// floor, so a taller ship needs more drive for the same speed.
//
// The count is made in the walk of her deck that fit_drives() makes before
// every hop (hull_drives.dm), so it costs no walk of its own. Not saved.
// Airships weigh their decks for lift by their own table (air_hull.dm).
// ============================================================

/datum/craft
	// Tiles of hull her floors weigh beyond one plank tile each, as last counted.
	var/tmp/structure_weight = 0

// The vehicle hull material a floor is made of, for vehicle_hull_stats().
/proc/hull_floor_material(obj/covers/C)
	switch (lowertext("[C.material]"))
		if ("aluminium", "aluminum")
			return "aluminium"
		if ("steel", "iron", "stone", "concrete")
			return "steel"
	return "wood"

// What a tile of this floor weighs in tiles of plank hull.
/proc/hull_floor_weight(obj/covers/C)
	return hull_material_weight(hull_floor_material(C))

/proc/hull_material_weight(hull)
	var/list/plank = vehicle_hull_stats("wood")
	var/list/stats = vehicle_hull_stats(hull)
	return round((stats ? stats[1] : 1) / plank[1], 0.01)

// TRUE when this body's floors weigh on her drives here.
/datum/craft_body/proc/weighs_floors()
	return FALSE

/datum/craft_body/built/weighs_floors()
	return TRUE

/datum/craft_body/built/air/weighs_floors()
	return FALSE

// Counts her floors from the walk of fit_drives(): what they weigh past one
// plank tile for each tile of her main deck. Each tile counts one floor.
/datum/craft/proc/count_structure(list/aboard)
	structure_weight = 0
	if (!body || !body.weighs_floors())
		return 0
	var/weight = 0
	var/list/seen = list()
	for (var/obj/covers/C in aboard)
		if (C.wall || seen[C.loc])
			continue
		seen[C.loc] = TRUE
		weight += hull_floor_weight(C)
	structure_weight = round(weight - body.tile_count(), 0.1)
	return structure_weight
