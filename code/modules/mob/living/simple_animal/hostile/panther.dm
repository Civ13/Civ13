
/mob/living/simple_animal/hostile/panther
	name = "panther"
	desc = "Better start running..."
	icon = 'icons/mob/animal_big.dmi'
	icon_state = "panther"
	icon_living = "panther"
	icon_dead = "panther_dead"
	icon_gib = "panther_gib"
	speak = list("GRRR!","rawrr","RAWR!","RRRRR!")
	speak_emote = list("growls", "roars")
	emote_hear = list("growls","roars","buffs")
	emote_see = list("stares ferociously", "sniffs the ground")
	speak_chance = TRUE
	turns_per_move = 5
	move_to_delay = 3
	see_in_dark = 6
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/meat
	response_help  = "pets"
	response_disarm = "gently pushes aside"
	response_harm   = "pokes"
	stop_automated_movement_when_pulled = FALSE
	maxHealth = 45
	health = 45
	melee_damage_lower = 12
	melee_damage_upper = 23
	mob_size = MOB_MEDIUM

	var/stance_step = FALSE

	faction = "neutral"

/mob/living/simple_animal/hostile/panther/jaguar
	name = "jaguar"
	icon_state = "jaguar"
	icon_living = "jaguar"
	icon_dead = "jaguar_dead"
	icon_gib = "jaguar_gib"

/mob/living/simple_animal/hostile/panther/Life()
	. =..()
	if (!.)
		return


	switch(stance)

		if (HOSTILE_STANCE_TIRED)
			stop_automated_movement = TRUE
			stance_step++
			if (stance_step >= 10) //rests for 10 ticks
				if (target_mob && target_mob in ListTargets(7))
					stance = HOSTILE_STANCE_ATTACK //If the mob he was chasing is still nearby, resume the attack, otherwise go idle.
				else
					stance = HOSTILE_STANCE_IDLE

		if (HOSTILE_STANCE_ALERT)
			stop_automated_movement = TRUE
			var/found_mob = FALSE
			if (target_mob && target_mob in ListTargets(7))
				if (!(SA_attackable(target_mob)))
					stance_step = max(0, stance_step) //If we have not seen a mob in a while, the stance_step will be negative, we need to reset it to FALSE as soon as we see a mob again.
					stance_step++
					found_mob = TRUE
					set_dir(get_dir(src,target_mob))	//Keep staring at the mob

					if (stance_step in list(1,4,7)) //every 3 ticks
						var/action = pick( list( "growls at [target_mob].", "stares angrily at [target_mob].", "prepares to attack [target_mob].", "closely watches [target_mob]." ) )
						if (action)
							custom_emote(1,action)
							if (prob(50))
								playsound(src.loc, 'sound/animals/panther/panthergrowl1.ogg', 150, TRUE, 2)
							else
								playsound(src.loc, 'sound/animals/panther/panthergrowl2.ogg', 150, TRUE, 2)
			if (!found_mob)
				stance_step--

			if (stance_step <= -20) //If we have not found a mob for 20-ish ticks, revert to idle mode
				stance = HOSTILE_STANCE_IDLE
			if (stance_step >= 3)   //If we have been staring at a mob for 7 ticks,
				stance = HOSTILE_STANCE_ATTACK
				playsound(src.loc, 'sound/animals/panther/pantherroar.ogg', 150, TRUE, 2)

		if (HOSTILE_STANCE_ATTACKING)
			if (stance_step >= 20)	//attacks for 20 ticks, then it gets tired and needs to rest
				custom_emote(1, "is worn out and needs to rest." )
				stance = HOSTILE_STANCE_TIRED
				stance_step = FALSE
				walk(src, FALSE) //This stops the bear's walking
				return



/mob/living/simple_animal/hostile/panther/attackby(var/obj/item/O as obj, var/mob/user as mob)
	if (stance != HOSTILE_STANCE_ATTACK && stance != HOSTILE_STANCE_ATTACKING)
		stance = HOSTILE_STANCE_ALERT
		stance_step = 6
		target_mob = user
	..()

/mob/living/simple_animal/hostile/panther/attack_hand(mob/living/carbon/human/M as mob)
	if (stance != HOSTILE_STANCE_ATTACK && stance != HOSTILE_STANCE_ATTACKING)
		stance = HOSTILE_STANCE_ALERT
		stance_step = 6
		target_mob = M
	..()

/mob/living/simple_animal/hostile/panther/FindTarget()
	. = ..()
	if (.)
		custom_emote(1,"stares alertly at [.].")
		stance = HOSTILE_STANCE_ALERT

/mob/living/simple_animal/hostile/panther/LoseTarget()
	..(5)

/mob/living/simple_animal/hostile/panther/AttackingTarget()
	if (!Adjacent(target_mob))
		return
	if(prob(50))
		playsound(src.loc, 'sound/weapons/bite.ogg', 100, TRUE, 2)
	else
		playsound(src.loc, 'sound/weapons/bite_2.ogg', 100, TRUE, 2)
	custom_emote(1, pick( list("slashes at [target_mob]!", "bites [target_mob]!") ) )

	var/damage = pick(melee_damage_lower,melee_damage_upper)

	if (ishuman(target_mob))
		var/mob/living/carbon/human/H = target_mob
		var/dam_zone = pick("chest", "l_hand", "r_hand", "l_leg", "r_leg")
		var/obj/item/organ/external/affecting = H.get_organ(ran_zone(dam_zone))
		H.apply_damage(damage, BRUTE, affecting, H.run_armor_check(affecting, "melee"), sharp=1, edge=1)
		return H
	else if (isliving(target_mob))
		var/mob/living/L = target_mob
		L.adjustBruteLoss(damage)
		return L