/mob/living/simple_animal/boar
	name = "boar"
	desc = "A male boar."
	icon_state = "boar_male"
	icon_living = "boar_male"
	icon_dead = "boar_male_dead"
	icon_gib = "boar_male_dead"
	speak = list("Snort!","Puff!")
	speak_emote = list("snorts","puffs out some air")
	emote_hear = list("snorts")
	emote_see = list("snorts", "puffs out some air")
	speak_chance = TRUE
	turns_per_move = 4
	see_in_dark = 8
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/meat
	meat_amount = 3
	response_help  = "rubs"
	response_disarm = "gently pushes aside"
	response_harm   = "kicks"
	attacktext = "kicked"
	health = 40
	mob_size = MOB_MEDIUM
	granivore = 1
	carnivore = 1
	behaviour = "defends"
	melee_damage_lower = 8
	melee_damage_upper = 15

/mob/living/simple_animal/boar/female
	name = "boar"
	desc = "A female boar."
	icon_state = "boar_female"
	icon_living = "boar_female_dead"
	icon_dead = "boar_female_dead"
	icon_gib = "boar_female_dead"
	mob_size = MOB_MEDIUM

/mob/living/simple_animal/boar/Life()
	..()
	if (stat != DEAD)
		var/done = FALSE
		for (var/mob/living/carbon/human/H in range(7, src))
			if (done == FALSE)
				var/dirh = get_dir(src,H)
				if (dirh == WEST)
					walk_to(src, locate(x+7,y,z), TRUE, 3)
				else if (dirh == EAST)
					walk_to(src, locate(x-7,y,z), TRUE, 3)
				else if (dirh == NORTH)
					walk_to(src, locate(x,y-7,z), TRUE, 3)
				else if (dirh == SOUTH)
					walk_to(src, locate(x,y+7,z), TRUE, 3)
				done = TRUE