/turf/broken_floor
	name = "hole"
	icon = 'icons/turf/areas.dmi'
	icon_state = "black"
	density = FALSE

/turf/broken_floor/Enter(atom/A)
	if (istype(A, /mob))
		A.z -= 1
	if (istype(A, /obj/item/projectile) ||istype(A, /obj/covers))
		return
	else
		A.z -= 1