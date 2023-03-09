
//Chemical Reactions - Initialises all /datum/chemical_reaction into a list
// It is filtered into multiple lists within a list.
// For example:
// chemical_reaction_list["tungsten"] is a list of all reactions relating to tungsten
// Note that entries in the list are NOT duplicated. So if a reaction pertains to
// more than one chemical it will still only appear in only one of the sublists.
/proc/initialize_chemical_reactions()
	var/paths = typesof(/datum/chemical_reaction) - /datum/chemical_reaction
	chemical_reactions_list = list()

	for (var/path in paths)
		var/datum/chemical_reaction/D = new path()
		if (D.required_reagents && D.required_reagents.len)
			var/reagent_id = D.required_reagents[1]
			if (!chemical_reactions_list[reagent_id])
				chemical_reactions_list[reagent_id] = list()
			chemical_reactions_list[reagent_id] += D

//prints all the recipes into a txt file
datum/admins/proc/print_chemical_reactions()
	set category = "Debug"
	set desc = "Print all the ingame chemical reactions into a txt file."
	set name = "Print Chemical Reactions"
	var/paths = typesof(/datum/chemical_reaction) - /datum/chemical_reaction
	var/recipe_list = file("recipes.txt")
	if (fexists(recipe_list))
		fdel(recipe_list)
	var/choice = WWinput(usr, "Which format to export?", "Chemical Recipe Export", "Plaintext", list("Plaintext", "Wiki"))
	if (choice == "Wiki")
		recipe_list <<"{| class=\"wikitable sortable\" style=\"text-align: left"
		recipe_list <<"! Result"
		recipe_list <<"! Ingredients"
		recipe_list <<"! Catalysts"
		recipe_list <<"! Inhibitors"
		recipe_list <<"! Produced Amount"
		recipe_list <<"! ID"
		recipe_list << " "
		for (var/path in paths)
			var/datum/chemical_reaction/D = new path()
			var/in_reagents = ""
			var/cat_reagents = ""
			var/req_reagents = ""
			for (var/i in D.required_reagents)
				var/amt = D.required_reagents[i]
				req_reagents += " [amt]u. [i]"
			for (var/j in D.catalysts)
				var/amt = D.catalysts[j]
				cat_reagents += " [amt]u. [j]"
			for (var/k in D.inhibitors)
				var/amt = D.inhibitors[k]
				in_reagents += " [amt]u. [k]"
			var/chemical_reactions_print_var = "|- id=\"[D.id]\"\n! [D.name]"
			if (req_reagents && req_reagents != "")
				chemical_reactions_print_var = "[chemical_reactions_print_var]\n| [req_reagents]"
			else
				chemical_reactions_print_var = "[chemical_reactions_print_var]\n| none"

			if (cat_reagents && cat_reagents != "")
				chemical_reactions_print_var = "[chemical_reactions_print_var]\n| [cat_reagents]"
			else
				chemical_reactions_print_var = "[chemical_reactions_print_var]\n| none"

			if (in_reagents && in_reagents != "")
				chemical_reactions_print_var = "[chemical_reactions_print_var]\n| [in_reagents]"
			else
				chemical_reactions_print_var = "[chemical_reactions_print_var]\n| none"

			chemical_reactions_print_var = "[chemical_reactions_print_var]\n| [D.result_amount]"
			chemical_reactions_print_var = "[chemical_reactions_print_var]\n| [D.id]"
			recipe_list << chemical_reactions_print_var
	else
		for (var/path in paths)
			var/datum/chemical_reaction/D = new path()
			var/in_reagents = ""
			var/cat_reagents = ""
			var/req_reagents = ""
			for (var/i in D.required_reagents)
				var/amt = D.required_reagents[i]
				req_reagents += " [amt]u. [i]"
			for (var/j in D.catalysts)
				var/amt = D.catalysts[j]
				cat_reagents += " [amt]u. [j]"
			for (var/k in D.inhibitors)
				var/amt = D.inhibitors[k]
				in_reagents += " [amt]u. [k]"
			var/chemical_reactions_print_var = "[D.name]:"
			if (req_reagents && req_reagents != "")
				chemical_reactions_print_var = "[chemical_reactions_print_var] Ingredients:[req_reagents],"
			if (in_reagents && in_reagents != "")
				chemical_reactions_print_var = "[chemical_reactions_print_var] Inhibitors:[in_reagents],"
			if (cat_reagents && cat_reagents != "")
				chemical_reactions_print_var = "[chemical_reactions_print_var] Catalysts:[cat_reagents],"
			chemical_reactions_print_var = "[chemical_reactions_print_var] Produces: [D.result_amount]. (ID: [D.id])"
			recipe_list << chemical_reactions_print_var
	world.log << "Finished saving all recipes into \"recipes.txt\"."
	return
//helper that ensures the reaction rate holds after iterating
//Ex. REACTION_RATE(0.3) means that 30% of the reagents will react each chemistry tick (~2 seconds by default).
#define REACTION_RATE(rate) (1.0 - (1.0-rate)**(1.0/PROCESS_REACTION_ITER))

//helper to define reaction rate in terms of half-life
//Ex.
//HALF_LIFE(0) -> Reaction completes immediately (default chems)
//HALF_LIFE(1) -> Half of the reagents react immediately, the rest over the following ticks.
//HALF_LIFE(2) -> Half of the reagents are consumed after 2 chemistry ticks.
//HALF_LIFE(3) -> Half of the reagents are consumed after 3 chemistry ticks.
#define HALF_LIFE(ticks) (ticks? 1.0 - (0.5)**(1.0/(ticks*PROCESS_REACTION_ITER)) : 1.0)

/datum/chemical_reaction
	var/name = null
	var/id = null
	var/result = null
	var/list/required_reagents = list()
	var/list/catalysts = list()
	var/list/inhibitors = list()
	var/result_amount = 0

	//how far the reaction proceeds each time it is processed. Used with either REACTION_RATE or HALF_LIFE macros.
	var/reaction_rate = HALF_LIFE(0)

	//if less than TRUE, the reaction will be inhibited if the ratio of products/reagents is too high.
	//0.5 = 50% yield -> reaction will only proceed halfway until products are removed.
	var/yield = 1.0

	//If limits on reaction rate would leave less than this amount of any reagent (adjusted by the reaction ratios),
	//the reaction goes to completion. This is to prevent reactions from going on forever with tiny reagent amounts.
	var/min_reaction = 2

	var/mix_message = "The solution begins to bubble."
	var/reaction_sound = 'sound/effects/bubbles.ogg'

	var/log_is_important = FALSE // If this reaction should be considered important for logging. Important recipes message admins when mixed, non-important ones just log to file.
/datum/chemical_reaction/proc/can_happen(var/datum/reagents/holder)
	//check that all the required reagents are present
	if (!holder.has_all_reagents(required_reagents))
		return FALSE

	//check that all the required catalysts are present in the required amount
	if (!holder.has_all_reagents(catalysts))
		return FALSE

	//check that none of the inhibitors are present in the required amount
	if (holder.has_any_reagent(inhibitors))
		return FALSE

	return TRUE

/datum/chemical_reaction/proc/calc_reaction_progress(var/datum/reagents/holder, var/reaction_limit)
	var/progress = reaction_limit * reaction_rate //simple exponential progression

	//calculate yield
	if (1-yield > 0.001) //if yield ratio is big enough just assume it goes to completion
		/*
			Determine the max amount of product by applying the yield condition:
			(max_product/result_amount) / reaction_limit == yield/(1-yield)

			We make use of the fact that:
			reaction_limit = (holder.get_reagent_amount(reactant) / required_reagents[reactant]) of the limiting reagent.
		*/
		var/yield_ratio = yield/(1-yield)
		var/max_product = yield_ratio * reaction_limit * result_amount //rearrange to obtain max_product
		var/yield_limit = max(0, max_product - holder.get_reagent_amount(result))/result_amount

		progress = min(progress, yield_limit) //apply yield limit

	//apply min reaction progress - wasn't sure if this should go before or after applying yield
	//I guess people can just have their miniscule reactions go to completion regardless of yield.
	for (var/reactant in required_reagents)
		var/remainder = holder.get_reagent_amount(reactant) - progress*required_reagents[reactant]
		if (remainder <= min_reaction*required_reagents[reactant])
			progress = reaction_limit
			break

	return progress

/datum/chemical_reaction/proc/process(var/datum/reagents/holder)
	//determine how far the reaction can proceed
	var/list/reaction_limits = list()
	for (var/reactant in required_reagents)
		reaction_limits += holder.get_reagent_amount(reactant) / required_reagents[reactant]

	//determine how far the reaction proceeds
	var/reaction_limit = min(reaction_limits)
	var/progress_limit = calc_reaction_progress(holder, reaction_limit)

	var/reaction_progress = min(reaction_limit, progress_limit) //no matter what, the reaction progress cannot exceed the stoichiometric limit.

	//need to obtain the new reagent's data before anything is altered
	var/data = send_data(holder, reaction_progress)

	//remove the reactants
	for (var/reactant in required_reagents)
		var/amt_used = required_reagents[reactant] * reaction_progress
		holder.remove_reagent(reactant, amt_used, safety = TRUE)

	//add the product
	var/amt_produced = result_amount * reaction_progress
	if (result)
		holder.add_reagent(result, amt_produced, data, safety = TRUE)

	on_reaction(holder, amt_produced)

	return reaction_progress

//called when a reaction processes
/datum/chemical_reaction/proc/on_reaction(var/datum/reagents/holder, var/created_volume)
	return

//called after processing reactions, if they occurred
/datum/chemical_reaction/proc/post_reaction(var/datum/reagents/holder)
	var/atom/container = holder.my_atom
	if (mix_message && container && !ismob(container))
		var/turf/T = get_turf(container)
		var/list/seen = viewers(4, T)
		for (var/mob/M in seen)
			M.show_message("<span class='notice'>\icon[container] [mix_message]</span>", TRUE)
		playsound(T, reaction_sound, 80, TRUE)

//obtains any special data that will be provided to the reaction products
//this is called just before reactants are removed.
/datum/chemical_reaction/proc/send_data(var/datum/reagents/holder, var/reaction_limit)
	return null

/* Common reactions */

/datum/chemical_reaction/
	name = ""
	id = ""
	result = ""
	required_reagents = list("acetone" = 1, "carbon" = 1, "sugar" = 1)
	result_amount = 3

/datum/chemical_reaction/penicillin
	name = "Penicillin"
	id = "penicillin"
	result = "penicillin"
	required_reagents = list("enzyme" = 10, "acetone" = 1)
	result_amount = 5

/datum/chemical_reaction/tramadol
	name = "Tramadol"
	id = "tramadol"
	result = "tramadol"
	required_reagents = list("opium" = 1, "ethanol" = 1, "acetone" = 1)
	result_amount = 3

/datum/chemical_reaction/paracetamol
	name = "Paracetamol"
	id = "paracetamol"
	result = "paracetamol"
	required_reagents = list("tramadol" = 1, "sugar" = 1, "water" = 1)
	result_amount = 3

/datum/chemical_reaction/oxycodone
	name = "Oxycodone"
	id = "oxycodone"
	result = "oxycodone"
	required_reagents = list("ethanol" = 1, "tramadol" = 1)
	catalysts = list("tungsten" = 5)
	result_amount = 1

/datum/chemical_reaction/adrenaline
	name = "Adrenaline"
	id = "adrenaline"
	result = "adrenaline"
	required_reagents = list("acetone" = 1, "sugar" = 1, "diethylamine" = 1, "potassium_chloride" = 1)
	result_amount = 5

/datum/chemical_reaction/methamphetamine
	name = "Methamphetamine"
	id = "methamphetamine"
	result = "methamphetamine"
	required_reagents = list("adrenaline" = 1, "carbon" = 1)
	result_amount = 1

/datum/chemical_reaction/soporific
	name = "Soporific"
	id = "stoxin"
	result = "stoxin"
	required_reagents = list("chloralhydrate" = 1, "sugar" = 4)
	inhibitors = list("phosphorus") // Messes with the smoke
	result_amount = 5

/datum/chemical_reaction/chloralhydrate
	name = "Chloral Hydrate"
	id = "chloralhydrate"
	result = "chloralhydrate"
	required_reagents = list("ethanol" = 1, "hclacid" = 3, "water" = 1)
	result_amount = 1

/datum/chemical_reaction/potassium_chloride
	name = "Potassium Chloride"
	id = "potassium_chloride"
	result = "potassium_chloride"
	required_reagents = list("sodiumchloride" = 1, "potassium" = 1)
	result_amount = 2

/datum/chemical_reaction/potassium_chlorophoride
	name = "Potassium Chlorophoride"
	id = "potassium_chlorophoride"
	result = "potassium_chlorophoride"
	required_reagents = list("potassium_chloride" = 1, "tungsten" = 1, "chloralhydrate" = 1)
	result_amount = 4

/datum/chemical_reaction/diethylamine
	name = "Diethylamine"
	id = "diethylamine"
	result = "diethylamine"
	required_reagents = list ("ammonia" = 1, "ethanol" = 1)
	result_amount = 2

/datum/chemical_reaction/foaming_agent
	name = "Foaming Agent"
	id = "foaming_agent"
	result = "foaming_agent"
	required_reagents = list("lithium" = 1, "hydrazine" = 1)
	result_amount = 1

/datum/chemical_reaction/hclacid
	name = "Hydrochloric Acid"
	id = "hclacid"
	result = "hclacid"
	required_reagents = list("hydrogen_chloride" = 1, "water" = 5)
	result_amount = 5

/datum/chemical_reaction/potassium_iodide
	name = "Potassium Iodide"
	id = "potassium_iodide"
	result = "potassium_iodide"
	required_reagents = list("potassium" = 1, "iodine" = 1)
	result_amount = 1


/datum/chemical_reaction/ammonia
	name = "Ammonia"
	id = "ammonia"
	result = "ammonia"
	required_reagents = list("nitrogen" = 1, "hydrogen" = 3)
	result_amount = 1

/datum/chemical_reaction/acetone
	name = "Acetone"
	id = "acetone"
	result = "acetone"
	required_reagents = list("carbon" = 1, "ethanol" = 2)
	result_amount = 1

/datum/chemical_reaction/salt
	name = "Table Salt"
	id = "sodiumchloride"
	result = "sodiumchloride"
	required_reagents = list("sodium" = 1, "chlorine" = 1)
	result_amount = 1

/datum/chemical_reaction/hydrogen_chloride
	name = "Hydrogen Chloride"
	id = "hydrogen_chloride"
	result = "hydrogen_chloride"
	required_reagents = list("hydrogen" = 1, "chlorine" = 1)
	result_amount = 1

/datum/chemical_reaction/hydrogen_peroxide
	name = "Hydrogen Peroxide"
	id = "hydrogen_peroxide"
	result = "hydrogen_peroxide"
	required_reagents = list("chlorine" = 1, "water" = 1, "oxygen" = 1)
	result_amount = 3

/datum/chemical_reaction/water
	name = "Water"
	id = "water"
	result = "water"
	required_reagents = list("oxygen" = 1, "hydrogen" = 1)
	result_amount = 1

/datum/chemical_reaction/cider
	name = "Cider"
	id = "cider"
	result = "cider"
	required_reagents = list("applejuice" = 10)
	catalysts = list("enzyme" = 5)
	result_amount = 10

/datum/chemical_reaction/glycerol
	name = "Glycerol"
	id = "glycerol"
	result = "glycerol"
	required_reagents = list("cornoil" = 3, "sacid" = 1)
	result_amount = 3

/datum/chemical_reaction/glycerol_hacid
	name = "Glycerol"
	id = "glycerol"
	result = "glycerol"
	required_reagents = list("cornoil" = 3, "hclacid" = 1)
	result_amount = 3

/datum/chemical_reaction/sodiumchloride
	name = "Sodium Chloride"
	id = "sodiumchloride"
	result = "sodiumchloride"
	required_reagents = list("sodium" = 1, "hclacid" = 1)
	result_amount = 2

/datum/chemical_reaction/aspirin
	name = "Aspirin"
	id = "aspirin"
	result = "aspirin"
	required_reagents = list("carbon" = 5, "water" = 4, "oxygen" = 2 )
	result_amount = 5

/datum/chemical_reaction/calcium_carbonate
	name = "Calcium carbonate"
	id = "calcium carbonate"
	result = "calcium carbonate"
	required_reagents = list("carbon" =1, "calcium" = 1, "oxygen" = 3 )
	result_amount = 2

/datum/chemical_reaction/carbon_dioxide
	name = "Carbon dioxide"
	id = "carbon_dioxide"
	result = "carbon_dioxide"
	required_reagents = list("carbon" =1,  "oxygen" = 2 )
	result_amount = 2


/datum/chemical_reaction/sulphuric_acid
	name = "Sulphuric acid"
	id = "sacid"
	result = "sacid"
	required_reagents = list("sulfur" =1, "oxygen" = 1, "hydrogen" = 1 )
	result_amount = 2

/datum/chemical_reaction/saline_glucose
	name = "Saline Glucose solution"
	id = "saline_glucose"
	result = "saline_glucose"
	required_reagents = list("sodiumchloride" = 1, "water" = 1, "sugar" = 1 )
	result_amount = 2

/datum/chemical_reaction/aqua_regia
	name = "Aqua regia"
	id = "aqua_regia"
	result = "aqua_regia"
	required_reagents = list("nitric_acid" = 1, "clorhydric_acid" = 3, )
	result_amount = 2

/datum/chemical_reaction/nitric_acid
	name = "Nitric acid"
	id = "nitric_acid"
	result = "nitric_acid"
	required_reagents = list("nitrogen" = 2, "oxygen" = 5, "water" = 3 )
	result_amount = 4

/datum/chemical_reaction/clorhydric_acid
	name = "Clorhydric acid"
	id = "clorhydric_acid"
	result = "clorhydric_acid"
	required_reagents = list("hydrogen" =1, "chlorine" = 1 )
	result_amount = 1

/datum/chemical_reaction/baking_soda
	name = "Baking soda"
	id = "baking_soda"
	result = "baking_soda"
	required_reagents = list("carbon_dioxide" =1, "ammonia" = 1, "sodium_chloride" = 2 )
	result_amount = 2

/datum/chemical_reaction/bleach
	name = "Bleach"
	id = "bleach"
	result = "bleach"
	required_reagents = list("sodium_hypochlorite" =1, "water" = 9)
	result_amount = 10

/datum/chemical_reaction/sodium_hypochlorite
	name = "Sodium hypochlorite"
	id = "sodium_hypochlorite"
	result = "sodium_hypochlorite"
	required_reagents = list("potassium" =1, "oxygen" = 1, "chlorine" = 1 )
	result_amount = 2

/datum/chemical_reaction/hydrazine
	name = "Hydrazine"
	id = "hydrazine"
	result = "hydrazine"
	required_reagents = list("ammonia" =1, "hydrogen" = 1, "nitrogen" = 1 )
	result_amount = 1

/datum/chemical_reaction/condensedcapsaicin
	name = "Condensed Capsaicin"
	id = "condensedcapsaicin"
	result = "condensedcapsaicin"
	required_reagents = list("capsaicin" = 2)
	catalysts = list("tungsten" = 5)
	result_amount = 1

/datum/chemical_reaction/methylphenidate
	name = "Methylphenidate"
	id = "methylphenidate"
	result = "methylphenidate"
	required_reagents = list("mindbreaker" = 1, "hydrazine" = 1)
	result_amount = 3

/datum/chemical_reaction/citalopram
	name = "Citalopram"
	id = "citalopram"
	result = "citalopram"
	required_reagents = list("mindbreaker" = 1, "carbon" = 1)
	result_amount = 3


/datum/chemical_reaction/paroxetine
	name = "Paroxetine"
	id = "paroxetine"
	result = "paroxetine"
	required_reagents = list("mindbreaker" = 1, "acetone" = 1)
	result_amount = 3

/datum/chemical_reaction/mindbreaker
	name = "Lysergic acid diethylamide"
	id = "mindbreaker"
	result = "mindbreaker"
	required_reagents = list("enzyme" = 1, "diethylamine" = 1)
	result_amount = 2
/* Grenade reactions */

/datum/chemical_reaction/explosion_potassium
	name = "Explosion"
	id = "explosion_potassium"
	result = null
	required_reagents = list("water" = 1, "potassium" = 1)
	result_amount = 2
	mix_message = null

/datum/chemical_reaction/explosion_potassium/on_reaction(var/datum/reagents/holder, var/created_volume)
	var/exloc = get_turf(holder.my_atom)
	var/datum/effect/effect/system/reagents_explosion/e = new()
	e.set_up(round (created_volume/10, TRUE), exloc, FALSE, FALSE)
	for (var/mob/living/L in exloc)
		e.amount *= 0.5
		if (L.stat != DEAD)
			if (e.amount >= 6)
				L.crush()
			e.amount *= 1.5
	e.start()
	holder.clear_reagents()

/datum/chemical_reaction/nitroglycerin
	name = "Nitroglycerin"
	id = "nitroglycerin"
	result = "nitroglycerin"
	required_reagents = list("glycerol" = 1, "potassium" = 1)
	result_amount = 2
	log_is_important = TRUE

/datum/chemical_reaction/nitroglycerin/on_reaction(var/datum/reagents/holder, var/created_volume)
	var/exloc = get_turf(holder.my_atom)
	if (created_volume >= 20)
		for (var/mob/living/human/H in range(exloc,3))
			H << "<big><span class = 'red'>The reagent begins to combust violenty, uh oh...</span></big>"
		spawn(30)
		explosion(exloc, 0, 1, 2, 6)

/datum/chemical_reaction/nitrocellulose
	name = "Nitrocellulose"
	id = "nitrocellulose"
	result = "nitrocellulose"
	required_reagents = list("cotton" = 1, "potassium" = 1)
	result_amount = 2
	log_is_important = TRUE

/datum/chemical_reaction/nitrocellulose/on_reaction(var/datum/reagents/holder, var/created_volume)
	var/exloc = get_turf(holder.my_atom)
	var/datum/effect/effect/system/reagents_explosion/e = new()
	e.set_up(round (created_volume/2, TRUE), exloc, FALSE, FALSE)
	for (var/mob/living/L in exloc)
		e.amount *= 0.5
		if (L.stat != DEAD)
			if (e.amount >= 6)
				L.crush()
			e.amount *= 1.5
	e.start()
	holder.clear_reagents()

/datum/chemical_reaction/gunpowder
	name = "Gunpowder"
	id = "gunpowder"
	result = "gunpowder"
	required_reagents = list("sulfur" = 1, "carbon" = 1, "potassium" = 1)
	result_amount = 3
	log_is_important = TRUE

/datum/chemical_reaction/gunpowder/on_reaction(var/datum/reagents/holder, var/created_volume)
	var/exloc = get_turf(holder.my_atom)
	var/datum/effect/effect/system/reagents_explosion/e = new()
	e.set_up(round (created_volume/4, TRUE), exloc, FALSE, FALSE)
	var/obj/item/flashlight/torch/T
	var/obj/item/weapon/flame/F
	for(T in range(2,src))
		if (T.on == TRUE)
			e.start()
			holder.clear_reagents()
		break
	for(F in range(2,src))
		if (F.lit == TRUE)
			e.start()
			holder.clear_reagents()
		break
	var/mob/living/human/H
	for(H in range(2,src))
		var/obj/item/clothing/mask/smokable/C
		if ((istype(H.wear_mask,/obj/item/clothing/mask/smokable)) && C.lit == TRUE)
			e.start()
			holder.clear_reagents()
		break

/datum/chemical_reaction/gunpowder_charcoal
	name = "Gunpowder"
	id = "gunpowder"
	result = "gunpowder"
	required_reagents = list("sulfur" = 1, "charcoal" = 1, "potassium" = 1)
	result_amount = 3
	log_is_important = TRUE

/datum/chemical_reaction/saltpeter_urine
	name = "Saltpeter"
	id = "potassium"
	result = "potassium"
	required_reagents = list("poo" = 2, "urine" = 1)
	result_amount = 1
	log_is_important = TRUE

/datum/chemical_reaction/saltpeter_fertilizer
	name = "Saltpeter"
	id = "potassium"
	result = "potassium"
	required_reagents = list("fertilizer" = 2, "urine" = 1)
	result_amount = 1
	log_is_important = TRUE

/datum/chemical_reaction/napalm
	name = "Napalm"
	id = "napalm"
	result = "napalm"
	required_reagents = list("gasoline" = 1, "cotton" = 1)
	result_amount = 1

/datum/chemical_reaction/chemsmoke
	name = "Chemsmoke"
	id = "chemsmoke"
	result = null
	required_reagents = list("potassium" = 1, "sugar" = 1, "phosphorus" = 1)
	result_amount = 0.4

/datum/chemical_reaction/hexachloroetane
	name = "Hexachloroetane"
	id = "hexachloroetane"
	result = "hexachloroetane"
	required_reagents = list("chlorine" = 6, "carbon" = 2)
	result_amount = 10

/datum/chemical_reaction/chlorine_gas
	name = "Chlorine Gas"
	id = "chlorine_gas"
	result = "chlorine_gas"
	required_reagents = list("chlorine" = 5, "hydrogen" = 5)
	result_amount = 5

/datum/chemical_reaction/mustard_gas
	name = "Mustard Gas"
	id = "mustard_gas"
	result = "mustard_gas"
	required_reagents = list("carbon" = 4, "hydrogen" = 8, "chlorine" = 2, "sulfur" = 1)
	result_amount = 10

/datum/chemical_reaction/white_phosphorus_gas
	name = "White Phosphorus Gas"
	id = "white_phosphorus_gas"
	result = "white_phosphorus_gas"
	required_reagents = list("phosphorus" = 5, "hydrogen" = 5)
	result_amount = 5

/datum/chemical_reaction/phosgene_gas
	name = "Phosgene Gas"
	id = "phosgene_gas"
	result = "phosgene_gas"
	required_reagents = list("chlorine" = 5, "carbon" = 2.5, "oxygen" = 2.5)
	catalysts = list("carbon" = 5)
	result_amount = 5

/datum/chemical_reaction/xylyl_bromide
	name = "Xylyl Bromide"
	id = "xylyl_bromide"
	result = "xylyl_bromide"
	required_reagents = list("carbon" = 6, "hydrogen" = 4, "bromine" = 1)
	result_amount = 5

/datum/chemical_reaction/zyklon_b
	name = "Zyklon B"
	id = "zyklon_b"
	result = "zyklon_b"
	required_reagents = list("cyanide" = 10, "hydrogen" = 5)
	result_amount = 5

/datum/chemical_reaction/cyanide
	name = "Cyanide"
	id = "cyanide"
	result = "cyanide"
	required_reagents = list("carbon" = 1, "nitrogen" = 1)
	result_amount = 1

/datum/chemical_reaction/crack
	name = "Crack cocaine"
	id = "crack"
	result = "crack"
	required_reagents = list("cocaine" = 1, "baking_soda" = 1)
	result_amount = 2

/datum/chemical_reaction/chemsmoke/on_reaction(var/datum/reagents/holder, var/created_volume)
	var/location = get_turf(holder.my_atom)
	var/datum/effect/effect/system/smoke_spread/chem/S = new /datum/effect/effect/system/smoke_spread/chem
	S.attach(location)
	S.set_up(holder, created_volume, FALSE, location)
	playsound(location, 'sound/effects/smoke.ogg', 50, TRUE, -3)
	spawn(0)
		S.start()
	holder.clear_reagents()
	return

/datum/chemical_reaction/kevlar/gasoline
	name = "Gasoline Kevlar"
	id = "gas_kevlar"
	result = "gas_kevlar"
	required_reagents = list("sacid" = 5, "gasoline" = 5)
	result_amount = 1

/datum/chemical_reaction/kevlar/gasoline/on_reaction(var/datum/reagents/holder, var/created_volume)
	var/location = get_turf(holder.my_atom)
	for (var/i = TRUE, i <= created_volume, i++)
		new/obj/item/stack/material/rawkevlar(location)
	return

/datum/chemical_reaction/kevlar/diesel
	name = "Diesel Kevlar"
	id = "diesel_kevlar"
	result = "diesel_kevlar"
	required_reagents = list("sacid" = 5, "diesel" = 5)
	result_amount = 1

/datum/chemical_reaction/kevlar/diesel/on_reaction(var/datum/reagents/holder, var/created_volume)
	var/location = get_turf(holder.my_atom)
	for (var/i = TRUE, i <= created_volume, i++)
		new/obj/item/stack/material/rawkevlar(location)
	return

/datum/chemical_reaction/kevlar/biodiesel
	name = "Biodiesel Kevlar"
	id = "biodiesel_kevlar"
	result = "biodiesel_kevlar"
	required_reagents = list("sacid" = 5, "biodiesel" = 5)
	result_amount = 1

/datum/chemical_reaction/kevlar/biodiesel/on_reaction(var/datum/reagents/holder, var/created_volume)
	var/location = get_turf(holder.my_atom)
	for (var/i = TRUE, i <= created_volume, i++)
		new/obj/item/stack/material/rawkevlar(location)
	return

/* Food */

/datum/chemical_reaction/hot_coco
	name = "Hot Coco"
	id = "hot_coco"
	result = "hot_coco"
	required_reagents = list("water" = 5, "cocoa" = 1)
	result_amount = 5

/datum/chemical_reaction/cheesewheel
	name = "Cheesewheel"
	id = "cheesewheel"
	result = null
	required_reagents = list("milk" = 40)
	catalysts = list("enzyme" = 5)
	result_amount = 1

/datum/chemical_reaction/cheesewheel/on_reaction(var/datum/reagents/holder, var/created_volume)
	var/location = get_turf(holder.my_atom)
	for (var/i = TRUE, i <= created_volume, i++)
		new /obj/item/weapon/reagent_containers/food/snacks/sliceable/cheesewheel(location)
	return

/datum/chemical_reaction/meatball
	name = "Meatball"
	id = "meatball"
	result = null
	required_reagents = list("protein" = 5, "flour" = 5)
	result_amount = 3

/datum/chemical_reaction/meatball/on_reaction(var/datum/reagents/holder, var/created_volume)
	var/location = get_turf(holder.my_atom)
	for (var/i = TRUE, i <= created_volume, i++)
		new /obj/item/weapon/reagent_containers/food/snacks/meatball(location)
	return

/datum/chemical_reaction/dough
	name = "Dough"
	id = "dough"
	result = null
	required_reagents = list("water" = 5, "flour" = 10)
	result_amount = 1

/datum/chemical_reaction/sweetdough
	name = "Sweet Dough"
	id = "sweet_dough"
	result = null
	required_reagents = list("egg" = 3, "flour" = 10, "sugar" = 2)
	result_amount = 1

/* Alcohol */

/datum/chemical_reaction/goldschlager
	name = "Goldschlager"
	id = "goldschlager"
	result = "goldschlager"
	required_reagents = list("vodka" = 10, "gold" = 1)
	result_amount = 10

/datum/chemical_reaction/patron
	name = "Patron"
	id = "patron"
	result = "patron"
	required_reagents = list("tequilla" = 10, "silver" = 1)
	result_amount = 10

/datum/chemical_reaction/bilk
	name = "Bilk"
	id = "bilk"
	result = "bilk"
	required_reagents = list("milk" = 1, "beer" = 1)
	result_amount = 2

/datum/chemical_reaction/icetea
	name = "Iced Tea"
	id = "icetea"
	result = "icetea"
	required_reagents = list("ice" = 1, "tea" = 2)
	result_amount = 3

/datum/chemical_reaction/icecoffee
	name = "Iced Coffee"
	id = "icecoffee"
	result = "icecoffee"
	required_reagents = list("ice" = 1, "coffee" = 2)
	result_amount = 3

/datum/chemical_reaction/moonshine
	name = "Moonshine"
	id = "moonshine"
	result = "moonshine"
	required_reagents = list("nutriment" = 10)
	catalysts = list("enzyme" = 5)
	result_amount = 5

/datum/chemical_reaction/grenadine
	name = "Grenadine Syrup"
	id = "grenadine"
	result = "grenadine"
	required_reagents = list("berryjuice" = 10)
	catalysts = list("enzyme" = 5)
	result_amount = 10

/datum/chemical_reaction/wine
	name = "Wine"
	id = "wine"
	result = "wine"
	required_reagents = list("grapejuice" = 10)
	catalysts = list("enzyme" = 5)
	result_amount = 10

/datum/chemical_reaction/watermelonliquor
	name = "Watermelon Liquor"
	id = "watermelonliquor"
	result = "watermelonliquor"
	required_reagents = list("watermelonjuice" = 10)
	catalysts = list("enzyme" = 5)
	result_amount = 5

/datum/chemical_reaction/vodka
	name = "Vodka"
	id = "vodka"
	result = "vodka"
	required_reagents = list("potato" = 10)
	catalysts = list("enzyme" = 5)
	result_amount = 5

/datum/chemical_reaction/coca_wine
	name = "Coca Wine"
	id = "cocawine"
	result = "cocawine"
	required_reagents = list("wine"= 10, "cocaine" = 1)
	catalysts = list("enzyme" = 5)
	result_amount = 10

/datum/chemical_reaction/sake
	name = "Sake"
	id = "sake"
	result = "sake"
	required_reagents = list("rice" = 10)
	catalysts = list("enzyme" = 5)
	result_amount = 5

/datum/chemical_reaction/gin_tonic
	name = "Gin and Tonic"
	id = "gintonic"
	result = "gintonic"
	required_reagents = list("gin" = 2, "tonic" = 1)
	result_amount = 3

/datum/chemical_reaction/martini
	name = "Classic Martini"
	id = "martini"
	result = "martini"
	required_reagents = list("gin" = 2, "vermouth" = 1)
	result_amount = 3

/datum/chemical_reaction/vodkamartini
	name = "Vodka Martini"
	id = "vodkamartini"
	result = "vodkamartini"
	required_reagents = list("vodka" = 2, "vermouth" = 1)
	result_amount = 3

/datum/chemical_reaction/white_russian
	name = "White Russian"
	id = "whiterussian"
	result = "whiterussian"
	required_reagents = list("blackrussian" = 2, "cream" = 1)
	result_amount = 3

/datum/chemical_reaction/screwdriver
	name = "Screwdriver"
	id = "screwdrivercocktail"
	result = "screwdrivercocktail"
	required_reagents = list("vodka" = 2, "orangejuice" = 1)
	result_amount = 3

/datum/chemical_reaction/bloody_mary
	name = "Bloody Mary"
	id = "bloodymary"
	result = "bloodymary"
	required_reagents = list("vodka" = 2, "tomatojuice" = 3, "limejuice" = 1)
	result_amount = 6

/datum/chemical_reaction/tequilla_sunrise
	name = "Tequilla Sunrise"
	id = "tequillasunrise"
	result = "tequillasunrise"
	required_reagents = list("tequilla" = 2, "orangejuice" = 1)
	result_amount = 3

/datum/chemical_reaction/irish_cream
	name = "Irish Cream"
	id = "irishcream"
	result = "irishcream"
	required_reagents = list("whiskey" = 2, "cream" = 1)
	result_amount = 3

/datum/chemical_reaction/manly_dorf
	name = "The Manly Dorf"
	id = "manlydorf"
	result = "manlydorf"
	required_reagents = list ("beer" = 1, "ale" = 2)
	result_amount = 3

/datum/chemical_reaction/irish_coffee
	name = "Irish Coffee"
	id = "irishcoffee"
	result = "irishcoffee"
	required_reagents = list("irishcream" = 1, "coffee" = 1)
	result_amount = 2

/datum/chemical_reaction/margarita
	name = "Margarita"
	id = "margarita"
	result = "margarita"
	required_reagents = list("tequilla" = 2, "limejuice" = 1)
	result_amount = 3


/datum/chemical_reaction/red_mead
	name = "Red Mead"
	id = "red_mead"
	result = "red_mead"
	required_reagents = list("blood" = 1, "mead" = 1)
	result_amount = 2

/datum/chemical_reaction/garum
	name = "Garum"
	id = "garum"
	result = "garum"
	required_reagents = list("sodiumchloride" = 1, "fish" = 2)
	catalysts = list("enzyme" = 5)
	result_amount = 2

/datum/chemical_reaction/mead
	name = "Mead"
	id = "mead"
	result = "mead"
	required_reagents = list("sugar" = 1, "water" = 1)
	catalysts = list("enzyme" = 5)
	result_amount = 2

/datum/chemical_reaction/iced_beer2
	name = "Iced Beer"
	id = "iced_beer"
	result = "iced_beer"
	required_reagents = list("beer" = 5, "ice" = 1)
	result_amount = 6

/datum/chemical_reaction/cafe_latte
	name = "Cafe Latte"
	id = "cafe_latte"
	result = "cafe_latte"
	required_reagents = list("coffee" = 1, "milk" = 1)
	result_amount = 2

/datum/chemical_reaction/andalusia
	name = "Andalusia"
	id = "andalusia"
	result = "andalusia"
	required_reagents = list("rum" = 1, "whiskey" = 1, "lemonjuice" = 1)
	result_amount = 3

/datum/chemical_reaction/snowwhite
	name = "Snow White"
	id = "snowwhite"
	result = "snowwhite"
	required_reagents = list("beer" = 1, "lemon_lime" = 1)
	result_amount = 2

/datum/chemical_reaction/syndicatebomb
	name = "Syndicate Bomb"
	id = "syndicatebomb"
	result = "syndicatebomb"
	required_reagents = list("beer" = 1, "whiskeycola" = 1)
	result_amount = 2

/datum/chemical_reaction/driestmartini
	name = "Driest Martini"
	id = "driestmartini"
	result = "driestmartini"
	required_reagents = list("nothing" = 1, "gin" = 1)
	result_amount = 2

/datum/chemical_reaction/lemonade
	name = "Lemonade"
	id = "lemonade"
	result = "lemonade"
	required_reagents = list("lemonjuice" = 1, "sugar" = 1, "water" = 1)
	result_amount = 3

/datum/chemical_reaction/kiraspecial
	name = "Kira Special"
	id = "kiraspecial"
	result = "kiraspecial"
	required_reagents = list("orangejuice" = 1, "limejuice" = 1, "sodawater" = 1)
	result_amount = 3

/datum/chemical_reaction/milkshake
	name = "Milkshake"
	id = "milkshake"
	result = "milkshake"
	required_reagents = list("cream" = 1, "ice" = 2, "milk" = 2)
	result_amount = 5

/datum/chemical_reaction/luminol
	name = "Luminol"
	id = "luminol"
	result = "luminol"
	required_reagents = list("hydrogen" = 2, "carbon" = 2, "ammonia" = 2)
	result_amount = 6

/datum/chemical_reaction/sterilizine
	name = "sterilizine"
	result = /datum/reagent/sterilizine
	required_reagents = list(/datum/reagent/ethanol = 1, /datum/reagent/anti_toxin = 1, /datum/reagent/acid/hydrochloric = 1)
	result_amount = 3

//fermentation
/datum/chemical_reaction/rum
	name = "rum"
	id = "rum"
	result = "rum"
	required_reagents = list("sugar" = 3, "water" = 1)
	catalysts = list("enzyme" = 5)
	result_amount = 1

/datum/chemical_reaction/gin
	name = "gin"
	id = "gin"
	result = "gin"
	required_reagents = list("sugar" = 3, "juniper_juice" = 1)
	catalysts = list("enzyme" = 5)
	result_amount = 1

/datum/chemical_reaction/beer
	name = "beer"
	id = "beer"
	result = "beer"
	required_reagents = list("barleyflour" = 2, "water" = 2, "hops" = 1)
	catalysts = list("enzyme" = 5)
	result_amount = 2

/datum/chemical_reaction/mezcal
	name = "mezcal"
	id = "mezcal"
	result = "mezcal"
	required_reagents = list("agave" = 5, "water" = 2)
	catalysts = list("enzyme" = 5)
	result_amount = 2

/datum/chemical_reaction/wheatbeer
	name = "wheat beer"
	id = "wheatbeer"
	result = "wheatbeer"
	required_reagents = list("flour" = 2, "water" = 2)
	catalysts = list("enzyme" = 5)
	result_amount = 2


/datum/chemical_reaction/ale
	name = "ale"
	id = "ale"
	result = "ale"
	required_reagents = list("barleyflour" = 2, "water" = 2)
	catalysts = list("enzyme" = 5)
	result_amount = 2

/datum/chemical_reaction/mead
	name = "mead"
	id = "mead"
	result = "mead"
	required_reagents = list("honey" = 2, "water" = 2)
	result_amount = 2

//Soap making
/datum/chemical_reaction/lard_soap
	name = "Lard Soap"
	id = "lard_soap"
	result = null
	required_reagents = list("lard" = 20, "lye" = 2)
	result_amount = 1

/datum/chemical_reaction/lard_soap/on_reaction(var/datum/reagents/holder, var/created_volume)
	var/location = get_turf(holder.my_atom)
	for (var/i = TRUE, i <= created_volume, i++)
		new /obj/item/weapon/soap/lard(location)
	return