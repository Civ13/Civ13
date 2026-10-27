// Controlled game reactions avoid ambiguous automatic elemental mixtures.
/obj/structure/reaction_bench
	name = "laboratory reaction bench"
	desc = "Holds a beaker inert while you choose a game laboratory recipe. These conversions are not real synthesis instructions."
	icon = 'icons/obj/chemical.dmi'
	icon_state = "mixer0b"
	density = TRUE
	anchored = TRUE
	var/obj/item/weapon/reagent_containers/glass/collector = null
	var/collector_was_inert = FALSE
	var/heated_until = 0
	var/list/reaction_paths = list(/datum/chemical_reaction/ethanoic_acid, /datum/chemical_reaction/calcium_carbonate, /datum/chemical_reaction/calcium_chloride, /datum/chemical_reaction/gluconic_acid, /datum/chemical_reaction/calcium_gluconate, /datum/chemical_reaction/sodium_sulfide, /datum/chemical_reaction/sodium_hydroxide, /datum/chemical_reaction/sulfurous_acid, /datum/chemical_reaction/hydrogen_sulfites, /datum/chemical_reaction/n_methylmorpholine_n_oxide, /datum/chemical_reaction/isobutylene, /datum/chemical_reaction/butylrubber, /datum/chemical_reaction/titaniumchloride, /datum/chemical_reaction/titaniumtrichloride, /datum/chemical_reaction/aluminumchloride, /datum/chemical_reaction/borontrifluoride, /datum/chemical_reaction/ethylene, /datum/chemical_reaction/propylene, /datum/chemical_reaction/polyethylene, /datum/chemical_reaction/octane, /datum/chemical_reaction/cyclopentane, /datum/chemical_reaction/toluene, /datum/chemical_reaction/butene, /datum/chemical_reaction/gasoline)

/obj/structure/reaction_bench/proc/install_beaker(obj/item/weapon/reagent_containers/glass/B, mob/user)
	if(collector || !B || !B.reagents)
		return FALSE
	if(user)
		user.drop_item()
	collector = B
	heated_until = 0
	collector_was_inert = (B.flags & NOREACT) != 0
	B.flags |= NOREACT
	B.loc = src
	return TRUE

/obj/structure/reaction_bench/proc/remove_beaker()
	if(!collector)
		return null
	var/obj/item/weapon/reagent_containers/glass/B = collector
	if(!collector_was_inert)
		B.flags &= ~NOREACT
	B.loc = get_turf(src)
	collector = null
	heated_until = 0
	B.reagents.handle_reactions()
	return B

/obj/structure/reaction_bench/proc/add_solution(obj/item/weapon/reagent_containers/glass/B, amount)
	if(!collector || collector.loc != src || !B || B == collector || !B.reagents || !isnum(amount) || amount <= 0)
		return 0
	return B.reagents.trans_to_holder(collector.reagents, amount)

/obj/structure/reaction_bench/proc/find_reaction(id)
	for(var/path in reaction_paths)
		var/datum/chemical_reaction/R = new path()
		if(R.id == id)
			return R
	return null

/obj/structure/reaction_bench/proc/synthesize(id)
	if(!collector || collector.loc != src || !(collector.flags & NOREACT))
		return FALSE
	var/datum/reagents/holder = collector.reagents
	var/datum/chemical_reaction/R = find_reaction(id)
	// Never consume input for a missing output or an unavailable recipe.
	if(!R || !R.result || !chemical_reagents_list[R.result] || !R.can_happen(holder))
		return FALSE
	var/list/limits = list()
	var/input_per_batch = 0
	for(var/reagent_id in R.required_reagents)
		limits += holder.get_reagent_amount(reagent_id) / R.required_reagents[reagent_id]
		input_per_batch += R.required_reagents[reagent_id]
	var/limit = min(limits)
	var/progress = min(limit, R.calc_reaction_progress(holder, limit))
	if(progress <= 0 || holder.total_volume + progress * (R.result_amount - input_per_batch) > holder.maximum_volume)
		return FALSE
	return R.process(holder) > 0

/obj/structure/reaction_bench/attackby(obj/item/W, mob/user)
	if(istype(W, /obj/item/weapon/laboratory_burner))
		var/obj/item/weapon/laboratory_burner/burner = W
		if(burner.heat_bench(src))
			to_chat(user, SPAN_NOTICE("You fuel the burner and heat the secured beaker for one minute."))
		else
			to_chat(user, SPAN_WARNING("Secure a beaker and fill the burner with purified ethanol first."))
		return
	if(istype(W, /obj/item/weapon/reagent_containers/glass))
		var/obj/item/weapon/reagent_containers/glass/B = W
		if(!collector)
			if(install_beaker(B, user))
				to_chat(user, SPAN_NOTICE("You secure the beaker. Its mixture is held inert until you select a recipe."))
		else
			var/added = add_solution(B, B.amount_per_transfer_from_this)
			to_chat(user, SPAN_NOTICE("You transfer [added] units into the secured beaker."))
		return
	..()

/obj/structure/reaction_bench/attack_hand(mob/user)
	if(!collector)
		to_chat(user, SPAN_NOTICE("Insert a beaker, then pour individual feedstocks into it."))
		return
	var/list/options = list()
	for(var/path in reaction_paths)
		var/datum/chemical_reaction/R = new path()
		options[R.name] = R.id
	var/choice = input(user, "Choose a game reaction. All required inputs and catalysts must be present; the output must fit.", name) as null|anything in options
	var/turf/user_turf = get_turf(user)
	var/turf/bench_turf = get_turf(src)
	if(!choice || !user || user.stat || user.restrained() || !user_turf || !bench_turf || user_turf.z != bench_turf.z || get_dist(user_turf, bench_turf) > 1)
		return
	if(synthesize(options[choice]))
		to_chat(user, SPAN_NOTICE("The selected game reaction completes."))
	else
		to_chat(user, SPAN_WARNING("That reaction cannot proceed. Check inputs, catalysts, and available capacity. Nothing was consumed."))

/obj/structure/reaction_bench/verb/eject_beaker()
	set name = "Remove reaction beaker"
	set src in range(1)
	remove_beaker()

/obj/structure/reaction_bench/Destroy()
	remove_beaker()
	return ..()

/obj/structure/reaction_bench/proc/is_heated()
	return collector && collector.loc == src && heated_until > world.time

/obj/structure/reaction_bench/New()
	..()
	reaction_paths += list(/datum/chemical_reaction/hydrogen_chloride, /datum/chemical_reaction/hclacid, /datum/chemical_reaction/polypropylene, /datum/chemical_reaction/gelatin_acid, /datum/chemical_reaction/gelatin_enzyme, /datum/chemical_reaction/gelatin_fruit, /datum/chemical_reaction/gelatin_water, /datum/chemical_reaction/gelatin_ethanol, /datum/chemical_reaction/enginefuel)

/obj/item/weapon/laboratory_burner
	name = "laboratory burner"
	desc = "Uses one unit of purified ethanol to heat a secured reaction-bench beaker for one minute."
	icon = 'icons/obj/chemical.dmi'
	icon_state = "extraction_kit"
	flags = NOREACT | OPENCONTAINER

/obj/item/weapon/laboratory_burner/New()
	..()
	reagents = new /datum/reagents(20, src)

/obj/item/weapon/laboratory_burner/proc/heat_bench(obj/structure/reaction_bench/bench)
	var/turf/burner_turf = get_turf(src)
	var/turf/bench_turf = get_turf(bench)
	if(!burner_turf || !bench_turf || burner_turf.z != bench_turf.z || get_dist(burner_turf, bench_turf) > 1 || !bench.collector || bench.collector.loc != bench || !reagents.has_reagent("pethanol", 1))
		return FALSE
	reagents.remove_reagent("pethanol", 1)
	bench.heated_until = world.time + 1 MINUTE
	return TRUE

/obj/item/weapon/laboratory_burner/attackby(obj/item/W, mob/user)
	if(istype(W, /obj/item/weapon/reagent_containers/glass))
		var/obj/item/weapon/reagent_containers/glass/B = W
		var/amount = min(B.amount_per_transfer_from_this, B.reagents.get_reagent_amount("pethanol"), reagents.get_free_space())
		if(amount > 0)
			reagents.add_reagent("pethanol", amount)
			B.reagents.remove_reagent("pethanol", amount)
		to_chat(user, SPAN_NOTICE("You add [amount] units of purified ethanol to the burner."))
		return
	..()
