// Weather-driven renewable sources on the shared civ_generator registry.
// Era baselines (map.ordinal_age): wind chargers from the Early Modern
// age (5), photovoltaic panels from the Cold War (7), and utility wind
// turbines alongside the solar array controller in the Modern age (8).

/obj/structure/civ_generator/solar/panel
	name = "photovoltaic panel"
	desc = "A single framed photovoltaic module on a steel stand. Outdoor daylight supplies a little power to the cable grid; nothing at night."
	icon = 'icons/obj/renewable_power.dmi'
	icon_state = "solar_panel"
	min_age = 7
	peak_output = 10

/obj/structure/civ_generator/wind
	name = "wind generator"
	desc = "Turns the wind into electricity for the cable grid. Needs open sky and room from other rotors."
	icon = 'icons/obj/renewable_power.dmi'
	var/peak_output = 0
	var/base_state = ""

/obj/structure/civ_generator/wind/New()
	..()
	update_icon()

/obj/structure/civ_generator/wind/rated_output()
	var/area/A = get_area(src)
	if (!map || !A || A.location != AREA_OUTSIDE || !isturf(loc))
		return 0
	var/fraction = wind_fraction(clamp(round(map.windspeedvar), 0, 4))
	// Rotors closer than three tiles share the same air and lose half.
	for (var/obj/structure/civ_generator/wind/other in range(2, loc))
		if (other != src && other.anchored)
			fraction *= 0.5
			break
	return round(peak_output * fraction)

// Output fraction by map.windspeedvar: 0 calm, 1 light, 2 moderate, 3 strong, 4 gale.
/obj/structure/civ_generator/wind/proc/wind_fraction(speed)
	return 0

/obj/structure/civ_generator/wind/update_icon()
	icon_state = (enabled && output_power > 0) ? "[base_state]_on" : base_state

/obj/structure/civ_generator/wind/settle_generation()
	..()
	update_icon()

/obj/structure/civ_generator/wind/stop_generation()
	..()
	update_icon()

/obj/structure/civ_generator/wind/examine(mob/user)
	..()
	if (map)
		to_chat(user, "The wind is [map.windspeed].")

/obj/structure/civ_generator/wind/charger
	name = "wind charger"
	desc = "A many-bladed rotor and dynamo on a steel lattice tower, like the interwar chargers that lit remote homesteads. It furls in a gale."
	icon_state = "wind_charger"
	base_state = "wind_charger"
	min_age = 5
	peak_output = 12

/obj/structure/civ_generator/wind/charger/wind_fraction(speed)
	switch (speed)
		if (1) return 0.3
		if (2) return 0.7
		if (3) return 1
		if (4) return 0.4
	return 0

/obj/structure/civ_generator/wind/turbine
	name = "wind turbine"
	desc = "A three-bladed utility turbine on a tubular tower. Pitch control keeps it at full output even in a gale."
	icon_state = "wind_turbine"
	base_state = "wind_turbine"
	min_age = 8
	peak_output = 45

/obj/structure/civ_generator/wind/turbine/wind_fraction(speed)
	switch (speed)
		if (1) return 0.15
		if (2) return 0.5
		if (3) return 0.9
		if (4) return 1
	return 0

// The wheel stands in flowing water; its builder works from the bank and
// places it on the water tile they face. A cable coil used on the wheel
// lays the feed back toward the bank.
/obj/structure/civ_generator/waterwheel
	name = "waterwheel generator"
	desc = "A paddle wheel and dynamo on timber trestles. Build it from the bank into flowing water, then cable it back to shore."
	icon = 'icons/obj/renewable_power.dmi'
	icon_state = "waterwheel"
	min_age = 5

/obj/structure/civ_generator/waterwheel/rated_output()
	if (!isturf(loc) || !river_current_direction(loc))
		return 0
	return 12

/obj/structure/civ_generator/waterwheel/examine(mob/user)
	..()
	if (isturf(loc) && !river_current_direction(loc))
		to_chat(user, "The water here is still, so the wheel cannot turn.")

/obj/structure/civ_generator/waterwheel/New()
	..()
	update_icon()

// The icon faces the current: face-on across east-west water, edge-on in
// north-south water, turning the way the stream runs.
/obj/structure/civ_generator/waterwheel/update_icon()
	var/direction = isturf(loc) ? river_current_direction(loc) : 0
	if (direction)
		set_dir(direction)
	icon_state = (enabled && output_power > 0) ? "waterwheel_on" : "waterwheel"

/obj/structure/civ_generator/waterwheel/settle_generation()
	..()
	update_icon()

/obj/structure/civ_generator/waterwheel/stop_generation()
	..()
	update_icon()

// The flowing water tile a builder on the bank would place a wheel on.
/proc/waterwheel_build_target(mob/user)
	if (!user || !isturf(user.loc))
		return null
	return get_step(user, user.dir)

// Null when user may build result_type facing this way, otherwise why not.
/proc/waterwheel_build_refusal(mob/user, result_type)
	if (!ispath(result_type, /obj/structure/civ_generator/waterwheel))
		return null
	if (!user || !isturf(user.loc) || istype(user.loc, /turf/floor/beach/water))
		return "Stand on the bank to build a waterwheel."
	var/turf/T = waterwheel_build_target(user)
	if (!istype(T, /turf/floor/beach/water) || !river_current_direction(T))
		return "Face flowing river water to build a waterwheel."
	if (T.density || T.iscovered())
		return "There is no room for a waterwheel there."
	for (var/atom/movable/A in T)
		if (A.density)
			return "There is no room for a waterwheel there."
	return null
