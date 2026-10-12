/proc/recipe_ci_exercise_progression()
	var/list/types = list(/obj/structure/exercise, /obj/structure/exercise/course, /obj/structure/exercise/modern, /obj/structure/exercise/modern/course)
	var/list/materials = list(/material/stone,/material/wood,/material/iron,/material/iron)
	var/list/costs = list(8,6,12,8)
	var/mob/living/human/recipe_ci/H = new(locate(1,1,1))
	H.stats["crafting"] = list(105,105)
	for (var/i = 1, i <= types.len, i++)
		var/path = types[i]
		H.civilization = "exercise_ci_[i]"
		map.faction_baseline_era[H.civilization] = 0
		var/list/entry = map.ensure_node_entry(H.civilization,get_recipe_node_req("[path]"))
		entry[RNODE_ENTRY_STATUS] = RNODE_DONE
		map.ordinal_age = i >= 3 ? 8 : 0
		var/datum/stack_recipe/R = recipe_ci_food_recipe(materials[i],path,H.civilization)
		recipe_ci_food_expect(R && R.req_amount == costs[i] && exercise_can_build(H,path), "exercise paid material route [path]")
		H.stats["crafting"] = list(i >= 3 ? 104 : 29,105)
		recipe_ci_food_expect(!exercise_can_build(H,path), "exercise current native crafting threshold [path]")
		H.stats["crafting"] = list(105,105)
		if (i >= 3)
			map.ordinal_age = 7
			recipe_ci_food_expect(!recipe_ci_food_recipe(materials[i],path,H.civilization) && !exercise_can_build(H,path), "Modern gym route rejects earlier era [path]")
			map.ordinal_age = 8
			entry[RNODE_ENTRY_STATUS] = RNODE_AVAILABLE
			recipe_ci_food_expect(!exercise_can_build(H,path) && !recipe_ci_food_recipe(materials[i],path,H.civilization), "Modern gym retains Factories research gate [path]")
	map.ordinal_age = 0
	qdel(H)
