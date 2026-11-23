// A bounded pressure pocket for rebuilt surface ships, not a submarine
// atmosphere. Actual steel floors, paired ceilings, and closed watertight
// walls form pockets on the main deck or in the hold. Neither a cover nor
// a painted room is a seal. There is no underwater source of fresh room air.

#define HULL_PRESSURE_CELL_BREATHS 30
#define HULL_PRESSURE_MIN_INTEGRITY 0.75

/datum/hull_ledger
	var/tmp/list/pressure_air = null
	var/tmp/list/pressure_rooms = null
	var/tmp/pressure_mapped_at = -1

/proc/hull_pressure_barrier(turf/T)
	for (var/obj/structure/hull_bulkhead/W in T)
		if (!QDELETED(W) && W.loc == T && W.health >= initial(W.health) * HULL_PRESSURE_MIN_INTEGRITY)
			return TRUE
	for (var/obj/structure/simple_door/key_door/anyone/fire_door/steel/watertight/D in T)
		if (!QDELETED(D) && D.loc == T && !D.state && D.health >= initial(D.health) * HULL_PRESSURE_MIN_INTEGRITY)
			return TRUE
	return FALSE

/proc/hull_pressure_shell(turf/T, turf/top = null)
	var/obj/covers/steelplating/F = locate() in T
	if (QDELETED(F) || F.loc != T || F.health < F.maxhealth * HULL_PRESSURE_MIN_INTEGRITY || istype(F, /obj/covers/steelplating/hold/breach))
		return FALSE
	var/obj/covers/C
	if (top)
		// The existing main deck can be the hold's pressure ceiling.
		C = locate(/obj/covers/steelplating) in top
	else
		var/obj/roof/R = locate() in T
		if (QDELETED(R) || R.loc != T || R.onfire || R.health < initial(R.health) * HULL_PRESSURE_MIN_INTEGRITY)
			return FALSE
		C = R.building_floor()
		// A plated upper face or a solid concrete slab, not an ordinary
		// wood deck, awning, or glass roof. The slab belongs to this roof.
		if (!istype(C, /obj/covers/steelplating) && !istype(R, /obj/roof/concrete))
			return FALSE
	if (QDELETED(C) || C.health < C.maxhealth * HULL_PRESSURE_MIN_INTEGRITY || !isturf(C.loc))
		return FALSE
	if ((locate(/obj/structure/multiz) in T) || (locate(/obj/structure/multiz) in C.loc) || (locate(/obj/structure/cargo_hatch) in T) || (locate(/obj/structure/cargo_hatch) in C.loc))
		return FALSE
	return TRUE

/datum/hull_ledger/proc/pressure_key(turf/T)
	var/datum/craft_body/built/B = craft ? craft.body : null
	if (!T || !istype(B) || !B.placed() || (T.z != B.z && T.z != B.lower_z()))
		return null
	return "[T.z == B.z ? 0 : -1],[T.x - B.px],[T.y - B.py]"

/datum/hull_ledger/proc/pressure_scan()
	if (pressure_mapped_at == world.time)
		return
	pressure_mapped_at = world.time
	pressure_rooms = list()
	var/datum/craft_body/built/B = craft ? craft.body : null
	if (!istype(B) || !B.placed() || !B.offsets.len || B.offsets.len > SHIP_DRAUGHT_MAX_TILES)
		return
	var/list/main = B.cells()
	pressure_scan_deck(main)
	pressure_scan_deck(B.lower_cells(main), main)
	// Vent by cell, not by room ID: opening or splitting bulkheads cannot
	// manufacture breaths. A remote room with all seals shut is unaffected.
	if (!pressure_air)
		return
	for (var/key in pressure_air.Copy())
		if (!pressure_rooms[key])
			pressure_air -= key

/datum/hull_ledger/proc/pressure_scan_deck(list/on_deck, list/above = null)
	var/list/shell = list()
	var/list/walls = list()
	var/list/wet = list()
	var/list/visited = list()
	var/split = depth_disabled && bays_split()
	for (var/i = 1, i <= on_deck.len, i++)
		var/turf/T = on_deck[i]
		if (!T)
			continue
		var/turf/top = above ? above[i] : null
		shell[T] = (!above || top) && hull_pressure_shell(T, top)
		walls[T] = hull_pressure_barrier(T)
		if (depth_disabled && hull_depth_underwater(T))
			var/bay = split ? cell_bay[i] : 1
			var/cap = bay ? bay_capacity(bay) : 0
			wet[T] = cap <= 0 || bay_water[bay] >= cap * 0.98
	for (var/turf/seed in on_deck)
		if (visited[seed] || walls[seed])
			continue
		var/list/open = list(seed)
		var/list/keys = list()
		var/intact = TRUE
		visited[seed] = TRUE
		for (var/i = 1, i <= open.len, i++)
			var/turf/T = open[i]
			keys += pressure_key(T)
			if (!shell[T] || wet[T])
				intact = FALSE
			for (var/d in cardinal)
				var/turf/N = get_step(T, d)
				if (!N || isnull(shell[N]))
					intact = FALSE
					continue
				if (walls[N])
					if (!shell[N])
						intact = FALSE
					continue
				if (!visited[N])
					visited[N] = TRUE
					open += N
		if (intact)
			for (var/key in keys)
				pressure_rooms[key] = keys

/datum/hull_ledger/proc/pressure_room_intact(turf/T)
	pressure_scan()
	var/key = pressure_key(T)
	return key && pressure_rooms[key] ? TRUE : FALSE

/datum/hull_ledger/proc/pressure_room_air(turf/T)
	if (!depth_disabled || !pressure_air || !pressure_air.len || !submerged_built_hull_deck(T))
		return null
	pressure_scan()
	var/key = pressure_key(T)
	var/list/room = key ? pressure_rooms[key] : null
	if (!islist(room))
		return null
	var/bay = bay_at(T)
	if (!bay || bay_capacity(bay) <= 0 || water_at(T) >= bay_capacity(bay) * 0.98)
		for (var/k in room)
			pressure_air -= k
		return null
	return room

/datum/hull_ledger/proc/pressure_breath(turf/T, consume = FALSE)
	var/list/room = pressure_room_air(T)
	for (var/key in room)
		var/remaining = pressure_air[key]
		if (remaining <= 0)
			continue
		if (consume)
			pressure_air[key] = remaining - 1
		return TRUE
	return FALSE

// Called once, only on the first successful surface-to-sea-layer move.
// A saved submerged hull with no record conservatively starts with no air.
/datum/hull_ledger/proc/pressure_prepare_descent()
	pressure_clear()
	pressure_scan()
	for (var/key in pressure_rooms)
		LAZYINITLIST(pressure_air)
		pressure_air[key] = HULL_PRESSURE_CELL_BREATHS

/datum/hull_ledger/proc/pressure_clear()
	pressure_air = null
	pressure_rooms = null
	pressure_mapped_at = -1

/datum/hull_ledger/proc/pressure_to_list()
	if (!pressure_air)
		return null
	pressure_scan()
	return pressure_air.Copy()

/datum/hull_ledger/proc/pressure_from_list(list/record)
	pressure_clear()
	if (!depth_disabled || !islist(record))
		return
	var/datum/craft_body/built/B = craft ? craft.body : null
	if (!istype(B) || !B.placed() || B.offsets.len > SHIP_DRAUGHT_MAX_TILES)
		return
	for (var/list/O in B.offsets)
		for (var/deck in list(0, -1))
			var/key = "[deck],[O[1]],[O[2]]"
			if (!isnum(record[key]) || record[key] < 0)
				continue
			LAZYINITLIST(pressure_air)
			pressure_air[key] = clamp(round(record[key]), 0, HULL_PRESSURE_CELL_BREATHS)

// Doors can briefly open and close between life ticks. Vent while they are
// actually open, not only when someone next breathes beside one.
/proc/hull_pressure_changed(turf/T)
	if (!hull_ledgers.len || !T)
		return
	var/datum/hull_ledger/L = hull_ledger_at(T)
	if (L && L.pressure_air)
		L.pressure_mapped_at = -1
		L.pressure_scan()

/proc/sunken_hull_pressure_breath(turf/T, consume = FALSE)
	if (!submerged_built_hull_deck(T))
		return FALSE
	var/datum/hull_ledger/L = hull_ledger_at(T)
	return L ? L.pressure_breath(T, consume) : FALSE

// An oxygen-depleted but still sealed pocket is not open to the surrounding
// water. This never substitutes for a successful breath.
/proc/sunken_hull_pressure_sheltered(turf/T)
	if (!submerged_built_hull_deck(T))
		return FALSE
	var/datum/hull_ledger/L = hull_ledger_at(T)
	var/list/room = L ? L.pressure_room_air(T) : null
	for (var/key in room)
		if (isnum(L.pressure_air[key]))
			return TRUE
	return FALSE

// Sheltered crew can walk only inside one connected pocket of their own
// hull. A recorded zero breath budget is exhausted air, not seawater.
/proc/sunken_hull_pressure_same_shelter(turf/from, turf/destination)
	if (!from || !destination || from.z != destination.z || !hull_depth_underwater(from) || !hull_depth_underwater(destination))
		return FALSE
	var/datum/hull_ledger/L = hull_ledger_at(from)
	if (!L?.depth_disabled || !L.pressure_air || !L.deck_holds(destination))
		return FALSE
	var/list/room = L.pressure_room_air(from)
	if (!room || room != L.pressure_room_air(destination))
		return FALSE
	for (var/key in room)
		if (isnum(L.pressure_air[key]))
			return TRUE
	return FALSE

#undef HULL_PRESSURE_CELL_BREATHS
#undef HULL_PRESSURE_MIN_INTEGRITY
