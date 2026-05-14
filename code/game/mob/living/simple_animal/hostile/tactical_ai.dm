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
