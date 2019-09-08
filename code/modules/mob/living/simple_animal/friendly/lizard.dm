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
