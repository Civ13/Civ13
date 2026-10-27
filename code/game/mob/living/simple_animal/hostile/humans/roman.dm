/mob/living/simple_animal/hostile/human/roman
	name = "Legionary"
	desc = "A Roman legionary!"
	icon_state = "legionary"
	icon_dead = "legionary_dead"
	response_help = "pushes"
	response_disarm = "shoves"
	response_harm = "hits"
	speak = list("Roma invicta!", "Aeterna victrix!", "Pullo, formation!", "Get back in formation, you drunken fool!", "Justice knows every man's number.", "For the glory of Rome!", "You have committed a terrible sacrilege, and you will pay for it with your life!", "Brawlers and drunkards will be flogged.", "Thieves will be strangled.", "Deserters will be crucified.") //can you tell I am a fan of HBO's Rome series?
	speak_emote = list("grumbles", "screams")
	emote_hear = list("curses","grumbles","screams")
	emote_see = list("stares ferociously", "stomps")
	attack_verb = "stabs"
	maxHealth = 150
	health = 150
	faction = ROMAN
	harm_intent_damage = 15
	melee_damage_lower = 35
	melee_damage_upper = 45
	attacktext = "stabbed"
	attack_sound = 'sound/weapons/bladeslice.ogg'
	behaviour = "hostile"
	role = "soldier"
	language = new/datum/language/latin
	weapon = /obj/item/weapon/material/sword/gladius/iron

/mob/living/simple_animal/hostile/human/roman/friendly
	name = "Roman Garrison"
	desc = "A Roman garrison soldier, hired to defend the colony."
	maxHealth = 300 //shhhh
	health = 300
	faction = CIVILIAN