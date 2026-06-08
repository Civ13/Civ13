//Dog
/mob/living/simple_animal/pet/dog
	name = "beagle"
	desc = "A cute beagle."
	icon_state = "beagle"
	item_state = "beagle"
	icon_living = "beagle"
	icon_dead = "beagle_dead"
	speak = list("Woof!","Wip!","rrr!","WOOF!")
	speak_emote = list("barks", "pants")
	emote_hear = list("barks","pants")
	emote_see = list("sniffs the floor", "wags it's tail")
	speak_chance = TRUE
	move_to_delay = 5
	see_in_dark = 6
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/meat
	response_help  = "pets"
	response_disarm = "gently pushes aside"
	response_harm   = "kicks"
	flee_message = "Wip wip!"
	minbodytemp = 223		//Below -50 Degrees Celcius
	maxbodytemp = 323	//Above 50 Degrees Celcius
	mob_size = MOB_SMALL
	possession_candidate = TRUE
	carnivore = 1

/mob/living/simple_animal/pet/dog/Life()
	//MICE!
	if ((loc) && isturf(loc))
		if (!stat && !resting && !buckled)
			for (var/mob/living/simple_animal/mouse/M in loc)
				if (!M.stat)
					M.splat()
					visible_emote(pick("bites \the [M]!","toys with \the [M].","chomps on \the [M]!"))
					M.apply_damage(1, BRUTE)
					movement_target = null
					stop_automated_movement = FALSE
					break

	..()

	for (var/mob/living/simple_animal/mouse/snack in oview(src,5))
		if (snack.stat < DEAD && prob(15))
			audible_emote(pick("growls!","barks fiercely at the [snack]!","eyes [snack] and sniffs the floor!"))
			playsound(src.loc, 'sound/animals/dog/dogbark1.ogg', 100, TRUE, 3)
		break

	for (var/mob/living/simple_animal/pet/cat/cats in oview(src,5))
		if (cats.stat < DEAD && prob(35))
			audible_emote(pick("growls!","barks fiercely at the [cats]!","eyes [cats] attentively!"))
			playsound(src.loc, 'sound/animals/dog/dogbark1.ogg', 100, TRUE, 3)
		break

	for (var/mob/living/simple_animal/hostile/enemy in orange(src,15))
		if (enemy.stat < DEAD && prob(35))
			audible_emote(pick("barks in fear!","smells something!"))
			playsound(src.loc, 'sound/animals/dog/dogbark2.ogg', 100, TRUE, 3)
		break
	if (incapacitated())
		return

	turns_since_scan++
	if (turns_since_scan > 5)
		walk(src,0)
		turns_since_scan = FALSE

		if (flee_target) //fleeing takes precendence
			handle_flee_target()
		else
			handle_movement_target()
