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

/turf/floor/broken_floor/New()
	..()
	if (z > 1)
		floorbelowz = locate(x, y, z-1)
	else
		floorbelowz = locate(x, y, 1)
//	var/mob/shadow/shadowcover = new/mob/shadow(src)
	spawn(5)
		update_icon()
/*		var/obj/effect/overlay/overfloor/OF
		if (!(OF in src.loc))
			new/obj/effect/overlay/overfloor(src)*/
	for(var/atom/movable/AM in src.contents)
		Entered(AM)

/turf/floor/broken_floor/Entered(atom/movable/A)
	. = ..()
	if (!A || !A.loc)
		return
	if (isobserver(A))
		return
	if (istype(A, /mob/shadow))
		return
	for (var/obj/covers/C in src)
		if (istype(C, /obj/covers))
			return
	if (floorbelowz)
		if (istype(A, /mob))
			A.z -= 1
			A.visible_message("[A] falls from the level above and slams into \the floor!", "You land on the floor.", "You hear a soft whoosh and a crunch.")
			if (istype(A, /mob/living/carbon/human))
				playsound(A.loc, 'sound/effects/gore/fallsmash.ogg', 50, TRUE)
				var/mob/living/carbon/human/H = A
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
		var/mob/living/carbon/human/H = user
		covers_time /= H.getStatCoeff("strength")
		covers_time /= (H.getStatCoeff("crafting") * H.getStatCoeff("crafting"))

	if (WWinput(user, "This will start building a floor cover [your_dir] of you.", "Floor Cover Construction", "Continue", list("Continue", "Stop")) == "Continue")
		visible_message("<span class='danger'>[user] starts constructing the floor cover.</span>", "<span class='danger'>You start constructing the floor cover.</span>")
		if (do_after(user, covers_time, user.loc))
			qdel(src)
			new/obj/covers/repairedfloor(get_step(user, user.dir), user)
			visible_message("<span class='danger'>[user] finishes placing the floor cover.</span>")
			if (ishuman(user))
				var/mob/living/carbon/human/H = user
				H.adaptStat("crafting", 3)
		return
	return