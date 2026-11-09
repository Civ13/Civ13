// Controlled game reactions avoid ambiguous automatic elemental mixtures.
// The reaction bench and the factory reaction vessel offer these recipes.
/proc/controlled_reaction_paths()
	return list(/datum/chemical_reaction/ethanoic_acid, /datum/chemical_reaction/calcium_carbonate, /datum/chemical_reaction/calcium_chloride, /datum/chemical_reaction/gluconic_acid, /datum/chemical_reaction/calcium_gluconate, /datum/chemical_reaction/sodium_sulfide, /datum/chemical_reaction/sodium_hydroxide, /datum/chemical_reaction/sulfurous_acid, /datum/chemical_reaction/hydrogen_sulfites, /datum/chemical_reaction/n_methylmorpholine_n_oxide, /datum/chemical_reaction/isobutylene, /datum/chemical_reaction/butylrubber, /datum/chemical_reaction/titaniumchloride, /datum/chemical_reaction/titaniumtrichloride, /datum/chemical_reaction/aluminumchloride, /datum/chemical_reaction/borontrifluoride, /datum/chemical_reaction/ethylene, /datum/chemical_reaction/propylene, /datum/chemical_reaction/polyethylene, /datum/chemical_reaction/octane, /datum/chemical_reaction/cyclopentane, /datum/chemical_reaction/toluene, /datum/chemical_reaction/butene, /datum/chemical_reaction/gasoline, /datum/chemical_reaction/hydrogen_chloride, /datum/chemical_reaction/hclacid, /datum/chemical_reaction/polypropylene, /datum/chemical_reaction/gelatin_acid, /datum/chemical_reaction/gelatin_enzyme, /datum/chemical_reaction/gelatin_fruit, /datum/chemical_reaction/gelatin_water, /datum/chemical_reaction/gelatin_ethanol, /datum/chemical_reaction/gelatin_mixed_solvent, /datum/chemical_reaction/gelatin_foam, /datum/chemical_reaction/enginefuel, /datum/chemical_reaction/rayon_fiber, /datum/chemical_reaction/lyocell_fiber)

var/global/list/controlled_reactions_by_id = null

// One shared reaction datum per controlled recipe id.
/proc/controlled_reaction(id)
	if (!controlled_reactions_by_id)
		controlled_reactions_by_id = list()
		for (var/path in controlled_reaction_paths())
			var/datum/chemical_reaction/R = new path()
			controlled_reactions_by_id[R.id] = R
	return controlled_reactions_by_id[id]

// Whether holder sits where a controlled reaction may run: the secured beaker
// of a reaction bench, or a powered factory reaction vessel. Heat comes from
// the bench's burner or the vessel's power.
/proc/controlled_reaction_site(datum/reagents/holder, needs_heat = FALSE)
	var/atom/A = holder ? holder.my_atom : null
	if (!A)
		return FALSE
	if (istype(A, /obj/structure/fluid_vessel))
		var/obj/structure/fluid_vessel/V = A
		return V.powered
	var/obj/structure/reaction_bench/bench = A.loc
	return istype(bench) && bench.collector == A && (!needs_heat || bench.is_heated())

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
	var/list/reaction_paths = null

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
	options["Make cloth from rayon fibre"] = "cloth_rayon"
	options["Make cloth from lyocell fibre"] = "cloth_lyocell"
	options["Make stoppered plastic bottle"] = "polymer_bottle"
	options["Make plastic storage bag"] = "polymer_bag"
	options["Make polyethylene sheet"] = "polyethylene_sheet"
	options["Make polypropylene sheet"] = "polypropylene_sheet"
	options["Make polypropylene cloth"] = "polypropylene_cloth"
	options["Make plastic comb"] = "polypropylene_comb"
	options["Make plastic play ball"] = "polyethylene_ball"
	options["Make butyl adhesive tape"] = "butyl_tape"
	options["Make butyl stopper"] = "butyl_stopper"
	options["Make butyl gasket"] = "butyl_gasket"
	var/choice = player_input(user, "Choose a game reaction. All required inputs and catalysts must be present; the output must fit.", name, null, "anything", options, TRUE)
	var/turf/user_turf = get_turf(user)
	var/turf/bench_turf = get_turf(src)
	if(!choice || !user || user.stat || user.restrained() || !user_turf || !bench_turf || user_turf.z != bench_turf.z || get_dist(user_turf, bench_turf) > 1)
		return
	var/selected = options[choice]
	var/succeeded
	if(selected == "cloth_rayon")
		succeeded = finish_wood_fiber("rayon_fiber")
	else if(selected == "cloth_lyocell")
		succeeded = finish_wood_fiber("lyocell_fiber")
	else if(selected in list("polymer_bottle", "polymer_bag", "polyethylene_sheet", "polypropylene_sheet", "polypropylene_cloth", "polypropylene_comb", "polyethylene_ball", "butyl_tape", "butyl_stopper", "butyl_gasket"))
		succeeded = finish_polymer_product(selected)
	else
		succeeded = synthesize(selected)
	if(succeeded)
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

// Four units of either fibre produce one ordinary cloth sheet.
/obj/structure/reaction_bench/proc/finish_wood_fiber(id)
	if(gcDestroyed || gc_destroyed || !(id in list("rayon_fiber", "lyocell_fiber")) || !collector || collector.gcDestroyed || collector.gc_destroyed || collector.loc != src || !(collector.flags & NOREACT) || !collector.reagents || !isturf(loc) || !collector.reagents.has_reagent(id, 4))
		return FALSE
	collector.reagents.remove_reagent(id, 4)
	new /obj/item/stack/material/cloth(loc, 1)
	return TRUE

// Paid polymer batches become existing functional containers.
/obj/structure/reaction_bench/proc/finish_polymer_product(product)
	if(gcDestroyed || gc_destroyed || !collector || collector.gcDestroyed || collector.gc_destroyed || collector.loc != src || !(collector.flags & NOREACT) || !collector.reagents || !isturf(loc))
		return FALSE
	if(product == "polymer_bottle")
		if(!collector.reagents.has_reagent("polyethylene", 4) || !collector.reagents.has_reagent("butylrubber", 1))
			return FALSE
		collector.reagents.remove_reagent("polyethylene", 4)
		collector.reagents.remove_reagent("butylrubber", 1)
		new /obj/item/weapon/reagent_containers/food/drinks/bottle/plastic/stoppered(loc)
		return TRUE
	if(product == "polyethylene_sheet" || product == "polypropylene_sheet")
		var/plastic = product == "polyethylene_sheet" ? "polyethylene" : "polypropylene"
		if(!collector.reagents.has_reagent(plastic, 4))
			return FALSE
		collector.reagents.remove_reagent(plastic, 4)
		new /obj/item/stack/material/plastic(loc, 1)
		return TRUE
	if(product == "polymer_bag")
		if(!collector.reagents.has_reagent("polypropylene", 4))
			return FALSE
		collector.reagents.remove_reagent("polypropylene", 4)
		new /obj/item/weapon/evidencebag(loc)
		return TRUE
	if(product == "polypropylene_cloth" || product == "polypropylene_comb")
		if(!collector.reagents.has_reagent("polypropylene", 4))
			return FALSE
		collector.reagents.remove_reagent("polypropylene", 4)
		if(product == "polypropylene_cloth")
			new /obj/item/stack/material/cloth(loc, 1)
		else
			new /obj/item/weapon/haircomb(loc)
		return TRUE
	if(product == "polyethylene_ball")
		if(!collector.reagents.has_reagent("polyethylene", 4))
			return FALSE
		collector.reagents.remove_reagent("polyethylene", 4)
		new /obj/item/weapon/basketball/plastic(loc)
		return TRUE
	if(product == "butyl_stopper" || product == "butyl_gasket")
		if(!collector.reagents.has_reagent("butylrubber", 1))
			return FALSE
		collector.reagents.remove_reagent("butylrubber", 1)
		if(product == "butyl_gasket")
			new /obj/item/butyl_stopper/gasket(loc)
		else
			new /obj/item/butyl_stopper(loc)
		return TRUE
	if(product == "butyl_tape")
		if(!collector.reagents.has_reagent("butylrubber", 2) || !collector.reagents.has_reagent("polypropylene", 2))
			return FALSE
		collector.reagents.remove_reagent("butylrubber", 2)
		collector.reagents.remove_reagent("polypropylene", 2)
		new /obj/item/taperoll/butyl(loc)
		return TRUE
	return FALSE

/obj/item/weapon/basketball/plastic
	name = "plastic play ball"
	desc = "A lightweight polyethylene ball for play."

/obj/item/butyl_stopper
	name = "butyl rubber stopper"
	desc = "A rubber stopper for sealing a small vial or drink bottle."
	icon = 'icons/obj/chemical.dmi'
	icon_state = "lid_bottle"
	w_class = ITEM_SIZE_SMALL

/obj/item/butyl_stopper/gasket
	name = "butyl rubber gasket"
	desc = "A rubber gasket for sealing a vial or drink bottle. Apply it to an open container."

/obj/item/butyl_stopper/proc/seal_bottle(obj/item/weapon/reagent_containers/container)
	if(gcDestroyed || gc_destroyed || !container || container.gcDestroyed || container.gc_destroyed || !container.is_open_container())
		return FALSE
	if(!istype(container, /obj/item/weapon/reagent_containers/glass/bottle) && !istype(container, /obj/item/weapon/reagent_containers/food/drinks/bottle))
		return FALSE
	if(istype(container, /obj/item/weapon/reagent_containers/food/drinks/bottle))
		var/obj/item/weapon/reagent_containers/food/drinks/bottle/drink = container
		if(drink.rag)
			return FALSE
	container.flags &= ~OPENCONTAINER
	container.update_icon()
	qdel(src)
	return TRUE

/obj/item/butyl_stopper/afterattack(atom/A, mob/user, proximity)
	if(istype(A, /obj/item/weapon/reagent_containers))
		if(!proximity || !user || user.stat || user.restrained() || user.get_active_hand() != src)
			return
		if(seal_bottle(A))
			to_chat(user, SPAN_NOTICE("You seal [A] with the rubber stopper."))
		return
	return ..()

/obj/item/taperoll/butyl
	name = "butyl adhesive tape"
	desc = "A roll of butyl adhesive tape. Use it on copper to make insulated cable, or to repair a broken drone."

/obj/item/taperoll/butyl/proc/insulate_copper(obj/item/stack/material/copper/conductor)
	var/turf/site = get_turf(src)
	if(gcDestroyed || gc_destroyed || !site || !conductor || conductor.gcDestroyed || conductor.gc_destroyed || !conductor.can_use(1))
		return FALSE
	conductor.use(1)
	new /obj/item/stack/cable_coil(site, 1)
	qdel(src)
	return TRUE

/obj/item/taperoll/butyl/afterattack(atom/A, mob/user, proximity)
	if(istype(A, /obj/item/stack/material/copper))
		if(!proximity || !user || user.stat || user.restrained() || user.get_active_hand() != src)
			return
		if(insulate_copper(A))
			to_chat(user, SPAN_NOTICE("You use the tape to insulate a copper cable."))
		return
	return ..()

/obj/item/weapon/reagent_containers/food/drinks/bottle/plastic/stoppered
	name = "stoppered plastic bottle"
	desc = "A plastic bottle closed with a butyl rubber stopper."

/obj/item/weapon/reagent_containers/food/drinks/bottle/plastic/stoppered/New()
	..()
	flags &= ~OPENCONTAINER

/obj/structure/reaction_bench/New()
	..()
	reaction_paths = controlled_reaction_paths()

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
