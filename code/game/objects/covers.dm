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
