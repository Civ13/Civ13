// Simple AI logic for non-hostile behaviors (wandering, feeding, etc.)

/mob/living/simple_animal/proc/handle_ai()
	if (client || stop_automated_movement || !wander || anchored || clients.len <= 0)
		return
	if (!isturf(loc) || resting || buckled || !canmove)
		return

	turns_since_move++
	if (turns_since_move < move_to_delay)
		return

	if (stop_automated_movement_when_pulled && pulledby)
		return

	// Specific landmark-based movement for skeletal attackers
	if (istype(src, /mob/living/simple_animal/hostile/human/skeleton/attacker))
		if (prob(20) && get_dist(src, locate(/obj/effect/landmark/npctarget)) > 11)
			walk_towards(src, locate(/obj/effect/landmark/npctarget), 6)
			return
	if (istype(src, /mob/living/simple_animal/hostile/human/skeleton/attacker_gods))
		var/mob/living/simple_animal/hostile/human/skeleton/attacker_gods/A = src
		if (prob(20) && get_dist(src, A.target_loc) > 11)
			walk_towards(src, A.target_loc, 6)
			return

	// Hunger/Food check takes priority for idle animals
	if (((stance == HOSTILE_STANCE_IDLE || stance == HOSTILE_STANCE_TIRED) && (prob(20) && (herbivore || carnivore || predatory_carnivore || granivore || scavenger) && simplehunger < 220)) || simplehunger < 180)
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
				walk_away_od(src, H, 7, 2)
				spawn(50)
					walk(src, 0)
				return "scared"

		if ("wander")
			var/moving_to = pick(cardinal)
			set_dir(moving_to)
			Move(get_step(src, moving_to))
			turns_since_move = 0
			return "wander"

		if ("hunt", "defends", "hostile")
			return handle_combat_behaviour(t_behaviour)

	return FALSE

/mob/living/simple_animal/proc/handle_combat_behaviour(t_behaviour)
	// Base implementation for mobs that don't use the hostile stance system
	return FALSE

/mob/living/simple_animal/proc/check_food()
	var/totalcount = herbivore+granivore+carnivore+predatory_carnivore+scavenger
	if (totalcount <= 0)
		return
	
	// Evaluate all diet types sequentially to allow for omnivores.
	
	if (herbivore)
		for(var/turf/floor/grass/GT in range(2,src))
			walk(src, 0)
			eat()
			return
		for(var/obj/item/weapon/reagent_containers/food/snacks/grown/wheat/WT in range(2,src))
			walk(src, 0)
			eat()
			return
		for(var/turf/floor/grass/GT in range(6,src))
			step_towards(src, GT)
			return

	if (granivore)
		for(var/obj/item/stack/farming/seeds/WT in range(2,src))
			walk(src, 0)
			eat()
			return
		for(var/obj/structure/farming/plant/PL in range(2,src))
			walk(src, 0)
			eat()
			return
		for(var/obj/structure/farming/plant/PL in range(8,src))
			step_towards(src, PL)
			return

	if (carnivore)
		for(var/mob/living/ML in range(2,src))
			if (ML.stat == DEAD)
				walk(src, 0)
				eat()
				return
		for(var/mob/living/ML in range(9,src))
			if (ML.stat == DEAD)
				step_towards(src, ML)
				return

	if (predatory_carnivore)
		for(var/mob/living/ML in range(2,src))
			if (((ML.mob_size <= mob_size && istype(ML, /mob/living/simple_animal/hostile)) || !istype(ML, /mob/living/simple_animal/hostile)) && !istype(ML, type) && !istype(src, ML.type))
				walk(src, 0)
				eat()
				return
		for(var/mob/living/ML in range(9,src))
			if (((ML.mob_size <= mob_size && istype(ML, /mob/living/simple_animal/hostile)) || !istype(ML, /mob/living/simple_animal/hostile)) && !istype(ML, type) && !istype(src, ML.type))
				step_towards(src, ML)
				return

	if (scavenger)
		for(var/obj/item/weapon/reagent_containers/food/snacks/FD in range(2,src))
			if(!istype(FD, /obj/item/weapon/reagent_containers/food/snacks/poo))
				walk(src, 0)
				eat()
				return
		for(var/obj/item/weapon/reagent_containers/food/snacks/FD in range(8,src))
			if(!istype(FD, /obj/item/weapon/reagent_containers/food/snacks/poo))
				step_towards(src, FD)
				return

/mob/living/simple_animal/proc/eat()
	var/totalcount = herbivore+granivore+carnivore+predatory_carnivore+scavenger
	if (totalcount <= 0)
		return

	if (herbivore)
		var/fed = FALSE
		if (prob(33))
			for(var/turf/floor/grass/GT in range(1,src))
				GT.grassamt -= 1
				if (GT.grassamt <= 0)
					if (istype(GT, (/turf/floor/grass/jungle)))
						GT.ChangeTurf(/turf/floor/dirt/jungledirt)
					else
						GT.ChangeTurf(/turf/floor/dirt)
				fed = TRUE
			if (fed == TRUE)
				visible_message("\The [src] eats some grass.")
				if (mob_size >= MOB_MEDIUM)
					new/obj/item/weapon/reagent_containers/food/snacks/poo/animal(src.loc)
				simplehunger += 550
				adjustBruteLoss(-4)
				return

		for(var/obj/item/weapon/reagent_containers/food/snacks/grown/wheat/WT in range(2,src))
			if (prob(30))
				visible_message("\The [src] eats some of the wheat.")
				if (mob_size >= MOB_MEDIUM)
					new/obj/item/weapon/reagent_containers/food/snacks/poo/animal(src.loc)
				simplehunger += 550
				adjustBruteLoss(-4)
				qdel(WT)
				return

	if (granivore)
		for(var/obj/item/stack/farming/seeds/SD in range(2,src))
			if (prob(35))
				visible_message("<span class='notice'>\The [src] eats \the [SD]!</span>")
				if (mob_size >= MOB_MEDIUM)
					new/obj/item/weapon/reagent_containers/food/snacks/poo/animal(src.loc)
				simplehunger += 500
				adjustBruteLoss(-4)
				if(SD.amount >= 2)
					SD.amount -= 1
				else
					qdel(SD)
				return
		for(var/obj/structure/farming/plant/PL in range(2,src))
			if (prob(15))
				visible_message("<span class='notice'>\The [src] eats \the [PL]!</span>")
				if (mob_size >= MOB_MEDIUM)
					new/obj/item/weapon/reagent_containers/food/snacks/poo/animal(src.loc)
				simplehunger += 400
				adjustBruteLoss(-4)
				qdel(PL)
				return


	if (carnivore)
		for(var/mob/living/ML in range(2,src))
			if (ML.stat == DEAD)
				if (prob(33))
					if (mob_size >= MOB_MEDIUM)
						new/obj/item/weapon/reagent_containers/food/snacks/poo/animal(src.loc)
					visible_message("\The [src] bites some meat of \the [ML].")
					simplehunger += 400
					adjustBruteLoss(-4)
					if (istype(ML, /mob/living/simple_animal))
						var/mob/living/simple_animal/MLL = ML
						if (MLL.mob_size <= 9)
							qdel(ML)
						else
							if (prob(30))
								qdel(ML)
						return
		for(var/obj/item/weapon/reagent_containers/food/snacks/meat/M in range(2,src))
			if (prob(33))
				visible_message("\The [src] bites some of \the [M].")
				if (mob_size >= MOB_MEDIUM)
					new/obj/item/weapon/reagent_containers/food/snacks/poo/animal(src.loc)
				simplehunger += 400
				adjustBruteLoss(-4)
				qdel(M)
				return

	if (scavenger)
		for(var/obj/item/weapon/reagent_containers/food/snacks/FD in range(2,src))
			if (prob(33) && !istype(FD, /obj/item/weapon/reagent_containers/food/snacks/poo))
				visible_message("\The [src] bites some of \the [FD].")
				if (mob_size >= MOB_MEDIUM)
					new/obj/item/weapon/reagent_containers/food/snacks/poo/animal(src.loc)
				simplehunger += 400
				adjustBruteLoss(-4)
				if (prob(60))
					qdel(FD)
					return


	if (predatory_carnivore)
		for(var/mob/living/ML in range(2,src))
			if (((ML.mob_size <= mob_size && istype(ML, /mob/living/simple_animal/hostile)) || !istype(ML, /mob/living/simple_animal/hostile)) && !istype(ML, type) && !istype(src, ML.type) && istype(src, /mob/living/simple_animal/hostile))
				var/mob/living/simple_animal/hostile/HS = src
				HS.target_mob = ML
				HS.stance = HOSTILE_STANCE_ATTACK
				if (ML.stat == DEAD)
					var/amt = 0
					if (ML.mob_size == MOB_MINISCULE)
						amt = 1
					if (ML.mob_size == MOB_TINY)
						amt = 2
					if (ML.mob_size == MOB_SMALL)
						amt = 3
					if (ML.mob_size == MOB_MEDIUM)
						amt = 4
					if (ML.mob_size == MOB_LARGE)
						amt = 5
					if (ML.mob_size == MOB_HUGE)
						amt = 8
					var/namt = amt-2
					if (namt <= 0)
						namt = 1
					visible_message("<span class='notice'>\The [src] rips \the [ML] apart!</span>")
					simplehunger += 400
					if (!istype(ML, /mob/living/simple_animal/crab))
						if (istype(ML, /mob/living/simple_animal/hostile/human/zombie))
							for (var/i=0, i<=namt, i++)
								var/obj/item/weapon/reagent_containers/food/snacks/meat/meat = new/obj/item/weapon/reagent_containers/food/snacks/meat(get_turf(src))
								meat.name = "rotten zombie meat"
								meat.radiation = radiation/2
								meat.icon_state = "rottenmeat"
								if (meat.reagents)
									meat.reagents.remove_reagent("protein", 2)
									meat.reagents.add_reagent("food_poisoning", 1)
								meat.rotten = TRUE
								meat.satisfaction = -30
						else
							for (var/i=0, i<=namt, i++)
								var/obj/item/weapon/reagent_containers/food/snacks/meat/meat = new/obj/item/weapon/reagent_containers/food/snacks/meat(get_turf(src))
								meat.name = "[name] meat"
								meat.radiation = radiation/2
					else
						for (var/i=0, i<=namt, i++)
							var/obj/item/weapon/reagent_containers/food/snacks/rawcrab/meat = new/obj/item/weapon/reagent_containers/food/snacks/rawcrab(get_turf(src))
							meat.radiation = radiation/2

					if ((amt-2) >= 1)
						var/obj/item/stack/material/bone/bone = new/obj/item/stack/material/bone(get_turf(src))
						bone.name = "[name] bone"
						bone.amount = (amt-2)
					ML.crush()
					qdel(ML)
		return