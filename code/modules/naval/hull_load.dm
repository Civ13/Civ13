// ============================================================
// Load and ballast (docs/hull-ledger.md)
// ------------------------------------------------------------
// Everything standing or lying on a boat's or ship's deck weighs on her.
// The weight is counted in tiles of hull, the same measure her drives push,
// and it is added up in the walk of her deck that fit_drives() already makes
// before every hop, so it costs no walk of its own while she sails.
//
// - Her burden is half a tile of weight for every tile of hull. Up to that
//   she carries her load for nothing.
// - Past her burden she is deep laden: every tile of weight over it is one
//   more tile for her drives to push, like water in the bilge.
// - Past twice her burden she is overladen: under way the sea slops over
//   her side, a bucketful a minute for every tile of weight over the mark.
//   It stops at awash, so greed alone does not sink her.
// - A ship with masts wants weight low in her to stand up to her sails:
//   a twentieth of her tiles for each rigged mast. Without it she is crank, and
//   under sail in a strong wind she heels and ships water over the rail.
//   Any load is ballast; stone is the cheap kind.
//
// Small craft are left out. The weight is not saved: it is counted again.
// ============================================================

#define HULL_BURDEN_PER_TILE 0.5
#define HULL_OVERLADEN 2
#define HULL_SLOP_PER_TILE_MINUTE 1
#define HULL_BALLAST_PER_MAST 0.05
#define HULL_CRANK_WIND 3
#define HULL_CRANK_PER_MINUTE 10

#define HULL_LADEN_LIGHT 0
#define HULL_LADEN_DEEP 1
#define HULL_LADEN_OVER 2

// What this weighs on a deck, in tiles of hull.
/atom/movable/proc/hull_load()
	return 0

/mob/living/hull_load()
	return 0.2

/obj/item/hull_load()
	return w_class >= ITEM_SIZE_LARGE ? 0.1 : 0.02

// A full stack of fifty weighs like a tile of hull.
/obj/item/stack/hull_load()
	return amount * 0.02

/obj/structure/hull_load()
	return density ? 0.5 : 0.1

// A chest or crate and what is in it.
/obj/structure/closet/hull_load()
	return 0.5 + 0.02 * contents.len

/obj/structure/cannon/hull_load()
	return 1.5

/obj/structure/engine/hull_load()
	return 1

/obj/structure/vehicleparts/movement/sail/hull_load()
	return 0.5

// Her own floors are her hull; what is built up on them is weight.
/obj/covers/hull_load()
	return wall ? 0.3 : 0

/datum/hull_ledger
	// Weight on her deck in tiles of hull, as last counted, and her rigged
	// masts.
	var/tmp/load = 0
	var/tmp/masts = 0
	var/tmp/laden_told = HULL_LADEN_LIGHT
	var/tmp/crank_told = FALSE

// TRUE when load and ballast count for her.
/datum/hull_ledger/proc/carries_load()
	return hull_class() != HULL_CLASS_SMALL

// The weight she carries for nothing.
/datum/hull_ledger/proc/burden()
	return tiles * HULL_BURDEN_PER_TILE

// Tiles of hull her load weighs on her drives.
/datum/hull_ledger/proc/load_weight()
	if (!carries_load())
		return 0
	return max(0, round(load - burden()))

/datum/hull_ledger/proc/laden()
	if (!carries_load() || load <= burden())
		return HULL_LADEN_LIGHT
	return load > burden() * HULL_OVERLADEN ? HULL_LADEN_OVER : HULL_LADEN_DEEP

// The weight a ship with masts wants low in her, and whether she lacks it.
/datum/hull_ledger/proc/ballast_wanted()
	if (hull_class() != HULL_CLASS_SHIP || masts <= 0)
		return 0
	return tiles * HULL_BALLAST_PER_MAST * masts

/datum/hull_ledger/proc/crank()
	return ballast_wanted() > 0 && load < ballast_wanted()

// The count from a walk of her deck. Her crew hears when she goes a mark
// deeper.
/datum/hull_ledger/proc/set_load(weight, rigged_masts)
	load = max(0, weight)
	masts = max(0, rigged_masts)
	var/now = laden()
	if (now > laden_told && craft)
		if (now == HULL_LADEN_OVER)
			craft.crew_message(SPAN_DANGER("The [craft.name] is overladen: she rides so low that the sea slops over her side while she sails. Lighten her."))
		else
			craft.crew_message(SPAN_WARNING("The [craft.name] is deep laden: she carries more than her burden and is slower for it."))
	laden_told = now

// Walks her deck and counts, for a hull lying still.
/datum/hull_ledger/proc/survey_load()
	if (!craft || !craft.body || !carries_load())
		return
	var/weight = 0
	var/rigged = 0
	for (var/atom/movable/M in craft.body.aboard())
		weight += M.hull_load()
		if (istype(M, /obj/structure/vehicleparts/movement/sail))
			var/obj/structure/vehicleparts/movement/sail/S = M
			if (S.sails && !S.broken)
				rigged++
	set_load(weight, rigged)

// TRUE when a sail is pushing her now.
/datum/hull_ledger/proc/under_sail()
	if (!under_way())
		return FALSE
	for (var/datum/craft_drive/fitted/sail/D in craft.drives)
		if (D.ready())
			return TRUE
	return FALSE

// One step of what her load lets in.
/datum/hull_ledger/proc/step_load(seconds)
	if (!carries_load())
		return
	if (!under_way())
		survey_load()
		return
	if (laden() == HULL_LADEN_OVER)
		add_water((load - burden() * HULL_OVERLADEN) * HULL_SLOP_PER_TILE_MINUTE * seconds / 60)
	if (crank() && under_sail())
		var/turf/at = craft.body.origin()
		if (at && weather_wind_at(at) >= HULL_CRANK_WIND)
			add_water(HULL_CRANK_PER_MINUTE * seconds / 60)
			if (!crank_told)
				crank_told = TRUE
				craft.crew_message(SPAN_DANGER("The [craft.name] heels hard in this wind and ships water over her rail: she is crank, with too little weight low in her for her sails. Ballast her with stone or cargo, or take in sail."))
			return
	crank_told = FALSE

/datum/hull_ledger/proc/load_text()
	if (!carries_load())
		return ""
	. = " She carries [round(load, 0.1)] tile\s of weight against a burden of [round(burden(), 0.1)]"
	switch (laden())
		if (HULL_LADEN_DEEP)
			. += ": deep laden, weighing on her like [load_weight()] more tile\s of hull."
		if (HULL_LADEN_OVER)
			. += ": <b>overladen</b>, weighing on her like [load_weight()] more tile\s of hull and shipping water under way."
		else
			. += "."
	if (crank())
		. += " <b>She is crank:</b> [masts] rigged mast\s want [round(ballast_wanted(), 0.1)] tile\s of weight low in her. Stone or cargo will do."

#undef HULL_BURDEN_PER_TILE
#undef HULL_OVERLADEN
#undef HULL_SLOP_PER_TILE_MINUTE
#undef HULL_BALLAST_PER_MAST
#undef HULL_CRANK_WIND
#undef HULL_CRANK_PER_MINUTE
