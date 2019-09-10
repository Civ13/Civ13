
/mob/living/simple_animal/hostile/bear
	name = "black bear boar"
	desc = "Rawr Rawr!!"
	icon_state = "blackbear"
	icon_living = "blackbear"
	icon_dead = "blackbear_dead"
	icon_gib = "blackbear_gib"
	speak = list("RAWR!","Rawr!","GRR!","Growl!")
	speak_emote = list("growls", "roars")
	emote_hear = list("rawrs","grumbles","grawls")
	emote_see = list("stares ferociously", "stomps")
	speak_chance = TRUE
	turns_per_move = 5
	move_to_delay = 5
	see_in_dark = 6
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/bearmeat
	response_help  = "pets"
	response_disarm = "gently pushes aside"
	response_harm   = "pokes"
	stop_automated_movement_when_pulled = FALSE
	maxHealth = 60
	health = 60
	melee_damage_lower = 20
	melee_damage_upper = 30
	mob_size = MOB_LARGE
	predatory_carnivore = 1
	carnivore = 1
	scavenger = 1

	var/cub = FALSE
	var/stance_step = FALSE
	var/btype = "black"
	var/female = FALSE
	faction = "neutral"
	var/pregnant = FALSE
	var/birthCountdown = 0
	var/overpopulationCountdown = 0

/mob/living/simple_animal/hostile/bear/female
	name = "black bear sow"
	female = TRUE

/mob/living/simple_animal/hostile/bear/Destroy()
	..()
	bear_count -= 1

/mob/living/simple_animal/hostile/bear/Life()
	. =..()
	if (!.)
		return

	if (overpopulationCountdown > 0) //don't do any checks while overpopulation is in effect
		overpopulationCountdown--
		return

	if (!pregnant && bear_count < 8)
		var/nearbyObjects = range(1,src) //3x3 area around animal
		for(var/mob/living/simple_animal/hostile/bear/M in nearbyObjects)
			if (M.stat == CONSCIOUS && !M.female)
				pregnant = TRUE
				birthCountdown = 600 // life ticks once per 2 seconds, 300 == 10 minutes
				break

		if (pregnant)
			nearbyObjects = range(7,src) //15x15 area around animal

			var/bearCount = 0
			for(var/mob/living/simple_animal/hostile/bear/M in nearbyObjects)
				if (M.stat == CONSCIOUS)
					bearCount++


			if (bearCount > 4) // max 5 cows/bulls in a 15x15 area around
				overpopulationCountdown = 300 // 5 minutes
				pregnant = FALSE
	else if (pregnant)
		birthCountdown--
		if (birthCountdown <= 0)
			pregnant = FALSE
			if (prob(50))
				var/mob/living/simple_animal/hostile/bear/C = new/mob/living/simple_animal/hostile/bear(loc)
				C.cub = TRUE
				C.btype = btype
			else
				var/mob/living/simple_animal/hostile/bear/female/B = new/mob/living/simple_animal/hostile/bear/female(loc)
				B.cub = TRUE
				B.btype = btype
			visible_message("A bear cub has been born!")
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
							playsound(src.loc, 'sound/animals/bear/beargrowl.ogg', 150, TRUE, 2)
			if (!found_mob)
				stance_step--

			if (stance_step <= -20) //If we have not found a mob for 20-ish ticks, revert to idle mode
				stance = HOSTILE_STANCE_IDLE
			if (stance_step >= 4)   //If we have been staring at a mob for 7 ticks,
				stance = HOSTILE_STANCE_ATTACK

		if (HOSTILE_STANCE_ATTACKING)
			if (stance_step >= 20)	//attacks for 20 ticks, then it gets tired and needs to rest
				custom_emote(1, "is worn out and needs to rest." )
				stance = HOSTILE_STANCE_TIRED
				stance_step = FALSE
				walk(src, FALSE) //This stops the bear's walking
				return

/mob/living/simple_animal/hostile/bear/attackby(var/obj/item/O as obj, var/mob/user as mob)
	if (stance != HOSTILE_STANCE_ATTACK && stance != HOSTILE_STANCE_ATTACKING)
		stance = HOSTILE_STANCE_ALERT
		stance_step = 6
		target_mob = user
	..()

/mob/living/simple_animal/hostile/bear/attack_hand(mob/living/carbon/human/M as mob)
	if (stance != HOSTILE_STANCE_ATTACK && stance != HOSTILE_STANCE_ATTACKING)
		stance = HOSTILE_STANCE_ALERT
		stance_step = 6
		target_mob = M
	..()

/mob/living/simple_animal/hostile/bear/FindTarget()
	. = ..()
	if (.)
		custom_emote(1,"stares alertly at [.].")
		stance = HOSTILE_STANCE_ALERT

/mob/living/simple_animal/hostile/bear/LoseTarget()
	..(5)

/mob/living/simple_animal/hostile/bear/AttackingTarget()
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
	//else if (istype(target_mob,/obj/mecha))
		//var/obj/mecha/M = target_mob
		//M.attack_animal(src)
		//return M

/mob/living/simple_animal/hostile/bear/New()
	bear_count += 1
	..()
	spawn(1)
		if (cub)
			icon_state = "[btype]bear_cub"
			icon_living = "[btype]bear_cub"
			icon_dead = "[btype]bear_cub_dead"
			meat_amount = 1
			mob_size = MOB_MEDIUM
			if (female)
				name = "female [btype] bear cub"
			else
				name = "male [btype] bear cub"
			spawn(3000)
				cub = FALSE
				icon_state = "[btype]bear"
				icon_living = "[btype]bear"
				icon_dead = "[btype]bear_dead"
				mob_size = MOB_LARGE
				if (female)
					name = "[btype] bear sow"
				else
					name = "[btype] bear boar"
		else
			if (female)
				name = "[btype] bear sow"
			else
				name = "[btype] bear boar"
			icon_state = "[btype]bear"

/mob/living/simple_animal/hostile/bear/brown
	name = "brown bear"
	icon_state = "brownbear"
	icon_living = "brownbear"
	icon_dead = "brownbear_dead"
	icon_gib = "brownbear_gib"
	btype = "brown"

/mob/living/simple_animal/hostile/bear/polar
	name = "polar bear"
	icon_state = "polarbear"
	icon_living = "polarbear"
	icon_dead = "polarbear_dead"
	icon_gib = "polarbear_gib"
	btype = "polar"