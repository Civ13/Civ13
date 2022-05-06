/mob/living/simple_animal/hostile
	faction = "hostile"
	stop_automated_movement_when_pulled = FALSE
	a_intent = I_HARM
	behaviour = "hunt"

/mob/living/simple_animal/proc/FindTarget()
	var/atom/T = null
	if(!istype(src,/mob/living/simple_animal/hostile/human))
		stop_automated_movement = FALSE
	var/list/the_targets = ListTargets(7) // range that simple_animal will look for targets
	if (behaviour == "hostile")
		stance = HOSTILE_STANCE_ATTACK
		for(var/mob/living/ML in the_targets)
			if (ishuman(ML))
				var/mob/living/human/H = ML
				if (H.faction_text == src.faction)
					the_targets -= ML
			if (istype(ML, /mob/living/simple_animal/hostile/human) && ML.faction == src.faction)
				the_targets -= ML

	for (var/atom/A in the_targets)
		if (A == src)
			continue
		if (isliving(A))
			var/mob/living/L = A
			if (istype(L, /mob/living/human))
				var/mob/living/human/RH = L
				if (RH.faction_text == faction)
					continue
				else if (RH in friends)
					continue
				else if (RH.wolfman && istype(src,/mob/living/simple_animal/hostile/wolf))
					continue
				else if (RH.lizard && istype(src,/mob/living/simple_animal/hostile/alligator))
					continue
				else
					if (RH.stat != DEAD)
						stance = HOSTILE_STANCE_ATTACK
						T = RH
						break
			else
				if (L.faction == faction)
					continue
				else if (L in friends)
					continue
				else if (map.ID == MAP_VOYAGE) //so animals dont slaughter each other in the islands
					continue
				else
					if (L.stat != DEAD)
						stance = HOSTILE_STANCE_ATTACK
						T = L
						break
	if (T)
		if (!istype(src,/mob/living/simple_animal/hostile/human))
			custom_emote(1,"stares alertly at [T].")
		else
			var/mob/living/simple_animal/hostile/human/HM = src
			if (HM.messages["enemy_sighted"] && prob(25))
				HM.say(HM.messages["enemy_sighted"],HM.language)

		stance = HOSTILE_STANCE_ATTACK
	return T

/mob/living/simple_animal/proc/MoveToTarget()
	if (!target_mob || !SA_attackable(target_mob))
		stance = HOSTILE_STANCE_IDLE
	if (target_mob in ListTargets(8))
		stance = HOSTILE_STANCE_ATTACK
		walk_to(src, target_mob, TRUE, move_to_delay)
	else if (target_mob in ListTargets(10))
		walk_to(src, target_mob, TRUE, move_to_delay)

/mob/living/simple_animal/proc/AttackTarget()
	if (!target_mob || !SA_attackable(target_mob))
		LoseTarget()
		return FALSE
	if (!(target_mob in ListTargets(8)))
		LostTarget()
		return FALSE
	if (get_dist(src, target_mob) <= 1)	//Attacking
		AttackingTarget()
		return TRUE
	else
		MoveToTarget()


/mob/living/simple_animal/proc/AttackingTarget()
	if (!Adjacent(target_mob))
		return
	playsound(src.loc, attack_sound, 100, TRUE, 2)
	custom_emote(1, "[attack_verb] [target_mob]!")

	var/damage = pick(melee_damage_lower,melee_damage_upper)
	if (ishuman(target_mob))
		var/mob/living/human/H = target_mob
		var/dam_zone = pick("chest", "l_hand", "r_hand", "l_leg", "r_leg")
		var/obj/item/organ/external/affecting = H.get_organ(ran_zone(dam_zone))
		if (istype(src, /mob/living/simple_animal/mouse))
			var/dmod = 1
			if (H.find_trait("Weak Immune System"))
				dmod = 2
			if (prob(3*dmod))
				H.disease = TRUE
				H.disease_type = "plague"

		if (prob(95) || !can_bite_limbs_off)
			H.apply_damage(damage, BRUTE, affecting, H.run_armor_check(affecting, "melee"), sharp=1, edge=1)
		else
			affecting.droplimb(FALSE, DROPLIMB_EDGE)
			visible_message("\The [src] bites off [H]'s limb!")
			for(var/mob/living/human/NB in view(6,src))
				NB.mood -= 10
	else if (isliving(target_mob))
		var/mob/living/L = target_mob
		L.adjustBruteLoss(damage)
		if (istype(target_mob, /mob/living/simple_animal))
			var/mob/living/simple_animal/SA = target_mob
			if (SA.behaviour == "defends" || SA.behaviour == "hunt")
				if (SA.stance != HOSTILE_STANCE_ATTACK)
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


/mob/living/simple_animal/proc/ListTargets(var/dist = 8)
	var/list/L = hearers(dist,src)
	return L

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
			else if (istype(obstacle, /obj/structure/simple_door))
				var/obj/structure/simple_door/SD = obstacle
				SD.Bumped(src)
