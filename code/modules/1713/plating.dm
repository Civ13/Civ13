/*/obj/structure/plating
	density = FALSE
	layer = 2.005 // above floors, below floor decals
	icon = 'icons/turf/floors.dmi'
	icon_state = "plating"

/obj/structure/plating/New()
	..()
	var/turf/T = loc
	if (istype(T, /turf/sky))
		T.name = "plane"

/obj/structure/plating/Destroy()
	var/turf/T = loc
	if (istype(T, /turf/sky))
		T.name = initial(T.name)
	..()
*/