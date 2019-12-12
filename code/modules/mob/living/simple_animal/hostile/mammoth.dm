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
	faction = list("hostile")
	density = TRUE
	mob_size = MOB_HUGE

	stop_automated_movement_when_pulled = FALSE
	wander = FALSE
	dir = WEST
	bound_x = 64
	bound_height = 96
	bound_width = 96
	herbivore = 1
	granivore = 1

/mob/living/simple_animal/hostile/mammoth/update_icons()
	..()
	if (dir == SOUTH || dir == EAST)
		bound_x = 0
	else
		bound_x = 64
/mob/living/simple_animal/hostile/mammoth/Life()
	. =..()
	if (!.)
		return

	icon_state = "mammoth"

	switch(stance)

		if (HOSTILE_STANCE_TIRED)
			stop_automated_movement = TRUE
			stance_step++
			if (stance_step >= 10) //rests for 10 ticks
				if (target_mob && target_mob in ListTargets(12))
					stance = HOSTILE_STANCE_ATTACK //If the mob he was chasing is still nearby, resume the attack, otherwise go idle.
				else
					stance = HOSTILE_STANCE_IDLE

		if (HOSTILE_STANCE_ALERT)
			stop_automated_movement = TRUE
			var/found_mob = FALSE
			if (target_mob && target_mob in ListTargets(12))
				if (!(SA_attackable(target_mob)))
					stance_step = max(0, stance_step) //If we have not seen a mob in a while, the stance_step will be negative, we need to reset it to FALSE as soon as we see a mob again.
					stance_step++
					found_mob = TRUE
					set_dir(get_dir(src,target_mob))	//Keep staring at the mob

					if (stance_step in list(1,4,7)) //every 3 ticks
						var/action = pick( list( "trumpets at [target_mob].", "prepares to charge [target_mob]." ) )
						if (action)
							custom_emote(1,action)
			if (!found_mob)
				stance_step--

			if (stance_step <= -20) //If we have not found a mob for 20-ish ticks, revert to idle mode
				stance = HOSTILE_STANCE_IDLE
			if (stance_step >= 7)   //If we have been staring at a mob for 7 ticks,
				stance = HOSTILE_STANCE_ATTACK

		if (HOSTILE_STANCE_ATTACKING)
			if (stance_step >= 40)	//attacks for 40 ticks, then it gets tired and needs to rest
				custom_emote(1, "is worn out and needs to rest." )
				stance = HOSTILE_STANCE_TIRED
				stance_step = FALSE
				walk(src, FALSE) //This stops the bear's walking
				return

/mob/living/simple_animal/hostile/mammoth/AttackingTarget()
	var/damage = pick(melee_damage_lower, melee_damage_upper)
	if (!Adjacent(target_mob))
		return
	custom_emote(1, pick("bites [target_mob]!","stomps on [target_mob]!", "kicks [target_mob]!"))
	if (ishuman(target_mob))
		var/mob/living/carbon/human/H = target_mob
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
		return L