/mob/living/simple_animal/hostile/human/zombie
	name = "\improper zombie"
	desc = "A reanimated dead corpse."
	icon = 'icons/mob/zombie1.dmi'
	icon_state = "zombie"
	icon_dead = ""
	response_help = "pushes"
	response_disarm = "shoves"
	response_harm = "hits"
	speak = list("arghh", "urrgh")
	speak_emote = list("groans", "moans")
	emote_hear = list("stares")
	emote_see = list("stares", "moves slowly","groans")
	speak_chance = TRUE
	speed = 12
	maxHealth = 100 //Buffed, might need more
	health = 100 //Buffed, might need more
	stop_automated_movement_when_pulled = FALSE
	harm_intent_damage = 18
	melee_damage_lower = 10
	melee_damage_upper = 18
	move_to_delay = 3
	break_stuff_probability = 25
	attacktext = "scratched"
	attack_sound = 'sound/animals/zombie/zombiehit.ogg'
	faction = "neutral"
	var/list/bodyparts = list()
	behaviour = "hostile"

/mob/living/simple_animal/hostile/human/zombie/New()
	..()
	icon_state = ""
	var/list/totalbodyparts = list("l_hand_s","r_hand_s","l_arm_s","r_arm_s","l_leg_s","r_leg_s","l_foot_s","r_foot_s")
	icon = pick('icons/mob/zombie1.dmi','icons/mob/zombie2.dmi','icons/mob/zombie3.dmi')
	bodyparts = totalbodyparts
	bodyparts += "head_s"
	bodyparts += "chest_s"
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
	maxHealth = rand(60,120)
	health = maxHealth
	limb_updates()
	update_icons()

/mob/living/simple_animal/hostile/human/zombie/handle_mutations_and_radiation()
	return

/mob/living/simple_animal/hostile/human/zombie/update_icons()
	..()
	overlays.Cut()
	if (stat == DEAD)
		for(var/i in bodyparts)
			overlays += image(icon, "[i]_dead")
	else
		for(var/i in bodyparts)
			overlays += image(icon, i)

/mob/living/simple_animal/hostile/human/zombie/death()
	update_icons()
	..()
/mob/living/simple_animal/hostile/human/zombie/Life()
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

/mob/living/simple_animal/hostile/human/zombie/hit_with_weapon(obj/item/O, mob/living/user, var/effective_force, var/hit_zone)
	if (hit_zone in list("r_leg", "l_leg", "l_arm", "r_arm") && prob(25))
		visible_message("<span class='notice'>[user] tried to strike \the [src] but missed!</span>")
		return
	else if (hit_zone in list("r_foot", "l_foot", "l_hand", "r_hand") && prob(40))
		visible_message("<span class='notice'>[user] tried to strike \the [src] but missed!</span>")
		return

	else if (hit_zone == "head" && prob(35))
		visible_message("<span class='notice'>[user] tried to strike \the [src] but missed!</span>")
		return
	else
		visible_message("<span class='danger'>\The [src] has been attacked in \the [parse_zone(hit_zone)] with \the [O] by [user].</span>")

		if (O.force <= resistance)
			user << "<span class='danger'>This weapon is ineffective, it does no damage.</span>"
			return 2

		var/damage = O.force
		if (O.damtype == HALLOSS)
			damage = FALSE

		adjustBruteLoss(damage)
		limb_hit(hit_zone)
	return FALSE


/mob/living/simple_animal/hostile/human/zombie/proc/limb_hit(var/limb)
	if (limb == "head")
		if (prob(50))
			health = 0
			death()
	else
		if (limb in list("r_leg", "l_leg", "l_arm", "r_arm") && prob(50))
			bodyparts -= "[limb]_s"
			visible_message("[src]'s [parse_zone(limb)] gets severed!")
			var/tmplimb = limb
			tmplimb = replacetext(tmplimb, "arm", "hand")
			tmplimb = replacetext(tmplimb, "leg", "foot")
			bodyparts -= "[tmplimb]_s"
	limb_updates()
	update_icons()

/mob/living/simple_animal/hostile/human/zombie/proc/limb_updates()
	harm_intent_damage = 14
	melee_damage_lower = 8
	melee_damage_upper = 14
	move_to_delay = 12
	speed = 12

	for (var/i in bodyparts)
		if (i == "l_leg_s")
			move_to_delay -= 2
			speed -= 2
		else if (i == "r_leg_s")
			move_to_delay -= 2
			speed -= 2
		else if (i == "l_foot_s")
			move_to_delay -= 1
			speed -= 1
		else if (i == "r_foot_s")
			move_to_delay -= 1
			speed -= 1
		else if (i == "l_hand_s")
			harm_intent_damage -= 4
			melee_damage_lower -= 2
			melee_damage_upper -= 4
		else if (i == "r_hand_s")
			harm_intent_damage -= 4
			melee_damage_lower -= 2
			melee_damage_upper -= 4
		else if (i == "l_arm_s")
			move_to_delay -= 1
			speed -= 1
		else if (i == "r_arm_s")
			move_to_delay -= 1
			speed -= 1


/mob/living/simple_animal/hostile/human/zombie/AttackingTarget()
	if (!Adjacent(target_mob))
		return
	if(prob(50))
		playsound(src.loc, 'sound/weapons/bite.ogg', 100, TRUE, 2)
	else
		playsound(src.loc, 'sound/weapons/bite_2.ogg', 100, TRUE, 2)
	custom_emote(1, pick( list("slashes [target_mob]!", "bites [target_mob]!") ) )

	var/damage = pick(melee_damage_lower,melee_damage_upper)
	if (ishuman(target_mob))
		var/mob/living/human/H = target_mob
		var/dam_zone = pick("chest", "l_hand", "r_hand", "l_leg", "r_leg")
		var/obj/item/organ/external/affecting = H.get_organ(ran_zone(dam_zone))
		var/dmod = 1
		if (H.find_trait("Weak Immune System"))
			dmod = 2
		if (prob(3*dmod))
			H.disease = TRUE
			H.disease_type = "zombie"
		H.apply_damage(damage, BRUTE, affecting, H.run_armor_check(affecting, "melee"), sharp=1, edge=1)
	else if (isliving(target_mob))
		var/mob/living/L = target_mob
		L.adjustBruteLoss(damage)
		return L