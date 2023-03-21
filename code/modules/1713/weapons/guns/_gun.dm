/obj/item/weapon/gun
	var/gun_safety = FALSE
	var/safetyon = FALSE
	var/obj/item/weapon/attachment/scope/adjustable/advanced/specialoptics = null
	var/obj/item/weapon/attachment/under/under = null
	var/pocket = FALSE

/obj/item/weapon/gun/Destroy()
	attachments = null
	contents = null
	..()

/obj/item/weapon/gun/attackby(obj/item/I, mob/user)
	if (istype(I, /obj/item/weapon/attachment))
		var/obj/item/weapon/attachment/A = I
		if (A.attachable)
			try_attach(A, user)
	if (istype(I, /obj/item/weapon/gun/launcher/grenade/underslung))
		var/obj/item/weapon/gun/launcher/grenade/underslung/G = I
		try_attach(G, user)
	..()

/obj/item/weapon/gun/projectile
	var/accuracy_list = list(

		// small body parts: head, hand, feet
		"small" = list(
			SHORT_RANGE_STILL = 100,
			SHORT_RANGE_MOVING = 50,

			MEDIUM_RANGE_STILL = 50,
			MEDIUM_RANGE_MOVING = 25,

			LONG_RANGE_STILL = 25,
			LONG_RANGE_MOVING = 12,

			VERY_LONG_RANGE_STILL = 12,
			VERY_LONG_RANGE_MOVING = 6),

		// medium body parts: limbs
		"medium" = list(
			SHORT_RANGE_STILL = 100,
			SHORT_RANGE_MOVING = 50,

			MEDIUM_RANGE_STILL = 50,
			MEDIUM_RANGE_MOVING = 25,

			LONG_RANGE_STILL = 25,
			LONG_RANGE_MOVING = 12,

			VERY_LONG_RANGE_STILL = 12,
			VERY_LONG_RANGE_MOVING = 6),

		// large body parts: chest, groin
		"large" = list(
			SHORT_RANGE_STILL = 100,
			SHORT_RANGE_MOVING = 50,

			MEDIUM_RANGE_STILL = 50,
			MEDIUM_RANGE_MOVING = 25,

			LONG_RANGE_STILL = 25,
			LONG_RANGE_MOVING = 12,

			VERY_LONG_RANGE_STILL = 12,
			VERY_LONG_RANGE_MOVING = 6)
	)

	var/accuracy_increase_mod = 1.00
	var/accuracy_decrease_mod = 1.00
	var/effectiveness_mod = 1.00
	var/KD_chance = 5
	var/stat = "rifle"
	var/load_delay = 0

	equiptimer = 10

	var/headshot_kill_chance = 40 // if we have enough damage. See projectile.dm if you want to know why this needs to be set to 40 for all guns - Kachnov
	var/KO_chance = 33 // even if we fail to kill with a headshot, chance to make the target go unconscious

	// does not need to include all organs
	var/list/redirection_chances = list(
		"l_hand" = list("l_arm" = 30, "chest" = 10, "groin" = 10),
		"r_hand" = list("r_arm" = 30, "chest" = 10, "groin" = 10),
		"l_foot" = list("l_leg" = 50),
		"r_foot" = list("r_leg" = 50),
		"chest" = list("l_arm" = 7, "r_arm" = 7, "head" = 7)
	)

	// must include all organs
	var/list/adjacent_redirections = list(
		"eyes" = list("head"),
		"mouth" = list("head"),
		"head" = list("head", "chest", "l_arm", "r_arm"), // "shoulders"
		"chest" = list("chest", "head", "l_arm", "r_arm", "l_leg", "r_leg"),
		"groin" = list("groin", "chest", "l_leg", "r_leg"),
		"l_arm" =  list("l_arm", "l_hand", "chest"),
		"r_arm" =  list("r_arm", "r_hand", "chest"),
		"l_leg" =  list("l_leg", "l_foot", "groin"),
		"r_leg" =  list("r_leg", "r_foot", "groin"),
		"l_hand" =  list("l_arm", "chest", "groin"),
		"r_hand" =  list("r_arm", "chest", "groin"),
		"l_foot" =  list("l_foot", "l_leg"),
		"r_foot" =  list("r_foot", "r_leg")
	)

	var/aim_miss_chance_divider = 1.50
	var/mob/living/human/firer = null
	var/blackpowder = FALSE
	secondary_action = TRUE
	var/sniper_scope = FALSE
/obj/item/weapon/gun/projectile/secondary_attack_self(mob/living/human/user)
	if (gun_safety)
		if (safetyon)
			safetyon = FALSE
			user << "<span class='notice'>You toggle \the [src]'s safety <b>OFF</b>.</span>"
			return
		else
			safetyon = TRUE
			user << "<span class='notice'>You toggle \the [src]'s safety <b>ON</b>.</span>"
			return

/obj/item/weapon/gun/projectile/special_check(var/mob/user)
	if (gun_safety && safetyon)
		user << "<span class='warning'>You can't fire \the [src] while the safety is on!</span>"
		return FALSE
	return ..()
/obj/item/weapon/gun/projectile/proc/calculate_miss_chance(zone, var/mob/target)

	if (ismob(loc))
		firer = loc
	else if (isturf(loc))
		if (istype(src, /obj/item/weapon/gun/projectile/automatic/stationary))
			for (var/mob/living/L in loc)
				if (L.using_MG == src)
					firer = L
					break
		else
			for (var/mob/living/L in loc)
				firer = L
				break

	if (!firer || !target || !istype(target))
		return prob(50)

	if (!istype(firer))
		return prob(50)

	var/accuracy_sublist = accuracy_list["large"]

	switch (zone)
		if ("l_leg", "r_leg", "l_arm", "r_arm")
			accuracy_sublist = accuracy_list["medium"]
		if ("l_hand", "r_hand", "l_foot", "r_foot", "head", "mouth", "eyes")
			accuracy_sublist = accuracy_list["small"]

	. = get_base_miss_chance(accuracy_sublist, target)
	var/modif = 1
	if (firer.religion_check() == "Combat")
		modif = 1.1

	var/firer_stat = firer.getStatCoeff(stat)*modif

	var/miss_chance_modifier = 1.00

//	log_debug("initial miss chance: [.]")

	if (firer_stat > 1.00)
		miss_chance_modifier -= ((firer_stat - 1.00) * accuracy_increase_mod)/5
	else if (firer_stat < 1.00)
		miss_chance_modifier += ((1.00 - firer_stat) * accuracy_decrease_mod)/5
	if (firer.prone)
		effectiveness_mod *= 1.1
	if (specialoptics)
		if ((specialoptics.scopeonly && specialoptics.zoomed) || !specialoptics.scopeonly)
			var/effmod2 = effectiveness_mod
			effmod2 *= specialoptics.acc_modifier
			if (effmod2 != 0)
				. /= effmod2
	else if (under)
		if ((under.scopeonly && specialoptics.zoomed) || !under.scopeonly)
			var/effmod3 = effectiveness_mod
			effmod3 *= under.acc_modifier
			if (effmod3 != 0)
				. /= effmod3
	else
		. /= effectiveness_mod

	var/d1 = abs(firer.x - target.x)
	var/d2 = abs(firer.y - target.y)
	var/d3 = round((d1 + d2)/2)
	var/distance = max(d1, d2, d3)

	// nothing can save you at point blank range - Kachnov
	if (distance != 1)
		if (zone == "mouth" || zone == "eyes")
			var/hitchance = 100 - .
			hitchance /= 2.00 // this used to be 3, needs to be 2 to double to triple miss chance
			. = ceil(100 - hitchance)

		else if (zone == "head")
			var/hitchance = 100 - .
			hitchance /= 1.33 // this used to be 2 and made headshots really inaccurate, needs to be 1.33 to "double" miss chance - Kachnov
			. = ceil(100 - hitchance)

		// gas masks make you less accurate now
		if (firer.wear_mask)
			var/hitchance = 100 - .
			hitchance /= 1.10
			. = ceil(100 - hitchance)
	if (firer.tactic == "aim")
		. *= 1.1
	. = min(CLAMP0100(.), 99) // minimum hit chance is 2% no matter what
//	log_debug(.)

//	log_debug("final miss chance: [.]")

	return .

/obj/item/weapon/gun/projectile/proc/get_base_miss_chance(var/accuracy_sublist, var/mob/target)
	var/moving_target = target.lastMovedRecently(target.get_run_delay(), TRUE)
	var/abs_x = abs(firer.x - target.x)
	var/abs_y = abs(firer.y - target.y)
	var/pythag = round((abs_x + abs_y)/2)
	var/distance = max(abs_x, abs_y, pythag)
	// note: the screen is 15 tiles wide by default, so a person more than 7 tiles (ZOOM_CONSTANT) away from you x/y won't be on screen
	// . = miss chance
	switch (distance)
		if (0 to 1)
			. = 0
		if (2 to 4)
			if (!moving_target)
				. =  (100 - accuracy_sublist[SHORT_RANGE_STILL])
			else
				. =  (100 - accuracy_sublist[SHORT_RANGE_MOVING])
		if (4 to ZOOM_CONSTANT)
			if (!moving_target)
				. =  (100 - accuracy_sublist[MEDIUM_RANGE_STILL])
			else
				. =  (100 - accuracy_sublist[MEDIUM_RANGE_MOVING])
		if (ZOOM_CONSTANT to ZOOM_CONSTANT*2)
			if (!moving_target)
				. =  (100 - accuracy_sublist[LONG_RANGE_STILL])
			else
				. =  (100 - accuracy_sublist[LONG_RANGE_MOVING])
		if (ZOOM_CONSTANT*2 to INFINITY)
			if (!moving_target)
				. =  (100 - accuracy_sublist[VERY_LONG_RANGE_STILL])
			else
				. =  (100 - accuracy_sublist[VERY_LONG_RANGE_MOVING])
	return .


// replaces proc/get_zone_with_miss_chance
/obj/item/weapon/gun/projectile/proc/get_zone(var/zone, var/mob/target, var/miss_chance = 0)
	// 10% miss chance = 90% hit chance, etc
	var/hit_chance = 100 - (miss_chance ? miss_chance : calculate_miss_chance(zone, target))
//	log_debug("MC: [miss_chance]")
//	log_debug("HC: [hit_chance]")
	// We hit. Return the zone or a zone in redirection_chances[zone]
	if (prob(hit_chance))
		if (zone in redirection_chances)
			for (var/nzone in redirection_chances[zone])
				if (prob(redirection_chances[zone][nzone]))
					zone = nzone
					break
		return zone
	// We didn't hit, and the target is running. Give us a chance to hit something in adjacent_redirections[zone]
	else if (target.lastMovedRecently(target.get_run_delay(), TRUE))

		var/hitchance_still = round((accuracy_list["small"][SHORT_RANGE_STILL]/accuracy_list["small"][SHORT_RANGE_MOVING]) * hit_chance)
		var/hitchance_delta = hitchance_still - hit_chance

//		log_debug("1: [hitchance_still]")
//		log_debug("2: [hitchance_delta]")

		if (hitchance_still && hitchance_delta)
			if (prob(ceil(hitchance_delta * 0.75)))
				if (!(zone in adjacent_redirections)) // wtf
					log_debug("No '[zone]' found in '[src].adjacent_redirections'! Returning null (_gun.dm, ~line 200)")
					return null
				return pick(adjacent_redirections[zone])
		else if (!hitchance_delta)
			if (hitchance_delta < 0)
				log_debug("hitchance_delta in '[src].get_zone()' was a value < 0! ([hitchance_delta]) (_gun.dm, ~line 200)")
			return null
		else if (!hitchance_still)
			if (hitchance_still < 0)
				log_debug("hitchance_still in '[src].get_zone()' was a value < 0! ([hitchance_still]) (_gun.dm, ~line 200)")
			return null

	// We missed.
	return null