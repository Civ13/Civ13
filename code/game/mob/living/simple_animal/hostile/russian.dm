/mob/living/simple_animal/hostile/human/rf_soldier
	name = "Russian Federal Forces soldier"
	desc = "A soldier serving for the Russian Federation."
	icon_state = "rus_che1_ng"
	icon_dead = "rus_che1_dead"
	response_help = "pushes"
	response_disarm = "shoves"
	response_harm = "hits"
	speak = list("When are we going home?", "That looks suspicious...","Awaiting orders.","Blyat...")
	speak_emote = list("grumbles", "mumbles")
	emote_hear = list("curses","grumbles")
	emote_see = list("aims", "raises his rifle")
	speak_chance = TRUE
	speed = 6
	stop_automated_movement_when_pulled = 0
	maxHealth = 100
	health = 100
	move_to_delay = 4
	harm_intent_damage = 10
	melee_damage_lower = 35
	melee_damage_upper = 45
	attacktext = "pistol-whipped"
	attack_sound = 'sound/weapons/punch3.ogg'
	mob_size = MOB_MEDIUM
	starves = FALSE
	behaviour = "hostile"
	faction = RUSSIAN
	ranged = 1
	rapid = 1
	firedelay = 15
	projectiletype = /obj/item/projectile/bullet/rifle/a545x39
	grenade_type = /obj/item/weapon/grenade/coldwar/rgd5
	casingtype = null
	language = new/datum/language/russian
	stop_automated_movement = TRUE
	wander = 0
	New()
		..()
		firedelay += pick(-1,0,1)
		icon_state = "rus_che[pick(1,2,3,4)]_ng"
		icon_living = icon_state
		icon_dead = "[icon_state]_dead"
		grenades = rand(0,1)
		messages["injured"] = list("!! I am injured!","!! AAARGH!")
		messages["backup"] = list( "!! I need backup!","!! Cover me!")
		messages["enemy_sighted"] = list("!! Enemy spotted!!","!! Take cover, they are here!!","!! Contact!")
		messages["grenade"] = list("!! GRENADE!!!", "!! Grenade, run!!")
		gun = new/obj/item/weapon/gun/projectile/submachinegun/ak74(src)
		overlays += image('icons/mob/items/righthand_guns.dmi', icon_state = "ak74")

/mob/living/simple_animal/hostile/human/rf_soldier/sniper
	rapid = 0
	New()
		..()
		icon_state = "rus_che1_ng"
		icon_living = icon_state
		icon_dead = "[icon_state]_dead"
		grenades = 0
		gun = new/obj/item/weapon/gun/projectile/semiautomatic/svd(src)
		overlays.Cut()
		overlays += image('icons/mob/items/righthand_guns.dmi', icon_state = "svd")