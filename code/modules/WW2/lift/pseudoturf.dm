// this is a lift pseudoturf, an object that takes the appearance and layer
// of a turf. It's based off of /obj/train_pseudoturf

var/turf/floor/plating/under/ref_under_plating = null

/obj/lift_pseudoturf
	anchored = TRUE
	name = "lift" // so we can edit it
	layer = TURF_LAYER + 0.01
	var/obj/lift_controller/master = null
	var/based_on_type = null // debug variable
	var/copy_of_instance = null // debug variable

/obj/lift_pseudoturf/New(_loc, var/turf/t, var/_master)
	..()

	loc = _loc

	if (istype(loc, /turf/open))
		var/turf/open/open_space = loc
		open_space.update_icon()

	if (t)
		icon = t.icon
		icon_state = t.icon_state
		density = t.density
		opacity = t.opacity
		based_on_type = t.type
		copy_of_instance = t
		layer = t.layer + 0.01
		pixel_x = t.pixel_x
		pixel_y = t.pixel_y
		dir = t.dir
	else
		icon = 'icons/turf/un.dmi'
		icon_state = "un_dark"


	for (var/atom/movable/a in loc)
		if (istype(a, /obj/structure/wild))
			qdel(a)
		if (ismob(a)) // fucking mice
			qdel(a)

	master = _master

	#ifndef LIFT_DEBUG
	name = ""
	#endif


/obj/lift_pseudoturf/proc/_Move(_newloc)

	var/list/move = list()
	for (var/mob/m in get_turf(src))
		move += m
	for (var/obj/o in get_turf(src))
		if (!o.anchored)
			move += o

	loc = _newloc

	// after we've moved but before our contents have
	destroy_objects()
	destroy_mobs()

	for (var/atom/movable/am in move)
		if (istype(am, /obj/lift_controller))
			continue
		if (istype(am, /obj/structure/light))
			continue
		am.loc = loc


/obj/lift_pseudoturf/proc/destroy_objects()
	for (var/obj/o in get_turf(src))

		if (!istype(o))
			continue
		if (o == src || istype(o, type))
			continue
		if (istype(o, /obj/lift_controller))
			continue
		if (istype(o, /obj/structure/light))
			continue
		if (istype(o, /obj/effect/landmark))
			continue
		if (istype(o, /atom/movable/lighting_overlay))
			continue

		if (o.density)
			visible_message("<span class = 'danger'>The lift crushes [o]!</span>")
			if (istype(o, /obj/structure))
				gibs(get_turf(o), gibber_type = /obj/effect/gibspawner/robot)
			qdel(o)
		else if (!o.density)
			visible_message("<span class = 'warning'>The lift crushes [o].</span>")
			qdel(o)

/obj/lift_pseudoturf/proc/destroy_mobs()
	for (var/mob/living/m in get_turf(src))

		if (!istype(m))
			continue

		if (istype(m))
			visible_message("<span class = 'danger'>The lift crushes [m]!</span>")
			m.crush()
