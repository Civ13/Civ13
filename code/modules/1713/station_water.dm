// Water for crafting stations (docs/station-water.md).
//
// A station that works with water has a small tank: `water_capacity` units,
// `water_per_use` taken each time it is used, `water_store` held now. Pour an
// open container into it, or pipe water to it on a pumped network. Set beside
// running water (a river with a current, a wet aqueduct channel, a fountain,
// a tap, a sink or a filled public bath) it simply counts as full, so no
// timer runs and nothing needs saving but the store. Still water lets you
// fill it by hand but never feeds it. A frozen river, or one at low water,
// stops feeding until it recovers.
//
// Hand recipes ask for water through config/craft_needs.json ("water": units
// per product), drawn from an open container held or at the crafter's feet,
// or free when the crafter stands beside running water.
//
// On a map without river flow data (round maps) any fresh water beside the
// station feeds it, so those maps play as before.

// River stage (levels from normal) at or below which a river no longer feeds.
#define STATION_WATER_LOW_STAGE -1

/obj/structure
	// Units of water the station's tank holds; 0 means it has no tank.
	var/water_capacity = 0
	// Units taken each time the station is used.
	var/water_per_use = 0
	// Units in the tank now.
	var/water_store = 0

// What feeds water to something at A, as a short phrase ("the river"), or
// null when nothing does.
/proc/running_water_feed(atom/A)
	var/turf/centre = get_turf(A)
	if (!centre)
		return null
	var/datum/river_flow/flow = map ? map.river_flow() : null
	var/charted = flow && flow.z_level == centre.z
	for (var/turf/T in range(1, centre))
		if (is_liquid_water(T) && aqueduct_fresh_water(T))
			if (!charted)
				return "fresh water"
			if (river_current_direction(T) && river_stage_at(T) > STATION_WATER_LOW_STAGE)
				return "the river"
		for (var/obj/O in T)
			var/feed = O.feeds_station_water()
			if (feed)
				return feed
	return null

// A phrase naming this as a running water feed, or null.
/obj/proc/feeds_station_water()
	return null

/obj/structure/aqueduct/feeds_station_water()
	return wet ? "the aqueduct" : null

/obj/structure/sink/feeds_station_water()
	return volume > 0 ? "the sink" : null

/obj/structure/sink/aqueduct_fountain/feeds_station_water()
	if (volume <= 0 || world.time - last_fed >= 1200)
		return null
	return "the [name]"

/obj/structure/aqueduct_bath/feeds_station_water()
	return has_water() ? "the bath" : null

/obj/structure/water_tap/feeds_station_water()
	return reagents && reagents.get_reagent_amount("water") > 0 ? "the tap" : null

/obj/structure/proc/station_water_feed()
	return water_capacity ? running_water_feed(src) : null

// Checks availability without drawing from the tank. A user can receive the shortage warning.
/obj/structure/proc/station_has_water(amount = water_per_use, mob/user = null)
	var/has_water = station_water_feed() || water_store >= amount
	if (user && !has_water)
		station_warn_needs_water(user, amount)
	return has_water

// Takes the water for one use. TRUE when there was enough; otherwise tells
// the user what to do and takes nothing.
/obj/structure/proc/station_take_water(mob/user, amount = water_per_use)
	if (!water_capacity || amount <= 0 || station_water_feed())
		return TRUE
	if (water_store >= amount)
		water_store -= amount
		return TRUE
	station_warn_needs_water(user, amount)
	return FALSE

/obj/structure/proc/station_warn_needs_water(mob/user, amount)
	if (user)
		to_chat(user, SPAN_WARNING("\The [src] needs water ([amount] units, it holds [round(water_store)]). Pour some in with a bucket, pipe it in, or set it beside running water."))

// Pours the water from an open container into the tank. TRUE when handled.
/obj/structure/proc/station_water_pour(obj/item/O, mob/user)
	var/obj/item/weapon/reagent_containers/C = O
	if (!water_capacity || !istype(C) || !C.is_open_container() || !C.reagents)
		return FALSE
	var/held = C.reagents.get_reagent_amount("water")
	if (held <= 0)
		return FALSE
	if (station_water_feed())
		to_chat(user, SPAN_NOTICE("\The [src] is fed with running water already."))
		return TRUE
	var/amount = min(held, water_capacity - water_store)
	if (amount <= 0)
		to_chat(user, SPAN_NOTICE("\The [src] is full of water."))
		return TRUE
	C.reagents.remove_reagent("water", amount)
	water_store += amount
	playsound(src, 'sound/effects/slosh.ogg', 25, TRUE)
	to_chat(user, SPAN_NOTICE("You pour [round(amount)] units of water into \the [src]."))
	return TRUE

/obj/structure/proc/station_water_examine(mob/user)
	if (!water_capacity)
		return
	var/feed = station_water_feed()
	if (feed)
		to_chat(user, SPAN_NOTICE("Its water is fed by [feed]."))
	else
		to_chat(user, SPAN_NOTICE("It holds [round(water_store)] of [water_capacity] units of water; each use takes [water_per_use]."))

// Pumped pipes fill the tank like any other pipe sink (factory_pipes.dm).
/obj/structure/fluid_demand_tier()
	if (water_capacity && anchored)
		return FLUID_TIER_SINK
	return ..()

/obj/structure/fluid_demand(id)
	if (water_capacity && anchored && id == "water")
		return max(0, water_capacity - water_store)
	return ..()

/obj/structure/fluid_receive(id, amount, data)
	if (!water_capacity || id != "water")
		return ..()
	var/taken = min(amount, fluid_demand(id))
	water_store += taken
	return taken

// ---- hand recipes -----------------------------------------------------------

// Whatever pays `amount` units of water for a hand recipe: a container held
// or at the builder's feet, a running water phrase, or null.
/proc/craft_need_water(mob/living/human/H, amount, list/candidates)
	var/feed = running_water_feed(H)
	if (feed)
		return feed
	for (var/obj/item/weapon/reagent_containers/C in candidates)
		if (C.is_open_container() && C.reagents && C.reagents.get_reagent_amount("water") >= amount)
			return C
	return null

// ---- stations that use water ------------------------------------------------
// The potter's wheel and brick bench are in clay_lime_fire.dm.

// A retting trough soaks fibre in water: 30 a batch. Retting in a river or
// pond tile stays free.
/obj/structure/converter/retting_trough
	water_capacity = 90
	water_per_use = 30

/obj/structure/converter/retting_trough/attackby(obj/item/M, mob/user)
	if (station_water_pour(M, user))
		return
	if (!filled && (istype(M, input) || istype(M, input1)) && M.amount >= inputamount && crafting_recipe_allowed(user, "[output]") && !station_take_water(user))
		return
	return ..()

/obj/structure/converter/retting_trough/examine(mob/user, distance = -1)
	. = ..()
	station_water_examine(user)

#undef STATION_WATER_LOW_STAGE
