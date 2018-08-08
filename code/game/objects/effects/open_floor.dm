/*/turf/broken_floor
	name = "hole"
	icon = 'icons/turf/areas.dmi'
	icon_state = "black"
	density = FALSE
	var/floorbelowz = FALSE

/turf/broken_floor/New()
	..()
	floorbelowz = get_turf(get_step(src,DOWN))

/turf/broken_floor/Enter(atom/A)
	if (floorbelowz)
		if (istype(A, /mob))
			A.z = floorbelowz.z
		if (istype(A, /obj/item/projectile) ||istype(A, /obj/covers))
			return
		else
			A.z = floorbelowz.z
*/