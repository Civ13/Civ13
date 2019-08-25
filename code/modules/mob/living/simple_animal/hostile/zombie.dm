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
	maxHealth = 80
	health = 80
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
	max_health = rand(60,120)
	health = max_health
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
	..()
	switch(stance)

		if (HOSTILE_STANCE_TIRED)
			stance = HOSTILE_STANCE_IDLE

		if (HOSTILE_STANCE_IDLE)
			if (prob(10))
				var/sound2play = pick('sound/animals/zombie/zombie_idle1.ogg', 'sound/animals/zombie/zombie_idle2.ogg', 'sound/animals/zombie/zombie_idle3.ogg','sound/animals/zombie/zombie_idle4.ogg','sound/animals/zombie/zombie_idle5.ogg','sound/animals/zombie/zombie_idle6.ogg','sound/animals/zombie/zombie_idle7.ogg')
				playsound(src.loc, sound2play, 100, TRUE)

		if (HOSTILE_STANCE_ALERT)
			if (prob(10))
				var/sound2play = pick('sound/animals/zombie/zombie_sight1.ogg', 'sound/animals/zombie/zombie_sight2.ogg', 'sound/animals/zombie/zombie_sight3.ogg','sound/animals/zombie/zombie_sight4.ogg','sound/animals/zombie/zombie_sight5.ogg','sound/animals/zombie/zombie_sight6.ogg','sound/animals/zombie/zombie_sight7.ogg')
				playsound(src.loc, sound2play, 100, TRUE)

		if (HOSTILE_STANCE_ATTACK)
			if (prob(10))
				var/sound2play = pick('sound/animals/zombie/zombie_sight1.ogg', 'sound/animals/zombie/zombie_sight2.ogg', 'sound/animals/zombie/zombie_sight3.ogg','sound/animals/zombie/zombie_sight4.ogg','sound/animals/zombie/zombie_sight5.ogg','sound/animals/zombie/zombie_sight6.ogg','sound/animals/zombie/zombie_sight7.ogg')
				playsound(src.loc, sound2play, 100, TRUE)

		if (HOSTILE_STANCE_ATTACKING)
			var/sound2play = pick('sound/animals/zombie/zombie_sight1.ogg', 'sound/animals/zombie/zombie_sight2.ogg', 'sound/animals/zombie/zombie_sight3.ogg','sound/animals/zombie/zombie_sight4.ogg','sound/animals/zombie/zombie_sight5.ogg','sound/animals/zombie/zombie_sight6.ogg','sound/animals/zombie/zombie_sight7.ogg')
			playsound(src.loc, sound2play, 100, TRUE)