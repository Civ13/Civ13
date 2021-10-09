/mob/living/simple_animal/hostile/pirate
	name = "Pirate"
	desc = "Does what he wants cause a pirate is free."
	icon_state = "piratemelee"
	icon_dead = "piratemelee_dead"
	response_help = "pushes"
	response_disarm = "shoves"
	response_harm = "hits"
	speak = list("ARRR!","Landlubber!")
	speak_emote = list("grumbles", "screams")
	emote_hear = list("curses","grumbles","screams")
	emote_see = list("stares ferociously", "stomps")
	speak_chance = TRUE
	speed = 4
	maxHealth = 100
	health = 100
	move_to_delay = 6
	stop_automated_movement_when_pulled = FALSE
	harm_intent_damage = 15
	melee_damage_lower = 30
	melee_damage_upper = 40
	attacktext = "slashed"
	attack_sound = 'sound/weapons/bladeslice.ogg'
	mob_size = MOB_MEDIUM
	behaviour = "hostile"

	var/corpse = /mob/living/human/corpse/pirate
	var/weapon1 = /obj/item/weapon/material/sword/cutlass

	faction = PIRATES

///mob/living/simple_animal/hostile/pirate/New()
//	..()
//	var/icon_pick = pick("piratemelee","piratemelee1","piratemelee2")
//	icon_living = icon_pick
//	icon_state = icon_pick


/mob/living/simple_animal/hostile/pirate/death()
	..()
	if(corpse)
		new corpse (src.loc)
	if(weapon1)
		new weapon1 (src.loc)
	qdel(src)
	return

/mob/living/simple_animal/hostile/human/pirate/ranged
	name = "Pirate"
	desc = "Does what he wants cause a pirate is free."
	icon_state = "pirateranged"
	icon_dead = "pirateranged_dead"
	response_help = "pushes"
	response_disarm = "shoves"
	response_harm = "hits"
	speak = list()
	speak_emote = list()
	emote_hear = list()
	emote_see = list("stares", "cocks musket")
	speak_chance = TRUE
	speed = 6
	stop_automated_movement_when_pulled = 0
	maxHealth = 150
	health = 150
	move_to_delay = 4
	harm_intent_damage = 10
	melee_damage_lower = 35
	melee_damage_upper = 45
	attacktext = "bashed"
	attack_sound = 'sound/weapons/punch3.ogg'
	mob_size = MOB_MEDIUM
	starves = FALSE
	behaviour = "hostile"
	faction = PIRATES
	ranged = TRUE
	rapid = FALSE
	firedelay = 180
	projectiletype = /obj/item/projectile/bullet/rifle/musketball_pistol
	corpse = /mob/living/human/corpse/pirate
	casingtype = null

	New()
		..()
		messages["injured"] = list("!!I am injured!","!!I'm hit!!")
		messages["backup"] = list("!!Over here!", "!!Come here!!")
		messages["enemy_sighted"] = list("!!I see one!", "!!HEY YOU!!")
		messages["grenade"] = list("!!GRENADE!")
		if (prob(65))
			gun = new/obj/item/weapon/gun/projectile/flintlock/musketoon(src)
		else
			gun = new/obj/item/weapon/gun/projectile/flintlock/musket(src)

/mob/living/simple_animal/hostile/human/pirate/ranged/death()
	..()
	if(corpse)
		new corpse (src.loc)
	if(gun)
		gun.forceMove(src.loc)
		qdel(src)
	return