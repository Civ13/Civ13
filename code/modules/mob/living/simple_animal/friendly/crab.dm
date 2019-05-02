//Look Sir, free crabs!
/mob/living/simple_animal/crab
	name = "crab"
	desc = "A hard-shelled crustacean. Seems quite content to lounge around all the time."
	icon_state = "crab"
	icon_living = "crab"
	icon_dead = "crab_dead"
	mob_size = MOB_SMALL
	speak_emote = list("clicks")
	emote_hear = list("clicks")
	emote_see = list("clacks")
	speak_chance = TRUE
	turns_per_move = 5
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/meat
	response_help  = "pets"
	response_disarm = "gently pushes aside"
	response_harm   = "stomps"
	stop_automated_movement = TRUE
	friendly = "pinches"
	mob_size = 5
	var/obj/item/inventory_head
	var/obj/item/inventory_mask
	possession_candidate = TRUE
	mob_size = MOB_SMALL

/mob/living/simple_animal/crab/small
	name = "small crab"
	desc = "A hard-shelled crustacean. it seems to look around for food trying to become a big boy."
	icon_state = "red_crab"
	icon_living = "red_crab"
	icon_dead = "red_crab_dead"
	mob_size = MOB_MINISCULE
	maxHealth = 10
	health = 10

/mob/living/simple_animal/crab/Life()
	..()
	//CRAB movement
	if (!ckey && !stat)
		if (isturf(loc) && !resting && !buckled)		//This is so it only moves if it's not inside a closet, gentics machine, etc.
			turns_since_move++
			if (turns_since_move >= turns_per_move)
				Move(get_step(src,pick(4,8)))
				turns_since_move = FALSE
	regenerate_icons()
