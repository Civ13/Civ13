
/mob/living/simple_animal/hostile/buffalo
	name = "buffalo"
	desc =  "A Large member of the Bovine Family, They are grazers and will be hostile if harmed."
	icon = 'icons/mob/animal_64.dmi'
	icon_state = "buffalo"
	icon_living = "buffalo"
	icon_dead = "buffalo_dead"
	speak_emote = list("Gnnnnnrrrr", "Moooooo", "Pnhhhh")
	emote_hear = list("Grunts", "Puffs")
	health = 350
	maxHealth = 350
	move_to_delay = 5
	turns_per_move = 4
	attacktext = "charges into"
	melee_damage_lower = 35
	melee_damage_upper = 50
	response_help  = "pets"
	response_disarm = "shoos"
	response_harm   = "punches"
	faction = list("neutral")
	mob_size = MOB_LARGE
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/meat
	behaviour = "defends"