
/mob/living/simple_animal/hostile/dinosaur/velociraptor
	name = "velociraptor"
	desc = "Yep. You are fucked."
	icon = 'icons/mob/animal_big.dmi'
	icon_state = "velociraptor"
	icon_living = "velociraptor"
	icon_dead = "velociraptor_dead"
	icon_gib = "velociraptor_dead"
	speak = list("hisss","kkk!","krrrr")
	speak_emote = list("bellow", "hiss")
	emote_hear = list("bellows","hisses")
	emote_see = list("stares ferociously", "grunts")
	speak_chance = TRUE
	turns_per_move = 3
	move_to_delay = 3
	see_in_dark = 6
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/meat
	response_help  = "pets"
	response_disarm = "gently pushes aside"
	response_harm   = "pokes"
	stop_automated_movement_when_pulled = FALSE
	maxHealth = 140
	health = 140
	melee_damage_lower = 35
	melee_damage_upper = 40
	mob_size = MOB_LARGE

	var/stance_step = FALSE

	faction = "neutral"

/mob/living/simple_animal/hostile/dinosaur/velociraptor/Life()
	. =..()
	if (!.)
		return

	icon_state = "velociraptor"

	switch(stance)

		if (HOSTILE_STANCE_TIRED)
			stop_automated_movement = TRUE
			stance_step++
			if (stance_step >= 5) //rests for 5 ticks
				if (target_mob && target_mob in ListTargets(6))
					stance = HOSTILE_STANCE_ATTACK //If the mob he was chasing is still nearby, resume the attack, otherwise go idle.
				else
					stance = HOSTILE_STANCE_IDLE

		if (HOSTILE_STANCE_ALERT)
			stop_automated_movement = TRUE
			var/found_mob = FALSE
			if (target_mob && target_mob in ListTargets(6))
				if (!(SA_attackable(target_mob)))
					stance_step = max(0, stance_step) //If we have not seen a mob in a while, the stance_step will be negative, we need to reset it to FALSE as soon as we see a mob again.
					stance_step++
					found_mob = TRUE
					set_dir(get_dir(src,target_mob))	//Keep staring at the mob

					if (stance_step in list(1,4,7)) //every 3 ticks
						var/action = pick( list( "hisses at [target_mob].", "stares angrily at [target_mob].", "prepares to attack [target_mob].", "closely watches [target_mob]." ) )
						if (action)
							custom_emote(1,action)
			if (!found_mob)
				stance_step--

			if (stance_step <= -35) //If we have not found a mob for 35-ish ticks, revert to idle mode
				stance = HOSTILE_STANCE_IDLE
			if (stance_step >= 3)   //If we have been staring at a mob for 4 ticks,
				stance = HOSTILE_STANCE_ATTACK

		if (HOSTILE_STANCE_ATTACKING)
			if (stance_step >= 30)	//attacks for 30 ticks, then it gets tired and needs to rest
				custom_emote(1, "is worn out and needs to rest." )
				stance = HOSTILE_STANCE_TIRED
				stance_step = FALSE
				walk(src, FALSE) //This stops the alligator's walking
				return



/mob/living/simple_animal/hostile/dinosaur/velociraptor/attackby(var/obj/item/O as obj, var/mob/user as mob)
	if (stance != HOSTILE_STANCE_ATTACK && stance != HOSTILE_STANCE_ATTACKING)
		stance = HOSTILE_STANCE_ALERT
		stance_step = 6
		target_mob = user
	..()

/mob/living/simple_animal/hostile/dinosaur/velociraptor/attack_hand(mob/living/carbon/human/M as mob)
	if (stance != HOSTILE_STANCE_ATTACK && stance != HOSTILE_STANCE_ATTACKING)
		stance = HOSTILE_STANCE_ALERT
		stance_step = 6
		target_mob = M
	..()

/mob/living/simple_animal/hostile/dinosaur/velociraptor/FindTarget()
	. = ..()
	if (.)
		custom_emote(1,"stares alertly at [.].")
		stance = HOSTILE_STANCE_ALERT

/mob/living/simple_animal/hostile/dinosaur/velociraptor/LoseTarget()
	..(5)

/mob/living/simple_animal/hostile/dinosaur/velociraptor/AttackingTarget()
	if (!Adjacent(target_mob))
		return
	custom_emote(1, pick( list("bites [target_mob]!") ) )

	var/damage = pick(melee_damage_lower,melee_damage_upper)

	if (ishuman(target_mob))
		var/mob/living/carbon/human/H = target_mob
		var/dam_zone = pick("l_hand", "r_hand", "l_leg", "r_leg")
		var/obj/item/organ/external/affecting = H.get_organ(ran_zone(dam_zone))
		if (prob(90))
			H.apply_damage(damage, BRUTE, affecting, H.run_armor_check(affecting, "melee"), sharp=1, edge=1)
		else
			affecting.droplimb(FALSE, DROPLIMB_EDGE)
			visible_message("\The [src] bites off [H]'s limb!")
			for(var/mob/living/carbon/human/NB in view(6,src))
				NB.mood -= 12
		return H
	else if (isliving(target_mob))
		var/mob/living/L = target_mob
		L.adjustBruteLoss(damage)
		return L