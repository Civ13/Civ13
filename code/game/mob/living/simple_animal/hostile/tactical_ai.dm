// Tactical AI helpers for human NPCs

// Optimized LOS check for AI
/proc/ai_check_los(atom/source, atom/target)
	if(!source || !target) return FALSE
	var/turf/start = get_turf(source)
	var/turf/end = get_turf(target)
	if(!start || !end) return FALSE
	// Hills hide what is behind a ridge (los_terrain.dm).
	if(los_terrain_ray_blocked(source, target)) return FALSE
	
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
	// Decision-local only: candidates are within 3 tiles, so their 1/5-tile
	// ally searches fit within 4/8 tiles of src. The first cover uses its small
	// native searches; only repeated cover candidates justify the broad gather.
	var/list/nearby_allies
	var/list/nearby_officers
	var/cover_count = 0
	
	// Scan 7x7 area around self
	for(var/turf/T in range(3, src))
		if(T.density) continue
		
		var/score = 0
		var/dist = get_dist(src, T)
		score -= dist * 10 // Prefer closer cover
		
		// Check if it's actually cover relative to the enemy
		if(is_good_cover(T, enemy))
			cover_count++
			if(cover_count == 2)
				nearby_allies = list()
				nearby_officers = list()
				for(var/mob/living/simple_animal/hostile/human/H in range(role == "officer" ? 4 : 8, src))
					if(H.faction != faction) continue
					if(H != src && get_dist(src, H) <= 4)
						nearby_allies += H
					if(role != "officer" && H.role == "officer")
						nearby_officers += H
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
			if(cover_count == 1)
				for(var/mob/living/simple_animal/hostile/human/H in range(1, T))
					if(H != src && H.faction == faction)
						score -= 60
				// Small bonus for being within sight of an officer (leadership)
				if(role != "officer")
					for(var/mob/living/simple_animal/hostile/human/H in range(5, T))
						if(H.role == "officer" && H.faction == faction)
							score += 20
							break
			else
				for(var/mob/living/simple_animal/hostile/human/H in nearby_allies)
					if(get_dist(T, H) <= 1)
						score -= 60
				if(role != "officer")
					for(var/mob/living/simple_animal/hostile/human/H in nearby_officers)
						if(get_dist(T, H) <= 5)
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

/mob/living/simple_animal/proc/npc_subtile_combat_wander(turf/destination)
	if (npc_subtile_enabled && npc_subtile_pursuit_enabled)
		return ai_step(destination, move_to_delay, TRUE)
	if (!npc_subtile_enabled && (npc_subtile_transaction || npc_subtile_pulse || (npc_subtile_offset_owned && (step_x || step_y))))
		return FALSE
	if (!npc_subtile_enabled && npc_subtile_pursuit)
		npc_subtile_stop_pursuit()
	return Move(destination)

/mob/living/simple_animal/handle_combat_behaviour(t_behaviour)
	if (stat == DEAD || stat == UNCONSCIOUS)
		return FALSE
	a_intent = I_HARM
	if (food_distraction_tick())
		return t_behaviour

	if (t_behaviour == "hunt" || (t_behaviour == "defends" && target_mob))
		if(prob(50))
			if(!isemptylist(hostilesounds))
				playsound(src, pick(hostilesounds), 60)
		if (isturf(loc) && !resting && !buckled && canmove)
			turns_since_move++
			if (turns_since_move >= move_to_delay && stance == HOSTILE_STANCE_IDLE)
				if (!(stop_automated_movement_when_pulled && pulledby))
					var/moved = FALSE
					if (istype(src, /mob/living/simple_animal/hostile/human/skeleton/attacker) || istype(src, /mob/living/simple_animal/hostile/wizard/moldy_man/attacker))
						if (prob(20) && get_dist(src, locate(/obj/effect/landmark/npctarget)) > 11)
							walk_to(src, locate(/obj/effect/landmark/npctarget), TRUE, move_to_delay)
							moved = TRUE
						else
							var/list/valid_dirs = get_valid_move_dirs()
							if (valid_dirs.len)
								var/moving_to = pick(valid_dirs)
								set_dir(moving_to)
								if (Move(get_step(src, moving_to)))
									moved = TRUE
					else
						var/list/valid_dirs = get_valid_move_dirs()
						if (valid_dirs.len)
							var/moving_to = pick(valid_dirs)
							set_dir(moving_to)
							if (npc_subtile_combat_wander(get_step(src, moving_to)))
								moved = TRUE
					if (moved)
						turns_since_move = 0
		switch(stance)
			if (HOSTILE_STANCE_IDLE)
				if (!target_mob || !(target_mob in view(idle_vision_range, src)) || target_mob.stat != CONSCIOUS)
					npc_set_combat_target(FindTarget())
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
							var/action = pick("stares alertly at [target_mob].", "closely watches [target_mob].")
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
				var/moved = FALSE
				if(istype(src, /mob/living/simple_animal/hostile))
					var/mob/living/simple_animal/hostile/H = src
					if(H.pathfind_target)
						if(get_dist(src, H.pathfind_target) > 2)
								// Mobs without targeting use do_movement() directly
							if(!targeting)
								src.do_movement(H.pathfind_target)
							moved = TRUE
						else
							H.pathfind_target = null
				
				if(!moved)
					var/list/valid_dirs = get_valid_move_dirs()
					if (valid_dirs.len)
						var/moving_to = pick(valid_dirs)
						var/turf/move_to_turf = get_step(src, moving_to)
						if (!(istype(loc, /turf/floor/trench) && !istype(move_to_turf, /turf/floor/trench)))
							set_dir(moving_to)
							if (npc_subtile_combat_wander(move_to_turf))
								moved = TRUE
				
				if (moved)
					turns_since_move = 0
		switch(stance)
			if (HOSTILE_STANCE_IDLE)
				if (!target_mob || !(target_mob in view(idle_vision_range, src)) || target_mob.stat != CONSCIOUS)
					npc_set_combat_target(FindTarget())
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
						npc_set_combat_target(FindTarget())
				else
					npc_set_combat_target(FindTarget())
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
	var/vision_range = (stance == HOSTILE_STANCE_IDLE) ? (idle_vision_range || 7) : (aggro_vision_range || 9)
	var/list/the_targets = ListTargets(vision_range)

	if (behaviour == "hostile")
		stance = HOSTILE_STANCE_ATTACK
	for (var/atom/A in the_targets)
		if (A == src)
			continue
		if (isliving(A))
			var/mob/living/L = A
			if (L.stat == DEAD)
				continue

			var/target_faction = null
			if (istype(L, /mob/living/human))
				var/mob/living/human/RH = L
				target_faction = RH.faction_text
			else if (istype(L, /mob/living/simple_animal))
				var/mob/living/simple_animal/SA = L
				target_faction = SA.faction

			if (!target_faction) continue

			if (target_faction == faction)
				continue

			// Special initiation rule: School and Ministry only attack Moldywart faction on sight.
			if (faction == "School" || faction == "Ministry")
				if (target_faction != "Moldywart")
					continue
			
			if (ishuman(L))
				var/mob/living/human/RH = L
				if (RH in friends) continue
				if (RH.wolfman && istype(src, /mob/living/simple_animal/hostile/wolf)) continue
				if (RH.lizard && istype(src, /mob/living/simple_animal/hostile/alligator)) continue
				// Wild predators leave people alone unless starving or crowded.
				if (!predator_will_hunt(RH)) continue
			else
				if (istype(L, /mob/living/simple_animal/civilian) && istype(src, /mob/living/simple_animal/hostile/human/redmenian_ng)) continue
				if (L in friends) continue
				if (map.ID == MAP_VOYAGE) continue

			// Not seen behind a ridge (los_terrain.dm).
			if (los_terrain_ray_blocked(src, L)) continue
			// Out of reach up a tree (tree_climbing.dm).
			if (!can_reach_tree_climber(L)) continue

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

// Staged pursuit adapter. No type enables it until every movement producer for
// that type has a safe handoff to and from owned partial positions.
/mob/living/simple_animal
	var/npc_subtile_pursuit_enabled = FALSE
	var/tmp/datum/npc_subtile_pursuit/npc_subtile_pursuit

/mob/living/simple_animal/proc/npc_subtile_pursuit_unsettled()
	return npc_subtile_offset_owned && (step_x || step_y)

/mob/living/simple_animal/proc/npc_subtile_stop_pursuit(cancel_pending = TRUE)
	if (cancel_pending)
		npc_subtile_cancel_pending("pursuit")
	var/datum/npc_subtile_pursuit/P = npc_subtile_pursuit
	if (!P)
		return
	P.cancelled = TRUE
	npc_subtile_pursuit = null
	if (move_gen == P.generation)
		npc_subtile_release_generation(P.generation, TRUE)
		moving = FALSE
		found_path = list()
		if (target_obj == P.target)
			target_obj = null

/mob/living/simple_animal/proc/npc_subtile_start_pursuit(mob/living/target, side_direction = 0)
	if (npc_subtile_can_defer())
		return npc_subtile_defer_intent("pursuit", target, null, null, null, side_direction)
	if (!npc_subtile_pursuit_enabled || !npc_subtile_enabled || !npc_subtile_ready() || !target || !SA_attackable(target) || target_mob != target || (side_direction && !(side_direction in alldirs)))
		return FALSE
	if (!((target in view(aggro_vision_range, src)) || (target in view(idle_vision_range, src))))
		return FALSE
	npc_subtile_pending_intent = null
	if (npc_subtile_pursuit && npc_subtile_pursuit.target == target && npc_subtile_pursuit.valid())
		if (side_direction in alldirs)
			npc_subtile_pursuit.pending_side = side_direction
			npc_subtile_pursuit.pending_side_origin = get_turf(src)
			npc_subtile_pursuit.pending_side_target = get_turf(target)
		return TRUE
	npc_subtile_stop_pursuit()
	// Pursuit takes the movement worker, never the durable leash relationship.
	npc_subtile_stop_follow()
	npc_subtile_stop_flee()
	npc_subtile_stop_pet_walk()
	npc_subtile_stop_wild_walk()
	// Stop native and OpenDream flee walkers before taking movement ownership.
	walk(src, 0)
	walk_id = 0
	// Invalidate any older do_movement loop before taking its path state.
	move_gen++
	target_obj = target
	found_path = list()
	moving = TRUE
	var/datum/npc_subtile_pursuit/P = new
	P.actor = src
	P.target = target
	P.generation = move_gen
	P.expected_stance = stance
	if (side_direction in alldirs)
		P.pending_side = side_direction
		P.pending_side_origin = get_turf(src)
		P.pending_side_target = get_turf(target)
	npc_subtile_pursuit = P
	spawn(0)
		P.perform()
	return TRUE

/datum/npc_subtile_pursuit
	should_save = FALSE
	var/mob/living/simple_animal/actor
	var/mob/living/target
	var/generation
	var/expected_stance
	var/pending_side = 0
	var/turf/pending_side_origin
	var/turf/pending_side_target
	var/cancelled = FALSE

/datum/npc_subtile_pursuit/proc/valid()
	return !cancelled && actor && !isDeleted(actor) && actor.npc_subtile_pursuit == src && actor.npc_subtile_pursuit_enabled && actor.npc_subtile_enabled && actor.npc_subtile_ready() && !actor.npc_subtile_pet_walk && actor.moving && actor.move_gen == generation && target && !isDeleted(target) && actor.target_obj == target && actor.target_mob == target && actor.stance == expected_stance && actor.SA_attackable(target) && ((target in view(actor.aggro_vision_range, actor)) || (target in view(actor.idle_vision_range, actor)))

/datum/npc_subtile_pursuit/proc/try_direction(direction, interval)
	if (!valid() || !(direction in alldirs))
		return FALSE
	return actor.ai_step_wait(get_step(actor, direction), interval, src)

// A cancelled pulse can cross a turf boundary before reaching its endpoint.
// Recover one owned axis through native collision before an adjacent attack.
/datum/npc_subtile_pursuit/proc/settle_axis()
	if (!valid() || !actor.npc_subtile_pursuit_unsettled())
		return
	actor.npc_subtile_settle_axis(src, actor.move_to_delay)

// The latest AI-tick side choice waits for the current pulse instead of moving
// concurrently with it. The choice itself is made only by MoveToTarget.
/datum/npc_subtile_pursuit/proc/perform_side(direction, interval)
	if (!valid())
		return
	var/started = world.time
	var/deadline = started + interval
	var/list/before = actor.npc_subtile_snapshot()
	if (!try_direction(direction, interval) && valid() && world.time == started && human_subtile_same(before, actor.npc_subtile_snapshot()))
		try_direction(turn(direction, 180), interval)
	if (valid() && world.time < deadline)
		sleep(deadline - world.time)
	else if (valid() && world.time == started)
		sleep(0)

/datum/npc_subtile_pursuit/proc/perform()
	try
		perform_loop()
	catch (var/exception/npc_pursuit_error)
		finish()
		throw npc_pursuit_error
	finish()

/datum/npc_subtile_pursuit/proc/finish()
	if (actor && !isDeleted(actor) && actor.npc_subtile_pursuit == src)
		actor.npc_subtile_stop_pursuit(FALSE)
	actor = null
	target = null

/datum/npc_subtile_pursuit/proc/perform_loop()
	while (valid() && (get_dist(actor, target) > 1 || actor.npc_subtile_pursuit_unsettled()))
		if (get_dist(actor, target) <= 1 && actor.npc_subtile_pursuit_unsettled())
			settle_axis()
			continue
		var/side_direction = pending_side
		var/turf/side_origin = pending_side_origin
		var/turf/side_target = pending_side_target
		pending_side = 0
		pending_side_origin = null
		pending_side_target = null
		if ((side_direction in alldirs) && get_turf(actor) == side_origin && get_turf(target) == side_target)
			perform_side(side_direction, actor.move_to_delay)
			continue
		if (actor.loc == actor.last_loc)
			actor.stuck_ticks++
		else
			actor.stuck_ticks = 0
			actor.last_loc = actor.loc
		if (actor.stuck_ticks >= 6 && actor.destroy_surroundings)
			actor.DestroySurroundings()
			if (!valid())
				break
			actor.stuck_ticks = 0
		else if (actor.stuck_ticks >= 4)
			actor.found_path = list()
		if (actor.found_path.len)
			var/turf/path_end = actor.found_path[actor.found_path.len]
			if (get_dist(path_end, get_turf(target)) > 2)
				actor.found_path = list()
		var/direction = 0
		if (actor.found_path.len)
			var/turf/next = actor.found_path[1]
			if (actor.loc == next)
				actor.found_path.Cut(1, 2)
				next = actor.found_path.len ? actor.found_path[1] : get_turf(target)
			else if (get_dist(actor, next) > 1)
				actor.found_path = list()
			if (next)
				direction = get_dir(actor, next)
		else
			var/path_found = actor.get_path()
			if (!valid())
				break
			if (!path_found)
				direction = get_dir(actor, target)
		if (!valid())
			break
		var/delay = actor.found_path.len ? actor.move_to_delay : max(actor.move_to_delay, 10)
		var/started = world.time
		var/deadline = started + delay
		if (direction && valid())
			var/list/before = actor.npc_subtile_snapshot()
			var/arrived = try_direction(direction, delay)
			// Only an immediately blocked attempt may try the legacy side choices
			// in the same interval. Partial progress never buys a second interval.
			if (!arrived && valid() && world.time == started && human_subtile_same(before, actor.npc_subtile_snapshot()))
				if (actor.stuck_ticks < 3)
					var/side_dir = pick(turn(direction, 90), turn(direction, -90))
					if (!try_direction(side_dir, delay) && valid() && world.time == started && human_subtile_same(before, actor.npc_subtile_snapshot()))
						try_direction(turn(side_dir, 180), delay)
				else
					actor.DestroySurroundings()
		if (valid() && world.time < deadline)
			sleep(deadline - world.time)
		else if (valid() && world.time == started)
			sleep(0)

/mob/living/simple_animal/proc/MoveToTarget()
	if (!target_mob || !SA_attackable(target_mob))
		if (npc_subtile_pursuit_enabled)
			npc_subtile_stop_pursuit()
		stance = HOSTILE_STANCE_IDLE
		walk(src, 0)
		return
	if (!npc_subtile_enabled && (npc_subtile_transaction || npc_subtile_pulse || (npc_subtile_offset_owned && (step_x || step_y))))
		return
	if (!npc_subtile_enabled && npc_subtile_pursuit)
		npc_subtile_stop_pursuit()
	if (npc_subtile_enabled && npc_subtile_pursuit_enabled)
		// Match the legacy AI-tick stuck observation and random side choice.
		// Physical execution remains serialized with the active pulse.
		if (loc == last_loc)
			stuck_ticks++
		else
			stuck_ticks = 0
			last_loc = loc
		if (target_mob in view(aggro_vision_range, src))
			stance = HOSTILE_STANCE_ATTACK
			if (stuck_ticks >= 3)
				var/dir_to_target = get_dir(src, target_mob)
				var/side_step_dir = pick(turn(dir_to_target, 90), turn(dir_to_target, -90))
				npc_subtile_start_pursuit(target_mob, side_step_dir)
				if (stuck_ticks >= 6 && destroy_surroundings)
					DestroySurroundings()
				stuck_ticks = 0
			else
				npc_subtile_start_pursuit(target_mob)
		else if (target_mob in view(idle_vision_range, src))
			npc_subtile_start_pursuit(target_mob)
		else
			npc_subtile_stop_pursuit()
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
			src.do_movement(target_mob) // Use do_movement for consistent pathfinding

	else if (target_mob in view(idle_vision_range, src))
		src.do_movement(target_mob) // Use do_movement for consistent pathfinding

/mob/living/simple_animal/proc/AttackTarget()
	if (!target_mob || !SA_attackable(target_mob) || !can_reach_tree_climber(target_mob))
		LoseTarget()
		return FALSE
	// A fed predator lets a person who never hurt it back away.
	if (ishuman(target_mob) && !predator_will_hunt(target_mob) && get_dist(src, target_mob) > predator_chase_range)
		LoseTarget()
		return FALSE
	if (!(target_mob in view(aggro_vision_range, src)))
		LostTarget()
		return FALSE
	if (get_dist(src, target_mob) <= 1)
		// Turf adjacency alone is insufficient after an interrupted owned pulse.
		if (npc_subtile_pursuit_enabled && npc_subtile_pursuit_unsettled())
			if (!npc_subtile_pursuit)
				npc_subtile_start_pursuit(target_mob)
			return FALSE
		// AI continues to decide attacks on its normal ticks, after an owned step.
		if (npc_subtile_pursuit_enabled && npc_subtile_pursuit && npc_subtile_transaction)
			return FALSE
		// One bite per cooldown, however many callers reach this in a tick.
		if (uses_paced_bites())
			if (world.time < next_melee_attack)
				return TRUE
			next_melee_attack = world.time + melee_attack_cooldown()
		AttackingTarget()
		return TRUE
	else
		MoveToTarget()

/mob/living/simple_animal/proc/AttackingTarget()
	if (!Adjacent(target_mob))
		return
	playsound(src.loc, attack_sound, 100, TRUE, 2)
	custom_emote(1, "[attack_verb] [target_mob]!")

	// This path applies damage directly, bypassing attack_generic's audit logs.
	// Keep the same attempted-attack semantics, independent of armor or Help.
	if (isliving(target_mob))
		append_attack_log(text("\[[time_stamp()]\] <font color='red'>attacked [target_mob.name] ([target_mob.ckey])</font>"))
		target_mob.append_attack_log(text("\[[time_stamp()]\] <font color='orange'>was attacked by [name] ([ckey])</font>"))
	var/damage = rand(melee_damage_lower, melee_damage_upper)
	if (ishuman(target_mob))
		var/mob/living/human/H = target_mob
		var/obj/item/organ/external/affecting = H.get_organ(animal_bite_zone())
		if (!affecting || affecting.is_stump())
			affecting = H.get_organ("chest")
		// Observe before damage: the same blow may incapacitate the victim.
		// Never disclose an unseen animal or infer injury from the attack emote.
		var/client/observing_client = H.client
		var/observed_attack = observing_client && observing_client.mob == H && observing_client.eye == H && H.stat == CONSCIOUS && H.sleeping <= 0 && !H.blinded && !H.eye_blind && !(H.sdisabilities & BLIND) && !H.find_trait("Blind") && !H.paralysis && H.see_invisible >= invisibility && (src in view(H))
		var/previous_damage = H.getBruteLoss() + H.getBurnLoss()
		var/attached_before = affecting && affecting.owner == H
		var/injury_limb = affecting ? affecting.limb_name : null
		if (istype(src, /mob/living/simple_animal/mouse))
			try_infect(H, 3, "plague")

		if (prob(95) || !can_bite_limbs_off)
			// Bites tear more than they crush: one heavy enough to break a bone
			// only sometimes does. The guard expires by itself after this tick.
			if (!prob(bite_fracture_chance))
				H.bite_fracture_guard = world.time + 1
			H.apply_damage(damage, BRUTE, affecting, H.run_armor_check(affecting, "melee"), sharp=1, edge=1)
			H.bite_fracture_guard = 0
		else
			affecting.droplimb(FALSE, DROPLIMB_EDGE)
			visible_message("\The [src] bites off [H]'s limb!")
			for(var/mob/living/human/NB in view(6, src))
				NB.adjust_mood(-(10), "seeing someone maimed")
		var/lost_limb = attached_before && (!affecting || affecting.owner != H)
		if (observed_attack && player_help_service && (lost_limb || H.getBruteLoss() + H.getBurnLoss() > previous_damage))
			player_help_service.record_animal_injury(observing_client, H, src, injury_limb, lost_limb)
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
					SA.npc_set_combat_target(src)
		return L

// Torso-weighted, so a run of bites wounds rather than wrecks every limb.
/mob/living/simple_animal/proc/animal_bite_zone()
	return pickweight(list("chest" = 29, "groin" = 15, "l_arm" = 9, "r_arm" = 9, "l_leg" = 9, "r_leg" = 9, "l_hand" = 4, "r_hand" = 4, "l_foot" = 4, "r_foot" = 4, "head" = 4))

// Animals that fight through the generic AttackTarget path. Human NPCs,
// wizard-school NPCs and the beetle keep their own attack timing.
/mob/living/simple_animal/proc/uses_paced_bites()
	return !istype(src, /mob/living/simple_animal/hostile/human) && !istype(src, /mob/living/simple_animal/wizard) && !istype(src, /mob/living/simple_animal/hostile/wizard) && !istype(src, /mob/living/simple_animal/hostile/phosphor_beetle)

/mob/living/simple_animal/proc/melee_attack_cooldown()
	if (melee_attack_delay > 0)
		return melee_attack_delay
	return max(20, min(40, move_to_delay * 10))

/mob/living/simple_animal/proc/is_natural_predator()
	return (predatory_carnivore || carnivore) && uses_paced_bites()

// Wild predators only go for a person who is too close, who hurt them, or when starving.
/mob/living/simple_animal/proc/predator_will_hunt(mob/living/L)
	if (!ishuman(L) || !is_natural_predator() || L == provoked_by)
		return TRUE
	// Busy with thrown meat: people are left alone until it is eaten or gone.
	if (is_food_distracted())
		return FALSE
	if (starves && simplehunger < predator_starving_hunger)
		return TRUE
	return get_dist(src, L) <= predator_encroach_range

// A hunting or defending animal that gets hurt turns on its attacker and,
// when it is in reach and its bite is ready, bites back at once.
/mob/living/simple_animal/proc/animal_provoked(mob/living/attacker)
	if (!uses_paced_bites() || client || stat != CONSCIOUS || !istype(attacker) || attacker == src || attacker == rider || attacker.stat == DEAD)
		return FALSE
	if (!(behaviour == "hunt" || behaviour == "defends" || behaviour == "hostile") || uses_defensive_retaliation())
		return FALSE
	if (istype(attacker, /mob/living/simple_animal))
		var/mob/living/simple_animal/SA = attacker
		if (SA.faction == faction)
			return FALSE
	provoked_by = attacker
	end_food_distraction()
	if (!target_mob || target_mob.stat == DEAD || get_dist(src, target_mob) > 1)
		npc_set_combat_target(attacker)
	stance = HOSTILE_STANCE_ATTACK
	stance_step = max(stance_step, 6)
	if (target_mob == attacker && get_dist(src, attacker) <= 1 && world.time >= next_melee_attack && canmove && !resting && !buckled && isturf(loc))
		AttackTarget()
	return TRUE

// Thrown meat draws a starving predator off a person it is chasing or watching.
// An animal anyone has hurt is not fooled, and a fed one has no interest.
/obj/item/weapon/reagent_containers/food/snacks/proc/is_predator_bait()
	return non_vegetarian || istype(src, /obj/item/weapon/reagent_containers/food/snacks/meat) || istype(src, /obj/item/weapon/reagent_containers/food/snacks/rawfish)

/obj/item/weapon/reagent_containers/food/snacks/throw_impact(atom/hit_atom, speed)
	var/mob/living/human/H = thrower
	..()
	if (isturf(hit_atom) && ishuman(H) && !QDELETED(src) && isturf(loc))
		lure_starving_predators(H)

/obj/item/weapon/reagent_containers/food/snacks/proc/lure_starving_predators(mob/living/human/thrower)
	var/turf/T = get_turf(src)
	if (!T || !isturf(loc) || !is_predator_bait())
		return 0
	var/lured = 0
	for (var/mob/living/simple_animal/SA in range(9, T))
		if (SA.distract_with_food(src, thrower))
			lured++
	return lured

/mob/living/simple_animal/proc/distract_with_food(obj/item/weapon/reagent_containers/food/snacks/food, mob/living/human/thrower)
	if (client || stat != CONSCIOUS || !is_natural_predator() || provoked_by || !istype(food) || !isturf(food.loc))
		return FALSE
	if (!starves || simplehunger >= predator_starving_hunger)
		return FALSE
	// Only an animal already after a person: chasing, closing in or watching.
	if (!ishuman(target_mob) || target_mob.stat == DEAD)
		return FALSE
	var/turf/T = food.loc
	var/sight = aggro_vision_range || 9
	if (get_dist(src, T) > sight || !(T in view(sight, src)))
		return FALSE
	var/mob/living/prey = target_mob
	LoseTarget()
	distracted_by = food
	distracted_until = world.time + food_distraction_time
	set_dir(get_dir(src, T))
	visible_message("<span class='notice'>\The [src] turns away from [prey] toward \the [food].</span>")
	if (get_dist(src, T) > 1)
		do_movement(food)
	return TRUE

/mob/living/simple_animal/proc/is_food_distracted()
	if (!distracted_by)
		return FALSE
	if (QDELETED(distracted_by) || !isturf(distracted_by.loc) || world.time > distracted_until || stat != CONSCIOUS)
		end_food_distraction()
		return FALSE
	return TRUE

/mob/living/simple_animal/proc/end_food_distraction()
	if (!distracted_by)
		return
	if (target_obj == distracted_by)
		target_obj = null
		found_path = list()
		move_gen++
		moving = FALSE
	distracted_by = null
	distracted_until = 0

// Each AI tick while distracted: walk to the meat, then eat it. TRUE while busy.
/mob/living/simple_animal/proc/food_distraction_tick()
	if (!is_food_distracted())
		return FALSE
	var/obj/item/weapon/reagent_containers/food/snacks/F = distracted_by
	if (get_dist(src, F) <= 1)
		end_food_distraction()
		npc_subtile_stop_continuous_walk()
		set_dir(get_dir(src, F))
		visible_message("<span class='notice'>\The [src] wolfs down \the [F].</span>")
		finish_eating(400)
		qdel(F)
		return TRUE
	if (!moving || target_obj != F)
		do_movement(F)
	return TRUE

/mob/living/simple_animal/proc/LoseTarget()
	if (npc_subtile_pursuit_enabled)
		npc_subtile_stop_pursuit()
	provoked_by = null
	stance = HOSTILE_STANCE_IDLE
	npc_set_combat_target(null)
	walk(src, FALSE)

/mob/living/simple_animal/proc/LostTarget()
	if (npc_subtile_pursuit_enabled)
		npc_subtile_stop_pursuit()
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
