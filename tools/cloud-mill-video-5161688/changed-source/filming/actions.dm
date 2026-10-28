// Explicitly staged stock manual mill and wheat on authored outdoor terrain.
// No construction/payment/original-mill-location or cross-run identity claim.
#define MILL_VIDEO_RELEASED TRUE
var/mob/living/human/intro_actor/mill_actor
var/mill_observing_work = FALSE
var/list/mill_progress_observations = list()
var/list/mill_expected_coefficients
var/obj/structure/mill/film_mill
var/obj/item/weapon/reagent_containers/food/snacks/grown/wheat/mill_input

/proc/mill_prepare()
	var/turf/mill_tile = locate(10,6,1)
	var/turf/actor_tile = locate(10,5,1)
	intro_check(istype(mill_tile, /turf/floor/beach/sand/desert) && istype(actor_tile, /turf/floor/beach/sand/desert) && !mill_tile.density && !mill_tile.opacity && !actor_tile.density && !actor_tile.opacity, "authored clear outdoor stage turfs")
	for (var/atom/movable/A in mill_tile)
		intro_check(!A.density && !A.opacity, "mill stage unobstructed")
	for (var/atom/movable/A in actor_tile)
		intro_check(!A.density && !A.opacity, "actor stage unobstructed")
	film_mill = new /obj/structure/mill(mill_tile)
	intro_check(film_mill.type == /obj/structure/mill && film_mill.anchored && !film_mill.current_work && !film_mill.opacity, "stock staged manual mill with native defaults")
	mill_actor = new(actor_tile)
	mill_actor.real_name = "Miller"
	mill_actor.name = "Miller"
	mill_actor.lastarea = get_area(mill_actor)
	mill_actor.dir = NORTH
	mill_actor.equip_to_slot(new /obj/item/clothing/under/civ4(mill_actor), slot_w_uniform)
	mill_actor.equip_to_slot(new /obj/item/clothing/shoes/leatherboots(mill_actor), slot_shoes)
	mill_input = new(mill_actor.loc)
	mill_input.attack_hand(mill_actor)
	intro_check(!mill_actor.client && !mill_actor.ckey && !mill_actor.incapacitated() && mill_actor.get_active_hand() == mill_input && film_mill.Adjacent(mill_actor), "staged wheat in capable miller hand")
	// Observe native stats; never improve them to shorten work.
	intro_check(mill_actor.getStatCoeff("strength") == 1 && mill_actor.getStatCoeff("stamina") == 1 && mill_actor.getStatCoeff("dexterity") == 1, "unchanged baseline work coefficients")
	intro_check(STAMINA_LOSS_BASE_PER_DECISECOND_SDS_OF_WORK == 0 && MOOD_LOSS_PER_DECISECOND_OF_PHYSICAL_WORK == 0, "production work charges currently zero")

// Read-only observation. No production callback, work, timer, stat or mood override.
/proc/mill_observe_work()
	var/last_progress = -1
	while (mill_observing_work && !intro_stopping)
		var/strength = mill_actor.getStatCoeff("strength")
		var/stamina = mill_actor.getStatCoeff("stamina")
		var/dexterity = mill_actor.getStatCoeff("dexterity")
		intro_check(mill_actor.stats["strength"][1] == 100 && mill_actor.stats["stamina"][1] == 100 && mill_actor.stats["dexterity"][1] == 100 && strength == mill_expected_coefficients[1] && stamina == mill_expected_coefficients[2] && dexterity == mill_expected_coefficients[3], "unchanged native raw stats and effective coefficients during work")
		if (film_mill.complete_percent != last_progress)
			intro_check(mill_progress_observations.len < 9, "bounded read-only progress observations")
			mill_progress_observations += list(list("time" = world.time, "progress" = film_mill.complete_percent, "strength_coeff" = strength, "stamina_coeff" = stamina, "dexterity_coeff" = dexterity, "raw_strength" = mill_actor.stats["strength"][1], "raw_stamina" = mill_actor.stats["stamina"][1], "raw_dexterity" = mill_actor.stats["dexterity"][1], "mood_modifier" = mill_actor.mood_modifier))
			last_progress = film_mill.complete_percent
		sleep(0.5)

/proc/mill_take()
	intro_check(MILL_VIDEO_RELEASED, "reviewed manual milling")
	var/start_time = world.time
	var/input_ref = "\ref[mill_input]"
	var/strength = mill_actor.getStatCoeff("strength")
	var/stamina = mill_actor.getStatCoeff("stamina")
	var/dexterity = mill_actor.getStatCoeff("dexterity")
	intro_check(strength > 0 && stamina > 0 && dexterity > 0 && mill_actor.stats["strength"][1] == 100 && mill_actor.stats["stamina"][1] == 100 && mill_actor.stats["dexterity"][1] == 100, "unmodified raw stats at work admission")
	// Exact production formula, evaluated before work; never refit after completion.
	var/work_increment = 6*strength + 6*stamina + 3*dexterity
	var/work_steps = ceil(100/work_increment)
	intro_check(work_steps >= 1 && 5 + work_steps*10 < 80, "source-derived normal work fits unchanged capture window")
	mill_expected_coefficients = list(strength, stamina, dexterity)
	var/list/old_flour = list()
	for (var/obj/item/weapon/reagent_containers/food/condiment/flour/F in film_mill.loc)
		old_flour += F
	text2file(json_encode(list("phase" = "before", "time" = start_time, "actor" = "\ref[mill_actor]", "mill" = "\ref[film_mill]", "input" = input_ref, "input_staged" = TRUE, "mill_staged" = TRUE, "original_mill_location_claim" = FALSE, "strength_coeff" = strength, "stamina_coeff" = stamina, "dexterity_coeff" = dexterity, "raw_strength" = mill_actor.stats["strength"][1], "raw_stamina" = mill_actor.stats["stamina"][1], "raw_dexterity" = mill_actor.stats["dexterity"][1], "mood_modifier" = mill_actor.mood_modifier, "work_increment" = work_increment, "work_steps" = work_steps, "requested_wait_ds" = 10, "stamina_cost_constant" = STAMINA_LOSS_BASE_PER_DECISECOND_SDS_OF_WORK, "mood_cost_constant" = MOOD_LOSS_PER_DECISECOND_OF_PHYSICAL_WORK)), "intro-state-before.json")
	intro_check(!mill_actor.incapacitated() && mill_actor.get_active_hand() == mill_input && film_mill.Adjacent(mill_actor), "native mill input preconditions")
	// Half a second shows the staged input; every source-derived work step retains do_after(10).
	sleep(5)
	var/work_started = world.time
	// Observe real progress alongside the unchanged blocking production handler.
	mill_observing_work = TRUE
	spawn(0)
		mill_observe_work()
	film_mill.attackby(mill_input, mill_actor)
	mill_observing_work = FALSE
	text2file(json_encode(list("phase" = "work_completion_diagnostic", "work_started" = work_started, "time" = world.time, "work_increment" = work_increment, "work_steps" = work_steps, "observed_progress" = mill_progress_observations, "input_consumed" = QDELETED(mill_input), "current_work" = !!film_mill.current_work, "current_progress" = film_mill.complete_percent)), "intro-checks.txt")
	intro_check(world.time - work_started >= work_steps*10 && world.time - start_time < 80 && QDELETED(mill_input), "source-derived normal work waits and material consumption")
	// finish_work immediately resets progress; the final increment is evidenced by
	// normal completion/output, not mislabelled as a directly sampled 100+ value.
	intro_check(mill_progress_observations.len == work_steps, "initial zero and every pre-completion work increment observed")
	for (var/i = 1, i <= mill_progress_observations.len, i++)
		var/list/row = mill_progress_observations[i]
		intro_check(abs(row["progress"] - (i-1)*work_increment) < 0.001 && row["time"] >= work_started + (i-1)*10, "observed real progress matches unchanged work formula and waits")
	intro_check(!film_mill.current_work && !film_mill.current_material && film_mill.complete_percent == 0, "normal mill completion cleared work")
	var/obj/item/weapon/reagent_containers/food/condiment/flour/output
	for (var/obj/item/weapon/reagent_containers/food/condiment/flour/F in film_mill.loc)
		if (!(F in old_flour))
			intro_check(!output, "exactly one fresh flour sack")
			output = F
	intro_check(output && output.type == /obj/item/weapon/reagent_containers/food/condiment/flour && output.reagents.get_reagent_amount("flour") == 10, "native ten-unit flour output")
	var/output_ref = "\ref[output]"
	intro_check(!mill_actor.get_active_hand() && output.Adjacent(mill_actor), "flour pickup reach")
	output.attack_hand(mill_actor)
	intro_check(mill_actor.get_active_hand() == output, "same milled flour picked up")
	text2file(json_encode(list("phase" = "after", "time" = world.time, "actor" = "\ref[mill_actor]", "mill" = "\ref[film_mill]", "input" = input_ref, "input_consumed" = TRUE, "mill_staged" = TRUE, "original_mill_location_claim" = FALSE, "produced_ref" = output_ref, "picked_ref" = "\ref[output]", "actor_holds_output" = output.loc == mill_actor, "flour_units" = output.reagents.get_reagent_amount("flour"), "work_started" = work_started, "work_elapsed" = world.time - work_started, "work_increment" = work_increment, "work_steps" = work_steps, "observed_progress" = mill_progress_observations, "final_increment_evidence" = "native finish_work output and cleared work; not directly sampled", "mill_idle" = !film_mill.current_work && !film_mill.current_material)), "intro-state-after.json")
	text2file(json_encode(list("source" = "58404f5bd16e3fed80f1d9844c5db3edd144942c", "engine" = "516.1688", "world_fps" = world.fps, "elapsed_deciseconds" = world.time - start_time, "scope" = "staged stock mill and wheat on authored outdoor terrain; normal manual mill waits/material transformation; no construction, original mill location, cross-run identity or nonzero work-cost claim")), "intro-take.json")
