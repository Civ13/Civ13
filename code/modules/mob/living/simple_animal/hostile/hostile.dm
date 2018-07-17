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

	var/shuttletarget = null
	var/enroute = FALSE

/mob/living/simple_animal/hostile/proc/FindTarget()

	var/atom/T = null
	stop_automated_movement = FALSE
	for (var/atom/A in ListTargets(10))

		if (A == src)
			continue

		var/atom/F = Found(A)
		if (F)
			T = F
			break

		if (isliving(A))
			var/mob/living/L = A
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
	if (target_mob in ListTargets(10))
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
	if (!(target_mob in ListTargets(10)))
		LostTarget()
		return FALSE
	if (get_dist(src, target_mob) <= 1)	//Attacking
		AttackingTarget()
		return TRUE

/mob/living/simple_animal/hostile/proc/AttackingTarget()
	if (!Adjacent(target_mob))
		return
	if (isliving(target_mob))
		var/mob/living/L = target_mob
		L.attack_generic(src,rand(melee_damage_lower,melee_damage_upper),attacktext)
		return L
/*	if (istype(target_mob,/obj/machinery/bot))
		var/obj/machinery/bot/B = target_mob
		B.attack_generic(src,rand(melee_damage_lower,melee_damage_upper),attacktext)
		return B*/

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
				AttackTarget()

/mob/living/simple_animal/hostile/proc/OpenFire(target_mob)
	var/target = target_mob
	visible_message("<span class = 'red'><b>[src]</b> fires at [target]!</span>", TRUE)

	if (rapid)
		spawn(1)
			Shoot(target, loc, src)
			if (casingtype)
				new casingtype(get_turf(src))
		spawn(4)
			Shoot(target, loc, src)
			if (casingtype)
				new casingtype(get_turf(src))
		spawn(6)
			Shoot(target, loc, src)
			if (casingtype)
				new casingtype(get_turf(src))
	else
		Shoot(target, loc, src)
		if (casingtype)
			new casingtype

	stance = HOSTILE_STANCE_IDLE
	target_mob = null
	return


/mob/living/simple_animal/hostile/proc/Shoot(var/target, var/start, var/user, var/bullet = FALSE)
	if (target == start)
		return

	var/obj/item/projectile/A = new projectiletype(user:loc)
	playsound(user, projectilesound, 100, TRUE)
	if (!A)	return
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


/mob/living/simple_animal/hostile/proc/check_horde()
	return FALSE
	/*if (emergency_shuttle.shuttle.location)
		if (!enroute && !target_mob)	//The shuttle docked, all monsters rush for the escape hallway
			if (!shuttletarget && escape_list.len) //Make sure we didn't already assign it a target, and that there are targets to pick
				shuttletarget = pick(escape_list) //Pick a shuttle target
			enroute = TRUE
			stop_automated_movement = TRUE
			spawn()
				if (!stat)
					horde()

		if (get_dist(src, shuttletarget) <= 2)		//The monster reached the escape hallway
			enroute = FALSE
			stop_automated_movement = FALSE*/

/mob/living/simple_animal/hostile/proc/horde()
	var/turf/T = get_step_to(src, shuttletarget)
	for (var/atom/A in T)
		if (istype(A, /obj/structure/window) || istype(A, /obj/structure/closet) || istype(A, /obj/structure/table) || istype(A, /obj/structure/grille))
			A.attack_generic(src, rand(melee_damage_lower, melee_damage_upper))
	Move(T)
	FindTarget()
	if (!target_mob || enroute)
		spawn(10)
			if (!stat)
				horde()
