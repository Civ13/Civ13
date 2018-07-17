/obj/tank/var/next_movement = -1
/obj/tank/var/next_movement_sound = -1
/obj/tank/var/movement_sound_delay = 30
/obj/tank/var/next_gib = -1
/obj/tank/var/lastdir = -1

// tanks move faster on grass, slower on roads - Kachnov
/obj/tank/var/movement_delay = 3.30
/obj/tank/var/slow_movement_delay = 3.30
/obj/tank/var/fast_movement_delay = 2.75



/obj/tank/proc/set_eye_location(var/mob/m)
	if (m.client)
		m.client.perspective = EYE_PERSPECTIVE
		/* fucking BYOND ree
		switch (dir)
			if (EAST, NORTHEAST, SOUTHEAST)
				m.client.eye = locate(x, y-2, z)
			if (WEST, NORTHWEST, SOUTHWEST)
				m.client.eye = locate(x+2, y-2, z)
			if (SOUTH)
				m.client.eye = locate(x+2, y-2, z)
			if (NORTH)
				m.client.eye = locate(x+2, y-2, z)
		*/
		m.client.eye = src

/obj/tank/Move()
	switch (dir)
		if (EAST, WEST)
			icon = horizontal_icon
			pixel_x = 0
		if (NORTH, SOUTH)
			icon = vertical_icon
			pixel_x = 0

	update_bounding_rectangle()

	..()

	if (drive_front_seat && drive_front_seat.client)
		set_eye_location(drive_front_seat)

	if (fire_back_seat && fire_back_seat.client)
		set_eye_location(fire_back_seat)

/obj/tank/proc/_Move(direct)
	var/turf/my_turf = get_turf(src)
	if (istype(my_turf, /turf/floor/plating/grass) || istype(my_turf, /turf/floor/dirt))
		movement_delay = fast_movement_delay
	else
		movement_delay = slow_movement_delay
	if (world.time >= next_movement)

		if (fuel <= 0)
			internal_tank_message("<span class = 'danger'><big>Out of fuel!</big></danger>")
			return

		next_movement = world.time + movement_delay
		var/turf/target = get_step(src, direct)

		var/driver = front_seat()
		if (target && map.check_prishtina_block(driver, target))
			play_movement_sound()
			driver << "<span class = 'warning'>You cannot pass the invisible wall until the Grace Period has ended.</span>"
			return

		if (istype(target, /turf/floor/plating/beach/water))
			play_movement_sound()
			return

		if (hascall(target, "has_snow") && target:has_snow())
			if (!truck)
				if (prob(25))
					internal_tank_message("<span class = 'notice'><big>Your tank gets stuck in the snow.</big></span>")
				else
					next_movement = world.time + (movement_delay*1.5)
			else
				if (prob(60))
					internal_tank_message("<span class = 'notice'><big>Your truck gets stuck in the snow.</big></span>")
				else
					next_movement = world.time + (movement_delay*1.5)

		if (direct != lastdir && lastdir != -1)
			internal_tank_message("<span class = 'notice'><big>Turning...</big></span>")
			var/turndelay = movement_delay * 1.5
			next_movement = world.time + turndelay + movement_delay
			sleep(turndelay)

		dir = direct
		lastdir = dir

		update_bounding_rectangle()
		switch (dir)
			if (EAST)
				icon = horizontal_icon
			if (WEST)
				icon = horizontal_icon
			if (NORTH)
				icon = vertical_icon
			if (SOUTH)
				icon = vertical_icon
		update_bounding_rectangle()

		if (!handle_passing_target_turf(target))
			return FALSE

		play_movement_sound()

		for (var/obj/o in get_step(src, direct))
			if (!handle_passing_obj(o))
				return FALSE

		for (var/mob/m in get_step(src, direct))
			if (!handle_passing_mob(m))
				return FALSE

		loc = target

		if (!admin)
			fuel -= pick(0.33,0.66,0.99)

/obj/tank/proc/play_movement_sound()
	if (world.time > next_movement_sound)
		playsound(get_turf(src), 'sound/weapons/WW2/tank_move.ogg', 100)
		next_movement_sound = world.time + movement_sound_delay

// bound_x, bound_width, bound_height need this or movement speed gets fucked
/proc/round_to_multiple_of_32(n, upper = FALSE)
	. = n - n%32
	if (upper)
		. += 32

/obj/tank/proc/update_bounding_rectangle()

	if (truck == FALSE)
		switch (dir)
			if (EAST)
			//	bound_x = round_to_multiple_of_32(32)
				bound_width = round_to_multiple_of_32(142)
				bound_height = round_to_multiple_of_32(75)
			if (WEST)
			//	bound_x = round_to_multiple_of_32(96)
				bound_width = round_to_multiple_of_32(142)
				bound_height = round_to_multiple_of_32(75)
			if (NORTH)
			//	bound_y = -round_to_multiple_of_32(64)
			//	bound_x = round_to_multiple_of_32(64)
				bound_width = round_to_multiple_of_32(113, TRUE)
				bound_height = round_to_multiple_of_32(89)
			if (SOUTH)
			//	bound_x = round_to_multiple_of_32(64)
				bound_width = round_to_multiple_of_32(113, TRUE)
				bound_height = round_to_multiple_of_32(89)
	else
		switch (dir)
			if (EAST)
				bound_x = -32
				bound_width = 128
				bound_height = 64
			if (WEST)
				bound_x = -32
				bound_width = 128
				bound_height = 64
			if (NORTH)
				bound_x = -32
				bound_width = 64
				bound_height = 64
			if (SOUTH)
				bound_x = -32
				bound_width = 64
				bound_height = 64
/obj/tank/proc/handle_passing_target_turf(var/turf/t)

	var/list/turfs_in_the_way = list()

	// note that the actual object's x is ALWAYS(?) the bottom left corner of it
	// this new turfs in the way code is designed assuming the bounds of
	// the tank while facing EAST and WEST is 5x3, and the bounds while
	// facing NORTH and SOUTH is 3x5

	switch (dir)
		if (EAST)
			turfs_in_the_way += locate(t.x+4, t.y, t.z)
			turfs_in_the_way += locate(t.x+4, t.y+1, t.z)
		//	turfs_in_the_way += locate(t.x+5, t.y+2, t.z) // doesn't work with the current sprite
		if (WEST)
			turfs_in_the_way += locate(t.x, t.y, t.z)
			turfs_in_the_way += locate(t.x, t.y+1, t.z)
		//	turfs_in_the_way += locate(t.x-1, t.y+2, t.z) // doesn't work with the current sprite
		if (NORTH)
			turfs_in_the_way += locate(t.x, t.y+1, t.z)
			turfs_in_the_way += locate(t.x+1, t.y+1, t.z)
			turfs_in_the_way += locate(t.x+2, t.y+1, t.z)
		if (SOUTH)
			turfs_in_the_way += locate(t.x, t.y, t.z)
			turfs_in_the_way += locate(t.x+1, t.y, t.z)
			turfs_in_the_way += locate(t.x+2, t.y, t.z)

	for (var/turf/tt in turfs_in_the_way)
		if (!handle_passing_turf(tt))
			return FALSE
		for (var/atom/movable/am in tt)
			if (isobj(am))
				if (!handle_passing_obj(am))
					return FALSE
			else if (ismob(am))
				if (!handle_passing_mob(am, TRUE))
					return FALSE
	return TRUE

/obj/tank/proc/handle_passing_turf(var/turf/t)
	if (!truck)
		if (!t.density)
			return TRUE
		if (!istype(t, /turf/wall))
			return TRUE
		if (istype(t,  /turf/wall/rockwall))
			return FALSE
		if (istype(t, /turf/wall))
			var/turf/wall/wall = t
			if (!wall.tank_destroyable)
				return FALSE
			var/wall_integrity = wall.material ? wall.material.integrity : 150
			if (prob(min(95, (wall_integrity/5) + 40)))
				tank_message("<span class = 'danger'>The tank smashes against [wall]!</span>")
				playsound(get_turf(src), 'sound/effects/clang.ogg', 100)
				return FALSE
			else // defenses [b]roke
				tank_message("<span class = 'danger'>The tank smashes its way through [wall]!</span>")
				qdel(wall)
				return TRUE
		return TRUE
	else
		if (!t.density)
			return TRUE
		if (!istype(t, /turf/wall))
			return TRUE
		if (istype(t,  /turf/wall/rockwall))
			return FALSE
		if (istype(t, /turf/wall))
			var/turf/wall/wall = t
			if (!wall.tank_destroyable)
				return FALSE
			tank_message("<span class = 'danger'>The truck smashes against [wall]!</span>")
			playsound(get_turf(src), 'sound/effects/clang.ogg', 100)
			damage += x_percent_of_max_damage(rand(2,4))
			update_damage_status()
			return FALSE
		return TRUE

/obj/tank/proc/handle_passing_obj(var/obj/o)

	if (!truck)

		if (o == src)
			return TRUE

		if (istype(o))

			if (istype(o, /obj/item/mine))
				var/obj/item/mine/mine = o
				mine.trigger(src)
				if (mine.atmine == TRUE)
					damage += 400
					update_damage_status()
				else
					damage += x_percent_of_max_damage(rand(5,7))
					update_damage_status()
				return FALSE // halt us too

			else if (istype(o, /obj/item/weapon/grenade))
				return TRUE // pass over it

			else if (istype(o, /obj/train_lever))
				return TRUE // pass over it

			else if (istype(o, /obj/structure/window/sandbag))
				if (prob(15))
					tank_message("<span class = 'danger'>The tank plows through the sandbag wall!</span>")
					qdel(o)
					return TRUE
				else
					tank_message("<span class = 'danger'>The tank smashes against the sandbag wall!</span>")
					playsound(get_turf(src), 'sound/effects/bamf.ogg', 100)
					return FALSE

			else if (istype(o, /obj/structure/anti_tank))
				if (prob(4))
					tank_message("<span class = 'danger'>The tank manages to plow through the anti-tank barrier!</span>")
					qdel(o)
					return TRUE
				else
					tank_message("<span class = 'danger'>The tank tries to push past the barrier!</span>")
					playsound(get_turf(src), 'sound/effects/clang.ogg', 100)
					playsound(get_turf(src), 'sound/effects/clang.ogg', 100)
					playsound(get_turf(src), 'sound/effects/bamf.ogg', 100)
					return FALSE

			else if (istype(o, /obj/structure/girder))
				if (prob(7))
					tank_message("<span class = 'danger'>The tank plows through the wall girder!</span>")
					qdel(o)
					return TRUE
				else
					tank_message("<span class = 'danger'>The tank smashes against the wall girder!</span>")
					playsound(get_turf(src), 'sound/effects/clang.ogg', 100)
					return FALSE

			else if (istype(o, /obj/structure/barricade))
				var/obj/structure/barricade/B = o
				if ((B.material && prob(max(3, 100 - (B.material.integrity/4) - 10))) || (!B.material && prob(80)))
					tank_message("<span class = 'danger'>The tank plows through \the [B]!</span>")
					qdel(o)
					return TRUE
				else
					tank_message("<span class = 'danger'>The tank smashes against \the [B]!</span>")
					playsound(get_turf(src), 'sound/effects/clang.ogg', 100)
					return FALSE

			else if (istype(o, /obj/structure/simple_door))
				var/obj/structure/simple_door/S = o
				if ((S.material && prob(max(5, 100 - (S.material.integrity/5) - 10))) || (!S.material && prob(80)))
					tank_message("<span class = 'danger'>The tank plows through \the [S]!</span>")
					qdel(o)
					return TRUE
				else
					tank_message("<span class = 'danger'>The tank smashes against \the [S]!</span>")
					playsound(get_turf(src), 'sound/effects/clang.ogg', 100)
					return FALSE

			else if (istype(o, /obj/train_pseudoturf))
				if (o.density)
					var/wall_integrity = 500 // trains are hard as fuck
					if (prob(min(wall_integrity/2, 98)))
						tank_message("<span class = 'danger'>The tank smashes against [o]!</span>")
						playsound(get_turf(src), 'sound/effects/clang.ogg', 100)
						return FALSE
					else
						tank_message("<span class = 'danger'>The tank smashes its way through [o]!</span>")
						qdel(o)
						return TRUE
				else // you can no longer drive tanks in to or on to trains.
					return FALSE

			else if (istype(o, /obj/tank))
				tank_message("<span class = 'danger'>The tank rams into [o]!</span>")
				var/obj/tank/other = o
				if (prob(50))
					if (!did_critical_damage)
						other.damage += other.x_percent_of_max_damage(2)
					else
						other.damage += other.x_percent_of_max_damage(0.5)
				else
					visible_message("<span class = 'danger'>The hit bounces off [other]!</span>")

				if (prob(33))
					damage += x_percent_of_max_damage(1) // we take some, but not much damage
				else
					visible_message("<span class = 'danger'>The hit bounces off [src]!</span>")

				layer = initial(layer) + 0.01
				other.layer = initial(layer)
				playsound(get_turf(src), 'sound/effects/clang.ogg', 100)

				update_damage_status()
				other.update_damage_status()

				if (prob(critical_damage_chance()))
					critical_damage()
				if (prob(other.critical_damage_chance()))
					other.critical_damage()

				return FALSE

			else if (istype(o, /obj/structure) && o.density)
				tank_message("<span class = 'danger'>The tank smashes through [o]!</span>")
				playsound(get_turf(src), 'sound/effects/clang.ogg', 100)
				qdel(o)
				return TRUE
			else
				if (!o.density && !istype(o, /obj/item))
					return TRUE
				if ((istype(o, /obj/item) && o.w_class == TRUE) || (istype(o, /obj/item) && o.anchored) || istype(o, /obj/item/ammo_casing) || istype(o, /obj/item/ammo_magazine) || istype(o, /obj/item/organ))
					return TRUE
				else
					tank_message("<span class = 'warning'>The tank crushes [o].</span>")
					qdel(o)
					return TRUE
				if (istype(o, /obj/structure))
					if (prob(40) || !o.density)
						tank_message("<span class = 'danger'>The tank crushes [o]!</span>")
						qdel(o)
						return TRUE
					else
						tank_message("<span class = 'danger'>The tank rams into [o]!</span>")
						playsound(get_turf(src), 'sound/effects/clang.ogg', rand(60,70))
						return FALSE
	//trucks
	else
		if (o == src)
			return TRUE

		if (istype(o))

			if (istype(o, /obj/item/mine))
				var/obj/item/mine/mine = o
				mine.trigger(src)
				damage += x_percent_of_max_damage(rand(40,70))
				update_damage_status()
				return FALSE // halt us too

			else if (istype(o, /obj/item/weapon/grenade))
				return TRUE // pass over it

			else if (istype(o, /obj/train_lever))
				return TRUE // pass over it

			else if (istype(o, /obj/structure/window/sandbag))
				if (prob(20))
					tank_message("<span class = 'danger'>The truck plows through the sandbag wall!</span>")
					qdel(o)
					damage += x_percent_of_max_damage(rand(1,3))
					update_damage_status()
					return TRUE
				else
					tank_message("<span class = 'danger'>The truck smashes against the sandbag wall!</span>")
					playsound(get_turf(src), 'sound/effects/bamf.ogg', 100)
					damage += x_percent_of_max_damage(rand(3,7))
					update_damage_status()
					return FALSE

			else if (istype(o, /obj/structure/anti_tank))
				tank_message("<span class = 'danger'>The truck smashes against the anti-tank barrier!</span>")
				playsound(get_turf(src), 'sound/effects/bamf.ogg', 100)
				damage += x_percent_of_max_damage(rand(10,18))
				update_damage_status()
				return FALSE

			else if (istype(o, /obj/structure/girder))
				tank_message("<span class = 'danger'>The truck smashes against the wall girder!</span>")
				playsound(get_turf(src), 'sound/effects/clang.ogg', 100)
				damage += x_percent_of_max_damage(rand(7,14))
				update_damage_status()
				return FALSE

			else if (istype(o, /obj/structure/barricade))
				tank_message("<span class = 'danger'>The truck smashes against the barricade!</span>")
				playsound(get_turf(src), 'sound/effects/clang.ogg', 100)
				damage += x_percent_of_max_damage(rand(5,12))
				update_damage_status()
				return FALSE


			else if (istype(o, /obj/train_pseudoturf))
				if (o.density)
					tank_message("<span class = 'danger'>The truck smashes against [o]!</span>")
					playsound(get_turf(src), 'sound/effects/clang.ogg', 100)
					return FALSE
				else // you can no longer drive tanks in to or on to trains.
					return FALSE

			else if (istype(o, /obj/tank))
				tank_message("<span class = 'danger'>The truck rams into \the [o]!</span>")
				playsound(get_turf(src), 'sound/effects/clang.ogg', 100)
				damage += x_percent_of_max_damage(rand(14,18))
				update_damage_status()
				return FALSE

				return FALSE

			else if (istype(o, /obj/structure) && o.density)
				tank_message("<span class = 'danger'>The truck smashes through [o]!</span>")
				playsound(get_turf(src), 'sound/effects/clang.ogg', 100)
				qdel(o)
				return TRUE
			else
				if (!o.density && !istype(o, /obj/item))
					return TRUE
				if ((istype(o, /obj/item) && o.w_class == TRUE) || (istype(o, /obj/item) && o.anchored) || istype(o, /obj/item/ammo_casing) || istype(o, /obj/item/ammo_magazine) || istype(o, /obj/item/organ))
					return TRUE
				else
					tank_message("<span class = 'warning'>The truck crushes [o].</span>")
					qdel(o)
					return TRUE
				if (istype(o, /obj/structure))
					if (prob(10) || !o.density)
						tank_message("<span class = 'danger'>The truck crushes [o]!</span>")
						qdel(o)
						return TRUE
					else
						tank_message("<span class = 'danger'>The truck rams into [o]!</span>")
						playsound(get_turf(src), 'sound/effects/clang.ogg', rand(60,70))
						damage += x_percent_of_max_damage(rand(3,8))
						update_damage_status()
						return FALSE

	return TRUE

/obj/tank/proc/handle_passing_mob(var/mob/living/m)

	if (istype(m) && world.time >= next_gib)

		// crushing allies is no longer possible
		if (ishuman(m) && m.stat != DEAD)
			var/mob/living/carbon/human/H = m
			if (H.original_job && drive_front_seat.original_job)
				if (H.original_job.base_type_flag() == drive_front_seat.original_job.base_type_flag())
					return FALSE

		// crushing allied dogs is no longer possible
		else if (istype(m, /mob/living/simple_animal/complex_animal/canine/dog) && m.stat != DEAD)
			var/mob/living/simple_animal/complex_animal/canine/dog/D = m
			if (drive_front_seat.original_job && D.faction)
				if (drive_front_seat.original_job.base_type_flag() == D.faction)
					return FALSE

		next_gib = world.time + 5
		if (!truck)
			tank_message("<span class = 'danger'>The tank runs over [m]!</span>")
			m.maim()
		else
			tank_message("<span class = 'danger'>The truck runs over [m]!</span>")
			m.apply_damage(70, BRUTE, null, FALSE)

	else if (istype(m) && !truck)
		spawn (5)
			m.maim()

	return TRUE