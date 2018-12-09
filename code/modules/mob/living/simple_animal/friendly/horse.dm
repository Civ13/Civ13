/mob/living/simple_animal/horse
	name = "horse"
	desc = "A friendly horse. Seems to be tamed."
	icon = 'icons/mob/animal_96.dmi'
	icon_state = "horse_empty"
	icon_living = "horse_empty"
	icon_dead = "horse_dead"
	speak = list("iiiiiiiih","BRHBRH","IIIIIIIIIIIIIIHHH")
	speak_emote = list("neighs")
	emote_hear = list("neighs")
	emote_see = list("shakes its head")
	speak_chance = TRUE
	turns_per_move = 2
	see_in_dark = 6
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/meat
	meat_amount = 6
	response_help  = "pets"
	response_disarm = "gently pushes aside"
	response_harm   = "kicks"
	attacktext = "kicked"
	health = 120
	mob_size = MOB_LARGE
	var/ride = FALSE
	var/mob/living/carbon/human/rider = null

/mob/living/simple_animal/horse/update_icons()
	..()
	if (ride)
		icon_state = "horse_riding"
	else
		icon_state = "horse_empty"

/mob/living/simple_animal/horse/attack_hand(mob/living/carbon/human/M as mob)
	if (ride == FALSE && isnull(rider))
		visible_message("<div class='notice'>[M] starts getting on the [src]'s back...</div>","<div class='notice'>You start going on the [src]'s back...</div>")
		if (do_after(M, 40, src))
			visible_message("<div class='notice'>[M] sucessfully climbs into the [src]'s back.</div>","<div class='notice'>You sucessfully climb into the [src]'s back.</div>")
			ride = TRUE
			rider = M
			M.forceMove(locate(x+1,y+1,z))
			M.riding = TRUE
			M.riding_mob = src
			update_icons()
			stop_automated_movement = TRUE
			return
	else
		if (rider == M)
			visible_message("<div class='notice'>[M] starts to get off the horse...</div>","<div class='notice'>You start to get off the horse...</div>")
			if (do_after(M, 40, src))
				visible_message("<div class='danger'>[M] gets out of the horse.</div>","<div class='danger'>You get out of the horse.</div>")
				M.riding = FALSE
				M.riding_mob = null
				M.forceMove(locate(x+1,y,z))
				ride = FALSE
				rider = null
				update_icons()
				stop_automated_movement = FALSE
				return
		else
			visible_message("<div class='danger'>[M] tries to pull [rider] from the horse!</div>","<div class='danger'>You try to pull [rider] from the horse!</div>")
			if (do_after(M, 40, src))
				visible_message("<div class='danger'>[M] pulls [rider] from the horse!</div>","<div class='danger'>You pull [rider] from the horse!</div>")
				rider.riding = FALSE
				rider.riding_mob = null
				rider.forceMove(locate(x+1,y,z))
				rider.SpinAnimation(5,1)
				rider.Weaken(5)
				ride = FALSE
				rider = null
				update_icons()
				stop_automated_movement = FALSE
				return

/mob/living/simple_animal/horse/death()
	..()
	if (ride)
		visible_message("<div class='danger'>[rider] falls from the horse!</div>","<div class='danger'>You fall from the horse!</div>")
		rider.riding = FALSE
		rider.SpinAnimation(5,1)
		rider.forceMove(locate(x+1,y,z))
		rider.Weaken(5)
		rider = null
		ride = FALSE
		rider = null