/mob/living/simple_animal/lizard
	name = "lizard"
	desc = "A cute tiny lizard."
	icon = 'icons/mob/critter.dmi'
	icon_state = "lizard"
	icon_living = "lizard"
	icon_dead = "lizard-dead"
	speak_emote = list("hisses")
	health = 5
	maxHealth = 5
	attacktext = "bitten"
	melee_damage_lower = TRUE
	melee_damage_upper = 2
	response_help  = "pets"
	response_disarm = "shoos"
	response_harm   = "stomps on"
	mob_size = MOB_MINISCULE
	possession_candidate = TRUE

/mob/living/simple_animal/lizard/Life()
	for (var/mob/living/simple_animal/mosquito/M in range(1,src))
		visible_message("\The [src] eats \the [M]!")
		qdel(M)
		adjustBruteLoss(-1)
	for (var/mob/living/simple_animal/fly/F in range(1,src))
		visible_message("\The [src] eats \the [F]!")
		qdel(F)
		adjustBruteLoss(-1)
	for (var/mob/living/simple_animal/cockroach/C in range(1,src))
		visible_message("\The [src] eats \the [C]!")
		qdel(C)
		adjustBruteLoss(-1)
	..()

/mob/living/simple_animal/frog
	name = "frog"
	desc = "A cute tiny frog."
	icon = 'icons/mob/animal.dmi'
	icon_state = "frog"
	icon_living = "frog"
	icon_dead = "frog-dead"
	speak_emote = list("croaks")
	health = 5
	maxHealth = 5
	attacktext = "bitten"
	melee_damage_lower = TRUE
	melee_damage_upper = 2
	response_help  = "pets"
	response_disarm = "shoos"
	response_harm   = "stomps on"
	mob_size = MOB_MINISCULE
	possession_candidate = TRUE

/mob/living/simple_animal/frog/Life()
	for (var/mob/living/simple_animal/mosquito/M in range(1,src))
		visible_message("\The [src] eats \the [M]!")
		qdel(M)
		adjustBruteLoss(-1)
	for (var/mob/living/simple_animal/fly/F in range(1,src))
		visible_message("\The [src] eats \the [F]!")
		qdel(F)
		adjustBruteLoss(-1)
	if (prob(1) && prob(17)) //roughly every 10 mins
		var/frogCount = 0
		for(var/mob/living/simple_animal/frog/M in range(6,src))
			frogCount++
		if (frogCount <= 2)
			if (isturf(loc) || istype(loc, /turf/floor/beach/water))
				new/obj/item/weapon/reagent_containers/food/snacks/frogegg(src.loc)
			else if (isturf(loc) && !istype(loc, /turf/floor/beach/water))
				for(var/turf/floor/beach/water/WT in range(6,src))
					walk_towards(src, WT, move_to_delay)
					spawn(10)
						new/obj/item/weapon/reagent_containers/food/snacks/frogegg(WT)
					break
	..()
/mob/living/simple_animal/frog/poisonous
	name = "poisonous frog"
	desc = "A tiny, colorful frog. Poisonous!"
	icon = 'icons/mob/animal.dmi'
	icon_state = "frog_poisonous"
	icon_living = "frog_poisonous"
	icon_dead = "frog_poisonous-dead"
	speak_emote = list("croaks")
	health = 5
	maxHealth = 5
	attacktext = "bitten"
	melee_damage_lower = TRUE
	melee_damage_upper = 2
	response_help  = "pets"
	response_disarm = "shoos"
	response_harm   = "stomps on"
	mob_size = MOB_MINISCULE
	possession_candidate = TRUE

/obj/item/weapon/reagent_containers/food/snacks/frogegg
	name = "frog eggs"
	desc = "A bunch of small frog eggs"
	icon_state = "amphibianeggs_1"
	icon = 'icons/mob/animal.dmi'
	nutriment_amt = 1
	nutriment_desc = list("slime" = 1)
	decay = 25*600
	var/amount_grown = 0
	var/growing = FALSE
	satisfaction = -5
	non_vegetarian = TRUE


/obj/item/weapon/reagent_containers/food/snacks/frogegg/New()
	..()
	spawn(50)
		process()
	icon_state = "amphibianeggs_[rand(1,3)]"
	var/nearbyObjects = range(5,src) //5x5 area around
	var/frogCount = 0

	for(var/mob/living/simple_animal/frog/M in nearbyObjects)
		frogCount++

	if (frogCount <= 2 && growing == FALSE) // max 2 in a 5x5 area for eggs to start hatching
		growing = TRUE
		grow()

/obj/item/weapon/reagent_containers/food/snacks/frogegg/proc/grow()
	if (isturf(loc) || istype(loc, /turf/floor/beach/water))
		amount_grown += 1
		if (amount_grown >= 400)
			new /mob/living/simple_animal/frog(get_turf(src))
			processing_objects -= src
			qdel(src)
			return
		else
			spawn(40)
				grow()

	else
		processing_objects -= src
		growing = FALSE
		return

/mob/living/simple_animal/ianthasaurus
	name = "ianthasaurus"
	desc = "A cute tiny ianthasaurus."
	icon = 'icons/mob/critter.dmi'
	icon_state = "ianthasaurus"
	icon_living = "ianthasaurus"
	icon_dead = "ianthasaurus_dead"
	speak_emote = list("hisses")
	health = 10
	maxHealth = 10
	attacktext = "bitten"
	melee_damage_lower = TRUE
	melee_damage_upper = 2
	response_help  = "pets"
	response_disarm = "shoos"
	response_harm   = "stomps on"
	mob_size = MOB_MINISCULE
	possession_candidate = TRUE
	scavenger = 1

/mob/living/simple_animal/ianthasaurus/Life()
	for (var/mob/living/simple_animal/mosquito/M in range(1,src))
		visible_message("\The [src] eats \the [M]!")
		qdel(M)
		adjustBruteLoss(-1)
	for (var/mob/living/simple_animal/fly/F in range(1,src))
		visible_message("\The [src] eats \the [F]!")
		qdel(F)
		adjustBruteLoss(-1)
	for (var/mob/living/simple_animal/cockroach/C in range(1,src))
		visible_message("\The [src] eats \the [C]!")
		qdel(C)
		adjustBruteLoss(-1)
	..()


/mob/living/simple_animal/tiktaalik
	name = "tiktaalik"
	desc = "A cute tiny amphibian like fish with fin legs."
	icon = 'icons/mob/animal.dmi'
	icon_state = "tiktaalik"
	icon_living = "tiktaalik"
	icon_dead = "tiktaalik_dead"
	speak_emote = list("screaches")
	health = 6
	maxHealth = 6
	attacktext = "bitten"
	melee_damage_lower = TRUE
	melee_damage_upper = 2
	response_help  = "pets"
	response_disarm = "shoos"
	response_harm   = "stomps on"
	mob_size = MOB_MINISCULE
	possession_candidate = TRUE

/mob/living/simple_animal/tiktaalik/Life()
	for (var/mob/living/simple_animal/mosquito/M in range(1,src))
		visible_message("\The [src] eats \the [M]!")
		qdel(M)
		adjustBruteLoss(-1)
	for (var/mob/living/simple_animal/fly/F in range(1,src))
		visible_message("\The [src] eats \the [F]!")
		qdel(F)
		adjustBruteLoss(-1)
	for (var/mob/living/simple_animal/cockroach/C in range(1,src))
		visible_message("\The [src] eats \the [C]!")
		qdel(C)
		adjustBruteLoss(-1)
	..()

/mob/living/simple_animal/ichthyostega
	name = "ichthyostega"
	desc = "An early amphibian with fully formed legs."
	icon = 'icons/mob/animal.dmi'
	icon_state = "ichthyostega"
	icon_living = "ichthyostega"
	icon_dead = "ichthyostega_dead"
	speak_emote = list("screaches")
	health = 8
	maxHealth = 8
	attacktext = "bitten"
	melee_damage_lower = TRUE
	melee_damage_upper = 2
	response_help  = "pets"
	response_disarm = "shoos"
	response_harm   = "stomps on"
	mob_size = MOB_MINISCULE
	possession_candidate = TRUE

/mob/living/simple_animal/ichthyostega/Life()
	for (var/mob/living/simple_animal/mosquito/M in range(1,src))
		visible_message("\The [src] eats \the [M]!")
		qdel(M)
		adjustBruteLoss(-1)
	for (var/mob/living/simple_animal/fly/F in range(1,src))
		visible_message("\The [src] eats \the [F]!")
		qdel(F)
		adjustBruteLoss(-1)
	for (var/mob/living/simple_animal/cockroach/C in range(1,src))
		visible_message("\The [src] eats \the [C]!")
		qdel(C)
		adjustBruteLoss(-1)
	..()

/mob/living/simple_animal/beelzebufo
	name = "beelzebufo"
	desc = "A creepy giant frog."
	icon = 'icons/mob/animal.dmi'
	icon_state = "beelzebufo"
	icon_living = "beelzebufo"
	icon_dead = "beelzebufo-dead"
	speak_emote = list("croaks", "grumbles")
	health = 15
	maxHealth = 5
	attacktext = "bitten"
	melee_damage_lower = TRUE
	melee_damage_upper = 2
	response_help  = "pets"
	response_disarm = "shoos"
	response_harm   = "stomps on"
	mob_size = MOB_MINISCULE
	possession_candidate = TRUE

/mob/living/simple_animal/beelzebufo/Life()
	for (var/mob/living/simple_animal/mosquito/M in range(1,src))
		visible_message("\The [src] eats \the [M]!")
		qdel(M)
		adjustBruteLoss(-1)
	for (var/mob/living/simple_animal/fly/F in range(1,src))
		visible_message("\The [src] eats \the [F]!")
		qdel(F)
		adjustBruteLoss(-1)
	for (var/mob/living/simple_animal/cockroach/C in range(1,src))
		visible_message("\The [src] eats \the [C]!")
		qdel(C)
		adjustBruteLoss(-1)
	..()