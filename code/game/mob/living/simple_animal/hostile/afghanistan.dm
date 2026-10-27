/mob/living/simple_animal/hostile/human/muj_insurgent
	name = "Mujahideen insurgent"
	desc = "A local insurgent fighting for the Mujahideen."
	icon_state = "muj1"
	icon_dead = "muj1_dead"
	response_help = "pushes"
	response_disarm = "shoves"
	response_harm = "hits"
	speak = list("Allahu akbar!!", "Death to the infidels!")
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
	faction = ARAB
	ranged = 1
	rapid = 0
	firedelay = 15
	projectiletype = /obj/item/projectile/bullet/rifle/a762x39
	grenade_type = /obj/item/weapon/grenade/coldwar/m67
	casingtype = null
	language = new/datum/language/arab
	stop_automated_movement = TRUE
	wander = 0
	New()
		..()
		firedelay += pick(-1,0,1)
		icon_state = "muj[pick(1,2)]"
		icon_living = icon_state
		icon_dead = "[icon_state]_dead"
		grenades = rand(0,1)
		messages["injured"] = list("!! I am injured!","!! AAARGH!")
		messages["backup"] = list( "!! I need backup!","!! Cover me!")
		messages["enemy_sighted"] = list("!! Shuravi!!","!! Traitors!!","!! Infidels spotted!")
		messages["grenade"] = list("!! GRENADE!!!", "!! Grenade, run!!")
		gun = new/obj/item/weapon/gun/projectile/boltaction/mosin/m30(src)

/mob/living/simple_animal/hostile/human/muj_insurgent/akm
	rapid = 1
	New()
		..()
		icon_state = "mujakm"
		icon_living = icon_state
		icon_dead = "[icon_state]_dead"
		gun = new/obj/item/weapon/gun/projectile/submachinegun/ak47(src)