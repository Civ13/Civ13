// backend member functions for complex_animals, which call frontend hooks
/mob/living/simple_animal/complex_animal/New()
	..()
	resting_state = "[icon_state]_rest"
	dead_state = "[icon_state]_dead"
	icon_dead = dead_state

/mob/living/simple_animal/complex_animal/Life()
	..()
	onEveryLifeTick()

/mob/living/simple_animal/complex_animal/death(gibbed, deathmessage = "dies!")
	..(gibbed,deathmessage)
	icon_state = dead_state

/mob/living/simple_animal/complex_animal/attack_hand(var/mob/living/carbon/human/H as mob)
	..(H)
	onTouchedBy(H, H.a_intent)

/mob/living/simple_animal/complex_animal/attackby(var/obj/item/weapon/W as obj, var/mob/living/carbon/human/H as mob)
	..(W, H)
	onAttackedBy(H, W)

// movement detection
/mob/living/simple_animal/complex_animal/Move()
	..()
	// I used to do a 'in range(30, src)' check here, it caused MASSIVE cpu usage
	for (var/mob/living/L in living_mob_list)
		if (L == src)
			continue
		if (istype(L, /mob/living/simple_animal/complex_animal))
			var/mob/living/simple_animal/complex_animal/C = L
			// range() can get extremely expensive so do this insteads
			var/dist_x = abs(x - C.x)
			var/dist_y = abs(x - C.y)
			if (prob(90) && dist_x <= C.sightrange && dist_y <= C.sightrange)
				C.knows_about_mobs |= src
			else if (prob(45) && dist_x <= C.hearrange && dist_y <= C.hearrange)
				C.knows_about_mobs |= src
			else if (prob(22) && dist_x <= C.smellrange && dist_y <= C.smellrange)
				C.knows_about_mobs |= src
			else if (vars.Find("base_type") && src:base_type == C.base_type)
				if (dist_x <= 10 && dist_y <= 10)
					C.onEveryBaseTypeMovement(src)
			else
				if (dist_x <= 10 && dist_y <= 10)
					C.onEveryXMovement(type)