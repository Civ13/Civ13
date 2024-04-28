/obj/structure/barbwire
	name = "barbwire"
	icon_state = "barbwire"
	anchored = TRUE
	var/capture = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	layer = 2.98

/obj/structure/barbwire/New()
	..()
	for(var/mob/living/human/H in get_turf(src))
		H.immune_to_barbwire = TRUE
	return

/obj/structure/barbwire/ex_act(severity)
	switch(severity)
		if (1)
			qdel(src)
		if (2)
			qdel(src)
		if (3)
			if (prob(50))
				qdel(src)
	return

/obj/structure/barbwire/CanPass(atom/movable/mover, turf/target, height=0, air_group=0)
	return TRUE

/obj/structure/barbwire/Crossed(AM as mob|obj)
	if (!src || !src.loc)
		return
	if (ismob(AM))
		var/mob/M = AM
		if (ishuman(M))
			var/mob/living/human/H = M
			if (prob(33))
				playsound(loc, pick('sound/effects/barbwire1.ogg','sound/effects/barbwire2.ogg','sound/effects/barbwire3.ogg'), 50, TRUE)
				var/obj/item/organ/external/affecting = H.get_organ(pick("l_foot", "r_foot", "l_leg", "r_leg"))
				if (affecting && affecting.take_damage(5, FALSE))
					H.UpdateDamageIcon()
				H.updatehealth()
				if (affecting)
					to_chat(M, SPAN_DANGER("Your [affecting.name] gets slightly cut by \the [src]!"))
			else if (prob(33))
				playsound(loc, pick('sound/effects/barbwire1.ogg','sound/effects/barbwire2.ogg','sound/effects/barbwire3.ogg'), 50, TRUE)
				var/obj/item/organ/external/affecting = H.get_organ(pick("l_foot", "r_foot", "l_leg", "r_leg"))
				if (affecting && affecting.take_damage(10, FALSE))
					H.UpdateDamageIcon()
				H.updatehealth()
				if (affecting)
					to_chat(M, SPAN_DANGER("Your [affecting.name] gets cut by \the [src]!"))
			else
				playsound(loc, pick('sound/effects/barbwire1.ogg','sound/effects/barbwire2.ogg','sound/effects/barbwire3.ogg'), 50, TRUE)
				var/obj/item/organ/external/affecting = H.get_organ(pick("l_foot", "r_foot", "l_leg", "r_leg"))
				if (affecting && affecting.take_damage(15, FALSE))
					H.UpdateDamageIcon()
				H.updatehealth()
				if (affecting)
					to_chat(M, SPAN_DANGER("Your [affecting.name] gets deeply cut by \the [src]!"))
	return ..()

// Disabled until a fix is found (the issue is that; Building a barbed wire on your src makes you get stuck in it too.)
/obj/structure/barbwire/Uncross(AM as mob)
	if(ismob(AM))
		var/mob/M = AM
		if (ishuman(M))
			var/mob/living/human/H = M
			if(!H.immune_to_barbwire)
				if(prob(50))
					M.visible_message(SPAN_DANGER("[M] struggle to free themselves from the barbed wire!"))
					playsound(loc, pick('sound/effects/barbwire1.ogg','sound/effects/barbwire2.ogg','sound/effects/barbwire3.ogg'), 50, TRUE)
					var/obj/item/organ/external/affecting = H.get_organ(pick("l_foot", "r_foot", "l_leg", "r_leg"))
					if (affecting.take_damage(4, FALSE))
						H.UpdateDamageIcon()
					H.updatehealth()
					return FALSE
				else
					M.visible_message(SPAN_DANGER("[M] frees themself from the barbed wire!"))
					return TRUE
			else
				H.immune_to_barbwire = FALSE
				return TRUE
	return ..()

/obj/structure/barbwire/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/wirecutters))
		if (anchored)
			user.visible_message(SPAN_NOTICE("\The [user] starts to cut through \the [src] with \the [W]."))
			if (!do_after(user,60))
				user.visible_message(SPAN_NOTICE("\The [user] decides not to cut through \the [src]."))
				return
			user.visible_message(SPAN_NOTICE("\The [user] finishes cutting through \the [src]!"))
			playsound(loc, 'sound/items/Wirecutter.ogg', 50, TRUE)
			qdel(src)
			return

	else if (istype(W, /obj/item/weapon/material/kitchen/utensil/knife) || istype(W, /obj/item/weapon/attachment/bayonet) || istype(W, /obj/item/weapon/material/hatchet))
		if (anchored)
			user.visible_message(SPAN_NOTICE("\The [user] starts to hack through \the [src] with \the [W]."))
			if (!do_after(user,120))
				user.visible_message(SPAN_NOTICE("\The [user] decides to hack through \the [src]."))
				return
			if (prob(40))
				user.visible_message(SPAN_NOTICE("\The [user] finishes hacking through \the [src]!"))
				playsound(loc, 'sound/items/Wirecutter.ogg', 50, TRUE)
				qdel(src)
				return
			else
				if (ishuman(user))
					var/mob/living/human/H = user
					var/obj/item/organ/external/affecting = null
					if (istype(H.l_hand, /obj/item/weapon/material/kitchen/utensil/knife) || istype(H.l_hand, /obj/item/weapon/attachment/bayonet) || istype(H.l_hand, /obj/item/weapon/material/hatchet))
						affecting = H.get_organ("l_hand")
					else
						affecting = H.get_organ("r_hand")

					to_chat(user, SPAN_DANGER("Your hand slips, causing \the [src] to gauge your [affecting.name] open!"))
					playsound(loc, pick('sound/effects/barbwire1.ogg','sound/effects/barbwire2.ogg','sound/effects/barbwire3.ogg'), 50, TRUE)
					if (affecting.take_damage(18, FALSE))
						H.UpdateDamageIcon()
					H.updatehealth()
					if (!(H.species && (H.species.flags)))
						H.Weaken(1)
