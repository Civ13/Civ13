#define SANDBAG_BLOCK_ITEMS_CHANCE 40

/obj/structure/window/barrier/proc/check_cover(obj/item/projectile/P)
	. = TRUE

	if (P.def_zone in list("r_leg", "l_leg", "r_foot", "l_foot"))
		return FALSE

// what is our chance of deflecting bullets regardless (compounded by check_cover)
/proc/bullet_deflection_chance(obj/item/projectile/proj)
	var/base = 100
	if (!istype(proj))
		return base
	return base - 15

// procedure for both incomplete and complete sandbags
/obj/structure/window/barrier/CanPass(atom/movable/mover, turf/target, height=0, air_group=0)
	for (var/obj/covers/repairedfloor/rope/R in loc)
		return TRUE

	for (var/obj/covers/repairedfloor/rope/R in get_turf(get_step(mover,mover.dir)))
		return TRUE

	if (istype(mover, /obj/effect/effect/smoke))
		return TRUE

	if (!istype(mover, /obj/item))
		if (get_dir(loc, target) & dir)
			return FALSE
		else
			return TRUE

	if (!istype(mover, /obj/item/projectile))
		return TRUE

	var/obj/item/projectile/proj = mover
	proj.throw_source = proj.starting

	if(!check_dir(proj.get_direction()))
		return TRUE

	var/hitchance = 0
	var/p_dist = proj.get_distance()
	var/is_lying = FALSE

	if(!proj.firer)
		return FALSE

	if(proj.firer.lying || proj.firer.prone)
		is_lying = TRUE

	if(p_dist > 3)
		hitchance = sqrt(p_dist) * 15
		if(incomplete)
			hitchance /= 2
		if(is_lying)
			hitchance *= 2
	else if (p_dist > 0 && is_lying && !incomplete)
		hitchance = 100
	else if (p_dist == 0 && !incomplete && is_lying)
		hitchance = 100

	if(prob(hitchance))
		health -= proj.damage * 0.01
		bullet_act(proj)
		return FALSE
	return TRUE

/obj/structure/window/barrier/proc/CanPassOut(var/obj/item/projectile/proj)
	if(!check_dir(opposite_direction(proj.get_direction())))
		return TRUE

	var/hitchance = 0
	var/p_dist = proj.get_distance()
	var/is_lying = FALSE

	if(!proj.firer)
		visible_message(SPAN_WARNING("[proj] hits \the [src]!"))
		health -= proj.damage * 0.01
		bullet_act(proj)
		return FALSE

	if(proj.firer.lying || proj.firer.prone)
		is_lying = TRUE

	if(p_dist > 3)
		hitchance = sqrt(p_dist) * 15
		if(incomplete)
			hitchance /= 2
		if(is_lying)
			hitchance *= 2
	else if (p_dist > 0 && is_lying)
		hitchance = 100

	if(prob(hitchance))
		visible_message(SPAN_WARNING("[proj] hits \the [src]!"))
		health -= proj.damage * 0.01
		bullet_act(proj)
		return FALSE
	return TRUE

/obj/structure/window/barrier/proc/check_dir(var/direction)
	switch(dir)
		if(SOUTH)
			if(direction in list(SOUTH, SOUTHWEST, SOUTHEAST))
				return TRUE
		if(EAST)
			if(direction in list(EAST, NORTHEAST, SOUTHEAST))
				return TRUE
		if(NORTH)
			if(direction in list(NORTH, NORTHEAST, NORTHWEST))
				return TRUE
		if(WEST)
			if(direction in list(WEST, SOUTHWEST, NORTHWEST))
				return TRUE
	return FALSE
