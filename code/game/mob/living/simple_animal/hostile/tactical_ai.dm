// Tactical AI helpers for human NPCs

// Optimized LOS check for AI
/proc/ai_check_los(atom/source, atom/target)
	if(!source || !target) return FALSE
	var/turf/start = get_turf(source)
	var/turf/end = get_turf(target)
	if(!start || !end) return FALSE
	
	var/list/turfs = getline2(start, end, FALSE)
	for(var/turf/T in turfs)
		if(T == end) break
		if(T.opacity) return FALSE
		for(var/atom/A in T)
			if(A.opacity) return FALSE
	return TRUE

// Evaluates if a turf provides cover against an enemy at a specific location
/proc/is_good_cover(turf/T, atom/enemy)
	if(!T || !enemy) return FALSE
	if(T.opacity || T.density) return TRUE // Basic dense turf cover
	
	// Check for structures that provide cover
	for(var/obj/structure/S in T)
		if(S.density) return TRUE
		if(istype(S, /obj/structure/window/barrier))
			// Windows/barriers only provide cover if facing the enemy
			var/dir_to_enemy = get_dir(T, enemy)
			if(S.dir & dir_to_enemy) return TRUE
			
	return FALSE

// Finds the best nearby cover relative to an enemy
/mob/living/simple_animal/hostile/human/proc/find_best_cover(atom/enemy)
	if(!enemy) return null
	
	var/turf/best_turf = null
	var/best_score = -9999
	
	// Scan 7x7 area around self
	for(var/turf/T in range(3, src))
		if(T.density) continue
		
		var/score = 0
		var/dist = get_dist(src, T)
		score -= dist * 10 // Prefer closer cover
		
		// Check if it's actually cover relative to the enemy
		if(is_good_cover(T, enemy))
			score += 100
			
			// Flanking bonus: prefer positions that are at a different angle from current
			var/current_dir = get_dir(src, enemy)
			var/new_dir = get_dir(T, enemy)
			if(new_dir != current_dir)
				score += 40
			
			// Check LOS from cover to enemy (we want cover that breaks LOS or allows peeking)
			if(!ai_check_los(T, enemy))
				score += 50 // Good, breaks LOS
			else
				score -= 30 // Bad, enemy can still see us here
				
			// Penalty for being too close to other allies (avoid grenades/clumping)
			for(var/mob/living/simple_animal/hostile/human/H in range(1, T))
				if(H != src && H.faction == faction)
					score -= 60
					
			// Small bonus for being within sight of an officer (leadership)
			if(role != "officer")
				for(var/mob/living/simple_animal/hostile/human/H in range(5, T))
					if(H.role == "officer" && H.faction == faction)
						score += 20
						break
					
		if(score > best_score)
			best_score = score
			best_turf = T
			
	return best_turf

// Checks if there is a friendly unit between the source and the target
/mob/living/simple_animal/hostile/human/proc/check_friendly_fire(atom/target)
	if(!target) return FALSE
	var/turf/start = get_turf(src)
	var/turf/end = get_turf(target)
	if(!start || !end) return FALSE
	
	var/list/turfs = getline2(start, end, FALSE)
	for(var/turf/T in turfs)
		if(T == start || T == end) continue
		for(var/mob/living/L in T)
			if(L.stat == DEAD) continue
			if(ishuman(L))
				var/mob/living/human/H = L
				if(H.faction_text == faction)
					return TRUE
			else if(istype(L, /mob/living/simple_animal/hostile/human))
				var/mob/living/simple_animal/hostile/human/HH = L
				if(HH.faction == faction)
					return TRUE
	return FALSE

// Combat-specific AI behaviors and stance handling

/mob/living/simple_animal/handle_combat_behaviour(t_behaviour)
	a_intent = I_HARM
	if (stat == DEAD || stat == UNCONSCIOUS)
		return FALSE

	if (t_behaviour == "hunt" || (t_behaviour == "defends" && target_mob))
		if(prob(50))
			if(!isemptylist(hostilesounds))
				playsound(src, pick(hostilesounds), 60)
		if (isturf(loc) && !resting && !buckled && canmove)
			turns_since_move++
			if (turns_since_move >= move_to_delay && stance == HOSTILE_STANCE_IDLE)
				if (!(stop_automated_movement_when_pulled && pulledby))
					if (istype(src, /mob/living/simple_animal/hostile/human/skeleton/attacker))
						if (prob(20) && get_dist(src, locate(/obj/effect/landmark/npctarget)) > 11)
							walk_to(src, locate(/obj/effect/landmark/npctarget), TRUE, move_to_delay)
					var/moving_to = pick(cardinal)
					set_dir(moving_to)
					Move(get_step(src, moving_to))
					turns_since_move = 0
		switch(stance)
			if (HOSTILE_STANCE_IDLE)
				if (!target_mob || !(target_mob in view(idle_vision_range, src)) || target_mob.stat != CONSCIOUS)
					target_mob = FindTarget()
					stance_step = 0
			if (HOSTILE_STANCE_TIRED)
				stance_step++
				if (stance_step >= 5)
					if (target_mob && (target_mob in view(idle_vision_range, src)))
						stance = HOSTILE_STANCE_ATTACK
					else
						stance = HOSTILE_STANCE_IDLE

			if (HOSTILE_STANCE_ALERT)
				var/found_mob = FALSE
				if (target_mob && (target_mob in view(aggro_vision_range, src)))
					if ((SA_attackable(target_mob)))
						stance_step = max(0, stance_step)
						stance_step++
						found_mob = TRUE
						set_dir(get_dir(src, target_mob))

						if (stance_step in list(0, 3, 5))
							var/action = pick(list("stares alertly at [target_mob].", "closely watches [target_mob]."))
							if (action)
								custom_emote(1, action)
								if(!isemptylist(hostilesounds))
									playsound(src, pick(hostilesounds), 60)
				if (!found_mob)
					stance_step--

				if (stance_step <= -10)
					stance = HOSTILE_STANCE_IDLE
				if (stance_step >= 1 || (behaviour == "hostile"))
					stance = HOSTILE_STANCE_ATTACK
					AttackTarget()

			if (HOSTILE_STANCE_ATTACK)
				if (destroy_surroundings)
					DestroySurroundings()
				AttackTarget()
				if (stance_step >= 20)
					custom_emote(1, "is worn out and needs to rest.")
					stance = HOSTILE_STANCE_TIRED
					stance_step = 0
					walk(src, 0)

	else if (t_behaviour == "hostile")
		if (isturf(loc) && !resting && !buckled && canmove)
			turns_since_move++
			if (turns_since_move >= move_to_delay && stance == HOSTILE_STANCE_IDLE)
				if(istype(src, /mob/living/simple_animal/hostile))
					var/mob/living/simple_animal/hostile/H = src
					if(H.pathfind_target)
						if(get_dist(src, H.pathfind_target) > 2)
							walk_to(src, H.pathfind_target, 2, move_to_delay)
						else
							H.pathfind_target = null
					else
						var/moving_to = pick(cardinal)
						var/turf/move_to_turf = get_step(src, moving_to)
						if (!(istype(loc, /turf/floor/trench) && !istype(move_to_turf, /turf/floor/trench)))
							set_dir(moving_to)
							Move(move_to_turf)
					turns_since_move = 0
				else
					var/moving_to = pick(cardinal)
					var/turf/move_to_turf = get_step(src, moving_to)
					if (!(istype(loc, /turf/floor/trench) && !istype(move_to_turf, /turf/floor/trench)))
						set_dir(moving_to)
						Move(move_to_turf)
				turns_since_move = 0
		switch(stance)
			if (HOSTILE_STANCE_IDLE)
				if (!target_mob || !(target_mob in view(idle_vision_range, src)) || target_mob.stat != CONSCIOUS)
					target_mob = FindTarget()
					if (target_mob)
						walk(src, 0) // Stop the pathfinding walk before entering combat
						stance = HOSTILE_STANCE_ATTACK
						if (target_mob && get_dist(target_mob, src) > 1)
							AttackTarget()
			if (HOSTILE_STANCE_TIRED, HOSTILE_STANCE_ALERT)
				if (target_mob && (target_mob in view(aggro_vision_range, src)))
					if ((SA_attackable(target_mob)))
						set_dir(get_dir(src, target_mob))
						stance = HOSTILE_STANCE_ATTACK
						AttackTarget()
					else
						target_mob = FindTarget()
				else
					target_mob = FindTarget()
			if (HOSTILE_STANCE_ATTACK)
				if (destroy_surroundings)
					DestroySurroundings()
				AttackTarget()
		return t_behaviour
	return FALSE

/mob/living/simple_animal/proc/FindTarget()
	var/atom/T = null
	if(!istype(src, /mob/living/simple_animal/hostile/human))
		stop_automated_movement = FALSE
	var/list/the_targets = ListTargets(idle_vision_range)
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
				else if (RH.wolfman && istype(src, /mob/living/simple_animal/hostile/wolf))
					continue
				else if (RH.lizard && istype(src, /mob/living/simple_animal/hostile/alligator))
					continue
				else
					if (RH.stat != DEAD)
						stance = HOSTILE_STANCE_ATTACK
						T = RH
						break
			else
				if (istype(L, /mob/living/simple_animal/civilian) && istype(src, /mob/living/simple_animal/hostile/human/redmenian_ng))
					continue
				if (L.faction == faction)
					continue
				else if (L in friends)
					continue
				else if (map.ID == MAP_VOYAGE)
					continue
				else
					if (L.stat != DEAD)
						stance = HOSTILE_STANCE_ATTACK
						T = L
						break
	if (T)
		if (!istype(src, /mob/living/simple_animal/hostile/human))
			custom_emote(1, "stares alertly at [T].")
		else
			var/mob/living/simple_animal/hostile/human/HM = src
			if (HM.messages["enemy_sighted"] && prob(25))
				HM.say(HM.messages["enemy_sighted"], HM.language)

		stance = HOSTILE_STANCE_ATTACK
	return T

/mob/living/simple_animal/proc/MoveToTarget()
	if (!target_mob || !SA_attackable(target_mob))
		stance = HOSTILE_STANCE_IDLE
		walk(src, 0)
		return

	// Stuck detection
	if (loc == last_loc)
		stuck_ticks++
	else
		stuck_ticks = 0
		last_loc = loc

	if (target_mob in view(aggro_vision_range, src))
		stance = HOSTILE_STANCE_ATTACK
		
		if (stuck_ticks >= 3)
			// Try to find a way around by stepping perpendicular to target
			var/dir_to_target = get_dir(src, target_mob)
			var/side_step_dir = pick(turn(dir_to_target, 90), turn(dir_to_target, -90))
			if (!step(src, side_step_dir))
				step(src, turn(side_step_dir, 180))
			
			// If really stuck, maybe try to break things
			if (stuck_ticks >= 6 && destroy_surroundings)
				DestroySurroundings()
				
			stuck_ticks = 0 // Reset counter after attempt
		else
			walk_to(src, target_mob, 1, move_to_delay)

	else if (target_mob in view(idle_vision_range, src))
		walk_to(src, target_mob, 1, move_to_delay)

/mob/living/simple_animal/proc/AttackTarget()
	if (!target_mob || !SA_attackable(target_mob))
		LoseTarget()
		return FALSE
	if (!(target_mob in view(aggro_vision_range, src)))
		LostTarget()
		return FALSE
	if (get_dist(src, target_mob) <= 1)
		AttackingTarget()
		return TRUE
	else
		MoveToTarget()

/mob/living/simple_animal/proc/AttackingTarget()
	if (!Adjacent(target_mob))
		return
	playsound(src.loc, attack_sound, 100, TRUE, 2)
	custom_emote(1, "[attack_verb] [target_mob]!")

	var/damage = pick(melee_damage_lower, melee_damage_upper)
	if (ishuman(target_mob))
		var/mob/living/human/H = target_mob
		var/dam_zone = pick("chest", "l_hand", "r_hand", "l_leg", "r_leg")
		var/obj/item/organ/external/affecting = H.get_organ(ran_zone(dam_zone))
		if (istype(src, /mob/living/simple_animal/mouse))
			var/dmod = 1
			if (H.find_trait("Weak Immune System"))
				dmod = 2
			if (H.find_trait("Strong Immune System"))
				dmod = 0.2
			if (prob(3*dmod))
				H.disease = TRUE
				H.disease_type = "plague"

		if (prob(95) || !can_bite_limbs_off)
			H.apply_damage(damage, BRUTE, affecting, H.run_armor_check(affecting, "melee"), sharp=1, edge=1)
		else
			affecting.droplimb(FALSE, DROPLIMB_EDGE)
			visible_message("\The [src] bites off [H]'s limb!")
			for(var/mob/living/human/NB in view(6, src))
				NB.mood -= 10
		do_attack_animation(H)
	else if (isliving(target_mob))
		var/mob/living/L = target_mob
		L.adjustBruteLoss(damage)
		do_attack_animation(L)
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

/mob/living/simple_animal/proc/ListTargets(var/dist = 7)
	return view(dist, src)

/mob/living/simple_animal/proc/SA_attackable(target_mob)
	if (isliving(target_mob))
		var/mob/living/L = target_mob
		if (L.stat != DEAD)
			return TRUE
	return FALSE

/mob/living/simple_animal/proc/DestroySurroundings()
	if (prob(break_stuff_probability))
		for (var/dir in cardinal)
			for (var/obj/structure/window/obstacle in get_step(src, dir))
				if (obstacle.dir == reverse_dir[dir])
					obstacle.attack_generic(src, rand(melee_damage_lower, melee_damage_upper), attacktext)
					return
			var/obj/structure/obstacle = locate(/obj/structure, get_step(src, dir))
			if (istype(obstacle, /obj/structure/window) || istype(obstacle, /obj/structure/closet) || istype(obstacle, /obj/structure/table) || istype(obstacle, /obj/structure/grille))
				obstacle.attack_generic(src, rand(melee_damage_lower, melee_damage_upper), attacktext)
			else if (istype(obstacle, /obj/structure/simple_door))
				var/obj/structure/simple_door/SD = obstacle
				SD.Bumped(src)
