// How hard a timed action works the body (human_life.dm survival_work_food_m):
// 3 heavy labour, 2 ordinary handwork, 1 light work. The tool in the active
// hand decides first, then what is being worked on; anything else is ordinary.
/mob/living/human/proc/survival_workload_for(atom/target)
	var/obj/item/held = get_active_hand()
	if (held)
		if ((held.tool_flags & (TOOL_PICKAXE | TOOL_SHOVEL | TOOL_HATCHET | TOOL_HAMMER | TOOL_CHISEL)) \
			|| istype(held, /obj/item/weapon/material/twohanded/fireaxe) || istype(held, /obj/item/weapon/sledgehammer) \
			|| istype(held, /obj/item/weapon/saw))
			return 3
		if (istype(held, /obj/item/weapon/pen) || istype(held, /obj/item/weapon/book) || istype(held, /obj/item/weapon/paper) \
			|| istype(held, /obj/item/weapon/paper_bundle) || istype(held, /obj/item/weapon/bone_needle) \
			|| istype(held, /obj/item/tailoring_project) || istype(held, /obj/item/rope_spindle))
			return 1
	if (target)
		if (istype(target, /turf/wall) || istype(target, /obj/structure/wild/tree) || istype(target, /obj/structure/wild/tree_stump) \
			|| istype(target, /obj/structure/anvil))
			return 3
		if (istype(target, /obj/structure/research_bench) || istype(target, /obj/structure/researchdesk) || istype(target, /obj/structure/loom) \
			|| istype(target, /obj/item/weapon/book) || istype(target, /obj/item/weapon/paper) || istype(target, /obj/item/tailoring_project))
			return 1
	return 2

// Characters saved with the old 400 food / 350 water pools keep the same
// fraction of a full stomach and canteen in the larger pools.
/mob/living/human/after_load()
	. = ..()
	var/full_food = initial(max_nutrition)
	if (max_nutrition > 0 && max_nutrition < full_food)
		nutrition = nutrition * full_food / max_nutrition
		max_nutrition = full_food
	var/full_water = initial(max_water)
	if (max_water > 0 && max_water < full_water)
		water = water * full_water / max_water
		max_water = full_water
