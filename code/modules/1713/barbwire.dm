
/obj/structure/barbwire
	name = "barbwire"
	icon_state = "barbwire"
	anchored = TRUE
	var/capture = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE

/obj/structure/barbwire/ex_act(severity)
	switch (severity)
		if (3.0)
			if (prob(50))
				qdel(src)
		else
			qdel(src)

/obj/structure/barbwire/CanPass(atom/movable/mover, turf/target, height=0, air_group=0)
	return TRUE

/obj/structure/barbwire/proc/check_cover(obj/item/projectile/P, turf/from)
	var/turf/cover = get_turf(src)
	if (!cover)
		return TRUE
	if (get_dist(P.starting, loc) <= 1) //Tables won't help you if people are THIS close
		return TRUE

	var/chance = 50 - (P.penetrating * 3)
	if (prob(chance))
		visible_message("<span class='warning'>[P] hits \the [src]!</span>")
		return FALSE
	else
		return TRUE

/obj/structure/barbwire/Crossed(AM as mob|obj)
	if (ismob(AM))
		var/mob/M = AM
		if (ishuman(M))
			var/mob/living/carbon/human/H = M
			if (prob (33))
				playsound(loc, 'sound/effects/glass_step.ogg', 50, TRUE)
				var/obj/item/organ/external/affecting = H.get_organ(pick("l_foot", "r_foot", "l_leg", "r_leg"))
				if (affecting && affecting.take_damage(5, FALSE))
					H.UpdateDamageIcon()
				H.updatehealth()
				if (!(H.species && (H.species.flags)))
					H.Weaken(1)
				if (affecting)
					M << "<span class = 'red'><b>Your [affecting.name] gets slightly cut by \the [src]!</b></span>"
			else if (prob (33))
				playsound(loc, 'sound/effects/glass_step.ogg', 50, TRUE)
				var/obj/item/organ/external/affecting = H.get_organ(pick("l_foot", "r_foot", "l_leg", "r_leg"))
				if (affecting.take_damage(10, FALSE))
					H.UpdateDamageIcon()
				H.updatehealth()
				if (!(H.species && (H.species.flags)))
					H.Weaken(1)
				M << "<span class = 'red'><b>Your [affecting.name] gets cut by \the [src]!</b></span>"
			else
				playsound(loc, 'sound/effects/glass_step.ogg', 50, TRUE)
				var/obj/item/organ/external/affecting = H.get_organ(pick("l_foot", "r_foot", "l_leg", "r_leg"))
				if (affecting.take_damage(15, FALSE))
					H.UpdateDamageIcon()
				H.updatehealth()
				if (!(H.species && (H.species.flags)))
					H.Weaken(1)
				M << "<span class = 'red'><b>Your [affecting.name] gets deeply cut by \the [src]!</b></span>"
			// stop crawling until we're up to prevent buggy crawling
			H.scrambling = TRUE
			spawn (35)
				if (H && H.stat != DEAD)
					H.scrambling = FALSE
	return ..()

/obj/structure/barbwire/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/wirecutters))
		if (anchored)
			user.visible_message("<span class = 'notice'>\The [user] starts to cut through \the [src] with [W].</span>")
			if (!do_after(user,60))
				user.visible_message("<span class = 'notice'>\The [user] decides not to cut through the \the [src].</span>")
				return
			user.visible_message("<span class = 'notice'>\The [user] finishes cutting through \the [src]!</span>")
			playsound(loc, 'sound/items/Wirecutter.ogg', 50, TRUE)
			qdel(src)
			return

	else if (istype(W, /obj/item/weapon/material/knife))
		if (anchored)
			user.visible_message("<span class = 'notice'>\The [user] starts to cut through \the [src] with [W].</span>")
			if (!do_after(user,80))
				user.visible_message("<span class = 'notice'>\The [user] decides not to cut through \the [src].</span>")
				return
			if (prob(40))
				user.visible_message("<span class = 'notice'>\The [user] finishes cutting through \the [src]!</span>")
				playsound(loc, 'sound/items/Wirecutter.ogg', 50, TRUE)
				qdel(src)
				return
			else
				if (ishuman(user))
					var/mob/living/carbon/human/H = user
					var/obj/item/organ/external/affecting = null
					if (istype(H.l_hand, /obj/item/weapon/material/knife))
						affecting = H.get_organ("l_hand")
					else
						affecting = H.get_organ("r_hand")

					user << "<span class = 'red'><b>Your hand slips, causing \the [src] to cut your [affecting.name] open!</b></span>"
					playsound(loc, 'sound/effects/glass_step.ogg', 50, TRUE)
					if (affecting.take_damage(10, FALSE))
						H.UpdateDamageIcon()
					H.updatehealth()
					if (!(H.species && (H.species.flags)))
						H.Weaken(1)
