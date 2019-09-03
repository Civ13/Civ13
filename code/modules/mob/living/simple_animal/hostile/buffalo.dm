
/mob/living/simple_animal/hostile/buffalo
	name = "buffalo"
	desc =  "A Large member of the Bovine Family, They are grazers and will be hostile if harmed."
	icon = 'icons/mob/animal_64.dmi'
	icon_state = "buffalo"
	icon_living = "buffalo"
	icon_dead = "buffalo_dead"
	speak_emote = list("Gnnnnnrrrr", "Moooooo", "Pnhhhh")
	emote_hear = list("Grunts", "Puffs")
	health = 350
	maxHealth = 350
	move_to_delay = 7
	turns_per_move = 6
	attacktext = "charges into"
	melee_damage_lower = 35
	melee_damage_upper = 50
	response_help  = "pets"
	response_disarm = "shoos"
	response_harm   = "punches"
	faction = list("neutral")
	mob_size = MOB_LARGE
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/meat
	var/stance_step = FALSE

/mob/living/simple_animal/hostile/buffalo/FindTarget()
	var/atom/T = null
	stop_automated_movement = FALSE
	for (var/atom/A in ListTargets(7))

		if (A == src)
			continue

		var/atom/F = Found(A)
		if (F)
			T = F
			break

		if (isliving(A))
			var/mob/living/L = A
			if (istype(L, /mob/living/simple_animal/mouse))
				var/mob/living/simple_animal/mouse/RH = L
				if (!RH.stat)
					stance = HOSTILE_STANCE_ALERT
					T = RH
	return T


/mob/living/simple_animal/hostile/buffalo/Life()
	. =..()
	if (!.)
		return

	icon_state = "buffalo"

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
						var/action = pick( list( "stares at [target_mob].", "closely watches [target_mob]." ) )
						if (action)
							custom_emote(1,action)
			if (!found_mob)
				stance_step--

			if (stance_step <= -20) //If we have not found a mob for 20-ish ticks, revert to idle mode
				stance = HOSTILE_STANCE_IDLE
			if (stance_step >= 7)   //If we have been staring at a mob for 7 ticks,
				stance = HOSTILE_STANCE_ATTACK

		if (HOSTILE_STANCE_ATTACKING)
			if (stance_step >= 20)	//attacks for 20 ticks, then it gets tired and needs to rest
				custom_emote(1, "is worn out and needs to rest." )
				stance = HOSTILE_STANCE_TIRED
				stance_step = FALSE
				walk(src, FALSE) //This stops the bear's walking
				return



/mob/living/simple_animal/hostile/buffalo/attackby(var/obj/item/O as obj, var/mob/user as mob)
	if (stance != HOSTILE_STANCE_ATTACK && stance != HOSTILE_STANCE_ATTACKING)
		stance = HOSTILE_STANCE_ATTACK
		stance_step = 0
		target_mob = user
	..()
/mob/living/simple_animal/hostile/buffalo/attack_hand(mob/living/M as mob)
	if (stance != HOSTILE_STANCE_ATTACK && stance != HOSTILE_STANCE_ATTACKING)
		stance = HOSTILE_STANCE_ATTACK
		stance_step = 0
		target_mob = M
	..()
/mob/living/simple_animal/hostile/buffalo/FindTarget()
	. = ..()
	if (.)
		custom_emote(1,"stares alertly at [.].")
		stance = HOSTILE_STANCE_ALERT

/mob/living/simple_animal/hostile/buffalo/LoseTarget()
	..(5)

/mob/living/simple_animal/hostile/buffalo/AttackingTarget()
	var/damage = pick(melee_damage_lower, melee_damage_upper)
	if (!Adjacent(target_mob))
		return
	else
		custom_emote(1, "tackles [target_mob]!")
		if (ishuman(target_mob))
			var/mob/living/carbon/human/H = target_mob
			var/dam_zone = pick("l_leg", "r_leg")
			var/obj/item/organ/external/affecting = H.get_organ(ran_zone(dam_zone))
			H.apply_damage(40, BRUTE, affecting, H.run_armor_check(affecting, "melee"), sharp=1, edge=1)
		else if (isliving(target_mob))
			var/mob/living/L = target_mob
			L.adjustBruteLoss(damage)
			return L
