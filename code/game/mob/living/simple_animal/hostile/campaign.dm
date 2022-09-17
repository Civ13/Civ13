/mob/living/simple_animal/hostile/human/redmenian_ng
	name = "NGR rifleman"
	desc = "A conscripted soldier of the National Guard of Redmenia."
	icon_state = "rng1"
	icon_dead = "rng1_dead"
	response_help = "pushes"
	response_disarm = "shoves"
	response_harm = "hits"
	speak = list("For Redmenia!!", "URAAAAAAA")
	speak_emote = list("grumbles", "mumbles")
	emote_hear = list("curses","grumbles")
	emote_see = list("aims", "raises his rifle")
	speak_chance = TRUE
	speed = 6
	stop_automated_movement_when_pulled = 0
	maxHealth = 125
	health = 125
	move_to_delay = 4
	harm_intent_damage = 10
	melee_damage_lower = 35
	melee_damage_upper = 45
	attacktext = "pistol-whipped"
	attack_sound = 'sound/weapons/punch3.ogg'
	mob_size = MOB_MEDIUM
	starves = FALSE
	behaviour = "hostile"
	faction = PIRATES
	ranged = 1
	rapid = 0
	firedelay = 15
	projectiletype = /obj/item/projectile/bullet/rifle/a762x39
	grenade_type = /obj/item/weapon/grenade/coldwar/m67
	casingtype = null
	language = new/datum/language/redmenian
	stop_automated_movement = TRUE
	wander = 0
	New()
		..()
		firedelay += pick(-1,0,1)
		icon_state = "rng[pick(1,2,3,4)]"
		icon_living = icon_state
		icon_dead = "[icon_state]_dead"
		grenades = rand(0,1)
		messages["injured"] = list("!! I am injured!","!! AAARGH!")
		messages["backup"] = list( "!! I need backup!","!! Cover me!")
		messages["enemy_sighted"] = list("!! Blugoslavian!!","!! Enemy spotted!")
		messages["grenade"] = list("!! GRENADE!!!", "!! Grenade, run!!")
		gun = new/obj/item/weapon/gun/projectile/boltaction/mosin/m30(src)

/mob/living/simple_animal/hostile/human/redmenian_ng/sl
	name = "NGR squad leader"
	desc = "A squad leader of the National Guard of Redmenia."
	icon_state = "rng_sl"
	icon_dead = "rng_sl_dead"
	maxHealth = 150
	health = 150
	rapid = 0
	firedelay = 8
	role = "officer"
	New()
		..()
		icon_state = "rng_sl"
		icon_living = icon_state
		icon_dead = "[icon_state]_dead"
		grenades = 1
		gun = new/obj/item/weapon/gun/projectile/submachinegun/ak101/ak103(src)

/mob/living/simple_animal/hostile/human/redmenian_ng/medic
	name = "NGR corpsman"
	desc = "A corpsman of the National Guard of Redmenia."
	icon_state = "rng_medic"
	icon_dead = "rng_medic_dead"
	maxHealth = 150
	health = 150
	role = "medic"
	New()
		..()
		icon_state = "rng_medic"
		icon_living = icon_state
		icon_dead = "[icon_state]_dead"
		grenades = 0