/mob/living/simple_animal/hostile/human/pmc
	name = "PMC"
	desc = "A heavily armoured PMC unit."
	icon_state = "pmc"
	icon_dead = "bandit_dead"
	response_help = "pushes"
	response_disarm = "shoves"
	response_harm = "hits"
	speak = list("Civlian stay still!", "responding to hostile")
	speak_emote = list("grumbles", "mumbles")
	emote_hear = list("curses","grumbles")
	emote_see = list("stares", "draws firearm")
	speak_chance = TRUE
	speed = 6
	move_to_delay = 3
	stop_automated_movement_when_pulled = 0
	maxHealth = 250
	health = 250
	move_to_delay = 4
	harm_intent_damage = 10
	melee_damage_lower = 35
	melee_damage_upper = 45
	attacktext = "pistol-whipped"
	attack_sound = 'sound/weapons/punch3.ogg'
	mob_size = MOB_MEDIUM
	starves = FALSE
	behaviour = "hostile"
	corpse = /mob/living/human/corpse/pmc
	faction = PIRATES
	ranged = 1
	rapid = 2
	projectiletype = /obj/item/projectile/bullet/rifle/a762x51
	casingtype = null

	New()
		..()
		gun = new/obj/item/weapon/gun/projectile/submachinegun/ar12(src)