// ============================================================
// The drydock (docs/berths.md)
// ------------------------------------------------------------
// Dig a basin of trench beside the water and build a dock gate on the
// flooded trench at its mouth. The basin is every trench tile joined to the
// gate's tile, not counting the gate; it must touch open water nowhere but at
// its gates (diagonals count, as water runs over corners), and holds at most
// DRYDOCK_MAX_TILES tiles.
//
// - Open, the gate lets a built hull sail into the flooded basin, which is a
//   berth (berth.dm) like a boathouse slip.
// - Shut, it holds the water back. Pump out the dock at the gate: two seconds
//   a tile by hand, faster for each bilge pump standing within three tiles of
//   the gate (a hand pump doubles it, a steam or sump pump adds four). When
//   the last tile is pumped the whole basin runs dry at once and every hull
//   in it settles on the floor: she lies dry, as on a slipway, and can be
//   worked on from stem to stern.
// - Open the sluices to flood the basin again, then open the gate to sail out.
//
// A hull is only pumped dry with every tile of her inside the basin. The
// gate keeps its state (shut, drained); the basin is found again from the
// gate, so nothing else is saved.
// ============================================================

#define DRYDOCK_MAX_TILES 400
#define DRYDOCK_PUMP_TIME 20     // deciseconds for one go at the pump
#define DRYDOCK_PUMP_REACH 3     // tiles from a gate a bilge pump helps
#define DRYDOCK_SLUICE_TIME 100  // deciseconds to flood the basin
#define DRYDOCK_SHUT_LEVEL -1000 // the level a shut gate holds the water at

// Basin and gate tiles of every known dock: turf = gate. Rebuilt from the
// gates, never saved.
var/global/list/dock_basin_turfs = list()

/obj/structure/canal_lock/dock_gate
	name = "dock gate"
	desc = "A heavy pair of timber gates across the mouth of a dug basin, with a sluice and a pump. Shut it and pump the basin dry to lay a ship on the dock floor; open the sluices and the gate to float her out."
	icon = 'icons/obj/berths.dmi'
	icon_state = "dock_gate_open"
	var/shut = FALSE
	var/drained = FALSE
	var/tmp/pumped = 0
	var/tmp/list/basin_cache = null

/obj/structure/canal_lock/dock_gate/persistence_runtime_var(key)
	return key == "pumped" || key == "basin_cache" || ..()

/obj/structure/canal_lock/dock_gate/spawn_level()
	set_shut(shut)
	refresh_basin()

/obj/structure/canal_lock/dock_gate/after_load()
	..()
	busy = FALSE
	set_shut(shut)
	refresh_basin()

/obj/structure/canal_lock/dock_gate/Destroy()
	forget_basin()
	return ..()

/obj/structure/canal_lock/dock_gate/update_icon()
	icon_state = shut ? "dock_gate_shut" : "dock_gate_open"

// The level of the open water outside the gate.
/obj/structure/canal_lock/dock_gate/proc/sea_level()
	var/turf/T = get_turf(src)
	var/list/B = basin()
	for (var/d in cardinal)
		var/turf/W = get_step(T, d)
		if (W && is_open_water(W) && !(B && (W in B)) && !(locate(/obj/structure/canal_lock/dock_gate) in W))
			return terrain_height_at(W)
	return T ? terrain_height_at(T) : 0

/obj/structure/canal_lock/dock_gate/proc/set_shut(state)
	shut = state
	density = shut
	chamber_level = shut ? DRYDOCK_SHUT_LEVEL : sea_level()
	update_icon()

// ---- The basin ----

// The basin tiles, or a text reason there is no basin. Fills gates with the
// dock gates around it.
/obj/structure/canal_lock/dock_gate/proc/survey_basin(list/gates = null)
	var/turf/start = get_turf(src)
	if (!istype(start, /turf/floor/trench))
		return "The dock gate must stand in the flooded mouth of a dug basin."
	var/list/basin = list()
	var/list/queue = list()
	var/list/seen = list()
	seen[start] = TRUE
	if (gates)
		gates |= src
	for (var/d in cardinal)
		var/turf/N = get_step(start, d)
		if (istype(N, /turf/floor/trench) && !(locate(/obj/structure/canal_lock/dock_gate) in N))
			queue += N
			seen[N] = TRUE
	while (queue.len)
		var/turf/T = queue[queue.len]
		queue.len--
		basin += T
		if (basin.len > DRYDOCK_MAX_TILES)
			return "The basin is too large: a dock holds at most [DRYDOCK_MAX_TILES] tiles."
		for (var/turf/N in range(1, T))
			if (seen[N])
				continue
			seen[N] = TRUE
			var/obj/structure/canal_lock/dock_gate/G = locate() in N
			if (G)
				if (gates)
					gates |= G
				continue
			if (istype(N, /turf/floor/trench))
				queue += N
			else if (is_open_water(N))
				return "The basin is open to the water at [N.x],[N.y]: only its gates may touch the water."
	if (!basin.len)
		return "There is no dug basin behind the gate."
	return basin

/obj/structure/canal_lock/dock_gate/proc/basin()
	if (!basin_cache)
		refresh_basin()
	return basin_cache

/obj/structure/canal_lock/dock_gate/proc/forget_basin()
	for (var/turf/T in dock_basin_turfs.Copy())
		if (dock_basin_turfs[T] == src)
			dock_basin_turfs -= T
	basin_cache = null

/obj/structure/canal_lock/dock_gate/proc/refresh_basin()
	forget_basin()
	var/list/B = survey_basin()
	if (!islist(B))
		return
	basin_cache = B
	for (var/turf/T in B)
		dock_basin_turfs[T] = src
	var/turf/G = get_turf(src)
	if (G)
		dock_basin_turfs[G] = src

// Every dock gate of this basin.
/obj/structure/canal_lock/dock_gate/proc/all_gates()
	. = list()
	var/B = survey_basin(.)
	if (!islist(B))
		. = list(src)

// TRUE when every tile of the basin is dry.
/obj/structure/canal_lock/dock_gate/proc/basin_dry()
	var/list/B = basin()
	if (!B)
		return FALSE
	for (var/turf/T in B)
		if (istype(T, /turf/floor/trench/flooded))
			return FALSE
	return TRUE

// The built hulls with every tile in the basin, and whether any lies across
// the gate or half out of it.
/obj/structure/canal_lock/dock_gate/proc/hulls_in_basin(list/astray = null)
	. = list()
	var/list/B = basin()
	if (!B)
		return
	var/list/inside = list()
	for (var/turf/T in B)
		inside[T] = TRUE
	var/list/seen = list()
	for (var/turf/T in B)
		var/datum/craft/C = craft_at(T)
		if (!C || seen[C] || !C.body)
			continue
		seen[C] = TRUE
		var/whole = TRUE
		for (var/turf/O in C.body.cells())
			if (!inside[O])
				whole = FALSE
				break
		if (whole)
			. += C
		else if (astray)
			astray += C

// ---- Keel blocks ----

// Timber blocks a ship's keel rests on in a dry dock or on a slipway berth.
// They hold nothing up in the game: a hull lies dry at a berth without them.
/obj/structure/keel_blocks
	name = "keel blocks"
	desc = "Stacked timber blocks for a ship's keel to rest on in a dry dock or on a slipway berth."
	icon = 'icons/obj/berths.dmi'
	icon_state = "keel_blocks"
	anchored = TRUE
	density = FALSE
	flammable = TRUE
	layer = TURF_LAYER + 0.05

// ---- The berth ----

/obj/structure/canal_lock/dock_gate/berth_holds(datum/craft/C, list/cells)
	var/list/B = basin()
	if (!B || !C || !cells || !cells.len)
		return FALSE
	var/list/inside = list()
	for (var/turf/T in B)
		inside[T] = TRUE
	for (var/turf/T in cells)
		if (!inside[T])
			return FALSE
	return TRUE

/obj/structure/canal_lock/dock_gate/berth_dry(datum/craft/C)
	return drained

// TRUE when a built hull may float on T: a flooded tile of a dock basin, or
// the tile of an open gate.
/proc/dock_floats(turf/T)
	var/obj/structure/canal_lock/dock_gate/G = dock_basin_turfs[T]
	if (!G || QDELETED(G))
		return FALSE
	if (get_turf(G) == T)
		return !G.shut
	return istype(T, /turf/floor/trench/flooded)

// ---- Working the dock ----

// Why the dock cannot be pumped out now, or null.
/obj/structure/canal_lock/dock_gate/proc/pump_refusal()
	var/B = survey_basin()
	if (!islist(B))
		return B
	if (drained || basin_dry())
		return "The basin is already dry."
	for (var/obj/structure/canal_lock/dock_gate/G in all_gates())
		if (!G.shut)
			return "Shut the gate[G == src ? "" : " at [G.x],[G.y]"] first."
	var/list/astray = list()
	hulls_in_basin(astray)
	if (astray.len)
		var/datum/craft/C = astray[1]
		return "The [C.name] lies partly outside the basin: bring her wholly inside or take her out first."
	return null

// Tiles one go at the pump drains, with the pumps standing near the gates.
/obj/structure/canal_lock/dock_gate/proc/pump_rate()
	. = 1
	var/hand = 0
	var/list/seen = list()
	for (var/obj/structure/canal_lock/dock_gate/G in all_gates())
		for (var/obj/structure/cellar_pump/P in range(DRYDOCK_PUMP_REACH, G))
			if (seen[P])
				continue
			seen[P] = TRUE
			if (istype(P, /obj/structure/cellar_pump/lever))
				hand++
			else
				. += 4
	. += hand

// Runs the whole basin dry and settles the hulls in it on the floor.
/obj/structure/canal_lock/dock_gate/proc/drain()
	var/list/B = basin()
	if (!B)
		return FALSE
	var/list/hulls = hulls_in_basin()
	for (var/turf/T in B)
		if (istype(T, /turf/floor/trench/flooded))
			T.ChangeTurf(/turf/floor/trench)
	pumped = 0
	for (var/obj/structure/canal_lock/dock_gate/G in all_gates())
		G.drained = TRUE
		G.refresh_basin()
	for (var/datum/craft/C in hulls)
		C.set_speed(VESSEL_SPEED_STOP)
		C.set_anchor(TRUE)
		if (C.ledger)
			C.ledger.water = 0
			C.ledger.grounded = FALSE
			C.ledger.stop_sinking()
			C.ledger.depth_told = HULL_DEPTH_DRY
		C.crew_message(SPAN_NOTICE("The last of the water is pumped out of the dock and the [C.name] settles on the blocks, dry from stem to stern."))
	return TRUE

// Floods the basin from the sea again.
/obj/structure/canal_lock/dock_gate/proc/flood()
	var/list/B = basin()
	if (!B)
		return FALSE
	var/salt = FALSE
	var/turf/floor/G = get_turf(src)
	if (istype(G) && G.salty)
		salt = TRUE
	for (var/turf/T in B)
		if (!istype(T, /turf/floor/trench/flooded))
			T.ChangeTurf(salt ? /turf/floor/trench/flooded/salty : /turf/floor/trench/flooded)
	pumped = 0
	for (var/obj/structure/canal_lock/dock_gate/D in all_gates())
		D.drained = FALSE
		D.refresh_basin()
	return TRUE

/obj/structure/canal_lock/dock_gate/examine(mob/user)
	..()
	var/B = survey_basin()
	if (!islist(B))
		to_chat(user, SPAN_WARNING(B))
		return
	var/list/basin = B
	to_chat(user, SPAN_NOTICE("The gate is [shut ? "shut" : "open"] and the basin of [basin.len] tile\s is [drained ? "pumped dry" : "flooded"]."))

/obj/structure/canal_lock/dock_gate/attack_hand(mob/living/human/H)
	if (!istype(H) || !Adjacent(H))
		return
	if (busy)
		to_chat(H, SPAN_WARNING("The dock is already being worked."))
		return
	refresh_basin()
	var/list/options = list()
	if (!drained)
		options[shut ? "Open the gate" : "Shut the gate"] = "gate"
	if (shut && !drained)
		options["Pump out the dock"] = "pump"
	if (drained)
		options["Open the sluices"] = "flood"
	if (basin())
		options["Survey her condition"] = "survey"
		breakup_options(options, breakup_hulls())
	var/B = survey_basin()
	var/text = islist(B) ? "The gate is [shut ? "shut" : "open"] and the basin is [drained ? "dry" : "flooded"]." : B
	var/choice = WWinput(H, text, name, "Cancel", options + list("Cancel"))
	if (!(choice in options) || busy || !Adjacent(H))
		return
	if (istype(options[choice], /datum/craft))
		breakup_action(H, options[choice])
		return
	switch (options[choice])
		if ("gate")
			var/blocker = null
			for (var/obj/structure/canal_lock/dock_gate/G in all_gates())
				if (!shut && craft_at(get_turf(G)))
					blocker = G
			if (blocker)
				to_chat(H, SPAN_WARNING("A hull lies across the gate."))
				return
			var/now = !shut
			for (var/obj/structure/canal_lock/dock_gate/G in all_gates())
				G.set_shut(now)
			H.visible_message(SPAN_NOTICE("[H] swings the dock gates [now ? "shut" : "open"]."))
		if ("pump")
			var/why = pump_refusal()
			if (why)
				to_chat(H, SPAN_WARNING(why))
				return
			var/list/basin = basin()
			busy = TRUE
			H.visible_message(SPAN_NOTICE("[H] starts pumping out the dock."), SPAN_NOTICE("You start working the dock pump. The basin holds [basin.len] tile\s of water."))
			while (TRUE)
				if (!do_after(H, yard_time(src, DRYDOCK_PUMP_TIME), src) || QDELETED(src) || pump_refusal())
					break
				pumped += pump_rate()
				if (pumped >= basin.len)
					drain()
					H.visible_message(SPAN_NOTICE("The dock is pumped dry."))
					break
			busy = FALSE
			if (!drained && pumped > 0 && !QDELETED(src))
				to_chat(H, SPAN_NOTICE("[min(pumped, basin.len)] of [basin.len] tiles are pumped out."))
		if ("flood")
			busy = TRUE
			H.visible_message(SPAN_NOTICE("[H] opens the sluices and the sea pours into the dock."))
			var/ok = do_after(H, yard_time(src, DRYDOCK_SLUICE_TIME), src)
			busy = FALSE
			if (ok && !QDELETED(src))
				flood()
		if ("survey")
			var/list/hulls = hulls_in_basin()
			if (!hulls.len)
				to_chat(H, SPAN_NOTICE("No hull lies wholly in the basin."))
			for (var/datum/craft/C in hulls)
				if (C.ledger)
					to_chat(H, SPAN_NOTICE(C.ledger.berth_condition_text()))

#undef DRYDOCK_MAX_TILES
#undef DRYDOCK_PUMP_TIME
#undef DRYDOCK_PUMP_REACH
#undef DRYDOCK_SLUICE_TIME
#undef DRYDOCK_SHUT_LEVEL
