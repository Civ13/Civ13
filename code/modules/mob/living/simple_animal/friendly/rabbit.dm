/mob/living/simple_animal/rabbit
	name = "rabbit"
	real_name = "rabbit"
	desc = "A small rabbit. Cute."
	icon_state = "rabbitgrey"
	item_state = "rabbitgrey"
	icon_living = "rabbitgrey"
	icon_dead = "rabbitgrey_dead"
	speak = list("Squeek!","SQUEEK!","Squeek?")
	speak_emote = list("squeeks","squeeks","squiks")
	emote_hear = list("squeeks","squeaks","squiks")
	emote_see = list("runs in a circle", "jumps", "sniffs the ground")
	pass_flags = PASSTABLE
	speak_chance = TRUE
	turns_per_move = 4
	see_in_dark = 6
	maxHealth = 12
	health = 12
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/meat
	response_help  = "pets"
	response_disarm = "gently pushes aside"
	response_harm   = "stamps on"
	density = FALSE
	var/body_color //brown, gray and white, leave blank for random
	layer = MOB_LAYER
	universal_speak = FALSE
	universal_understand = TRUE
	mob_size = MOB_SMALL
	granivore = 1

/mob/living/simple_animal/rabbit/New()
	..()

	if (!body_color)
		body_color = pick( list("black","grey","white") )
	icon_state = "rabbit[body_color]"
	item_state = "rabbit[body_color]"
	icon_living = "rabbit[body_color]"
	icon_dead = "rabbit[body_color]_dead"


/mob/living/simple_animal/rabbit/death()
	layer = MOB_LAYER
	..()
