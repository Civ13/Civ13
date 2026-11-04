/world
	hub = ""
	hub_password = ""
	maxx = 12
	maxy = 12
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/hydro_probe/New()
	return
/mob/living/human/hydro_probe/New()
	return
/mob/living/human/hydro_probe/update_icons()
	return
var/hydro_failures = 0
var/hydro_runtime_error = FALSE
/proc/hydro_check(condition, label)
	if (!condition)
		hydro_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	hydro_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/proc/hydro_count(turf/T, type)
	var/total = 0
	for (var/obj/item/I in T)
		if (I.type == type)
			if (istype(I, /obj/item/stack))
				var/obj/item/stack/S = I
				total += S.amount
			else
				total++
	return total
/proc/hydro_clear(turf/T)
	for (var/obj/item/I in T)
		qdel(I)
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		populate_material_list()
		build_research_tree()
		map = new /obj/map_metadata/hydro_probe
		map.ordinal_age = 6
		hydro_check(!world.port, "fixture has no listening port")
		hydro_lifecycle_checks()
		hydro_shortage_checks()
		hydro_persistence_checks()
		hydro_construction_checks()
		hydro_catalog_checks()
	catch(var/exception/e)
		hydro_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = hydro_failures, "runtime_error" = hydro_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/hydro_powered_tray(x, y)
	var/turf/T = locate(x, y, 1)
	T = T.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
	var/obj/structure/hydroponics_tray/tray = new(T)
	var/obj/structure/cable/C = new(T)
	var/obj/structure/engine/E = new(locate(x + 1, y, 1))
	E.on = TRUE
	E.maxpower = 200
	E.connections = list(C)
	C.connections = list(tray, E)
	tray.powersource = C
	return tray

/proc/hydro_lifecycle_checks()
	var/obj/structure/hydroponics_tray/tray = hydro_powered_tray(3, 3)
	var/obj/structure/cable/C = tray.powersource
	var/turf/T = get_turf(tray)
	var/turf/standing = locate(3, 4, 1)
	standing = standing.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
	var/mob/living/human/hydro_probe/H = new(standing)

	var/obj/item/stack/farming/seeds/hemp/hemp = new(H, 5)
	hydro_check(!tray.plant_seed(H, hemp) && hemp.amount == 5 && !tray.crop, "crops outside the accepted whitelist are refused")
	var/obj/item/stack/farming/seeds/wheat/wheat = new(H, 5)
	hydro_check(tray.plant_seed(H, wheat) && wheat.amount == 4 && tray.crop == "wheat" && tray.stage == 1, "planting pays one seed and starts at stage 1")
	hydro_check(!tray.plant_seed(H, wheat) && wheat.amount == 4, "an occupied tray refuses a second seed")
	hydro_check(tray in processing_objects, "a planted tray registers one processing owner")

	var/obj/item/weapon/reagent_containers/glass/bucket/small = new(H)
	small.reagents.add_reagent("water", 30)
	hydro_check(tray.fill_water(H, small) == 30 && tray.water_units == 30 && small.reagents.get_reagent_amount("water") == 0, "a partial fill moves all donor water")
	var/obj/item/weapon/reagent_containers/food/snacks/poo/fertilizer/F1 = new(H)
	var/obj/item/weapon/reagent_containers/food/snacks/poo/fertilizer/F2 = new(H)
	hydro_check(tray.add_compost(H, F1) && tray.add_compost(H, F2) && tray.nutrient_units == 6, "each compost adds 3 nutrient")
	var/obj/item/weapon/reagent_containers/glass/bucket/big = new(H)
	big.reagents.add_reagent("water", 100)
	big.reagents.add_reagent("sodiumchloride", 5)
	var/accepted = tray.fill_water(H, big)
	hydro_check(accepted == 24 && tray.water_units + tray.nutrient_units == 60, "fill stops at the combined 60-unit reservoir")
	hydro_check(big.reagents.get_reagent_amount("water") == 76 && big.reagents.get_reagent_amount("sodiumchloride") == 5, "donor keeps unaccepted water and every other reagent")
	var/obj/item/weapon/reagent_containers/food/snacks/poo/fertilizer/F3 = new(H)
	hydro_check(!tray.add_compost(H, F3) && !QDELETED(F3) && tray.nutrient_units == 6, "a full reservoir refuses compost without spending it")

	tray.powersource = null
	tray.advance(600)
	hydro_check(tray.stage == 1 && tray.cycle_progress == 0 && tray.water_units == 54, "an unpowered tray pauses without paying")
	tray.powersource = C
	tray.advance(300)
	hydro_check(tray.stage == 1 && tray.cycle_progress == 300 && C.currentflow == 5 && tray.water_units == 54, "a powered half cycle reserves 5 PU and pays nothing yet")
	var/obj/structure/engine/E = C.connections[2]
	E.on = FALSE
	tray.advance(300)
	hydro_check(tray.stage == 1 && tray.cycle_progress == 300 && !tray.powered, "a power cut pauses and keeps paid-for progress")
	E.on = TRUE
	tray.advance(300)
	hydro_check(tray.stage == 2 && tray.cycle_progress == 0 && tray.water_units == 52 && tray.nutrient_units == 5, "a completed cycle pays 2 water and 1 nutrient for one stage")
	tray.advance(6000)
	hydro_check(tray.stage == 3 && tray.water_units == 50 && tray.nutrient_units == 4, "one call never advances more than one stage")
	for (var/i in 1 to 10)
		tray.advance(600)
	hydro_check(tray.ready() && tray.stage == 7 && tray.water_units == 42 && tray.nutrient_units == 0, "six paid cycles make one ready crop for 12 water and 6 nutrient")
	hydro_check(C.currentflow == 0 && !tray.powered, "a ready crop stops drawing power")
	tray.advance(6000)
	hydro_check(tray.ready() && tray.water_units == 42, "a ready crop has no time expiry and pays nothing")
	hydro_clear(T)
	hydro_check(tray.harvest(H, 2) && !tray.crop && hydro_count(T, /obj/item/stack/farming/seeds/wheat) == 2 && hydro_count(T, /obj/item/weapon/reagent_containers/food/snacks/grown/wheat) == 2, "harvest emits two seeds and the produce on the tray tile")
	hydro_check(!tray.harvest(H, 3) && hydro_count(T, /obj/item/weapon/reagent_containers/food/snacks/grown/wheat) == 2, "a repeated harvest emits nothing")
	hydro_check(!(tray in processing_objects), "an empty tray leaves processing")
	hydro_clear(T)
	qdel(tray)
	qdel(H)

/proc/hydro_shortage_checks()
	var/obj/structure/hydroponics_tray/tray = hydro_powered_tray(3, 7)
	var/obj/structure/cable/C = tray.powersource
	var/mob/living/human/hydro_probe/H = new(locate(4, 8, 1))
	var/obj/item/stack/farming/seeds/potato/potato = new(H, 5)
	tray.plant_seed(H, potato)
	tray.water_units = 10
	tray.advance(600)
	hydro_check(tray.stage == 1 && tray.cycle_progress == 0 && tray.water_units == 10 && C.currentflow == 0, "no nutrient pauses growth without power or water use")
	tray.water_units = 0
	tray.nutrient_units = 5
	for (var/i in 1 to 30)
		tray.advance(600)
	hydro_check(!tray.dead() && tray.stage == 1, "a dry potato pauses but does not die")
	tray.clear_crop()
	var/obj/item/stack/farming/seeds/tomato/tomato = new(H, 5)
	tray.plant_seed(H, tomato)
	for (var/i in 1 to 9)
		tray.advance(600)
	hydro_check(!tray.dead(), "a dry tomato survives nine minutes")
	tray.advance(600)
	hydro_check(tray.dead() && !(tray in processing_objects) && C.currentflow == 0, "a tomato dies after ten dry minutes and releases its owner")
	hydro_check(!tray.harvest(H) , "a dead crop cannot be harvested")
	var/obj/item/weapon/material/kitchen/utensil/knife/knife = new(H)
	tray.attackby(knife, H)
	hydro_check(!tray.crop, "a knife clears a dead crop")
	var/obj/item/stack/farming/seeds/beans/beans = new(H, 5)
	tray.plant_seed(H, beans)
	tray.water_units = 1
	for (var/i in 1 to 9)
		tray.advance(600)
	tray.water_units = 10
	tray.advance(600)
	hydro_check(!tray.dead() && tray.dry_time == 0, "watering resets a fragile crop's dry timer")
	var/area/A = get_area(tray)
	var/old_location = A.location
	var/old_state = A.icon_state
	A.location = AREA_OUTSIDE
	A.icon_state = "snow_storm"
	new /obj/roof(get_turf(tray))
	tray.advance(600)
	hydro_check(!tray.dead(), "a roof shelters the tray from a snowstorm")
	for (var/obj/roof/R in get_turf(tray))
		qdel(R)
	tray.advance(600)
	hydro_check(tray.dead(), "an exposed tray's crop freezes in a snowstorm")
	A.location = old_location
	A.icon_state = old_state
	qdel(tray)
	qdel(H)

/proc/hydro_persistence_checks()
	var/obj/structure/hydroponics_tray/tray = hydro_powered_tray(7, 3)
	var/obj/structure/cable/C = tray.powersource
	var/mob/living/human/hydro_probe/H = new(locate(7, 4, 1))
	var/obj/item/stack/farming/seeds/carrot/carrot = new(H, 5)
	tray.plant_seed(H, carrot)
	tray.water_units = 20
	tray.nutrient_units = 10
	tray.advance(300)
	var/list/saved = tray.get_saved_vars()
	hydro_check(("crop" in saved) && ("stage" in saved) && ("cycle_progress" in saved) && ("water_units" in saved) && ("nutrient_units" in saved), "crop, stage, partial cycle and reservoir are saved")
	hydro_check(!("last_tick" in saved) && !("registered" in saved) && !("powersource" in saved) && !("powered" in saved), "clock anchor, processing membership and power lease are runtime-only")
	tray.stop_processing()
	tray.release_power()
	tray.water_units = 80
	tray.cycle_progress = 9999
	tray.after_load()
	hydro_check(tray.water_units == 60 && tray.nutrient_units == 0 && tray.cycle_progress == 599, "load clamps the reservoir and partial cycle")
	hydro_check(tray.powersource == C && (tray in C.connections) && (tray in processing_objects) && tray.registered, "load rejoins the cable on its tile and registers once")
	tray.after_load()
	var/count = 0
	for (var/obj/O in processing_objects)
		if (O == tray)
			count++
	hydro_check(count == 1, "repeated load never registers a second owner")
	tray.crop = "poppy"
	tray.after_load()
	hydro_check(!tray.crop && !(tray in processing_objects), "load clears a crop outside the whitelist")
	qdel(tray)
	hydro_check(!(tray in processing_objects), "deleting the tray releases processing")
	qdel(H)

/proc/hydro_construction_checks()
	var/turf/T = locate(9, 9, 1)
	T = T.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
	var/mob/living/human/hydro_probe/H = new(locate(9, 10, 1))
	var/obj/structure/hydroponics_frame/frame = new(T)
	var/obj/item/stack/cable_coil/early = new(H, 5)
	frame.attackby(early, H)
	hydro_check(!QDELETED(frame) && early.amount == 5, "an unglazed frame refuses cable")
	var/obj/item/stack/material/glass/one = new(H, 1)
	frame.attackby(one, H)
	hydro_check(!frame.glazed && one.amount == 1, "one glass sheet is not enough")
	qdel(one)
	var/obj/item/stack/material/glass/G = new(H, 5)
	frame.attackby(G, H)
	hydro_check(frame.glazed && G.amount == 3, "glazing pays two glass sheets")
	frame.attackby(early, H)
	var/obj/structure/hydroponics_tray/tray = locate() in T
	hydro_check(QDELETED(frame) && tray && early.amount == 4, "one cable finishes the tray")
	qdel(tray)
	qdel(H)

/proc/hydro_catalog_checks()
	hydro_check(get_recipe_node_req("/obj/structure/hydroponics_frame") == "hydroponics" && get_recipe_node_req("/obj/structure/hydroponics_tray") == "hydroponics", "frame and tray unlock at Hydroponics")
	var/datum/research_node/node = research_nodes["hydroponics"]
	hydro_check(node && node.era_tier == 6 && ("advanced_agriculture" in node.prereqs) && ("electricity" in node.prereqs), "Hydroponics is era 6 after Advanced Agriculture and Electricity")
	for (var/crop in hydroponics_crops())
		var/plant_path = text2path("/obj/structure/farming/plant/[crop]")
		var/obj/structure/farming/plant/P = plant_path
		var/list/states = icon_states(initial(P.icon))
		var/ok = ("[crop]-harvest" in states) && ("[crop]-dead" in states) && text2path("/obj/item/stack/farming/seeds/[crop]") && text2path("/obj/item/weapon/reagent_containers/food/snacks/grown/[crop]")
		for (var/i in 1 to 6)
			ok = ok && ("[crop]-grow[i]" in states)
		hydro_check(ok, "[crop] has seeds, produce and every tray sprite state")
	hydro_check("kevlar_trough_empty" in icon_states('icons/obj/structures.dmi'), "tray sprite state exists")
	var/list/rows = list()
	for (var/line in splittext(file2text("config/crafting/material_recipes_global.txt"), "\n"))
		if (findtext(line, "RECIPE: ") == 1)
			rows += list(splittext(replacetext(line, "RECIPE: ", ""), ","))
	craftlist_lists["global"] = rows
	var/material/steel = get_material_by_name("steel")
	map.ordinal_age = 6
	map.faction_baseline_era["hydro-before"] = 5
	steel.generate_recipes_civs(list(0,0,0), "global", "hydro-before")
	hydro_check(!hydro_has_recipe(steel.recipes, /obj/structure/hydroponics_frame), "tray frame hidden before Hydroponics")
	map.faction_baseline_era["hydro-after"] = 6
	steel.generate_recipes_civs(list(0,0,0), "global", "hydro-after")
	hydro_check(!hydro_has_recipe(steel.recipes, /obj/structure/hydroponics_frame), "the era alone never grants the Agriculture-tree node")
	hydro_check(!map.add_research_ticks("hydro-after", "hydroponics", 100000), "Hydroponics cannot be studied before Advanced Agriculture")
	map.add_research_ticks("hydro-after", "irrigation", 100000)
	map.add_research_ticks("hydro-after", "advanced_agriculture", 100000)
	map.add_research_ticks("hydro-after", "hydroponics", 100000)
	hydro_check(map.is_node_done("hydro-after", "hydroponics"), "researching Hydroponics completes the node")
	steel.generate_recipes_civs(list(0,0,0), "global", "hydro-after")
	hydro_check(hydro_recipe_cost(steel.recipes, /obj/structure/hydroponics_frame) == 4, "tray frame costs four steel sheets at Hydroponics")

/proc/hydro_has_recipe(list/recipes, result_type)
	return hydro_recipe_cost(recipes, result_type) > 0

/proc/hydro_recipe_cost(list/recipes, result_type)
	for (var/datum/R in recipes)
		if (istype(R, /datum/stack_recipe))
			var/datum/stack_recipe/recipe = R
			if (recipe.result_type == result_type)
				return recipe.req_amount
		else if (istype(R, /datum/stack_recipe_list))
			var/datum/stack_recipe_list/category = R
			var/found = hydro_recipe_cost(category.recipes, result_type)
			if (found)
				return found
	return 0
