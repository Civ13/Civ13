/turf/broken_floor
	name = "hole"
	icon = 'icons/turf/areas.dmi'
	icon_state = "black"
	density = FALSE

/turf/broken_floor/New()
	..()
	if (z > 1)
		floorbelowz = locate(x, y, z-1)
	else
		floorbelowz = locate(x, y, 1)
//	var/mob/shadow/shadowcover = new/mob/shadow(src)

/turf/broken_floor/Entered(atom/movable/A)
	. = ..()
	if (!A || !A.loc)
		return
	if (isobserver(A))
		return
	if (istype(A, /mob/shadow))
		return
	if (floorbelowz)
		if (istype(A, /mob))
			A.z -= 1
			A.visible_message("\[A] falls from the deck above and slams into \the floor!", "You land on the floor.", "You hear a soft whoosh and a crunch")
			if (istype(A, /mob/living/carbon/human))
				playsound(A.loc, 'sound/effects/gore/fallsmash.ogg', 50, TRUE)
				var/mob/living/carbon/human/H = A
				var/damage = 10
				H.apply_damage(rand(0, damage), BRUTE, "head")
				H.apply_damage(rand(0, damage), BRUTE, "chest")
				H.apply_damage(rand(0, damage), BRUTE, "l_leg")
				H.apply_damage(rand(0, damage), BRUTE, "r_leg")
				H.apply_damage(rand(0, damage), BRUTE, "l_arm")
				H.apply_damage(rand(0, damage), BRUTE, "r_arm")
				H.Stun(3)
				H.updatehealth()

/*		if (istype(A, /obj) && !(istype(A, /obj/item/projectile) || !(istype(A, /obj/covers)))
			A.z -= 1
			A.visible_message("\The [A] falls from the deck above and slams into the floor!", "You hear something slam into the deck."
		if (istype(A, /obj/item/projectile) || istype(A, /obj/covers))
			return
*/
