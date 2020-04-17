/mob/living/simple_animal/hostile/fox
	name = "fox"
	desc = "A small fox."
	icon_state = "fox"
	icon_living = "fox"
	icon_dead = "fox_dead"
	icon_gib = "fox_gib"
	speak = list("GRRR!","Wooh!","Wuuh!")
	speak_emote = list("growls")
	emote_hear = list("growls","whimps")
	emote_see = list("stares alertly", "sniffs the ground")
	speak_chance = TRUE
	move_to_delay = 3
	see_in_dark = 6
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/meat
	response_help  = "pets"
	response_disarm = "gently pushes aside"
	response_harm   = "pokes"
	stop_automated_movement_when_pulled = FALSE
	maxHealth = 25
	health = 25
	melee_damage_lower = 8
	melee_damage_upper = 14
	mob_size = MOB_SMALL
	carnivore = 1
	scavenger = 1
	behaviour = "defends"

/mob/living/simple_animal/hostile/fox/arctic
	name = "arctic fox"
	desc = "A small white fox."
	icon_state = "arcticfox"
	icon_living = "arcticfox"
	icon_dead = "arcticfox_dead"
	icon_gib = "arcticfox_gib"