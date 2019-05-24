/mob/living/simple_animal/hostage
	name = "Hostage"
	desc = "A poor guy made hostage."
	icon = 'icons/mob/animal.dmi'
	icon_state = "hostage_m1"
	icon_living = "hostage_m1"
	icon_dead = "hostage_m1_dead"
	speak = list("Oh god!","Please don't!","AAAAAAH!")
	speak_emote = list("cries","screams","sobs")
	speak_emote = list("cries","screams","sobs")
	emote_see = list("walks around", "waves his hands", "trembles in fear")
	meat_amount = 2
	attacktext = "hit"
	melee_damage_lower = 6
	melee_damage_upper = 9
	mob_size = MOB_MEDIUM
	possession_candidate = FALSE
	turns_per_move = 4
	response_help = "pushes"
	response_disarm = "shoves"
	response_harm = "hits"
	speak_chance = FALSE
	speed = 4
	maxHealth = 150
	health = 150
	stop_automated_movement_when_pulled = TRUE
	stop_automated_movement = TRUE
	wander = FALSE

/mob/living/simple_animal/hostage/New()
	..()
	icon_state = "hostage_m[rand(1,5)]"
	icon_living = icon_state
	icon_dead = "[icon_state]_dead"
	update_icons()