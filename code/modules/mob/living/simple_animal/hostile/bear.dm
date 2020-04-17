
/mob/living/simple_animal/hostile/bear
	name = "black bear boar"
	desc = "Rawr Rawr!!"
	icon_state = "blackbear"
	icon_living = "blackbear"
	icon_dead = "blackbear_dead"
	icon_gib = "blackbear_gib"
	speak = list("RAWR!","Rawr!","GRR!","Growl!")
	speak_emote = list("growls", "roars")
	emote_hear = list("rawrs","grumbles","grawls")
	emote_see = list("stares ferociously", "stomps")
	speak_chance = TRUE
	move_to_delay = 5
	see_in_dark = 6
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/bearmeat
	response_help  = "pets"
	response_disarm = "gently pushes aside"
	response_harm   = "pokes"
	stop_automated_movement_when_pulled = FALSE
	maxHealth = 60
	health = 60
	melee_damage_lower = 20
	melee_damage_upper = 30
	mob_size = MOB_LARGE
	predatory_carnivore = 1
	carnivore = 1
	scavenger = 1

	var/cub = FALSE

	var/btype = "black"
	var/female = FALSE
	faction = "neutral"
	var/pregnant = FALSE
	var/birthCountdown = 0
	var/overpopulationCountdown = 0

/mob/living/simple_animal/hostile/bear/female
	name = "black bear sow"
	female = TRUE

/mob/living/simple_animal/hostile/bear/death()
	if (!removed_from_list)
		removed_from_list=TRUE
		bear_count -= 1
	..()
/mob/living/simple_animal/hostile/bear/Destroy()
	if (!removed_from_list)
		removed_from_list=TRUE
		bear_count -= 1
	..()
/mob/living/simple_animal/hostile/bear/Life()
	if (overpopulationCountdown > 0) //don't do any checks while overpopulation is in effect
		overpopulationCountdown--
		return

	if (!pregnant && bear_count < 12)
		var/nearbyObjects = range(1,src) //3x3 area around animal
		for(var/mob/living/simple_animal/hostile/bear/M in nearbyObjects)
			if (M.stat == CONSCIOUS && !M.female)
				pregnant = TRUE
				birthCountdown = 600 // life ticks once per 2 seconds, 300 == 10 minutes
				break

		if (pregnant)
			nearbyObjects = range(7,src) //15x15 area around animal

			var/bearCount = 0
			for(var/mob/living/simple_animal/hostile/bear/M in nearbyObjects)
				if (M.stat == CONSCIOUS)
					bearCount++


			if (bearCount > 4) // max 5 cows/bulls in a 15x15 area around
				overpopulationCountdown = 300 // 5 minutes
				pregnant = FALSE
	else if (pregnant)
		birthCountdown--
		if (birthCountdown <= 0)
			pregnant = FALSE
			if (prob(50))
				var/mob/living/simple_animal/hostile/bear/C = new/mob/living/simple_animal/hostile/bear(loc)
				C.cub = TRUE
				C.btype = btype
			else
				var/mob/living/simple_animal/hostile/bear/female/B = new/mob/living/simple_animal/hostile/bear/female(loc)
				B.cub = TRUE
				B.btype = btype
			visible_message("A bear cub has been born!")
	..()

/mob/living/simple_animal/hostile/bear/New()
	bear_count += 1
	..()
	spawn(1)
		if (cub)
			icon_state = "[btype]bear_cub"
			icon_living = "[btype]bear_cub"
			icon_dead = "[btype]bear_cub_dead"
			meat_amount = 1
			mob_size = MOB_MEDIUM
			if (female)
				name = "female [btype] bear cub"
			else
				name = "male [btype] bear cub"
			spawn(3000)
				cub = FALSE
				icon_state = "[btype]bear"
				icon_living = "[btype]bear"
				icon_dead = "[btype]bear_dead"
				mob_size = MOB_LARGE
				if (female)
					name = "[btype] bear sow"
				else
					name = "[btype] bear boar"
		else
			if (female)
				name = "[btype] bear sow"
			else
				name = "[btype] bear boar"
			icon_state = "[btype]bear"

/mob/living/simple_animal/hostile/bear/brown
	name = "brown bear"
	icon_state = "brownbear"
	icon_living = "brownbear"
	icon_dead = "brownbear_dead"
	icon_gib = "brownbear_gib"
	btype = "brown"

/mob/living/simple_animal/hostile/bear/polar
	name = "polar bear"
	icon_state = "polarbear"
	icon_living = "polarbear"
	icon_dead = "polarbear_dead"
	icon_gib = "polarbear_gib"
	btype = "polar"