//Cat
/mob/living/simple_animal/cat
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
	var/turns_since_scan = FALSE
	var/mob/living/simple_animal/mouse/movement_target
	var/mob/flee_target
	minbodytemp = 223		//Below -50 Degrees Celcius
	maxbodytemp = 323	//Above 50 Degrees Celcius
//	holder_type = /obj/item/weapon/holder/cat
	mob_size = MOB_SMALL
	possession_candidate = TRUE
	carnivore = 1
	melee_damage_lower = 5
	melee_damage_upper = 9

/mob/living/simple_animal/cat/Life()
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

/mob/living/simple_animal/cat/proc/handle_movement_target()
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

/mob/living/simple_animal/cat/proc/handle_flee_target()
	//see if we should stop fleeing
	if (flee_target && !(flee_target.loc in view(src)))
		flee_target = null
		stop_automated_movement = FALSE

	if (flee_target)
		if (prob(25)) say("HSSSSS")
		stop_automated_movement = TRUE
		walk_away(src, flee_target, 7, 2)

/mob/living/simple_animal/cat/proc/set_flee_target(atom/A)
	if (A)
		flee_target = A
		turns_since_scan = 5

/mob/living/simple_animal/cat/attackby(var/obj/item/O, var/mob/user)
	. = ..()
	if (O.force)
		set_flee_target(user? user : loc)

/mob/living/simple_animal/cat/attack_hand(mob/living/human/M as mob)
	. = ..()
	if (M.a_intent == I_HARM)
		set_flee_target(M)

/mob/living/simple_animal/cat/ex_act()
	. = ..()
	set_flee_target(loc)

/mob/living/simple_animal/cat/bullet_act(var/obj/item/projectile/proj)
	. = ..()
	set_flee_target(proj.firer? proj.firer : loc)

/mob/living/simple_animal/cat/hitby(atom/movable/AM)
	. = ..()
	set_flee_target(AM.thrower? AM.thrower : loc)
/*
/mob/living/simple_animal/cat/MouseDrop(atom/over_object)

	var/mob/living/human/H = over_object
	if (!istype(H) || !Adjacent(H)) return ..()

	if (H.a_intent == I_HELP)
		get_scooped(H)
		return
	else
		return ..()
*/
//Basic friend AI
/mob/living/simple_animal/cat/fluff
	var/mob/living/human/friend

/mob/living/simple_animal/cat/fluff/handle_movement_target()
	if (friend)
		var/follow_dist = 5
		if (friend.stat >= DEAD || friend.health <= config.health_threshold_softcrit) //danger
			follow_dist = TRUE
		else if (friend.stat || friend.health <= 50) //danger or just sleeping
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

/mob/living/simple_animal/cat/fluff/Life()
	..()
	if (stat || !friend)
		return
	if (get_dist(src, friend) <= 1)
		if (friend.stat >= DEAD || friend.health <= config.health_threshold_softcrit)
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

/mob/living/simple_animal/cat/fluff/verb/friend()
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

	usr << "<span class='notice'>[src] ignores you.</span>"
	return


//RUNTIME IS ALIVE! SQUEEEEEEEE~
/mob/living/simple_animal/cat/fluff/Runtime
	name = "Runtime"
	desc = "Her fur has the look and feel of velvet, and her tail quivers occasionally."
	gender = FEMALE
	icon_state = "cat"
	item_state = "cat"
	icon_living = "cat"
	icon_dead = "cat_dead"

/mob/living/simple_animal/cat/kitten
	name = "kitten"
	desc = "D'aaawwww"
	icon_state = "kitten"
	item_state = "kitten"
	icon_living = "kitten"
	icon_dead = "kitten_dead"
	gender = NEUTER

/mob/living/simple_animal/cat/kitten/New()
	gender = pick(MALE, FEMALE)
	..()

/mob/living/simple_animal/cat/salem
	name = "Salem"
	desc = "The ship's black tomcat. Keeps the hull clear of mice and brings good luck to the crew. His death would be disastrous..."
	gender = MALE
	icon_state = "cat4"
	item_state = "cat4"
	icon_living = "cat4"
	icon_dead = "cat4_dead"
	starves = FALSE