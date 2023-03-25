var/process/open_space/OS_controller = null

/process/open_space
	var/list/open_spaces = list()

/process/open_space/setup()
	name = "openspace"
	schedule_interval = 1 SECONDS // every second
	start_delay = 12
	OS_controller = src

/process/open_space/fire()
	for (var/turf/floor/broken_floor/T in open_spaces)
		T.update_icon()

/turf/floor/broken_floor/New()
	..()
	if (OS_controller)
		OS_controller.open_spaces += src

/turf/floor/broken_floor/Del()
	if (OS_controller)
		OS_controller.open_spaces -= src
	..()

/turf/floor/broken_floor/update_icon()
	overlays.Cut()
	if (!isturf(floorbelowz))
		floorbelowz = GetBelow(src)
	if (floorbelowz)
		icon = floorbelowz.icon
		icon_state = floorbelowz.icon_state
		dir = floorbelowz.dir
		color = floorbelowz.color

		if (!istype(floorbelowz,/turf/floor/broken_floor))
			// get objects
			var/image/o_img = list()
			for (var/obj/o in floorbelowz)
				// ingore objects that have any form of invisibility
				if (o.invisibility) continue
				var/image/temp2 = image(o, dir=o.dir, layer = o.layer+0.02)
				temp2.plane = plane
				temp2.color = o.color//rgb(127,127,127)
				temp2.overlays += o.overlays
				o_img += temp2
			for (var/mob/m in floorbelowz)
				if (m.invisibility || istype(m, /mob/observer/ghost)) continue
				var/image/temp3 = image(m, dir=m.dir, layer = m.layer)
				temp3.plane = plane
				temp3.color = m.color//rgb(127,127,127)
				temp3.overlays += m.overlays
				o_img += temp3
			overlays += o_img

			var/image/over_OS_darkness = image('icons/turf/floors.dmi', "black_open")
			over_OS_darkness.plane = FLOOR_PLANE
			over_OS_darkness.layer = MOB_LAYER + 0.1
			overlays += over_OS_darkness

/turf/sky
	icon = 'icons/turf/sky.dmi'
	icon_state = ""
	name = "the sky"

var/list/sky_drop_map = list()

/turf/sky/Entered(var/atom/movable/mover)
	if (isobserver(mover))
		return
	if (locate_dense_type(contents, /obj/structure))
		return ..(mover)
	else
		..(mover)
		if (locate(/obj/covers) in contents)
			return
		var/area/caribbean/no_mans_land/sky/A = get_area(src)
		if (!istype(A))
			return
		if (!A.landing_area)
			return
		if (sky_drop_map.len)
			for (var/locstr in sky_drop_map)
				for (var/turf/T in range(5, sky_drop_map[locstr]))
					if (locate(/mob/living) in T)
						continue
					if (locate_dense_type(contents, /obj/structure/wild/tree) in T)
						continue
					mover.forceMove(T)
		else
			if (A.allow_area_subtypes)
				var/area/AA = locate(A.landing_area)
				for (AA in area_list)
					if (istype(AA, A.landing_area))
						var/turf/newloc = pick((AA.get_turfs()))
						mover.x = newloc.x
						mover.y = newloc.y
						mover.z = newloc.z
						sky_drop_map["[mover.x],[mover.y],[mover.z]"] = get_turf(mover)
						break
			else
				var/area/AA = locate(A.landing_area)
				var/turf/newloc = pick((AA.get_turfs()))
				mover.x = newloc.x
				mover.y = newloc.y
				mover.z = newloc.z
				sky_drop_map["[mover.x],[mover.y],[mover.z]"] = get_turf(mover)

		if (isliving(mover))
			var/mob/living/L = mover
			if (!ishuman(mover))
				L << "<span class = 'good'>You land softly onto the ground.</span>"
			else
				var/mob/living/human/H = mover
				if (!H.back || !istype(H.back, /obj/item/weapon/storage/backpack/paratrooper))
					if (prob(10))
						H << "<span class = 'userdanger'><b>You smack face first onto the ground, damn.</b></span>"
					else
						H << "<span class = 'userdanger'><b>You land hard on the ground!</b></span>"
					H.adjustBruteLossByPart(300, "l_leg")
					H.adjustBruteLossByPart(300, "r_leg")
					if (hasorgans(H))
						var/dam_zone = pick("l_leg", "r_leg")
						var/obj/item/organ/external/affecting = H.get_organ(dam_zone)
						affecting.fracture()
					H.updatehealth()
				else
					H.pixel_y += 60
					spawn (5)
						H.client.canmove = FALSE
						var/image/I = image(icon = 'icons/misc/parachute.dmi', H, layer = MOB_LAYER + 1.0)
						I.pixel_x = -16
						I.pixel_y = 16

						H.overlays += I

						for (var/v in 1 to 6)
							spawn (5)
								H.pixel_y -= 10

						spawn (20)
							I = image(icon = 'icons/misc/parachute.dmi', H, icon_state = "closing", layer = MOB_LAYER + 1.0)
							spawn (10) // animation is over now
								H.overlays -= I
								H.pixel_y = 0
								qdel(I)

								spawn(10)
									playsound(get_turf(H), 'sound/effects/thud.ogg', 80)
									shake_camera(H, 2)
									H.client.canmove = TRUE

		// make sure we have the right ambience for our new location
		spawn (1)
			if (ishuman(mover))
				var/area/H_area = get_area(mover)
				H_area.play_ambience(mover)

/turf/floor/broken_floor
	name = "hole"
	icon = 'icons/turf/areas.dmi'
	icon_state = "black"
	density = FALSE
	var/turf/floorbelowz
	// "push" floors for effects, like the bottom deck of the ship. It pushes you into a direction if you fall that way.
	var/push_dir = null

/turf/floor/broken_floor/sky
	name = "sky"
	density = FALSE
	icon = 'icons/turf/sky.dmi'
	icon_state = ""

/turf/floor/broken_floor/New()
	..()
	if (z > 1)
		floorbelowz = locate(x, y, z-1)
	else
		floorbelowz = locate(x, y, 1)

	spawn(5)
		update_icon()

	for(var/atom/movable/AM in src.contents)
		Entered(AM)

/turf/floor/broken_floor/Entered(atom/movable/A)
	. = ..()
	if (!A || !A.loc)
		return
	if (isobserver(A))
		return
	for (var/obj/covers/C in src)
		if (istype(C, /obj/covers))
			return
	for (var/obj/structure/multiz/ladder/LD in src)
		if (istype(LD, /obj/structure/multiz/ladder))
			return
	for(var/obj/structure/voyage/grid/G in src)
		if(G.opened == FALSE)
			return
	if (floorbelowz)
		if (istype(A, /mob))
			if(push_dir)
				A.forceMove(get_step(src,push_dir))
				return
			A.z -= 1
			A.visible_message("[A] falls from the level above and slams into \the floor!", "You land on the floor.", "You hear a soft whoosh and a crunch.")
			if (istype(A, /mob/living/human))
				playsound(A.loc, 'sound/effects/gore/fallsmash.ogg', 50, TRUE)
				var/mob/living/human/H = A
				H.Stun(6)
				var/damage = 25
				H.apply_damage(rand(0, damage), BRUTE, "head")
				H.apply_damage(rand(0, damage), BRUTE, "chest")
				H.apply_damage(rand(0, damage), BRUTE, "l_leg")
				H.apply_damage(rand(0, damage), BRUTE, "r_leg")
				H.apply_damage(rand(0, damage), BRUTE, "l_arm")
				H.apply_damage(rand(0, damage), BRUTE, "r_arm")
				H.updatehealth()

		if (istype(A, /obj))
			if (istype(A, /obj/item/projectile) || istype(A, /obj/covers) || istype(A, /obj/structure/barricade/ship/mast) || istype(A, /obj/structure/voyage/grid))
				return
			else
				if(push_dir)
					A.forceMove(get_step(src,push_dir))
					return
				A.z -= 1
				A.visible_message("\The [A] falls from the level above and slams into the floor!", "You hear something slam into the deck.")

/turf/floor/broken_floor/attackby(mob/user)
	var/your_dir = "NORTH"

	switch (user.dir)
		if (NORTH)
			your_dir = "NORTH"
		if (SOUTH)
			your_dir = "SOUTH"
		if (EAST)
			your_dir = "EAST"
		if (WEST)
			your_dir = "WEST"

	var/covers_time = 80

	if (ishuman(user))
		var/mob/living/human/H = user
		covers_time /= H.getStatCoeff("strength")
		covers_time /= (H.getStatCoeff("crafting") * H.getStatCoeff("crafting"))

	if (WWinput(user, "This will start building a floor cover [your_dir] of you.", "Floor Cover Construction", "Continue", list("Continue", "Stop")) == "Continue")
		visible_message("<span class='danger'>[user] starts constructing the floor cover.</span>", "<span class='danger'>You start constructing the floor cover.</span>")
		if (do_after(user, covers_time, user.loc))
			qdel(src)
			new/obj/covers/repairedfloor(get_step(user, user.dir), user)
			visible_message("<span class='danger'>[user] finishes placing the floor cover.</span>")
			if (ishuman(user))
				var/mob/living/human/H = user
				H.adaptStat("crafting", 3)
		return
	return