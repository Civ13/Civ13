/world
	hub = ""
	hub_password = ""
	maxx = 4
	maxy = 4
	maxz = 1
	turf = /turf/floor/plating
	area = /area
	visibility = 0

/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE

// Reactions whose on_reaction spawns objects or clears the holder instead of
// leaving a reagent product.
/datum/chemical_reaction/proc/registration_spawns_objects()
	return FALSE

/datum/chemical_reaction/kevlar/registration_spawns_objects()
	return TRUE

/datum/chemical_reaction/nitrocellulose/registration_spawns_objects()
	return TRUE

/proc/registration_mix(list/inputs, product, expected, list/problems)
	var/obj/item/weapon/reagent_containers/glass/beaker/large/B = new(locate(1,1,1))
	for (var/id in inputs)
		B.reagents.add_reagent(id, inputs[id])
	// handle_reactions() only queues for the chemistry process; run its body directly.
	B.reagents.process_reactions()
	var/amount = B.reagents.get_reagent_amount(product)
	if (amount != expected)
		problems += "mixing [list2params(inputs)] produced [amount] [product], expected [expected]"
	qdel(B)

/world/New()
	OpenPort("none")
	sleep(1)
	var/list/problems = list()
	try
		initialize_chemical_reagents()
		initialize_chemical_reactions()
		var/list/owners = list()
		for (var/path in typesof(/datum/reagent) - /datum/reagent)
			var/datum/reagent/R = new path()
			if (!R.name)
				continue
			if (owners[R.id])
				problems += "duplicate reagent id [R.id]: [owners[R.id]] and [path]"
			else
				owners[R.id] = "[path]"
		var/list/default_inputs = list()
		var/datum/chemical_reaction/base = new /datum/chemical_reaction
		default_inputs = base.required_reagents
		for (var/path in typesof(/datum/chemical_reaction) - /datum/chemical_reaction)
			var/datum/chemical_reaction/C = new path()
			if (!C.required_reagents || !C.required_reagents.len)
				continue
			if (C.result && !chemical_reagents_list[C.result] && !C.registration_spawns_objects())
				problems += "unregistered product [C.result] from [path]"
			if (default_inputs && default_inputs.len && list2params(C.required_reagents) == list2params(default_inputs))
				problems += "inherited base inputs in [path]"
			for (var/input in C.required_reagents)
				if (!chemical_reagents_list[input])
					problems += "unregistered input [input] in [path]"
		if (default_inputs && default_inputs.len)
			problems += "base reaction declares default inputs"
		var/list/expected_types = list("coffee" = /datum/reagent/drink/coffee, "ethanol" = /datum/reagent/ethanol, "drink" = /datum/reagent/drink, "toxin" = /datum/reagent/toxin, "condensedcapsaicin" = /datum/reagent/capsaicin/condensed, "salbutamol" = /datum/reagent/salbutamol)
		for (var/id in expected_types)
			var/datum/reagent/R = chemical_reagents_list[id]
			if (!R || R.type != expected_types[id])
				problems += "id [id] resolves to [R ? R.type : "nothing"]"
		registration_mix(list("isobutylene" = 10, "aluminumchloride" = 1), "butylrubber", 5, problems)
		registration_mix(list("coffee" = 10, "milk" = 10), "cafe_latte", 20, problems)
		registration_mix(list("wine" = 10, "cocaine" = 1, "enzyme" = 5), "coca_wine", 10, problems)
		registration_mix(list("ethanol" = 10, "anti_toxin" = 10, "hclacid" = 10), "sterilizine", 30, problems)
		registration_mix(list("acetone" = 5, "carbon" = 5, "sugar" = 5), "acetone", 5, problems)
		for (var/line in problems)
			world.log << "CHEM PROBLEM: [line]"
		text2file(problems.len ? "FAIL: [problems.len] registration problems" : "PASS: chemical registration consistent", "result.txt")
	catch (var/exception/E)
		world.log << "CHEM exception: [E] at [E.file]:[E.line]"
		text2file("FAIL: [E.name]", "result.txt")
	shutdown()
