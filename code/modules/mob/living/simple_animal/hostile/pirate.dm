/mob/living/simple_animal/hostile/pirate
	name = "Pirate"
	desc = "Does what he wants cause a pirate is free."
	icon_state = "piratemelee"
	icon_dead = "piratemelee_dead"
	turns_per_move = 2
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

	var/corpse = /mob/living/carbon/human/corpse/pirate
	var/weapon1 = /obj/item/weapon/material/sword/cutlass

	faction = PIRATES

///mob/living/simple_animal/hostile/pirate/New()
//	..()
//	var/icon_pick = pick("piratemelee","piratemelee1","piratemelee2")
//	icon_living = icon_pick
//	icon_state = icon_pick


/mob/living/simple_animal/hostile/pirate/ranged
	name = "Pirate Gunner"
	icon_state = "pirateranged"
	icon_living = "pirateranged"
	icon_dead = "pirateranged_dead"
	projectilesound = 'sound/weapons/mosin_shot.ogg'
	ranged = 1
	rapid = 0
	projectiletype = /obj/item/projectile/bullet/rifle/musketball
	corpse = /mob/living/carbon/human/corpse/pirate
	weapon1 = /obj/item/weapon/gun/projectile/flintlock/musketoon

/mob/living/simple_animal/hostile/pirate/ranged/New()
	..()
	icon_living = "pirateranged"
	icon_state = "pirateranged"

/mob/living/simple_animal/hostile/pirate/death()
	..()
	if(corpse)
		new corpse (src.loc)
	if(weapon1)
		new weapon1 (src.loc)
	qdel(src)
	return