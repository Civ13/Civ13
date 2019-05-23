/mob/living/pointed(atom/A as mob|obj|turf in view())
	set name = "Point To"
	set category = null

	if (!src || !isturf(loc) || !(A in view(loc)))
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