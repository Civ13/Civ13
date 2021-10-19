/mob/living/simple_animal/deer
	name = "stag"
	desc = "Provides some nice meat, if you can catch it."
	icon_state = "deer_m"
	icon_living = "deer_m"
	icon_dead = "deer_m_dead"
	icon_gib = "deer_m_dead"
	speak = list("rrrw","meew","MEEEW")
	speak_emote = list("bellows","bleats")
	emote_hear = list("bellows")
	emote_see = list("shakes its head", "looks attently")
	speak_chance = TRUE
	move_to_delay = 2
	see_in_dark = 8
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/meat
	meat_amount = 5
	response_help  = "pets"
	response_disarm = "gently pushes aside"
	response_harm   = "kicks"
	attacktext = "kicked"
	health = 50
	mob_size = MOB_LARGE
	var/babydeer = FALSE
	behaviour = "scared"
	herbivore = 1
	var/pregnant = FALSE
	var/birthCountdown = 0
	var/overpopulationCountdown = 0
	var/female = FALSE

	melee_damage_lower = 6
	melee_damage_upper = 12
	wandersounds = list('sound/animals/deer/deer_bleat_1.ogg','sound/animals/deer/deer_bleat_2.ogg','sound/animals/deer/deer_bleat_3.ogg')

/mob/living/simple_animal/deer/male
	name = "stag"
	desc = "Provides some nice meat, if you can catch it."
	icon_state = "deer_m"
	icon_living = "deer_m"
	icon_dead = "deer_m_dead"
	icon_gib = "deer_m_dead"


/mob/living/simple_animal/deer/female
	name = "doe"
	icon_state = "deer_f"
	icon_living = "deer_f"
	icon_dead = "deer_f_dead"
	icon_gib = "deer_f_dead"
	female = TRUE

/mob/living/simple_animal/deer/death()

	deer_count &= src
	..()
/mob/living/simple_animal/deer/Destroy()

	deer_count &= src
	..()
/mob/living/simple_animal/deer/New()
	deer_count |= src
	..()
	spawn(1)
		if (babydeer)
			icon_state = "babydeer"
			icon_living = "babydeer"
			icon_dead = "babydeer_dead"
			meat_amount = 1
			mob_size = MOB_SMALL
			spawn(3000)
				if (female)
					babydeer = FALSE
					icon_state = "deer_f"
					icon_living = "deer_f"
					icon_dead = "deer_f_dead"
					mob_size = MOB_LARGE
				else
					babydeer = FALSE
					icon_state = "deer_m"
					icon_living = "deer_m"
					icon_dead = "deer_m_dead"
					mob_size = MOB_LARGE


/mob/living/simple_animal/deer/Life()
	..()
	if (female)
		if (overpopulationCountdown > 0) //don't do any checks while overpopulation is in effect
			overpopulationCountdown--
			return

		if (!pregnant && deer_count.len < 30)
			var/nearbyObjects = range(1,src) //3x3 area around the deer
			for(var/mob/living/simple_animal/deer/male/M in nearbyObjects)
				if (M.stat == CONSCIOUS)
					pregnant = TRUE
					birthCountdown = 600
					break

			if (pregnant)
				nearbyObjects = range(7,src) //15x15 area around the deer
				var/deerCount = 0
				for(var/mob/living/simple_animal/deer/female/M in nearbyObjects)
					if (M.stat == CONSCIOUS)
						deerCount++

				for(var/mob/living/simple_animal/deer/male/M in nearbyObjects)
					if (M.stat == CONSCIOUS)
						deerCount++

				if (deerCount > 5) // max 5 deers in a 15x15 area around deer
					overpopulationCountdown = 300
					pregnant = FALSE
		else if (pregnant)
			birthCountdown--
			if (birthCountdown <= 0)
				pregnant = FALSE
				if (prob(50))
					var/mob/living/simple_animal/deer/female/C = new/mob/living/simple_animal/deer/female(loc)
					C.babydeer = TRUE
				else
					var/mob/living/simple_animal/deer/male/B = new/mob/living/simple_animal/deer/male(loc)
					B.babydeer = TRUE
				visible_message("A deer has been born!")

/mob/living/simple_animal/deer/reindeer/male
	name = "reindeer stag"
	desc = "Provides some nice meat, if you can catch it."
	icon_state = "reindeer_m"
	icon_living = "reindeer_m"
	icon_dead = "reindeer_m_dead"
	icon_gib = "reindeer_m_dead"
	speak = list("rrrw","meew","MEEEW")
	speak_emote = list("bellows","bleats")
	emote_hear = list("bellows")
	emote_see = list("shakes its head", "looks attently")
	speak_chance = TRUE
	move_to_delay = 2
	see_in_dark = 8
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/meat
	meat_amount = 5
	var/babyreindeer = FALSE
	health = 50
	mob_size = MOB_LARGE
	female = FALSE

/mob/living/simple_animal/deer/reindeer/female
	name = "reindeer doe"
	icon_state = "reindeer_f"
	icon_living = "reindeer_f"
	icon_dead = "reindeer_f_dead"
	icon_gib = "reindeer_f_dead"
	mob_size = MOB_LARGE
	female = TRUE

/mob/living/simple_animal/deer/elk/male
	name = "elk stag"
	desc = "Provides some nice meat, if you can catch it."
	icon_state = "elk_m"
	icon_living = "elk_m"
	icon_dead = "elk_m_dead"
	icon_gib = "elk_m_dead"
	speak = list("Qeeeeeeeel","Ei'Il")
	speak_emote = list("bellows","bleats")
	emote_hear = list("bellows")
	emote_see = list("shakes its head", "looks attently")
	speak_chance = TRUE
	move_to_delay = 2
	see_in_dark = 8
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/meat
	meat_amount = 6
	health = 80
	female = FALSE

/mob/living/simple_animal/deer/elk/female
	name = "elk doe"
	icon_state = "elk_f"
	icon_living = "elk_f"
	icon_dead = "elk_f_dead"
	icon_gib = "elk_f_dead"

	female = TRUE

/mob/living/simple_animal/deer/dikdik/male
	name = "dik-dik stag"
	desc = "A small little mammal seems kinda cute, might be good eating if you can catch it."
	icon_state = "dikdik_male"
	icon_living = "dikdik_male"
	icon_dead = "dikdik_dead"
	icon_gib = "dikdik_dead"
	speak = list("ssssceeeee","Shhhhk","Szzzzzzeeee")
	speak_emote = list("shrillss","whistless")
	emote_hear = list("shrills")
	emote_see = list("shakes its head", "looks attently")
	speak_chance = TRUE
	move_to_delay = 1.5
	see_in_dark = 8
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/meat
	meat_amount = 3
	var/babydikdikdeer = FALSE
	health = 45
	mob_size = MOB_SMALL
	female = FALSE

/mob/living/simple_animal/deer/dikdik/female
	name = "dik-dik doe"
	icon_state = "dikdik_female"
	icon_living = "dikdik_female"
	icon_dead = "reindeer_f_dead"
	icon_gib = "reindeer_f_dead"
	mob_size = MOB_SMALL
	female = TRUE

/mob/living/simple_animal/deer/dikdik/New()
	deer_count |= src
	..()
	spawn(1)
		if (babydeer)
			icon_state = "babydikdik"
			icon_living = "babydikdik"
			icon_dead = "dikdik_dead"
			meat_amount = 1
			mob_size = MOB_SMALL
			spawn(3000)
				if (female)
					babydeer = FALSE
					icon_state = "dikdik_female"
					icon_living = "dikdik_female"
					icon_dead = "dikdik_dead"
					mob_size = MOB_SMALL
				else
					babydeer = FALSE
					icon_state = "dikdik_male"
					icon_living = "dikdik_male"
					icon_dead = "dikdik_dead"
					mob_size = MOB_SMALL


/mob/living/simple_animal/deer/dikdik/Life()
	..()
	if (female)
		if (overpopulationCountdown > 0) //don't do any checks while overpopulation is in effect
			overpopulationCountdown--
			return

		if (!pregnant && deer_count.len < 30)
			var/nearbyObjects = range(1,src) //3x3 area around the deer
			for(var/mob/living/simple_animal/deer/dikdik/male/M in nearbyObjects)
				if (M.stat == CONSCIOUS)
					pregnant = TRUE
					birthCountdown = 600
					break

			if (pregnant)
				nearbyObjects = range(7,src) //15x15 area around the deer
				var/deerCount = 0
				for(var/mob/living/simple_animal/deer/dikdik/female/M in nearbyObjects)
					if (M.stat == CONSCIOUS)
						deerCount++

				for(var/mob/living/simple_animal/deer/dikdik/male/M in nearbyObjects)
					if (M.stat == CONSCIOUS)
						deerCount++

				if (deerCount > 5) // max 5 deers in a 15x15 area around deer
					overpopulationCountdown = 300
					pregnant = FALSE
		else if (pregnant)
			birthCountdown--
			if (birthCountdown <= 0)
				pregnant = FALSE
				if (prob(50))
					var/mob/living/simple_animal/deer/dikdik/female/C = new/mob/living/simple_animal/deer/dikdik/female(loc)
					C.babydeer = TRUE
				else
					var/mob/living/simple_animal/deer/dikdik/male/B = new/mob/living/simple_animal/deer/dikdik/male(loc)
					B.babydeer = TRUE
				visible_message("A dik-dik has been born!")