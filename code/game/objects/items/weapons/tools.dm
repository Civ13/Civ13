//This file was auto-corrected by findeclaration.exe on 25.5.2012 20:42:32

/* Tools!
 * Note: Multitools are /obj/item
 *
 * Contains:
 * 		Wrench
 * 		Screwdriver
 * 		Wirecutters
 * 		Welding Tool
 * 		Crowbar
 */

/*
 * Wrench
 */
/obj/item/weapon/wrench
	name = "wrench"
	desc = "A wrench with many common uses. Can be usually found in your hand."
	icon = 'icons/obj/items.dmi'
	icon_state = "wrench"
	flags = CONDUCT
	slot_flags = SLOT_BELT
	force = WEAPON_FORCE_NORMAL
	throwforce = WEAPON_FORCE_NORMAL
	w_class = 2.0
//	origin_tech = list(TECH_MATERIAL = TRUE, TECH_ENGINEERING = TRUE)
	matter = list(DEFAULT_WALL_MATERIAL = 150)
	attack_verb = list("bashed", "battered", "bludgeoned", "whacked")


/*
 * Screwdriver
 */
/obj/item/weapon/screwdriver
	name = "screwdriver"
	desc = "You can be totally screwwy with this."
	icon = 'icons/obj/items.dmi'
	icon_state = "screwdriver"
	flags = CONDUCT
	slot_flags = SLOT_BELT | SLOT_EARS
	force = WEAPON_FORCE_NORMAL
	w_class = 1.0
	throwforce = WEAPON_FORCE_NORMAL
	throw_speed = 3
	throw_range = 5
	matter = list(DEFAULT_WALL_MATERIAL = 75)
	attack_verb = list("stabbed")

/obj/item/weapon/screwdriver/New()
	switch(pick("red","blue","purple","brown","green","cyan","yellow"))
		if ("red")
			icon_state = "screwdriver2"
			item_state = "screwdriver"
		if ("blue")
			icon_state = "screwdriver"
			item_state = "screwdriver_blue"
		if ("purple")
			icon_state = "screwdriver3"
			item_state = "screwdriver_purple"
		if ("brown")
			icon_state = "screwdriver4"
			item_state = "screwdriver_brown"
		if ("green")
			icon_state = "screwdriver5"
			item_state = "screwdriver_green"
		if ("cyan")
			icon_state = "screwdriver6"
			item_state = "screwdriver_cyan"
		if ("yellow")
			icon_state = "screwdriver7"
			item_state = "screwdriver_yellow"

	if (prob(75))
		pixel_y = rand(0, 16)
	..()

/obj/item/weapon/screwdriver/attack(mob/living/carbon/M as mob, mob/living/carbon/user as mob)
	if (!istype(M) || user.a_intent == "help")
		return ..()
	if (user.targeted_organ != "eyes" && user.targeted_organ != "head")
		return ..()
	if ((CLUMSY in user.mutations) && prob(50))
		M = user
	return eyestab(M,user)

/*
 * Wirecutters
 */
/obj/item/weapon/wirecutters
	name = "wirecutters"
	desc = "This cuts wires."
	icon = 'icons/obj/items.dmi'
	icon_state = "cutters"
	flags = CONDUCT
	slot_flags = SLOT_BELT
	force = WEAPON_FORCE_WEAK
	throw_speed = 2
	throw_range = 9
	w_class = 2.0
//	origin_tech = list(TECH_MATERIAL = TRUE, TECH_ENGINEERING = TRUE)
	matter = list(DEFAULT_WALL_MATERIAL = 80)
	attack_verb = list("pinched", "nipped")
	sharp = TRUE
	edge = TRUE

/obj/item/weapon/wirecutters/New()
	if (!istype(src, /obj/item/weapon/wirecutters/boltcutters))
		if (prob(50))
			icon_state = "cutters-y"
			item_state = "cutters_yellow"
	..()

/obj/item/weapon/wirecutters/attack(mob/living/carbon/C as mob, mob/user as mob)
	if (user.a_intent == I_HELP && (C.handcuffed) && (istype(C.handcuffed, /obj/item/weapon/handcuffs/cable)))
		usr.visible_message("\The [usr] cuts \the [C]'s restraints with \the [src]!",\
		"You cut \the [C]'s restraints with \the [src]!",\
		"You hear cable being cut.")
		C.handcuffed = null
		if (C.buckled && C.buckled.buckle_require_restraints)
			C.buckled.unbuckle_mob()
		C.update_inv_handcuffed()
		return
	else
		..()

/*
 * Welding Tool
 */
/obj/item/weapon/weldingtool
	name = "welding tool"
	icon = 'icons/obj/items.dmi'
	icon_state = "welder_off"
	var/on_state = "welder_on"
	var/off_state = "welder_off"
	flags = CONDUCT
	slot_flags = SLOT_BELT

	//Amount of OUCH when it's thrown
	force = WEAPON_FORCE_WEAK
	throwforce = WEAPON_FORCE_WEAK
	throw_speed = TRUE
	throw_range = 5
	w_class = 2.0

	//Cost to make in the autolathe
	matter = list(DEFAULT_WALL_MATERIAL = 70, "glass" = 30)

	//R&D tech level
//	origin_tech = list(TECH_ENGINEERING = TRUE)

	//Welding tool specific stuff
	var/welding = FALSE 	//Whether or not the welding tool is off(0), on(1) or currently welding(2)
	var/status = TRUE 		//Whether the welder is secured or unsecured (able to attach rods to it to make a flamethrower)
	var/max_fuel = 20 	//The max amount of fuel the welder can hold

/obj/item/weapon/weldingtool/New()
//	var/random_fuel = min(rand(10,20),max_fuel)
	var/datum/reagents/R = new/datum/reagents(max_fuel)
	reagents = R
	R.my_atom = src
	R.add_reagent("fuel", max_fuel)
	..()

/obj/item/weapon/weldingtool/Destroy()
	if (welding)
		processing_objects -= src
	return ..()

/obj/item/weapon/weldingtool/examine(mob/user)
	if (..(user, FALSE))
		user << text("\icon[] [] contains []/[] units of fuel!", src, name, get_fuel(),max_fuel )


/obj/item/weapon/weldingtool/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W,/obj/item/weapon/screwdriver))
		if (welding)
			user << "<span class='danger'>Stop welding first!</span>"
			return
		status = !status
		if (status)
			user << "<span class='notice'>You secure the welder.</span>"
		else
			user << "<span class='notice'>The welder can now be attached and modified.</span>"
		add_fingerprint(user)
		return

	if ((!status) && (istype(W,/obj/item/stack/rods)))
		var/obj/item/stack/rods/R = W
		R.use(1)
		var/obj/item/weapon/flamethrower/F = new/obj/item/weapon/flamethrower(user.loc)
		loc = F
		F.weldtool = src
		if (user.client)
			user.client.screen -= src
		if (user.r_hand == src)
			user.remove_from_mob(src)
		else
			user.remove_from_mob(src)
		master = F
		layer = initial(layer)
		user.remove_from_mob(src)
		if (user.client)
			user.client.screen -= src
		loc = F
		add_fingerprint(user)
		return

	..()
	return


/obj/item/weapon/weldingtool/process()
	if (welding)
		if (prob(5))
			remove_fuel(1)

		if (get_fuel() < 1)
			setWelding(0)

	//I'm not sure what this does. I assume it has to do with starting fires...
	//...but it doesnt check to see if the welder is on or not.
	var/turf/location = loc
	if (istype(location, /mob/))
		var/mob/M = location
		if (M.l_hand == src || M.r_hand == src)
			location = get_turf(M)
	if (istype(location, /turf))
		location.hotspot_expose(700, 5)


/obj/item/weapon/weldingtool/afterattack(obj/O as obj, mob/user as mob, proximity)
	if (!proximity) return
	if (istype(O, /obj/structure/reagent_dispensers/fueltank) && get_dist(src,O) <= 1 && !welding)
		O.reagents.trans_to_obj(src, max_fuel)
		user << "<span class='notice'>Welder refueled</span>"
		playsound(loc, 'sound/effects/refill.ogg', 50, TRUE, -6)
		return
	else if (istype(O, /obj/structure/reagent_dispensers/fueltank) && get_dist(src,O) <= 1 && welding)
		message_admins("[key_name_admin(user)] triggered a fueltank explosion with a welding tool.")
		log_game("[key_name(user)] triggered a fueltank explosion with a welding tool.")
		user << "<span class='danger'>You begin welding on the fueltank and with a moment of lucidity you realize, this might not have been the smartest thing you've ever done.</span>"
		var/obj/structure/reagent_dispensers/fueltank/tank = O
		tank.explode()
		return
	if (welding)
		remove_fuel(1)
		var/turf/location = get_turf(user)
		if (isliving(O))
			var/mob/living/L = O
			L.IgniteMob()
		if (istype(location, /turf))
			location.hotspot_expose(700, 50, TRUE)
	return


/obj/item/weapon/weldingtool/attack_self(mob/user as mob)
	setWelding(!welding, usr)
	return

//Returns the amount of fuel in the welder
/obj/item/weapon/weldingtool/proc/get_fuel()
	return reagents.get_reagent_amount("fuel")


//Removes fuel from the welding tool. If a mob is passed, it will perform an eyecheck on the mob. This should probably be renamed to use()
/obj/item/weapon/weldingtool/proc/remove_fuel(var/amount = TRUE, var/mob/M = null)
	if (!welding)
		return FALSE
	if (get_fuel() >= amount)
		reagents.remove_reagent("fuel", amount)
		if (M)
			eyecheck(M)
		return TRUE
	else
		if (M)
			M << "<span class='notice'>You need more welding fuel to complete this task.</span>"
		return FALSE

//Returns whether or not the welding tool is currently on.
/obj/item/weapon/weldingtool/proc/isOn()
	return welding

/obj/item/weapon/weldingtool/update_icon()
	..()
	icon_state = welding ? on_state : off_state
	var/mob/M = loc
	if (istype(M))
		M.update_inv_l_hand()
		M.update_inv_r_hand()

//Sets the welding state of the welding tool. If you see W.welding = TRUE anywhere, please change it to W.setWelding(1)
//so that the welding tool updates accordingly
/obj/item/weapon/weldingtool/proc/setWelding(var/set_welding, var/mob/M)
	if (!status)	return

	var/turf/T = get_turf(src)
	//If we're turning it on
	if (set_welding && !welding)
		if (get_fuel() > 0)
			if (M)
				M << "<span class='notice'>You switch the [src] on.</span>"
			else if (T)
				T.visible_message("<span class='danger'>\The [src] turns on.</span>")
			force = WEAPON_FORCE_PAINFUL
			damtype = "fire"
			w_class = 4
			welding = TRUE
			update_icon()
			set_light(l_range = 1.4, l_power = TRUE, l_color = COLOR_ORANGE)
			processing_objects |= src
		else
			if (M)
				M << "<span class='notice'>You need more welding fuel to complete this task.</span>"
			return
	//Otherwise
	else if (!set_welding && welding)
		processing_objects -= src
		if (M)
			M << "<span class='notice'>You switch \the [src] off.</span>"
		else if (T)
			T.visible_message("<span class='warning'>\The [src] turns off.</span>")
		force = WEAPON_FORCE_WEAK
		damtype = "brute"
		w_class = initial(w_class)
		welding = FALSE
		update_icon()
		set_light(l_range = FALSE, l_power = FALSE, l_color = COLOR_ORANGE)

//Decides whether or not to damage a player's eyes based on what they're wearing as protection
//Note: This should probably be moved to mob
/obj/item/weapon/weldingtool/proc/eyecheck(mob/user as mob)
	if (!iscarbon(user))	return TRUE
	if (istype(user, /mob/living/carbon/human))
		var/mob/living/carbon/human/H = user
		var/obj/item/organ/eyes/E = H.internal_organs_by_name["eyes"]
		if (!E)
			return
		var/safety = H.eyecheck()
		switch(safety)
			if (FLASH_PROTECTION_MODERATE)
				H << "<span class='warning'>Your eyes sting a little.</span>"
				E.damage += rand(1, 2)/2
				if (E.damage > 12)
					H.eye_blurry += rand(3,6)/2
			if (FLASH_PROTECTION_NONE)
				H << "<span class='warning'>Your eyes burn.</span>"
				E.damage += rand(2, 4)/2
				if (E.damage > 10)
					E.damage += rand(4,10)/2
			if (FLASH_PROTECTION_REDUCED)
				H << "<span class='danger'>Your equipment intensify the welder's glow. Your eyes itch and burn severely.</span>"
				H.eye_blurry += rand(12,20)/2
				E.damage += rand(12, 16)/2
		if (safety<FLASH_PROTECTION_MAJOR)
			if (E.damage > 10)
				user << "<span class='warning'>Your eyes are really starting to hurt. This can't be good for you!</span>"

			if (E.damage >= E.min_broken_damage)
				H << "<span class='danger'>You go blind!</span>"
				H.sdisabilities |= BLIND
			else if (E.damage >= E.min_bruised_damage)
				H << "<span class='danger'>You go blind!</span>"
				H.eye_blind = 5
				H.eye_blurry = 5
				H.disabilities |= NEARSIGHTED
				spawn(100)
					H.disabilities &= ~NEARSIGHTED

/obj/item/weapon/weldingtool/largetank
	name = "industrial welding tool"
	max_fuel = 40
//	origin_tech = list(TECH_ENGINEERING = 2)
	matter = list(DEFAULT_WALL_MATERIAL = 70, "glass" = 60)

/obj/item/weapon/weldingtool/hugetank
	name = "upgraded welding tool"
	max_fuel = 80
	w_class = 3.0
//	origin_tech = list(TECH_ENGINEERING = 3)
	matter = list(DEFAULT_WALL_MATERIAL = 70, "glass" = 120)

/obj/item/weapon/weldingtool/experimental
	name = "experimental welding tool"
	max_fuel = 40
	w_class = 3.0
//	origin_tech = list(TECH_ENGINEERING = 4, TECH_PLASMA = 3)
	matter = list(DEFAULT_WALL_MATERIAL = 70, "glass" = 120)
	var/last_gen = FALSE



/obj/item/weapon/weldingtool/experimental/proc/fuel_gen()//Proc to make the experimental welder generate fuel, optimized as fuck -Sieve
	var/gen_amount = ((world.time-last_gen)/25)
	reagents += (gen_amount)
	if (reagents > max_fuel)
		reagents = max_fuel

/*
 * Crowbar
 */

/obj/item/weapon/crowbar
	name = "crowbar"
	desc = "Used to remove floors and to pry open doors."
	icon = 'icons/obj/items.dmi'
	icon_state = "crowbar"
	flags = CONDUCT
	slot_flags = SLOT_BELT
	force = WEAPON_FORCE_PAINFUL
	throwforce = WEAPON_FORCE_NORMAL
	item_state = "crowbar"
	w_class = 2.0
//	origin_tech = list(TECH_ENGINEERING = TRUE)
	matter = list(DEFAULT_WALL_MATERIAL = 50)
	attack_verb = list("attacked", "bashed", "battered", "bludgeoned", "whacked")

/obj/item/weapon/crowbar/red
	icon = 'icons/obj/items.dmi'
	icon_state = "red_crowbar"
	item_state = "crowbar_red"

/obj/item/weapon/weldingtool/afterattack(var/mob/M, var/mob/user)

	if (ishuman(M))
		var/mob/living/carbon/human/H = M
		var/obj/item/organ/external/S = H.organs_by_name[user.targeted_organ]

		if (!S) return
		if (!(S.status & ORGAN_ROBOT) || user.a_intent != I_HELP)
			return ..()

		if (S.brute_dam)
			if (S.brute_dam < ROBOLIMB_SELF_REPAIR_CAP)
				S.heal_damage(15,0,0,1)
				user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
				user.visible_message("<span class='notice'>\The [user] patches some dents on \the [M]'s [S.name] with \the [src].</span>")
			else if (S.open != 2)
				user << "<span class='danger'>The damage is far too severe to patch over externally.</span>"
			return TRUE
		else if (S.open != 2)
			user << "<span class='notice'>Nothing to fix!</span>"

	else
		return ..()