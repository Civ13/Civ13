// ============================================================
// Methane-oxygen propellant (orbital stations, stage D)
// ------------------------------------------------------------
// Methalox is a cleaner rocket fuel than the hydrazine mix. It can be made
// two ways:
//
// - In a chemistry lab: carbon dioxide and hydrogen give methane, and methane
//   with oxygen gives methalox.
// - In a methalox plant, which cracks water ice like the propellant plant
//   (self_sufficiency.dm) and joins it with carbon dioxide. On Mars it draws
//   the CO2 from the open air; inside a habitat module, anywhere, it takes the
//   CO2 the crew breathe out of the module's air, so it also helps the
//   scrubber.
//
// The reusable rocket and the cargo freighter burn it; on methalox the
// reusable booster wears half as much (orbit_reusable.dm). A craft's tank
// holds one fuel at a time (crewed_lander.fuels in lander.dm).
// ============================================================

// CO2 (ledger units) one batch of methalox takes from a module's air.
#define METHALOX_CO2_PER_BATCH 1

/datum/reagent/methane
	name = "Methane"
	id = "methane"
	description = "A light, odourless fuel gas, kept cold and under pressure as a liquid."
	taste_description = "nothing at all"
	reagent_state = GAS
	color = "#d8e8f0"

/datum/reagent/methane/touch_mob(var/mob/living/L, var/amount)
	if (istype(L))
		L.adjust_fire_stacks(amount / 4)

/datum/reagent/methalox
	name = "Methalox"
	id = "methalox"
	description = "Liquid methane and liquid oxygen, a clean-burning rocket propellant."
	taste_description = "frost"
	reagent_state = LIQUID
	color = "#b8d0f8"

/datum/reagent/methalox/affect_blood(var/mob/living/human/M, var/alien, var/removed)
	M.adjustToxLoss(3 * removed)

/datum/reagent/methalox/touch_mob(var/mob/living/L, var/amount)
	if (istype(L))
		L.adjust_fire_stacks(amount / 2)

/datum/chemical_reaction/methane
	name = "Methane"
	id = "methane"
	result = "methane"
	required_reagents = list("carbon_dioxide" = 1, "hydrogen" = 4)
	result_amount = 1

/datum/chemical_reaction/methalox
	name = "Methalox"
	id = "methalox"
	result = "methalox"
	required_reagents = list("methane" = 1, "oxygen" = 2)
	result_amount = 3

// ---------------------------------------------------------------- plant

/obj/structure/reagent_dispensers/propellant_plant/methalox
	name = "methalox plant"
	desc = "Cracks water ice and joins the hydrogen with carbon dioxide into methane, then chills it with the oxygen into methalox. On Mars it breathes the open air; inside a habitat module it takes the CO2 the crew breathe out. Load ice, cable it, and draw methalox with a container."
	product = "methalox"
	product_name = "Methalox"

/obj/structure/reagent_dispensers/propellant_plant/methalox/examine(mob/user)
	..()
	var/source = co2_source()
	if (source == "air")
		to_chat(user, SPAN_NOTICE("It draws carbon dioxide from the open air."))
	else if (istype(source, /datum/habitat_ledger))
		to_chat(user, SPAN_NOTICE("It takes carbon dioxide from the module's air."))
	else
		to_chat(user, SPAN_WARNING("There is no carbon dioxide here. Set it up inside a crewed habitat module, or outside on Mars."))

// Where the CO2 comes from: "air" on open Martian ground, the module's ledger
// inside a habitat module, or null.
/obj/structure/reagent_dispensers/propellant_plant/methalox/proc/co2_source()
	var/turf/T = get_turf(src)
	if (!T)
		return null
	if (istype(T, /turf/floor/habitat))
		var/turf/floor/habitat/F = T
		var/obj/structure/habitat_core/C = F.habitat_core()
		return C ? C.air() : null
	if (barren_world() && !moon_world() && !orbit_world())
		return "air"
	return null

/obj/structure/reagent_dispensers/propellant_plant/methalox/feedstock_ready()
	var/source = co2_source()
	if (source == "air")
		return TRUE
	var/datum/habitat_ledger/L = source
	return istype(L) && L.co2 >= METHALOX_CO2_PER_BATCH

/obj/structure/reagent_dispensers/propellant_plant/methalox/use_feedstock()
	var/datum/habitat_ledger/L = co2_source()
	if (istype(L))
		L.scrub_co2(METHALOX_CO2_PER_BATCH)

#undef METHALOX_CO2_PER_BATCH
