// Diesel working (docs/trains.md#diesel-working). What a diesel gives over
// steam is a small crew: no fire, no water, one driver.
//
// - The main-line diesel is six sections long with a cab at each end. It is
//   driven from either; the cab that leads has to be manned for full speed.
// - Diesel units coupled next to each other work in multiple: their control
//   cables join with the couplings, so one driver starts, stops, drives and
//   brakes them all from any of their cabs.
// - A dead-man's handle: with nobody fit to hold it in a cab of the working
//   units, the power is shut off and the brakes go on.

#define DEADMAN_CHECKS 2 // looks at the cab, one every six tiles, before it trips

/obj/structure/trains/locomotive
	var/tmp/list/linked = null // car id -> engine of the units worked with this one, while it drives
	var/tmp/deadman_missed = 0

/obj/structure/trains/locomotive/heavy_diesel/mainline
	name = "main-line diesel locomotive"
	desc = "A big diesel locomotive with a cab at each end and walkways along its hood. It runs on diesel or biodiesel, and works in multiple with other diesels coupled next to it."
	body_kind = "dieselmain"
	health = 4000
	max_fuel = 600
	train_weight = 6.5 // 9 with its five body sections
	haul = 64

/////////////////////////////////////////////////////////////////////////////
// Two cabs

// The rear cab of an engine with a cab at each end, or null.
/obj/structure/trains/locomotive/proc/rear_cab()
	var/list/L = body_layout()
	if (!L || !L["cab2"])
		return null
	for (var/obj/structure/trains/platform/P in range(body_length(), src))
		if (P.car_id == car_id && P.seg_index == L["cab2"])
			return P
	return null

// TRUE when somebody fit to drive stands in a cab: 1 the front cab, 2 the
// rear one, 0 either.
/obj/structure/trains/locomotive/proc/cab_manned(which = 0)
	var/list/spots = list()
	if (which != 2)
		spots += control_spot()
	if (which != 1)
		spots += rear_cab()
	for (var/obj/structure/trains/S in spots)
		if (!isturf(S.loc))
			continue
		for (var/turf/T in train_platform_tiles(S.loc, S.dir))
			for (var/mob/living/human/H in T)
				if (H.stat == CONSCIOUS && !H.incapacitated())
					return TRUE
	return FALSE

/////////////////////////////////////////////////////////////////////////////
// Working in multiple

// TRUE for an engine that is worked with its neighbours from one cab.
/obj/structure/trains/locomotive/proc/works_in_multiple()
	return FALSE

/obj/structure/trains/locomotive/heavy_diesel/works_in_multiple()
	return TRUE

// The units worked with this one: the unbroken row of such engines it is
// coupled into, itself included, as car id -> engine. Null for an engine that
// works alone. `cars` is the train in order, when the caller has it.
/obj/structure/trains/locomotive/proc/linked_units(list/cars)
	if (!works_in_multiple() || !car_id)
		return null
	if (!cars)
		cars = train_consist_list(train_head())
	// The train as a row of vehicles: the sections of one share a car id.
	var/list/ids = list()
	var/list/engines = list()
	var/last = null
	for (var/obj/structure/trains/car in cars)
		var/id = car.car_id ? car.car_id : "\ref[car]"
		if (id != last)
			ids += id
			last = id
		if (istype(car, /obj/structure/trains/locomotive))
			var/obj/structure/trains/locomotive/L = car
			if (L.works_in_multiple())
				engines[id] = L
	var/at = ids.Find(car_id)
	if (!at)
		return null
	var/list/units = list()
	units[car_id] = src
	for (var/i = at - 1, i >= 1, i--)
		if (!engines[ids[i]])
			break
		units[ids[i]] = engines[ids[i]]
	for (var/i = at + 1, i <= ids.len, i++)
		if (!engines[ids[i]])
			break
		units[ids[i]] = engines[ids[i]]
	return units

// The unit whose controls a cab of this engine works: the linked unit that
// is driving the train, else this engine itself.
/obj/structure/trains/locomotive/proc/linked_driver()
	if (driving)
		return src
	var/list/units = linked_units()
	for (var/id in units)
		var/obj/structure/trains/locomotive/L = units[id]
		if (L != src && L.driving)
			return L
	return src

// Starts or stops the units linked to this one with it. Returns how many
// changed.
/obj/structure/trains/locomotive/proc/switch_linked(state, mob/user)
	. = 0
	var/list/units = linked_units()
	if (!units || units.len < 2)
		return
	for (var/id in units)
		var/obj/structure/trains/locomotive/L = units[id]
		if (L == src || !!L.on == !!state)
			continue
		if (state && (L.engine_disabled() || (L.max_fuel && L.fuel <= 0) || L.start_problem()))
			if (user)
				to_chat(user, SPAN_WARNING("\The [L] linked to it does not start: [L.engine_disabled() ? "it is wrecked" : "its [L.fuel_store] is empty"]."))
			continue
		L.on = !!state
		if (!state)
			L.throttle = 0
		L.update_icon()
		.++
	if (. && user)
		to_chat(user, "[.] linked unit\s [state ? "start" : "stop"] with it.")

/obj/structure/trains/locomotive/heavy_diesel/state_text()
	. = ..()
	var/list/units = linked_units()
	if (!units || units.len < 2)
		return
	var/running = 0
	for (var/id in units)
		var/obj/structure/trains/locomotive/L = units[id]
		if (L.on)
			running++
	. += " [units.len] units work in multiple, [running] running."

/////////////////////////////////////////////////////////////////////////////
// The dead-man's handle

/obj/structure/trains/locomotive/proc/has_deadman()
	return FALSE

/obj/structure/trains/locomotive/heavy_diesel/has_deadman()
	return TRUE

// TRUE when a cab of this engine or of a unit linked to it is manned.
/obj/structure/trains/locomotive/proc/deadman_held()
	if (cab_manned())
		return TRUE
	for (var/id in linked)
		var/obj/structure/trains/locomotive/L = linked[id]
		if (L != src && !QDELETED(L) && L.cab_manned())
			return TRUE
	return FALSE

// Looked at from the drive loop (trains.dm) each time the train is counted.
// Returns TRUE when the handle trips.
/obj/structure/trains/locomotive/proc/deadman_watch()
	if (!has_deadman() || (throttle <= 0 && braking) || deadman_held())
		deadman_missed = 0
		return FALSE
	deadman_missed++
	if (deadman_missed < DEADMAN_CHECKS)
		return FALSE
	deadman_missed = 0
	throttle = 0
	braking = TRUE
	if (isturf(loc))
		visible_message(SPAN_WARNING("With nobody at the controls, the dead-man's handle of \the [src] shuts off the power and puts its brakes on."))
		playsound(loc, 'sound/effects/lever.ogg', 80, TRUE)
	return TRUE

/obj/structure/trains/locomotive/proc/diesel_examine(mob/user)
	to_chat(user, "It has a dead-man's handle: with nobody fit to drive in a cab, the power shuts off and the brakes go on within a dozen tiles.")
	var/list/units = linked_units()
	if (units && units.len > 1)
		to_chat(user, "[units.len] diesel units are coupled together and work in multiple: any of their cabs starts, stops, drives and brakes them all.")
	else
		to_chat(user, "Couple another diesel locomotive next to it and the two work in multiple from one cab.")

#undef DEADMAN_CHECKS
