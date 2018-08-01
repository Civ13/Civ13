/mob/living/simple_animal/hostile/pirate
	name = "Pirate"
	desc = "Does what he wants cause a pirate is free."
	icon_state = "piratemelee"
	icon_dead = "piratemelee_dead"
	turns_per_move = 5
	response_help = "pushes"
	response_disarm = "shoves"
	response_harm = "hits"
	speak = list("ARRR!","AaarGH!")
	speak_emote = list("grumbles", "screams")
	emote_hear = list("curses","grumbles","screams")
	emote_see = list("stares ferociously", "stomps")
	speak_chance = TRUE
	speed = 4
	stop_automated_movement_when_pulled = 0
	maxHealth = 100
	health = 100

	harm_intent_damage = 5
	melee_damage_lower = 30
	melee_damage_upper = 40
	attacktext = "slashed"
	attack_sound = 'sound/weapons/bladeslice.ogg'

	min_oxy = 5
	max_oxy = 0
	min_tox = 0
	max_tox = 1
	min_co2 = 0
	max_co2 = 5
	min_n2 = 0
	max_n2 = 0
	unsuitable_atoms_damage = 15
	var/corpse = /mob/living/carbon/human/corpse
	var/weapon1 = /obj/item/weapon/material/sword/cutlass

	faction = "pirate"

/mob/living/simple_animal/hostile/pirate/New()
	..()
	var/icon_pick = pick("piratemelee","piratemelee1","piratemelee2")
	icon_living = icon_pick
	icon_state = icon_pick

/*
/mob/living/simple_animal/hostile/pirate/ranged
	name = "Pirate Gunner"
	icon_state = "pirateranged"
	icon_living = "pirateranged"
	icon_dead = "piratemelee_dead"
	projectilesound = 'sound/weapons/laser.ogg'
	ranged = 1
	rapid = 1
	projectiletype = /obj/item/projectile/beam
	corpse = /obj/effect/landmark/mobcorpse/pirate/ranged
	weapon1 = /obj/item/weapon/gun/energy/laser

*/
/mob/living/simple_animal/hostile/pirate/death()
	..()
	if(corpse)
		new corpse (src.loc)
	if(weapon1)
		new weapon1 (src.loc)
	qdel(src)
	return