/* complex_animals are based off of simple_animals. They have more complex
  AI, require food, and have stamina. */

/mob/living/simple_animal/complex_animal

	var/base_type = /mob/living/simple_animal/complex_animal
	var/stamina = 100
	var/nutrition = 500
	var/mob/owner = null
	// from how far away can we detect others: must be below or = 30.
	// sight is more accurate than hearing, and hearing more than smelling.
	var/sightrange = 7
	var/hearrange = 10
	var/smellrange = 12
	var/list/knows_about_mobs = list()

	// who are we going to kill or not kill: by default we do NOT kill anyone
	var/friendly_to_base_type = TRUE
	var/list/unfriendly_types = list()

	// if a mob is in unfriendly_types() but friendly_factions(), faction wins
	// for example, guard dogs are unfriendly to humans, except those in their
	// faction
	var/list/friendly_factions = list()

	// any specific people we like or dislike: overrides everything else
	var/list/friends = list()
	var/list/enemies = list()

	// icons
	icon = 'icons/mob/animal.dmi'
	icon_state = null
	var/resting_state = null
	var/dead_state = null

	// can we move outside of the area we started in, or an area we were moved to
	var/allow_moving_outside_home = FALSE

	// how likely are we to try and wander each lifetick
	var/wander_probability = 20

	// simple_animal overrides
	response_help   = "pets"
	response_disarm = "pushes"
	response_harm   = "punches"

	//list of people trying to pet the animal
	var/list/friendly_mobs = list()
	var/tameminimum = 100 // minimum friendly value to tame an animal
	var/tamed = FALSE
	var/starving = FALSE
// things we do every life tick: by default, wander every few seconds,
// rest every ~20 minutes. Deplete nutrition over ~30 minutes
/mob/living/simple_animal/complex_animal/proc/onEveryLifeTick()

	if (stat == DEAD)
		return FALSE

	if (!client)
		if (prob(1) && prob(15) && !resting && can_rest_specialcheck())
			nap()
		else if (resting && prob(1))
			stop_napping()

	// todo: dehydration

	var/nutrition_loss = initial(nutrition)/900
	if (resting)
		nutrition_loss /= 2

	nutrition -= nutrition_loss

	if (nutrition <= initial(nutrition)*0.2)
		//start starving. Will attack animals for food
		starving = TRUE
	else
		starving = FALSE

	if (nutrition <= 0)
		adjustBruteLoss(1)
		nutrition = 5
		visible_message("\The [src] is starving!")

	if (stat == UNCONSCIOUS)
		return -1

	if (!client)
		if (starving)
			var/targeting = FALSE
			var/mob/living/simple_animal/targetmob = null
			for (var/mob/living/simple_animal/SA in range(9) && !targeting)
				if (SA.mob_size <= mob_size && !targeting && SA.faction != faction) // only attack smaller animals
					walk_to(src, SA, TRUE, 4)
					targeting = TRUE
					targetmob = SA
			if (targetmob)
				if (get_dist(src, targetmob) <= 1)
					if (targetmob.stat == DEAD)
						visible_message("\The [src] eats \the [targetmob]!")
						nutrition += targetmob.mob_size*12
						qdel (targetmob)
					else
						visible_message("\The [src] attacks \the [targetmob]!")
						do_attack_animation(targetmob)
						targetmob.health -= rand(8,13)
		else
			if (prob(wander_probability) && !resting && can_wander_specialcheck())
				var/list/possible_wander_locations = list()
				for (var/turf/T in range(1, src))
					if (!T.density && !istype(T, /turf/wall))
						for (var/atom/movable/AM in T.contents)
							if (AM.density)
								continue
						if (get_area(T) != get_area(src))
							if (!allow_moving_outside_home)
								continue
						if (istype(src, /mob/living/simple_animal/complex_animal/dog))
							var/mob/living/simple_animal/complex_animal/dog/D = src
							if (D.last_patrol_area == get_area(T))
								continue

						possible_wander_locations += T

				// patrolling dogs will always exit their current area if possible
				var/list/possible_wander_areas = list()
				var/area/forced_wander_area = null

				for (var/turf/T in possible_wander_locations)
					possible_wander_areas |= get_area(T)

				// patrolling dogs will always try to exit their area.
				if (possible_wander_areas.len > 1)
					for (var/area/A in possible_wander_areas)
						if (istype(src, /mob/living/simple_animal/complex_animal/dog))
							var/mob/living/simple_animal/complex_animal/dog/D = src
							if (D.patrolling)
								if (A != get_area(src))
									forced_wander_area = A

				for (var/turf/T in possible_wander_locations)
					if (!forced_wander_area || get_area(T) == forced_wander_area)

						if (forced_wander_area)
							if (istype(src, /mob/living/simple_animal/complex_animal/dog))
								var/mob/living/simple_animal/complex_animal/dog/D = src
								if (D.last_patrol_area == get_area(T))
									continue

						if (istype(src, /mob/living/simple_animal/complex_animal/dog))
							var/mob/living/simple_animal/complex_animal/dog/D = src
							D.last_patrol_area = get_area(get_turf(D))

						Move(T, get_dir(loc, T))

	return TRUE

	// todo: starvation

/mob/living/simple_animal/complex_animal/proc/can_wander_specialcheck()
	return TRUE

/mob/living/simple_animal/complex_animal/proc/can_rest_specialcheck()
	return TRUE

// things we do when someone touches us
/mob/living/simple_animal/complex_animal/proc/onTouchedBy(var/mob/living/human/H, var/intent = I_HELP)
	if (stat == DEAD || stat == UNCONSCIOUS || client)
		return FALSE
	return TRUE

// things we do when someone attacks us
/mob/living/simple_animal/complex_animal/proc/onAttackedBy(var/mob/living/human/H, var/obj/item/weapon/W)
	if (stat == DEAD || stat == UNCONSCIOUS || client)
		return FALSE
	return TRUE

/* things we do whenever a nearby human moves:
called after H added to knows_about_mobs() */
/mob/living/simple_animal/complex_animal/proc/onHumanMovement(var/mob/living/human/H)
	if (stat == DEAD || stat == UNCONSCIOUS || client)
		return FALSE
	return TRUE

// things we do whenever a mob with our base_type moves
/mob/living/simple_animal/complex_animal/proc/onEveryBaseTypeMovement(var/mob/living/simple_animal/complex_animal/C)
	if (stat == DEAD || stat == UNCONSCIOUS || client)
		return FALSE
	return TRUE

// things we do whenever a mob with type 'X' moves
/mob/living/simple_animal/complex_animal/proc/onEveryXMovement(var/mob/X)
	if (stat == DEAD || stat == UNCONSCIOUS || client)
		return FALSE
	return TRUE


/mob/living/simple_animal/complex_animal/bullet_act(var/obj/item/projectile/P, var/def_zone)
	var/dmg = P.damage * random_decimal(0.7,1.3)
	if (prob(33))
		dmg /= rand(5,10)
		visible_message("<span class = 'warning'>The [P.name] just grazes \the [src].</span>")
	apply_damage(dmg)
	if (client)
		var/m_faction = P.firer.faction
		if (istype(P, /mob/living/carbon/human))
			var/mob/living/carbon/human/H = P
			if (map.civilizations)
				m_faction = H.civilization
			else
				m_faction = H.faction_text
		if (P.firer && (P.original == src || !P.firer.original_job || m_faction != faction))
			enemies |= P.firer
			onHumanMovement(P.firer)
			for (var/mob/living/simple_animal/complex_animal/C in oview(7, src))
				if (C.faction == faction && C.type == type)
					C.enemies |= P.firer
					C.onHumanMovement(P.firer)

/mob/living/simple_animal/complex_animal/death(gibbed, deathmessage = "dies!")
	..(gibbed, deathmessage)
	walk(src, FALSE)
	lying = TRUE