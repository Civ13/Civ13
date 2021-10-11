/mob/living/simple_animal/hostile/mammoth
	name = "mammoth"
	desc = "This thing is huge!"
	icon = 'icons/mob/animal_192.dmi'
	icon_state = "mammoth"
	icon_living = "mammoth"
	icon_dead = "mammoth_dead"
	speak_emote = list("trumpets")
	health = 1200
	maxHealth = 1200
	move_to_delay = 12
	move_to_delay = 10
	attacktext = "stomps"
	melee_damage_lower = 35
	melee_damage_upper = 45
	response_help  = "pets"
	response_disarm = "punches"
	response_harm   = "kicks"
	faction = "hostile"
	density = TRUE
	mob_size = MOB_HUGE
	fat_extra = 20

	stop_automated_movement_when_pulled = FALSE
	wander = FALSE
	dir = WEST
	bound_x = 64
	bound_height = 96
	bound_width = 96
	herbivore = 1
	granivore = 1
	behaviour = "defends"

/mob/living/simple_animal/hostile/mammoth/update_icons()
	..()
	if (dir == SOUTH || dir == EAST)
		bound_x = 0
	else
		bound_x = 64

/mob/living/simple_animal/hostile/mammoth/AttackingTarget()
	var/damage = pick(melee_damage_lower, melee_damage_upper)
	if (!Adjacent(target_mob))
		return
	custom_emote(1, pick("bites [target_mob]!","stomps on [target_mob]!", "kicks [target_mob]!"))
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