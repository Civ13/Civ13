//Cat
/mob/living/simple_animal/pet/cat
	name = "cat"
	desc = "A domesticated, feline pet. Has a tendency to adopt humans."
	icon_state = "cat2"
	item_state = "cat2"
	icon_living = "cat2"
	icon_dead = "cat2_dead"
	speak = list("Meow!","Esp!","Purr!","HSSSSS")
	speak_emote = list("purrs", "meows")
	emote_hear = list("meows","mews")
	emote_see = list("shakes their head", "shivers")
	speak_chance = TRUE
	move_to_delay = 5
	see_in_dark = 6
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/meat
	response_help  = "pets"
	response_disarm = "gently pushes aside"
	response_harm   = "kicks"
	flee_message = "HSSSSS"
	minbodytemp = 223		//Below -50 Degrees Celcius
	maxbodytemp = 323	//Above 50 Degrees Celcius
//	holder_type = /obj/item/weapon/holder/cat
	mob_size = MOB_SMALL
	possession_candidate = TRUE
	carnivore = 1
	melee_damage_lower = 5
	melee_damage_upper = 9

/mob/living/simple_animal/pet/cat/Life()
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
			audible_emote(pick("hisses and spits!","mrowls fiercely!","eyes [snack] hungrily."))
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

	if (prob(2)) //spooky
		var/mob/observer/ghost/spook = locate() in range(src,5)
		if (spook)
			var/turf/T = spook.loc
			var/list/visible = list()
			for (var/obj/O in T.contents)
				if (!O.invisibility && O.name)
					visible += O
			if (visible.len)
				var/atom/A = pick(visible)
				visible_emote("suddenly stops and stares at something unseen[istype(A) ? " near [A]":""].")

/*
/mob/living/simple_animal/pet/cat/MouseDrop(atom/over_object)

	var/mob/living/human/H = over_object
	if (!istype(H) || !Adjacent(H)) return ..()

	if (H.a_intent == I_HELP)
		get_scooped(H)
		return
	else
		return ..()
*/
//Basic friend AI
/mob/living/simple_animal/pet/cat/fluff
	var/mob/living/human/friend

/mob/living/simple_animal/pet/cat/fluff/handle_movement_target()
	if (friend)
		var/follow_dist = 5
		if (friend.stat == DEAD || friend.health <= 0) //danger
			follow_dist = 1
		else if (friend.stat == UNCONSCIOUS || friend.health <= 50) //danger or just sleeping
			follow_dist = 2
		var/near_dist = max(follow_dist - 2, TRUE)
		var/current_dist = get_dist(src, friend)

		if (movement_target != friend)
			if (current_dist > follow_dist && !istype(movement_target, /mob/living/simple_animal/mouse) && (friend in oview(src)))
				//stop existing movement
				walk(src,0)
				turns_since_scan = FALSE

				//walk to friend
				stop_automated_movement = TRUE
				movement_target = friend
				walk_to(src, movement_target, near_dist, 4)

		//already following and close enough, stop
		else if (current_dist <= near_dist)
			walk(src,0)
			movement_target = null
			stop_automated_movement = FALSE
			if (prob(10))
				say("Meow!")

	if (!friend || movement_target != friend)
		..()

/mob/living/simple_animal/pet/cat/fluff/Life()
	..()
	if (stat || !friend)
		return
	if (get_dist(src, friend) <= 1)
		if (friend.stat == DEAD || friend.health <= 0)
			if (prob((friend.stat < DEAD)? 50 : 15))
				var/verb = pick("meows", "mews", "mrowls")
				audible_emote(pick("[verb] in distress.", "[verb] anxiously."))
		else
			if (prob(5))
				visible_emote(pick("nuzzles [friend].",
								   "brushes against [friend].",
								   "rubs against [friend].",
								   "purrs."))
	else if (friend.health <= 50)
		if (prob(10))
			var/verb = pick("meows", "mews", "mrowls")
			audible_emote("[verb] anxiously.")

/mob/living/simple_animal/pet/cat/fluff/verb/friend()
	set name = "Become Friends"
	set category = "IC"
	set src in view(1)

	if (friend && usr == friend)
		set_dir(get_dir(src, friend))
		say("Meow!")
		return

	if (ishuman(usr))
		friend = usr
		set_dir(get_dir(src, friend))
		say("Meow!")
		return

	to_chat(usr, "<span class='notice'>[src] ignores you.</span>")
	return


//RUNTIME IS ALIVE! SQUEEEEEEEE~
/mob/living/simple_animal/pet/cat/fluff/Runtime
	name = "Runtime"
	desc = "Her fur has the look and feel of velvet, and her tail quivers occasionally."
	gender = FEMALE
	icon_state = "cat"
	item_state = "cat"
	icon_living = "cat"
	icon_dead = "cat_dead"

/mob/living/simple_animal/pet/cat/kitten
	name = "kitten"
	desc = "D'aaawwww"
	icon_state = "kitten"
	item_state = "kitten"
	icon_living = "kitten"
	icon_dead = "kitten_dead"
	gender = NEUTER

/mob/living/simple_animal/pet/cat/kitten/New()
	gender = pick(MALE, FEMALE)
	..()

/mob/living/simple_animal/pet/cat/salem
	name = "Salem"
	desc = "The ship's black tomcat. Keeps the hull clear of mice and brings good luck to the crew. His death would be disastrous..."
	gender = MALE
	icon_state = "cat4"
	item_state = "cat4"
	icon_living = "cat4"
	icon_dead = "cat4_dead"
	starves = FALSE
