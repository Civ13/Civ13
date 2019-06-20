/turf/open
	name = "open space"
	icon = 'icons/turf/areas.dmi'
	icon_state = "black"
	density = FALSE
	plane = OPENSPACE_PLANE
	pathweight = 100000 //Seriously, don't try and path over this one numbnuts

	var/turf/below
	var/list/underlay_references
	var/global/overlay_map = list()

/turf/open/initialize()
	..()
	below = get_step(src,DOWN)
//	ASSERT(HasBelow(z)) // why does this fail at roundstart? Who knows - Kach

/turf/open/Entered(var/atom/movable/mover)
	. = ..()
	if (!mover || !mover.loc)
		return
	if (isobserver(mover))
		return
	if (istype(mover, /mob/living/carbon/human))
		var/mob/living/carbon/human/H = mover
		if (H.stopDumbDamage)
			return
#ifdef USE_OPENSPACE
	if (istype(mover, /mob/shadow))
		return
#endif USE_OPENSPACE
	// only fall down in defined areas (read: areas with artificial gravitiy)
	if (!istype(below)) //make sure that there is actually something below
		below = GetBelow(src)
		if (!below)
			return

	// See if something prevents us from falling.
	var/soft = FALSE
	for (var/atom/A in below)
		if (A.density)
			if (!istype(A, /obj/structure/window))
				return
			else
				var/obj/structure/window/W = A
				if (W.is_fulltile())
					return
		// Dont break here, since we still need to be sure that it isnt blocked
		if (istype(A, /obj/structure/stairs))
			soft = TRUE

	// We've made sure we can move, now.
	mover.Move(below)

	if (!soft)

		if (!isliving(mover))
			if (istype(below, /turf/open))
				mover.visible_message("\The [mover] falls from the deck above through \the [below]!", "You hear a whoosh of displaced air.")
			else
				mover.visible_message("\The [mover] falls from the deck above and slams into \the [below]!", "You hear something slam into the deck.")
		else
			var/mob/M = mover
			if (istype(below, /turf/open))
				below.visible_message("\The [mover] falls from the deck above through \the [below]!", "You hear a soft whoosh.[M.stat ? "" : ".. and some screaming."]")
			else
				M.visible_message("\The [mover] falls from the deck above and slams into \the [below]!", "You land on \the [below].", "You hear a soft whoosh and a crunch")

			// Handle people getting hurt, it's funny!
			if (istype(mover, /mob/living/carbon/human))
				playsound(mover.loc, 'sound/effects/gore/fallsmash.ogg', 50, TRUE)
				var/mob/living/carbon/human/H = mover
				var/damage = 10
				H.apply_damage(rand(0, damage), BRUTE, "head")
				H.apply_damage(rand(0, damage), BRUTE, "chest")
				H.apply_damage(rand(0, damage), BRUTE, "l_leg")
				H.apply_damage(rand(0, damage), BRUTE, "r_leg")
				H.apply_damage(rand(0, damage), BRUTE, "l_arm")
				H.apply_damage(rand(0, damage), BRUTE, "r_arm")
				H.Stun(3)//.
				H.updatehealth()//.

// override to make sure nothing is hidden
/turf/open/levelupdate()
	for (var/obj/O in src)
		O.hide(0)

// Straight copy from space.
/turf/open/attackby(obj/item/C as obj, mob/user as mob)

/turf/open/attack_hand(mob/user)//Climbing down.
	if (!istype(below)) //make sure that there is actually something below
		below = GetBelow(src)
		if (!below)
			return
	if (user.resting || user.prone)//Can't climb down if you're lying down.
		return

	playsound(user.loc, 'sound/effects/climb.ogg', 50, TRUE)
	spawn(15)
		user.visible_message("<span class='notice'>[user] climbs down.","<span class='notice'>You climb down.")
		user.Move(below)

