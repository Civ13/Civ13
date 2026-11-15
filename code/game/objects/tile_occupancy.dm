// One floor and one wall per tile.
// A tile holds at most one floor cover and one wall piece (wall, door, window
// frame or wall frame). Builders are refused while the tile is taken; remove
// a floor with a hammer first. Walls and floors may share a tile, and a door
// or curtain may hang in a doorway or archway.

/obj/covers/proc/is_floor_cover()
	return !wall && layer < 2.1

/proc/cover_type_is_floor(path)
	if (!ispath(path, /obj/covers))
		return FALSE
	var/obj/covers/C = path
	return !initial(C.wall) && initial(C.layer) < 2.1

// Paths that take the wall slot of a tile.
/proc/type_takes_wall_slot(path)
	if (ispath(path, /obj/covers))
		var/obj/covers/C = path
		return initial(C.wall)
	return ispath(path, /obj/structure/simple_door) || ispath(path, /obj/structure/window_frame) || ispath(path, /obj/structure/wallframe)

/proc/tile_floor_cover(turf/T)
	if (!T)
		return null
	for (var/obj/covers/C in T)
		if (C.is_floor_cover() && !QDELETED(C))
			return C
	return null

/atom/proc/takes_wall_slot()
	return FALSE

/obj/covers/takes_wall_slot()
	return wall

/obj/structure/simple_door/takes_wall_slot()
	return TRUE

/obj/structure/window_frame/takes_wall_slot()
	return TRUE

/obj/structure/wallframe/takes_wall_slot()
	return TRUE

/proc/tile_wall_piece(turf/T)
	if (!T)
		return null
	if (istype(T, /turf/wall))
		return T
	for (var/obj/O in T)
		if (O.takes_wall_slot() && !QDELETED(O))
			return O
	return null

// A wall cover left open as a passage: a door can hang in it.
/proc/wall_piece_is_opening(atom/A)
	if (!istype(A, /obj/covers))
		return FALSE
	var/obj/covers/C = A
	return C.wall && !C.density && !C.incomplete

// Why new_type cannot be built on T, or null when the tile is free for it.
/proc/tile_build_refusal(turf/T, new_type)
	if (!T || !new_type)
		return null
	if (cover_type_is_floor(new_type))
		var/obj/covers/floor = tile_floor_cover(T)
		if (floor)
			return "There is already \a [floor] here. Remove it with a hammer first."
		return null
	if (type_takes_wall_slot(new_type))
		var/atom/piece = tile_wall_piece(T)
		if (!piece)
			return null
		if (ispath(new_type, /obj/structure/simple_door) && wall_piece_is_opening(piece))
			for (var/obj/structure/simple_door/D in T)
				if (!QDELETED(D))
					return "There is already \a [D] here."
			return null
		return "There is already \a [piece] here."
	return null

// Wall foundations laid from a held item (bricks, dirt, snow).
/proc/wall_foundation_tile_free(mob/user, new_type)
	var/refusal = tile_build_refusal(get_turf(user), new_type)
	if (refusal)
		to_chat(user, SPAN_WARNING(refusal))
		return FALSE
	return TRUE
