/mob/living/simple_animal/parrot
	name = "Parrot"
	desc = "A parrot. Maybe it can sit on your shoulder?."
	icon = 'icons/mob/animal.dmi'
	icon_state = "parrot_sit"
	icon_living = "parrot_sit"
	icon_dead = "parrot_dead"
	speak_emote = list("squawks")
	health = 25
	maxHealth = 25
	attacktext = "bitten"
	melee_damage_lower = 2
	melee_damage_upper = 5
	response_help  = "pets"
	response_disarm = "shoos"
	response_harm   = "hits"
	meat_amount = 2
	mob_size = MOB_SMALL
	possession_candidate = TRUE

/mob/living/simple_animal/turkey_f
	name = "\improper turkey"
	desc = "A common american animal. Good for meat."
	icon_state = "turkey-hen"
	icon_living = "turkey-hen"
	icon_dead = "turkey-hen-dead"
	speak = list("Cluck!","Gluglugluglu!","GLU GLU.")
	speak_emote = list("clucks","gubles")
	emote_hear = list("gubles")
	emote_see = list("pecks at the ground","flaps its wings viciously")
	speak_chance = 2
	turns_per_move = 3
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/meat
	meat_amount = 3
	response_help  = "pets"
	response_disarm = "gently pushes aside"
	response_harm   = "kicks"
	attacktext = "kicked"
	health = 12
	pass_flags = PASSTABLE
	mob_size = MOB_MEDIUM
	var/eggsleft = 5
	var/egg_timer = FALSE

/mob/living/simple_animal/turkey_m
	name = "\improper turkey"
	desc = "A common american animal. Good for meat."
	icon_state = "turkey-tom"
	icon_living = "turkey-tom"
	icon_dead = "turkey-tom-dead"
	speak = list("Cluck!","Gluglugluglu!","GLU GLU.")
	speak_emote = list("clucks","gubles")
	emote_hear = list("gubles")
	emote_see = list("pecks at the ground","flaps its wings viciously")
	speak_chance = 2
	turns_per_move = 3
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/meat
	meat_amount = 3
	response_help  = "pets"
	response_disarm = "gently pushes aside"
	response_harm   = "kicks"
	attacktext = "kicked"
	health = 12
	harm_intent_damage = 4
	pass_flags = PASSTABLE
	mob_size = MOB_MEDIUM

/mob/living/simple_animal/goose
	name = "\improper goose"
	desc = "A common american migratory bird. Quite dangerous."
	icon_state = "goose"
	icon_living = "goose"
	icon_dead = "goose-dead"
	speak = list("HONK!","SSSS!","HONK HONK HONK!")
	speak_emote = list("honks","hisses")
	emote_hear = list("honks")
	emote_see = list("pecks at the ground","flaps its wings viciously")
	speak_chance = 2
	turns_per_move = 3
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/meat
	meat_amount = 3
	response_help  = "pets"
	response_disarm = "gently pushes aside"
	response_harm   = "kicks"
	attacktext = "kicked"
	health = 12
	harm_intent_damage = 7
	pass_flags = PASSTABLE
	mob_size = MOB_MEDIUM


/mob/living/simple_animal/turkeychick
	name = "\improper turkey chick"
	desc = "Adorable! They make such a racket though."
	icon_state = "turkey-chick"
	icon_living = "turkey-chick"
	icon_dead = "turkey-chick-dead"
	icon_gib = "chick_gib"
	speak = list("Cherp.","Cherp?","Chirrup.","Cheep!")
	speak_emote = list("cheeps")
	emote_hear = list("cheeps")
	emote_see = list("pecks at the ground","flaps its tiny wings")
	speak_chance = 2
	turns_per_move = 2
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/meat
	meat_amount = TRUE
	response_help  = "pets"
	response_disarm = "gently pushes aside"
	response_harm   = "kicks"
	attacktext = "kicked"
	health = TRUE
	var/amount_grown = FALSE
	pass_flags = PASSTABLE
	mob_size = MOB_MINISCULE

/mob/living/simple_animal/turkeychick/New()
	..()
	pixel_x = rand(-6, 6)
	pixel_y = rand(0, 10)

/mob/living/simple_animal/turkeychick/Life()
	. =..()
	if (!.)
		return
	if (!stat)
		amount_grown += 1
		if (amount_grown >= 250)
			if (prob(50))
				new /mob/living/simple_animal/turkey_m(loc)
			else
				new /mob/living/simple_animal/turkey_f(loc)
			qdel(src)

/mob/living/simple_animal/turkey_m/New()
	..()
	turkey_count += 1

/mob/living/simple_animal/turkey_m/death()
	..()
	turkey_count -= 1
/mob/living/simple_animal/turkey_f/New()
	..()
	turkey_count += 1

/mob/living/simple_animal/turkey_f/death()
	..()
	turkey_count -= 1

/mob/living/simple_animal/turkeychick/death()
	..()
	turkey_count -= 1

/mob/living/simple_animal/turkey_f/Life()
	. =..()
	if (!.)
		return
	if (!stat)
		egg_timer += 1
		if (egg_timer >= 120)
			if (!stat && eggsleft > 0)
				visible_message("[src] [pick("lays an egg.","squats down and croons.","begins making a huge racket.","begins clucking raucously.")]")
				eggsleft--
				egg_timer = 0
				var/obj/item/weapon/reagent_containers/food/snacks/turkeyegg/E = new(get_turf(src))
				E.pixel_x = rand(-6,6)
				E.pixel_y = rand(-6,6)
				var/malearound = FALSE
				var/nearbyObjects = range(1,src) //3x3 area around cow
				for(var/mob/living/simple_animal/turkey_m/M in nearbyObjects)
					if (M.stat == CONSCIOUS)
						malearound = TRUE
				if (prob(20) && malearound)
					var/nearbyObjects1 = range(2,src) //5x5 area
					var/turkeyCount = 0
					for(var/mob/living/simple_animal/turkey_m/M in nearbyObjects1)
						turkeyCount++

					for(var/mob/living/simple_animal/turkey_f/M in nearbyObjects1)
						turkeyCount++

					for(var/mob/living/simple_animal/turkeychick/M in nearbyObjects1)
						turkeyCount++

					if (turkeyCount <= 5) // max 5 chickens/chicks in a 5x5 area for eggs to start hatching
						processing_objects.Add(E)

/obj/item/weapon/reagent_containers/food/snacks/turkeyegg/process()
	if (isturf(loc) && turkey_count < 35)
		turkey_count++
		amount_grown += 1
		if (amount_grown >= 400)
			visible_message("[src] hatches with a quiet cracking sound.")
			new /mob/living/simple_animal/turkeychick(get_turf(src))
			processing_objects.Remove(src)
			qdel(src)
			return
		else
			spawn(40)
				process()
	else
		processing_objects.Remove(src)
		return
