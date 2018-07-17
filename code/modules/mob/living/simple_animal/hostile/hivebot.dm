/obj/item/projectile/hivebotbullet
	damage = 10
	damage_type = BRUTE

/mob/living/simple_animal/hostile/hivebot
	name = "Hivebot"
	desc = "A small robot"
	icon = 'icons/mob/hivebot.dmi'
	icon_state = "basic"
	icon_living = "basic"
	icon_dead = "basic"
	health = 15
	maxHealth = 15
	melee_damage_lower = 2
	melee_damage_upper = 3
	attacktext = "clawed"
	projectilesound = 'sound/weapons/Gunshot.ogg'
	projectiletype = /obj/item/projectile/hivebotbullet
	faction = "hivebot"
	min_oxy = FALSE
	max_oxy = FALSE
	min_tox = FALSE
	max_tox = FALSE
	min_co2 = FALSE
	max_co2 = FALSE
	min_n2 = FALSE
	max_n2 = FALSE
	minbodytemp = FALSE
	speed = 4

/mob/living/simple_animal/hostile/hivebot/range
	name = "Hivebot"
	desc = "A smallish robot, this one is armed!"
	ranged = TRUE

/mob/living/simple_animal/hostile/hivebot/rapid
	ranged = TRUE
	rapid = TRUE

/mob/living/simple_animal/hostile/hivebot/strong
	name = "Strong Hivebot"
	desc = "A robot, this one is armed and looks tough!"
	health = 80
	ranged = TRUE


/mob/living/simple_animal/hostile/hivebot/death()
	..()
	visible_message("<b>[src]</b> blows apart!")
	new /obj/effect/decal/cleanable/blood/gibs/robot(loc)
	var/datum/effect/effect/system/spark_spread/s = new /datum/effect/effect/system/spark_spread
	s.set_up(3, TRUE, src)
	s.start()
	qdel(src)
	return

/mob/living/simple_animal/hostile/hivebot/tele//this still needs work
	name = "Beacon"
	desc = "Some odd beacon thing"
	icon = 'icons/mob/hivebot.dmi'
	icon_state = "def_radar-off"
	icon_living = "def_radar-off"
	health = 200
	maxHealth = 200
	status_flags = FALSE
	anchored = TRUE
	stop_automated_movement = TRUE
	var/bot_type = "norm"
	var/bot_amt = 10
	var/spawn_delay = 600
	var/turn_on = FALSE
	var/auto_spawn = TRUE
	proc
		warpbots()


	New()
		..()
		var/datum/effect/effect/system/smoke_spread/smoke = new /datum/effect/effect/system/smoke_spread()
		smoke.set_up(5, FALSE, loc)
		smoke.start()
		visible_message("<span class = 'red'><b>The [src] warps in!</b></span>")
		playsound(loc, 'sound/effects/EMPulse.ogg', 25, TRUE)

	warpbots()
		icon_state = "def_radar"
		visible_message("<span class = 'red'>The [src] turns on!</span>")
		while(bot_amt > 0)
			bot_amt--
			switch(bot_type)
				if("norm")
					new /mob/living/simple_animal/hostile/hivebot(get_turf(src))
				if("range")
					new /mob/living/simple_animal/hostile/hivebot/range(get_turf(src))
				if("rapid")
					new /mob/living/simple_animal/hostile/hivebot/rapid(get_turf(src))
		spawn(100)
			qdel(src)
		return


	Life()
		..()
		if(stat == FALSE)
			if(sprob(2))//Might be a bit low, will mess with it likely
				warpbots()

