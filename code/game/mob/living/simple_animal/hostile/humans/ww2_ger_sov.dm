/mob/living/simple_animal/hostile/human/ww2_german
	name = "German Soldier"
	desc = "A German soldier! He looks hostile!"
	use_generated_appearance = TRUE
	icon_state = "ww2_german_ranged1"
	icon_dead = "bandit2_dead"
	response_help = "pushes"
	response_disarm = "shoves"
	response_harm = "whacks"
	speak = list("Feind gesichtet!", "Für das Vaterland!", "Halt!")
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
	faction = GERMAN
	ranged = 1
	projectiletype = /obj/item/projectile/bullet/rifle/a792x57
	corpse = /mob/living/human/corpse/ww2_german
	casingtype = null
	grenade_type = /obj/item/weapon/grenade/ww2/stg1924
	language = new/datum/language/german

	New()
		..()
		faction2_npcs++
		grenades = rand(1,2)
		messages["injured"] = list("!!Ich bin verletzt!","!!AAARGH!")
		messages["backup"] =list( "!!Ich brauche Unterstützung!","!!Deckung!")
		messages["enemy_sighted"] = list("!!Feind!!","!!Feindkontakt!")
		messages["grenade"] = list("!!GRANATE!!!", "!!Deckung, Granate!!")

		gun = new/obj/item/weapon/gun/projectile/boltaction/gewehr98/karabiner98k(src)
		icon_state = "ww2_german_ranged[rand(1,5)]"

/mob/living/simple_animal/hostile/human/ww2_german/death()
	faction2_npcs--
	..()

/mob/living/simple_animal/hostile/human/ww2_german/medic
	name = "German Medic"
	icon_state = "ww2_german_ranged_medic"
	corpse = /mob/living/human/corpse/ww2_german_medic
	role = "medic"
	grenades = 0

	New()
		..()
		icon_state = "ww2_german_ranged_medic"
		gun = new/obj/item/weapon/gun/projectile/pistol/waltherp38(src)

/mob/living/simple_animal/hostile/human/ww2_german/mg
	name = "German Machinegunner"
	icon_state = "ww2_german_ranged_mg"
	corpse = /mob/living/human/corpse/ww2_german_mg
	rapid = 2
	grenades = 0
	projectiletype = /obj/item/projectile/bullet/rifle/a792x57

	New()
		..()
		icon_state = "ww2_german_ranged_mg"
		gun = new/obj/item/weapon/gun/projectile/automatic/manual/mg34(src)

/mob/living/simple_animal/hostile/human/ww2_german/squad_leader
	name = "German Squad Leader"
	icon_state = "ww2_german_ranged_sl"
	corpse = /mob/living/human/corpse/ww2_german_sl
	rapid = 1
	grenades = 1
	role = "officer"
	projectiletype = /obj/item/projectile/bullet/pistol/a9x19

	New()
		..()
		icon_state = "ww2_german_ranged_sl"
		gun = new/obj/item/weapon/gun/projectile/submachinegun/mp40(src)


/mob/living/simple_animal/hostile/human/ww2_soviet
	name = "Soviet Soldier"
	desc = "A Soviet soldier! He looks hostile!"
	use_generated_appearance = TRUE
	icon_state = "ww2_soviet_ranged1"
	icon_dead = "bandit2_dead"
	response_help = "pushes"
	response_disarm = "shoves"
	response_harm = "whacks"
	speak = list("Vrag zamechen!", "Za Rodinu!", "Stoy!")
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
	faction = RUSSIAN
	ranged = 1
	projectiletype = /obj/item/projectile/bullet/rifle/a762x54
	corpse = /mob/living/human/corpse/ww2_soviet
	casingtype = null
	grenade_type = /obj/item/weapon/grenade/ww2/rg42
	language = new/datum/language/russian

	New()
		..()
		faction1_npcs++
		grenades = rand(1,2)
		messages["injured"] = list("!!Ya ranen!","!!AAARGH!")
		messages["backup"] =list( "!!Mne nuzhna podderzhka!","!!Prikroy!")
		messages["enemy_sighted"] = list("!!Vrag!!","!!Vrag zamechen!")
		messages["grenade"] = list("!!GRANATA!!!", "!!Lozhis, granata!!")

		gun = new/obj/item/weapon/gun/projectile/boltaction/mosin(src)
		icon_state = "ww2_soviet_ranged[rand(1,5)]"

/mob/living/simple_animal/hostile/human/ww2_soviet/death()
	..()
	faction1_npcs--

/mob/living/simple_animal/hostile/human/ww2_soviet/medic
	name = "Soviet Medic"
	icon_state = "ww2_soviet_ranged_medic"
	corpse = /mob/living/human/corpse/ww2_soviet_medic
	role = "medic"
	grenades = 0

	New()
		..()
		icon_state = "ww2_soviet_ranged_medic"
		gun = new/obj/item/weapon/gun/projectile/pistol/tt30(src)

/mob/living/simple_animal/hostile/human/ww2_soviet/mg
	name = "Soviet Machinegunner"
	icon_state = "ww2_soviet_ranged_mg"
	corpse = /mob/living/human/corpse/ww2_soviet_mg
	rapid = 2
	grenades = 0
	projectiletype = /obj/item/projectile/bullet/rifle/a762x54

	New()
		..()
		icon_state = "ww2_soviet_ranged_mg"
		gun = new/obj/item/weapon/gun/projectile/automatic/dp28(src)

/mob/living/simple_animal/hostile/human/ww2_soviet/squad_leader
	name = "Soviet Squad Leader"
	icon_state = "ww2_soviet_ranged_sl"
	corpse = /mob/living/human/corpse/ww2_soviet_sl
	rapid = 1
	grenades = 1
	role = "officer"
	projectiletype = /obj/item/projectile/bullet/pistol/a762x25

	New()
		..()
		icon_state = "ww2_soviet_ranged_sl"
		gun = new/obj/item/weapon/gun/projectile/submachinegun/pps(src)
