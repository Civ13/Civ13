// Point at something: Shift+middle-click it, or right-click it and choose
// Point To. A bobbing arrow hangs over its tile for two seconds and everyone
// nearby reads who pointed at what.
/mob/living/verb/pointed(atom/A as mob|obj|turf in view(WORLD_VIEW))
	set name = "Point To"
	set category = null

	if (!src || !isturf(loc) || !can_point_at(A))
		return FALSE
	if (istype(A, /obj/effect/decal/point))
		return FALSE

	var/tile = get_turf(A)
	if (!tile)
		return FALSE

	var/obj/P = new /obj/effect/decal/point(tile)
	P.invisibility = invisibility
	spawn (20)
		if (P)
			qdel(P)	// qdel

	face_atom(A)
	return TRUE

// Anything on screen can be pointed at. The widescreen game view is wider than
// world.view, so the range comes from the pointer's own view.
/mob/living/proc/can_point_at(atom/A)
	if (!A || !isturf(loc))
		return FALSE
	return A in view(client && client.view ? client.view : WORLD_VIEW, loc)