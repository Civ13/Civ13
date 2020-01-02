/mob/living/simple_animal/hostile
	faction = "hostile"
	stop_automated_movement_when_pulled = FALSE
	a_intent = I_HARM
	behaviour = "hunt"

/mob/living/simple_animal/proc/FindTarget()

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
	if (T)
		custom_emote(1,"stares alertly at [T].")
		stance = HOSTILE_STANCE_ALERT
	return T


/mob/living/simple_animal/proc/Found(var/atom/A)
	return

/mob/living/simple_animal/proc/MoveToTarget()
	if (!target_mob || SA_attackable(target_mob))
		stance = HOSTILE_STANCE_IDLE
	if (target_mob in ListTargets(7))
		stance = HOSTILE_STANCE_ATTACKING
		walk_to(src, target_mob, TRUE, move_to_delay)

/mob/living/simple_animal/proc/AttackTarget()
	if (!target_mob || SA_attackable(target_mob))
		LoseTarget()
		return FALSE
	if (!(target_mob in ListTargets(7)))
		LostTarget()
		return FALSE
	if (get_dist(src, target_mob) <= 1)	//Attacking
		AttackingTarget()
		return TRUE

/mob/living/simple_animal/proc/AttackingTarget()
	if (!Adjacent(target_mob))
		return
	if(prob(50))
		playsound(src.loc, 'sound/weapons/bite.ogg', 100, TRUE, 2)
	else
		playsound(src.loc, 'sound/weapons/bite_2.ogg', 100, TRUE, 2)
	custom_emote(1, pick( list("slashes at [target_mob]!", "bites [target_mob]!") ) )

	var/damage = pick(melee_damage_lower,melee_damage_upper)

	if (ishuman(target_mob))
		var/mob/living/carbon/human/H = target_mob
		var/dam_zone = pick("chest", "l_hand", "r_hand", "l_leg", "r_leg")
		var/obj/item/organ/external/affecting = H.get_organ(ran_zone(dam_zone))
		if (prob(95) || !can_bite_limbs_off)
			H.apply_damage(damage, BRUTE, affecting, H.run_armor_check(affecting, "melee"), sharp=1, edge=1)
		else
			affecting.droplimb(FALSE, DROPLIMB_EDGE)
			visible_message("\The [src] bites off [H]'s limb!")
			for(var/mob/living/carbon/human/NB in view(6,src))
				NB.mood -= 10
	else if (isliving(target_mob))
		var/mob/living/L = target_mob
		L.adjustBruteLoss(damage)
		if (istype(target_mob, /mob/living/simple_animal))
			var/mob/living/simple_animal/SA = target_mob
			if (SA.behaviour == "defends" || SA.behaviour == "hunt")
				if (SA.stance != HOSTILE_STANCE_ATTACK && SA.stance != HOSTILE_STANCE_ATTACKING)
					SA.stance = HOSTILE_STANCE_ATTACK
					SA.stance_step = 7
					SA.target_mob = src
		return L
/mob/living/simple_animal/proc/LoseTarget()
	stance = HOSTILE_STANCE_IDLE
	target_mob = null
	walk(src, FALSE)

/mob/living/simple_animal/proc/LostTarget()
	stance = HOSTILE_STANCE_IDLE
	walk(src, FALSE)


/mob/living/simple_animal/proc/ListTargets(var/dist = 7)
	var/list/L = hearers(dist,src)
	return L

/mob/living/simple_animal/hostile/Life()

	. = ..()
	if (!.)
		walk(src, FALSE)
		return FALSE
	if (client)
		return FALSE
	if ((prob(20) && (herbivore || carnivore || predatory_carnivore || granivore || scavenger) && simplehunger < 220) || simplehunger < 180)

		check_food() // animals will search for crops, grass, and so on

/mob/living/simple_animal/proc/DestroySurroundings()
	if (prob(break_stuff_probability))
		for (var/dir in cardinal) // North, South, East, West
			for (var/obj/structure/window/obstacle in get_step(src, dir))
				if (obstacle.dir == reverse_dir[dir]) // So that windows get smashed in the right order
					obstacle.attack_generic(src,rand(melee_damage_lower,melee_damage_upper),attacktext)
					return
			var/obj/structure/obstacle = locate(/obj/structure, get_step(src, dir))
			if (istype(obstacle, /obj/structure/window) || istype(obstacle, /obj/structure/closet) || istype(obstacle, /obj/structure/table) || istype(obstacle, /obj/structure/grille))
				obstacle.attack_generic(src,rand(melee_damage_lower,melee_damage_upper),attacktext)