/mob/living/simple_animal/hostile/poison
	var/poison_per_bite = 0
	var/poison_type = "toxin"


/mob/living/simple_animal/hostile/poison/snake
	name = "snake"
	desc = "A slithery snake. These legless reptiles are the bane of mice and adventurers alike."
	icon_state = "snake"
	icon_living = "snake"
	icon_dead = "snake_dead"
	speak_emote = list("hisses")
	health = 20
	maxHealth = 20
	move_to_delay = 2
	attacktext = "bites"
	melee_damage_lower = 5
	melee_damage_upper = 6
	response_help  = "pets"
	response_disarm = "shoos"
	response_harm   = "steps on"
	faction = list("hostile")
	density = FALSE
	pass_flags = PASSTABLE
	mob_size = MOB_SMALL
	var/stance_step = FALSE

/mob/living/simple_animal/hostile/poison/snake/FindTarget()
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


/mob/living/simple_animal/hostile/poison/snake/Life()
	. =..()
	if (!.)
		return

	icon_state = "snake"

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
						var/action = pick( list( "hisses at [target_mob].", "closely watches [target_mob]." ) )
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



/mob/living/simple_animal/hostile/poison/snake/attackby(var/obj/item/O as obj, var/mob/user as mob)
	if (stance != HOSTILE_STANCE_ATTACK && stance != HOSTILE_STANCE_ATTACKING)
		stance = HOSTILE_STANCE_ATTACK
		stance_step = 0
		target_mob = user
	..()

/mob/living/simple_animal/hostile/poison/snake/attack_hand(mob/living/carbon/human/M as mob)
	if (stance != HOSTILE_STANCE_ATTACK && stance != HOSTILE_STANCE_ATTACKING)
		stance = HOSTILE_STANCE_ATTACK
		stance_step = 0
		target_mob = M
	..()

/mob/living/simple_animal/hostile/poison/snake/FindTarget()
	. = ..()
	if (.)
		custom_emote(1,"stares alertly at [.].")
		stance = HOSTILE_STANCE_ALERT

/mob/living/simple_animal/hostile/poison/snake/LoseTarget()
	..(5)

/mob/living/simple_animal/hostile/poison/snake/AttackingTarget()
	var/damage = pick(melee_damage_lower, melee_damage_upper)
	if (!Adjacent(target_mob))
		return

	if(istype(target_mob, /mob/living/simple_animal/mouse))
		visible_message("<span class='notice'>[name] consumes [target_mob] in a single gulp!</span>", "<span class='notice'>You consume [target_mob] in a single gulp!</span>")
		qdel(target_mob)
		adjustBruteLoss(-2)
	else
		custom_emote(1, "bites [target_mob]!")
		if (ishuman(target_mob))
			var/mob/living/carbon/human/H = target_mob
			var/dam_zone = pick("l_leg", "r_leg")
			var/obj/item/organ/external/affecting = H.get_organ(ran_zone(dam_zone))
			H.apply_damage(5, TOX, affecting, H.run_armor_check(affecting, "melee"), sharp=1, edge=1)
		else if (isliving(target_mob))
			var/mob/living/L = target_mob
			L.adjustBruteLoss(damage)
			return L
