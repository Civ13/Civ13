// Modern electrical sources. One scheduler owns updates; no machine sleepers.
#define CIV_GENERATOR_LIMIT 128

var/global/list/civ_generators = list()

/obj/structure/civ_generator
	name = "electrical generator"
	anchored = TRUE
	density = TRUE
	var/enabled = FALSE
	var/tmp/registered = FALSE
	var/tmp/retired = FALSE
	var/tmp/output_power = 0
	var/tmp/output_until = 0
	var/tmp/output_epoch = -1
	var/tmp/charge_power = 0

/obj/structure/civ_generator/New()
	..()
	register_generator()

/obj/structure/civ_generator/proc/register_generator()
	if (registered || retired || civ_generators.len >= CIV_GENERATOR_LIMIT)
		return registered
	civ_generators |= src
	registered = TRUE
	return TRUE

/obj/structure/civ_generator/proc/connected()
	return !retired && registered && anchored && isturf(loc) && powersource && isturf(powersource.loc) && powersource.loc == loc && (src in powersource.connections)

/obj/structure/civ_generator/proc/stop_generation()
	enabled = FALSE
	output_power = 0
	output_until = 0
	// Keep this interval's charge ledger: toggling cannot mint another budget.

/obj/structure/civ_generator/proc/disconnect_generation()
	stop_generation()
	if (powersource)
		var/obj/structure/cable/CB = powersource
		CB.connections -= src
		CB.power_consumers -= src
		powersource = null
		CB.rebuild_supply()

/obj/structure/civ_generator/proc/retire_generator()
	if (retired)
		return
	retired = TRUE
	civ_generators -= src
	registered = FALSE
	disconnect_generation()

/obj/structure/civ_generator/Destroy()
	retire_generator()
	return ..()

/obj/structure/civ_generator/Del()
	retire_generator()
	..()

/obj/structure/civ_generator/Move()
	var/atom/previous = loc
	. = ..()
	if (. && loc != previous)
		disconnect_generation()

/obj/structure/civ_generator/forceMove(atom/destination, special_event)
	var/atom/previous = loc
	. = ..()
	if (. && loc != previous)
		disconnect_generation()

/obj/structure/civ_generator/persistence_runtime_var(key)
	return (key in list("enabled", "registered", "retired", "output_power", "output_until", "output_epoch", "charge_power", "powersource")) || ..()

/obj/structure/civ_generator/after_load()
	..()
	disconnect_generation()
	output_epoch = -1
	charge_power = 0
	// Constructors register the restored instance, but never start output.
	register_generator()

/obj/structure/civ_generator/proc/rated_output()
	return 0

/obj/structure/civ_generator/proc/settle_generation()
	var/epoch = round(world.time / 10)
	if (retired || output_epoch == epoch)
		return
	output_epoch = epoch
	charge_power = 0
	output_power = 0
	output_until = 0
	if (!enabled || !connected() || !map || map.ordinal_age < 8)
		return
	output_power = max(0, rated_output())
	// A delayed scheduler expires output rather than backfilling missed energy.
	output_until = world.time + 10

/obj/structure/civ_generator/proc/available_output()
	if (!enabled || !connected() || !map || map.ordinal_age < 8 || world.time >= output_until)
		return 0
	return max(0, output_power - charge_power)

/obj/structure/civ_generator/proc/reserve_charge(requested)
	var/transfer = min(max(0, requested), available_output())
	charge_power += transfer
	return transfer

/obj/structure/civ_generator/solar
	name = "solar array controller"
	desc = "Controls an integrated photovoltaic array. Outdoor daylight supplies the cable grid; storage must be charged before night."
	icon = 'icons/obj/computers.dmi'
	icon_state = "solar_screen"
	var/peak_output = 30

/obj/structure/civ_generator/solar/rated_output()
	var/area/A = get_area(src)
	if (!A || A.location != AREA_OUTSIDE)
		return 0
	var/fraction = 0
	switch (time_of_day)
		if ("Early Morning") fraction = 0.25
		if ("Morning") fraction = 0.65
		if ("Midday") fraction = 1
		if ("Afternoon") fraction = 0.8
		if ("Evening") fraction = 0.15
	// Night, Dark Night and unknown labels deliberately produce no output.
	switch (A.weather)
		if (WEATHER_WET) fraction *= 0.5
		if (WEATHER_SMOG) fraction *= 0.35
		if (WEATHER_EXTREME) fraction *= 0.1
	return round(peak_output * fraction)
