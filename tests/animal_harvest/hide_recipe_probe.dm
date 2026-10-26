var/global/tanning_recipe_config = 'config/crafting/material_recipes_global.txt'

// Research admission is an explicit adapter: this tests recipe families, not unlocks.
/obj/map_metadata/harvest_fixture/hide_recipes
	ID = MAP_NOMADS_GAIA
	ordinal_age = 0

/obj/map_metadata/harvest_fixture/hide_recipes/is_node_done(faction, node_id)
	return TRUE

/proc/tanning_recipe_regressions()
	var/obj/map_metadata/old_map = map
	var/list/old_catalog = craftlist_lists["global"]
	var/obj/map_metadata/harvest_fixture/hide_recipes/test_map = new
	var/list/catalog = list()
	for (var/line in file2list(tanning_recipe_config, "\n"))
		if (findtext(line, "RECIPE: ") && !findtext(line, "//"))
			catalog += list(splittext(replacetext(line, "RECIPE: ", ""), ","))
	craftlist_lists["global"] = catalog
	harvest_assert(catalog.len > 100, "Actual crafting catalog resource was not loaded")
	// Causal control: the old default hardness makes an unguarded wet hide a utensil material.
	var/material/wet = get_material_by_name("wethide")
	wet.processing_only = FALSE
	wet.generate_recipes_civs(list(100,100,100), "global")
	var/fork_found = FALSE
	var/spoon_found = FALSE
	for (var/datum/stack_recipe/R in wet.recipes)
		fork_found |= R.result_type == /obj/item/weapon/material/kitchen/utensil/fork
		spoon_found |= R.result_type == /obj/item/weapon/material/kitchen/utensil/spoon
	harvest_assert(fork_found && spoon_found, "Legacy wet-hide utensil control did not reproduce")
	wet.processing_only = TRUE
	for (var/name in list("rawhide", "hairlesshide", "wethide", "dryhide"))
		var/material/M = get_material_by_name(name)
		var/old_hardness = M.hardness
		M.hardness = 999 // Softness alone must not be the recipe-family guard.
		M.generate_recipes_civs(list(100,100,100), "global")
		harvest_assert(M.processing_only && !M.recipes.len, "Intermediate hide inherited generic recipes: [name]")
		var/list/forced_recipes = M.get_recipes_civs(forced = TRUE)
		harvest_assert(!forced_recipes.len, "Forced catalog retained intermediate recipes: [name]")
		M.hardness = old_hardness
	for (var/name in list("leather", "cowpelt", "iron"))
		var/material/M = get_material_by_name(name)
		M.generate_recipes_civs(list(100,100,100), "global")
		harvest_assert(!M.processing_only && M.recipes.len, "Legitimate finished/pelt/metal recipes were removed: [name]")
	craftlist_lists["global"] = old_catalog
	map = old_map
	qdel(test_map)
	world.log << "PASS: processing-only hides reject utensils/all crafting; actual leather/pelt/iron catalog retained"
