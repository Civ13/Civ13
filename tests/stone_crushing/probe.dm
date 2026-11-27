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
/obj/map_metadata/crush_probe/New()
	return
/mob/living/human/crush_probe/New()
	return
// The fixture actor has no species appearance to redraw.
/mob/living/human/crush_probe/update_icons()
	return
// Bounded action-delay adapter; the production loop body is unchanged.
/obj/structure/stone_crusher/crush_probe
	var/wait_mode
	var/obj/item/stack/material/stone/wait_stack
	var/wait_calls = 0
	var/payment_attempts = 0

/obj/structure/stone_crusher/crush_probe/crushing_wait(mob/living/human/H)
	wait_calls++
	switch (wait_mode)
		if ("failed")
			return FALSE
		if ("worker")
			H.stat = 1
		if ("anchor")
			anchored = FALSE
		if ("deleted")
			qdel(wait_stack)
		if ("location")
			wait_stack.loc = get_turf(src)
		if ("amount")
			wait_stack.amount = 0
		if ("distance")
			H.loc = locate(8,8,1)
	return TRUE

/obj/structure/stone_crusher/crush_probe/crush_one_stone(mob/living/human/H, obj/item/stack/S, roll = null)
	payment_attempts++
	return ..(H, S, roll)
var/crush_failures = 0
var/crush_runtime_error = FALSE
/proc/crush_check(condition, label)
	if (!condition)
		crush_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	crush_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/proc/crush_table_total(list/table)
	var/total = 0
	for (var/ore_type in table)
		total += table[ore_type]
	return total
/proc/crush_count(turf/T, type)
	var/total = 0
	for (var/obj/item/stack/S in T)
		if (S.type == type)
			total += S.amount
	return total
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
		map = new /obj/map_metadata/crush_probe
		map.ordinal_age = 0
		crush_check(!world.port, "fixture has no listening port")
		crush_table_checks()
		crush_manual_checks()
		crush_interruption_checks()
		crush_stamp_mill_checks()
		crush_quarry_rubble_checks()
		crush_catalog_checks()
	catch(var/exception/e)
		crush_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = crush_failures, "runtime_error" = crush_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/crush_table_checks()
	var/list/stone_age = legacy_gaia_stone_crushing_table(0, FALSE)
	var/list/medieval = legacy_gaia_stone_crushing_table(2, FALSE)
	var/list/powered = legacy_gaia_stone_crushing_table(8, TRUE)
	crush_check(!(/obj/item/stack/ore/iron in stone_age) && medieval[/obj/item/stack/ore/iron] == 300, "legacy Gaia recovery respects era gates")
	crush_check(stone_age[/obj/item/stack/ore/copper] == 600 && stone_age[/obj/item/stack/ore/tin] == 250 && stone_age[/obj/item/stack/ore/gold] == 15, "Gaia fallback uses Gaia rates")
	crush_check(!(/obj/item/stack/ore/bauxite in powered) && !(/obj/item/stack/ore/uranium in powered) && powered[/obj/item/stack/ore/glass] == 2500, "legacy fallback never finds bauxite or uranium")
	var/obj/item/stack/material/sandstone/sandstone = new(null)
	var/obj/item/stack/material/stone/stone = new(null)
	var/obj/item/stack/material/stone/quarried/spent = new(null, 4, FALSE)
	crush_check(is_crushable_stone(stone) && is_crushable_stone(spent) && !is_crushable_stone(sandstone) && !is_crushable_stone(null), "both stone-block types are crushable")
	var/old_map = map.ID
	map.ID = MAP_NOMADS_EARTH_OCEANIA
	crush_check(stone_crush_result(stone, FALSE, 2001) == /obj/item/stack/ore/copper, "unknown-origin stone follows Gaia even on Oceania")
	map.ID = old_map
	crush_check(stone_crush_result(spent, FALSE, 2000) == /obj/item/stack/ore/glass && !stone_crush_result(spent, FALSE, 2001), "spent quarry stone can yield sand but never rolls trace ore")
	crush_check(stone_workshop_feed_type(spent) == stone.type && spent.get_material() == stone.get_material(), "spent quarry blocks are the usual building material")
	crush_check(!stone.merge(spent) && !spent.merge(stone) && !spent.transfer_to(stone), "quarry stone cannot mix with unknown-origin stone")
	var/obj/item/stack/material/stone/quarried/half = spent.split(2)
	crush_check(istype(half) && half.amount == 2 && spent.amount == 2 && half.stacktype == spent.stacktype, "splitting preserves accounted stone status")
	qdel(half)
	qdel(spent)
	qdel(sandstone)
	qdel(stone)

/proc/crush_manual_checks()
	map.ordinal_age = 2
	var/turf/T = locate(3,3,1)
	T = T.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
	var/obj/structure/stone_crusher/crush_probe/C = new(T)
	crush_check(C.icon == 'icons/obj/hopper_machines.dmi' && C.icon_state == "millstones", "the manual crusher uses the millstone placeholder")
	var/list/saved = C.get_saved_vars()
	crush_check(!("icon" in saved) && !("icon_state" in saved), "default crusher art is not baked into the save")
	C.reagents.add_reagent("mercury", 1)
	C.arrastra_update_overlay()
	crush_check(C.overlays.len == 1 && C.icon_state == "millstones", "a charged arrastra retains its overlay on the new base")
	C.reagents.remove_reagent("mercury", 1)
	C.arrastra_update_overlay()
	crush_check(!C.overlays.len && C.icon_state == "millstones", "clearing the charge restores the new base alone")
	var/turf/standing = locate(3,4,1)
	standing = standing.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
	var/mob/living/human/crush_probe/H = new(standing)
	var/obj/item/stack/material/stone/S = new(H, 10, FALSE)
	crush_check(C.crush_one_stone(H, S, 1) && S.amount == 9 && crush_count(T, /obj/item/stack/ore/glass) == 1, "sand roll spends one stone and deposits one sand")
	crush_check(C.crush_one_stone(H, S, 9999) && S.amount == 8 && crush_count(T, /obj/item/stack/ore/glass) == 1, "rubble roll spends one stone and deposits nothing")
	crush_check(C.crush_one_stone(H, S, 2001) && crush_count(T, /obj/item/stack/ore/copper) == 1, "legacy Gaia ore roll deposits ore under the crusher")
	for (var/obj/item/stack/item in T)
		qdel(item)
	for (var/i in 1 to 12)
		new /obj/item/stack/material/wood(T, 50, FALSE)
	var/before = S.amount
	crush_check(!C.crush_one_stone(H, S, 1) && S.amount == before && !crush_count(T, /obj/item/stack/ore/glass), "full output refuses before spending stone")
	crush_check(C.crush_one_stone(H, S, 9999) && S.amount == before - 1, "rubble still clears with full output")
	for (var/obj/item/stack/item in T)
		qdel(item)
	// Held stone stays in the worker; equipment slots are not needed for the loop.
	var/remaining = S.amount
	var/crushed = C.crush_stones(H, S)
	crush_check(crushed == remaining && QDELETED(S) && !(H in C.crushing_workers), "worked loop crushes the held stack and releases the worker")
	var/obj/item/stack/material/stone/far = new(H, 5, FALSE)
	H.loc = locate(8,8,1)
	crush_check(!C.crush_stones(H, far) && far.amount == 5, "a distant worker crushes nothing")
	H.loc = standing
	C.anchored = FALSE
	crush_check(!C.crush_stones(H, far) && far.amount == 5, "an unanchored crusher refuses work")
	crush_check(!("crushing_workers" in C.get_saved_vars()), "worker list is runtime-only")
	qdel(far)
	qdel(C)
	qdel(H)
	for (var/obj/item/stack/item in T)
		qdel(item)

/proc/crush_interruption_checks()
	var/turf/T = locate(3,3,1)
	var/turf/standing = locate(3,4,1)
	for (var/mode in list("failed", "worker", "anchor", "deleted", "location", "amount", "distance"))
		var/obj/structure/stone_crusher/crush_probe/C = new(T)
		var/mob/living/human/crush_probe/H = new(standing)
		var/obj/item/stack/material/stone/S = new(H, 5, FALSE)
		C.wait_mode = mode
		C.wait_stack = S
		var/crushed = C.crush_stones(H, S)
		crush_check(C.wait_calls == 1 && !crushed && !C.payment_attempts && !(H in C.crushing_workers), "[mode] during wait stops before payment and releases worker")
		if (mode != "deleted" && mode != "amount")
			crush_check(S.amount == 5, "[mode] preserves the stone stack")
		qdel(S)
		qdel(C)
		qdel(H)

/proc/crush_stamp_mill_checks()
	map.ordinal_age = 5
	var/turf/T = locate(5,5,1)
	T = T.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
	var/obj/structure/drill/stamp_mill/M = new(T)
	M.anchored = TRUE
	var/obj/structure/cable/C = new(locate(6,5,1))
	var/obj/structure/engine/E = new(locate(7,5,1))
	E.on = TRUE
	E.maxpower = 200
	E.connections = list(C)
	C.connections = list(M,E)
	M.powersource = C
	var/turf/standing = locate(5,6,1)
	standing = standing.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
	var/mob/living/human/crush_probe/H = new(standing)
	M.attack_hand(H)
	crush_check(!M.active && C.currentflow == 0, "empty hopper refuses to start")
	var/obj/item/stack/material/stone/S = new(H, 50, FALSE)
	var/obj/item/stack/material/stone/S2 = new(H, 10, FALSE)
	crush_check(M.load_stone(H, S) == 50 && QDELETED(S), "hopper takes a full stack")
	crush_check(!M.load_stone(H, S2) && S2.amount == 10 && M.loaded_stone_amount() == 50, "a full hopper takes no more stone")
	M.attack_hand(H)
	crush_check(M.active && M.process_pending && C.currentflow == 150, "loaded mill starts with reserved cable demand")
	for (var/i in 1 to 10)
		M.attack_hand(H)
		M.attack_hand(H)
	crush_check(M.active && M.loaded_stone_amount() == 50, "repeated toggles crush nothing early")
	sleep(45)
	crush_check(M.loaded_stone_amount() == 49, "one stone is stamped every four seconds")
	M.stop_drilling()
	sleep(21)
	crush_check(!M.process_pending && C.currentflow == 0, "stop settles callback and releases demand")
	for (var/obj/item/stack/item in T)
		qdel(item)
	for (var/i in 1 to 12)
		new /obj/item/stack/material/wood(T, 50, FALSE)
	crush_check(!M.stamp_one_stone(1) && M.loaded_stone_amount() == 49, "full output refuses before spending stone")
	for (var/obj/item/stack/item in T)
		qdel(item)
	crush_check(M.stamp_one_stone(1) && M.loaded_stone_amount() == 48 && crush_count(T, /obj/item/stack/ore/glass) == 1, "stamped sand roll spends one stone")
	for (var/obj/item/stack/item in T)
		qdel(item)
	var/obj/item/stack/material/stone/hopper = M.loaded_stone()
	hopper.amount = 1
	M.attack_hand(H)
	M.next_spawn = 0
	sleep(21)
	sleep(21)
	crush_check(!M.active && !M.loaded_stone() && C.currentflow == 0, "mill stops and releases demand once the hopper is empty")
	M.load_stone(H, S2)
	M.active = TRUE
	M.after_load()
	crush_check(!M.active && !M.process_pending && M.next_spawn == -1, "inherited load hook stops the mill")
	M.unload_stone()
	crush_check(!M.loaded_stone() && crush_count(T, /obj/item/stack/material/stone) == 10, "unloading returns hopper stone to the floor")
	qdel(M)
	qdel(H)

/proc/crush_quarry_rubble_checks()
	var/turf/T = locate(9,9,1)
	T = T.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
	var/mob/living/human/crush_probe/H = new(locate(9,10,1))
	var/obj/structure/stone_crusher/C = new(T)
	var/obj/structure/drill/stamp_mill/M = new(T)
	var/obj/item/stack/quarry_rubble/iron/iron = new(H, 3, FALSE)
	var/obj/item/stack/quarry_rubble/gold/gold = new(H, 2, FALSE)
	var/obj/item/stack/quarry_rubble/iron/split = iron.split(1)
	crush_check(istype(split) && !iron.merge(gold) && !gold.transfer_to(iron) && split.amount == 1 && iron.amount == 2, "rubble stacks split without changing mineral and cannot mix minerals")
	var/list/transit = region_travel_worn_entry(iron)
	var/obj/item/stack/quarry_rubble/iron/travelled = region_travel_make_item(transit[1], transit[2], T)
	crush_check(istype(travelled) && travelled.amount == 2 && stone_crush_result(travelled, TRUE, 1) == /obj/item/stack/ore/iron, "region travel round-trip retains mineral and count")
	crush_check(!region_travel_item_path(transit[1], 51) && !region_travel_item_path("stack:quarry:/obj/item/stack/quarry_rubble", 1), "travel only accepts valid amounts of concrete quarry feed")
	qdel(travelled)
	for (var/i in 1 to 12)
		new /obj/item/stack/material/wood(T, 50, FALSE)
	crush_check(!C.crush_one_stone(H, split, 10000) && split.amount == 1, "full hand-crusher output does not spend fixed ore")
	crush_check(M.load_stone(H, gold) == 2 && QDELETED(gold) && !M.stamp_one_stone(10000) && M.loaded_stone_amount() == 2, "stamp mill accepts named rubble and never debits when output is full")
	for (var/obj/item/stack/item in T)
		qdel(item)
	crush_check(C.crush_one_stone(H, split, 10000) && QDELETED(split) && crush_count(T, /obj/item/stack/ore/iron) == 1, "hand crusher recovers the source mineral despite a failed legacy roll")
	crush_check(!C.crush_one_stone(H, split, 1) && crush_count(T, /obj/item/stack/ore/iron) == 1, "spent hand feed cannot pay twice")
	crush_check(M.stamp_one_stone(10000) && M.stamp_one_stone(1) && !M.stamp_one_stone(1) && crush_count(T, /obj/item/stack/ore/gold) == 2 && !M.loaded_stone_amount(), "stamp mill gives exactly the loaded fixed ore budget")
	qdel(iron)
	qdel(H)
	qdel(C)
	qdel(M)

/proc/crush_catalog_checks()
	crush_check(get_recipe_node_req("/obj/structure/stone_crusher") == "resource_processing", "hand crusher unlocks at Resource Processing")
	crush_check(get_recipe_node_req("/obj/structure/drill/stamp_mill") == "electricity", "stamp mill unlocks at Electricity")
	var/list/states = icon_states('icons/obj/structures.dmi')
	crush_check("grindstone" in states, "hand crusher sprite state exists")
	var/obj/structure/drill/stamp_mill/M = new(null)
	states = icon_states(M.icon)
	crush_check(("mining_drill" in states) && ("mining_drill_powered" in states) && ("mining_drill_active" in states), "stamp mill sprite states exist")
	qdel(M)
	var/list/rows = list()
	for (var/line in splittext(file2text("config/crafting/material_recipes_global.txt"), "\n"))
		if (findtext(line, "RECIPE: ") == 1)
			rows += list(splittext(replacetext(line, "RECIPE: ", ""), ","))
	craftlist_lists["global"] = rows
	var/material/stone/stone = get_material_by_name("stone")
	map.ordinal_age = 1
	map.faction_baseline_era["crush-before"] = 0
	stone.generate_recipes_civs(list(0,0,0), "global", "crush-before")
	crush_check(!crush_has_recipe(stone.recipes, /obj/structure/stone_crusher), "hand crusher hidden before Resource Processing")
	map.faction_baseline_era["crush-after"] = 1
	stone.generate_recipes_civs(list(0,0,0), "global", "crush-after")
	crush_check(crush_has_recipe(stone.recipes, /obj/structure/stone_crusher), "hand crusher craftable from stone at Resource Processing")
	var/material/electronics/electronics = get_material_by_name("electronic")
	map.ordinal_age = 5
	map.faction_baseline_era["crush-power-before"] = 4
	electronics.generate_recipes_civs(list(0,0,0), "global", "crush-power-before")
	crush_check(!crush_has_recipe(electronics.recipes, /obj/structure/drill/stamp_mill), "stamp mill hidden before Electricity")
	map.faction_baseline_era["crush-power-after"] = 5
	electronics.generate_recipes_civs(list(0,0,0), "global", "crush-power-after")
	crush_check(crush_has_recipe(electronics.recipes, /obj/structure/drill/stamp_mill), "stamp mill buildable at Electricity")

/proc/crush_has_recipe(list/recipes, result_type)
	for (var/datum/R in recipes)
		if (istype(R, /datum/stack_recipe))
			var/datum/stack_recipe/recipe = R
			if (recipe.result_type == result_type)
				return TRUE
		else if (istype(R, /datum/stack_recipe_list))
			var/datum/stack_recipe_list/category = R
			if (crush_has_recipe(category.recipes, result_type))
				return TRUE
	return FALSE
