// Actual recipe generator and construction authorization, isolated actors.
/proc/recipe_ci_telecom_progression()
	var/faction = "telecom_locked_ci"
	map.faction_baseline_era[faction] = 0
	map.ordinal_age = 8
	var/list/types = list(/obj/structure/telecom, /obj/structure/telecom/station, /obj/structure/telecom/tv, /obj/structure/telecom/station/tv, /obj/structure/telecom/terminal, /obj/item/weapon/telephone/landline, /obj/structure/telecom/antenna)
	var/list/costs = list(3,6,3,10,8,2,5)
	var/mob/living/human/recipe_ci/H = new(locate(1,1,1))
	H.civilization = faction
	H.stats["crafting"] = list(160,160)
	for (var/i = 1, i <= types.len, i++)
		faction = "telecom_locked_ci_[i]"
		H.civilization = faction
		map.faction_baseline_era[faction] = 0
		var/path = types[i]
		var/material_path = path == /obj/structure/telecom/antenna ? /material/iron : /material/electronics
		recipe_ci_food_expect(!recipe_ci_food_recipe(material_path,path,faction) && !civ_telecom_can_build(H,path), "telecom [path] requires its research node")
		var/list/entry = map.ensure_node_entry(faction,get_recipe_node_req("[path]"))
		entry[RNODE_ENTRY_STATUS] = RNODE_DONE
		map.ordinal_age = 7
		recipe_ci_food_expect(!recipe_ci_food_recipe(material_path,path,faction) && !civ_telecom_can_build(H,path), "telecom [path] cannot construct before Modern")
		map.ordinal_age = 8
		var/datum/stack_recipe/R = recipe_ci_food_recipe(material_path,path,faction)
		recipe_ci_food_expect(R && R.req_amount == costs[i] && civ_telecom_can_build(H,path), "Modern completed-node paid recipe [path]")
		H.stats["crafting"] = list(civ_telecom_crafting_skill(path)-1,160)
		recipe_ci_food_expect(!civ_telecom_can_build(H,path), "telecom [path] enforces native crafting skill")
		H.stats["crafting"] = list(160,160)
	map.ordinal_age = 0
	qdel(H)
