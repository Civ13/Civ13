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

/mob/living/simple_animal/horse/New()
	..()
	var/pickcolor = pick("horse", "horse2", "horse3", "horse4")
	icon_state = pickcolor
	icon_living = pickcolor
	icon_dead = "[pickcolor]_dead"