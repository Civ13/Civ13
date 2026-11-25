// Lifts: a platform that rides up and down a shaft between storeys, carrying
// whoever and whatever stands on it.
//
// The shaft is a column of open air through the floors over a patch of ground.
// The platform stands at the bottom, or on the open air of any storey it has
// been raised to, and is floor while it is there (castle_trapdoor_holds in
// castle_traps.dm). Click it while standing on it to ride to another storey.
//
// What winds it decides how fast it goes and whether it comes when called:
// - nothing: the rider winds it up by hand, a storey at a time, slowly;
// - a treadwheel, horse gin, mill wheel or windmill turning beside the shaft
//   on any storey winds it faster (mechanical_power.dm);
// - a steam lift engine beside the shaft winds it fast, burning a little fuel
//   for each storey;
// - an electric lift motor beside the shaft, connected to a powered cable,
//   winds it fastest.
// A lift bell beside the shaft rings for the rider of a hand-wound lift; with
// any other drive, it, or a lift call button, brings the platform to that floor.
//
// A wooden platform carries people and what they can carry; an iron lift car
// also takes the heavy machines that otherwise need a hoist (lifting_machines.dm).
// Nothing ticks and nothing but the objects themselves is saved.
//
// Art: icons/obj/lifts.dmi, drawn by Fable with tests/sprites/create_lifts.py.

#define LIFT_HAND_TIME 60        // deciseconds a storey, wound by hand
#define LIFT_STEAM_FACTOR 0.35   // share of the hand time with a steam engine
#define LIFT_ELECTRIC_TIME 8     // deciseconds a storey with an electric motor
#define LIFT_MIN_TIME 8
#define LIFT_MAX_STOREYS 8       // levels searched up and down a shaft
#define LIFT_DRIVE_HAND 0
#define LIFT_DRIVE_MOVER 1
#define LIFT_DRIVE_STEAM 2
#define LIFT_DRIVE_ELECTRIC 3

/obj/structure/lift_platform
	name = "wooden lift"
	desc = "A heavy timber platform hung on ropes in a shaft between storeys. Stand on it and click it to ride up or down."
	icon = 'icons/obj/lifts.dmi'
	icon_state = "lift_wood"
	anchored = TRUE
	density = FALSE
	layer = TURF_LAYER + 0.3 // a floor: under people and things on it
	not_movable = TRUE
	not_disassemblable = FALSE
	flammable = TRUE
	var/carries_heavy = FALSE
	var/tmp/moving = FALSE

/obj/structure/lift_platform/iron
	name = "lift car"
	desc = "An iron-framed lift car with a railing, hung on cables in a shaft between storeys. It takes heavy machines as well as people. Stand on it and click it to ride up or down."
	icon_state = "lift_iron"
	flammable = FALSE
	carries_heavy = TRUE

/obj/structure/lift_platform/persistence_runtime_var(key)
	return key == "moving" || ..()

// ---- the shaft -----------------------------------------------------------------------

// The turf at the same x and y on level z, or null.
/proc/lift_turf_on(turf/T, z)
	return (T && z) ? locate(T.x, T.y, z) : null

// TRUE when a lift can stand on T in a shaft: open air with nothing laid over
// it (the platform rides through), or the ground at the bottom of the shaft.
/proc/lift_stop_open(turf/T)
	if (!T || T.density)
		return FALSE
	if (building_open_turf(T))
		if (locate(/obj/covers) in T)
			return FALSE
		if (trapdoor_at(T) || (locate(/obj/structure/castle_trapdoor) in T))
			return FALSE
	for (var/atom/movable/A in T)
		if (A.density && !ismob(A))
			return FALSE
	return TRUE

// The levels this platform can stop at, bottom first: up through open air and
// down to the ground under it. Every stop between keeps the shaft clear.
/obj/structure/lift_platform/proc/shaft_levels()
	. = list()
	var/turf/here = get_turf(src)
	if (!here)
		return
	var/list/below = list()
	var/turf/T = here
	var/z = multiz_level_below(T.z)
	// Down: while the cell we stand in is open air, the level below is reachable.
	while (z && below.len < LIFT_MAX_STOREYS && building_open_turf(T))
		var/turf/B = lift_turf_on(here, z)
		if (!lift_stop_open(B))
			break
		below.Insert(1, z)
		T = B
		z = multiz_level_below(z)
	. += below
	. += here.z
	z = multiz_level_above(here.z)
	var/count = 0
	while (z && count < LIFT_MAX_STOREYS)
		var/turf/U = lift_turf_on(here, z)
		if (!U || !building_open_turf(U) || !lift_stop_open(U))
			break
		. += z
		count++
		z = multiz_level_above(z)

// Every cell of the shaft, on each level it can stop at.
/obj/structure/lift_platform/proc/shaft_turfs()
	. = list()
	var/turf/here = get_turf(src)
	for (var/z in shaft_levels())
		. += lift_turf_on(here, z)

// ---- drives --------------------------------------------------------------------------

/obj/structure/lift_drive
	name = "lift drive"
	icon = 'icons/obj/lifts.dmi'
	anchored = TRUE
	density = TRUE
	not_movable = FALSE
	not_disassemblable = FALSE
	var/base_state = ""

/obj/structure/lift_drive/proc/ready()
	return FALSE

// Spend what one trip of storeys costs; FALSE when it cannot.
/obj/structure/lift_drive/proc/spend(storeys)
	return ready()

/obj/structure/lift_drive/proc/run_icon(on)
	icon_state = on ? "[base_state]_on" : base_state

/obj/structure/lift_drive/proc/lift_drive_kind()
	return LIFT_DRIVE_HAND

// Steam lift engine: burns solid fuel, a haul's worth a storey.
/obj/structure/lift_drive/steam
	name = "steam lift engine"
	desc = "A small boiler and winding drum that winds a lift up and down its shaft. Load coal, charcoal or wood; each storey burns a little."
	icon_state = "steam_lift_engine"
	base_state = "steam_lift_engine"
	var/fuel = 0
	var/fuel_limit = 40

/obj/structure/lift_drive/steam/lift_drive_kind()
	return LIFT_DRIVE_STEAM

/obj/structure/lift_drive/steam/ready()
	return anchored && fuel >= 1

/obj/structure/lift_drive/steam/spend(storeys)
	if (!anchored || fuel < storeys)
		return FALSE
	fuel -= storeys
	return TRUE

/obj/structure/lift_drive/steam/examine(mob/user, distance = -1)
	..()
	to_chat(user, SPAN_NOTICE("It has fuel for [round(fuel)] of [fuel_limit] storeys."))

/obj/structure/lift_drive/steam/attackby(obj/item/I, mob/living/human/H)
	if (is_tool(I, TOOL_WRENCH))
		toggle_anchor(H)
		return
	var/obj/item/stack/S = I
	var/each = istype(S) ? solid_fuel_unit_value(S, steam_crane_fuel_rates) : 0
	if (!each || !istype(H))
		return ..()
	var/moved = min(S.amount, round((fuel_limit - fuel) / each))
	if (moved <= 0)
		to_chat(H, SPAN_WARNING("\The [src]'s bunker is full."))
		return
	record_wood_fuel(S, moved * each)
	S.use(moved)
	fuel += moved * each
	visible_message(SPAN_NOTICE("[H] stokes \the [src]."))

// Electric lift motor: draws from a powered cable while it winds.
/obj/structure/lift_drive/electric
	name = "electric lift motor"
	desc = "An electric motor and cable drum that winds a lift up and down its shaft. Bolt it down with a wrench and connect a powered cable to it."
	icon_state = "lift_motor"
	base_state = "lift_motor"
	powerneeded = 10

/obj/structure/lift_drive/electric/lift_drive_kind()
	return LIFT_DRIVE_ELECTRIC

/obj/structure/lift_drive/electric/ready()
	return anchored && powersource && powersource.powered

/obj/structure/lift_drive/electric/spend(storeys)
	if (!anchored || !powersource)
		return FALSE
	return draw_cable_power()

/obj/structure/lift_drive/electric/run_icon(on)
	..()
	if (!on && powersource)
		powersource.update_power(-powerneeded, 1, src)

/obj/structure/lift_drive/electric/attackby(obj/item/I, mob/living/human/H)
	if (is_tool(I, TOOL_WRENCH))
		if (powersource)
			to_chat(H, SPAN_NOTICE("Remove the cables first."))
			return
		toggle_anchor(H)
		return
	if (istype(I, /obj/item/stack/cable_coil))
		if (!anchored)
			to_chat(H, SPAN_NOTICE("Bolt \the [src] down with a wrench first."))
			return
		connect_cable(H, I)
		return
	return ..()

/obj/structure/lift_drive/electric/examine(mob/user, distance = -1)
	..()
	to_chat(user, ready() ? SPAN_NOTICE("Its switch box lamp shows power.") : SPAN_WARNING("It has no power."))

// The best drive working this platform's shaft: an electric motor, a steam
// engine, then a turning prime mover, beside any stop of the shaft.
/obj/structure/lift_platform/proc/best_drive()
	var/obj/structure/lift_drive/best = null
	var/mover = FALSE
	for (var/turf/T in shaft_turfs())
		for (var/obj/structure/lift_drive/D in range(1, T))
			if (D.ready() && (!best || D.lift_drive_kind() > best.lift_drive_kind()))
				best = D
		if (!mover && mechanical_drive_factor(T) < 1)
			mover = TRUE
	if (best)
		return best
	return mover ? LIFT_DRIVE_MOVER : null

/obj/structure/lift_platform/proc/drive_kind(drive)
	if (istype(drive, /obj/structure/lift_drive))
		var/obj/structure/lift_drive/D = drive
		return D.lift_drive_kind()
	return drive == LIFT_DRIVE_MOVER ? LIFT_DRIVE_MOVER : LIFT_DRIVE_HAND

// Deciseconds to travel this many storeys with drive.
/obj/structure/lift_platform/proc/travel_time(drive, storeys)
	switch (drive_kind(drive))
		if (LIFT_DRIVE_ELECTRIC)
			return max(LIFT_MIN_TIME, LIFT_ELECTRIC_TIME * storeys)
		if (LIFT_DRIVE_STEAM)
			return max(LIFT_MIN_TIME, round(LIFT_HAND_TIME * LIFT_STEAM_FACTOR * storeys))
		if (LIFT_DRIVE_MOVER)
			var/factor = 1
			for (var/turf/T in shaft_turfs())
				factor = min(factor, mechanical_drive_factor(T))
			return max(LIFT_MIN_TIME, round(LIFT_HAND_TIME * factor * storeys))
	return LIFT_HAND_TIME * storeys

// ---- riding --------------------------------------------------------------------------

// Storeys counted from the bottom of the shaft (1 is the bottom).
/obj/structure/lift_platform/proc/storey_label(list/levels, z)
	var/index = levels.Find(z)
	return index ? "[building_storey_name(index)] stop" : "stop"

// What on the platform's tile rides with it.
/obj/structure/lift_platform/proc/riders()
	. = list()
	var/turf/T = get_turf(src)
	if (!T)
		return
	for (var/atom/movable/A in T)
		if (A == src || isobserver(A) || istype(A, /atom/movable/lighting_overlay) || istype(A, /atom/movable/lighting_fullbright) || istype(A, /obj/effect))
			continue
		if (A.anchored && !ismob(A))
			continue
		. += A
	// Keep a rider with their seat. Fixed furniture isn't part of the load.
	var/list/carried = .
	for (var/mob/living/M in carried.Copy())
		if (M.buckled && !(M.buckled in carried))
			carried -= M

// Why the platform refuses to carry what is on it, or null.
/obj/structure/lift_platform/proc/load_refusal(list/carried = null)
	if (carries_heavy)
		return null
	if (isnull(carried))
		carried = riders()
	for (var/atom/movable/A in carried)
		if (needs_hoist(A))
			return "\The [A] is too heavy for \the [src]. An iron lift car or a hoist could take it."
	return null

// Moves the platform and its riders to level z. TRUE when it got there.
/obj/structure/lift_platform/proc/arrive(z, list/carried = null)
	var/turf/here = get_turf(src)
	var/turf/there = lift_turf_on(here, z)
	if (!there || !lift_stop_open(there))
		return FALSE
	if (isnull(carried))
		carried = riders()
	if (!persistence_set_loc(there))
		return FALSE
	var/list/seated = list()
	for (var/atom/movable/A in carried)
		if (QDELETED(A) || A.loc != here)
			continue
		if (isliving(A))
			var/mob/living/M = A
			if (M.buckled)
				seated += M
				continue
		A.persistence_set_loc(there)
	// Test the actual seat destination rather than relying on rider order.
	for (var/mob/living/M in seated)
		if (!QDELETED(M) && M.loc == here && M.buckled && (M.buckled in carried) && M.buckled.loc == there)
			M.persistence_set_loc(there)
	playsound(there, 'sound/effects/ladder.ogg', 40, TRUE)
	return TRUE

// Rides to level z, worked by user (the rider, or whoever called it).
/obj/structure/lift_platform/proc/travel(mob/living/user, z, rider = TRUE)
	if (moving || !z || z == src.z)
		return FALSE
	var/list/levels = shaft_levels()
	if (!(z in levels))
		to_chat(user, SPAN_WARNING("The shaft is blocked."))
		return FALSE
	var/refusal = load_refusal()
	if (refusal)
		to_chat(user, SPAN_WARNING(refusal))
		return FALSE
	var/storeys = abs(levels.Find(z) - levels.Find(src.z))
	var/drive = best_drive()
	if (!rider && drive_kind(drive) == LIFT_DRIVE_HAND)
		return FALSE
	var/obj/structure/lift_drive/D = istype(drive, /obj/structure/lift_drive) ? drive : null
	if (D && !D.spend(storeys))
		to_chat(user, SPAN_WARNING("\The [D] can't wind that far."))
		return FALSE
	var/turf/start = get_turf(src)
	moving = TRUE
	if (D)
		D.run_icon(TRUE)
	visible_message(SPAN_NOTICE(drive_kind(drive) == LIFT_DRIVE_HAND ? "[user] starts winding \the [src] [levels.Find(z) > levels.Find(src.z) ? "up" : "down"]." : "\The [src] starts to move [levels.Find(z) > levels.Find(src.z) ? "up" : "down"]."))
	var/done = do_after(user, travel_time(drive, storeys), rider ? src : user)
	if (D && !QDELETED(D))
		D.run_icon(FALSE)
	moving = FALSE
	if (QDELETED(src) || !done || get_turf(src) != start)
		return FALSE
	if (rider && get_turf(user) != start)
		return FALSE
	return finish_travel(user, z, levels)

// Take one fresh snapshot after winding. Use it for both admission and arrival.
/obj/structure/lift_platform/proc/finish_travel(mob/living/user, z, list/levels)
	var/list/carried = riders()
	var/refusal = load_refusal(carried)
	if (refusal)
		to_chat(user, SPAN_WARNING(refusal))
		return FALSE
	if (!(z in shaft_levels()) || !arrive(z, carried))
		to_chat(user, SPAN_WARNING("The shaft is blocked."))
		return FALSE
	visible_message(SPAN_NOTICE("\The [src] stops at the [storey_label(levels, z)]."))
	return TRUE

/obj/structure/lift_platform/attack_hand(mob/living/user)
	if (!isliving(user) || user.incapacitated())
		return
	if (get_turf(user) != get_turf(src))
		to_chat(user, SPAN_NOTICE("Stand on \the [src] to ride it."))
		return
	if (moving)
		return
	var/list/levels = shaft_levels()
	if (levels.len < 2)
		to_chat(user, SPAN_WARNING("There is no open shaft above or below \the [src]. Leave the floors over it open."))
		return
	var/list/choices = list()
	for (var/z in levels)
		if (z != src.z)
			choices[capitalize(storey_label(levels, z))] = z
	var/list/options = list()
	for (var/label in choices)
		options += label
	options += "Cancel"
	var/pick = WWinput(user, "Which stop?", "Lift", "Cancel", options)
	if (!istext(pick) || !(pick in choices) || QDELETED(src) || get_turf(user) != get_turf(src))
		return
	travel(user, choices[pick], TRUE)

/obj/structure/lift_platform/examine(mob/user, distance = -1)
	..()
	if (get_dist(user, src) > 2)
		return
	var/list/levels = shaft_levels()
	if (levels.len < 2)
		to_chat(user, SPAN_NOTICE("There is no open shaft above or below it."))
	else
		to_chat(user, SPAN_NOTICE("Its shaft has [levels.len] stops; it is at the [storey_label(levels, z)]."))
	switch (drive_kind(best_drive()))
		if (LIFT_DRIVE_ELECTRIC)
			to_chat(user, SPAN_NOTICE("An electric motor winds it."))
		if (LIFT_DRIVE_STEAM)
			to_chat(user, SPAN_NOTICE("A steam engine winds it."))
		if (LIFT_DRIVE_MOVER)
			to_chat(user, SPAN_NOTICE("A turning wheel beside the shaft winds it."))
		else
			to_chat(user, SPAN_NOTICE("It is wound by hand from the platform."))

// ---- calling ----------------------------------------------------------------------------

/obj/structure/lift_call
	name = "lift bell"
	desc = "A bell on a bracket beside a lift shaft. Ring it to call the lift to this floor."
	icon = 'icons/obj/lifts.dmi'
	icon_state = "lift_bell"
	anchored = TRUE
	density = FALSE
	not_movable = FALSE
	not_disassemblable = FALSE
	var/lit_state = null

/obj/structure/lift_call/button
	name = "lift call button"
	desc = "A call button beside a lift shaft. Press it to bring the lift to this floor."
	icon_state = "lift_button"
	lit_state = "lift_button_lit"

// The platform of the shaft beside this call, on any level of its column.
/obj/structure/lift_call/proc/find_platform()
	var/turf/here = get_turf(src)
	if (!here)
		return null
	for (var/turf/N in range(1, here))
		if (N == here)
			continue
		var/obj/structure/lift_platform/P = locate() in N
		if (P)
			return P
		var/turf/T = N
		var/z = here.z
		var/count = 0
		while (count < LIFT_MAX_STOREYS)
			z = multiz_level_below(z)
			T = z ? lift_turf_on(N, z) : null
			if (!T)
				break
			for (var/obj/structure/lift_platform/candidate in T)
				if (here.z in candidate.shaft_levels())
					return candidate
			count++
		z = here.z
		count = 0
		while (count < LIFT_MAX_STOREYS)
			z = multiz_level_above(z)
			T = z ? lift_turf_on(N, z) : null
			if (!T)
				break
			for (var/obj/structure/lift_platform/candidate in T)
				if (here.z in candidate.shaft_levels())
					return candidate
			count++
	return null

/obj/structure/lift_call/attack_hand(mob/living/user)
	if (!isliving(user) || user.incapacitated() || !Adjacent(user))
		return
	var/obj/structure/lift_platform/P = find_platform()
	if (lit_state)
		flick(lit_state, src)
		playsound(src, 'sound/machines/button.ogg', 40, TRUE)
	else
		playsound(src, 'sound/effects/deskbell.ogg', 50, TRUE)
	if (!P)
		to_chat(user, SPAN_WARNING("There is no lift in the shaft beside \the [src]."))
		return
	if (P.z == z)
		to_chat(user, SPAN_NOTICE("The lift is already here."))
		return
	if (P.drive_kind(P.best_drive()) == LIFT_DRIVE_HAND)
		user.visible_message(SPAN_NOTICE("[user] rings \the [src]."), SPAN_NOTICE("You ring \the [src]. Whoever rides the lift must wind it here."))
		for (var/mob/living/M in get_turf(P))
			to_chat(M, SPAN_NOTICE("You hear the lift bell ring at another floor."))
		return
	if (P.moving)
		to_chat(user, SPAN_NOTICE("The lift is already moving."))
		return
	to_chat(user, SPAN_NOTICE("You call the lift. Wait here for it."))
	var/turf/stop = lift_turf_on(get_turf(P), z)
	if (!stop || !(z in P.shaft_levels()))
		to_chat(user, SPAN_WARNING("The shaft doesn't reach this floor."))
		return
	P.travel(user, z, FALSE)

#undef LIFT_HAND_TIME
#undef LIFT_STEAM_FACTOR
#undef LIFT_ELECTRIC_TIME
#undef LIFT_MIN_TIME
#undef LIFT_MAX_STOREYS
#undef LIFT_DRIVE_HAND
#undef LIFT_DRIVE_MOVER
#undef LIFT_DRIVE_STEAM
#undef LIFT_DRIVE_ELECTRIC
