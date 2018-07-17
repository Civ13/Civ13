/obj/structure/railing/train_zone_railing

/obj/structure/railing/train_railing
	icon = 'icons/obj/railing.dmi'
	icon_state = "railing1"
	name = "train railing"
	var/occupied = FALSE
	var/datum/train_controller/master = null
	uses_initial_density = TRUE
	initial_density = TRUE
	uses_initial_opacity = TRUE
	initial_opacity = FALSE
	layer = 2.4 // just above connectors, below TPTs

/obj/structure/railing/train_railing/proc/_Move()

	if (master.moving)
		switch (master.direction)
			if ("FORWARDS")
				pixel_y = 9
			if ("BACKWARDS")
				pixel_y = -9
	else
		pixel_y = 0

	for (var/atom_movable in get_turf(src))
		var/atom/movable/AM = atom_movable
		if (check_object_invalid_for_moving(src, AM))
			continue
		switch (master.orientation)
			if (VERTICAL)
				AM.y+=master.getMoveInc()
			if (HORIZONTAL)
				AM.x+=master.getMoveInc()

	switch (master.orientation)
		if (VERTICAL)
			y+=master.getMoveInc()
		if (HORIZONTAL)
			x+=master.getMoveInc()

/obj/structure/railing/train_railing/ex_act(severity)
	if (prob(round(60 * (1/severity))))
		qdel(src)
	else
		return

/obj/structure/railing/train_railing/Destroy()
	if (master)
		master.train_railings -= src
		master.reverse_train_railings -= src
	..()