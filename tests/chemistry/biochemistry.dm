#define BIOCHEMISTRY_PROBE
#include "processing.dm"

// Actual timed centrifuge callback; only the external power boundary is injected.
/obj/structure/centrifuge/chemistry_power
	var/fixture_power = TRUE
	check_power()
		return fixture_power

/proc/processing_extra_checks()
	GLOB.all_observable_events = list()
	GLOB.moved_event = new /decl/observ/moved
	GLOB.dir_set_event = new /decl/observ/dir_set
	GLOB.name_set_event = new /decl/observ/name_set
	GLOB.stat_set_event = new /decl/observ/stat_set
	biochemistry_acquisition_checks()
	biochemistry_heat_fuel_checks()
	biochemistry_gelatin_checks()
	return TRUE

/proc/biochemistry_build(result_path, material_path, stack_path, cost, x)
	var/material/M = new material_path()
	M.generate_recipes_civs(list(999,999,999), "global", null)
	var/datum/stack_recipe/recipe
	for(var/entry in M.recipes)
		if(istype(entry, /datum/stack_recipe))
			var/datum/stack_recipe/R = entry
			if(R.result_type == result_path)
				recipe = R
		else if(istype(entry, /datum/stack_recipe_list))
			var/datum/stack_recipe_list/group = entry
			for(var/datum/stack_recipe/R in group.recipes)
				if(R.result_type == result_path)
					recipe = R
	chemistry_assert(recipe && recipe.req_amount == cost, "Equipment catalog/research missing: [result_path]")
	var/turf/T = locate(x, 20, 1)
	T = T.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
	var/mob/living/human/chemistry_builder/builder = new(T)
	var/obj/item/stack/stock = new stack_path(T)
	stock.amount = cost + 5
	recipe.time = 0 // Only the timed build is adapted.
	stock.produce_recipe(recipe, 1, builder)
	chemistry_assert(stock.amount == 5, "Equipment craft cost: [result_path]")
	var/obj/output = locate(result_path) in T
	chemistry_assert(output, "Equipment constructor missing: [result_path]")
	return output

/proc/biochemistry_supply(obj/structure/chemical_dispenser/D, obj/structure/reaction_bench/bench, id, amount)
	var/obj/item/weapon/reagent_containers/glass/beaker/B = new(D)
	D.beaker = B // Container-install/UI boundary adapter; actual dispensing stays intact.
	chemistry_assert(D.dispense_into_beaker(id, amount) == amount, "Player supply unavailable: [id]")
	chemistry_assert(bench.add_solution(B, amount) == amount, "Supply transfer: [id]")
	chemistry_assert(B.reagents.total_volume == 0, "Supply source remained full: [id]")
	D.beaker = null
	qdel(B)

/proc/biochemistry_acquisition_checks()
	var/obj/structure/chemical_dispenser/full/laboratory/D = biochemistry_build(/obj/structure/chemical_dispenser/full/laboratory, /material/glass, /obj/item/stack/material/glass, 20, 26)
	var/obj/structure/reaction_bench/bench = processing_new_bench()
	for(var/id in list("hydrogen", "carbon", "oxygen", "nitrogen", "calcium", "chlorine", "sodium", "sulfur", "titanium", "boron", "fluorine", "aluminum", "water", "pethanol"))
		biochemistry_supply(D, bench, id, 1)
	bench.collector.reagents.clear_reagents()
	biochemistry_supply(D, bench, "hydrogen", 2)
	biochemistry_supply(D, bench, "chlorine", 2)
	chemistry_assert(bench.synthesize("hydrogen_chloride"), "Obtainable hydrogen chloride precursor")
	biochemistry_supply(D, bench, "water", 5)
	chemistry_assert(bench.synthesize("hclacid") && bench.collector.reagents.get_reagent_amount("hclacid") == 5, "Obtainable hydrochloric-acid chain")
	bench.collector.reagents.clear_reagents()
	D.beaker = new /obj/item/weapon/reagent_containers/glass/beaker(D)
	chemistry_assert(D.dispense_into_beaker("not_registered", 5) == 0, "Dispenser accepted unknown reagent")
	chemistry_assert(D.dispense_into_beaker("titanium", -5) == 0, "Dispenser accepted negative quantity")
	chemistry_assert(D.dispense_into_beaker("titanium", 120) == 60, "Dispenser capacity clamp")
	D.beaker.reagents.clear_reagents()
	chemistry_assert(D.dispense_into_beaker("titanium", 120) == 39, "Finite titanium stock not decremented")
	D.beaker.reagents.clear_reagents()
	chemistry_assert(D.dispense_into_beaker("titanium", 1) == 0, "Dispenser minted depleted stock")
	qdel(D.beaker)
	qdel(D)
	qdel(bench)
	var/obj/structure/wild/W = new(locate(22,20,1))
	W.generate_seed_list("jungle")
	chemistry_assert(/obj/item/stack/farming/seeds/papaya in seed_list_jungle, "Papaya absent from natural seed gathering")
	var/turf/planting = locate(22,20,1)
	planting.ChangeTurf(/turf/floor/dirt/ploughed, FALSE, FALSE)
	var/obj/item/stack/farming/seeds/papaya/seed = new(locate(22,20,1))
	seed.spawn_plant(get_turf(seed))
	var/obj/structure/farming/plant/papaya/crop = locate() in get_turf(seed)
	chemistry_assert(crop && crop.sprite_plant == "orange", "Papaya planting failed")
	var/list/crop_states = icon_states(crop.icon)
	for(var/stage in 1 to 6)
		chemistry_assert("orange-grow[stage]" in crop_states, "Papaya crop sprite missing growth stage [stage]")
	chemistry_assert("orange-harvest" in crop_states && "orange-dead" in crop_states, "Papaya harvest/dead sprites missing")
	crop.stage = 7 // Harvest-ready fixture; no growth-duration claim.
	var/mob/living/human/chemistry_builder/harvester = new(get_turf(seed))
	var/obj/item/weapon/material/kitchen/utensil/knife/knife = new(get_turf(seed))
	crop.attackby(knife, harvester)
	chemistry_assert(locate(/obj/item/weapon/reagent_containers/food/snacks/grown/papaya) in get_turf(seed), "Actual harvest omitted papaya")
	var/obj/item/weapon/reagent_containers/food/snacks/grown/papaya/fruit = locate() in get_turf(seed)
	chemistry_assert(fruit.icon_state in icon_states(fruit.icon), "Papaya fruit sprite missing")
	chemistry_assert(!crop.loc, "Harvest did not remove crop")
	var/obj/item/weapon/reagent_containers/glass/extraction_kit/kit = biochemistry_build(/obj/item/weapon/reagent_containers/glass/extraction_kit, /material/iron, /obj/item/stack/material/iron, 14, 27)
	for(var/source_path in list(/obj/item/weapon/reagent_containers/food/snacks/meat, /obj/effect/decal/cleanable/vomit, /obj/item/weapon/reagent_containers/food/snacks/grown/papaya))
		var/atom/source = new source_path(get_turf(kit))
		chemistry_assert(kit.extract_biological(source), "Biological source extraction failed: [source_path]")
		chemistry_assert(kit.reagents.total_volume == 4 && !source.loc, "Extraction yield/source consumption")
		var/atom/other = new source_path(get_turf(kit))
		chemistry_assert(!kit.extract_biological(other) && other.loc, "Nonempty kit consumed biological source")
		kit.reagents.clear_reagents()
		qdel(other)
	var/obj/item/weapon/reagent_containers/food/snacks/meat/spoiled = new(get_turf(kit))
	spoiled.rotten = TRUE
	chemistry_assert(!kit.extract_biological(spoiled) && spoiled.loc, "Spoiled meat accepted")
	chemistry_assert(!kit.extract_biological(knife) && knife.loc, "Unknown biological source consumed")
	qdel(kit)

/proc/biochemistry_heat_fuel_checks()
	var/obj/structure/reaction_bench/bench = processing_new_bench()
	processing_add(bench, "propylene", 2)
	processing_add(bench, "titaniumchloride", 10)
	processing_add(bench, "borontrifluoride", 5)
	processing_add(bench, "aluminumchloride", 5)
	chemistry_assert(!bench.synthesize("polypropylene") && bench.collector.reagents.get_reagent_amount("propylene") == 2, "Cold polypropylene accepted")
	var/obj/item/weapon/laboratory_burner/burner = biochemistry_build(/obj/item/weapon/laboratory_burner, /material/iron, /obj/item/stack/material/iron, 4, 28)
	burner.loc = get_turf(bench)
	chemistry_assert(!burner.heat_bench(bench), "Empty burner heated bench")
	var/obj/item/weapon/reagent_containers/glass/beaker/fuel = new(get_turf(bench))
	fuel.reagents.add_reagent("pethanol", 2)
	burner.attackby(fuel, null)
	chemistry_assert(fuel.reagents.total_volume == 0 && burner.reagents.get_reagent_amount("pethanol") == 2, "Burner filling did not transfer fuel")
	burner.loc = locate(1,1,1)
	chemistry_assert(!burner.heat_bench(bench) && burner.reagents.get_reagent_amount("pethanol") == 2, "Remote burner heated bench or consumed fuel")
	burner.loc = null
	chemistry_assert(!burner.heat_bench(bench), "Unlocated burner heated bench")
	burner.loc = get_turf(bench)
	chemistry_assert(burner.heat_bench(bench) && burner.reagents.get_reagent_amount("pethanol") == 1, "Burner heat fuel cost")
	bench.heated_until = world.time - 1
	chemistry_assert(!bench.synthesize("polypropylene"), "Expired heat accepted")
	chemistry_assert(burner.heat_bench(bench) && bench.synthesize("polypropylene"), "Heated polypropylene rejected")
	chemistry_assert(bench.collector.reagents.get_reagent_amount("polypropylene") == 25 && burner.reagents.total_volume == 0, "Heated polymer or fuel yield")
	qdel(bench)
	bench = processing_new_bench()
	processing_add(bench, "gasoline", 18)
	chemistry_assert(!bench.synthesize("enginefuel"), "Fuel blend without ethanol accepted")
	processing_add(bench, "pethanol", 2)
	chemistry_assert(bench.synthesize("enginefuel") && bench.collector.reagents.get_reagent_amount("enginefuel") == 20, "Scaled 9:1 enginefuel yield")
	var/obj/structure/engine/internal/gasoline/engine = new(get_turf(bench))
	var/obj/item/weapon/reagent_containers/glass/barrel/tank = new(get_turf(bench))
	chemistry_assert(bench.collector.reagents.trans_to_holder(tank.reagents, 20) == 20, "Fuel tank transfer")
	engine.fueltank = tank
	engine.currentpower = engine.maxpower
	engine.on = TRUE
	engine.running()
	chemistry_assert(abs(tank.reagents.get_reagent_amount("enginefuel") - 19.4) < 0.001 && engine.on, "Real gasoline engine did not consume blended fuel")
	engine.on = FALSE
	tank.reagents.clear_reagents()
	tank.reagents.add_reagent("gasoline", 20)
	engine.on = TRUE
	engine.currentpower = engine.maxpower
	engine.running()
	chemistry_assert(abs(tank.reagents.get_reagent_amount("gasoline") - 19.4) < 0.001 && engine.on, "Existing gasoline consumption changed")
	engine.on = FALSE
	var/obj/structure/engine/internal/diesel/diesel = new(get_turf(bench))
	chemistry_assert(!("enginefuel" in diesel.fuels), "Diesel-only engine accepts gasoline blend")
	qdel(engine)
	qdel(diesel)
	qdel(bench)

/proc/biochemistry_gelatin_checks()
	var/obj/structure/centrifuge/C = biochemistry_build(/obj/structure/centrifuge, /material/electronics, /obj/item/stack/material/electronics, 24, 29)
	C.collector = new /obj/item/weapon/reagent_containers/glass/beaker/vial(C)
	C.reagents.add_reagent("water", 10)
	chemistry_assert(!C.separate_batch() && C.reagents.total_volume == 10, "Unknown centrifuge input consumed")
	C.reagents.clear_reagents()
	C.reagents.add_reagent("blood", 10)
	chemistry_assert(C.separate_batch(), "Blood separation failed")
	chemistry_assert(C.collector.reagents.get_reagent_amount("blood_plasma") == 6 && C.collector.reagents.get_reagent_amount("red_blood_cells") == 3 && C.collector.reagents.get_reagent_amount("white_blood_cells") == 1, "Blood separation did not recover all fractions")
	C.collector.reagents.clear_reagents()
	C.reagents.add_reagent("unpurified_gelatin", 10)
	C.collector.reagents.add_reagent("water", C.collector.reagents.maximum_volume)
	chemistry_assert(!C.separate_batch() && C.reagents.total_volume == 10, "Full collector consumed gelatin")
	C.collector.reagents.clear_reagents()
	C.active = TRUE
	C.process_machine()
	chemistry_assert(!C.active && C.reagents.total_volume == 10, "Unpowered centrifuge consumed input")
	qdel(C)
	for(var/treatment in list("hclacid", "proteolytic_enzyme", "fruit_protease"))
		for(var/solvent in list("water", "pethanol"))
			var/obj/structure/reaction_bench/bench = processing_new_bench()
			var/obj/item/weapon/reagent_containers/glass/extraction_kit/kit = new(get_turf(bench))
			var/obj/item/weapon/reagent_containers/food/snacks/meat/meat = new(get_turf(bench))
			chemistry_assert(kit.extract_biological(meat) && bench.add_solution(kit, 4) == 4, "Collagen-to-bench path")
			processing_add(bench, treatment, 1)
			var/recipe_id = treatment == "hclacid" ? "gelatin_acid" : (treatment == "fruit_protease" ? "gelatin_fruit" : "gelatin_enzyme")
			chemistry_assert(bench.synthesize(recipe_id), "Gelatin treatment failed: [recipe_id]")
			C = new /obj/structure/centrifuge(get_turf(bench))
			C.collector = new /obj/item/weapon/reagent_containers/glass/beaker/vial(C)
			chemistry_assert(bench.collector.reagents.trans_to_holder(C.reagents, 5) == 5 && C.separate_batch(), "Crude gelatin transfer/purification")
			chemistry_assert(C.collector.reagents.get_reagent_amount("purified_gelatin") == 4 && C.reagents.total_volume == 0, "Purified gelatin yield")
			chemistry_assert(bench.add_solution(C.collector, 4) == 4, "Purified gelatin return transfer")
			processing_add(bench, solvent, 1)
			chemistry_assert(bench.synthesize(solvent == "water" ? "gelatin_water" : "gelatin_ethanol") && bench.collector.reagents.get_reagent_amount("gelatin") == 5, "Solid gelatin final yield")
			qdel(C)
			qdel(bench)
	var/obj/structure/centrifuge/chemistry_power/timed = new(locate(20,20,1))
	timed.collector = new /obj/item/weapon/reagent_containers/glass/beaker/vial(timed)
	timed.reagents.add_reagent("unpurified_gelatin", 5)
	timed.active = TRUE
	timed.process_machine()
	var/obj/structure/centrifuge/chemistry_power/interrupted = new(locate(21,20,1))
	interrupted.collector = new /obj/item/weapon/reagent_containers/glass/beaker/vial(interrupted)
	interrupted.reagents.add_reagent("unpurified_gelatin", 5)
	interrupted.active = TRUE
	interrupted.process_machine()
	interrupted.fixture_power = FALSE
	var/obj/structure/centrifuge/chemistry_power/missing = new(locate(22,20,1))
	missing.collector = new /obj/item/weapon/reagent_containers/glass/beaker/vial(missing)
	missing.reagents.add_reagent("unpurified_gelatin", 5)
	missing.active = TRUE
	missing.process_machine()
	qdel(missing.collector)
	missing.collector = null
	var/obj/structure/centrifuge/chemistry_power/restarted = new(locate(23,20,1))
	restarted.collector = new /obj/item/weapon/reagent_containers/glass/beaker/vial(restarted)
	restarted.reagents.add_reagent("unpurified_gelatin", 5)
	restarted.active = TRUE
	restarted.process_machine()
	sleep(1 SECONDS)
	restarted.process_machine()
	sleep(14 SECONDS + 1)
	chemistry_assert(!timed.active && timed.collector.reagents.get_reagent_amount("purified_gelatin") == 4, "Real timed centrifuge callback failed")
	chemistry_assert(!interrupted.active && interrupted.reagents.total_volume == 5 && interrupted.collector.reagents.total_volume == 0, "Lost power consumed input or left centrifuge active")
	chemistry_assert(!missing.active && missing.reagents.total_volume == 5, "Lost collector consumed input or left centrifuge active")
	chemistry_assert(restarted.active && restarted.reagents.total_volume == 5, "Obsolete centrifuge cycle completed newer operation early")
	sleep(1 SECONDS)
	chemistry_assert(!restarted.active && restarted.collector.reagents.get_reagent_amount("purified_gelatin") == 4, "Restarted centrifuge cycle did not finish")
	qdel(timed)
	qdel(interrupted)
	qdel(missing)
	qdel(restarted)
