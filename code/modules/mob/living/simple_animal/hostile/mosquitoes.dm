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
	mob_size = MOB_MINISCULE
	stop_automated_movement_when_pulled = FALSE

/mob/living/simple_animal/mosquito/Life()
	..()
	if (stat != DEAD)
		if (prob(10))
			var/done = FALSE
			for (var/mob/living/carbon/human/H in range(6, src))
				if (done == FALSE)
					walk_to(src, H.loc, TRUE, 2)
					done = TRUE
	if (stat == DEAD)
		spawn(50)
			qdel(src)

/mob/living/simple_animal/mosquito/bullet_act(var/obj/item/projectile/Proj)
	return

/mob/living/simple_animal/mosquito/attack_hand(mob/living/carbon/human/M as mob)
	visible_message("[M] swats away the [src]!","You swat away the [src]!")
	//move them somewhere
/mob/living/simple_animal/attackby(var/obj/item/O, var/mob/user)
	if (istype(O, /obj/item/weapon/leash))
		return