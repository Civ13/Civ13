
/mob/living/simple_animal/hostile/wolf
	name = "grey wolf"
	desc = "Better start running..."
	icon_state = "greywolf"
	icon_living = "greywolf"
	icon_dead = "greywolf_dead"
	icon_gib = "greywolf_gib"
	speak = list("GRRR!","Wooh!","Wuuh!","HUUUUU!")
	speak_emote = list("growls", "howls")
	emote_hear = list("growls","howls","whimps")
	emote_see = list("stares ferociously", "sniffs the ground")
	speak_chance = TRUE
	move_to_delay = 3
	see_in_dark = 1
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/meat
	response_help  = "pets"
	response_disarm = "gently pushes aside"
	response_harm   = "pokes"
	stop_automated_movement_when_pulled = FALSE
	maxHealth = 80
	health = 80
	melee_damage_lower = 6
	melee_damage_upper = 12
	mob_size = MOB_MEDIUM
	predatory_carnivore = 1
	carnivore = 1
	fat_penalty = 1


	var/btype = "grey"
	var/cub = FALSE
	var/growing = FALSE
	var/female = FALSE
	faction = "neutral"
	var/pregnant = FALSE
	var/birthCountdown = 0
	var/overpopulationCountdown = 0

/mob/living/simple_animal/hostile/wolf/female
	name = "grey she-wolf"
	female = TRUE

/mob/living/simple_animal/hostile/wolf/death()

	wolf_count &= src
	..()
/mob/living/simple_animal/hostile/wolf/Destroy()

	wolf_count &= src
	..()
/mob/living/simple_animal/hostile/wolf/New()
	wolf_count |= src
	if (female)
		name = "[btype] wolf"
	else
		name = "[btype] she-wolf"
	..()

/mob/living/simple_animal/hostile/wolf/Life()
	..()
	if(src.cub && !src.growing)
		growing = TRUE //No need to set it all again if its already growing
		icon_state = "[btype]wolf_cub"
		icon_living = "[btype]wolf_cub"
		icon_dead = "[btype]wolf_dead"
		meat_amount = 1
		mob_size = MOB_SMALL
		if (female)
			name = "female [btype] wolf cub"
		else
			name = "male [btype] wolf cub"
		spawn(4500)
			cub = FALSE
			growing = FALSE
			icon_state = "[btype]wolf"
			icon_living = "[btype]wolf"
			icon_dead = "[btype]wolf_dead"
			mob_size = MOB_MEDIUM
			if (female)
				name = "[btype] she-wolf"
			else
				name = "[btype] she-wolf"

	if(!src.following_mob)
		src.do_behaviour()
	if (src.female && !src.pregnant)
		if(!src.cub) //Cubs cant get pregnant
			var/nearbyObjects = range(1,src) //3x3 area around animal
			for(var/mob/living/simple_animal/hostile/wolf/M in nearbyObjects)
				if (M.stat == CONSCIOUS && !M.female) //Failsafe, no misscheck for self-reproduction
					pregnant = TRUE
					birthCountdown = 900 // life ticks once per 2 seconds, 300 == 10 minutes
	else if (src.female && src.pregnant)
		birthCountdown--
		if (birthCountdown <= 0)
			pregnant = FALSE
			if (prob(50))
				var/mob/living/simple_animal/hostile/wolf/C = new/mob/living/simple_animal/hostile/wolf(loc)
				C.cub = TRUE
				C.btype = btype
			else
				var/mob/living/simple_animal/hostile/wolf/female/B = new/mob/living/simple_animal/hostile/wolf/female(loc)
				B.cub = TRUE
				B.btype = btype
			visible_message("A wolf cub has been born!")

/mob/living/simple_animal/hostile/wolf/white
	name = "white wolf"
	icon_state = "whitewolf"
	icon_living = "whitewolf"
	icon_dead = "whitewolf_dead"
	icon_gib = "whitewolf_gib"
	btype = "white"

/mob/living/simple_animal/hostile/wolf/white/female
	name = "white she-wolf"
	female = TRUE