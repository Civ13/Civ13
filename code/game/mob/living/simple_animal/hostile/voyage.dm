/mob/living/simple_animal/hostile/human/voyage
	idle_counter = 70
	response_help = "pushes"
	response_disarm = "shoves"
	response_harm = "hits"
	speak_chance = TRUE
	speed = 4
	move_to_delay = 4
	stop_automated_movement_when_pulled = FALSE
	mob_size = MOB_MEDIUM
	behaviour = "hostile"
	role = "soldier"
	starves = FALSE

	New()
		..()
		spawn(600)
			if(faction != PIRATES && behaviour == "hostile")
				charge()

/mob/living/simple_animal/hostile/human/voyage/spanish
	name = "Spanish Soldier"
	desc = "Attacks any and all intruders or enemies."
	icon_state = "spanish_soldier"
	icon_dead = "piratemelee_dead"
	speak = list("Fine day for sailing","Sure hope we dont run into any pirates")
	speak_emote = list("grumbles", "screams")
	emote_hear = list("curses","grumbles","screams")
	emote_see = list("stares ferociously", "readies his sword")
	maxHealth = 100
	health = 100
	harm_intent_damage = 5
	melee_damage_lower = 10
	melee_damage_upper = 20
	attacktext = "slashed"
	attack_sound = 'sound/weapons/bladeslice.ogg'
	speed = 6
	stop_automated_movement_when_pulled = 0
	corpse = /mob/living/human/corpse/spanish_soldier
	faction = SPANISH
	language = new/datum/language/spanish

/mob/living/simple_animal/hostile/human/voyage/spanish/ranged
	name = "Spanish Rifleman"
	desc = "Attacks any and all intruders or enemies."
	icon_state = "spanish_rifleman"
	icon_dead = "pirateranged_dead"
	speak = list()
	speak_emote = list("another day in the grand spanish navy")
	emote_hear = list()
	emote_see = list("stares", "cocks musket")
	maxHealth = 100
	health = 100
	harm_intent_damage = 5
	melee_damage_lower = 5
	melee_damage_upper = 10
	attacktext = "bashed"
	attack_sound = 'sound/weapons/punch3.ogg'
	behaviour = "hostile"
	faction = SPANISH
	ranged = TRUE
	rapid = FALSE
	firedelay = 120
	projectiletype = /obj/item/projectile/bullet/rifle/musketball
	corpse = /mob/living/human/corpse/spanish_rifleman
	casingtype = null
	role = "soldier"

	New()
		..()
		messages["injured"] = list("!!I am injured!","!!I'm hit!!")
		messages["backup"] = list("!!Over here!", "!!Come here!!")
		messages["enemy_sighted"] = list("!!I see one!", "!!Got em in my sights!!")
		messages["grenade"] = list("!!GRENADE!")

/mob/living/simple_animal/hostile/human/voyage/spanish/ranged/sgt
	name = "Spanish Petty Officer"
	desc = "Attacks any and all intruders or enemies. Armed with a pistol and a sword."
	icon_state = "spanish_sgt"
	icon_dead = "pirateranged_dead"
	response_help = "pushes"
	response_disarm = "shoves"
	response_harm = "hits"
	speak = list()
	speak_emote = list("another day in the grand spanish navy")
	emote_hear = list()
	emote_see = list("stares", "cocks flintlock pistol")

	maxHealth = 100
	health = 100
	harm_intent_damage = 10
	melee_damage_lower = 15
	melee_damage_upper = 20
	attacktext = "slashed"
	attack_sound = 'sound/weapons/bladeslice.ogg'
	behaviour = "hostile"
	faction = SPANISH
	ranged = TRUE
	rapid = FALSE
	firedelay = 100
	projectiletype = /obj/item/projectile/bullet/rifle/musketball_pistol
	corpse = /mob/living/human/corpse/spanish_sgt
	casingtype = null
	role = "officer"

	New()
		..()
		messages["injured"] = list("!!I am injured!","!!I'm hit!!")
		messages["backup"] = list("!!Over here!", "!!Come here!!")
		messages["enemy_sighted"] = list("!!I see one!", "!!Got em in my sights!!")
		messages["grenade"] = list("!!GRENADE!")

/mob/living/simple_animal/hostile/human/voyage/spanish/ranged/lt
	name = "Spanish Boatswain"
	desc = "Attacks any and all intruders or enemies. Armed with a pistol and a sword."
	icon_state = "spanish_lt"
	icon_dead = "pirateranged_dead"
	response_help = "pushes"
	response_disarm = "shoves"
	response_harm = "hits"
	speak = list()
	speak_emote = list("another day in the grand spanish navy")
	emote_hear = list()
	emote_see = list("stares", "cocks flintlock pistol")
	maxHealth = 100
	health = 100
	harm_intent_damage = 10
	melee_damage_lower = 20
	melee_damage_upper = 30
	attacktext = "slashed"
	attack_sound = 'sound/weapons/bladeslice.ogg'
	
	behaviour = "hostile"
	faction = SPANISH
	ranged = TRUE
	rapid = FALSE
	firedelay = 80
	projectiletype = /obj/item/projectile/bullet/rifle/musketball_pistol
	corpse = /mob/living/human/corpse/spanish_lt
	casingtype = null
	role = "officer"

	New()
		..()
		messages["injured"] = list("!!I am injured!","!!I'm hit!!")
		messages["backup"] = list("!!Over here!", "!!Come here!!")
		messages["enemy_sighted"] = list("!!I see one!", "!!Got em in my sights!!")
		messages["grenade"] = list("!!GRENADE!")

/mob/living/simple_animal/hostile/human/voyage/spanish/ranged/cpt
	name = "Spanish Capitan"
	desc = "Attacks any and all intruders or enemies. Armed with a pistol and a sword."
	icon_state = "spanish_cpt"
	icon_dead = "pirateranged_dead"
	response_help = "pushes"
	response_disarm = "shoves"
	response_harm = "hits"
	speak = list()
	speak_emote = list("another day in the grand spanish navy")
	emote_hear = list()
	emote_see = list("stares", "cocks flintlock pistol")
	maxHealth = 150
	health = 150
	harm_intent_damage = 10
	melee_damage_lower = 30
	melee_damage_upper = 45
	attacktext = "slashed"
	attack_sound = 'sound/weapons/bladeslice.ogg'
	
	behaviour = "hostile"
	faction = SPANISH
	ranged = TRUE
	rapid = FALSE
	firedelay = 80
	projectiletype = /obj/item/projectile/bullet/rifle/musketball_pistol
	corpse = /mob/living/human/corpse/spanish_cpt
	casingtype = null
	role = "officer"

	New()
		..()
		messages["injured"] = list("!!I am injured!","!!I'm hit!!")
		messages["backup"] = list("!!Over here!", "!!Come here!!")
		messages["enemy_sighted"] = list("!!I see one!", "!!Got em in my sights!!")
		messages["grenade"] = list("!!GRENADE!")



////////////////////////////////////////////////CIVIES////////////////////////////////////////////////////////

/mob/living/simple_animal/hostile/human/voyage/merchant
	name = "Merchant"
	desc = "Defends himself if he has to."
	icon_state = "merchant"
	icon_dead = "piratemelee_dead"
	response_help = "pushes"
	response_disarm = "shoves"
	response_harm = "hits"
	speak = list("Would you like to see my wares?","Sure hope we dont run into any pirates.", "I've got the produce if you've got the coin")
	speak_emote = list("mouths something")
	emote_hear = list("hums something","mumbles")
	emote_see = list("stares at the next possible customer", "playes with his hands")
	maxHealth = 100
	health = 100
	stop_automated_movement_when_pulled = FALSE
	harm_intent_damage = 5
	melee_damage_lower = 10
	melee_damage_upper = 20
	attacktext = "punched"
	attack_sound = 'sound/weapons/punch3.ogg'
	behaviour = "defend"
	role = "officer"

	corpse = /mob/living/human/corpse/merchant
	faction = PIRATES

/mob/living/simple_animal/hostile/human/voyage/barmaiden
	name = "Bar Maid"
	desc = "Defends herself if she has to."
	icon_state = "barmaiden"
	icon_dead = "piratemelee_dead"
	response_help = "pushes"
	response_disarm = "shoves"
	response_harm = "hits"
	speak = list("Fancy a drink?","You've got to go elsewhere for those kinds of services", "Bottoms up lads!", "Keep drinking and making me rich!")
	speak_emote = list("mouths something")
	emote_hear = list("hums something","whistles a tune")
	emote_see = list("stares at the next possible customer", "glares at an eyeing customer")
	maxHealth = 100
	health = 100
	stop_automated_movement_when_pulled = FALSE
	harm_intent_damage = 5
	melee_damage_lower = 10
	melee_damage_upper = 20
	attacktext = "punched"
	attack_sound = 'sound/weapons/punch3.ogg'
	behaviour = "defend"
	role = "medic"

	corpse = /mob/living/human/corpse/barmaiden
	faction = PIRATES

/mob/living/simple_animal/hostile/human/voyage/civilian
	name = "Civilian"
	desc = "Defends himself if he has to."
	icon_state = "civ1"
	icon_dead = "piratemelee_dead"
	response_help = "pushes"
	response_disarm = "shoves"
	response_harm = "hits"
	speak = list("Could use a drink","Know where I might find some fine ladies?", "Bottoms up lads!", "Nothing as good as that hot bleaching sun on the even hotter sand.")
	speak_emote = list("grumbles")
	emote_hear = list("hums something","whistles a tune")
	emote_see = list("eyes down a suspicious looking grain of sand", "glares at the sea", "trips")
	maxHealth = 100
	health = 100
	stop_automated_movement_when_pulled = FALSE
	harm_intent_damage = 5
	melee_damage_lower = 10
	melee_damage_upper = 20
	attacktext = "punched"
	attack_sound = 'sound/weapons/punch3.ogg'
	behaviour = "defend"

	corpse = /mob/living/human/corpse/colony_civ
	faction = PIRATES
	New()
		..()
		icon_state = "civ[rand(1,5)]"
		if(prob(33))
			ranged = TRUE
			firedelay = 100
			projectiletype = /obj/item/projectile/bullet/rifle/musketball_pistol

/mob/living/simple_animal/hostile/human/voyage/civilian_f
	name = "Civilian"
	desc = "Defends herself if she has to."
	icon_state = "civ1"
	icon_dead = "piratemelee_dead"
	response_help = "pushes"
	response_disarm = "shoves"
	response_harm = "hits"
	speak = list("Could use a drink","Know where I might find a good man that doesnt drink all his pay?", "We need more stores around here...", "Damn these dresses can get warm")
	speak_emote = list("grumbles")
	emote_hear = list("hums something","whistles a tune")
	emote_see = list("eyes down a suspicious looking grain of sand", "glares at the sea", "trips", "looks at the large number of pirates")
	maxHealth = 100
	health = 100
	stop_automated_movement_when_pulled = FALSE
	harm_intent_damage = 5
	melee_damage_lower = 10
	melee_damage_upper = 20
	attacktext = "punched"
	attack_sound = 'sound/weapons/punch3.ogg'
	behaviour = "defend"
	role = "medic"

	corpse = /mob/living/human/corpse/colony_civ_f
	faction = PIRATES
	New()
		..()
		icon_state = "civ[rand(6,9)]"
