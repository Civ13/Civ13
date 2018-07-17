// WIP
/obj/structure/rwall
	icon = 'icons/turf/wall_masks.dmi'
	icon_state = "rgeneric"
	density = TRUE
	anchored = TRUE

/obj/structure/rwall/New()
	..()
	var/turf/T = loc
	if (istype(T, /turf/sky))
		T.name = "plane"

/obj/structure/rwall/Destroy()
	var/turf/T = loc
	if (istype(T, /turf/sky))
		T.name = initial(T.name)
	..()