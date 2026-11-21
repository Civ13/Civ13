// ============================================================
// A hull's sides: gunwales and bulwarks (docs/ship-edges.md)
// ------------------------------------------------------------
// A boat or ship has a defined edge. Every side of a deck tile that is not
// joined to another deck tile is open until it is closed by:
// - a gunwale (wood) or bulwark (steel) along it: a railing built for a hull,
//   or any other built railing or railing gate;
// - a wall, window or door standing on that tile, which fills it whole.
//
// Small craft (rafts, canoes: up to HULL_SMALL_MAX_TILES tiles) are left
// open. A boat or ship is not commissioned, or refitted, from her tiller
// until every side is closed; "Rail her sides" at the tiller fits gunwales on
// the open ones from the stack in hand. A hull already afloat keeps sailing
// with open sides until it is refitted, and the tiller says how many it has.
//
// Gunwales are part of her hull: they weigh nothing on her deck, sail and
// turn with her like anything else standing on it, and shots fly over them.
// People climb over a gunwale like a railing; going over into the water asks
// first.
// ============================================================

#define HULL_RAIL_TIME 10        // ds to fit one gunwale with Rail her sides
#define HULL_SIDE_MARK_TIME 50   // ds the open sides stay marked

/obj/structure/railing/built/gunwale
	name = "wooden gunwale"
	desc = "The planked top edge of a boat's side, a little above her deck. It keeps the crew aboard and the sea out."
	icon_state = "wood"
	railing_style = "wood"
	material_name = "wood"
	health = 120
	maxhealth = 120

/obj/structure/railing/built/gunwale/bulwark
	name = "steel bulwark"
	desc = "A riveted steel plate standing above the deck along a ship's side, topped with a rail."
	icon_state = "steel_pipe"
	railing_style = "steel_pipe"
	material_name = "steel"
	health = 350
	maxhealth = 350
	flammable = FALSE
	masonry_cover = TRUE

// Part of her hull, not a load on it.
/obj/structure/railing/built/gunwale/hull_load()
	return 0

/obj/structure/railing/built/gunwale/examine(mob/user)
	. = ..()
	to_chat(user, SPAN_NOTICE("Climb over it to go over the side."))

// Over the side into the water asks first.
/obj/structure/railing/built/gunwale/do_climb(mob/living/user)
	var/turf/beyond = get_step(get_turf(src), dir)
	if (user && get_turf(user) == get_turf(src) && istype(beyond, /turf/floor/beach/water) && !hull_floor_in(beyond) && can_climb(user))
		if (WWinput(user, "Over the side is open water. Climb over into the water?", "Over the side", "Stop", list("Climb over", "Stop")) != "Climb over")
			return
	return ..()

// ---- Which sides are open ----

// TRUE when T is filled whole by a wall, window or door, closing every side.
/proc/hull_tile_walled(turf/T)
	for (var/obj/covers/C in T)
		if (C.wall && C.loc == T)
			return TRUE
	if (locate(/obj/structure/window_frame) in T)
		return TRUE
	if (locate(/obj/structure/simple_door) in T)
		return TRUE
	return FALSE

// TRUE when a railing (a gunwale, a bulwark or any built railing) runs
// along side direction of T.
/proc/hull_side_railed(turf/T, direction)
	for (var/obj/structure/railing/R in T)
		if (!QDELETED(R) && R.loc == T && R.dir == direction)
			return TRUE
	return FALSE

// The open sides of a hull of these deck tiles: list(list(turf, direction)).
/proc/hull_open_sides(list/deck)
	. = list()
	var/list/on_deck = list()
	for (var/turf/T in deck)
		on_deck[T] = TRUE
	for (var/turf/T in deck)
		if (hull_tile_walled(T))
			continue
		for (var/d in cardinal)
			var/turf/N = get_step(T, d)
			if (N && on_deck[N])
				continue
			if (hull_side_railed(T, d))
				continue
			. += list(list(T, d))

// Why a hull of these tiles needs her sides closed first, or null. Small
// craft need none.
/proc/hull_sides_refusal(list/deck)
	if (!deck || deck.len <= HULL_SMALL_MAX_TILES)
		return null
	var/list/open = hull_open_sides(deck)
	if (!open.len)
		return null
	hull_mark_open_sides(open)
	return "Her sides are open in [open.len] place\s, marked on her deck: a boat or ship needs a gunwale (or a wall, window, door or railing) along every side of her deck. Hold planks or steel and choose \"Rail her sides\" at the tiller, or build gunwales along her edges yourself."

// Marks the open sides for a few seconds, like the course markers.
/proc/hull_mark_open_sides(list/open)
	for (var/list/side in open)
		var/turf/T = side[1]
		if (locate(/obj/effect/vessel_path/open_side) in T)
			continue
		var/obj/effect/vessel_path/open_side/P = new(T)
		addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(qdel), P), HULL_SIDE_MARK_TIME)

/obj/effect/vessel_path/open_side
	name = "open side"
	desc = "This edge of her deck has no gunwale yet."

// What closes a side of a tile with this floor: a bulwark on steel, a gunwale
// on anything else.
/proc/hull_gunwale_for(turf/T)
	return (locate(/obj/covers/steelplating) in T) ? /obj/structure/railing/built/gunwale/bulwark : /obj/structure/railing/built/gunwale

/proc/hull_gunwale_material(path)
	return ispath(path, /obj/structure/railing/built/gunwale/bulwark) ? "steel" : "wood"

// Closes every open side for nothing (slipway ships coming off the ways).
// Returns how many were fitted.
/proc/hull_rail_sides_free(list/deck)
	. = 0
	for (var/list/side in hull_open_sides(deck))
		var/turf/T = side[1]
		var/path = hull_gunwale_for(T)
		var/obj/structure/railing/R = new path(T)
		R.set_dir(side[2])
		.++

// ---- At the tiller ----

/obj/structure/hull_tiller/proc/open_sides()
	var/datum/craft_body/built/B = body()
	if (!istype(B) || !B.placed() || B.tile_count() <= HULL_SMALL_MAX_TILES)
		return list()
	return hull_open_sides(B.cells())

// Fits gunwales on her open sides, stern to bow, while the stack in hand pays.
/obj/structure/hull_tiller/proc/rail_sides(mob/living/human/H)
	var/list/deck = craft ? craft.body.cells() : built_hull_survey(get_turf(src))
	if (istext(deck))
		to_chat(H, SPAN_WARNING(deck))
		return
	var/list/open = hull_open_sides(deck)
	if (!open.len)
		to_chat(H, SPAN_NOTICE("Her sides are already closed all round."))
		return
	var/obj/item/stack/S = H.get_active_hand()
	var/material = istype(S) ? piece_material(S) : null
	if (material != "wood" && material != "steel")
		to_chat(H, SPAN_WARNING("She has [open.len] open side\s. Hold wood to fit gunwales on her plank deck, or steel for bulwarks on her steel deck: 2 a side."))
		return
	var/fitted = 0
	var/skipped = 0
	to_chat(H, SPAN_NOTICE("You start fitting her sides..."))
	for (var/list/side in open)
		var/turf/T = side[1]
		var/path = hull_gunwale_for(T)
		if (hull_gunwale_material(path) != material)
			skipped++
			continue
		if (QDELETED(S) || S.loc != H || S.amount < 2)
			break
		if (!do_after(H, HULL_RAIL_TIME, src) || get_dist(H, src) > 1)
			break
		if (QDELETED(S) || S.amount < 2 || hull_side_railed(T, side[2]) || hull_tile_walled(T))
			continue
		S.use(2)
		var/obj/structure/railing/R = new path(T)
		R.set_dir(side[2])
		fitted++
	var/left = hull_open_sides(deck).len
	if (fitted)
		log_game("[key_name(H)] railed [fitted] side\s of the hull at [x],[y],[z] ([left] left open).")
	to_chat(H, SPAN_NOTICE("You fit [fitted] [material == "steel" ? "bulwark" : "gunwale"]\s. [left ? "[left] side\s still open[skipped ? ", some of them on [material == "steel" ? "plank" : "steel"] deck" : ""]." : "Her sides are closed all round."]"))

#undef HULL_RAIL_TIME
#undef HULL_SIDE_MARK_TIME
