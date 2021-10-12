/mob/living/simple_animal/hostile/human
	move_to_delay = 3

/mob/living/simple_animal/hostile/human/japanese
	name = "Japanese Soldier"
	desc = "A japanese soldier."
	icon_state = "japmelee"
	icon_dead = "japmelee_dead"
	response_help = "pushes"
	response_disarm = "shoves"
	response_harm = "hits"
	speak = list("TENNOHEIKA BANZAI!!","BANZAI!!","banzai!","Tennoheika banzai!","Shinjimae!")
	speak_emote = list("grumbles", "mumbles")
	emote_hear = list("curses","grumbles","banzai's")
	emote_see = list("stares murderously", "draws metal")
	speak_chance = TRUE
	speed = 4
	move_to_delay = 3
	stop_automated_movement_when_pulled = 0
	maxHealth = 100
	health = 100
	harm_intent_damage = 5
	melee_damage_lower = 30
	melee_damage_upper = 40
	attacktext = "slashed"
	attack_sound = 'sound/weapons/bladeslice.ogg'
	mob_size = MOB_MEDIUM
	language = new/datum/language/japanese

	corpse = /mob/living/human/corpse/japanese

	faction = JAPANESE

/mob/living/simple_animal/hostile/human/japanesecap
	name = "Japanese Captain"
	desc = "A japanese captain."
	icon_state = "japcommander"
	icon_dead = "japmelee_dead"
	response_help = "pushes"
	response_disarm = "shoves"
	response_harm = "hits"
	speak = list("omae wa mou, shinde iru", "hah hah hah hah, baka ne")
	speak_emote = list("grumbles", "mumbles")
	emote_hear = list("curses","grumbles","banzai's")
	emote_see = list("stares 'omae wa mou shinde iru-ly'", "draws metal")
	speak_chance = TRUE
	speed = 6
	move_to_delay = 3
	stop_automated_movement_when_pulled = 0
	maxHealth = 120
	health = 120
	harm_intent_damage = 10
	melee_damage_lower = 35
	melee_damage_upper = 45
	attacktext = "pistol-whipped"
	attack_sound = 'sound/weapons/punch3.ogg'
	mob_size = MOB_MEDIUM

	corpse = /mob/living/human/corpse/japanesecap

	faction = JAPANESE

/mob/living/simple_animal/hostile/human/ww2_jap
	name = "Japanese Soldier"
	desc = "A jap soldier! he looks hostile!"
	icon_state = "ww2_jap_ranged1"
	icon_dead = "bandit2_dead"
	response_help = "pushes"
	response_disarm = "shoves"
	response_harm = "whacks"
	speak = list()
	speak_emote = list()
	emote_hear = list()
	emote_see = list("aims", "raises his rifle")
	speak_chance = TRUE
	move_to_delay = 3
	stop_automated_movement_when_pulled = 0
	maxHealth = 150
	health = 150
	harm_intent_damage = 10
	melee_damage_lower = 35
	melee_damage_upper = 45
	attacktext = "bayoneted"
	attack_sound = 'sound/weapons/slice.ogg'
	mob_size = MOB_MEDIUM
	starves = FALSE
	behaviour = "hostile"
	faction = JAPANESE
	ranged = 1
	projectiletype = /obj/item/projectile/bullet/rifle/a77x58
	corpse = /mob/living/human/corpse/japanese_ww2
	casingtype = null
	grenade_type = /obj/item/weapon/grenade/ww2/type97
	language = new/datum/language/japanese

	New()
		..()
		faction2_npcs++
		grenades = rand(1,2)
		messages["injured"] = list("!!I am injured!","!!AAARGH!")
		messages["backup"] =list( "!!I need backup!","!!Cover me!")
		messages["enemy_sighted"] = list("!!Found an american dog!","!!Enemy spotted!")
		messages["grenade"] = list("!!GRENADE!!!", "!!Grenade, run!!")

		gun = new/obj/item/weapon/gun/projectile/boltaction/arisaka99/bayonet(src)
		icon_state = "ww2_jap_ranged[rand(1,4)]"
/mob/living/simple_animal/hostile/human/ww2_jap/death()
	faction2_npcs--
	..()


/mob/living/simple_animal/hostile/human/ww2_jap/summer
	name = "Japanese Soldier"
	desc = "A jap soldier! he looks hostile!"
	icon_state = "ww2_jap_ranged_summer1"

	New()
		..()
		icon_state = "ww2_jap_ranged_summer[rand(1,4)]"

/mob/living/simple_animal/hostile/human/ww2_jap/summer/medic
	name = "Japanese Medic"
	icon_state = "ww2_jap_ranged_summer_medic"
	corpse = /mob/living/human/corpse/ww2_jap_medic
	role = "medic"

	New()
		..()
		icon_state = "ww2_jap_ranged_summer_medic"
		grenades = 0

/mob/living/simple_animal/hostile/human/ww2_jap/mg
	name = "Japanese Machinegunner"
	icon_state = "ww2_jap_ranged_summer_mg"
	corpse = /mob/living/human/corpse/ww2_jap_mg
	rapid = 2
	grenades = 0
	projectiletype = /obj/item/projectile/bullet/rifle/a77x58

	New()
		..()
		icon_state = "ww2_jap_ranged_summer_mg"
		gun = new/obj/item/weapon/gun/projectile/automatic/type99(src)

/mob/living/simple_animal/hostile/human/ww2_jap/squad_leader
	name = "Japanese Squad Leader"
	icon_state = "ww2_jap_ranged_summer_sl"
	projectiletype = /obj/item/projectile/bullet/pistol/c8mmnambu
	corpse = /mob/living/human/corpse/ww2_jap_sl
	rapid = 1
	grenades = 1
	role = "officer"

	New()
		..()
		icon_state = "ww2_jap_ranged_summer_sl"
		gun = new/obj/item/weapon/gun/projectile/submachinegun/type100(src)

/mob/living/simple_animal/hostile/human/ww2_american
	name = "American Soldier"
	desc = "An american soldier! he looks hostile!"
	icon_state = "ww2_american_ranged1"
	icon_dead = "bandit2_dead"
	response_help = "pushes"
	response_disarm = "shoves"
	response_harm = "whacks"
	speak = list("You're dead!", "Just try and kill me bastards!")
	speak_emote = list("grumbles", "mumbles")
	emote_hear = list("curses","grumbles")
	emote_see = list("aims", "raises his rifle")
	speak_chance = TRUE
	move_to_delay = 3
	stop_automated_movement_when_pulled = 0
	maxHealth = 150
	health = 150
	harm_intent_damage = 10
	melee_damage_lower = 35
	melee_damage_upper = 45
	attacktext = "whacked"
	attack_sound = 'sound/weapons/slice.ogg'
	mob_size = MOB_MEDIUM
	starves = FALSE
	behaviour = "hostile"
	faction = AMERICAN
	ranged = 1
	projectiletype = /obj/item/projectile/bullet/rifle/a3006
	corpse = /mob/living/human/corpse/ww2_american
	casingtype = null
	grenade_type = /obj/item/weapon/grenade/ww2/mk2

	New()
		..()
		faction1_npcs++
		grenades = rand(1,2)
		messages["injured"] = list("!!I am injured!","!!AAARGH!")
		messages["backup"] =list( "!!I need backup!","!!Cover me!")
		messages["enemy_sighted"] = list("!!Jap!!","!!Enemy spotted!")
		messages["grenade"] = list("!!GRENADE!!!", "!!Grenade, run!!")
		gun = new/obj/item/weapon/gun/projectile/semiautomatic/m1garand(src)

/mob/living/simple_animal/hostile/human/ww2_american/death()
	..()
	faction1_npcs--

/mob/living/simple_animal/hostile/human/ww2_american/medic
	name = "American Medic"
	icon_state = "ww2_american_ranged_medic"
	corpse = /mob/living/human/corpse/ww2_american_medic
	role = "medic"
	grenades = 0

	New()
		..()
		icon_state = "ww2_american_ranged_medic"

/mob/living/simple_animal/hostile/human/ww2_american/mg
	name = "American Machinegunner"
	icon_state = "ww2_american_ranged_mg"
	corpse = /mob/living/human/corpse/ww2_american_mg
	rapid = 2
	grenades = 0
	projectiletype = /obj/item/projectile/bullet/rifle/a762x54/weak

	New()
		..()
		icon_state = "ww2_american_ranged_mg"
		gun = new/obj/item/weapon/gun/projectile/automatic/bar(src)

/mob/living/simple_animal/hostile/human/ww2_american/squad_leader
	name = "American Squad Leader"
	icon_state = "ww2_american_ranged_sl"
	corpse = /mob/living/human/corpse/ww2_american_sl
	rapid = 1
	grenades = 1
	role = "officer"
	projectiletype = /obj/item/projectile/bullet/pistol/a45

	New()
		..()
		icon_state = "ww2_american_ranged_sl"
		gun = new/obj/item/weapon/gun/projectile/submachinegun/thompson(src)