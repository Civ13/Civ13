// Real-beaker evidence adapter. Shares the labeled read-only chemistry viewer.
/proc/fuel_prepare_visual()
	world.name = "Civ13 LOCAL gasoline fixture"
	chemistry_visual_product = "gasoline"
	var/datum/chemical_reaction/gasoline/recipe = new
	for(var/i in 1 to 3)
		var/turf/T = locate(19+i, 20, 1)
		T = T.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
		var/obj/item/weapon/reagent_containers/glass/beaker/large/beaker = new(T)
		beaker.name = list("A: two complete gasoline batches", "B: missing butene", "C: insufficient butene")[i]
		for(var/id in recipe.required_reagents)
			if(i == 2 && id == "butene")
				continue
			var/amount = recipe.required_reagents[id] * (i == 1 ? 2 : 1)
			if(i == 3 && id == "butene")
				amount = 0.5
			chemistry_assert(beaker.reagents.add_reagent(id, amount, safety = TRUE), "Visual input missing: [id]")
		chemistry_visual_beakers += beaker
	text2file("READY: gasoline fixture; use Inspect chemistry then Run chemistry", "visual_ready.txt")
	spawn(9000)
		del(world)

/proc/fuel_run_visual()
	if(chemistry_visual_processed)
		return
	var/datum/chemical_reaction/gasoline/recipe = new
	for(var/obj/item/weapon/reagent_containers/glass/beaker/large/beaker in chemistry_visual_beakers)
		beaker.reagents.process_reactions()
	var/obj/item/weapon/reagent_containers/glass/beaker/large/positive = chemistry_visual_beakers[1]
	var/obj/item/weapon/reagent_containers/glass/beaker/large/missing = chemistry_visual_beakers[2]
	var/obj/item/weapon/reagent_containers/glass/beaker/large/insufficient = chemistry_visual_beakers[3]
	chemistry_assert(positive.reagents.get_reagent_amount("gasoline") == 40, "Visual gasoline yield")
	chemistry_assert(positive.reagents.total_volume == 40, "Visual gasoline volume")
	for(var/id in recipe.required_reagents)
		chemistry_assert(positive.reagents.get_reagent_amount(id) == 0, "Visual input not consumed: [id]")
		if(id != "butene")
			chemistry_assert(missing.reagents.get_reagent_amount(id) == recipe.required_reagents[id], "Missing-input mixture consumed: [id]")
			chemistry_assert(insufficient.reagents.get_reagent_amount(id) == recipe.required_reagents[id], "Insufficient-input mixture consumed: [id]")
	chemistry_assert(missing.reagents.get_reagent_amount("gasoline") == 0, "Visual missing ingredient")
	chemistry_assert(insufficient.reagents.get_reagent_amount("gasoline") == 0, "Visual insufficient ingredient")
	chemistry_assert(insufficient.reagents.get_reagent_amount("butene") == 0.5, "Insufficient butene consumed")
	chemistry_visual_processed = TRUE
	text2file("PASS: real beaker process_reactions - A=40 gasoline, B=0, C=0; rejected inputs preserved", "visual_result.txt")
