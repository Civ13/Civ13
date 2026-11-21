// One floor and one wall per tile.
// A tile holds at most one floor cover and one wall piece (wall, door, window
// frame or wall frame). Builders are refused while the tile is taken; remove
// a floor with a hammer first. Walls and floors may share a tile, and a door
// or curtain may hang in a doorway or archway.
// A plain floor cover (also the walkable face of a roof) is a subfloor: any
// other floor can be laid straight over it and takes its place.

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

// A plain floor cover or upper floor, which a finished floor may replace.
/obj/covers/proc/is_subfloor()
	return type == /obj/covers/repairedfloor

/proc/tile_floor_cover(turf/T)
	if (!T)
		return null
	for (var/obj/covers/C in T)
		if (C.loc == T && C.is_floor_cover() && !QDELETED(C))
			return C
	return null

// Footing for recipes built on the floor: the ground itself, or a floor cover
// on any tile, which is how every upper storey stands over open air.
/proc/tile_has_floor(turf/T)
	return isfloor(T) || tile_floor_cover(T)

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
		if (O.loc == T && O.takes_wall_slot() && !QDELETED(O))
			return O
	return null

// A wall cover left open as a passage: a door can hang in it.
/proc/wall_piece_is_opening(atom/A)
	if (!istype(A, /obj/covers))
		return FALSE
	var/obj/covers/C = A
	return C.wall && !C.density && !C.incomplete

// The subfloor that a floor of new_type would be laid over on T, or null.
/proc/tile_subfloor_for(turf/T, new_type)
	if (!T || !cover_type_is_floor(new_type) || new_type == /obj/covers/repairedfloor)
		return null
	var/obj/covers/floor = tile_floor_cover(T)
	return floor && floor.is_subfloor() ? floor : null

// Lay this floor over the subfloor on its tile. It takes over the subfloor's
// link to the ceiling below, so the room underneath keeps its roof, and the
// subfloor is used up. Call it after this floor is on the tile so nothing
// standing there falls through.
/obj/covers/proc/replace_subfloor(obj/covers/old)
	if (!old || old == src || QDELETED(old) || old.loc != loc)
		return FALSE
	if (old.building_pair_id)
		building_pair_id = old.building_pair_id
		building_roof_z = old.building_roof_z
		old.building_pair_id = null
		old.building_roof_z = 0
	old.amount = 0
	qdel(old)
	return TRUE

// Take up a finished floor that is a storey's floor: a plain upper floor goes
// back under it and keeps the link to the ceiling below. Returns the new floor.
/obj/covers/proc/revert_to_subfloor()
	var/turf/T = get_turf(src)
	if (!T || !building_pair_id || is_subfloor() || !is_floor_cover())
		return null
	var/obj/roof/R = building_roof()
	drop_dismantle_refund() // the finished floor's material comes back
	var/obj/covers/repairedfloor/sub = new(T)
	sub.building_take_upper_face(R)
	if (!sub.replace_subfloor(src))
		qdel(sub)
		return null
	return sub

// Why new_type cannot be built on T, or null when the tile is free for it.
/proc/tile_build_refusal(turf/T, new_type)
	if (!T || !new_type)
		return null
	if (cover_type_is_floor(new_type))
		var/obj/covers/floor = tile_floor_cover(T)
		if (floor && !tile_subfloor_for(T, new_type))
			return "There is already \a [floor] here. Remove it with a hammer first."
		return null
	if (type_is_window_door(new_type))
		return window_door_build_refusal(T, new_type)
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
