// ============================================================
// Self-sufficiency (space settlement phase 6)
// ------------------------------------------------------------
// Closed loops: a water recycler reclaims the water a module's occupants
// breathe and sweat out, feeding the module's electrolysers first, and an
// oxygen reclaimer scrubs CO2 like the scrubber but returns half of it as
// oxygen. Composting into hydroponics nutrient already works in a module's
// greenhouse trays.
//
// Local propellant: a propellant plant cracks water ice into rocket
// propellant, one piece at a time while powered, so a settlement can fuel a
// lander without mainland chemistry. With propellant on hand, a launch pad
// on a settled world can be pointed back at the mainland (lander.dm).
// Reuses existing sprites; no new art.
// ============================================================

// Water reclaimed per occupant per second of power.
#define SPACE_RECYCLE_WATER_PER_SECOND 0.02
#define SPACE_RECYCLER_CAPACITY 200
#define SPACE_RECLAIM_PER_SECOND 0.1
#define SPACE_RECLAIM_OXYGEN_FRACTION 0.5
#define SPACE_PLANT_PROPELLANT_PER_ICE 5
#define SPACE_PLANT_CAPACITY 300
#define SPACE_PLANT_ICE_MAX 100

// ---------------------------------------------------------------- recycling

/obj/structure/life_support/water_recycler
	name = "water recycler"
	desc = "Condenses and filters the water a module's crew breathe and sweat out. It feeds electrolysers in the module first; draw the rest with a container. Cable it."
	powerneeded = 5
	var/water = 0

/obj/structure/life_support/water_recycler/examine(mob/user)
	..()
	pipe_settle()
	to_chat(user, SPAN_NOTICE("Reclaimed water: [round(water, 0.1)]/[SPACE_RECYCLER_CAPACITY] units."))

/obj/structure/life_support/water_recycler/proc/module_core()
	var/turf/floor/habitat/F = get_turf(src)
	return istype(F) ? F.habitat_core() : null

/obj/structure/life_support/water_recycler/work(datum/habitat_ledger/L, seconds)
	pipe_settle()
	var/obj/structure/habitat_core/C = module_core()
	if (!C || !has_power())
		return FALSE
	var/occupants = C.breathers()
	if (occupants > 0)
		water = min(SPACE_RECYCLER_CAPACITY, water + occupants * SPACE_RECYCLE_WATER_PER_SECOND * seconds)
	return feed_electrolysers(C) > 0 || occupants > 0

// Tops up the module's electrolysers from the reclaimed water.
/obj/structure/life_support/water_recycler/proc/feed_electrolysers(obj/structure/habitat_core/C)
	if (!C)
		return 0
	. = 0
	for (var/turf/T in C.interior())
		for (var/obj/structure/life_support/electrolyser/E in T)
			var/give = min(water, E.water_max - E.water)
			if (give > 0)
				E.water += give
				water -= give
				. += give

/obj/structure/life_support/water_recycler/attackby(obj/item/W as obj, mob/user as mob)
	pipe_settle()
	if (istype(W, /obj/item/weapon/reagent_containers) && W.reagents && W.is_open_container())
		var/amount = min(water, W.reagents.maximum_volume - W.reagents.total_volume)
		if (amount <= 0)
			to_chat(user, SPAN_WARNING(water <= 0 ? "\The [src] has no water to give." : "\The [W] is full."))
			return
		W.reagents.add_reagent("water", amount)
		water -= amount
		to_chat(user, SPAN_NOTICE("You draw [round(amount, 0.1)] units of water from \the [src]."))
		return
	return ..()

/obj/structure/life_support/oxygen_reclaimer
	name = "oxygen reclaimer"
	desc = "Scrubs CO2 from the module's air and cracks half of it back into oxygen. Cable it."
	powerneeded = 15

/obj/structure/life_support/oxygen_reclaimer/work(datum/habitat_ledger/L, seconds)
	var/excess = L.co2 - HABITAT_CO2_TARGET_KPA * L.volume
	if (excess <= 0 || !has_power())
		return FALSE
	var/scrubbed = L.scrub_co2(min(excess, SPACE_RECLAIM_PER_SECOND * seconds))
	L.add_gas(scrubbed * SPACE_RECLAIM_OXYGEN_FRACTION)
	return TRUE

// ---------------------------------------------------------------- propellant

/obj/structure/reagent_dispensers/propellant_plant
	name = "propellant plant"
	desc = "Splits water ice into hydrogen and oxygen and chills them into rocket propellant. Load ice, cable it, and draw propellant with a container to fill a lander."
	icon = 'icons/obj/modern_structures.dmi'
	icon_state = "uranium_refinery"
	anchored = TRUE
	not_movable = FALSE
	max_capacity = SPACE_PLANT_CAPACITY
	powerneeded = 30
	var/ice = 0

/obj/structure/reagent_dispensers/propellant_plant/New()
	..()
	processing_objects |= src

/obj/structure/reagent_dispensers/propellant_plant/Destroy()
	processing_objects -= src
	return ..()

/obj/structure/reagent_dispensers/propellant_plant/examine(mob/user)
	..()
	to_chat(user, SPAN_NOTICE("Ice loaded: [ice]/[SPACE_PLANT_ICE_MAX]. Propellant: [round(reagents ? reagents.get_reagent_amount("rocket_propellant") : 0)]/[max_capacity] units. [powersource ? "It is cabled." : "Run a cable to it to power it."]"))

/obj/structure/reagent_dispensers/propellant_plant/proc/has_power()
	return draw_cable_power()

// Takes ice from a stack; returns how many pieces it took.
/obj/structure/reagent_dispensers/propellant_plant/proc/load_ice(obj/item/stack/ore/ice/I)
	if (!istype(I))
		return 0
	var/pieces = min(I.amount, SPACE_PLANT_ICE_MAX - ice)
	if (pieces <= 0)
		return 0
	ice += pieces
	I.use(pieces)
	return pieces

// Gives the plant's power back to the grid while it has nothing to do.
/obj/structure/reagent_dispensers/propellant_plant/proc/release_power()
	if (powersource && powersource.power_consumers[src])
		powersource.update_power(0, 1, src)

// Cracks one piece of ice while powered and with room. Returns TRUE if it did.
/obj/structure/reagent_dispensers/propellant_plant/proc/crack()
	if (ice <= 0 || !reagents || max_capacity - reagents.total_volume < SPACE_PLANT_PROPELLANT_PER_ICE)
		release_power()
		return FALSE
	if (!has_power())
		return FALSE
	ice--
	reagents.add_reagent("rocket_propellant", SPACE_PLANT_PROPELLANT_PER_ICE)
	return TRUE

/obj/structure/reagent_dispensers/propellant_plant/process()
	if (!clients.len)
		release_power()
		return
	crack()

/obj/structure/reagent_dispensers/propellant_plant/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/stack/ore/ice))
		var/pieces = load_ice(W)
		if (pieces <= 0)
			to_chat(user, SPAN_WARNING("\The [src] is full of ice."))
			return
		to_chat(user, SPAN_NOTICE("You load [pieces] piece\s of ice into \the [src] ([ice]/[SPACE_PLANT_ICE_MAX])."))
		return
	if (istype(W, /obj/item/stack/cable_coil))
		if (powersource)
			to_chat(user, SPAN_WARNING("It is already cabled."))
			return
		connect_cable(user, W)
		return
	return ..()

// ---------------------------------------------------------------- pipes
// A water recycler is a pipe source for the water it holds once its own
// module's electrolysers are full, and an electrolyser is a pipe sink, so one
// recycler, an intake or a tank of melted ice can keep several modules
// breathing. The recycler keeps its water as a number; the network draws
// from a holder refilled from it each step, and what the network took is
// settled back into the number before the water is used again.

/obj/structure/life_support/water_recycler
	var/tmp/datum/reagents/pipe_out = null
	var/tmp/pipe_offered = 0

/obj/structure/life_support/water_recycler/persistence_runtime_var(key)
	return key == "pipe_out" || key == "pipe_offered" || ..()

/obj/structure/life_support/water_recycler/proc/pipe_settle()
	if (pipe_out && pipe_offered > 0)
		var/taken = pipe_offered - pipe_out.get_reagent_amount("water")
		if (taken > 0)
			water = max(0, water - taken)
	pipe_offered = 0
	if (pipe_out)
		pipe_out.clear_reagents()

/obj/structure/life_support/water_recycler/fluid_supply_tier()
	return anchored ? FLUID_TIER_SOURCE : 0

/obj/structure/life_support/water_recycler/fluid_supplies(id)
	return id == "water"

/obj/structure/life_support/water_recycler/fluid_supply_holder()
	pipe_settle()
	if (!pipe_out)
		pipe_out = new /datum/reagents(SPACE_RECYCLER_CAPACITY, src)
	if (water > 0)
		pipe_out.add_reagent("water", water)
	pipe_offered = water
	return pipe_out

/obj/structure/life_support/electrolyser/fluid_demand_tier()
	return anchored ? FLUID_TIER_SINK : 0

/obj/structure/life_support/electrolyser/fluid_demand(id)
	if (!anchored || id != "water")
		return 0
	return max(0, water_max - water)

/obj/structure/life_support/electrolyser/fluid_receive(id, amount, data)
	var/taken = min(amount, fluid_demand(id))
	if (taken <= 0)
		return 0
	water += taken
	return taken
