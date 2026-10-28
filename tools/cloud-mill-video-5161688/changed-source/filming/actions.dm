// Fresh review candidate; unpublished: authored manual mill, staged wheat, unchanged work.
#define MILL_VIDEO_RELEASED TRUE
var/mob/living/human/intro_actor/mill_actor
var/obj/structure/mill/film_mill
var/obj/item/weapon/reagent_containers/food/snacks/grown/wheat/mill_input

/proc/mill_prepare()
	film_mill = locate(/obj/structure/mill) in locate(8,8,1)
	intro_check(film_mill && film_mill.type == /obj/structure/mill && film_mill.anchored && !film_mill.current_work, "authored idle manual mill")
	mill_actor = new(locate(8,7,1))
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

/proc/mill_take()
	intro_check(MILL_VIDEO_RELEASED, "reviewed manual milling")
	var/start_time = world.time
	var/input_ref = "\ref[mill_input]"
	var/list/old_flour = list()
	for (var/obj/item/weapon/reagent_containers/food/condiment/flour/F in film_mill.loc)
		old_flour += F
	text2file(json_encode(list("phase" = "before", "time" = start_time, "actor" = "\ref[mill_actor]", "mill" = "\ref[film_mill]", "input" = input_ref, "input_staged" = TRUE, "strength_coeff" = mill_actor.getStatCoeff("strength"), "stamina_coeff" = mill_actor.getStatCoeff("stamina"), "dexterity_coeff" = mill_actor.getStatCoeff("dexterity"), "stamina_cost_constant" = STAMINA_LOSS_BASE_PER_DECISECOND_SDS_OF_WORK, "mood_cost_constant" = MOOD_LOSS_PER_DECISECOND_OF_PHYSICAL_WORK)), "intro-state-before.json")
	intro_check(!mill_actor.incapacitated() && mill_actor.get_active_hand() == mill_input && film_mill.Adjacent(mill_actor), "native mill input preconditions")
	// Half a second shows the staged input; ordinary work still takes seven seconds.
	sleep(5)
	var/work_started = world.time
	// Blocking ordinary handler performs all seven native do_after work steps.
	film_mill.attackby(mill_input, mill_actor)
	intro_check(world.time - work_started >= 70 && world.time - start_time < 80 && QDELETED(mill_input), "normal work time and material consumption")
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
	text2file(json_encode(list("phase" = "after", "time" = world.time, "actor" = "\ref[mill_actor]", "mill" = "\ref[film_mill]", "input" = input_ref, "input_consumed" = TRUE, "produced_ref" = output_ref, "picked_ref" = "\ref[output]", "actor_holds_output" = output.loc == mill_actor, "flour_units" = output.reagents.get_reagent_amount("flour"), "work_started" = work_started, "work_elapsed" = world.time - work_started, "mill_idle" = !film_mill.current_work && !film_mill.current_material)), "intro-state-after.json")
	text2file(json_encode(list("source" = "58404f5bd16e3fed80f1d9844c5db3edd144942c", "engine" = "516.1688", "world_fps" = world.fps, "elapsed_deciseconds" = world.time - start_time, "scope" = "staged wheat; normal manual mill waits/material transformation; no cross-run identity or nonzero work-cost claim")), "intro-take.json")
