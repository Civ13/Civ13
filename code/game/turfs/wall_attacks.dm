//Interactions
/turf/wall/proc/toggle_open(var/mob/user)

	if (can_open == WALL_OPENING)
		return

	if (density)
		can_open = WALL_OPENING
		//flick("[material.icon_base]fwall_opening", src)
		sleep(15)
		density = FALSE
		opacity = FALSE
		update_icon()
		set_light(0)
	else
		can_open = WALL_OPENING
		//flick("[material.icon_base]fwall_closing", src)
		density = TRUE
		opacity = TRUE
		update_icon()
		sleep(15)
		set_light(1)

	can_open = WALL_CAN_OPEN
	update_icon()

/turf/wall/attack_hand(var/mob/user)
	add_fingerprint(user)
	user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)


/turf/wall/attack_generic(var/mob/user, var/damage, var/attack_message, var/wallbreaker)
	if (!istype(user))
		return

	user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)


/turf/wall/attackby(obj/item/weapon/W as obj, mob/user as mob)

	user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)

	if (istype(src, /turf/wall/indestructable))
		return
	else return ..()

	// this code is no longer used - you need c4 to get through walls now - Kachnov

	/* not sure what this shitcode is so its disabled - Kachnov
	if (!user.)
		user << "<span class='warning'>You don't have the dexterity to do this!</span>"
		return*/

	//get the user's location
	if (!istype(user.loc, /turf))	return	//can't do this stuff whilst inside objects and such

	if (W)
		if (is_hot(W))
			burn(is_hot(W))
/*
	if (istype(W,/obj/item/frame))
		var/obj/item/frame/F = W
		F.try_build(src)
		return*/
	if (istype(W, /obj/item/weapon/poster/religious))
		user << "You start placing the [W] on the [src]..."
		if (do_after(user, 70, src))
			visible_message("[user] places the [W] on the [src].")
			var/obj/structure/poster/religious/RP = new/obj/structure/poster/religious(get_turf(src))
			var/obj/item/weapon/poster/religious/P = W
			RP.religion = P.religion
			RP.symbol = P.symbol
			RP.color1 = P.color1
			RP.color2 = P.color2
			user.drop_from_inventory(W)
			qdel(W)
			return
	if (istype(W, /obj/item/weapon/poster/faction))
		user << "You start placing the [W] on the [src]..."
		if (do_after(user, 70, src))
			visible_message("[user] places the [W] on the [src].")
			var/obj/structure/poster/faction/RP = new/obj/structure/poster/faction(get_turf(src))
			var/obj/item/weapon/poster/faction/P = W
			RP.faction = P.faction
			RP.bstyle = P.bstyle
			RP.color1 = P.color1
			RP.color2 = P.color2
			user.drop_from_inventory(W)
			qdel(W)
			return
	if (!istype(W, /obj/item/weapon/reagent_containers))
		if (!W.force)
			return attack_hand(user)
		var/dam_threshhold = material.integrity
		var/dam_prob = min(100,material.hardness*1.5)
		if (dam_prob < 100 && W.force > (dam_threshhold/10))
			playsound(src, hitsound, 80, TRUE)
			if (!prob(dam_prob))
				visible_message("<span class='danger'>\The [user] attacks \the [src] with \the [W] and it [material.destruction_desc]!</span>")
				dismantle_wall(1)
			else
				visible_message("<span class='danger'>\The [user] attacks \the [src] with \the [W]!</span>")
		else
			visible_message("<span class='danger'>\The [user] attacks \the [src] with \the [W], but it bounces off!</span>")
		return
