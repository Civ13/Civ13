//Cat
/mob/living/simple_animal/dog
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
	var/turns_since_scan = FALSE
	var/mob/living/simple_animal/mouse/movement_target
	var/mob/flee_target
	minbodytemp = 223		//Below -50 Degrees Celcius
	maxbodytemp = 323	//Above 50 Degrees Celcius
	mob_size = MOB_SMALL
	possession_candidate = TRUE
	carnivore = 1

/mob/living/simple_animal/dog/Life()
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

	for (var/mob/living/simple_animal/cat/cats in oview(src,5))
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

/mob/living/simple_animal/dog/proc/handle_movement_target()
	//if our target is neither inside a turf or inside a human(???), stop
	if ((movement_target) && !(isturf(movement_target.loc) || ishuman(movement_target.loc) ))
		movement_target = null
		stop_automated_movement = FALSE
	//if we have no target or our current one is out of sight/too far away
	if ( !movement_target || !(movement_target.loc in oview(src, 4)) )
		movement_target = null
		stop_automated_movement = FALSE
		for (var/mob/living/simple_animal/mouse/snack in oview(src)) //search for a new target
			if (isturf(snack.loc) && !snack.stat)
				movement_target = snack
				break

	if (movement_target)
		stop_automated_movement = TRUE
		walk_to(src,movement_target,0,3)

/mob/living/simple_animal/dog/proc/handle_flee_target()
	//see if we should stop fleeing
	if (flee_target && !(flee_target.loc in view(src)))
		flee_target = null
		stop_automated_movement = FALSE

	if (flee_target)
		if (prob(25)) say("Wip wip!")
		stop_automated_movement = TRUE
		walk_away(src, flee_target, 7, 2)

/mob/living/simple_animal/dog/proc/set_flee_target(atom/A)
	if (A)
		flee_target = A
		turns_since_scan = 5

/mob/living/simple_animal/dog/attackby(var/obj/item/O, var/mob/user)
	. = ..()
	if (O.force)
		set_flee_target(user? user : loc)

/mob/living/simple_animal/dog/attack_hand(mob/living/human/M as mob)
	. = ..()
	if (M.a_intent == I_HARM)
		set_flee_target(M)

/mob/living/simple_animal/dog/ex_act()
	. = ..()
	set_flee_target(loc)

/mob/living/simple_animal/dog/bullet_act(var/obj/item/projectile/proj)
	. = ..()
	set_flee_target(proj.firer? proj.firer : loc)

/mob/living/simple_animal/dog/hitby(atom/movable/AM)
	. = ..()
	set_flee_target(AM.thrower? AM.thrower : loc)