/obj/covers

	name = "floor covers"
	icon = 'icons/turf/floors.dmi'
	icon_state = "wood_ship"
	var/passable = TRUE
	var/origin_passable = FALSE
	anchored = TRUE
	opacity = FALSE
	density = FALSE
	layer = 2
	level = 2


/obj/covers/wood
	name = "wood floor"
	icon_state = "wood_ship"
	passable = TRUE

/obj/covers/New()
	..()
	if (passable)
		for(var/turf/T in src)
			density = FALSE

/obj/covers/Destroy()
	..()
	if (!origin_passable)
		for(var/turf/T in src)
			density = TRUE
