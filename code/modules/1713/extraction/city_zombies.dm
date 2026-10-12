// City roster is separate from Industrial Scav/PMC population and equipment.
/obj/map_metadata/extraction_survival/modern_city
	var/tmp/list/city_zombies = list()
	population_tick()
		if (round_closing || game_over || world.time < next_population) return
		next_population = world.time + 30 SECONDS
		for (var/mob/living/simple_animal/hostile/human/zombie/extraction_city/Z in city_zombies.Copy())
			if (!Z.loc || Z.stat == DEAD) city_zombies -= Z
		if (city_zombies.len >= 12 || !extraction_npc_markers.len) return
		var/obj/effect/extraction_npc_marker/marker = pick(extraction_npc_markers)
		var/turf/T = get_turf(marker)
		if (!T || !extraction_mission_z(T.z) || T.density) return
		for (var/mob/living/simple_animal/hostile/human/zombie/extraction_city/Z in city_zombies)
			if (Z.z == T.z && get_dist(Z, T) < 2) return
		for (var/owner in accounts.sessions)
			var/datum/extraction_session/S = accounts.sessions[owner]
			if (S.body?.z == T.z && extraction_mission_z(S.body?.z) && get_dist(S.body, T) < 12) return
		var/mob/living/simple_animal/hostile/human/zombie/extraction_city/Z = new(T)
		Z.city = src
		city_zombies += Z

/mob/living/simple_animal/hostile/human/zombie/extraction_city
	name = "city zombie"
	starves = FALSE
	wander = FALSE
	stop_automated_movement = TRUE
	var/tmp/obj/map_metadata/extraction_survival/modern_city/city
	var/tmp/turf/wander_goal
	var/tmp/next_city_decision = 0
	var/tmp/next_city_wander = 0
	var/tmp/list/city_route = list()
	New()
		..()
		should_save = FALSE
	do_human_behaviour()
		return
	handle_ai()
		if (!city || city.game_over || city.round_closing || stat != CONSCIOUS || !extraction_mission_z(z) || world.time < next_city_decision) return
		next_city_decision = world.time + 2 SECONDS
		var/mob/living/human/chosen
		var/best = 8
		// Account admission caps this registry; local visibility caps perception.
		for (var/owner in city.accounts.sessions)
			var/datum/extraction_session/S = city.accounts.sessions[owner]
			var/mob/living/human/H = S.body
			if (!H || H.stat == DEAD || S.profile["state"] != "raid" || H.z != z || !(H in view(7, src))) continue
			var/distance = get_dist(src, H)
			if (distance < best)
				chosen = H
				best = distance
		target_mob = chosen
		if (chosen)
			wander_goal = null
			if (Adjacent(chosen))
				city_route.Cut()
				AttackingTarget()
				return
			city_route = cirrAstar(get_turf(src), get_turf(chosen), 1, 32)
		else
			if (world.time >= next_city_wander)
				next_city_wander = world.time + 10 SECONDS
				// Defend the current neighborhood, then occasionally move locally.
				wander_goal = locate(clamp(x + rand(-3,3), 1, world.maxx), clamp(y + rand(-3,3), 1, world.maxy), z)
				city_route = wander_goal && !wander_goal.density ? cirrAstar(get_turf(src), wander_goal, 1, 32) : list()
		// Native paths include their starting turf; discard it before stepping.
		while (city_route.len && city_route[1] == get_turf(src)) city_route.Cut(1,2)
		if (city_route.len)
			var/turf/next = city_route[1]
			city_route.Cut(1,2)
			if (!step_towards(src, next)) city_route.Cut()
	death()
		if (stat == DEAD) return
		..()
		target_mob = null
		wander_goal = null
		city_route.Cut()
		if (city)
			city.city_zombies -= src
			city.npc_corpses[src] = world.time + 5 MINUTES
	Destroy()
		if (city)
			city.city_zombies -= src
			city.npc_corpses -= src
		city = null
		wander_goal = null
		target_mob = null
		city_route.Cut()
		return ..()
