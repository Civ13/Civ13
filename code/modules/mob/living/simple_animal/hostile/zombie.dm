/mob/living/simple_animal/hostile/zombie
	name = "\improper zombie"
	desc = "A reanimated dead corpse."
	icon = 'icons/mob/zombie1.dmi'
	icon_state = "chest_s"
	icon_dead = ""
	turns_per_move = 8
	response_help = "pushes"
	response_disarm = "shoves"
	response_harm = "hits"
	speak = list("...")
	speak_emote = list("groans")
	emote_hear = list("spooks")
	emote_see = list("stares", "moves slowly","groans")
	speak_chance = TRUE
	speed = 8
	maxHealth = 100
	health = 100
	stop_automated_movement_when_pulled = FALSE
	harm_intent_damage = 14
	melee_damage_lower = 8
	melee_damage_upper = 14
	move_to_delay = 8
	break_stuff_probability = 25
	attacktext = "scratched"
	attack_sound = 'sound/animals/zombie/zombiehit.ogg'
	faction = "neutral"
	var/list/bodyparts = list()
	var/stance_step = FALSE

/mob/living/simple_animal/hostile/zombie/New()
	..()
	var/list/totalbodyparts = list("l_hand_s","r_hand_s","l_arm_s","r_arm_s","l_leg_s","r_leg_s","l_foot_s","r_foot_s", "head_s")
	icon = pick('icons/mob/zombie1.dmi','icons/mob/zombie2.dmi','icons/mob/zombie3.dmi')
	bodyparts = totalbodyparts
	if (prob(30))
		if (prob(60))
			bodyparts -= "l_hand_s"
		else
			bodyparts -= "l_arm_s"
			bodyparts -= "l_hand_s"
	if (prob(30))
		if (prob(60))
			bodyparts -= "r_hand_s"
		else
			bodyparts -= "r_arm_s"
			bodyparts -= "r_hand_s"
	if (prob(20))
		if (prob(60))
			bodyparts -= "r_foot_s"
		else
			bodyparts -= "r_leg_s"
			bodyparts -= "r_foot_s"
	if (prob(20))
		if (prob(60))
			bodyparts -= "l_foot_s"
		else
			bodyparts -= "l_leg_s"
			bodyparts -= "l_foot_s"
	move_to_delay = rand(6,9)
	speed = rand(6,9)
	update_icons()
/mob/living/simple_animal/hostile/zombie/update_icons()
	..()
	overlays.Cut()
	for(var/i in bodyparts)
		overlays += image(icon, i)

/mob/living/simple_animal/hostile/zombie/death()
	..()
	new/obj/structure/religious/remains(src.loc)
	qdel(src)
	return

/mob/living/simple_animal/hostile/zombie/Life()
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
					var/sound2play = pick('sound/animals/zombie/zombie_idle1.ogg', 'sound/animals/zombie/zombie_idle2.ogg', 'sound/animals/zombie/zombie_idle3.ogg','sound/animals/zombie/zombie_idle4.ogg','sound/animals/zombie/zombie_idle5.ogg','sound/animals/zombie/zombie_idle6.ogg','sound/animals/zombie/zombie_idle7.ogg')
					playsound(src.loc, sound2play, 100, TRUE)

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
							var/sound2play = pick('sound/animals/zombie/zombie_sight1.ogg', 'sound/animals/zombie/zombie_sight2.ogg', 'sound/animals/zombie/zombie_sight3.ogg','sound/animals/zombie/zombie_sight4.ogg','sound/animals/zombie/zombie_sight5.ogg','sound/animals/zombie/zombie_sight6.ogg','sound/animals/zombie/zombie_sight7.ogg')
							playsound(src.loc, sound2play, 100, TRUE)

			if (!found_mob)
				stance_step--

			if (stance_step <= -20) //If we have not found a mob for 20-ish ticks, revert to idle mode
				stance = HOSTILE_STANCE_IDLE
			if (stance_step >= 3)   //If we have been staring at a mob for 7 ticks,
				stance = HOSTILE_STANCE_ATTACK
				var/sound2play = pick('sound/animals/zombie/zombie_sight1.ogg', 'sound/animals/zombie/zombie_sight2.ogg', 'sound/animals/zombie/zombie_sight3.ogg','sound/animals/zombie/zombie_sight4.ogg','sound/animals/zombie/zombie_sight5.ogg','sound/animals/zombie/zombie_sight6.ogg','sound/animals/zombie/zombie_sight7.ogg')
				playsound(src.loc, sound2play, 100, TRUE)

		if (HOSTILE_STANCE_ATTACKING)
			if (stance_step >= 20)	//attacks for 20 ticks, then it gets tired and needs to rest
				custom_emote(1, "is worn out and needs to rest." )
				stance = HOSTILE_STANCE_TIRED
				stance_step = FALSE
				walk(src, FALSE) //This stops the bear's walking
				return

/mob/living/simple_animal/hostile/zombie/attackby(var/obj/item/O as obj, var/mob/user as mob)
	if (stance != HOSTILE_STANCE_ATTACK && stance != HOSTILE_STANCE_ATTACKING)
		stance = HOSTILE_STANCE_ALERT
		stance_step = 6
		target_mob = user
	..()

/mob/living/simple_animal/hostile/zombie/attack_hand(mob/living/carbon/human/M as mob)
	if (stance != HOSTILE_STANCE_ATTACK && stance != HOSTILE_STANCE_ATTACKING)
		stance = HOSTILE_STANCE_ALERT
		stance_step = 6
		target_mob = M
	..()