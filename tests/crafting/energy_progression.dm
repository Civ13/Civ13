/proc/recipe_ci_energy_progression()
	var/faction = "solar_locked_ci"
	map.faction_baseline_era[faction] = 0
	map.ordinal_age = 8
	var/path = /obj/structure/civ_generator/solar
	var/mob/living/human/recipe_ci/H = new(locate(1,1,1))
	H.civilization = faction
	H.stats["crafting"] = list(105,105)
	recipe_ci_food_expect(!recipe_ci_food_recipe(/material/electronics,path,faction) && !civ_generation_can_build(H,path), "solar needs completed digital computing")
	var/list/entry = map.ensure_node_entry(faction,get_recipe_node_req("[path]"))
	entry[RNODE_ENTRY_STATUS] = RNODE_DONE
	map.ordinal_age = 7
	recipe_ci_food_expect(!recipe_ci_food_recipe(/material/electronics,path,faction) && !civ_generation_can_build(H,path), "solar rejects pre-Modern era")
	map.ordinal_age = 8
	var/datum/stack_recipe/R = recipe_ci_food_recipe(/material/electronics,path,faction)
	recipe_ci_food_expect(R && R.req_amount == 20 && civ_generation_can_build(H,path), "solar paid electronics route at crafting105")
	H.stats["crafting"] = list(104,105)
	recipe_ci_food_expect(!civ_generation_can_build(H,path), "solar rejects crafting104")
	map.ordinal_age = 0
	qdel(H)
	H = new(locate(1,1,1))
	H.civilization = "nuclear_locked_ci"
	map.faction_baseline_era[H.civilization] = 0
	H.stats["crafting"] = list(105,105)
	map.ordinal_age = 8
	for (var/result in list(/obj/structure/civ_generator/nuclear,/obj/structure/reactor_fuel_processor))
		var/material_type = result == /obj/structure/civ_generator/nuclear ? /material/electronics : /material/steel
		recipe_ci_food_expect(get_recipe_node_req("[result]") == "nuclear_power", "nuclear explicit node mapping")
		recipe_ci_food_expect(!recipe_ci_food_recipe(material_type,result,H.civilization) && !civ_generation_can_build(H,result), "nuclear locked node rejects construction")
	entry = map.ensure_node_entry(H.civilization,"nuclear_power")
	entry[RNODE_ENTRY_STATUS] = RNODE_DONE
	for (var/result in list(/obj/structure/civ_generator/nuclear,/obj/structure/reactor_fuel_processor))
		var/material_type = result == /obj/structure/civ_generator/nuclear ? /material/electronics : /material/steel
		R = recipe_ci_food_recipe(material_type,result,H.civilization)
		recipe_ci_food_expect(R && R.req_amount == (result == /obj/structure/civ_generator/nuclear ? 40 : 20) && civ_generation_can_build(H,result), "nuclear completed node paid recipe")
		map.ordinal_age = 7
		recipe_ci_food_expect(!recipe_ci_food_recipe(material_type,result,H.civilization) && !civ_generation_can_build(H,result), "nuclear preModern rejected")
		map.ordinal_age = 8
	map.ordinal_age = 0
	qdel(H)
