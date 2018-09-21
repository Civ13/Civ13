/mob/living/simple_animal/hostile/british
	name = "Redcoat Soldier"
	desc = "A british soldier."
	icon_state = "britishmelee"
	icon_dead = "britishmelee_dead"
	turns_per_move = 5
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

	harm_intent_damage = 5
	melee_damage_lower = 30
	melee_damage_upper = 40
	attacktext = "slashed"
	attack_sound = 'sound/weapons/bladeslice.ogg'


	var/corpse = /mob/living/carbon/human/corpse/british
	var/weapon1 = /obj/item/weapon/material/sword/sabre

	faction = BRITISH


/mob/living/simple_animal/hostile/british/death()
	..()
	if(corpse)
		new corpse (src.loc)
	if(weapon1)
		new weapon1 (src.loc)
	qdel(src)
	return