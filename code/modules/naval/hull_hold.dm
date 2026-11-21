// ============================================================
// Built hulls: a hold below the waterline (docs/craft-core.md)
// ------------------------------------------------------------
// A built hull (craft/built_body.dm) can carry a hold on the level below her
// deck: floors laid in the rock (or deep water) under her own tiles. Like her
// upper deck, the hold and everything in it sail with her, found again by
// position at every move, so no field links one deck to the other.
//
// The tiles under her hold floors are hollowed into ship_hold turfs as she
// arrives over them, and get back the ground they were as she leaves: each
// hold floor keeps the turf type it hollowed out (hold_origin), and that is
// saved with it. The rock around the hold is her hull below the waterline.
// Only rock and deep water can take her hold.
// ============================================================

/obj/covers
	var/hold_origin = null       // A floor of a hull's hold: the turf type it hollowed out, as text.

// The space a hull's hold stands in.
/turf/floor/plating/ship_hold
	name = "hold"
	desc = "The inside of a ship's hull, below the waterline."

/obj/covers/steelplating/hold
	name = "hold floor"
	desc = "The steel floor of a ship's hold, below the waterline."

// The floor of a hull's hold filed on T, or null.
/proc/hull_hold_cover(turf/T)
	if (!istype(T, /turf/floor/plating/ship_hold))
		return null
	for (var/obj/covers/C in T)
		if (C.loc == T && C.hold_origin)
			return C
	return null

// Ground a hold may be hollowed out of.
/proc/hull_hold_ground(turf/T)
	return istype(T, /turf/wall/rockwall) || istype(T, /turf/floor/beach/water/deep)

// The turf type a hold floor gives back to its tile when the hold leaves it.
/proc/hull_hold_origin_path(origin)
	var/path = istext(origin) ? text2path(origin) : origin
	return ispath(path, /turf) ? path : /turf/wall/rockwall

// Hollows T and lays a hold floor of path on it. Returns the floor, or null
// when T is not ground a hold may be hollowed out of.
/proc/hull_hold_lay(turf/T, path = /obj/covers/steelplating/hold)
	if (!T || !hull_hold_ground(T))
		return null
	var/origin = "[T.type]"
	T.ChangeTurf(/turf/floor/plating/ship_hold)
	var/obj/covers/C = new path(T)
	C.hold_origin = origin
	return C

// The level her hold lies on, or 0 where the map has none below her.
/datum/craft_body/built/proc/lower_z()
	return placed() ? multiz_level_below(z) : 0

// The tile below hull tile S when it is part of her hold.
/datum/craft_body/built/proc/lower_deck_cell(turf/S, lz)
	if (!S || !lz)
		return null
	var/turf/L = locate(S.x, S.y, lz)
	return hull_hold_cover(L) ? L : null

// Her hold: one entry per offset, the tile below it or null.
/datum/craft_body/built/proc/lower_cells(list/above = null)
	. = list()
	var/lz = lower_z()
	if (!lz)
		for (var/list/O in offsets)
			. += null
		return
	if (!above)
		above = cells()
	for (var/turf/S in above)
		. += lower_deck_cell(S, lz)

/datum/craft_body/built/proc/lower_tile_count()
	. = 0
	for (var/turf/L in lower_cells())
		.++

// Why a tile below the waterline cannot take a tile of her hold, or null.
/datum/craft_body/built/proc/lower_tile_refusal(turf/D)
	if (!D)
		return "the edge of the world"
	if (!hull_hold_ground(D))
		return "[D.name] in the way of her hold at [D.x],[D.y]"
	for (var/obj/covers/C in D)
		if (C.loc == D)
			return "a floor in the way of her hold at [D.x],[D.y]"
	for (var/atom/movable/M in D)
		if (M.loc == D && M.density && !istype(M, /atom/movable/lighting_overlay))
			return "[M.name] in the way of her hold at [D.x],[D.y]"
	return null

// TRUE when T is one of her tiles on any of her decks.
/datum/craft_body/built/carries(turf/T)
	if (!T || !placed())
		return FALSE
	if (T.z == z)
		return contains(T)
	if (!contains(locate(T.x, T.y, z)))
		return FALSE
	if (T.z == upper_z())
		return !isnull(upper_deck_cell(locate(T.x, T.y, z), T.z))
	if (T.z == top_z())
		return !isnull(upper_deck_cell(upper_deck_cell(locate(T.x, T.y, z), upper_z()), T.z))
	if (T.z == lower_z())
		return !isnull(hull_hold_cover(T))
	return FALSE

// Hollows the tiles her hold arrives on and gives back the ground of those it
// left. lower_old and lower_new are her hold tiles before and after the move,
// in offset order; the floors have not moved yet. Returns origin, which
// after_hold_move() needs: turf -> the ground type that tile had.
/datum/craft_body/built/proc/before_hold_move(list/lower_old, list/lower_new)
	. = list()
	var/list/origin = .
	for (var/turf/S in lower_old)
		var/obj/covers/C = hull_hold_cover(S)
		origin[S] = C ? C.hold_origin : "[/turf/wall/rockwall]"
	var/old_bulk = wall_bulk_placement
	wall_bulk_placement = TRUE
	for (var/turf/D in lower_new)
		if (!isnull(origin[D]))
			continue
		origin[D] = "[D.type]"
		D.ChangeTurf(/turf/floor/plating/ship_hold)
	wall_bulk_placement = old_bulk

// After the hold floors moved: each takes the ground of its new tile, and the
// tiles the hold left get theirs back.
/datum/craft_body/built/proc/after_hold_move(list/lower_old, list/lower_new, list/origin)
	var/list/kept = list()
	for (var/i = 1, i <= lower_new.len, i++)
		var/turf/D = lower_new[i]
		if (!D)
			continue
		kept[D] = TRUE
		var/obj/covers/C = hull_hold_cover(D)
		if (C)
			C.hold_origin = origin[D]
	var/old_bulk = wall_bulk_placement
	wall_bulk_placement = TRUE
	for (var/turf/S in lower_old)
		if (kept[S])
			continue
		S.ChangeTurf(hull_hold_origin_path(origin[S]))
	wall_bulk_placement = old_bulk
