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

// A dynamo on the bank can draw from an adjacent flowing water tile.
/obj/structure/civ_generator/waterwheel
	name = "waterwheel generator"
	desc = "A waterwheel and dynamo. Place it beside flowing water and connect it to a cable."
	icon = 'icons/obj/renewable_power.dmi'
	icon_state = "waterwheel"
	min_age = 5

/obj/structure/civ_generator/waterwheel/rated_output()
	if (!isturf(loc) || istype(loc, /turf/floor/beach/water))
		return 0
	for (var/direction in list(NORTH, SOUTH, EAST, WEST))
		if (river_current_direction(get_step(src, direction)))
			return 12
	return 0

/obj/structure/civ_generator/waterwheel/update_icon()
	icon_state = (enabled && output_power > 0) ? "waterwheel_on" : "waterwheel"

/obj/structure/civ_generator/waterwheel/settle_generation()
	..()
	update_icon()

/obj/structure/civ_generator/waterwheel/stop_generation()
	..()
	update_icon()
