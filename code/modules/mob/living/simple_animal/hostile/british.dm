/mob/living/simple_animal/hostile/british
	name = "Redcoat Soldier"
	desc = "A british soldier."
	icon_state = "britishmelee"
	icon_dead = "britishmelee_dead"
	turns_per_move = 2
	response_help = "pushes"
	response_disarm = "shoves"
	response_harm = "hits"
	speak = list("FOR THE KING!","Fucking pirates!")
	speak_emote = list("grumbles", "screams")
	emote_hear = list("curses","grumbles","screams")
	emote_see = list("stares ferociously", "stomps")
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

	var/corpse = /mob/living/carbon/human/corpse/british

	faction = BRITISH


/mob/living/simple_animal/hostile/british/death()
	..()
	if(corpse)
		new corpse (src.loc)
	qdel(src)
	return

/mob/living/simple_animal/hostile/townmilitia
	name = "Town Militia"
	desc = "A british town militia."
	icon_state = "britishmelee"
	icon_dead = "britishmelee_dead"
	turns_per_move = 2
	response_help = "pushes"
	response_disarm = "shoves"
	response_harm = "hits"
	speak = list("FOR THE KING!","Fucking pirates!")
	speak_emote = list("grumbles", "screams")
	emote_hear = list("curses","grumbles","screams")
	emote_see = list("stares ferociously", "stomps")
	speak_chance = TRUE
	speed = 4
	stop_automated_movement_when_pulled = 0
	maxHealth = 100
	health = 100
	move_to_delay = 6
	harm_intent_damage = 5
	melee_damage_lower = 30
	melee_damage_upper = 40
	attacktext = "slashed"
	attack_sound = 'sound/weapons/bladeslice.ogg'


	var/corpse = /mob/living/carbon/human/corpse/british
	faction = CIVILIAN


/mob/living/simple_animal/hostile/townmilitia/death()
	..()
	if(corpse)
		new corpse (src.loc)
	qdel(src)
	return