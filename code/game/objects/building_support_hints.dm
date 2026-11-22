// Window frames and glazed windows stand in a wall line and carry a roof
// like the wall beside them: one tile, at the strength of their material.
/proc/building_window_tier(atom/A)
	if (!A || A.gc_destroyed || A.gcDestroyed)
		return 0
	var/path = "[A.type]"
	for (var/masonry in list("clay", "redearth", "villa", "brick", "stone", "marble", "sandstone", "sumerian"))
		if (findtext(path, "/[masonry]"))
			return 4
	return 2

/proc/building_is_window_support(atom/A)
	return istype(A, /obj/structure/window_frame) || istype(A, /obj/structure/window/classic)

/obj/structure/window_frame/building_support_tier()
	return building_window_tier(src)

/obj/structure/window/classic/building_support_tier()
	return building_window_tier(src)

// Glazing swaps a frame for a window and breaking swaps it back; the collapse
// check waits a few seconds, so only a window that is really gone drops a roof.
/proc/building_window_support_lost(atom/A)
	var/turf/T = get_turf(A)
	if (!T)
		return
	for (var/obj/roof/R in range(1, T))
		R.collapse_check()
	building_recheck_storeys_above(A)

/obj/structure/window_frame/Destroy()
	building_window_support_lost(src)
	..()

/obj/structure/window/classic/Destroy()
	building_window_support_lost(src)
	..()

// Wall-like things that never hold a roof, named so a refusal can say so.
/proc/building_non_support_name(atom/A)
	if (istype(A, /obj/covers))
		var/obj/covers/C = A
		if (C.wall && C.incomplete)
			return "unfinished [C.name]"
		return null
	if (istype(A, /obj/structure/window/barrier) || istype(A, /obj/structure/grille) || istype(A, /obj/structure/wallframe))
		return "[A.name]"
	return null

// What the nearest supports are, for a roof refused on T: a sentence naming
// the closest wall or pillar and how far it is from the tile.
/proc/building_support_hint(turf/T)
	if (!T)
		return ""
	var/atom/nearest
	var/nearest_dist = 99
	var/atom/blocker
	var/blocker_dist = 99
	for (var/atom/A in range(6, T))
		var/d = get_dist(A, T)
		if (A.building_support_tier())
			if (d < nearest_dist)
				nearest = A
				nearest_dist = d
		else if (d < blocker_dist && building_non_support_name(A))
			blocker = A
			blocker_dist = d
	. = "A roof tile needs a wall or window within 1 tile, a stone pillar within 2 or a wooden roof support within 3. A door holds only its own tile."
	if (nearest)
		var/reach = building_support_reach(nearest)
		if (nearest_dist > reach)
			. += " The nearest support, \a [nearest], is [nearest_dist] tile\s away but reaches only [reach]."
		else
			. += " \The [nearest] [nearest_dist] tile\s away is close enough, but it is not strong enough or not held up from below."
	else
		. += " There is no wall or pillar within 6 tiles."
	if (blocker && blocker_dist < nearest_dist)
		. += " The [building_non_support_name(blocker)] [blocker_dist ? "[blocker_dist] tile\s away" : "here"] does not hold roofs."
	. += " Put a roof support in the middle of a wide room."
