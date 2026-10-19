// Modern electrical sources. One scheduler owns updates; no machine sleepers.
#define CIV_GENERATOR_LIMIT 128

var/global/list/civ_generators = list()

/proc/civ_generation_era(result_type)
	return !(ispath(result_type, /obj/structure/civ_generator) || ispath(result_type, /obj/structure/reactor_fuel_processor)) || (map && map.ordinal_age >= 8)

/proc/civ_generation_can_build(mob/living/human/H, result_type)
	if (!(ispath(result_type, /obj/structure/civ_generator) || ispath(result_type, /obj/structure/reactor_fuel_processor)))
		return TRUE
	return H && H.stat == CONSCIOUS && civ_generation_era(result_type) && H.getStat("crafting") >= 105 && map.is_node_done(H.civilization, get_recipe_node_req("[result_type]"))

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

/obj/structure/civ_generator/examine(mob/user)
	..()
	to_chat(user, "Generator: [enabled ? "enabled" : "off"]. Available output: [available_output()] PU. Maximum: [rated_output()] PU.")

/obj/structure/civ_generator/attack_hand(mob/user)
	if (!registered || !connected() || !map || map.ordinal_age < 8)
		to_chat(user, "Secure and cable this Modern generator first. The shared registry supports at most 128 generators.")
		return
	if (enabled)
		stop_generation()
	else
		enabled = TRUE
	// Enabling never resets an already spent interval or issues instant output.
	powersource.rebuild_supply()
	to_chat(user, "Generator [enabled ? "enabled" : "off"].")

/obj/structure/civ_generator/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/weapon/wrench))
		if (powersource)
			to_chat(user, "Cut the cable first.")
			return
		stop_generation()
		anchored = !anchored
		return
	if (istype(W, /obj/item/stack/cable_coil))
		if (!anchored || powersource || !registered)
			return
		var/obj/item/stack/cable_coil/CC = W
		var/obj/structure/cable/CB = CC.place_turf(get_turf(src), user, turn(get_dir(user, src), 180))
		if (!CB)
			return
		powersource = CB
		CB.connections |= src
		for (var/obj/structure/cable/N in range(1, CB))
			if (N != CB && N.z == CB.z && N.cable_color == CB.cable_color && N.tiledir == CB.tiledir && ((CB.tiledir == "horizontal" && N.y == CB.y) || (CB.tiledir == "vertical" && N.x == CB.x)))
				CB.connections |= N
				N.connections |= CB
		CB.rebuild_supply()
		return
	..()

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
	powersource.rebuild_supply()

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
