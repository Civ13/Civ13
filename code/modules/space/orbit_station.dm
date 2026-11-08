// ============================================================
// Orbital station hardware (orbital stations, stage B, 1969)
// ------------------------------------------------------------
// The orbital day: every orbit is ORBIT_SUNLIT_SECONDS of sunlight and then
// ORBIT_SHADE_SECONDS of shade. The registry keeps where the station is in
// it as a remaining number of seconds (never a world.time stamp), and the
// clock only runs while the world has players.
//
// Heat: a module in orbit loses heat slowly to the cold of space, gains heat
// from the sun while sunlit and from every machine that works inside it.
// Heaters carry it through the shade; radiators shed the excess.
//
// Hardware, all gated on Orbital Flight (1969):
// - the orbital workshop module, a module kit with two bunks, a workbench
//   and a crate, the first module of a 1969 station;
// - the fixed solar wing, a photovoltaic generator that gives power only in
//   the sunlit part of the orbit (any solar generator in orbit follows the
//   orbital day and ignores the weather);
// - the fuel cell, a generator that burns hydrogen and oxygen into power and
//   keeps the water it makes, for the shade;
// - the radiator, a life support machine that sheds a module's excess heat.
//
// Debris strikes hull modules in orbit the way meteorites strike them on the
// barren surface, and a breach is patched the same way.
// ============================================================

#define ORBIT_SUNLIT_SECONDS 1200
#define ORBIT_SHADE_SECONDS 600
// Most seconds one advance may count, so a late call cannot replay a backlog.
#define ORBIT_DAY_MAX_STEP 10
// Heat in degrees per second for a module, with the module's tick.
#define ORBIT_SUN_HEAT_PER_SECOND 0.15
#define ORBIT_MACHINE_HEAT_PER_POWER 0.004
#define ORBIT_RADIATOR_PER_SECOND 0.4
// Fuel cell: units of hydrogen and of oxygen burnt per second of output,
// and water kept per second.
#define ORBIT_FUEL_CELL_BURN 0.2
#define ORBIT_FUEL_CELL_WATER 0.2

// This session only (never saved): when the orbital day was last advanced.
var/global/orbit_day_last_advance = -1

// ---------------------------------------------------------------- the day

// Advances the orbital day by the time since the last call, capped, while
// the world has players.
/proc/orbit_day_advance()
	var/obj/structure/orbit_registry/R = orbit_get_registry()
	if (!R)
		return FALSE
	var/now = world.time
	var/last = orbit_day_last_advance
	orbit_day_last_advance = now
	if (last < 0 || !clients.len)
		return FALSE
	return orbit_day_step(min(ORBIT_DAY_MAX_STEP, max(0, (now - last) / 10)))

// Counts the orbital day on by seconds. Returns TRUE when it turned.
/proc/orbit_day_step(seconds)
	var/obj/structure/orbit_registry/R = orbit_get_registry()
	if (!R || !isnum(seconds) || seconds <= 0)
		return FALSE
	if (!isnum(R.sun_left) || R.sun_left <= 0 || R.sun_left > ORBIT_SUNLIT_SECONDS + ORBIT_SHADE_SECONDS)
		R.sun_left = R.sunlit ? ORBIT_SUNLIT_SECONDS : ORBIT_SHADE_SECONDS
	R.sun_left -= seconds
	if (R.sun_left > 0)
		return FALSE
	R.sunlit = !R.sunlit
	R.sun_left = R.sunlit ? ORBIT_SUNLIT_SECONDS : ORBIT_SHADE_SECONDS
	orbit_day_announce(R.sunlit ? SPAN_NOTICE("The sun rises over the edge of the world.") : SPAN_WARNING("The station passes into the world's shadow. Solar power fails until sunrise."))
	return TRUE

/proc/orbit_sunlit()
	if (!orbit_world())
		return FALSE
	orbit_day_advance()
	var/obj/structure/orbit_registry/R = orbit_get_registry()
	return R && R.sunlit ? TRUE : FALSE

// Seconds until the orbital day turns, for consoles and examine text.
/proc/orbit_day_left()
	var/obj/structure/orbit_registry/R = orbit_get_registry()
	return R ? max(0, round(R.sun_left)) : 0

/proc/orbit_day_announce(message)
	for (var/client/C in clients)
		var/mob/living/human/H = C.mob
		if (istype(H) && H.z && orbit_world())
			to_chat(H, message)

// ---------------------------------------------------------------- heat

// A module's heat for one step: sunlight on the hull, then the radiators
// (machines add their own heat as they work, habitat_modules.dm).
/proc/orbit_module_heat(datum/habitat_ledger/L, seconds)
	if (!L || !orbit_world())
		return FALSE
	if (orbit_sunlit())
		L.temperature += ORBIT_SUN_HEAT_PER_SECOND * seconds
	L.clamp_contents()
	return TRUE

/proc/orbit_machine_heat(datum/habitat_ledger/L, obj/structure/life_support/M, seconds)
	if (!L || !M || !orbit_world() || istype(M, /obj/structure/life_support/radiator))
		return FALSE
	L.temperature += max(0, M.powerneeded) * ORBIT_MACHINE_HEAT_PER_POWER * seconds
	return TRUE

// ---------------------------------------------------------------- workshop

/obj/item/habitat_kit/orbital_workshop
	name = "orbital workshop kit"
	desc = "A folded orbital workshop: two bunks, a workbench and a crate, sealed in a 5x5 module. Use it where you stand, in orbit or on the ground."
	kind = "orbital workshop"

// ---------------------------------------------------------------- solar

/obj/structure/civ_generator/solar/wing
	name = "fixed solar wing"
	desc = "A rigid wing of photovoltaic cells on a short boom. In orbit it charges the grid only while the station is in sunlight."
	icon = 'icons/obj/renewable_power.dmi'
	icon_state = "solar_panel"
	min_age = 7
	peak_output = 20

/obj/structure/civ_generator/solar/wing/examine(mob/user)
	..()
	if (orbit_world())
		to_chat(user, orbit_sunlit() ? "In sunlight for another [orbit_day_left()] seconds." : "In shadow for another [orbit_day_left()] seconds.")
		// Cell wear (orbit_wear.dm).
		to_chat(user, "Cell wear: [round(wear)]%[wear >= 25 ? ". Two glass sheets would replace the worst cells." : "."]")

// 2013: a wider array on a gimbal that keeps it square to the sun.
/obj/structure/civ_generator/solar/wing/tracking
	name = "tracking solar array"
	desc = "Two wide photovoltaic wings on a gimbal that keeps them square to the sun. In orbit it charges the grid only while the station is in sunlight."
	min_age = 8
	peak_output = 35

// ---------------------------------------------------------------- isotope

// 2013: steady power through sunlight and shade, with nothing to feed.
/obj/structure/civ_generator/isotope
	name = "radioisotope generator"
	desc = "A shielded core of decaying isotope ringed with thermocouples. It gives steady power through sunlight and shade, with nothing to feed it. Cable it and switch it on."
	icon = 'icons/obj/modern_structures.dmi'
	icon_state = "uranium_refinery"
	min_age = 8
	var/peak_output = 10

/obj/structure/civ_generator/isotope/rated_output()
	return peak_output

// ---------------------------------------------------------------- fuel cell

/obj/structure/civ_generator/fuel_cell
	name = "fuel cell"
	desc = "Burns hydrogen and oxygen into steady power and keeps the water it makes. Pour both in, cable it and switch it on; empty a container on it to draw the water."
	icon = 'icons/obj/modern_structures.dmi'
	icon_state = "smes2"
	min_age = 7
	var/peak_output = 15
	var/hydrogen = 0
	var/oxygen = 0
	var/water = 0
	var/tank_max = 200

/obj/structure/civ_generator/fuel_cell/rated_output()
	return (hydrogen >= ORBIT_FUEL_CELL_BURN && oxygen >= ORBIT_FUEL_CELL_BURN) ? peak_output : 0

/obj/structure/civ_generator/fuel_cell/settle_generation()
	var/epoch = round(world.time / 10)
	var/fresh = output_epoch != epoch
	..()
	if (fresh && output_power > 0)
		hydrogen = max(0, hydrogen - ORBIT_FUEL_CELL_BURN)
		oxygen = max(0, oxygen - ORBIT_FUEL_CELL_BURN)
		water = min(tank_max, water + ORBIT_FUEL_CELL_WATER)

/obj/structure/civ_generator/fuel_cell/examine(mob/user)
	..()
	to_chat(user, "Hydrogen: [round(hydrogen)]/[tank_max]. Oxygen: [round(oxygen)]/[tank_max]. Water: [round(water)]/[tank_max].")

/obj/structure/civ_generator/fuel_cell/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/weapon/reagent_containers) && W.reagents)
		var/took = 0
		var/h = min(tank_max - hydrogen, W.reagents.get_reagent_amount("hydrogen"))
		if (h > 0)
			W.reagents.remove_reagent("hydrogen", h)
			hydrogen += h
			took += h
		var/o = min(tank_max - oxygen, W.reagents.get_reagent_amount("oxygen"))
		if (o > 0)
			W.reagents.remove_reagent("oxygen", o)
			oxygen += o
			took += o
		if (took)
			to_chat(user, SPAN_NOTICE("You fill \the [src]."))
			return
		var/w = min(water, W.reagents.maximum_volume - W.reagents.total_volume)
		if (w > 0)
			W.reagents.add_reagent("water", w)
			water -= w
			to_chat(user, SPAN_NOTICE("You draw [round(w)] units of water from \the [src]."))
			return
		to_chat(user, SPAN_WARNING("\The [src] takes only hydrogen and oxygen, and has no water to give."))
		return
	return ..()

// ---------------------------------------------------------------- radiator

/obj/structure/life_support/radiator
	name = "radiator"
	desc = "Pumps coolant from the module out to panels that shed heat into space. Cable it inside a module; it only runs while the module is warmer than room temperature."
	powerneeded = 2

/obj/structure/life_support/radiator/work(datum/habitat_ledger/L, seconds)
	if (L.temperature <= HABITAT_ROOM_C || !has_power())
		return FALSE
	L.temperature = max(HABITAT_ROOM_C, L.temperature - ORBIT_RADIATOR_PER_SECOND * seconds)
	return TRUE
