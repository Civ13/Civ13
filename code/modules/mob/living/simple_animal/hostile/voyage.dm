/mob/living/simple_animal/hostile/human/voyage/spanish/
	name = "Spanishg Soldier"
	desc = "Attacks any and all intruders or enemies."
	icon_state = "spanish_soldier"
	icon_dead = "piratemelee_dead"
	response_help = "pushes"
	response_disarm = "shoves"
	response_harm = "hits"
	speak = list("For Spain!!","Die Pirate!")
	speak_emote = list("grumbles", "screams")
	emote_hear = list("curses","grumbles","screams")
	emote_see = list("stares ferociously", "readies his sword")
	speak_chance = TRUE
	speed = 4
	maxHealth = 100
	health = 100
	move_to_delay = 6
	stop_automated_movement_when_pulled = FALSE
	harm_intent_damage = 5
	melee_damage_lower = 10
	melee_damage_upper = 20
	attacktext = "slashed"
	attack_sound = 'sound/weapons/bladeslice.ogg'
	mob_size = MOB_MEDIUM
	behaviour = "hostile"

	corpse = /mob/living/human/corpse/spanish_soldier
	faction = SPANISH


/mob/living/simple_animal/hostile/human/voyage/spanish/ranged
	name = "Spanish Rifleman"
	desc = "Attacks any and all intruders or enemies."
	icon_state = "spanish_rifleman"
	icon_dead = "pirateranged_dead"
	response_help = "pushes"
	response_disarm = "shoves"
	response_harm = "hits"
	speak = list()
	speak_emote = list("I've got 'em in my sights!")
	emote_hear = list()
	emote_see = list("stares", "cocks musket")
	speak_chance = TRUE
	speed = 6
	stop_automated_movement_when_pulled = 0
	maxHealth = 100
	health = 100
	move_to_delay = 4
	harm_intent_damage = 5
	melee_damage_lower = 5
	melee_damage_upper = 10
	attacktext = "bashed"
	attack_sound = 'sound/weapons/punch3.ogg'
	mob_size = MOB_MEDIUM
	starves = FALSE
	behaviour = "hostile"
	faction = SPANISH
	ranged = TRUE
	rapid = FALSE
	firedelay = 150
	projectiletype = /obj/item/projectile/bullet/rifle/musketball
	corpse = /mob/living/human/corpse/spanish_rifleman
	casingtype = null

	New()
		..()
		messages["injured"] = list("!!I am injured!","!!I'm hit!!")
		messages["backup"] = list("!!Over here!", "!!Come here!!")
		messages["enemy_sighted"] = list("!!I see one!", "!!HEY YOU!!")
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
	speak_emote = list("I've got 'em in my sights!")
	emote_hear = list()
	emote_see = list("stares", "cocks flintlock pistol")
	speak_chance = TRUE
	speed = 6
	stop_automated_movement_when_pulled = 0
	maxHealth = 100
	health = 100
	move_to_delay = 4
	harm_intent_damage = 10
	melee_damage_lower = 15
	melee_damage_upper = 20
	attacktext = "slashed"
	attack_sound = 'sound/weapons/bladeslice.ogg'
	mob_size = MOB_MEDIUM
	starves = FALSE
	behaviour = "hostile"
	faction = SPANISH
	ranged = TRUE
	rapid = FALSE
	firedelay = 120
	projectiletype = /obj/item/projectile/bullet/rifle/musketball_pistol
	corpse = /mob/living/human/corpse/spanish_sgt
	casingtype = null

	New()
		..()
		messages["injured"] = list("!!I am injured!","!!I'm hit!!")
		messages["backup"] = list("!!Over here!", "!!Come here!!")
		messages["enemy_sighted"] = list("!!I see one!", "!!HEY YOU!!")
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
	speak_emote = list("I've got 'em in my sights!")
	emote_hear = list()
	emote_see = list("stares", "cocks flintlock pistol")
	speak_chance = TRUE
	speed = 6
	stop_automated_movement_when_pulled = 0
	maxHealth = 100
	health = 100
	move_to_delay = 4
	harm_intent_damage = 10
	melee_damage_lower = 20
	melee_damage_upper = 30
	attacktext = "slashed"
	attack_sound = 'sound/weapons/bladeslice.ogg'
	mob_size = MOB_MEDIUM
	starves = FALSE
	behaviour = "hostile"
	faction = SPANISH
	ranged = TRUE
	rapid = FALSE
	firedelay = 120
	projectiletype = /obj/item/projectile/bullet/rifle/musketball_pistol
	corpse = /mob/living/human/corpse/spanish_lt
	casingtype = null

	New()
		..()
		messages["injured"] = list("!!I am injured!","!!I'm hit!!")
		messages["backup"] = list("!!Over here!", "!!Come here!!")
		messages["enemy_sighted"] = list("!!I see one!", "!!HEY YOU!!")
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
	speak_emote = list("I've got 'em in my sights!")
	emote_hear = list()
	emote_see = list("stares", "cocks flintlock pistol")
	speak_chance = TRUE
	speed = 6
	stop_automated_movement_when_pulled = 0
	maxHealth = 150
	health = 150
	move_to_delay = 4
	harm_intent_damage = 10
	melee_damage_lower = 30
	melee_damage_upper = 45
	attacktext = "slashed"
	attack_sound = 'sound/weapons/bladeslice.ogg'
	mob_size = MOB_MEDIUM
	starves = FALSE
	behaviour = "hostile"
	faction = SPANISH
	ranged = TRUE
	rapid = FALSE
	firedelay = 100
	projectiletype = /obj/item/projectile/bullet/rifle/musketball_pistol
	corpse = /mob/living/human/corpse/spanish_cpt
	casingtype = null

	New()
		..()
		messages["injured"] = list("!!I am injured!","!!I'm hit!!")
		messages["backup"] = list("!!Over here!", "!!Come here!!")
		messages["enemy_sighted"] = list("!!I see one!", "!!HEY YOU!!")
		messages["grenade"] = list("!!GRENADE!")