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

/turf/wall/proc/fail_smash(var/mob/user)
	user << "<span class='danger'>You smash against the wall!</span>"
	take_damage(rand(25,75))

/turf/wall/proc/success_smash(var/mob/user)
	user << "<span class='danger'>You smash through the wall!</span>"
	user.do_attack_animation(src)
	spawn(1)
		dismantle_wall(1)

/turf/wall/proc/try_touch(var/mob/user, var/rotting)

	if (rotting)
		if (reinf_material)
			user << "<span class='danger'>\The [reinf_material.display_name] feels porous and crumbly.</span>"
		else
			user << "<span class='danger'>\The [material.display_name] crumbles under your touch!</span>"
			dismantle_wall()
			return TRUE

	if (..()) return TRUE

	if (!can_open)
		user << "<span class='notice'>You push the wall, but nothing happens.</span>"
		playsound(src, hitsound, 25, TRUE)
	else
		toggle_open(user)
	return FALSE


/turf/wall/attack_hand(var/mob/user)

	radiate()
	add_fingerprint(user)
	user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)


/turf/wall/attack_generic(var/mob/user, var/damage, var/attack_message, var/wallbreaker)

	radiate()
	if (!istype(user))
		return

	user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
	if (!damage || !wallbreaker)
		return


	if (reinf_material)
		if ((wallbreaker == 2) || (damage >= max(material.hardness,reinf_material.hardness)))
			return success_smash(user)
	else if (damage >= material.hardness)
		return success_smash(user)
	return fail_smash(user)

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
		radiate()
		if (is_hot(W))
			burn(is_hot(W))


	// Basic dismantling.
	if (isnull(construction_stage) || !reinf_material)

		var/cut_delay = 60 - material.cut_delay
		var/dismantle_verb
		var/dismantle_sound

		if (dismantle_verb)

			user << "<span class='notice'>You begin [dismantle_verb] through the outer plating.</span>"
			if (dismantle_sound)
				playsound(src, dismantle_sound, 100, TRUE)

			if (cut_delay<0)
				cut_delay = FALSE

			if (!do_after(user,cut_delay,src))
				return

			user << "<span class='notice'>You remove the outer plating.</span>"
			dismantle_wall()
			user.visible_message("<span class='warning'>The wall was torn open by [user]!</span>")
			return

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
		if (reinf_material)
			dam_threshhold = ceil(max(dam_threshhold,reinf_material.integrity)/2)
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
