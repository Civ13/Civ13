//not really a subtype of hostile animals, but it is harmful so it goes here.
/mob/living/simple_animal/vampirebatblack
	name = "vampire bat"
	desc = "It want's your blood!"
	icon = 'icons/mob/animal.dmi'
	icon_state = "vampire_bat_black"
	icon_living = "vampire_bat_black"
	icon_dead = "vampire_bat_black_dead"
	icon_gib = "vampire_bat_black_dead"
	speak = list("screech","chirps")
	emote_see = list("flaps", "swoops down")
	speak_chance = TRUE
	move_to_delay = 3
	see_in_dark = 10
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/meat
	meat_amount = 1
	response_help  = "waves"
	response_disarm = "waves"
	response_harm   = "slaps"
	attacktext = "bitten"
	health = 10
	maxHealth = 10
	mob_size = MOB_SMALL
	stop_automated_movement_when_pulled = FALSE
	stop_automated_movement = TRUE
	wander = TRUE
	density = FALSE
	layer = 4.1
	wandersounds = list('sound/animals/bat/bats_1.ogg','sound/animals/bat/bats_2.ogg','sound/animals/bat/bats_3.ogg')
	hostilesounds = list('sound/animals/bat/bats_1.ogg','sound/animals/bat/bats_2.ogg','sound/animals/bat/bats_3.ogg')

/mob/living/simple_animal/vampirebatblack/New()
	..()


/mob/living/simple_animal/vampirebatblack/Life()
	..()
	if (stat != DEAD)
		if (prob(80))
			var/done = FALSE
			for (var/mob/living/human/H in range(8, src))
				if (done == FALSE)
					walk_towards(src, H, 3)
					done = TRUE
			if (done == FALSE)
				walk_rand(src,4)
		else if (prob(20))
			var/done = FALSE
			for (var/mob/living/simple_animal/cow in range(10, src))
				if (done == FALSE)
					walk_towards(src, cow, 3)
					done = TRUE
			if (done == FALSE)
				walk_rand(src,4)
		else if (prob(20))
			var/done = FALSE
			for (var/mob/living/simple_animal/bull in range(10, src))
				if (done == FALSE)
					walk_towards(src, bull, 3)
					done = TRUE
			if (done == FALSE)
				walk_rand(src,4)
		else
			walk_rand(src,4)
		if (prob(5))
			for (var/mob/living/human/TG in range(1,src))
				visible_message("<span class = 'danger'>\The [src] bites [TG]!")
				TG.adjustBruteLoss(1,2)
				var/dmod = 1
				if (TG.find_trait("Weak Immune System"))
					dmod = 2
				if (prob(25*dmod) && TG.disease == 0)
					TG.disease_progression = 0
					TG.disease_type ="malaria"
					TG.disease = 1

/mob/living/simple_animal/vampirebatblack/bullet_act(var/obj/item/projectile/Proj)
	return