/proc/extraction_city_zombie_probe(obj/map_metadata/extraction_survival/modern_city/M, mob/living/human/A, mob/living/human/B)
	var/turf/old_a = get_turf(A)
	var/turf/old_b = get_turf(B)
	A.forceMove(locate(1,1,2))
	B.forceMove(locate(1,1,2))
	for (var/i in 1 to 40)
		M.next_population = 0
		M.population_tick()
	equipment_assert(M.city_zombies.len > 0 && M.city_zombies.len <= 12 && !M.npcs.len, "city markers spawn bounded zombie roster without Industrial Scav or PMC actors")
	var/count = M.city_zombies.len
	M.population_tick()
	equipment_assert(M.city_zombies.len == count, "city population cooldown prevents duplicate spawns")
	// Explicitly fill the bounded roster with native actors to exercise its cap.
	while (M.city_zombies.len < 12)
		var/mob/living/simple_animal/hostile/human/zombie/extraction_city/filler = new(locate(48,48,1))
		filler.city = M
		M.city_zombies += filler
	M.next_population = 0
	M.population_tick()
	equipment_assert(M.city_zombies.len == 12, "full city roster rejects another spawn before selecting a marker")
	for (var/mob/living/simple_animal/hostile/human/zombie/extraction_city/Z in M.city_zombies.Copy())
		equipment_assert(Z.bodyparts.len && Z.overlays.len && !Z.should_save && !Z.gun, "city zombie inherits native limb appearance without invented armed loot")
		qdel(Z)
	M.city_zombies.Cut()
	var/mob/living/simple_animal/hostile/human/zombie/extraction_city/Z = new(locate(48,48,1))
	Z.city = M
	M.city_zombies += Z
	var/turf/start = get_turf(Z)
	equipment_assert(!start.density, "city central street physically supports zombie wandering")
	for (var/i in 1 to 32)
		Z.next_city_decision = 0
		Z.next_city_wander = 0
		Z.handle_ai()
		if (get_turf(Z) != start) break
	equipment_assert(get_turf(Z) != start && !Z.target_mob && Z.city_route.len <= 32, "idle city zombie takes actual bounded local wander steps")
	var/decision = Z.next_city_decision
	var/turf/stopped = get_turf(Z)
	Z.handle_ai()
	equipment_assert(Z.next_city_decision == decision && get_turf(Z) == stopped, "city idle AI remains rate limited between scheduler decisions")
	A.forceMove(locate(Z.x + 3, Z.y, 1))
	Z.next_city_decision = 0
	Z.handle_ai()
	equipment_assert(Z.target_mob == A && Z.city_route.len <= 32, "city zombie defends visible area against actual admitted raid survivor")
	A.forceMove(locate(1,1,2))
	// Keep idle wandering on cooldown and retain a real native pursuit path.
	// The old code steps along that path despite having lost its visible target.
	Z.next_city_wander = world.time + 10 SECONDS
	Z.city_route = cirrAstar(get_turf(Z), locate(Z.x + 2, Z.y, Z.z), 1, 32)
	equipment_assert(Z.city_route.len > 1, "lost-target fixture retains a traversable native pursuit route")
	var/turf/lost_position = get_turf(Z)
	Z.next_city_decision = 0
	Z.handle_ai()
	equipment_assert(!Z.target_mob && !Z.city_route.len && !Z.wander_goal && get_turf(Z) == lost_position, "zombie lost perception cancels pursuit before idle cooldown expires")
	// Native deletion can clear a mob reference before the next AI decision.
	Z.target_mob = null
	Z.city_pursuing = TRUE
	Z.city_route = cirrAstar(get_turf(Z), locate(Z.x + 2, Z.y, Z.z), 1, 32)
	Z.next_city_decision = 0
	Z.handle_ai()
	equipment_assert(!Z.city_pursuing && !Z.city_route.len && get_turf(Z) == lost_position, "cleared target reference cannot preserve cached zombie pursuit")
	A.forceMove(old_a)
	B.forceMove(old_b)
	Z.death()
	equipment_assert(!M.city_zombies.len && M.npc_corpses[Z] && !Z.target_mob && !Z.city_route.len, "zombie death releases active roster and bounds corpse lifetime")
	M.npc_corpses[Z] = world.time
	M.tick()
	equipment_assert((!Z || !Z.loc) && !M.npc_corpses.len, "city tick retires expired zombie through existing bounded corpse lifecycle")
