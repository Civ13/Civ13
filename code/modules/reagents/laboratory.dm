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
	var/list/reaction_paths = list(/datum/chemical_reaction/ethanoic_acid, /datum/chemical_reaction/calcium_carbonate, /datum/chemical_reaction/calcium_chloride, /datum/chemical_reaction/gluconic_acid, /datum/chemical_reaction/calcium_gluconate, /datum/chemical_reaction/sodium_sulfide, /datum/chemical_reaction/sodium_hydroxide, /datum/chemical_reaction/sulfurous_acid, /datum/chemical_reaction/hydrogen_sulfites, /datum/chemical_reaction/n_methylmorpholine_n_oxide, /datum/chemical_reaction/isobutylene, /datum/chemical_reaction/titaniumchloride, /datum/chemical_reaction/titaniumtrichloride, /datum/chemical_reaction/aluminumchloride, /datum/chemical_reaction/borontrifluoride, /datum/chemical_reaction/ethylene, /datum/chemical_reaction/propylene, /datum/chemical_reaction/polyethylene, /datum/chemical_reaction/octane, /datum/chemical_reaction/cyclopentane, /datum/chemical_reaction/toluene, /datum/chemical_reaction/butene, /datum/chemical_reaction/gasoline)

/obj/structure/reaction_bench/proc/install_beaker(obj/item/weapon/reagent_containers/glass/B, mob/user)
	if(collector || !B || !B.reagents)
		return FALSE
	if(user)
		user.drop_item()
	collector = B
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
	if(!choice || !user || get_dist(src, user) > 1)
		return
	if(synthesize(options[choice]))
		to_chat(user, SPAN_NOTICE("The selected game reaction completes."))
	else
		to_chat(user, SPAN_WARNING("That reaction cannot proceed. Check inputs, catalysts, and available capacity. Nothing was consumed."))

/obj/structure/reaction_bench/verb/eject_beaker()
	set name = "Remove reaction beaker"
	set src in range(1, usr)
	remove_beaker()

/obj/structure/reaction_bench/Destroy()
	remove_beaker()
	return ..()
