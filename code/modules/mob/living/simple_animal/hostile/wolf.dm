
/mob/living/simple_animal/hostile/wolf
	name = "grey wolf"
	desc = "Better start running..."
	icon_state = "greywolf"
	icon_living = "greywolf"
	icon_dead = "greywolf_dead"
	icon_gib = "greywolf_gib"
	speak = list("GRRR!","Wooh!","Wuuh!","HUUUUU!")
	speak_emote = list("growls", "howls")
	emote_hear = list("growls","howls","whimps")
	emote_see = list("stares ferociously", "sniffs the ground")
	speak_chance = TRUE
	turns_per_move = 4
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
	predatory_carnivore = 1
	carnivore = 1


	var/btype = "grey"
	var/cub = FALSE
	var/female = FALSE
	faction = "neutral"
	var/pregnant = FALSE
	var/birthCountdown = 0
	var/overpopulationCountdown = 0

/mob/living/simple_animal/hostile/wolf/female
	name = "female wolf"
	female = TRUE

/mob/living/simple_animal/hostile/wolf/death()
	if (!removed_from_list)
		removed_from_list=TRUE
		wolf_count -= 1
	..()
/mob/living/simple_animal/hostile/wolf/Destroy()
	if (!removed_from_list)
		removed_from_list=TRUE
		wolf_count -= 1
	..()
/mob/living/simple_animal/hostile/wolf/New()
	wolf_count += 1
	..()
	spawn(1)
		if (cub)
			icon_state = "[btype]wolf_cub"
			icon_living = "[btype]wolf_cub"
			icon_dead = "[btype]wolf_cub_dead"
			meat_amount = 1
			mob_size = MOB_SMALL
			if (female)
				name = "female [btype] wolf cub"
			else
				name = "male [btype] wolf cub"
			spawn(3000)
				cub = FALSE
				icon_state = "[btype]wolf"
				icon_living = "[btype]wolf"
				icon_dead = "[btype]wolf_dead"
				mob_size = MOB_MEDIUM
				if (female)
					name = "female [btype] wolf"
				else
					name = "male [btype] wolf"
		else
			if (female)
				name = "female [btype] wolf"
			else
				name = "male [btype] wolf"

/mob/living/simple_animal/hostile/wolf/Life()
	. =..()
	if (!.)
		return
	if (overpopulationCountdown > 0) //don't do any checks while overpopulation is in effect
		overpopulationCountdown--
		return

	if (!pregnant && wolf_count < 12)
		var/nearbyObjects = range(1,src) //3x3 area around animal
		for(var/mob/living/simple_animal/hostile/wolf/M in nearbyObjects)
			if (M.stat == CONSCIOUS && !M.female)
				pregnant = TRUE
				birthCountdown = 600 // life ticks once per 2 seconds, 300 == 10 minutes
				break

		if (pregnant)
			nearbyObjects = range(7,src) //15x15 area around animal

			var/wolfCount = 0
			for(var/mob/living/simple_animal/hostile/wolf/M in nearbyObjects)
				if (M.stat == CONSCIOUS)
					wolfCount++


			if (wolfCount > 4) // max 5 in a 15x15 area around
				overpopulationCountdown = 300 // 5 minutes
				pregnant = FALSE
	else if (pregnant)
		birthCountdown--
		if (birthCountdown <= 0)
			pregnant = FALSE
			if (prob(50))
				var/mob/living/simple_animal/hostile/wolf/C = new/mob/living/simple_animal/hostile/wolf(loc)
				C.cub = TRUE
				C.btype = btype
			else
				var/mob/living/simple_animal/hostile/wolf/female/B = new/mob/living/simple_animal/hostile/wolf/female(loc)
				B.cub = TRUE
				B.btype = btype
			visible_message("A wolf cub has been born!")
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
								playsound(src.loc, 'sound/animals/wolf/wolfgrowl.ogg', 150, TRUE, 2)
							else
								playsound(src.loc, 'sound/animals/wolf/wolfbark.ogg', 150, TRUE, 2)
			if (!found_mob)
				stance_step--

			if (stance_step <= -20) //If we have not found a mob for 20-ish ticks, revert to idle mode
				stance = HOSTILE_STANCE_IDLE
			if (stance_step >= 3)   //If we have been staring at a mob for 7 ticks,
				stance = HOSTILE_STANCE_ATTACK
				if (prob(50))
					playsound(src.loc, 'sound/animals/wolf/wolfsnarl.ogg', 150, TRUE, 2)
				else
					playsound(src.loc, 'sound/animals/wolf/wolfsnarl2.ogg', 150, TRUE, 2)

		if (HOSTILE_STANCE_ATTACKING)
			if (stance_step >= 20)	//attacks for 20 ticks, then it gets tired and needs to rest
				custom_emote(1, "is worn out and needs to rest." )
				stance = HOSTILE_STANCE_TIRED
				stance_step = FALSE
				walk(src, FALSE) //This stops the wolf's walking
				return

/mob/living/simple_animal/hostile/wolf/AttackingTarget()
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

/mob/living/simple_animal/hostile/wolf/white
	name = "white wolf"
	icon_state = "whitewolf"
	icon_living = "whitewolf"
	icon_dead = "whitewolf_dead"
	icon_gib = "whitewolf_gib"
	btype = "white"
