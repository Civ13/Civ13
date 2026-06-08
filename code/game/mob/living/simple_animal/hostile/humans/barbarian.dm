/mob/living/simple_animal/hostile/human/barbarian
	name = "Barbarian"
	desc = "A fierce barbarian!"
	icon_state = "barbarian"
	icon_dead = "barbarian_dead"
	response_help = "pushes"
	response_disarm = "shoves"
	response_harm = "hits"
	speak = list("Bar bar bar!", "Töten!", "Grrr!")
	speak_emote = list("grumbles", "screams")
	emote_hear = list("curses","grumbles","screams")
	emote_see = list("stares ferociously", "stomps")
	attack_verb = "stabs"
	maxHealth = 100
	health = 100
	faction = GERMAN
	harm_intent_damage = 15
	melee_damage_lower = 25
	melee_damage_upper = 35
	attacktext = "stabbed"
	attack_sound = 'sound/weapons/bladeslice.ogg'
	behaviour = "hostile"
	role = "soldier"
	language = new/datum/language/german
	weapon = /obj/item/weapon/material/spear/dory

/mob/living/simple_animal/hostile/human/barbarian/death()
	if(icon_state == icon_dead)
		return
	new /obj/item/stack/money/silvercoin(src.loc)
	return ..()

/mob/living/simple_animal/hostile/human/barbarian/friendly
	name = "Foederati"
	desc = "A hired barbarian from a tribe allied with Rome."
	maxHealth = 200
	health = 200
	faction = CIVILIAN