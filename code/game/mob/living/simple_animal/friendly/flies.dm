//not really a subtype of hostile animals, but it is harmful so it goes here.
/mob/living/simple_animal/fly
	name = "flies"
	desc = "Annoying and dirty."
	icon = 'icons/mob/critter.dmi'
	icon_state = "flies"
	icon_living = "flies"
	icon_dead = "blank"
	icon_gib = "blank"
	speak = list("bzzzz","zzzzzzz")
	emote_see = list("buzz around", "fly around")
	speak_chance = TRUE
	move_to_delay = 3
	see_in_dark = 9
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/meat
	meat_amount = 0
	response_help  = "waves"
	response_disarm = "waves"
	response_harm   = "slaps"
	attacktext = "bitten"
	health = 5
	maxHealth = 5
	mob_size = MOB_MINISCULE
	stop_automated_movement_when_pulled = FALSE
	stop_automated_movement = TRUE
	wander = FALSE
	density = FALSE
	layer = 4.1
	scavenger = 1
/mob/living/simple_animal/fly/New()
	..()
	spawn(6000)
		stat = DEAD
		qdel(src)

/mob/living/simple_animal/fly/Life()
	..()
	if (stat != DEAD)
		walk_rand(src,4)

/mob/living/simple_animal/fly/bullet_act(var/obj/item/projectile/Proj)
	return

/mob/living/simple_animal/fly/attack_hand(mob/living/human/M as mob)
	M.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
	visible_message("[M] swats away the [src]!","You swat away the [src]!")
	if (prob(40))
		walk_away(src, M, 3, 3)
		return
	if (prob(10))
		if (origin)
			var/obj/structure/sink/S = origin
			S.mosquito_count--
		qdel(src)
		return

/mob/living/simple_animal/fly/attackby(var/obj/item/O, var/mob/user)
	if (istype(O, /obj/item/weapon/swatter/modern))
		if (prob(75))
			visible_message("[user] swats \the [src] with \the [O]!")
			if (origin)
				var/obj/structure/sink/S = origin
				S.mosquito_count--
			qdel(src)
			return
		else
			visible_message("[user] misses \the [src]!")
			return
	else if (istype(O, /obj/item/weapon/swatter))
		if (prob(30))
			visible_message("[user] swats \the [src] with \the [O]!")
			if (origin)
				var/obj/structure/sink/S = origin
				S.mosquito_count--
			qdel(src)
			return
		else
			visible_message("[user] misses \the [src]!")
			return
	else
		return

/obj/structure/curtain/Crossed(var/mob/living/simple_animal/fly/M)
	if (icon_state != "open" && istype(M, /mob/living/simple_animal/fly))
		walk(M,0)
		walk(M,turn(dir,180),3)
	else
		..()