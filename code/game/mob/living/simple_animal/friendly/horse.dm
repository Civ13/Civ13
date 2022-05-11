/mob/living/simple_animal/horse
	name = "horse"
	desc = "A friendly horse. Seems to be tamed."
	icon = 'icons/mob/animal_64.dmi'
	icon_state = "horse"
	icon_living = "horse"
	icon_dead = "horse_dead"
	speak = list("iiiiiiiih","BRHBRH","IIIIIIIIIIIIIIHHH")
	speak_emote = list("neighs")
	emote_hear = list("neighs")
	emote_see = list("shakes its head")
	speak_chance = TRUE
	move_to_delay = 3.2
	see_in_dark = 6
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/meat
	meat_amount = 4
	response_help  = "pets"
	response_disarm = "gently pushes aside"
	response_harm   = "kicks"
	attacktext = "kicked"
	health = 1800
	mob_size = MOB_LARGE
	layer = 3.99
	a_intent = I_HARM
	can_ride = TRUE

/mob/living/simple_animal/horse/black
	icon_state = "horse2"
	icon_living = "horse2"
	icon_dead = "horse2_dead"
	layer = 3.99

/mob/living/simple_animal/horse/beige
	icon_state = "horse3"
	icon_living = "horse3"
	icon_dead = "horse3_dead"
	layer = 3.99

/mob/living/simple_animal/horse/white
	icon_state = "horse4"
	icon_living = "horse4"
	icon_dead = "horse4_dead"
	layer = 3.99