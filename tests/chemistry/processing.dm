/world
	hub = ""
	hub_password = ""
	maxx = 30
	maxy = 30
	maxz = 1
	turf = /turf
	area = /area

/obj/map_metadata/chemistry_ci/New()
	return

var/processing_error = FALSE

/world/Error(exception/error)
	if(!processing_error)
		text2file("FAIL: runtime [error]", "chemistry_result.txt")
	processing_error = TRUE
	world.log << "Runtime error: [error] at [error.file]:[error.line]"

/world/New()
	text2file(json_encode(list("commit" = world.params["tested_commit"], "probe" = "processing", "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "metadata.json")
	try
		initialize_chemical_reagents()
		initialize_chemical_reactions()
		map = new /obj/map_metadata/chemistry_ci
		chemistry_assert(processing_recipe_checks(), "Recipe checks did not complete")
		chemistry_assert(processing_guard_checks(), "Guard checks did not complete")
		chemistry_assert(processing_crafting_checks(), "Crafting checks did not complete")
		if(!processing_error)
			chemistry_assert(processing_extra_checks(), "Additional processing checks did not complete")
		chemistry_assert(!processing_error, "Runtime error during processing")
		if(!processing_error)
			text2file("PASS: controlled recipe outputs, calcium chain, transfers, catalyst/capacity/missing-input guards, beaker lifecycle, research/catalog and production construction", "chemistry_result.txt")
	catch(var/exception/error)
		text2file("FAIL: [error]", "chemistry_result.txt")
	del(world)

/proc/chemistry_assert(condition, message)
	if(!condition)
		if(!processing_error)
			text2file("FAIL: [message]", "chemistry_result.txt")
		processing_error = TRUE
	return condition

// Constructor adapter avoids character/random-name/global startup in this
// bounded world. Production produce_recipe/use and output New stay intact.
/mob/living/human/chemistry_builder/New()
	return

/proc/processing_add(obj/structure/reaction_bench/bench, id, amount)
	var/obj/item/weapon/reagent_containers/glass/beaker/source = new(get_turf(bench))
	chemistry_assert(source.reagents.add_reagent(id, amount, safety = TRUE), "Missing feedstock: [id]")
	chemistry_assert(bench.add_solution(source, amount) == amount, "Transfer mismatch: [id]")
	chemistry_assert(source.reagents.total_volume == 0, "Source not emptied: [id]")
	qdel(source)

/proc/processing_new_bench(small = FALSE)
	var/obj/structure/reaction_bench/bench = new(locate(20, 20, 1))
	var/obj/item/weapon/reagent_containers/glass/beaker/B
	if(small)
		B = new /obj/item/weapon/reagent_containers/glass/beaker/vial(get_turf(bench))
	else
		B = new /obj/item/weapon/reagent_containers/glass/beaker/large(get_turf(bench))
	chemistry_assert(bench.install_beaker(B), "Beaker installation failed")
	return bench

/proc/processing_recipe_checks()
	var/obj/structure/reaction_bench/catalog = new
	var/list/results = list()
	for(var/path in catalog.reaction_paths)
		var/datum/chemical_reaction/R = new path()
		var/obj/structure/reaction_bench/bench = processing_new_bench()
		for(var/id in R.required_reagents)
			processing_add(bench, id, R.required_reagents[id])
		for(var/id in R.catalysts)
			processing_add(bench, id, R.catalysts[id])
		if(R.id == "polypropylene")
			var/obj/item/weapon/laboratory_burner/burner = new(get_turf(bench))
			burner.reagents.add_reagent("pethanol", 1)
			chemistry_assert(burner.heat_bench(bench), "Fixture burner could not heat bench")
			qdel(burner)
		chemistry_assert(!bench.collector.reagents.process_reactions(), "Automatic mixing escaped inert bench")
		chemistry_assert(bench.synthesize(R.id), "Bench synthesis unavailable: [R.id]")
		chemistry_assert(bench.collector.reagents.get_reagent_amount(R.result) == R.result_amount, "Bench product mismatch: [R.id]")
		for(var/id in R.required_reagents)
			chemistry_assert(bench.collector.reagents.get_reagent_amount(id) == 0, "Bench input not consumed: [id]")
		for(var/id in R.catalysts)
			chemistry_assert(bench.collector.reagents.get_reagent_amount(id) == R.catalysts[id], "Bench catalyst consumed: [id]")
		results[R.id] = R.result_amount
		qdel(bench)
	qdel(catalog)
	var/obj/structure/reaction_bench/chain = processing_new_bench()
	processing_add(chain, "calcium", 1)
	processing_add(chain, "carbon", 1)
	processing_add(chain, "oxygen", 3)
	chemistry_assert(chain.synthesize("calcium_carbonate"), "Calcium carbonate chain failed")
	processing_add(chain, "chlorine", 10)
	chemistry_assert(chain.synthesize("calcium_chloride"), "Calcium chloride chain failed")
	chemistry_assert(chain.collector.reagents.get_reagent_amount("calcium_chloride") == 15, "Calcium chloride chain yield")
	qdel(chain)
	chemistry_assert(chemical_reagents_list["titaniumtrichloride"]:reagent_state == SOLID, "Titanium III not solid")
	chemistry_assert(chemical_reagents_list["titaniumchloride"]:reagent_state == LIQUID, "Titanium IV not liquid")
	text2file(json_encode(results), "processing_results.json")
	return TRUE

#ifndef BIOCHEMISTRY_PROBE
/proc/processing_extra_checks()
	return TRUE
#endif

/proc/processing_guard_checks()
	var/obj/structure/reaction_bench/bench = processing_new_bench(TRUE)
	processing_add(bench, "ethylene", 2)
	processing_add(bench, "titaniumchloride", 10)
	processing_add(bench, "borontrifluoride", 5)
	processing_add(bench, "aluminumchloride", 5)
	chemistry_assert(!bench.synthesize("polyethylene"), "Overflow accepted")
	chemistry_assert(bench.collector.reagents.total_volume == 22 && bench.collector.reagents.get_reagent_amount("ethylene") == 2, "Overflow consumed inputs")
	chemistry_assert(!bench.synthesize("not_a_recipe"), "Unknown recipe accepted")
	var/obj/item/weapon/reagent_containers/glass/removed = bench.remove_beaker()
	chemistry_assert(!(removed.flags & NOREACT) && removed.loc == get_turf(bench), "Ordinary beaker not restored")
	removed.flags |= NOREACT
	chemistry_assert(bench.install_beaker(removed), "Inert beaker installation")
	qdel(bench)
	chemistry_assert(removed && (removed.flags & NOREACT) && removed.loc == locate(20,20,1), "Preexisting inert flag or beaker lost on deletion")
	bench = processing_new_bench()
	processing_add(bench, "ethylene", 2)
	chemistry_assert(!bench.synthesize("polyethylene"), "Missing catalysts accepted")
	chemistry_assert(bench.collector.reagents.get_reagent_amount("ethylene") == 2, "Missing catalysts consumed input")
	qdel(bench)
	bench = processing_new_bench()
	processing_add(bench, "calcium", 1)
	chemistry_assert(!bench.synthesize("calcium_carbonate"), "Missing carbonate inputs accepted")
	chemistry_assert(bench.collector.reagents.get_reagent_amount("calcium") == 1, "Missing inputs consumed calcium")
	qdel(bench)
	return TRUE

/proc/processing_crafting_checks()
	populate_material_list()
	build_research_tree()
	chemistry_assert(get_recipe_node_req("/obj/structure/reaction_bench") == "apothecary", "Bench research mapping missing")
	craftlist_lists["config/crafting/global"] = list()
	map.load_new_recipes("config/crafting/material_recipes_global.txt")
	var/list/selected_catalog
	for(var/catalog_name in craftlist_lists)
		var/list/rows = craftlist_lists[catalog_name]
		for(var/list/row in rows)
			if(row[3] == "/obj/structure/reaction_bench")
				chemistry_assert(row.len == 13 && row[1] == "/material/glass/" && text2num(row[4]) == 10, "Bench catalog contract")
				selected_catalog = rows
	chemistry_assert(selected_catalog, "Bench catalog missing")
	// Route the production parser's file-keyed rows through the same global key
	// installed by normal setup; normal setup/schedulers stay disabled here.
	craftlist_lists["global"] = selected_catalog
	map.ordinal_age = 8
	var/material/glass/G = new
	G.generate_recipes_civs(list(999,999,999), "global", null)
	var/datum/stack_recipe/bench_recipe
	for(var/datum/stack_recipe_list/group in G.recipes)
		for(var/datum/stack_recipe/R in group.recipes)
			if(R.result_type == /obj/structure/reaction_bench)
				bench_recipe = R
	chemistry_assert(bench_recipe && bench_recipe.req_amount == 10, "Player recipe generation omitted bench")
	var/turf/T = locate(25,20,1)
	T = T.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
	var/mob/living/human/chemistry_builder/builder = new(T)
	var/obj/item/stack/material/glass/stock = new(T)
	stock.amount = 20
	bench_recipe.time = 0 // Isolated timing adapter; no craft-duration claim.
	stock.produce_recipe(bench_recipe, 1, builder)
	chemistry_assert(stock.amount == 10, "Production construction did not consume glass")
	chemistry_assert(locate(/obj/structure/reaction_bench) in T, "Production construction did not create bench")
	stock.produce_recipe(bench_recipe, 1, builder)
	chemistry_assert(stock.amount == 10, "Occupied tile consumed glass")
	var/obj/structure/reaction_bench/built = locate() in T
	qdel(built)
	stock.amount = 9
	stock.produce_recipe(bench_recipe, 1, builder)
	chemistry_assert(stock.amount == 9 && !(locate(/obj/structure/reaction_bench) in T), "Insufficient glass accepted")
	return TRUE
