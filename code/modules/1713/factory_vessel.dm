// Chemistry automation phase 2: the reaction vessel. It holds its contents
// inert, takes one chosen recipe's inputs from its pipe network in ratio for a
// full batch, reacts the batch with power, then lets everything but the
// recipe's catalysts out through the pipes. Holding tank filters sort the
// product from any leftovers. See docs/chemistry-automation-design.md.

#define FLUID_VESSEL_VOLUME 200
#define FLUID_VESSEL_REACT_STEPS 3
#define VESSEL_FILLING 0
#define VESSEL_REACTING 1
#define VESSEL_EMPTYING 2

var/global/list/fluid_vessels = list()

/obj/structure/fluid_vessel
	name = "reaction vessel"
	desc = "A powered steel vessel for a pipe network. Choose a laboratory recipe and it draws a full batch of that recipe's inputs, reacts them, then lets the result out to the network. Its contents are held inert otherwise."
	icon = 'icons/obj/chemical.dmi'
	icon_state = "distill_empty"
	anchored = TRUE
	density = TRUE
	flammable = FALSE
	not_movable = FALSE
	not_disassemblable = FALSE
	flags = NOREACT
	powerneeded = 4
	var/volume = FLUID_VESSEL_VOLUME
	var/react_time = FLUID_VESSEL_REACT_STEPS // powered steps per batch
	var/recipe_id = null
	var/stage = VESSEL_FILLING
	// Emptying everything, catalysts included, after a recipe change.
	var/flushing = FALSE
	var/tmp/react_steps = 0

// Faster tiers (phase 3): bigger batches that react in one powered step.
/obj/structure/fluid_vessel/fast
	name = "fast reaction vessel"
	powerneeded = 8
	volume = 400
	react_time = 1

/obj/structure/fluid_vessel/industrial
	name = "industrial reaction vessel"
	powerneeded = 15
	volume = 1000
	react_time = 1

/obj/structure/fluid_vessel/New()
	..()
	create_reagents(volume)
	fluid_vessels |= src
	fluid_mark_dirty()

/obj/structure/fluid_vessel/Destroy()
	fluid_vessels -= src
	vessel_release_power()
	fluid_mark_dirty()
	return ..()

/obj/structure/fluid_vessel/persistence_runtime_var(key)
	if (key == "powered" || key == "react_steps")
		return TRUE
	return ..()

// A batch in progress restarts its reaction time after load.
/obj/structure/fluid_vessel/after_load()
	. = ..()
	powered = FALSE
	react_steps = 0
	fluid_vessels |= src
	fluid_mark_dirty()
	update_icon()

/obj/structure/fluid_vessel/update_icon()
	icon_state = stage == VESSEL_REACTING ? "distill_active" : (reagents && reagents.total_volume ? "distill" : "distill_empty")

/obj/structure/fluid_vessel/proc/recipe()
	return recipe_id ? controlled_reaction(recipe_id) : null

// Whole batches of the recipe that fit, with room for its catalysts.
/obj/structure/fluid_vessel/proc/batch_count()
	var/datum/chemical_reaction/R = recipe()
	if (!R || !R.result || !R.required_reagents.len)
		return 0
	var/inputs = 0
	for (var/id in R.required_reagents)
		inputs += R.required_reagents[id]
	var/catalysts = 0
	for (var/id in R.catalysts)
		catalysts += R.catalysts[id]
	var/per_batch = max(inputs, R.result_amount)
	if (per_batch <= 0)
		return 0
	return max(0, round((volume - catalysts) / per_batch))

// Units of id the batch still needs.
/obj/structure/fluid_vessel/proc/batch_want(id)
	var/datum/chemical_reaction/R = recipe()
	if (!R)
		return 0
	var/want = 0
	if (id in R.required_reagents)
		want += R.required_reagents[id] * batch_count()
	if (id in R.catalysts)
		want += R.catalysts[id]
	return max(0, want - reagents.get_reagent_amount(id))

/obj/structure/fluid_vessel/proc/batch_ready()
	var/datum/chemical_reaction/R = recipe()
	if (!R || batch_count() < 1)
		return FALSE
	for (var/id in R.required_reagents + R.catalysts)
		if (batch_want(id) > 0.01)
			return FALSE
	return TRUE

// What is left once the batch's product and leftovers are out.
/obj/structure/fluid_vessel/proc/kept(id)
	if (flushing)
		return FALSE
	var/datum/chemical_reaction/R = recipe()
	return R && (id in R.catalysts)

/obj/structure/fluid_vessel/proc/emptied()
	for (var/datum/reagent/reagent in reagents.reagent_list)
		if (reagent.volume > 0.01 && !kept(reagent.id))
			return FALSE
	return TRUE

/obj/structure/fluid_vessel/proc/vessel_release_power()
	if (powersource)
		powersource.update_power(-powerneeded, 1, src)
	powered = FALSE

// A finished batch keeps its power reservation until the next step, so one
// grid's capacity runs only one batch per step.
/obj/structure/fluid_vessel/proc/set_stage(new_stage, keep_power = FALSE)
	stage = new_stage
	react_steps = 0
	if (stage != VESSEL_REACTING && !keep_power)
		vessel_release_power()
	var/datum/fluid_network/N = fluid_network_of(src)
	if (N)
		N.idle_steps = 0
	update_icon()

// Run the batch. A recipe that cannot proceed consumes nothing and waits.
/obj/structure/fluid_vessel/proc/react_batch()
	var/datum/chemical_reaction/R = recipe()
	if (!R || !chemical_reagents_list[R.result] || !R.can_happen(reagents))
		return FALSE
	return R.process(reagents) > 0

/obj/structure/fluid_vessel/proc/vessel_step()
	if (!anchored || !isturf(loc))
		vessel_release_power()
		return
	switch (stage)
		if (VESSEL_FILLING)
			if (batch_ready())
				set_stage(VESSEL_REACTING)
		if (VESSEL_REACTING)
			if (!batch_ready())
				set_stage(VESSEL_FILLING)
				return
			powered = draw_cable_power() ? TRUE : FALSE
			if (!powered)
				return
			if (++react_steps < react_time)
				return
			if (react_batch())
				set_stage(VESSEL_EMPTYING, TRUE)
			else
				// Inputs stay put; examining the vessel says why it waits.
				react_steps = 0
		if (VESSEL_EMPTYING)
			if (powered)
				vessel_release_power()
			if (emptied())
				flushing = FALSE
				set_stage(VESSEL_FILLING)

/obj/structure/fluid_vessel/fluid_supply_tier()
	return anchored && stage == VESSEL_EMPTYING ? FLUID_TIER_SOURCE : 0

/obj/structure/fluid_vessel/fluid_demand_tier()
	return anchored && stage == VESSEL_FILLING && recipe_id ? FLUID_TIER_SINK : 0

/obj/structure/fluid_vessel/fluid_supply_holder()
	return stage == VESSEL_EMPTYING ? reagents : null

/obj/structure/fluid_vessel/fluid_supplies(id)
	return stage == VESSEL_EMPTYING && !kept(id)

/obj/structure/fluid_vessel/fluid_demand(id)
	if (stage != VESSEL_FILLING)
		return 0
	return batch_want(id)

/obj/structure/fluid_vessel/fluid_receive(id, amount, data)
	amount = min(amount, fluid_demand(id))
	if (amount <= 0)
		return 0
	. = fluid_add_to(reagents, id, amount, data)
	update_icon()

/obj/structure/fluid_vessel/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/stack/cable_coil))
		connect_cable(user, W)
		return
	return ..()

/obj/structure/fluid_vessel/attack_hand(mob/user)
	var/list/options = list("No recipe (empty the vessel)" = "none")
	controlled_reaction(null)
	for (var/id in controlled_reactions_by_id)
		var/datum/chemical_reaction/R = controlled_reactions_by_id[id]
		if (R.result)
			options[R.name] = R.id
	var/choice = input(user, "Choose the game reaction this vessel runs. It takes a full batch of inputs from its pipes.", name) as null|anything in options
	if (!choice || !user || user.incapacitated() || get_dist(user, src) > 1)
		return
	set_recipe(options[choice] == "none" ? null : options[choice])
	var/datum/chemical_reaction/R = recipe()
	if (R)
		to_chat(user, SPAN_NOTICE("\The [src] now runs [R.name] in batches of [batch_count()]."))
	else
		to_chat(user, SPAN_NOTICE("\The [src] now runs nothing."))

// A new recipe flushes whatever the old one left behind, catalysts included.
/obj/structure/fluid_vessel/proc/set_recipe(id)
	if (id == recipe_id)
		return
	recipe_id = id
	flushing = reagents.total_volume > 0
	set_stage(flushing ? VESSEL_EMPTYING : VESSEL_FILLING)
	fluid_mark_dirty()

/obj/structure/fluid_vessel/examine(mob/user, distance)
	..(user, distance)
	var/datum/chemical_reaction/R = recipe()
	to_chat(user, SPAN_NOTICE("It holds [round(reagents.total_volume)] of [volume] units[reagents.total_volume ? ", mostly [reagents.get_master_reagent_name()]" : ""]."))
	if (!R)
		to_chat(user, SPAN_NOTICE("No recipe is set."))
		return
	var/state = "filling"
	if (stage == VESSEL_REACTING)
		state = powered ? "reacting" : "waiting for power"
	else if (stage == VESSEL_EMPTYING)
		state = "emptying"
	to_chat(user, SPAN_NOTICE("It runs [R.name] in batches of [batch_count()], and is [state]."))
	if (stage == VESSEL_REACTING && powered && !R.can_happen(reagents))
		to_chat(user, SPAN_WARNING("The batch cannot react here and waits."))

#undef VESSEL_FILLING
#undef VESSEL_REACTING
#undef VESSEL_EMPTYING
