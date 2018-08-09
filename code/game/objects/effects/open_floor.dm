/*/turf/broken_floor
	name = "hole"
	icon = 'icons/turf/areas.dmi'
	icon_state = "black"
	density = FALSE
	var/floorbelowz = null

/turf/broken_floor/New()
	..()
	if (z > 1)
		floorbelowz = locate(x, y, z-1)

/turf/broken_floor/Enter(atom/A)
	if (floorbelowz)
		if (istype(A, /mob))
			A.z = floorbelowz.z
		if (istype(A, /obj/item/projectile) ||istype(A, /obj/covers))
			return
		else
			A.z = floorbelowz.z
*/