// Simple AI logic for non-hostile behaviors (wandering, feeding, etc.)

/mob/living/simple_animal/proc/handle_ai()

	if (stat == DEAD || stat == UNCONSCIOUS)
		return
	if (client || anchored || clients.len <= 0)
		return
	if (stop_automated_movement || !wander)
		if (stance == HOSTILE_STANCE_ATTACK || stance == HOSTILE_STANCE_ALERT)
			ai_tick_delay = 0
			do_behaviour()
			return
		if ((faction == "School" || faction == "Ministry") && stance == HOSTILE_STANCE_IDLE)
			npc_set_combat_target(FindTarget())
			if (target_mob)
				behaviour = "hostile"
				stance = HOSTILE_STANCE_ATTACK
				handle_combat_behaviour("hostile")
				return
		// Fall through to the main AI logic below so enemy detection
		// (FindTarget via do_behaviour) can still run during patrol.

	if (!isturf(loc) || resting || buckled || !canmove)
		return

	// Going for thrown meat comes before any fight or forage.
	if (food_distraction_tick() || predator_feeding_tick())
		return

	// An adjacent fight runs every Life tick and the bite cooldown sets the
	// pace, so walking speed no longer decides how often an animal bites.
	if (stance == HOSTILE_STANCE_ATTACK && target_mob && uses_paced_bites() && get_dist(src, target_mob) <= 1)
		if (world.time >= next_melee_attack)
			AttackTarget()
		return

	turns_since_move++
	if (turns_since_move < move_to_delay)
		return

	if (stop_automated_movement_when_pulled && pulledby)
		return

	// Specific landmark-based movement for skeletal attackers and moldy men
	if (istype(src, /mob/living/simple_animal/hostile/human/skeleton/attacker))
		if (stance == HOSTILE_STANCE_IDLE && prob(20) && get_dist(src, locate(/obj/effect/landmark/npctarget)) > 11)
			src.do_movement(locate(/obj/effect/landmark/npctarget))
			return
	if (map && map.ID == MAP_WIZARD_BOY && istype(src, /mob/living/simple_animal/hostile/wizard/moldy_man/attacker))
		var/obj/map_metadata/wizard_boy/WB = map
		if (WB.moldy_invasion)
			if (stance == HOSTILE_STANCE_IDLE && prob(20) && get_dist(src, locate(/obj/effect/landmark/npctarget)) > 11)
				src.do_movement(locate(/obj/effect/landmark/npctarget))
				return
	if (istype(src, /mob/living/simple_animal/hostile/human/skeleton/attacker_gods))
		var/mob/living/simple_animal/hostile/human/skeleton/attacker_gods/A = src
		if (stance == HOSTILE_STANCE_IDLE && prob(20) && get_dist(src, A.target_loc) > 11)
			src.do_movement(A.target_loc)
			return

	// Hunger/Food check takes priority for idle animals. A fight never stops
	// for food: a hungry predator in ATTACK stance used to forage instead of biting.
	if ((stance == HOSTILE_STANCE_IDLE || stance == HOSTILE_STANCE_TIRED) && ((prob(20) && (herbivore || carnivore || predatory_carnivore || granivore || scavenger) && simplehunger < 220) || simplehunger < 180))
		ai_tick_delay = 0
		check_food()
		return

	// Main behaviour logic with AI logic throttling
	if (stance == HOSTILE_STANCE_ATTACK || stance == HOSTILE_STANCE_ALERT)
		ai_tick_delay = 0
		do_behaviour()
		turns_since_move = 0
	else
		ai_tick_delay++
		if (ai_tick_delay >= ai_tick_delay_max)
			do_behaviour()
			ai_tick_delay = 0
			turns_since_move = 0

/mob/living/simple_animal/proc/do_behaviour(var/t_behaviour = null)
	if (stat == DEAD || stat == UNCONSCIOUS)
		return FALSE
	if (!t_behaviour)
		t_behaviour = behaviour

	switch(t_behaviour)
		if ("scared")
			for (var/mob/living/human/H in range(7, src))
				if (npc_subtile_flee_enabled && npc_subtile_enabled)
					var/list/flee_receipt = list()
					if (npc_subtile_start_flee(H, 7, npc_subtile_native_interval(2), flee_receipt))
						var/list/flee_ticket = flee_receipt["ticket"]
						var/flee_remaining = max(0, flee_ticket["expires_at"] - world.time)
						spawn(flee_remaining)
							npc_subtile_stop_flee_ticket(flee_ticket)
				else if (npc_subtile_enabled || npc_subtile_continuous_legacy_ready("flee"))
					walk_away_od(src, H, 7, 2)
					spawn(50)
						walk(src, 0)
				return "scared"

		if ("wander")
			if (faction == "School" || faction == "Ministry")
				npc_set_combat_target(FindTarget())
				if (target_mob)
					behaviour = "hostile"
					stance = HOSTILE_STANCE_ATTACK
					return handle_combat_behaviour("hostile")

			var/list/valid_dirs = get_valid_move_dirs()
			if (valid_dirs.len)
				var/moving_to = pick(valid_dirs)
				set_dir(moving_to)
				if (ai_step(get_step(src, moving_to), move_to_delay))
					turns_since_move = 0
			return "wander"

		if ("hunt", "defends", "hostile")
			return handle_combat_behaviour(t_behaviour)

	return FALSE

/mob/living/simple_animal/proc/handle_combat_behaviour(t_behaviour)
	// Base implementation for mobs that don't use the hostile stance system
	return FALSE

// Keep a cap on loose manure even before old piles decay: leave no new pile
// while one already lies on or next to this animal's tile.
/mob/living/simple_animal/proc/drop_manure()
	if (mob_size < MOB_MEDIUM || !isturf(loc))
		return null
	for (var/obj/item/weapon/reagent_containers/food/snacks/poo/animal/M in range(1, src))
		return null
	return new/obj/item/weapon/reagent_containers/food/snacks/poo/animal(loc)

/mob/living/simple_animal/proc/finish_eating(var/hunger_gain)
	drop_manure()
	simplehunger = min(simplehunger + hunger_gain, 1000)
	adjustBruteLoss(-4)

/mob/living/simple_animal/proc/check_food()
	// Phase 1: Try to eat food already in close range
	if (herbivore)
		// Grazed grass grows back (wild_feeding.dm) instead of turning to dirt.
		if (prob(33))
			for (var/turf/floor/GT in range(1, src))
				if (!GT.pasture_ready())
					continue
				npc_subtile_stop_continuous_walk()
				GT.graze_down()
				visible_message("\The [src] eats some grass.")
				finish_eating(550)
				return
		for (var/obj/item/weapon/reagent_containers/food/snacks/grown/wheat/WT in range(2, src))
			if (prob(30))
				npc_subtile_stop_continuous_walk()
				visible_message("\The [src] eats some of the wheat.")
				finish_eating(550)
				qdel(WT)
				return

	if (granivore)
		for (var/obj/item/stack/farming/seeds/SD in range(2, src))
			if (!animal_can_eat(SD))
				continue
			if (prob(35))
				npc_subtile_stop_continuous_walk()
				visible_message("<span class='notice'>\The [src] eats \the [SD]!</span>")
				finish_eating(500)
				if (SD.amount >= 2)
					SD.amount -= 1
				else
					qdel(SD)
				return
		for (var/obj/structure/farming/plant/PL in range(2, src))
			if (!animal_can_eat(PL))
				continue
			if (prob(15))
				npc_subtile_stop_continuous_walk()
				visible_message("<span class='notice'>\The [src] eats \the [PL]!</span>")
				finish_eating(400)
				qdel(PL)
				return

	if (carnivore)
		for (var/mob/living/ML in range(2, src))
			if (ML.stat == DEAD && prob(33))
				npc_subtile_stop_continuous_walk()
				visible_message("\The [src] bites some meat of \the [ML].")
				finish_eating(400)
				if (istype(ML, /mob/living/simple_animal))
					var/mob/living/simple_animal/MLL = ML
					if (MLL.mob_size <= 9)
						qdel(ML)
					else if (prob(30))
						qdel(ML)
				return
		for (var/obj/item/weapon/reagent_containers/food/snacks/meat/M in range(2, src))
			if (prob(33))
				npc_subtile_stop_continuous_walk()
				visible_message("\The [src] bites some of \the [M].")
				finish_eating(400)
				qdel(M)
				return

	if (predatory_carnivore)
		for (var/mob/living/ML in range(2, src))
			if (ishuman(ML) && !predator_will_hunt(ML))
				continue
			if ((ML.mob_size <= mob_size || !istype(ML, /mob/living/simple_animal/hostile)) && !istype(ML, type) && !istype(src, ML.type) && istype(src, /mob/living/simple_animal/hostile))
				npc_subtile_stop_continuous_walk()
				var/mob/living/simple_animal/hostile/HS = src
				HS.npc_set_combat_target(ML)
				HS.stance = HOSTILE_STANCE_ATTACK
				if (ML.stat == DEAD)
					var/amt = butcher_yield(ML)
					var/namt = amt-2
					if (namt <= 0)
						namt = 1
					visible_message("<span class='notice'>\The [src] rips \the [ML] apart!</span>")
					simplehunger = min(simplehunger + 400, 1000)
					if (!istype(ML, /mob/living/simple_animal/crab))
						if (istype(ML, /mob/living/simple_animal/hostile/human/zombie))
							for (var/i=0, i<=namt, i++)
								var/obj/item/weapon/reagent_containers/food/snacks/meat/meat = new/obj/item/weapon/reagent_containers/food/snacks/meat(get_turf(src))
								meat.name = "rotten zombie meat"
								meat.radiation = ML.radiation/2
								meat.icon_state = "rottenmeat"
								if (meat.reagents)
									meat.reagents.remove_reagent("protein", 2)
									meat.reagents.add_reagent("food_poisoning", 1)
									meat.note_food_toxin("zombie meat")
								meat.rotten = TRUE
								meat.satisfaction = -30
						else
							for (var/i=0, i<=namt, i++)
								var/obj/item/weapon/reagent_containers/food/snacks/meat/meat = new/obj/item/weapon/reagent_containers/food/snacks/meat(get_turf(src))
								meat.name = "[ML.name] meat"
								meat.radiation = ML.radiation/2
					else
						for (var/i=0, i<=namt, i++)
							var/obj/item/weapon/reagent_containers/food/snacks/rawcrab/meat = new/obj/item/weapon/reagent_containers/food/snacks/rawcrab(get_turf(src))
							meat.radiation = ML.radiation/2
					if ((amt-2) >= 1)
						// Do not merge before the new pile has its carcass identity.
						var/obj/item/stack/material/bone/bone = new(get_turf(src), amt-2, FALSE)
						bone.name = "[ML.name] bone"
						bone.radiation = ML.radiation/2
					ML.crush()
					qdel(ML)
				return

	if (scavenger)
		for (var/obj/item/weapon/reagent_containers/food/snacks/FD in range(2, src))
			if (prob(33) && !istype(FD, /obj/item/weapon/reagent_containers/food/snacks/poo))
				npc_subtile_stop_continuous_walk()
				visible_message("\The [src] bites some of \the [FD].")
				finish_eating(400)
				if (prob(60))
					qdel(FD)
				return

	// Wild seed eaters and grazers forage pasture, shrubs and desert plants.
	if (forage_wild())
		return

	// Phase 2: No food in close range, walk toward distant food
	if (herbivore)
		for (var/turf/floor/GT in range(6, src))
			if (!GT.pasture_ready())
				continue
			smart_step_towards(GT)
			return

	if (granivore)
		for (var/obj/structure/farming/plant/PL in range(8, src))
			if (!animal_can_eat(PL))
				continue
			smart_step_towards(PL)
			return

	if (seek_wild_forage())
		return

	if (carnivore)
		for (var/mob/living/ML in range(9, src))
			if (ML.stat == DEAD)
				smart_step_towards(ML)
				return

	if (predatory_carnivore)
		for (var/mob/living/ML in range(9, src))
			if (ishuman(ML) && !predator_will_hunt(ML))
				continue
			if ((ML.mob_size <= mob_size || !istype(ML, /mob/living/simple_animal/hostile)) && !istype(ML, type) && !istype(src, ML.type))
				smart_step_towards(ML)
				return

	if (scavenger)
		for (var/obj/item/weapon/reagent_containers/food/snacks/FD in range(8, src))
			if (!istype(FD, /obj/item/weapon/reagent_containers/food/snacks/poo))
				smart_step_towards(FD)
				return
