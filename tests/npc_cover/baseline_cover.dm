// Frozen baseline: find_best_cover() from tactical_ai.dm at
// 1627730ecec53f385cbf1956b7a9e4385dffa675, so the parity check needs no Git history.
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

