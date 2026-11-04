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
	recipe_ci_renewable_progression()

// Renewable sources: each type opens at its own era baseline and research node.
/proc/recipe_ci_renewable_progression()
	var/list/routes = list(
		list(/obj/structure/civ_generator/wind/charger, /material/iron, "electricity", 5, 15),
		list(/obj/structure/civ_generator/solar/panel, /material/electronics, "automation", 7, 10),
		list(/obj/structure/civ_generator/wind/turbine, /material/steel, "digital_computing", 8, 30))
	for (var/list/route in routes)
		var/path = route[1]
		var/material_type = route[2]
		var/node = route[3]
		var/age = route[4]
		var/mob/living/human/recipe_ci/H = new(locate(1,1,1))
		H.civilization = "renewable_[age]_ci"
		map.faction_baseline_era[H.civilization] = 0
		H.stats["crafting"] = list(105,105)
		map.ordinal_age = age
		recipe_ci_food_expect(get_recipe_node_req("[path]") == node, "[path] maps to [node]")
		recipe_ci_food_expect(!recipe_ci_food_recipe(material_type,path,H.civilization) && !civ_generation_can_build(H,path), "[path] needs completed [node]")
		var/list/entry = map.ensure_node_entry(H.civilization,node)
		entry[RNODE_ENTRY_STATUS] = RNODE_DONE
		var/datum/stack_recipe/R = recipe_ci_food_recipe(material_type,path,H.civilization)
		recipe_ci_food_expect(R && R.req_amount == route[5] && civ_generation_can_build(H,path), "[path] paid route at era [age]")
		map.ordinal_age = age - 1
		recipe_ci_food_expect(!recipe_ci_food_recipe(material_type,path,H.civilization) && !civ_generation_can_build(H,path), "[path] rejects era [age - 1]")
		map.ordinal_age = 0
		qdel(H)
	// Output follows the shared wind and daylight state and fails closed indoors.
	var/turf/T = locate(1,1,1)
	var/area/A = get_area(T)
	var/old_location = A.location
	var/old_weather = A.weather
	var/old_wind = map.windspeedvar
	var/old_time = time_of_day
	A.location = AREA_OUTSIDE
	A.weather = WEATHER_NONE
	var/obj/structure/civ_generator/wind/turbine/W = new(T)
	var/list/turbine = list(0, 6, 22, 40, 45)
	var/list/charger = list(0, 3, 8, 12, 4)
	for (var/speed = 0, speed <= 4, speed++)
		map.windspeedvar = speed
		recipe_ci_food_expect(W.rated_output() == turbine[speed + 1], "turbine output at wind [speed]")
	W.retire_generator()
	W.loc = null
	var/obj/structure/civ_generator/wind/charger/C = new(T)
	recipe_ci_food_expect(C.min_age == 5 && W.min_age == 8, "wind era baselines")
	for (var/speed = 0, speed <= 4, speed++)
		map.windspeedvar = speed
		recipe_ci_food_expect(C.rated_output() == charger[speed + 1], "charger output at wind [speed]")
	map.windspeedvar = 3
	W.loc = T
	recipe_ci_food_expect(C.rated_output() == 6, "nearby rotor halves output")
	W.loc = null
	A.location = AREA_INSIDE
	recipe_ci_food_expect(C.rated_output() == 0, "indoor rotor produces nothing")
	A.location = AREA_OUTSIDE
	var/obj/structure/civ_generator/solar/panel/P = new(T)
	time_of_day = "Midday"
	recipe_ci_food_expect(P.rated_output() == 10 && P.min_age == 7, "panel midday output")
	time_of_day = "Night"
	recipe_ci_food_expect(P.rated_output() == 0, "panel night output")
	for (var/obj/structure/civ_generator/G in list(W, C, P))
		G.retire_generator()
		qdel(G)
	A.location = old_location
	A.weather = old_weather
	map.windspeedvar = old_wind
	time_of_day = old_time
