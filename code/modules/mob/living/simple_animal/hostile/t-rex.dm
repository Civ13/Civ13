/mob/living/simple_animal/hostile/trex
	name = "tyrannosaurus rex"
	desc = "A gargantuan carnivorous dinosaur of spine chillingly terrible majesty. The monarch of the prehistoric world"
	icon = 'icons/mob/animal_128.dmi'
	icon_state = "rex"
	icon_living = "rex"
	icon_dead = "rex_dead"
	speak = list("GRRRHRMM!","ROOOOOOOAR!")
	speak_emote = list("roars")
	emote_hear = list("GRRRRHMM")
	emote_see = list("stares with murderous intent", "sniffs the air")
	speak_chance = TRUE
	health = 1200
	maxHealth = 1200
	move_to_delay = 12
	move_to_delay = 10
	attacktext = "chomps"
	melee_damage_lower = 50
	melee_damage_upper = 55
	response_help  = "nudges"
	response_disarm = "overpowers"
	response_harm   = "rams"
	faction = "hostile"
	density = TRUE
	mob_size = MOB_HUGE
	can_bite_limbs_off = TRUE
	stop_automated_movement_when_pulled = FALSE
	wander = FALSE
	dir = WEST
	bound_x = 64
	bound_height = 96
	bound_width = 96
	predatory_carnivore = 1
	carnivore = 1
	break_stuff_probability = 45 //smashes and thrashes around relentlessly.

/mob/living/simple_animal/hostile/trex/update_icons()
	..()
	if (dir == SOUTH || dir == EAST)
		bound_x = 0
	else
		bound_x = 64

/mob/living/simple_animal/hostile/trex/AttackingTarget()
	var/damage = pick(melee_damage_lower, melee_damage_upper)
	if (!Adjacent(target_mob))
		return
	custom_emote(1, pick("bites [target_mob]!","stomps on [target_mob]!"))
	if (ishuman(target_mob))
		var/mob/living/human/H = target_mob
		var/dam_zone = pick("l_hand", "r_hand", "l_leg", "r_leg")
		var/obj/item/organ/external/affecting = H.get_organ(ran_zone(dam_zone))
		if (prob(88))
			H.apply_damage(damage, BRUTE, affecting, H.run_armor_check(affecting, "melee"), sharp=1, edge=1)
		else
			visible_message("\The [src] crushes [H]!")
			spawn(5)
				H.crush()
		return H
	else if (isliving(target_mob))
		var/mob/living/L = target_mob
		L.adjustBruteLoss(damage)
		if (istype(target_mob, /mob/living/simple_animal))
			var/mob/living/simple_animal/SA = target_mob
			if (SA.behaviour == "defends" || SA.behaviour == "hunt")
				if (SA.stance != HOSTILE_STANCE_ATTACK)
					SA.stance = HOSTILE_STANCE_ATTACK
					SA.stance_step = 7
					SA.target_mob = src
		return L