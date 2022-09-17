#define SANDBAG_BLOCK_ITEMS_CHANCE 40

/obj/structure/window/barrier/incomplete/check_cover(obj/item/projectile/P, turf/from)
	return prob(..() * round(progress/3))

// how much do we cover mobs behind full sandbags?
/obj/structure/window/barrier/proc/check_cover(obj/item/projectile/P, turf/from)
	var/turf/cover = get_turf(src)
	if (!cover)
		return FALSE
	if (!istype(P, /obj/item/projectile))
		return FALSE
	if (get_dist(P.starting, loc) <= 1) //Tables won't help you if people are THIS close
		return FALSE
	// can't hit legs or feet when they're behind a sandbag
	if (list("r_leg", "l_leg", "r_foot", "l_foot").Find(P.def_zone))
		return TRUE

	var/base_chance = SANDBAG_BLOCK_ITEMS_CHANCE
	var/extra_chance = 0

	if (ismob(P.original)) // what the firer clicked
		var/mob/m = P.original
		if (m.lying || m.prone)
			if (incomplete)
				extra_chance += 20
			else
				extra_chance += 60
		if (ishuman(m))
			var/mob/living/human/H = m
			if (H.crouching && !H.lying)
				extra_chance += 20

	var/chance = base_chance + extra_chance

	chance = min(chance, 98)

	if (prob(chance))
		return TRUE
	else
		return FALSE

// what is our chance of deflecting bullets regardless (compounded by check_cover)
/proc/bullet_deflection_chance(obj/item/projectile/proj)
	var/base = 100
	if (!istype(proj))
		return base
	return base - min(15, proj.accuracy)

// procedure for both incomplete and complete sandbags
/obj/structure/window/barrier/CanPass(atom/movable/mover, turf/target, height=0, air_group=0)

	for (var/obj/covers/repairedfloor/rope/R in loc)
		return TRUE

	for (var/obj/covers/repairedfloor/rope/R in get_turf(get_step(mover,mover.dir)))
		return TRUE

	if (istype(mover, /obj/effect/effect/smoke))
		return TRUE

	else if (!istype(mover, /obj/item))
		if (get_dir(loc, target) & dir)
			return FALSE
		else
			return TRUE
	else
		if (istype(mover, /obj/item/projectile))
			var/obj/item/projectile/proj = mover
			proj.throw_source = proj.starting

			if (ishuman(proj.firer) && !incomplete && (proj.firer.lying || proj.firer.prone))
				visible_message("<span class = 'warning'>[mover] hits the [src]!</span>")
				if (istype(mover, /obj/item/projectile))
					var/obj/item/projectile/B = mover
					B.damage = 0 // make sure we can't hurt people after hitting a sandbag
					B.invisibility = 101
					B.loc = null
					qdel(B) // because somehow we were still passing the sandbag
				return FALSE
		if (!mover.throw_source)
			if (get_dir(loc, target) & dir)
				return FALSE
			else
				return TRUE
		else
			switch (get_dir(mover.throw_source, get_turf(src)))
				if (NORTH, NORTHEAST)
					if (dir == EAST || dir == WEST || dir == NORTH)
						return TRUE
				if (SOUTH, SOUTHEAST)
					if (dir == EAST || dir == WEST || dir == SOUTH)
						return TRUE
				if (EAST)
					if (dir != WEST)
						return TRUE
				if (WEST)
					if (dir != EAST)
						return TRUE

			if (check_cover(mover, mover.throw_source) && prob(bullet_deflection_chance(mover)))
				visible_message("<span class = 'warning'>[mover] hits \the [src]!</span>")
				if (istype(mover, /obj/item/projectile))
					var/obj/item/projectile/B = mover
					B.damage = 0 // make sure we can't hurt people after hitting a sandbag
					B.invisibility = 101
					B.loc = null
					qdel(B) // because somehow we were still passing the sandbag
				return FALSE
			else
				return TRUE