/mob/living/simple_animal/parrot
	name = "parrot"
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
	granivore = 1
	behaviour = "wander"
///////////////////////////////////////CHICKENS////////////////////////

/mob/living/simple_animal/chick
	name = "\improper chick"
	desc = "Adorable! They make such a racket though."
	icon_state = "chick"
	icon_living = "chick"
	icon_dead = "chick_dead"
	icon_gib = "chick_gib"
	speak = list("Cherp.","Cherp?","Chirrup.","Cheep!")
	speak_emote = list("cheeps")
	emote_hear = list("cheeps")
	emote_see = list("pecks at the ground","flaps its tiny wings")
	speak_chance = 2
	move_to_delay = 2
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
	granivore = 1
	behaviour = "wander"
	has_fat =  FALSE

/mob/living/simple_animal/chick/New()
	..()
	pixel_x = rand(-6, 6)
	pixel_y = rand(0, 10)
	chicken_count |= src

/mob/living/simple_animal/chick/Life()
	. =..()
	if (!.)
		return
	if (!stat)
		amount_grown += 1
		if (amount_grown >= 250)
			new /mob/living/simple_animal/chicken(loc)
			qdel(src)

/mob/living/simple_animal/chick/death()

	chicken_count &= src
	..()
/mob/living/simple_animal/chick/Destroy()

	chicken_count &= src
	..()
/mob/living/simple_animal/chicken
	name = "\improper chicken"
	desc = "Hopefully the eggs are good this season."
	icon_state = "brownhen"
	icon_living = "brownhen"
	icon_dead = "brownhen_dead"
	speak = list("Cluck!","BWAAAAARK BWAK BWAK BWAK!","Bwaak bwak.")
	speak_emote = list("clucks","croons")
	emote_hear = list("clucks")
	emote_see = list("pecks at the ground","flaps its wings viciously")
	speak_chance = 2
	move_to_delay = 3
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/meat
	meat_amount = 2
	response_help  = "pets"
	response_disarm = "gently pushes aside"
	response_harm   = "kicks"
	attacktext = "kicked"
	health = 10
	eggsleft = 5
	var/roosting_icon = "brownhen_roosting"
	var/body_color
	var/egg_timer = FALSE
	pass_flags = PASSTABLE
	mob_size = MOB_SMALL
	granivore = 1
	behaviour = "wander"
	wandersounds = list('sound/animals/bird/chicken_1.ogg','sound/animals/bird/chicken_2.ogg')

/mob/living/simple_animal/chicken/New()
	..()
	if (!body_color)
		body_color = pick( list("brown","black","white","grey") )
	icon_state = "[body_color]hen"
	icon_living = "[body_color]hen"
	roosting_icon = "[body_color]hen_roosting"
	icon_dead = "[body_color]hen_dead"
	pixel_x = rand(-6, 6)
	pixel_y = rand(0, 10)
	chicken_count |= src

/mob/living/simple_animal/chicken/death()

	chicken_count &= src
	..()
/mob/living/simple_animal/chicken/Destroy()

	chicken_count &= src
	..()
/mob/living/simple_animal/chicken/Life()
	. =..()
	if (!.)
		return
	if (!stat)
		egg_timer += 1
		if (egg_timer >= 120)
			if (!stat && eggsleft > 0)
				visible_message("[src] [pick("lays an egg.","squats down and croons.","begins making a huge racket.","begins clucking raucously.")]")
				stop_automated_movement = TRUE
				icon_state = roosting_icon
				icon_living = roosting_icon
				update_icons()
				spawn(250)
					icon_state = "[body_color]hen"
					icon_living = "[body_color]hen"
					update_icons()
				eggsleft--
				egg_timer = 0
				var/obj/item/weapon/reagent_containers/food/snacks/egg/E = new(get_turf(src))
				E.pixel_x = rand(-6,6)
				E.pixel_y = rand(-6,6)

/obj/item/weapon/reagent_containers/food/snacks/egg/New()
	..()
	var/malearound = FALSE
	var/nearbyObjects = range(3,src) //3x3 area around chicken
	for(var/mob/living/simple_animal/rooster/M in nearbyObjects)
		if (M.stat == CONSCIOUS)
			malearound = TRUE
	if (malearound)
		var/chickenCount = 0
		for(var/mob/living/simple_animal/chicken/M in nearbyObjects)
			chickenCount++

		for(var/mob/living/simple_animal/chick/M in nearbyObjects)
			chickenCount++

		if (chickenCount <= 5 && growing == FALSE) // max 5 chickens/chicks in a 5x5 area for eggs to start hatching
			growing = TRUE
			grow()

/obj/item/weapon/reagent_containers/food/snacks/egg/proc/grow()
	if (isturf(loc) && chicken_count.len < 50)
		amount_grown += 1
		if (amount_grown >= 400)
			visible_message("[src] hatches with a quiet cracking sound.")
			new /mob/living/simple_animal/chick(get_turf(src))
			processing_objects -= src
			qdel(src)
			return
		else
			spawn(40)
				grow()

	else
		processing_objects -= src
		return

/mob/living/simple_animal/rooster
	name = "\improper rooster"
	desc = "Hopefully the eggs are good this season."
	icon_state = "brownrooster"
	icon_living = "brownrooster"
	icon_dead = "brownrooster_dead"
	speak = list("Cluck!","BWAAAAARK BWAK BWAK BWAK!","Cock-a-doodle-doo!")
	speak_emote = list("clucks","croons")
	emote_hear = list("clucks")
	emote_see = list("pecks at the ground","flaps its wings viciously")
	speak_chance = 2
	move_to_delay = 3
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/meat
	meat_amount = 2
	response_help  = "pets"
	response_disarm = "gently pushes aside"
	response_harm   = "kicks"
	attacktext = "kicked"
	health = 15
	var/roosting_icon = "brownrooster_roosting"
	var/body_color
	var/egg_timer = FALSE
	pass_flags = PASSTABLE
	mob_size = MOB_SMALL
	granivore = 1
	behaviour = "wander"
	wandersounds = list('sound/animals/bird/chicken_1.ogg','sound/animals/bird/chicken_2.ogg')
	var/announced_day = TRUE
/mob/living/simple_animal/rooster/Life()
	..()
	if (time_of_day == "Early Morning" && !announced_day)
		playsound(src, 'sound/animals/bird/rooster.ogg', 60)
		announced_day = TRUE
	else if (time_of_day != "Early Morning" && announced_day)
		announced_day = FALSE
/mob/living/simple_animal/rooster/New()
	..()
	if (!body_color)
		body_color = pick( list("brown","black","white","grey") )
	icon_state = "[body_color]rooster"
	icon_living = "[body_color]rooster"
	roosting_icon = "[body_color]rooster_roosting"
	icon_dead = "[body_color]rooster_dead"
	pixel_x = rand(-6, 6)
	pixel_y = rand(0, 10)
	chicken_count |= src

/mob/living/simple_animal/rooster/death()

	chicken_count &= src
	..()
/mob/living/simple_animal/rooster/Destroy()

	chicken_count &= src
	..()
////////////////////////////////////////TURKEYS//////////////////////
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
	move_to_delay = 3
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/meat
	meat_amount = 3
	response_help  = "pets"
	response_disarm = "gently pushes aside"
	response_harm   = "kicks"
	attacktext = "kicked"
	health = 12
	pass_flags = PASSTABLE
	mob_size = MOB_MEDIUM
	eggsleft = 5
	var/egg_timer = FALSE
	granivore = 1
	behaviour = "wander"
	wandersounds = list('sound/animals/turkey/turkey_1.ogg','sound/animals/turkey/turkey_2.ogg','sound/animals/turkey/turkey_3.ogg')

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
	move_to_delay = 3
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
	granivore = 1
	behaviour = "wander"
	wandersounds = list('sound/animals/turkey/turkey_1.ogg','sound/animals/turkey/turkey_2.ogg','sound/animals/turkey/turkey_3.ogg')

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
	move_to_delay = 3
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
	granivore = 1
	behaviour = "defends"
	melee_damage_lower = 3
	melee_damage_upper = 7

/mob/living/simple_animal/pelican
	name = "\improper pelican"
	desc = "A common sea bird."
	icon_state = "pelican-filled"
	icon_living = "pelican-filled"
	icon_dead = "pelican_dead"
	speak = list("GRUNT!","KRRR KRRR!")
	speak_emote = list("gruntss","hisses")
	emote_hear = list("grunts")
	emote_see = list("pecks at the ground","flaps its wings viciously")
	speak_chance = 2
	move_to_delay = 3
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
	granivore = 1
	behaviour = "defends"
	melee_damage_lower = 3
	melee_damage_upper = 7

/mob/living/simple_animal/seagull
	name = "\improper seagull"
	desc = "A common sea bird."
	icon_state = "gull"
	icon_living = "gull"
	icon_dead = "gull-dead"
	speak = list("squak!","SQUAK SQUAK!")
	speak_emote = list("squaks")
	emote_hear = list("squaks")
	emote_see = list("pecks at the ground","flaps its wings viciously")
	speak_chance = 2
	move_to_delay = 3
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
	granivore = 1
	scavenger = 1
	behaviour = "wander"
	melee_damage_lower = 2
	melee_damage_upper = 4

/mob/living/simple_animal/crow
	name = "\improper crow"
	desc = "A common scavenger bird."
	icon_state = "crow"
	icon_living = "crow"
	icon_dead = "crow_dead"
	speak = list("caw caw!","CA-CAW CA-CAW!")
	speak_emote = list("caws")
	emote_hear = list("caws")
	emote_see = list("pecks at the ground","flaps its wings viciously")
	speak_chance = 2
	move_to_delay = 3
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
	granivore = 1
	carnivore = 1
	scavenger = 1
	density = 0
	behaviour = "scared"
	melee_damage_lower = 3
	melee_damage_upper = 7
	wandersounds = list('sound/animals/bird/crow_1.ogg','sound/animals/bird/crow_2.ogg','sound/animals/bird/crow_3.ogg')

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
	move_to_delay = 2
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
	granivore = 1
	behaviour = "wanders"

/mob/living/simple_animal/turkeychick/New()
	..()
	pixel_x = rand(-6, 6)
	pixel_y = rand(0, 10)
	turkey_count |= src

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
	turkey_count |= src

/mob/living/simple_animal/turkey_m/death()

	turkey_count &= src
	..()
/mob/living/simple_animal/turkey_m/Destroy()

	turkey_count &= src
	..()
/mob/living/simple_animal/turkey_f/New()
	..()
	turkey_count |= src

/mob/living/simple_animal/turkey_f/death()

	turkey_count &= src
	..()
/mob/living/simple_animal/turkey_f/Destroy()

	turkey_count &= src
	..()
/mob/living/simple_animal/turkeychick/death()

	turkey_count &= src
	..()
/mob/living/simple_animal/turkeychick/Destroy()

	turkey_count &= src
	..()
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

/obj/item/weapon/reagent_containers/food/snacks/turkeyegg/proc/grow()
	if (isturf(loc) && turkey_count.len < 35)
		amount_grown += 1
		if (amount_grown >= 400)
			visible_message("[src] hatches with a quiet cracking sound.")
			new /mob/living/simple_animal/turkeychick(get_turf(src))
			processing_objects -= src
			qdel(src)
			return
		else
			spawn(50)
				grow()
	else
		processing_objects -= src
		return
/obj/item/weapon/reagent_containers/food/snacks/turkeyegg/New()
	..()
	var/malearound = FALSE
	var/nearbyObjects = range(3,src) //3x3 area around turkey
	for(var/mob/living/simple_animal/turkey_m/M in nearbyObjects)
		if (M.stat == CONSCIOUS)
			malearound = TRUE
	if (malearound)
		var/nearbyObjects1 = range(2,src) //5x5 area
		var/turkeyCount = 0
		for(var/mob/living/simple_animal/turkey_m/M in nearbyObjects1)
			turkeyCount++

		for(var/mob/living/simple_animal/turkey_f/M in nearbyObjects1)
			turkeyCount++

		for(var/mob/living/simple_animal/turkeychick/M in nearbyObjects1)
			turkeyCount++

		if (turkeyCount <= 5 && growing == FALSE) // max 5 turkeys/chicks in a 5x5 area for eggs to start hatching
			growing = TRUE
			grow()
