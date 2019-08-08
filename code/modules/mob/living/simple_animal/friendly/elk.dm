/mob/living/simple_animal/elk/male
	name = "elk stag"
	desc = "Provides some nice meat, if you can catch it."
	icon_state = "elk_m"
	icon_living = "elk_m"
	icon_dead = "elk_m_dead"
	icon_gib = "elk_m_dead"
	speak = list("Qeeeeeeeel","Ei'Il")
	speak_emote = list("bellows","bleats")
	emote_hear = list("bellows")
	emote_see = list("shakes its head", "looks attently")
	speak_chance = TRUE
	turns_per_move = 2
	see_in_dark = 8
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/meat
	meat_amount = 6
	response_help  = "pets"
	response_disarm = "gently pushes aside"
	response_harm   = "kicks"
	attacktext = "kicked"
	health = 80
	mob_size = MOB_LARGE
/mob/living/simple_animal/elk/female
	name = "elk doe"
	icon_state = "elk_f"
	icon_living = "elk_f"
	icon_dead = "elk_f_dead"
	icon_gib = "elk_f_dead"
	mob_size = MOB_LARGE
	herbivore = 1

/mob/living/simple_animal/elk/Life()
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
