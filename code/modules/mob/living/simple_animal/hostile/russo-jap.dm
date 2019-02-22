/mob/living/simple_animal/hostile/japanese
	name = "Japanese Soldier"
	desc = "A japanese soldier."
	icon_state = "japmelee"
	icon_dead = "japmelee_dead"
	turns_per_move = 2
	response_help = "pushes"
	response_disarm = "shoves"
	response_harm = "hits"
	speak = list("TENNOHEIKA BANZAI!!","BANZAI!!","banzai!","Tennoheika banzai!","Shinjimae!")
	speak_emote = list("grumbles", "mumbles")
	emote_hear = list("curses","grumbles","banzai's")
	emote_see = list("stares murderously", "draws metal")
	speak_chance = TRUE
	speed = 4
	move_to_delay = 6
	stop_automated_movement_when_pulled = 0
	maxHealth = 100
	health = 100
	move_to_delay = 6
	harm_intent_damage = 5
	melee_damage_lower = 30
	melee_damage_upper = 40
	attacktext = "slashed"
	attack_sound = 'sound/weapons/bladeslice.ogg'
	mob_size = MOB_MEDIUM

	var/corpse = /mob/living/carbon/human/corpse/japanese

	faction = JAPANESE


/mob/living/simple_animal/hostile/japanese/death()
	..()
	if(corpse)
		new corpse (src.loc)
	qdel(src)
	return

/mob/living/simple_animal/hostile/japanesecap
	name = "Japanese Captain"
	desc = "A japanese captain."
	icon_state = "japcommander"
	icon_dead = "japmelee_dead"
	turns_per_move = 3
	response_help = "pushes"
	response_disarm = "shoves"
	response_harm = "hits"
	speak = list("omae wa mou, shinde iru", "hah hah hah hah, baka ne")
	speak_emote = list("grumbles", "mumbles")
	emote_hear = list("curses","grumbles","banzai's")
	emote_see = list("stares 'omae wa mou shinde iru-ly'", "draws metal")
	speak_chance = TRUE
	speed = 6
	move_to_delay = 4
	stop_automated_movement_when_pulled = 0
	maxHealth = 120
	health = 120
	move_to_delay = 4
	harm_intent_damage = 10
	melee_damage_lower = 35
	melee_damage_upper = 45
	attacktext = "pistol-whipped"
	attack_sound = 'sound/weapons/punch3.ogg'
	mob_size = MOB_MEDIUM

	var/corpse = /mob/living/carbon/human/corpse/japanesecap

	faction = JAPANESE


/mob/living/simple_animal/hostile/japanesecap/death()
	..()
	if(corpse)
		new corpse (src.loc)
	qdel(src)
	return