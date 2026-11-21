/proc/recipe_ci_exercise_progression()
	var/list/types = list(/obj/item/weapon/lifting_weight/heavy, /obj/item/weapon/lifting_weight/great, /obj/structure/treadwheel, /obj/item/weapon/lifting_weight/hand_weights, /obj/item/weapon/lifting_weight/barbell, /obj/structure/treadwheel/treadmill)
	var/list/materials = list(/material/stone,/material/stone,/material/wood,/material/bronze,/material/iron,/material/steel)
	var/list/costs = list(5,10,8,3,12,6)
	var/mob/living/human/recipe_ci/H = new(locate(1,1,1))
	for (var/i = 1, i <= types.len, i++)
		var/path = types[i]
		var/modern = exercise_modern_gear(path)
		H.civilization = "exercise_ci_[i]"
		map.faction_baseline_era[H.civilization] = 0
		var/list/entry = map.ensure_node_entry(H.civilization,get_recipe_node_req("[path]"))
		entry[RNODE_ENTRY_STATUS] = RNODE_DONE
		map.ordinal_age = modern ? 8 : 0
		H.stats["crafting"] = list(modern ? 105 : 30,105)
		var/datum/stack_recipe/R = recipe_ci_food_recipe(materials[i],path,H.civilization)
		recipe_ci_food_expect(R && R.req_amount == costs[i] && exercise_can_build(H,path), "exercise paid material route [path]")
		H.stats["crafting"] = list(modern ? 104 : 29,105)
		recipe_ci_food_expect(!exercise_can_build(H,path), "exercise current native crafting threshold [path]")
		H.stats["crafting"] = list(105,105)
		if (modern)
			map.ordinal_age = 7
			recipe_ci_food_expect(!recipe_ci_food_recipe(materials[i],path,H.civilization) && !exercise_can_build(H,path), "Modern gym route rejects earlier era [path]")
			map.ordinal_age = 8
			entry[RNODE_ENTRY_STATUS] = RNODE_AVAILABLE
			recipe_ci_food_expect(!exercise_can_build(H,path) && !recipe_ci_food_recipe(materials[i],path,H.civilization), "Modern gym retains Factories research gate [path]")
	// The small stone asks no crafting skill at all.
	H.civilization = "exercise_ci_small"
	map.faction_baseline_era[H.civilization] = 0
	var/list/small = map.ensure_node_entry(H.civilization,get_recipe_node_req("[/obj/item/weapon/lifting_weight]"))
	small[RNODE_ENTRY_STATUS] = RNODE_DONE
	map.ordinal_age = 0
	H.stats["crafting"] = list(1,105)
	recipe_ci_food_expect(exercise_can_build(H,/obj/item/weapon/lifting_weight), "small lifting stone needs no crafting skill")
	recipe_ci_food_expect(exercise_build_skill(/obj/item/weapon/skipping_rope) == 0, "skipping rope needs no crafting skill")
	qdel(H)
