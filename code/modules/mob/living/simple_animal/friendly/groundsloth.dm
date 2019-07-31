/mob/living/simple_animal/hostile/groundsloth
	name = "giant ground sloth"
	desc = "A very slow and peaceful giant, unless you poke it with a stick."
	icon = 'icons/mob/animal_64.dmi'
	icon_state = "giantgroundsloth_living"
	icon_living = "giantgroundsloth_living"
	icon_dead = "giantgroundsloth_dead"
	icon_gib = "giantgroundsloth_dead"
	speak = list("Gra","Buuuuur","Urgggggggggghh","Uahhhh")
	speak_emote = list("bellows", "groans")
	emote_hear = list("bellows")
	emote_see = list("shakes its head", "looks attently")
	speak_chance = TRUE
	turns_per_move = 1
	see_in_dark = 8
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/meat
	meat_amount = 8
	response_help  = "pets"
	response_disarm = "gently pushes aside"
	response_harm   = "kicks"
	attacktext = "kicked"
	health = 250
	mob_size = MOB_HUGE
	var/stance_step = FALSE

/mob/living/simple_animal/hostile/groundsloth/FindTarget()
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


/mob/living/simple_animal/hostile/groundsloth/Life()
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
						var/action = pick( list( "groans at [target_mob].", "closely watches [target_mob]." ) )
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



/mob/living/simple_animal/hostile/groundsloth/attackby(var/obj/item/O as obj, var/mob/user as mob)
	if (stance != HOSTILE_STANCE_ATTACK && stance != HOSTILE_STANCE_ATTACKING)
		stance = HOSTILE_STANCE_ATTACK
		stance_step = 0
		target_mob = user
	..()

/mob/living/simple_animal/hostile/groundsloth/attack_hand(mob/living/carbon/human/M as mob)
	if (stance != HOSTILE_STANCE_ATTACK && stance != HOSTILE_STANCE_ATTACKING)
		stance = HOSTILE_STANCE_ATTACK
		stance_step = 0
		target_mob = M
	..()

/mob/living/simple_animal/hostile/groundsloth/FindTarget()
	. = ..()
	if (.)
		custom_emote(1,"stares alertly at [.].")
		stance = HOSTILE_STANCE_ALERT

/mob/living/simple_animal/hostile/groundsloth/LoseTarget()
	..(5)
