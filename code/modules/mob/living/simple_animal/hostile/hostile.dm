/mob/living/simple_animal/hostile
	faction = "hostile"
	var/stance = HOSTILE_STANCE_IDLE	//Used to determine behavior
	var/mob/living/target_mob
	var/attack_same = FALSE
	var/ranged = FALSE
	var/rapid = FALSE
	var/projectiletype
	var/projectilesound
	var/casingtype
	var/move_to_delay = 4 //delay for the automated movement.
	var/list/friends = list()
	var/break_stuff_probability = 10
	stop_automated_movement_when_pulled = FALSE
	var/destroy_surroundings = TRUE
	a_intent = I_HURT

	var/enroute = FALSE
/mob/living/simple_animal/hostile/proc/FindTarget()

	var/atom/T = null
	stop_automated_movement = FALSE
	for (var/atom/A in ListTargets(7))

		if (A == src)
			continue

		var/atom/F = Found(A)
		if (F)
			T = F
			break

		if (isliving(A))
			var/mob/living/L = A
			if (istype(L, /mob/living/carbon/human))
				var/mob/living/carbon/human/RH = L
				if (RH.faction_text == faction && !attack_same)
					continue
				else if (RH in friends)
					continue
				else if (RH.wolfman && istype(src,/mob/living/simple_animal/hostile/wolf))
					continue
				else if (RH.lizard && istype(src,/mob/living/simple_animal/hostile/alligator))
					continue
				else
					if (!RH.stat)
						stance = HOSTILE_STANCE_ATTACK
						T = RH
						break
			else
				if (L.faction == faction && !attack_same)
					continue
				else if (L in friends)
					continue
				else
					if (!L.stat)
						stance = HOSTILE_STANCE_ATTACK
						T = L
						break

	return T


/mob/living/simple_animal/hostile/proc/Found(var/atom/A)
	return

/mob/living/simple_animal/hostile/proc/MoveToTarget()
	stop_automated_movement = TRUE
	if (!target_mob || SA_attackable(target_mob))
		stance = HOSTILE_STANCE_IDLE
	if (target_mob in ListTargets(7))
		if (ranged)
			if (get_dist(src, target_mob) <= 6)
				OpenFire(target_mob)
			else
				walk_to(src, target_mob, TRUE, move_to_delay)
		else
			stance = HOSTILE_STANCE_ATTACKING
			walk_to(src, target_mob, TRUE, move_to_delay)

/mob/living/simple_animal/hostile/proc/AttackTarget()
	stop_automated_movement = TRUE
	if (!target_mob || SA_attackable(target_mob))
		LoseTarget()
		return FALSE
	if (!(target_mob in ListTargets(7)))
		LostTarget()
		return FALSE
	if (get_dist(src, target_mob) <= 1)	//Attacking
		AttackingTarget()
		return TRUE

/mob/living/simple_animal/hostile/proc/AttackingTarget()
	if (!Adjacent(target_mob))
		return
	if (target_mob.bruteloss<200)
		var/mob/living/L = target_mob
		L.attack_generic(src,rand(melee_damage_lower,melee_damage_upper),attacktext)
		return L

/mob/living/simple_animal/hostile/proc/LoseTarget()
	stance = HOSTILE_STANCE_IDLE
	target_mob = null
	walk(src, FALSE)

/mob/living/simple_animal/hostile/proc/LostTarget()
	stance = HOSTILE_STANCE_IDLE
	walk(src, FALSE)


/mob/living/simple_animal/hostile/proc/ListTargets(var/dist = 7)
	var/list/L = hearers(src, dist)
	return L

/mob/living/simple_animal/hostile/death()
	..()
	walk(src, FALSE)

/mob/living/simple_animal/hostile/Life()

	. = ..()
	if (!.)
		walk(src, FALSE)
		return FALSE
	if (client)
		return FALSE

/mob/living/simple_animal/hostile/proc/OpenFire(target_mob)
	var/target = target_mob
	visible_message("<span class = 'red'><b>[src]</b> fires at [target]!</span>", TRUE)

	if (rapid)
		spawn(1)
			Shoot(target, loc, src)
		spawn(4)
			Shoot(target, loc, src)
		spawn(6)
			Shoot(target, loc, src)
	else
		Shoot(target, loc, src)

	stance = HOSTILE_STANCE_IDLE
	target_mob = null
	return


/mob/living/simple_animal/hostile/proc/Shoot(var/target, var/start, var/user, var/bullet = FALSE)
	if (target == start)
		return

	var/obj/item/projectile/A = new projectiletype(src.loc)
	playsound(user, projectilesound, 100, TRUE)
	if (!A)
		return
	var/def_zone = get_exposed_defense_zone(target)
	A.launch(target, def_zone)

/mob/living/simple_animal/hostile/proc/DestroySurroundings()
	if (prob(break_stuff_probability))
		for (var/dir in cardinal) // North, South, East, West
			for (var/obj/structure/window/obstacle in get_step(src, dir))
				if (obstacle.dir == reverse_dir[dir]) // So that windows get smashed in the right order
					obstacle.attack_generic(src,rand(melee_damage_lower,melee_damage_upper),attacktext)
					return
			var/obj/structure/obstacle = locate(/obj/structure, get_step(src, dir))
			if (istype(obstacle, /obj/structure/window) || istype(obstacle, /obj/structure/closet) || istype(obstacle, /obj/structure/table) || istype(obstacle, /obj/structure/grille))
				obstacle.attack_generic(src,rand(melee_damage_lower,melee_damage_upper),attacktext)


/mob/living/simple_animal/hostile/proc/tickproc() //for AI stuff. Life process only runs every 2 seconds
	spawn(10)
		if (health <= 0)
			death()
			return
		if (!stat)
			switch(stance)
				if (HOSTILE_STANCE_IDLE)
					target_mob = FindTarget()

				if (HOSTILE_STANCE_ATTACK)
					if (destroy_surroundings)
						DestroySurroundings()
					MoveToTarget()

				if (HOSTILE_STANCE_ATTACKING)
					if (destroy_surroundings)
						DestroySurroundings()
					spawn(10)
						AttackTarget()
		if (isturf(loc) && !resting && !buckled && canmove)		//This is so it only moves if it's not inside a closet, gentics machine, etc.
			turns_since_move++
			if (turns_since_move >= turns_per_move)
				if (!(stop_automated_movement_when_pulled && pulledby)) //Soma animals don't move when pulled
					if (istype(src, /mob/living/simple_animal/hostile/skeleton/attacker))
						if (prob(20) && get_dist(src, locate(/obj/effect/landmark/npctarget)) > 11)
							walk_to(src, locate(/obj/effect/landmark/npctarget),TRUE,move_to_delay)
					var/moving_to = FALSE // otherwise it always picks 4, fuck if I know.   Did I mention fuck BYOND
					moving_to = pick(cardinal)
					set_dir(moving_to)			//How about we turn them the direction they are moving, yay.
					Move(get_step(src,moving_to))
					turns_since_move = FALSE
		tickproc()

/mob/living/simple_animal/hostile/New()
	..()
	tickproc()