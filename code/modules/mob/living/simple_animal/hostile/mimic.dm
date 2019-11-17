/mob/living/simple_animal/hostile/mimic
	name = "mimic"
	desc = "Thats no treasure chest!"
	icon_state = "mimic"
	icon_living = "mimic"
	icon_dead = "none"
	icon_gib = "none"
	speak = list("clatter","drool","rattle","creak")
	speak_emote = list("clatters", "creaks")
	emote_hear = list("clatters","creaks","shivers")
	emote_see = list("looks hungry", "starts drooling")
	speak_chance = TRUE
	turns_per_move = 5
	move_to_delay = 5
	see_in_dark = 8
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/bearmeat
	response_help  = "opens"
	response_disarm = "opens"
	response_harm   = "kicks"
	stop_automated_movement_when_pulled = FALSE
	maxHealth = 120
	health = 120
	melee_damage_lower = 15
	melee_damage_upper = 25
	mob_size = MOB_LARGE

	var/activeicon = 'icons/mob/animal.dmi'
	var/activeicon_state = "mimic"
	var/idleicon = 'icons/obj/storage.dmi'
	var/idleicon_state = "treasure_chest"
	var/stance_step = FALSE
	var/btype = ""

	faction = "neutral"

/mob/living/simple_animal/hostile/mimic/Life()
	. =..()
	if (!.)
		return

	icon_state = "mimic"

	switch(stance)

		if (HOSTILE_STANCE_TIRED)
			stop_automated_movement = TRUE
			icon = idleicon
			icon_state = idleicon_state
			stance_step++
			if (stance_step >= 10) //rests for 10 ticks
				if (target_mob && target_mob in ListTargets(7))
					stance = HOSTILE_STANCE_ATTACK //If the mob he was chasing is still nearby, resume the attack, otherwise go idle.
				else
					stance = HOSTILE_STANCE_IDLE

		if (HOSTILE_STANCE_ALERT)
			icon = idleicon
			icon_state = idleicon_state
			stop_automated_movement = TRUE
			var/found_mob = FALSE
			if (target_mob && target_mob in ListTargets(7))
				if (!(SA_attackable(target_mob)))
					stance_step = max(0, stance_step) //If we have not seen a mob in a while, the stance_step will be negative, we need to reset it to FALSE as soon as we see a mob again.
					stance_step++
					found_mob = TRUE
					set_dir(get_dir(src,target_mob))	//Keep staring at the mob

			if (!found_mob)
				stance_step--

			if (stance_step <= -20) //If we have not found a mob for 20-ish ticks, revert to idle mode
				stance = HOSTILE_STANCE_IDLE
			if (stance_step >= 20)   //If we have been staring at a mob for 7 ticks,
				stance = HOSTILE_STANCE_ATTACK

		if (HOSTILE_STANCE_ATTACKING)
			icon = activeicon
			icon_state = activeicon_state
			if (stance_step >= 20)	//attacks for 20 ticks, then it gets tired and needs to rest
				custom_emote(1, "shutters and closes." )
				stance = HOSTILE_STANCE_TIRED
				stance_step = FALSE
				walk(src, FALSE) //This stops the bear's walking
				return



/mob/living/simple_animal/hostile/mimic/attackby(var/obj/item/O as obj, var/mob/user as mob)
	if (stance != HOSTILE_STANCE_ATTACK && stance != HOSTILE_STANCE_ATTACKING)
		stance = HOSTILE_STANCE_ALERT
		stance_step = 6
		target_mob = user
	..()

/mob/living/simple_animal/hostile/bear/attack_hand(mob/living/carbon/human/M as mob)
	if (stance != HOSTILE_STANCE_ATTACK && stance != HOSTILE_STANCE_ATTACKING)
		stance = HOSTILE_STANCE_ATTACKING
		stance_step = 6
		target_mob = M
	..()

/mob/living/simple_animal/hostile/mimic/FindTarget()
	. = ..()
	if (.)
		stance = HOSTILE_STANCE_ALERT

/mob/living/simple_animal/hostile/mimic/LoseTarget()
	..(5)

/mob/living/simple_animal/hostile/mimic/AttackingTarget()
	if (!Adjacent(target_mob))
		return
	if(prob(50))
		playsound(src.loc, 'sound/effects/shieldbash.ogg', 100, TRUE, 2)
	else
		playsound(src.loc, 'sound/effects/shieldbash2.ogg', 100, TRUE, 2)
	custom_emote(1, pick( list("chomps [target_mob]!", "bites [target_mob]!") ) )

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


/mob/living/simple_animal/hostile/mimic/death()
	new/obj/structure/closet/crate/loottreasurechest(src.loc)
	qdel(src)