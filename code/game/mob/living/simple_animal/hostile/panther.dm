
/mob/living/simple_animal/hostile/panther
	name = "panther"
	desc = "Better start running..."
	icon = 'icons/mob/animal_big.dmi'
	icon_state = "panther"
	icon_living = "panther"
	icon_dead = "panther_dead"
	icon_gib = "panther_gib"
	speak = list("GRRR!","rawrr","RAWR!","RRRRR!")
	speak_emote = list("growls", "roars")
	emote_hear = list("growls","roars","buffs")
	emote_see = list("stares ferociously", "sniffs the ground")
	speak_chance = TRUE
	move_to_delay = 3
	see_in_dark = 6
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/meat
	response_help  = "pets"
	response_disarm = "gently pushes aside"
	response_harm   = "pokes"
	stop_automated_movement_when_pulled = FALSE
	maxHealth = 45
	health = 45
	melee_damage_lower = 12
	melee_damage_upper = 23
	mob_size = MOB_MEDIUM
	predatory_carnivore = 1
	carnivore = 1
	faction = "neutral"

/mob/living/simple_animal/hostile/panther/jaguar
	name = "jaguar"
	icon_state = "jaguar"
	icon_living = "jaguar"
	icon_dead = "jaguar_dead"
	icon_gib = "jaguar_gib"