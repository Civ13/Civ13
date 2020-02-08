/mob/living/simple_animal/hostile/bandit
	name = "Bandit"
	desc = "A bandit! he looks scary!"
	icon_state = "bandit2"
	icon_dead = "bandit2_dead"
	turns_per_move = 2
	response_help = "pushes"
	response_disarm = "shoves"
	response_harm = "hits"
	speak = list("You are dead meat!", "COME BACK HERE!")
	speak_emote = list("grumbles", "mumbles")
	emote_hear = list("curses","grumbles")
	emote_see = list("stares", "draws firearm")
	speak_chance = TRUE
	speed = 6
	move_to_delay = 3
	stop_automated_movement_when_pulled = 0
	maxHealth = 80
	health = 80
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
	projectiletype = /obj/item/projectile/bullet/pistol/pistol9
	projectilesound = 'sound/weapons/guns/fire/pistol_fire.ogg'
	casingtype = null

	New()
		..()
		gun = new/obj/item/weapon/gun/projectile/pistol/glock17/standardized(src)

/mob/living/simple_animal/hostile/bandit/death()