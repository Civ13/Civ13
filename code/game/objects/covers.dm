/obj/covers

	name = "floor covers"
	icon = 'icons/turf/floors.dmi'
	icon_state = "wood_ship"
	var/passable = TRUE
	var/origin_density = FALSE
	is_cover = TRUE
	anchored = TRUE
	opacity = FALSE
	density = FALSE
	layer = 3
	level = 2
//	invisibility = 101 //starts invisible


/obj/covers/wood
	name = "wood floor"
	icon_state = "wood_ship"
	passable = TRUE

/obj/covers/New()
	..()
	if (passable)
		var/turf/T = get_turf(src)
		origin_density = T.density
		T.density = FALSE
	return TRUE
/*	for(var/obj/Ob in get_turf(src))
		if (Ob.invisibility == 0)
			Ob.invisibility = 101
	for(var/mob/Mb in get_turf(src))
		if (Mb.invisibility == 0)
			Mb.invisibility = 101 */

/obj/covers/updateturf()
	if (passable)
		var/turf/T = get_turf(src)
		origin_density = T.density
		T.density = FALSE
	return TRUE


/obj/covers/Destroy()
	if (origin_density)
		var/turf/T = get_turf(src)
		T.density = TRUE
	..()
	return TRUE
