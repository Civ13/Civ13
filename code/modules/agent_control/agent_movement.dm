// Walking for agent characters (docs/agent-control.md#movement).
//
// A player's step goes through /client/Move, which an agent character (no
// client) never reaches. agent_walk_step applies the same rules to an agent's
// move: the grace-period wall, saving levels, nooses, crouching, restraint and
// pinning, crawling while prone or lying, and the step's cost in time,
// food, water and stamina for the movement mode, ground (snow, mud, flood,
// floor), hills, drowsiness, deployed sarissas, pulling and speed traits.
// tests/agent_control (MovementParityTests) pins the client lines it mirrors.

// Why the character cannot step toward d right now, as /client/Move refuses it, or null.
/proc/agent_walk_refusal(mob/living/M, d, turf/n)
	if (persistence_frozen_levels.len && persistence_frozen_levels["[M.z]"])
		return "this level is being saved; wait a moment"
	for (var/obj/structure/noose/N in get_turf(M))
		if (N.hanging == M)
			return "hanging from a noose"
	if (map)
		var/list/dirs = (d in cornerdirs) ? list(d & (NORTH|SOUTH), d & (EAST|WEST)) : list(d)
		for (var/refdir in dirs)
			var/turf/ref = get_step(M, refdir)
			if (ref && map.check_caribbean_block(M, ref))
				return "the invisible wall cannot be passed until the Grace Period has ended"
	if (ishuman(M))
		var/mob/living/human/H = M
		if (H.crouching)
			return "crouching: stand up first"
	if (M.restrained())
		for (var/mob/P in range(M, 1))
			if (P.pulling == M && !P.restrained() && P.stat == CONSCIOUS && P.canmove && M.Adjacent(P))
				return "restrained and held by [P]"
	if (M.pinned.len)
		return "pinned to a wall by [M.pinned[1]]"
	return null

// Ground slowdown as /client/Move adds it to the movement mode's delay.
/proc/agent_ground_delay(mob/living/human/H, turf/floor/F)
	if (!istype(F) || !ishuman(H) || !isnull(H.riding_mob))
		return 0
	. = 0
	var/covered = locate(/obj/covers) in F
	for (var/obj/effect/flooding/FLD in F)
		switch (FLD.flood_level)
			if (1)
				. = 2
			if (2)
				. = 4
			if (3)
				. = 6
	if (istype(F, /turf/floor/sub_deck))
		var/turf/floor/sub_deck/SD = F
		if (SD.water_depth >= 150)
			. = 6
		else if (SD.water_depth >= 100)
			. = 4
		else if (SD.water_depth >= 50)
			. = 2
	if (F.has_snow_cover() && !covered && !H.lizard)
		. = pick(1.25, 1.75)
	else if (F.muddy && !H.lizard)
		. = rand(2, 3)
	if (istype(F, /turf/floor/trench/flooded))
		. = rand(2, 3)

// One step for an agent character: the player's rules, timing and costs.
// Returns the move's result row; crawling sleeps, so it runs only from the queue.
/datum/agent_control/proc/agent_walk_step(datum/agent_identity/A, datum/agent_character/C, d, from_queue, hold = 5)
	var/mob/living/M = C.body
	var/turf/old = get_turf(M)
	var/turf/n = get_step(M, d)
	// The arrow keys also steer a held wheel, turret controls or drone (agent_vehicles.dm).
	var/list/keys = null
	if (M.stat == CONSCIOUS && agent_holds_arrow_controls(M))
		keys = agent_arrow_keys(M, d, hold)
		// A seat or an active drone keeps the body still (living/Move refuses both).
		if (M.using_drone || M.buckled && !istype(M.buckled, /obj/structure/bed/chair/wheelchair))
			C.next_action = world.time + 2
			return list("moved" = FALSE, "controls" = keys, "self" = character_state(C))
	if (M.stat != CONSCIOUS || !M.canmove)
		agent_fail("cannot_move", "the character cannot move right now")
	if (M.buckled)
		// A wheelchair rolls under its rider's hands; any other seat holds the character.
		if (!istype(M.buckled, /obj/structure/bed/chair/wheelchair))
			agent_fail("cannot_move", "the character is buckled to [M.buckled]")
		var/obj/structure/bed/chair/wheelchair/W = M.buckled
		if (M.confused && prob(40))
			d = pick(cardinal)
		W.relaymove(M, d)
		C.next_action = world.time + max(1, M.movement_delay() + 2)
		return list("moved" = get_turf(M) != old ? TRUE : FALSE, "self" = character_state(C))
	var/why = agent_walk_refusal(M, d, n)
	if (why)
		M.set_dir(d)
		agent_fail("cannot_move", why)
	// Prone or lying: a step is a crawl, which takes its own time.
	if ((M.prone || M.lying) && isturf(n) && n.Adjacent(M))
		agent_queue_only("move while prone or lying", from_queue)
		if (M.lying)
			M.scramble(n)
		else
			M.proning(n)
		var/crawled = get_turf(M) != old
		C.next_action = world.time + 1
		return list("moved" = crawled ? TRUE : FALSE, "crawled" = TRUE, "self" = character_state(C))
	var/mob/living/human/H = ishuman(M) ? M : null
	var/delay = M.movement_delay()
	var/turf/floor/F = old
	var/ground = 0
	if (H)
		ground = agent_ground_delay(H, F)
		if (istype(F) && !H.crab && isnull(H.riding_mob))
			delay += F.move_delay
	if (M.velocity_lastdir != -1 && d != M.velocity_lastdir)
		M.velocity = max(M.velocity - pick(1, 2), 0)
	switch (M.m_intent)
		if ("run")
			M.velocity = min(M.velocity + 1, 15)
			M.velocity_lastdir = d
			delay += M.get_run_delay() + ground
		if ("walk")
			delay += M.get_walk_delay() + ground
		if ("stealth")
			delay += M.get_stealth_delay() + ground
		else
			delay += ground
	delay += terrain_slope_delay(old, n, delay)
	if (M.drowsyness > 0)
		delay += 3
	for (var/obj/item/weapon/material/spear/sarissa/S in list(M.l_hand, M.r_hand))
		if (S.deployed)
			delay += 6
	if (M.pulling)
		if (!M.pulling.Adjacent(M))
			M.stop_pulling()
		else if (ismob(M.pulling))
			delay += 1.25
		else if (istype(M.pulling, /obj/item/weapon/gun/projectile/automatic/stationary))
			delay += 1
		else if (istype(M.pulling, /obj/structure))
			delay += 0.75
	M.Move(n, d)
	var/moved = get_turf(M) != old
	if (moved && H)
		agent_walk_costs(H, old, n)
	var/speed = M.movement_speed_multiplier
	if (M.find_trait("Slowness"))
		speed *= 0.85
	else if (M.find_trait("Agile"))
		speed *= 1.15
	else if (M.original_job_title == "Tuy Phai")
		speed *= 1.25
	if (M.find_trait("Gigantism"))
		speed *= 0.9
	if (H && H.riding && H.riding_mob)
		delay = 0.5
	else
		delay /= max(0.1, speed)
		if (d in cornerdirs)
			delay *= ROOT2_FAST
	C.next_action = world.time + max(1, delay)
	M.last_movement = world.time
	game_log("AGENT", "[A.name] moved [M] ([agent_ref(M)]) [dir2text(d)] [moved ? "moved" : "blocked"] from [old.x],[old.y],[old.z]")
	. = list("moved" = moved ? TRUE : FALSE, "self" = character_state(C))
	if (length(keys))
		.["controls"] = keys

// Food, water, stamina and warmth a step costs, by movement mode, plus hills.
/proc/agent_walk_costs(mob/living/human/H, turf/old, turf/n)
	switch (H.m_intent)
		if ("run")
			H.nutrition -= 0.005
			H.water -= 0.005
			if (H.stats["stamina"][1] > 0)
				H.stats["stamina"][1] -= H.find_trait("Flat Footed") ? 2 : 1
			if (H.bodytemperature < H.species.body_temperature)
				H.bodytemperature += 0.66
			if (H.getStat("stamina") <= 0)
				to_chat(H, SPAN_WARNING("You're too tired to keep running."))
				H.m_intent = "walk"
		if ("walk")
			H.nutrition -= 0.002
			H.water -= 0.002
		if ("stealth")
			H.nutrition -= 0.004
			H.water -= 0.004
		if ("proning")
			H.nutrition -= 0.0015
			H.water -= 0.0015
	terrain_climb_effects(H, old, n, 1)
