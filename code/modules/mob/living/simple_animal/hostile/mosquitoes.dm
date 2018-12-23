//not really a subtype of hostile animals, but it is harmful so it goes here.
/mob/living/simple_animal/mosquito
	name = "mosquitoes"
	desc = "Annoying and dangerous."
	icon = 'icons/mob/critter.dmi'
	icon_state = "mosquitoes1"
	icon_living = "mosquitoes1"
	icon_dead = "blank"
	icon_gib = "blank"
	speak = list("bzzzz","zzzzzzz")
	emote_see = list("buzz around", "fly around")
	speak_chance = TRUE
	turns_per_move = 1
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

/mob/living/simple_animal/mosquito/New()
	..()

/mob/living/simple_animal/mosquito/death()
	var/obj/structure/sink/S = origin
	S.mosquito_count--
	..()

/mob/living/simple_animal/mosquito/Life()
	..()
	if (stat != DEAD)
		if (prob(70))
			var/done = FALSE
			for (var/mob/living/carbon/human/H in range(6, src))
				if (done == FALSE)
					walk_towards(src, H, 3)
					done = TRUE
			if (done == FALSE)
				walk_rand(src,4)
		else if (prob(15))
			var/done = FALSE
			for (var/obj/structure/sink/S in range(8, src))
				if (done == FALSE)
					walk_towards(src, S, 3)
					done = TRUE
			if (done == FALSE)
				walk_rand(src,4)
		else
			walk_rand(src,4)
		if (prob(10))
			for (var/mob/living/carbon/human/TG in range(1,src))
				visible_message("<span class = 'danger'>\The [src] bite [TG]!")
				TG.adjustBruteLoss(1,2)
				if (prob(20) && TG.disease == 0)
					TG.disease_progression = 0
					TG.disease_type ="malaria"
					TG.disease = 1

	if (stat == DEAD)
		spawn(50)
			qdel(src)
			return
/mob/living/simple_animal/mosquito/bullet_act(var/obj/item/projectile/Proj)
	return

/mob/living/simple_animal/mosquito/attack_hand(mob/living/carbon/human/M as mob)
	M.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
	visible_message("[M] swats away the [src]!","You swat away the [src]!")
	walk_away(src, M, 3, 3)
	if (prob(20))
		health--

/mob/living/simple_animal/mosquito/attackby(var/obj/item/O, var/mob/user)
	if (istype(O, /obj/item/weapon/swatter))
		if (prob(20))
			visible_message("[user] swats \the [src] with \the [O]!")
			walk(src,0)
			walk_away(src, user, 5, 3)
			health--
			return
		else
			visible_message("[user] misses \the [src]!")
			return
	else
		return

/obj/structure/curtain/Crossed(var/mob/living/simple_animal/mosquito/M)
	if (icon_state != "open" && istype(M, /mob/living/simple_animal/mosquito))
		walk(M,0)
		walk_away(M, src, 1, 3)
	else
		..()