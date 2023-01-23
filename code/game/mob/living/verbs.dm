/mob/living/verb/pointed(atom/A as mob|obj|turf in view())
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

	if (stat || !canmove || restrained())
		return FALSE
	if (status_flags & FAKEDEATH)
		return FALSE

	usr.visible_message("<b>[src]</b> points to [A].")

	return TRUE