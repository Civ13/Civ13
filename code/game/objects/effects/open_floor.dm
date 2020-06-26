var/process/open_floor/OS2_controller = null

/process/open_floor
	var/list/open_floors = list()

/process/open_floor/setup()
	name = "openfloor"
	schedule_interval = TRUE SECONDS // every second
	start_delay = 12
	OS2_controller = src

/process/open_floor/fire()
	for (var/turf/floor/broken_floor/T in open_floors)
		T.update_icon()

/turf/sky
	icon = 'icons/turf/sky.dmi'
	icon_state = ""
	name = "the sky"
	opacity = FALSE
	density = TRUE

//to create the "shadow" over the previous floor
/obj/effect/overlay/overfloor
	name = "Hole"
	desc = "It's a hole in the floor. You can see what is below."
	icon = 'icons/turf/floors.dmi'
	icon_state = "black_open"
	density = FALSE
	anchored = TRUE
	flags = NOBLUDGEON
	layer = 2.9

/turf/floor/broken_floor
	name = "hole"
	icon = 'icons/turf/areas.dmi'
	icon_state = "black"
	density = FALSE

/turf/floor/broken_floor/sky
	name = "sky"
	density = FALSE
	icon = 'icons/turf/sky.dmi'
	icon_state = ""
/*
var/list/sky_drop_map = list()

// this is probably laggy as hell but oh well - Kachnov
/turf/sky/Entered(var/atom/movable/mover)
	if (locate_dense_type(contents, /obj/structure) || locate_type(contents, /obj/structure/window/classic)) // plane windows
		return ..(mover)
	else
		..(mover)
		if (locate(/obj/structure/plating) in contents)
			return
		var/area/caribbean/void/sky/A = get_area(src)
		if (!istype(A))
			return
		if (!A.corresponding_area_type)
			return
		if (!istype(mover, /mob/observer))
			if (sky_drop_map.len)
				for (var/locstr in sky_drop_map)
					for (var/turf/T in range(5, sky_drop_map[locstr]))
						if (locate(/mob/living) in T)
							continue
						mover.forceMove(T)
			else
				if (A.corresponding_area_allow_subtypes )
					for (var/area/AA in area_list)
						if (istype(AA, A.corresponding_area_type))
							mover.forceMove(pick(AA.contents))
							mover.loc = get_turf(mover.loc)
							sky_drop_map["[mover.x],[mover.y],[mover.z]"] = mover.loc
							break
				else
					var/area/AA = locate(A.corresponding_area_type)
					mover.forceMove(pick(AA.contents))
					mover.loc = get_turf(mover.loc)
					sky_drop_map["[mover.x],[mover.y],[mover.z]"] = mover.loc

		if (isliving(mover))
			var/mob/living/L = mover
			if (!ishuman(mover))
				if (processes.paratrooper_plane.isLethalToJump())
					L << "<span class = 'userdanger'>You land hard on the ground.</span>"
					L.adjustBruteLoss(150)
				else
					L << "<span class = 'good'>You land softly on the ground.</span>"
			else
				var/mob/living/carbon/human/H = mover
				if (processes.paratrooper_plane.isLethalToJump() || !H.back || !istype(H.back, /obj/item/weapon/storage/backpack/german/paratrooper))
					H << "<span class = 'userdanger'>You land hard on the ground.</span>"
					H.adjustBruteLossByPart(75, "l_leg")
					H.adjustBruteLossByPart(75, "r_leg")
				else
					#define FALL_STEPS 12
					try
						H.client.canmove = FALSE
						var/image/I = image('icons/misc/parachute.dmi', H, layer = MOB_LAYER + 1.0)
						I.pixel_x = -16
						I.pixel_y = 32

						// hack to stop overlays from resetting when you shoot and stuff (wtf)
						// this gets called world.fps times a second but it's usually just searching a list, no big deal
						spawn (0)
							while (H && !isDeleted(I))
								if (!H.overlays.Find(I))
									H.overlays += I
								sleep(world.tick_lag)

						H.overlays += I
						H.pixel_y += FALL_STEPS*10

						for (var/v in 1 to FALL_STEPS)
							spawn (v*5)
								H.pixel_y -= 10

						// animation is over now: it's supposed to be 7.8 seconds but this works better
						spawn (60)
							H.overlays -= I
							qdel(I)

						spawn ((FALL_STEPS+0.5)*5)
							playsound(get_turf(H), 'sound/effects/bamf.ogg', 20)
							shake_camera(H, 2)
							H.client.canmove = TRUE

					catch (var/exception/E)
						pass(E)
						H.client.canmove = TRUE
					#undef FALL_STEPS

		// make sure we have the right ambience for our new location
		spawn (1)
			if (ishuman(mover))
				var/area/H_area = get_area(mover)
				H_area.play_ambience(mover)
*/
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
	if (floorbelowz)
		if (istype(A, /mob))
			A.z -= 1
			A.visible_message("[A] falls from the level above and slams into \the floor!", "You land on the floor.", "You hear a soft whoosh and a crunch.")
			if (istype(A, /mob/living/human))
				playsound(A.loc, 'sound/effects/gore/fallsmash.ogg', 50, TRUE)
				var/mob/living/human/H = A
				H.Stun(6)
				var/damage = 40
				H.apply_damage(rand(0, damage), BRUTE, "head")
				H.apply_damage(rand(0, damage), BRUTE, "chest")
				H.apply_damage(rand(0, damage), BRUTE, "l_leg")
				H.apply_damage(rand(0, damage), BRUTE, "r_leg")
				H.apply_damage(rand(0, damage), BRUTE, "l_arm")
				H.apply_damage(rand(0, damage), BRUTE, "r_arm")
				H.updatehealth()

		if (istype(A, /obj))
			if (istype(A, /obj/item/projectile) || istype(A, /obj/covers))
				return
			else
				A.z -= 1
				A.visible_message("\The [A] falls from the level above and slams into the floor!", "You hear something slam into the deck.")

/turf/floor/broken_floor/New()
	..()
	if (OS2_controller)
		OS2_controller.open_floors += src

/turf/floor/broken_floor/Del()
	if (OS2_controller)
		OS2_controller.open_floors -= src
	..()
/turf/floor/broken_floor/update_icon()
	overlays.Cut()
	var/turf/below = locate(x, y, z-1)
	if (!isturf(below))
		below = locate(x, y, z)
	if (below)
		icon = below.icon
		icon_state = below.icon_state
		dir = below.dir
		color = below.color//rgb(127,127,127)
	//	overlays += below.overlays // for some reason this turns an open
	// space into plating.

		if (!istype(below,/turf/floor/broken_floor))
			// get objects
			var/image/o_img = list()
			for (var/obj/o in below)
				// ignore objects that have any form of invisibility
				if (o.invisibility) continue
				var/image/temp2 = image(o, dir=o.dir, layer = o.layer)
				temp2.plane = FLOOR_PLANE
				temp2.color = o.color//rgb(127,127,127)
				temp2.overlays += o.overlays
				o_img += temp2
			overlays += o_img

			var/image/over_OS2_darkness = image('icons/turf/floors.dmi', "black_open")
			over_OS2_darkness.plane = FLOOR_PLANE
			over_OS2_darkness.layer = MOB_LAYER + 0.1
			overlays += over_OS2_darkness



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