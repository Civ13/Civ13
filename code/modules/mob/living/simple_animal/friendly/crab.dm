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
	move_to_delay = 5
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
			if (turns_since_move >= move_to_delay)
				Move(get_step(src,pick(4,8)))
				turns_since_move = FALSE
	regenerate_icons()

/mob/living/simple_animal/crab/small/crab_san
	name = "crab-san"
	desc = "A hard-shelled crustacean soldier. it seems to look around for enemies to kill, being a soldier of the imperial army and all."
	icon_state = "crab_san"
	icon_living = "crab_san"
	icon_dead = "crab_san_dead"
	mob_size = MOB_MINISCULE
	maxHealth = 40
	health = 40

/mob/living/simple_animal/crab/small/trilobite
	name = "trilobite"
	desc = "A hard-shelled artiopodan. it seems to be scavanging for food."
	icon_state = "trilobite_living"
	icon_living = "trilobite_living"
	icon_dead = "trilobite_dead"
	mob_size = MOB_MINISCULE
	maxHealth = 50
	health = 50

/mob/living/simple_animal/crab/small/dead
	New()
		..()
		death()