// Fresh review candidate; unpublished: three authored crops staged mature before recording.
// No planting/growth-duration/cost claim. Native harvest and yields unchanged.
#define HARVEST_VIDEO_RELEASED TRUE
var/mob/living/human/intro_actor/harvest_actor
var/obj/item/weapon/material/scythe/harvest_tool
var/list/harvest_targets = list()

/proc/harvest_prepare()
	harvest_actor = new(locate(8,8,1))
	harvest_actor.real_name = "Farmer"
	harvest_actor.name = "Farmer"
	harvest_actor.lastarea = get_area(harvest_actor)
	harvest_actor.dir = NORTH
	harvest_actor.equip_to_slot(new /obj/item/clothing/under/civ4(harvest_actor), slot_w_uniform)
	harvest_actor.equip_to_slot(new /obj/item/clothing/shoes/leatherboots(harvest_actor), slot_shoes)
	harvest_tool = new(harvest_actor.loc)
	harvest_tool.attack_hand(harvest_actor)
	intro_check(!harvest_actor.client && !harvest_actor.ckey && !harvest_actor.incapacitated() && harvest_actor.get_active_hand() == harvest_tool, "headless capable farmer holds normal scythe")
	for (var/tx in list(7,8,9))
		var/obj/structure/farming/plant/wheat/P = locate(/obj/structure/farming/plant/wheat) in locate(tx,9,1)
		intro_check(P && istype(get_turf(P), /turf/floor/dirt/ploughed) && P.Adjacent(harvest_actor) && !P.vstatic, "authored reachable wheat target")
		// Explicit initial-state staging, never claimed as observed plant growth.
		// Match the existing growth() mature branch; leave scheduled waits intact.
		P.stage = P.readyStageMin
		var/sprite_name = P.sprite_plant ? P.sprite_plant : P.plant
		P.icon_state = "[sprite_name]-harvest"
		P.name = "ready [P.plant] plant"
		P.desc = "A ready to harvest [P.plant] plant."
		intro_check(P.readyHarvest() && P.stage == 7 && P.water > 0 && P.plant_nutrition > 0, "valid mature crop staged before take")
		harvest_targets += P

/proc/harvest_take()
	intro_check(HARVEST_VIDEO_RELEASED && harvest_targets.len == 3, "reviewed three-crop harvest")
	var/start_time = world.time
	var/list/target_refs = list()
	var/list/rows = list()
	var/list/all_grain = list()
	for (var/obj/structure/farming/plant/wheat/P in harvest_targets.Copy())
		target_refs += "\ref[P]"
	text2file(json_encode(list("phase" = "before", "time" = start_time, "actor" = "\ref[harvest_actor]", "tool" = "\ref[harvest_tool]", "targets" = target_refs, "staged_mature" = TRUE, "growth_observed" = FALSE)), "intro-state-before.json")
	// One second establishes the real input state; two-second beats reveal yields.
	sleep(10)
	for (var/obj/structure/farming/plant/wheat/P in harvest_targets.Copy())
		var/turf/T = get_turf(P)
		var/plant_ref = "\ref[P]"
		var/list/old_seeds = list()
		for (var/obj/item/stack/farming/seeds/wheat/S in T)
			old_seeds += S
		var/list/old_grain = list()
		for (var/obj/item/weapon/reagent_containers/food/snacks/grown/wheat/G in T)
			old_grain += G
		intro_check(!harvest_actor.incapacitated() && harvest_actor.get_active_hand() == harvest_tool && P.Adjacent(harvest_actor) && P.readyHarvest(), "normal harvest preconditions")
		P.attackby(harvest_tool, harvest_actor)
		intro_check(QDELETED(P), "normal harvest removes source crop")
		var/list/new_refs = list()
		for (var/obj/item/weapon/reagent_containers/food/snacks/grown/wheat/G in T)
			if (!(G in old_grain))
				new_refs += "\ref[G]"
				all_grain += G
		intro_check(new_refs.len >= 1 && new_refs.len <= 3, "native wheat yield within production bounds")
		var/seed_units = 0
		for (var/obj/item/stack/farming/seeds/wheat/S in T)
			if (!(S in old_seeds))
				seed_units += S.amount
		intro_check(seed_units == 2, "native seed return retained")
		rows += list(list("plant" = plant_ref, "time" = world.time, "removed" = TRUE, "outputs" = new_refs, "seed_units" = seed_units))
		sleep(20)
	intro_check(all_grain.len >= 3 && all_grain.len <= 9, "bounded native harvested grain")
	harvest_actor.swap_hand()
	var/obj/item/weapon/reagent_containers/food/snacks/grown/wheat/picked = all_grain[1]
	intro_check(!harvest_actor.get_active_hand() && picked.Adjacent(harvest_actor), "grain pickup reachable")
	picked.attack_hand(harvest_actor)
	intro_check(harvest_actor.get_active_hand() == picked, "same harvested wheat picked up")
	text2file(json_encode(list("phase" = "after", "time" = world.time, "actor" = "\ref[harvest_actor]", "tool" = "\ref[harvest_tool]", "targets" = target_refs, "rows" = rows, "picked_ref" = "\ref[picked]", "actor_holds_output" = picked.loc == harvest_actor, "staged_mature" = TRUE, "growth_observed" = FALSE)), "intro-state-after.json")
	text2file(json_encode(list("source" = "58404f5bd16e3fed80f1d9844c5db3edd144942c", "engine" = "516.1688", "world_fps" = world.fps, "elapsed_deciseconds" = world.time - start_time, "scope" = "staged mature crop; native harvest/yield only; no growth or cross-run continuity claim")), "intro-take.json")
