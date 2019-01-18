/mob/living/simple_animal/penguin
	name = "penguin"
	desc = "A black and white flightless bird."
	icon_state = "penguin"
	icon_living = "penguin"
	icon_dead = "penguin_dead"
	icon_gib = "penguin_dead"
	speak = list("HONK!","pip pip!","honk!")
	speak_emote = list("honks","peeps")
	emote_hear = list("honks")
	emote_see = list("honks", "peeps")
	speak_chance = TRUE
	turns_per_move = 4
	see_in_dark = 8
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/meat
	meat_amount = 2
	response_help  = "pets"
	response_disarm = "gently pushes aside"
	response_harm   = "kicks"
	attacktext = "kicked"
	health = 25
	mob_size = MOB_SMALL


/mob/living/simple_animal/penguin/Life()
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