/mob/living/simple_animal/parrot
	name = "Parrot"
	desc = "A parrot. Maybe it can sit on your shoulder?."
	icon = 'icons/mob/animal.dmi'
	icon_state = "parrot_sit"
	icon_living = "parrot_sit"
	icon_dead = "parrot_dead"
	speak_emote = list("squawks")
	health = 25
	maxHealth = 25
	attacktext = "bitten"
	melee_damage_lower = 2
	melee_damage_upper = 5
	response_help  = "pets"
	response_disarm = "shoos"
	response_harm   = "hits"
	mob_size = MOB_SMALL
	possession_candidate = TRUE